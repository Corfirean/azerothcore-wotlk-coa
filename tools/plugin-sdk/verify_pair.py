"""Check that a worldserver.exe and an exported SDK belong to the same build, and write the pair manifest.

The host records its ABI fingerprint in a `.coapl` section ("COAPLUGIN1|worldserver|<fp>"); the SDK records
the fingerprint plugins are built with in sdk.json. They must be equal, or every plugin built against this SDK
would be refused by this host.

usage: python -I verify_pair.py <worldserver.exe> <sdk dir> <manifest out> [--core-sha SHA] [--expect-cl VERSION]
"""
import argparse
import hashlib
import json
import re
import sys

HOST_MARK = re.compile(rb'COAPLUGIN1\|worldserver\|([0-9a-f]{64})')


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('worldserver')
    ap.add_argument('sdk')
    ap.add_argument('manifest')
    ap.add_argument('--core-sha', default='')
    ap.add_argument('--expect-cl', default='', help='exact MSVC version the toolchain pin requires')
    a = ap.parse_args()

    data = open(a.worldserver, 'rb').read()
    marks = set(HOST_MARK.findall(data))
    if len(marks) != 1:
        sys.exit('worldserver.exe must carry exactly one host ABI mark, found %d' % len(marks))
    host_fp = marks.pop().decode()

    sdk = json.load(open(a.sdk + '/sdk.json', encoding='utf-8'))
    sdk_fp = sdk['abiFingerprint']
    if host_fp != sdk_fp:
        sys.exit('ABI mismatch: worldserver.exe %s, SDK %s' % (host_fp, sdk_fp))

    compiler = next((i.split('=', 1)[1] for i in sdk['abiInputs'] if i.startswith('compiler=')), '')
    if a.expect_cl and compiler != 'MSVC-' + a.expect_cl:
        sys.exit('toolchain pin: built with %s, pinned MSVC-%s' % (compiler, a.expect_cl))

    manifest = {
        'schema': 1,
        'kind': 'coa-plugin-host-pair',
        'coreCommit': a.core_sha,
        'abiFingerprint': host_fp,
        'compiler': compiler,
        'worldserverSha256': sha256(a.worldserver),
        'worldserverLibSha256': sdk.get('worldserverLibSha256', ''),
    }
    json.dump(manifest, open(a.manifest, 'w', encoding='utf-8'), indent=2)
    print('pair OK: fingerprint %s, compiler %s' % (host_fp, compiler))


if __name__ == '__main__':
    main()
