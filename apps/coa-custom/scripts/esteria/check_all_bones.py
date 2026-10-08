# Every playable race model: does its .skin (as the client loads it) fit its .m2? Bone lists past the model's bone
# lookup table or lookup entries past its bones make the client read past the bone matrices (crash 0x008204AE).
import sys, glob, struct, tempfile, os
sys.path.insert(0, 'C:/CoA-Build/eunoia')
import storm
S = storm.S
B = chr(92)
D = 'C:/Ascension Local/Data/'
handles = []
for a in sorted(glob.glob(D + '*.MPQ') + glob.glob(D + '*/*.MPQ')):
    try:
        handles.append((os.path.basename(a), storm.open_mpq(a)))
    except Exception:
        pass


def get(name):
    owner = [(n, h) for n, h in handles if S.SFileHasFile(h, name.encode())]
    if not owner:
        return None, None
    t = tempfile.mktemp()
    storm.extract(owner[-1][1], name, t)
    return open(t, 'rb').read(), owner[-1][0]


for line in open(sys.argv[1]).read().splitlines():
    race, path = line.split(' ', 1)
    base = path.replace('/', B)[:-3]
    m, mfrom = get(base + '.m2')
    k, kfrom = get(base + '00.skin')
    if not m or not k:
        print(race, path, 'MISSING', 'm2' if not m else 'skin')
        continue
    nb = struct.unpack_from('<I', m, 0x2C)[0]
    nbl, obl = struct.unpack_from('<II', m, 0x78)
    lookups = struct.unpack_from('<%dh' % nbl, m, obl) if nbl else ()
    bad_lookup = sum(1 for x in lookups if x >= nb)
    nsub, osub = struct.unpack_from('<II', k, 4 + 6 * 4)
    past = 0
    for i in range(nsub):
        bc, bs = struct.unpack_from('<HH', k, osub + i * 48 + 12)
        if bs + bc > nbl:
            past += 1
    if bad_lookup or past:
        print('%s %s  m2 from %s, skin from %s: bones %d, lookups %d, lookup entries past bones %d, sections past lookups %d'
              % (race, path, mfrom, kfrom, nb, nbl, bad_lookup, past))
print('done')
