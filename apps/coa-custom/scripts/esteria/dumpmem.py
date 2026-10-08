# Memory reader for full minidumps (Memory64ListStream)
import struct, mmap


class Dump:
    def __init__(self, path):
        self.f = open(path, 'rb')
        self.d = mmap.mmap(self.f.fileno(), 0, access=mmap.ACCESS_READ)
        sig, ver, n, rva = struct.unpack_from('<4sIII', self.d, 0)
        st = {}
        for i in range(n):
            t, size, at = struct.unpack_from('<III', self.d, rva + i * 12)
            st.setdefault(t, []).append((size, at))
        size, at = st[9][0]
        cnt, off = struct.unpack_from('<QQ', self.d, at)
        self.segs = []
        for i in range(cnt):
            s, sz = struct.unpack_from('<QQ', self.d, at + 16 + i * 16)
            self.segs.append((s, sz, off))
            off += sz
        self.segs.sort()

    def read(self, a, n):
        for s, sz, o in self.segs:
            if s <= a and a + n <= s + sz:
                return bytes(self.d[o + a - s:o + a - s + n])
        return None

    def u32(self, a):
        b = self.read(a, 4)
        return struct.unpack('<I', b)[0] if b else None
