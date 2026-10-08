# Mesh pieces (skin submeshes) of a client model whose vertices use bone slots outside the piece's bone list
# (stretched sheets in game). Usage: python check_bones.py <model.m2 path in the client>
import sys, glob, struct, tempfile, collections
sys.path.insert(0, 'C:/CoA-Build/eunoia')
import storm
S = storm.S
B = chr(92)
D = 'C:/Ascension Local/Data/'
handles = []
for a in sorted(glob.glob(D + '*.MPQ') + glob.glob(D + '*/*.MPQ')):
    try:
        handles.append(storm.open_mpq(a))
    except Exception:
        pass


def get(name):
    owner = [h for h in handles if S.SFileHasFile(h, name.encode())]
    t = tempfile.mktemp()
    storm.extract(owner[-1], name, t)
    return open(t, 'rb').read()


base = sys.argv[1].replace('/', B)[:-3]
m, k = get(base + '.m2'), get(base + '00.skin')
nb = struct.unpack_from('<I', m, 0x2C)[0]
nv, ov = struct.unpack_from('<II', m, 0x3C)
nbl, obl = struct.unpack_from('<II', m, 0x78)
bone_lookup = struct.unpack_from('<%dh' % nbl, m, obl)
nvl, ovl, nidx, oidx, nprop, oprop, nsub, osub = struct.unpack_from('<8I', k, 4)
lookup = struct.unpack_from('<%dH' % nvl, k, ovl)
tris = struct.unpack_from('<%dH' % nidx, k, oidx)
props = k[oprop:oprop + nprop * 4]
print('bones', nb, 'bone lookup', nbl, 'submeshes', nsub)
for i in range(nsub):
    sid, level, vs, vc, ts, tc, bc, bs = struct.unpack_from('<8H', k, osub + i * 48)
    start = (level << 16) | ts
    over = past = 0
    for v in set(tris[start:start + tc]):
        for j in range(4):
            weight = m[ov + lookup[v] * 48 + 12 + j]
            slot = props[v * 4 + j]
            if weight and slot >= bc:
                over += 1
            if weight and bs + slot < nbl and bone_lookup[bs + slot] >= nb:
                past += 1
    if over or past or bs + bc > nbl:
        print('  geoset %5d  bones %3d from %4d  weighted slots past its list %5d  bad bone ids %4d%s'
              % (sid, bc, bs, over, past, '  LIST PAST LOOKUP TABLE' if bs + bc > nbl else ''))
