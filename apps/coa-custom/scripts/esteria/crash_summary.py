# Tonight's client crash logs side by side: address and the models the client was handling when it crashed
import glob, re, os, collections, sys
day = sys.argv[1] if len(sys.argv) > 1 else '2026-10-08'
fields = ('Last M2 Animate Name', 'Last M2 Animate MT Name', 'Last M2 Scene Render Name', 'Last M2 GetSequenceInfo',
          'Last Loaded M2 (Skin) Name')
count = collections.Counter()
for f in sorted(glob.glob(r'C:\Ascension Local\Errors\%s*Crash.txt' % day)):
    t = open(f, 'rb').read().decode('latin1')
    a = re.search(r'at 0023:([0-9A-F]+)', t)
    names = []
    for k in fields:
        m = re.search(re.escape(k) + r':\s*([^\r\n(]*)', t)
        v = m.group(1).strip() if m else ''
        names.append(v.split(chr(92))[-1])
        if v:
            count[v.lower()] += 1
    print(os.path.basename(f)[11:19], a.group(1) if a else '-', ' | '.join(names))
print()
print('models named most often:')
for k, v in count.most_common(15):
    print(' ', v, k)
