"""Export the CoA Plugin SDK from a COA_PLUGIN_HOST build tree.

The SDK is self-contained: headers, generated headers, the worldserver import library, the
static helper libraries plugins need, and a CMake package. Plugins are configured against the
SDK directory only and never see the core source or build tree.

usage: python -I export_sdk.py <source dir> <build dir> <sdk out dir>

The SDK and the worldserver.exe of the same build form a pair: both carry the same ABI fingerprint, and a
plugin built against this SDK loads only into that host. CI publishes them together.
"""
import hashlib
import json
import os
import re
import shutil
import sys

HEADER_EXT = ('.h', '.hpp', '.hh', '.inl', '.ipp', '.tcc')


def norm(p):
    return os.path.normcase(os.path.normpath(p))


def ninja_unescape(s):
    return s.replace('$:', ':').replace('$ ', ' ').replace('$$', '$')


def module_compile_vars(build_dir):
    """DEFINES / INCLUDES / FLAGS of one translation unit of the static `modules` target."""
    text = open(os.path.join(build_dir, 'build.ninja'), encoding='utf-8', errors='replace').read()
    for block in text.split('\nbuild '):
        head = block.split('\n', 1)[0]
        if 'modules.dir' in head and head.split(':')[0].endswith('.cpp.obj') and 'CXX_COMPILER' in head:
            vars_ = {}
            for line in block.split('\n')[1:]:
                m = re.match(r'\s+(\w+) = (.*)', line)
                if m:
                    vars_[m.group(1)] = ninja_unescape(m.group(2))
                elif line and not line.startswith(' '):
                    break
            if 'INCLUDES' in vars_:
                return head, vars_
    raise SystemExit('no modules translation unit found in build.ninja')


def split_args(s):
    out, cur, quoted = [], '', False
    s = s.replace('\\"', '\x01')  # escaped quote inside a -D value: keep it literally
    for ch in s:
        if ch == '\x01':
            cur += '"'
            quoted = not quoted
        elif ch == '"':
            quoted = not quoted
        elif ch == ' ' and not quoted:
            if cur:
                out.append(cur)
            cur = ''
        else:
            cur += ch
    if cur:
        out.append(cur)
    return out


def copy_headers(src, dst, recursive):
    count = 0
    if recursive:
        # A Boost distribution root (the binary installer's, used in CI) also holds libs/, doc/, tools/
        # with tests, fuzz corpora and deep paths; plugins include only <boost/...>.
        walk_from = src
        if os.path.isfile(os.path.join(src, 'boost', 'version.hpp')) and os.path.isdir(os.path.join(src, 'libs')):
            walk_from = os.path.join(src, 'boost')
        for root, _, files in os.walk(walk_from):
            for f in files:
                rel = os.path.relpath(os.path.join(root, f), src)
                in_boost = rel.replace('\\', '/').startswith('boost/')
                if f.lower().endswith(HEADER_EXT) or (in_boost and '.' not in f):
                    os.makedirs(os.path.dirname(os.path.join(dst, rel)), exist_ok=True)
                    shutil.copy2(os.path.join(root, f), os.path.join(dst, rel))
                    count += 1
    else:
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(src):
            p = os.path.join(src, f)
            if os.path.isfile(p) and f.lower().endswith(HEADER_EXT):
                shutil.copy2(p, os.path.join(dst, f))
                count += 1
    return count


