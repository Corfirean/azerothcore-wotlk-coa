# CoA Custom 1.5: the racials of coa_racials.py (every non-vanilla race: an active and a passive, copies of Blizzard
# racials under new ids, names, lore and icons). Run from the scratchpad after gen3.py (which writes out_Spell.dbc):
#   python gen_coa_racials.py
# Writes:
#   out_Spell.dbc                           the copies appended (client, through patch-T; the old ones removed first)
#   out_races/coa_racials.sql               the same rows in acore_world.spell_dbc (server)
#   C:/CoA-Build/core/src/server/shared/CoaCustomRacials.h   race -> spells, used by the core
#   out_races/coa_racials.lua               race id -> names and texts for the creation screen
import json, os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from coa_racials import RACIALS, SPELL_BASE, spell_ids

SPELL = 'out_Spell.dbc'
ICONS = 'C:/CoA-Build/esteria/spellicons.json'
HEADER = 'C:/CoA-Build/core/src/server/shared/CoaCustomRacials.h'
B = chr(92)
ID, ICON, NAME, NAME_MASK, RANK, DESC, DESC_MASK, TIP = 0, 133, 136, 152, 153, 170, 186, 187
FLOATS = {47, 77, 78, 79, 101, 102, 103, 119, 120, 121}
UNSIGNED = {int(x) for x in open('C:/CoA-Build/coa_racials/unsigned_columns.txt').read().split(',') if x.strip()}
STRINGS = set(range(136, 152)) | set(range(153, 169)) | set(range(170, 186)) | set(range(187, 203))
# what each template does, in plain words (the creation screen cannot resolve the client's $ variables)
EFFECT = {20549: 'Stuns nearby enemies.', 26297: 'Increases attack and casting speed for a short time.',
          20594: 'Removes poison, disease and bleed effects and reduces damage taken for a short time.',
          58984: 'Slip into the shadows, dropping out of combat.',
          20589: 'Escapes any immobilization or movement slowing effect.',
          33697: 'Increases attack power and spell power for a short time.',
          28730: 'Silences nearby enemies and restores mana.', 28880: 'Heals the target over time.',
          7744: 'Removes Charm, Fear and Sleep effects.', 59752: 'Removes all stuns and movement impairing effects.',
          20573: 'Stun effects last 15% less.', 20550: 'Base health increased by 5%.',
          20591: 'Intellect increased by 5%.', 20598: 'Spirit increased by 3%.',
          20555: 'Health regeneration increased; part of it continues in combat.',
          28878: 'Increases chance to hit with spells and attacks by 1%.', 20582: 'Increases dodge chance by 2%.',
          20551: 'Reduces Nature damage taken by 4%.', 20579: 'Reduces Shadow damage taken by 4%.',
          20592: 'Reduces Arcane damage taken by 4%.', 20596: 'Reduces Frost damage taken by 4%.',
          58985: 'Increases stealth detection.'}

d = bytearray(open(SPELL, 'rb').read())
_, n, fc, rs, ss = struct.unpack('<4s4I', d[:20])
body, strings = d[20:20 + n * rs], bytearray(d[20 + n * rs:])
rows = [list(struct.unpack_from('<%dI' % fc, body, i * rs)) for i in range(n)]
rows = [r for r in rows if not SPELL_BASE < r[ID] < SPELL_BASE + 10000]          # our older copies
by_id = {r[ID]: r for r in rows}
pool = {}


def text(o):
    return bytes(strings[o:strings.index(0, o)]).decode('utf-8', 'replace')


def add_string(s):
    if s not in pool:
        pool[s] = len(strings)
        strings.extend(s.encode('utf-8') + b'\0')
    return pool[s]


icon_ids = {}
for k, v in json.load(open(ICONS)).items():
    icon_ids.setdefault(v.split(B)[-1].lower(), int(k))

