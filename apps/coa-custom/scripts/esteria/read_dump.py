# Minimal reader of the client's crash minidump: registers at the crash and the bytes of the memory it saved
import sys, struct, glob
f = sys.argv[1] if len(sys.argv) > 1 else sorted(glob.glob(r'C:\Ascension Local\Errors\*Crash.dmp'))[-1]
d = open(f, 'rb').read()
sig, ver, n, rva = struct.unpack_from('<4sIII', d, 0)
streams = {}
for i in range(n):
    t, size, at = struct.unpack_from('<III', d, rva + i * 12)
    streams.setdefault(t, []).append((size, at))
mem = []
for size, at in streams.get(5, []):                      # MemoryListStream
    cnt = struct.unpack_from('<I', d, at)[0]
    for i in range(cnt):
        start, dsize, drva = struct.unpack_from('<QII', d, at + 4 + i * 16)
        mem.append((start, dsize, drva))


def read(addr, size):
    for start, dsize, drva in mem:
        if start <= addr and addr + size <= start + dsize:
            return d[drva + addr - start:drva + addr - start + size]
    return None


size, at = streams[6][0]                                 # ExceptionStream
tid, _, code, flags, rec, addr = struct.unpack_from('<IIIIQQ', d, at)
ctx_size, ctx_rva = struct.unpack_from('<II', d, at + 8 + 152)
c = d[ctx_rva:ctx_rva + ctx_size]
names = ['edi', 'esi', 'ebx', 'edx', 'ecx', 'eax', 'ebp', 'eip']
regs = dict(zip(names, struct.unpack_from('<8I', c, 0x9C)))
esp = struct.unpack_from('<I', c, 0xC4)[0]
regs['esp'] = esp
print('crash at %08X code %08X' % (regs['eip'], code))
print(' '.join('%s=%08X' % (k, v) for k, v in regs.items()))
print('saved memory ranges', len(mem))
