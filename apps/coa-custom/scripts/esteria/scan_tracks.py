# Bone animation tracks of client models whose per-sequence arrays are fewer than the model's sequences (and not a
# global-sequence track): the client reads past them when it plays a later sequence
import sys, glob, struct, tempfile
sys.path.insert(0, 'C:/CoA-Build/eunoia')
import storm
S = storm.S
B = chr(92)
D = 'C:/Ascension Local/Data/'
handles = []
for a in sorted(glob.glob(D + '*.MPQ') + glob.glob(D + '*/*.MPQ') + glob.glob(D + '*.mpq')):
    try:
        handles.append(storm.open_mpq(a))
    except Exception:
        pass
for m2 in sys.argv[1:]:
    m2 = m2.replace('/', B)
    owner = [h for h in handles if S.SFileHasFile(h, m2.encode())]
    if not owner:
        print(m2, 'not found'); continue
    t = tempfile.mktemp(); storm.extract(owner[-1], m2, t); m = open(t, 'rb').read()
    nseq = struct.unpack_from('<I', m, 0x1C)[0]
    nb, ob = struct.unpack_from('<II', m, 0x2C)
    short, oob, maxbone = 0, 0, 0
    for b in range(nb):
        for tr in (ob + b * 88 + 0x10, ob + b * 88 + 0x24, ob + b * 88 + 0x38):
            gs, = struct.unpack_from('<h', m, tr + 2)
            nts, ots, nk, ok = struct.unpack_from('<IIII', m, tr + 4)
            if gs < 0 and 0 < nts < nseq:
                short += 1
            if ots + nts * 8 > len(m) or ok + nk * 8 > len(m):
                oob += 1
        parent, = struct.unpack_from('<h', m, ob + b * 88 + 8)
        if parent >= nb:
            maxbone += 1
    nlk, olk = struct.unpack_from('<II', m, 0x34)
    badlk = sum(1 for i in range(nlk) if struct.unpack_from('<h', m, olk + i * 2)[0] >= nseq)
    print('%s seqs %d bones %d | short tracks %d, tracks out of file %d, bad parents %d, anim lookups >= seqs %d'
          % (m2, nseq, nb, short, oob, maxbone, badlk))
