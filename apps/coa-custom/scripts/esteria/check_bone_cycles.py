# Bone parent chains of client models: a parent loop (or a parent past the bone list) makes the client spin forever
# walking up the chain (hang at 0x0083DC22) or read past the bones (crash 0x008204AE).
import sys, glob, struct, tempfile, os
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


def check(path):
    path = path.replace('/', B)
    owner = [h for h in handles if S.SFileHasFile(h, path.encode())]
    if not owner:
        return 'not found'
    t = tempfile.mktemp()
    storm.extract(owner[-1], path, t)
    m = open(t, 'rb').read()
    if m[:4] != b'MD20':
        return 'not MD20 (%r)' % m[:4]
    nb, ob = struct.unpack_from('<II', m, 0x2C)
    parents = [struct.unpack_from('<h', m, ob + i * 88 + 8)[0] for i in range(nb)]
    bad = []
    for i in range(nb):
        seen, j = set(), i
        while j >= 0:
            if j >= nb:
                bad.append('bone %d: parent %d past %d bones' % (i, j, nb)); break
            if j in seen:
                bad.append('bone %d: parent loop' % i); break
            seen.add(j)
            j = parents[j]
    return ('%d bones, ' % nb) + ('; '.join(bad[:4]) + (' ... %d problems' % len(bad) if bad else 'ok'))


for line in open(sys.argv[1]).read().splitlines():
    if line.strip():
        race, path = line.split(' ', 1)
        result = check(path)
        if not result.endswith('ok'):
            print(race, path, '->', result)
print('done')