new_rows, lua, header = [], [], []
done = set()
for race, pair in sorted(RACIALS.items()):
    active_id, passive_id = spell_ids(race)
    for spell_id, (name, template, icon, lore) in zip((active_id, passive_id), pair):
        if spell_id in done:
            continue
        done.add(spell_id)
        row = list(by_id[template])
        row[ID] = spell_id
        row[ICON] = icon_ids[icon.lower()]
        row[NAME] = add_string(name)
        row[RANK] = add_string('Racial')
        row[DESC] = add_string(lore + '\n\n' + text(by_id[template][DESC]))
        row[DESC_MASK] = by_id[template][DESC_MASK] or 0xFE
        new_rows.append(row)
    lua.append('\t[%d] = {{"%s", "%s", "%s"}, {"%s", "%s", "%s"}},' % (
        race, *[x.replace('"', '\\"') for (nm, t, ic, lo) in pair for x in (nm, ic, lo + ' ' + EFFECT[t])]))
    header.append('    {%d, %d, %d},' % (race, active_id, passive_id))

rows += new_rows
rows.sort(key=lambda r: r[ID])
out = b''.join(struct.pack('<%dI' % fc, *r) for r in rows)
open(SPELL, 'wb').write(struct.pack('<4s4I', b'WDBC', len(rows), fc, rs, len(strings)) + out + bytes(strings))

# server: the same rows in spell_dbc
values = []
for r in new_rows:
    cells = []
    for i, v in enumerate(r):
        if i in STRINGS:
            s = text(v) if v else ''
            cells.append("'" + s.replace(B, B + B).replace("'", "''").replace('\n', B + 'n') + "'")
        elif i in FLOATS:
            cells.append(repr(struct.unpack('<f', struct.pack('<I', v))[0]))
        elif i in UNSIGNED:
            cells.append(str(v))
        else:
            cells.append(str(struct.unpack('<i', struct.pack('<I', v))[0]))
    values.append('(' + ','.join(cells) + ')')
ids = ','.join(str(r[ID]) for r in new_rows)
sql = ['-- CoA Custom 1.5: racials of the non-vanilla races (gen_coa_racials.py)', 'USE acore_world;',
       'DELETE FROM spell_dbc WHERE ID BETWEEN %d AND %d;' % (SPELL_BASE, SPELL_BASE + 9999),
       "DELETE FROM playercreateinfo_spell_custom WHERE Note LIKE 'racial combo:%';",
       'INSERT INTO spell_dbc VALUES\n' + ',\n'.join(values) + ';']
open('out_races/coa_racials.sql', 'w', encoding='utf-8').write('\n'.join(sql) + '\n')

open('out_races/coa_racials.lua', 'w', encoding='utf-8').write(
    'CHAR_CREATE_COA_RACIALS = {\n' + '\n'.join(lua) + '\n}\n')

open(HEADER, 'w', encoding='utf-8', newline='\n').write('''// Generated by CoA-Custom/scripts/gen_coa_racials.py from coa_racials.py: do not edit by hand.
// The racials of every non-vanilla race (12 and up): an active and a passive spell (spell_dbc / client Spell.dbc).
// They replace the racials these races had; the vanilla races 1-11 keep theirs.
#ifndef COA_CUSTOM_RACIALS_H
#define COA_CUSTOM_RACIALS_H

#include "Define.h"
#include <array>

struct CoaCustomRacial
{
    uint8 RaceId;
    uint32 ActiveSpell;
    uint32 PassiveSpell;
};

inline constexpr std::array<CoaCustomRacial, %d> CoaCustomRacials =
{{
%s
}};

inline CoaCustomRacial const* GetCoaCustomRacial(uint8 race)
{
    for (CoaCustomRacial const& racial : CoaCustomRacials)
        if (racial.RaceId == race)
            return &racial;
    return nullptr;
}

#endif
''' % (len(header), '\n'.join(header)))
print('%d racial spells for %d races: out_Spell.dbc, coa_racials.sql, coa_racials.lua, CoaCustomRacials.h'
      % (len(new_rows), len(header)))
