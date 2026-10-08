# Pack an Esteria race's converted files (output/patch-root, then integration/patch-root on top) into one client
# archive. Sequences of the player models without a .anim file are aliased to Stand (else crash 0x006844E8).
#   python pack_race.py <race> <archive name> <model path inside the archive> [...]
import sys, os, struct, ctypes
sys.path.insert(0, 'C:/CoA-Build/eunoia')
import storm
import m2fix
S = storm.S
B = chr(92)
race, archive, models = sys.argv[1], sys.argv[2], sys.argv[3:]
ROOT = 'C:/Users/ilusi/Downloads/RetroPorterWork/%s/' % race
WORK = 'C:/CoA-Build/esteria/pack_%s/' % os.environ.get('PACK_NAME', race)
files = {}
for top in os.environ.get('PACK_ROOTS', 'output/patch-root,integration/patch-root').split(','):
    base = ROOT + top
    for d, _, names in os.walk(base):
        for n in names:
            rel = os.path.relpath(os.path.join(d, n), base).replace('/', B).replace(chr(92), B)
            if rel.lower().endswith(('.lua', '.xml', '.toc')):
                continue                    # never Esteria's UI scripts: they replace our creation screen
            files[rel.lower()] = (rel, os.path.join(d, n))
os.makedirs(WORK, exist_ok=True)
for model in models:
    key = model.lower()
    rel, disk = files[key]
    m = bytearray(open(disk, 'rb').read())
    stem = key[:-3]
    fixed = m2fix.alias_missing(m, lambda sid, var: (stem + '%04d-%02d.anim' % (sid, var)) in files)
    padded = m2fix.pad_tracks(m)
    n = struct.unpack_from('<I', m, 0x1C)[0]
    out = WORK + os.path.basename(disk)
    open(out, 'wb').write(m)
    files[key] = (rel, out)
    print(rel, 'sequences', n, 'aliased to stand', fixed, 'tracks padded', padded)
S.SFileCreateArchive.argtypes = [ctypes.c_char_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(ctypes.c_void_p)]
S.SFileCreateArchive.restype = ctypes.c_bool
S.SFileAddFileEx.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32]
S.SFileAddFileEx.restype = ctypes.c_bool
S.SFileCloseArchive.argtypes = [ctypes.c_void_p]
arc = os.path.abspath(WORK + archive)
if os.path.exists(arc):
    os.remove(arc)
h = ctypes.c_void_p()
assert S.SFileCreateArchive(arc.encode(), 0x01000000 | 0x00100000 | 0x00200000, len(files) + 64, ctypes.byref(h))
for rel, disk in files.values():
    assert S.SFileAddFileEx(h, os.path.abspath(disk).encode(), rel.encode(), 0x200 | 0x80000000, 2, 2), rel
S.SFileCloseArchive(h)
print('built', arc, len(files), 'files', os.path.getsize(arc), 'bytes')
