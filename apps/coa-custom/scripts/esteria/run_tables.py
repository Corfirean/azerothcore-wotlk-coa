# Run Esteria's own race table builders (EsteriaWoW/tools/*_race_pack.py tables()) against our client tables and
# keep only that race's rows, as source tables for gen_eunoia.py (which copies them to our race ids 66+).
#   python run_tables.py <earthen|haranir|highmountain|vulpera|...>
import sys, os, struct, inspect, textwrap
from pathlib import Path
G = 'C:/Users/ilusi/Downloads/Esteria-RaceGuide-2026-10-03/RaceGuide/sources/'
sys.path[:0] = [G + 'EsteriaWoW/tools', G + 'Converter']
import retroported_race_pack as p
race = sys.argv[1]
OURS = ('C:/Users/ilusi/AppData/Local/Temp/claude/C--Program-Files--x86--Steam-steamapps-common-Assassin-s-Creed-'
        'Black-Flag-Resynced/d6f2176a-cfae-45f1-878b-a98d1307c3f6/scratchpad/bak_skyborne/out_races/')
EMPTY = {'CharSections', 'CharHairGeosets', 'CharacterFacialHairStyles', 'CharHairTextures'}
FREE = {20} | set(range(45, 64))          # Esteria's ids: ours there are other races
SKY = 'C:/CoA-Build/esteria/skyborne_dbc/'


def read(storm, archive, name):
    n = name.split(chr(92))[-1][:-4]
    path = OURS + n + '.dbc' if os.path.exists(OURS + n + '.dbc') else SKY + n + '.dbc'
    data = open(path, 'rb').read()
    c, f, rs, ss = struct.unpack_from('<4I', data, 4)
    if n in EMPTY:
        return struct.pack('<4s4I', b'WDBC', 0, f, rs, 1) + b'\0'
    if n == 'ChrRaces':
        keep = [data[20 + i * rs:20 + (i + 1) * rs] for i in range(c)
                if struct.unpack_from('<I', data, 20 + i * rs)[0] not in FREE]
        return struct.pack('<4s4I', b'WDBC', len(keep), f, rs, ss) + b''.join(keep) + data[20 + c * rs:]
    return data


p._read_archive_entry = read
p.Storm = lambda *a, **k: None
# outfits and names are copied from a template race by gen_eunoia: Esteria's steps for them are skipped
p._build_char_start_outfit = lambda data, *a, **k: data
p._clone_namegen = lambda data, *a, **k: data
_clone = p._clone_race_rows


def clone(table_name, data, *a, **k):      # CharHairTextures is not used by our client
    return data if table_name == 'CharHairTextures' else _clone(table_name, data, *a, **k)


p._clone_race_rows = clone
MODULES = {'highmountain': 'highmountain_integration'}
root = Path('C:/Users/ilusi/Downloads/RetroPorterWork/' + race)
for name in (race + '_race_pack', MODULES.get(race, race + '_race_pack')):
    mod = __import__(name)
    mod.ROOT, mod.SOURCE, mod.ART = root, root / 'output/patch-root', root / 'integration/patch-root'
    mod.STAGE = Path('C:/CoA-Build/esteria/stage_' + race)
lines = textwrap.dedent(inspect.getsource(mod.tables)).split('\n')
out_lines, skip = [], False
for line in lines:
    if line.startswith('    for name in ("CharStartOutfit", "NameGen"):'):
        skip = True
        continue
    if skip and (line.startswith('        ') or not line.strip()):
        continue
    skip = False
    out_lines.append(line)
exec(compile('\n' * (mod.tables.__code__.co_firstlineno - 1) + '\n'.join(out_lines), mod.__file__, 'exec'), mod.__dict__)
result = mod.tables()
out = Path('C:/CoA-Build/esteria/tables/' + race)
out.mkdir(parents=True, exist_ok=True)
for name, data in result.items():
    (out / (name + '.dbc')).write_bytes(data)
    print(name, struct.unpack_from('<I', data, 4)[0], 'records')
