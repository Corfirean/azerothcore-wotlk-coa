# Fixes for Esteria's converted player models (WotLK M2, MD20 v264):
#  - alias_missing: sequences without their .anim file -> alias of Stand (else crash 0x006844E8)
#  - pad_tracks: bone tracks with fewer per-sequence arrays than the model has sequences get empty arrays up to the
#    sequence count (else the client reads past the track for a high sequence: crash 0x00684527, Skyborne High Order)
import struct


def alias_missing(m, has_anim):
    n, o = struct.unpack_from('<II', m, 0x1C)
    stand = next(i for i in range(n) if struct.unpack_from('<HH', m, o + i * 64) == (0, 0))
    fixed = 0
    for i in range(n):
        sid, var = struct.unpack_from('<HH', m, o + i * 64)
        if struct.unpack_from('<I', m, o + i * 64 + 12)[0] & 0x20:
            continue
        if not has_anim(sid, var):
            struct.pack_into('<I', m, o + i * 64 + 12, 0x60)
            struct.pack_into('<H', m, o + i * 64 + 62, stand)
            fixed += 1
    return fixed


def pad_tracks(m):
    nseq = struct.unpack_from('<I', m, 0x1C)[0]
    nb, ob = struct.unpack_from('<II', m, 0x2C)
    padded = 0
    for b in range(nb):
        for t in (ob + b * 88 + 0x10, ob + b * 88 + 0x24, ob + b * 88 + 0x38):     # translation, rotation, scale
            global_seq, = struct.unpack_from('<h', m, t + 2)
            nts, ots, nk, okey = struct.unpack_from('<IIII', m, t + 4)
            if global_seq >= 0 or not (0 < nts < nseq):
                continue
            for count_at, offset_at, have, at in ((t + 4, t + 8, nts, ots), (t + 12, t + 16, nk, okey)):
                table = bytes(m[at:at + have * 8]) + bytes((nseq - have) * 8)
                m.extend(bytes(-len(m) % 16))
                new = len(m)
                m.extend(table)
                struct.pack_into('<II', m, count_at, nseq, new)
            padded += 1
    return padded