def main():
    source, build, sdk = (os.path.abspath(a) for a in sys.argv[1:4])
    if os.path.exists(sdk):
        shutil.rmtree(sdk)
    os.makedirs(sdk)

    head, v = module_compile_vars(build)
    includes = [a[2:] for a in split_args(v['INCLUDES']) if a.startswith(('-I', '/I'))]
    includes += [a for a in split_args(v['INCLUDES']) if not a.startswith(('-I', '/I', '-external'))]
    externals = []
    args = split_args(v['INCLUDES'])
    for i, a in enumerate(args):
        if a in ('-external:I', '/external:I') and i + 1 < len(args):
            externals.append(args[i + 1])
        elif a.startswith(('-external:I', '/external:I')) and len(a) > len('-external:I'):
            externals.append(a[len('-external:I'):])
    includes = [p for p in includes if os.path.isdir(p)] + [p for p in externals if os.path.isdir(p)]

    sdk_includes, header_count, seen = [], 0, set()
    src_root = norm(os.path.join(source, 'src'))
    for n, inc in enumerate(includes):
        key = norm(inc)
        if key in seen or key.startswith(norm(os.path.join(source, 'modules'))):
            continue  # other modules' sources are not part of the plugin API
        seen.add(key)
        if key.startswith(src_root):
            rel = os.path.relpath(inc, source)
            dst = os.path.join(sdk, 'include', 'core', rel)
            header_count += copy_headers(inc, dst, recursive=False)
        elif key.startswith(norm(build)):
            rel = os.path.relpath(inc, build)
            dst = os.path.join(sdk, 'include', 'generated', rel)
            header_count += copy_headers(inc, dst, recursive=False)
        else:
            # Short on purpose: the SDK is unpacked inside the server folder, Boost alone nests 155
            # characters deep, and Ninja on Windows stops at 250.
            rel = 'x%d' % n
            if key.startswith(norm(source)):
                rel = os.path.join('deps', os.path.relpath(inc, source))
            dst = os.path.join(sdk, 'include', rel)
            header_count += copy_headers(inc, dst, recursive=True)
        if os.path.isdir(dst):
            sdk_includes.append(os.path.relpath(dst, sdk).replace('\\', '/'))

    defines = [d[2:] for d in split_args(v.get('DEFINES', '')) if d.startswith(('-D', '/D'))]
    # BOOST_ALL_NO_LIB: compiled Boost code a plugin needs (SQUID's boost::thread) is the host's own copy,
    # exported by worldserver.exe; Boost's auto-link pragmas would pull in a second, conflicting one.
    defines = [d for d in defines if not d.startswith(('ACORE_API_EXPORT_', '_CONF_DIR'))] + ['COA_PLUGIN_SDK', 'BOOST_ALL_NO_LIB']
    # Output paths and the core's precompiled header (/Yu /Fp /FI of cmake_pch) belong to the host build,
    # not to the plugin ABI; a plugin given them would look for a PCH that does not exist.
    raw_flags = split_args(v.get('FLAGS', ''))
    flags = []
    skip_next = False
    for f in raw_flags:
        if skip_next:
            skip_next = False
            continue
        if f.startswith(('/Fd', '/Fo', '/FS', '-Fd', '-Fo', '/Yu', '-Yu', '/Fp', '-Fp')):
            continue
        if f in ('/FI', '-FI'):
            skip_next = True
            continue
        if f.startswith(('/FI', '-FI')) and 'cmake_pch' in f:
            continue
        flags.append(f)
    # Plugins are built by Ninja in parallel: /Zi makes every object of a target write one shared
    # PDB (C2471 under load). /Z7 keeps debug info in the objects; it does not affect the ABI.
    flags = ['/Z7' if f in ('/Zi', '-Zi') else f for f in flags]

    os.makedirs(os.path.join(sdk, 'lib'))
    libs = []
    for name in ('worldserver.lib', 'fmt.lib'):
        found = None
        for root, _, files in os.walk(build):
            if name in files:
                found = os.path.join(root, name)
                break
        if not found:
            raise SystemExit('missing ' + name)
        shutil.copy2(found, os.path.join(sdk, 'lib', name))
        libs.append('lib/' + name)

    abi_dir = os.path.join(build, 'coa_plugin')
    abi_inputs = open(os.path.join(abi_dir, 'coa-plugin-abi-inputs.txt'), encoding='utf-8').read()
    fingerprint = re.search(r'fingerprint=([0-9a-f]{64})', abi_inputs).group(1)
    shutil.copy2(os.path.join(abi_dir, 'coa-plugin-abi-inputs.txt'), os.path.join(sdk, 'coa-plugin-abi-inputs.txt'))

    def cm(items):
        return ';'.join(i.replace('\\', '/').replace(';', '\\;').replace('"', '\\"') for i in items)

    os.makedirs(os.path.join(sdk, 'cmake'))
    with open(os.path.join(sdk, 'cmake', 'CoAPluginSDKConfig.cmake'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('# Generated by export_sdk.py. Host ABI fingerprint: %s\n' % fingerprint)
        f.write('get_filename_component(COA_SDK_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)\n')
        f.write('set(COA_PLUGIN_ABI_FINGERPRINT "%s")\n' % fingerprint)
        f.write('if(NOT TARGET CoA::PluginSDK)\n')
        f.write('  add_library(CoA::PluginSDK INTERFACE IMPORTED)\n')
        f.write('  set(_coa_inc "")\n  foreach(_d %s)\n    list(APPEND _coa_inc "${COA_SDK_ROOT}/${_d}")\n  endforeach()\n'
                % ' '.join('"%s"' % i for i in sdk_includes))
        f.write('  set(_coa_libs "")\n  foreach(_l %s)\n    list(APPEND _coa_libs "${COA_SDK_ROOT}/${_l}")\n  endforeach()\n'
                % ' '.join('"%s"' % l for l in libs))
        f.write('  set_target_properties(CoA::PluginSDK PROPERTIES\n')
        f.write('    INTERFACE_INCLUDE_DIRECTORIES "${_coa_inc}"\n')
        f.write('    INTERFACE_COMPILE_DEFINITIONS "%s"\n' % cm(defines))
        f.write('    INTERFACE_COMPILE_OPTIONS "%s"\n' % cm(flags))
        f.write('    INTERFACE_LINK_LIBRARIES "${_coa_libs}")\n')
        f.write('endif()\n')
        f.write('function(coa_add_plugin name)\n')
        f.write('  add_library(${name} SHARED ${ARGN})\n')
        f.write('  target_link_libraries(${name} PRIVATE CoA::PluginSDK)\n')
        f.write('  set_target_properties(${name} PROPERTIES MSVC_RUNTIME_LIBRARY MultiThreadedDLL)\n')
        f.write('  if(MSVC)\n')
        f.write('    target_link_options(${name} PRIVATE "/MAP")\n')
        f.write('  endif()\n')
        f.write('endfunction()\n')

    sdk_json = {
        'schema': 1,
        'abiFingerprint': fingerprint,
        'abiInputs': abi_inputs.strip().split('\n'),
        'sourceTu': head.split(':')[0],
        'includeDirs': len(sdk_includes),
        'headers': header_count,
        'defines': defines,
        'flags': flags,
        'libs': libs,
        'worldserverLibSha256': hashlib.sha256(open(os.path.join(sdk, 'lib', 'worldserver.lib'), 'rb').read()).hexdigest(),
    }
    json.dump(sdk_json, open(os.path.join(sdk, 'sdk.json'), 'w', encoding='utf-8'), indent=2)
    size = sum(os.path.getsize(os.path.join(r, x)) for r, _, fs in os.walk(sdk) for x in fs)
    print('SDK %s: %d include dirs, %d headers, %.1f MB, fingerprint %s' % (sdk, len(sdk_includes), header_count, size / 1e6, fingerprint))


if __name__ == '__main__':
    main()
