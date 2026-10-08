# Races from the Eunoia client (by Furioz, Corruption and Eunoia, used with permission), merged into the generated
# race tables of gen_races.py. Run from the scratchpad after gen_races.py and gen_race_looks.py, before build.py:
#     python gen_eunoia.py     -> rewrites out_races\*.dbc in place, writes out_races\eunoia.sql
# The Eunoia tables and files come from C:\CoA-Build\eunoia (dbc\ and files\, extracted with StormLib).
#
# Race ids only have 32 bits in every race mask (skills, racials, quests, factions...). Ids above 32 wrap around:
# both the client and the server build the mask as 1 << (race - 1), and x86 keeps only the low 5 bits of the shift,
# so race 68 uses the bit of race 4. Each new race above 32 shares the bit of a race of its own faction (MASK_TWIN):
# same skills, racials and reputations; its look, name, faction and start come from its own rows.
import struct

EU = 'C:/CoA-Build/eunoia/dbc/'
OUT = 'out_races/'
A, H = 'A', 'H'
# our id: (Eunoia id, faction, name, look twin (camera, names, emote sounds, creation previews), stats race)
RACES = {
    20: (22, H, 'Pandaren', 20, 6),               # replaces our Pandaren (Horde)
    29: (26, A, 'Pandaren', 20, 6),               # replaces our Pandaren (Alliance): own "Pandaren_A" files
    22: (23, A, 'Broken', 11, 11),                # replaces our Broken
    27: (30, A, 'Dracthyr', 10, 10),              # Earthen's slot
    62: (15, A, 'Void Elf', 10, 10),              # mask of 1 (Human)
    61: (24, A, 'Illidari Night Elf', 4, 4),      # mask of 13 (Worgen)
    48: (29, A, 'Dark Iron Dwarf', 3, 3),         # mask of 16 (Kul Tiran)
    54: (20, A, 'Lightforged Draenei', 11, 11),   # mask of 22 (Broken)
    49: (16, H, 'Eredar', 11, 2),                 # mask of 17 (Taunka)
    51: (27, H, 'Illidari Blood Elf', 10, 10),    # mask of 19 (Vulpera)
    53: (13, H, 'Nightborne', 4, 10),             # mask of 21 (Naga)
    55: (19, H, 'Ogre', 2, 2),                    # mask of 23 (Fel Orc)
    56: (17, H, 'Dracthyr', 10, 10),              # mask of 24 (Forest Troll)
}
# The client keeps some per-race data in arrays of 64: a race id above 63 crashed the creation screen as soon as it
# was clicked (0x004F3C22, Dark Iron Dwarf at 67, Illidari Night Elf at 68). Ids 33-63 are Ascension's NPC races; the
# ones used here are free (47-50, 59) or used by no creature display (CreatureDisplayInfoExtra) of the client.
# Eunoia races removed 2026-10-06, permission given again 2026-10-07 by the creator: the ones we have no other
# version of come back on the last free ids (their old ids now hold Medviten's / our own races)
EUNOIA_RACES = RACES
RACES = {
    20: (22, H, 'Pandaren', 20, 6),               # replaces our Pandaren (Horde) (2026-10-07)
    29: (26, A, 'Pandaren', 20, 6),               # replaces our Pandaren (Alliance): own "Pandaren_A" files
    22: (23, A, 'Broken', 11, 11),               # replaces our Broken (2026-10-07)
    55: (16, H, 'Eredar', 11, 2),                # replaces the creature-model Eredar (2026-10-07)
    54: (30, A, 'Dracthyr', 10, 10),              # ids > 32 share a race-mask bit with id - 32: an Alliance race
    58: (17, H, 'Dracthyr', 10, 10),
    59: (15, A, 'Void Elf', 10, 10),
    61: (24, A, 'Illidari Night Elf', 4, 4),      # needs an Alliance twin (54->22 Broken, 61->29 Pandaren A,
    60: (27, H, 'Illidari Blood Elf', 10, 10),    # 60->28 Drakkari): 52/60/61 made them hostile to their faction
    62: (20, A, 'Lightforged Draenei', 11, 11),
    63: (13, H, 'Nightborne', 4, 10),
}
REPLACED = [r for r in RACES if r <= 31]
NEW = [r for r in RACES if r > 31]
FACTION = {A: (1, 0, 7), H: (2, 1, 1)}          # faction template, alliance field, base language
TEMPLATE = {A: 1, H: 2}                         # Human / Orc: start, items, action bars (as gen_races.py)
# races cloned from Ascension's NPC races (male-only): their HD rows (copied by gen_races.py) crashed the creation
# screen with complete normal rows (Ice Troll, Forest Troll: 0x004EA77F); they keep the normal textures only
# helmet model prefix: Eunoia's "Pa" (Pandaren, Ogre) has no helmet for Ascension's CoA items (blue cube); a base
# race prefix has them all. Our earlier Pandaren used "Dw".
PREFIX = {20: 'Dw', 29: 'Dw', 55: 'Ta'}
NO_HD = ()   # was (15, 17, 18, 23, 24, 25, 26): the real cause was the HD row IDs (below)
NO_DK = 6                                       # the Death Knight class is not offered at creation any more


def twin_bit(race):
    return ((race - 1) & 31) + 1


class DBC:
    def __init__(self, path, packed=False):
        d = open(path, 'rb').read()
        _, self.n, self.fc, self.rs, ss = struct.unpack('<4s4I', d[:20])
        self.packed = packed
        body = d[20:20 + self.n * self.rs]
        self.sb = bytearray(d[20 + self.n * self.rs:])
        if packed:
            self.raw = [bytearray(body[i * self.rs:(i + 1) * self.rs]) for i in range(self.n)]
        else:
            w = self.rs // 4
            self.rows = [list(struct.unpack_from('<%dI' % w, body, i * self.rs)) for i in range(self.n)]
        self.cache = {}

    def s(self, off):
        return self.sb[off:self.sb.index(0, off)].decode('utf-8', 'replace') if 0 < off < len(self.sb) else ''

    def string(self, text):
        # an empty string must point at a NUL byte: Ascension's string blocks do not start with one, offset 0 is
        # "Character\Human\Male\HumanMaleSkin00_00.blp" in CharSections, so every empty texture slot loaded the
        # Human male skin and painted it over faces, chests and pelvises of the imported races
        if text not in self.cache:
            self.cache[text] = len(self.sb)
            self.sb.extend(text.encode('utf-8') + b'\0')
        return self.cache[text]

    def save(self, path):
        if self.packed:
            body = b''.join(bytes(r) for r in self.raw)
            n = len(self.raw)
        else:
            body = b''.join(struct.pack('<%dI' % len(r), *[v & 0xFFFFFFFF for v in r]) for r in self.rows)
            n = len(self.rows)
        open(path, 'wb').write(struct.pack('<4s4I', b'WDBC', n, self.fc, self.rs, len(self.sb)) + body + bytes(self.sb))
        print('%-36s %8d records' % (path.split('/')[-1], n))


def copy_strings(src, dst, row, fields):
    for k in fields:
        text = src.s(row[k])
        if 'jinyu' in text.lower():                          # Eunoia's Ogre underwear: a transparent Jinyu texture
            text = chr(92).join(['Character', 'CoACustom', 'BlankFaceLower.blp'])   # not in their archives: transparent
        row[k] = dst.string(text)


# ---------------------------------------------------------------- displays and models
eu_cdi, eu_cmd = DBC(EU + 'CreatureDisplayInfo.dbc'), DBC(EU + 'CreatureModelData.dbc')
cdi, cmd = DBC(OUT + 'CreatureDisplayInfo.dbc'), DBC(OUT + 'CreatureModelData.dbc')
EU_CDI = {r[0]: r for r in eu_cdi.rows}
EU_CMD = {r[0]: r for r in eu_cmd.rows}
CDI = {r[0]: r for r in cdi.rows}
CMD = {r[0]: r for r in cmd.rows}
next_cdi, next_cmd = max(CDI) + 1, max(CMD) + 1
eu_races = DBC(EU + 'ChrRaces.dbc')
EU_RACE = {r[0]: r for r in eu_races.rows}
model_ids, display_ids = {}, {}                  # their model / display -> ours
for rid, (eid, side, name, look, stats) in RACES.items():
    for sex in (0, 1):
        their = EU_RACE[eid][4 + sex]
        if their in display_ids:
            continue
        d = list(EU_CDI[their])
        if d[1] not in model_ids:
            m = list(EU_CMD[d[1]])
            m[0] = next_cmd
            copy_strings(eu_cmd, cmd, m, [2])
            model_ids[d[1]] = next_cmd
            cmd.rows.append(m)
            next_cmd += 1
        d[0], d[1] = next_cdi, model_ids[d[1]]
        copy_strings(eu_cdi, cdi, d, [6, 7, 8, 9])
        d[2] = d[3] = d[12] = d[13] = d[14] = d[15] = 0          # sounds, extra, particle colours: theirs are not ours
        display_ids[their] = next_cdi
        cdi.rows.append(d)
        next_cdi += 1
cdi.save(OUT + 'CreatureDisplayInfo.dbc')
cmd.save(OUT + 'CreatureModelData.dbc')

# ---------------------------------------------------------------- ChrRaces (server and client copies)
for name in ('ChrRaces.dbc', 'client_ChrRaces.dbc'):
    t = DBC(OUT + name)
    by = {r[0]: r for r in t.rows}
    for rid, (eid, side, rname, look, stats) in RACES.items():
        base = list(by.get(look) or by[TEMPLATE[side]])
        e = EU_RACE[eid]
        base[0] = rid
        base[1] = 0xC                                            # playable
        base[2], base[13], base[7] = FACTION[side]
        base[4], base[5] = display_ids[e[4]], display_ids[e[5]]
        base[6] = t.string(PREFIX.get(rid, eu_races.s(e[6])))   # client prefix (helmet models)
        base[11] = t.string(eu_races.s(e[11]))                  # file name: texture folders
        base[12] = 0                                             # no intro cinematic
        for k in list(range(14, 30)) + list(range(31, 47)) + list(range(48, 64)):
            base[k] = t.string('')                                          # names (all, female, male), every locale; the
        for k in (14, 31, 48):                                   # locale flag fields 30 / 47 / 64 stay the twin's
            base[k] = t.string(rname)
        for k in (65, 66, 67):
            base[k] = t.string(eu_races.s(e[k]))
        base[68] = 0
        if rid in by:
            t.rows[t.rows.index(by[rid])] = base
        else:
            t.rows.append(base)
    t.rows.sort(key=lambda r: r[0])
    t.save(OUT + name)

# ---------------------------------------------------------------- appearance tables (rows of their race, renumbered)
import os as _os
EU_FILES = 'C:/CoA-Build/eunoia/files/'
# switches of the 00:12 texture build (login crash investigation)
BLANK_HD = (chr(92).join(['Character', 'CoACustom', 'BlankFaceLower.blp']), chr(92).join(['Character', 'CoACustom', 'BlankFaceUpper.blp']))
BLANK_SD = (chr(92).join(['Character', 'CoACustom', 'BlankFaceLowerSD.blp']), chr(92).join(['Character', 'CoACustom', 'BlankFaceUpperSD.blp']))
# faces of the imported races: cut from their own skin texture (make_faces.py), so they always match the skin
FACE_PATH = chr(92).join(['Character', 'CoACustom', 'Face', '%d_%d_%d_%s.blp'])
# No flag 8 (pre-composited skin) for any imported race: with it the client skips the face and underwear loaders
# WITHOUT releasing the previous character's textures (exe 0x4EA4C8 -> 0x4EA581), so the Human face of the default
# creation race stayed painted over every new race's head. Classic overlays: faces cut from the race's own skin.
PRECOMPOSED = ()
SKIP_MISSING, FACE_BLANK, HD_EXTRA = True, True, ()   # not 47, 57, 59: in HD they crashed the creation screen (0x004F3C22, 0x004F3BDB)
EU_HAVE = {_os.path.relpath(_os.path.join(r, n), EU_FILES).replace(_os.sep, chr(92)).lower()
           for r, _d, ns in _os.walk(EU_FILES) for n in ns}


def merge_rows(name, race_field, id_field=0, strings=()):
    ours, theirs = DBC(OUT + name), DBC(EU + name)
    ours.rows = [r for r in ours.rows if r[race_field] not in RACES]
    next_id = max(r[id_field] for r in ours.rows) + 1 if id_field is not None else None
    for rid, (eid, *_rest) in RACES.items():
        for r in theirs.rows:
            if r[race_field] != eid:
                continue
            nr = list(r)
            nr[race_field] = rid
            if id_field is not None:
                nr[id_field] = next_id
                next_id += 1
            copy_strings(theirs, ours, nr, strings)
            if name == 'CharSections.dbc':                      # Death Knight-only skins (flag 4) are skipped by
                nr[7] = (nr[7] | 1) & ~4                         # the client for other classes: holes (Illidari NE)
                skin = theirs.s(r[4]).lower()
                if SKIP_MISSING and r[3] == 0 and skin.startswith('character') and skin not in EU_HAVE:
                    continue                                     # skin texture not in Eunoia's files (Illidari NE _19)
                if FACE_BLANK and r[3] == 1:                     # Eunoia's skins already carry the face: an overlay of
                    nr[4], nr[5], nr[6] = ours.string(FACE_PATH % (rid, r[2], r[9], 'L')), ours.string(FACE_PATH % (rid, r[2], r[9], 'U')), ours.string('')
                                                                 # showed as a mask; an empty row crashed: transparent
            ours.rows.append(nr)
    ours.save(OUT + name)


merge_rows('CharSections.dbc', 1, 0, (4, 5, 6))
merge_rows('CharHairGeosets.dbc', 1, 0)
merge_rows('CharacterFacialHairStyles.dbc', 0, None)
hd = DBC(OUT + 'HDCharSections.dbc')                             # our HD overrides of the replaced races go
hd.rows = [r for r in hd.rows if r[1] not in RACES and r[1] not in NO_HD]
hd.save(OUT + 'HDCharSections.dbc')


# ---------------------------------------------------------------- rows copied from the look twin (new races only)
def copy_twin(name, race_field, id_field=0):
    t = DBC(OUT + name)
    t.rows = [r for r in t.rows if r[race_field] not in NEW]
    next_id = max(r[id_field] for r in t.rows) + 1
    for rid in NEW:
        look = RACES[rid][3]
        for r in [r for r in t.rows if r[race_field] == look]:
            nr = list(r)
            nr[race_field], nr[id_field] = rid, next_id
            next_id += 1
            t.rows.append(nr)
    t.save(OUT + name)


copy_twin('UICameraAppearanceChrRaces.dbc', 1)
copy_twin('NameGen.dbc', 2)
copy_twin('EmotesTextSound.dbc', 2)
for n in ('ClassDetails', 'ArchetypeDetails', 'ShapeshiftDetails'):
    copy_twin('CharacterCreation%s.dbc' % n, 2)

# CharStartOutfit (byte-packed race, class, sex, outfit): the new races wear their faction template's outfits
so = DBC(OUT + 'CharStartOutfit.dbc', packed=True)
so.raw = [r for r in so.raw if r[4] not in NEW]
next_id = max(struct.unpack_from('<I', r)[0] for r in so.raw) + 1
for rid in NEW:
    for r in [r for r in so.raw if r[4] == TEMPLATE[RACES[rid][1]]]:
        nr = bytearray(r)
        struct.pack_into('<I', nr, 0, next_id)
        nr[4] = rid
        next_id += 1
        so.raw.append(nr)
so.save(OUT + 'CharStartOutfit.dbc')

# CharBaseInfo (race, class bytes): the classes of the Human for every new race; no Death Knight for anyone
c = open(OUT + 'CharBaseInfo.dbc', 'rb').read()
pairs = [(c[20 + i * 2], c[21 + i * 2]) for i in range(struct.unpack('<I', c[4:8])[0])]
human = [cl for r, cl in pairs if r == 1]
pairs = [p for p in pairs if p[0] not in NEW] + [(rid, cl) for rid in NEW for cl in human]
pairs = [p for p in pairs if p[1] != NO_DK]
open(OUT + 'CharBaseInfo.dbc', 'wb').write(struct.pack('<4s4I', b'WDBC', len(pairs), 2, 2, 0) + b''.join(bytes(p) for p in pairs))
print('%-36s %8d records' % ('CharBaseInfo.dbc', len(pairs)))

# ---------------------------------------------------------------- world database
ids = ','.join(str(r) for r in NEW + [66, 67, 68, 74, 75, 78, 98, 106, 138, 33, 45, 59])   # + the first ids (above 63)
sql = ['USE acore_world;', 'START TRANSACTION;']
for table, col in (('playercreateinfo', 'race'), ('playercreateinfo_item', 'race'), ('playercreateinfo_action', 'race'),
                   ('player_race_stats', 'Race'), ('ascension_custom_class_race', 'race')):
    sql.append('DELETE FROM %s WHERE %s IN (%s);' % (table, col, ids))
for rid in NEW:
    eid, side, name, look, stats = RACES[rid]
    tpl = TEMPLATE[side]
    sql.append('INSERT INTO playercreateinfo SELECT %d,class,map,zone,position_x,position_y,position_z,orientation FROM playercreateinfo WHERE race=%d;' % (rid, tpl))
    sql.append('INSERT INTO playercreateinfo_item SELECT %d,class,itemid,amount,Note FROM playercreateinfo_item WHERE race=%d;' % (rid, tpl))
    sql.append('INSERT INTO playercreateinfo_action SELECT %d,class,button,action,type FROM playercreateinfo_action WHERE race=%d;' % (rid, tpl))
    sql.append('INSERT INTO player_race_stats SELECT %d,Strength,Agility,Stamina,Intellect,Spirit FROM player_race_stats WHERE Race=%d;' % (rid, stats))
    sql.append('INSERT INTO ascension_custom_class_race SELECT DISTINCT class,%d FROM ascension_custom_class_race;' % rid)
# model size and gender of the new displays: the look twin's (the Human's when it has none)
for (eid_disp, new_disp) in display_ids.items():
    sex = next(s for rid, (eid, *_r) in RACES.items() for s in (0, 1) if EU_RACE[eid][4 + s] == eid_disp)
    look = next(look for rid, (eid, _s, _n, look, _st) in RACES.items() if eid_disp in EU_RACE[eid][4:6])
    twin_disp = next(r[4 + sex] for r in DBC(OUT + 'ChrRaces.dbc').rows if r[0] == look)
    sql.append('DELETE FROM creature_model_info WHERE DisplayID=%d;' % new_disp)
    sql.append('INSERT INTO creature_model_info (DisplayID,BoundingRadius,CombatReach,Gender,DisplayID_Other_Gender) '
               'SELECT %d,BoundingRadius,CombatReach,%d,0 FROM creature_model_info WHERE DisplayID IN (%d,%d) ORDER BY DisplayID=%d DESC LIMIT 1;'
               % (new_disp, sex, twin_disp, 49 + sex, twin_disp))
sql.append('COMMIT;')
open(OUT + 'eunoia.sql', 'w').write('\n'.join(sql) + '\n')
print('eunoia.sql: %d statements; new race ids %s (mask twins %s)' % (len(sql), NEW, {r: twin_bit(r) for r in NEW}))


# ---------------------------------------------------------------- Naga (21): Sirus's HD player Naga (open source)
# Character/NagaSirusHD (Snaga_male, Snaga_Female): player models with 199 / 153 animations and the cape and hair
# texture slots; their appearance rows are Sirus's race 13. Files in patch-ZE5.MPQ.
SIRUS = 'C:/Users/ilusi/Downloads/Naga_Extract_2026-10-03/Naga_Extract_2026-10-03/Race13LinkedTables/ByArchive/ruRU/patch-ruRU-4.mpq/DBFilesClient/'
NAGA, SIRUS_NAGA = 21, 13
BSL = chr(92)
NAGA_MODELS = (BSL.join(['Character', 'NagaSirusHD', 'Male', 'Snaga_male.mdx']),
               BSL.join(['Character', 'NagaSirusHD', 'female', 'Snaga_Female.mdx']))


def merge_sirus(name, race_field, id_field=0, strings=()):
    ours, theirs = DBC(OUT + name), DBC(SIRUS + name)
    ours.rows = [r for r in ours.rows if r[race_field] != NAGA]
    next_id = max(r[id_field] for r in ours.rows) + 1 if id_field is not None else None
    for r in theirs.rows:
        if r[race_field] != SIRUS_NAGA:
            continue
        nr = list(r)
        nr[race_field] = NAGA
        if id_field is not None:
            nr[id_field] = next_id
            next_id += 1
        copy_strings(theirs, ours, nr, strings)
        ours.rows.append(nr)
    ours.save(OUT + name)


merge_sirus('CharSections.dbc', 1, 0, (4, 5, 6))
merge_sirus('CharHairGeosets.dbc', 1, 0)
merge_sirus('CharacterFacialHairStyles.dbc', 0, None)
cdi, cmd = DBC(OUT + 'CreatureDisplayInfo.dbc'), DBC(OUT + 'CreatureModelData.dbc')
CDI = {r[0]: r for r in cdi.rows}
CMD = {r[0]: r for r in cmd.rows}
naga_displays = []
for name in ('ChrRaces.dbc', 'client_ChrRaces.dbc'):
    t = DBC(OUT + name)
    row = next(r for r in t.rows if r[0] == NAGA)
    if not naga_displays:                                    # new display + model for each sex, from our old ones
        for sex in (0, 1):
            old = CDI[row[4 + sex]]
            m = list(CMD[old[1]])
            m[0] = max(CMD) + 1
            m[2] = cmd.string(NAGA_MODELS[sex])
            CMD[m[0]] = m
            cmd.rows.append(m)
            d = list(old)
            d[0], d[1] = max(CDI) + 1, m[0]
            d[6] = d[7] = d[8] = 0                           # textures come from CharSections
            CDI[d[0]] = d
            cdi.rows.append(d)
            naga_displays.append((d[0], old[0], sex))
    row[4], row[5] = naga_displays[0][0], naga_displays[1][0]
    t.save(OUT + name)
cdi.save(OUT + 'CreatureDisplayInfo.dbc')
cmd.save(OUT + 'CreatureModelData.dbc')
sql = open(OUT + 'eunoia.sql').read().replace('COMMIT;\n', '')
for new, old, sex in naga_displays:
    sql += 'DELETE FROM creature_model_info WHERE DisplayID=%d;\n' % new
    sql += ('INSERT INTO creature_model_info (DisplayID,BoundingRadius,CombatReach,Gender,DisplayID_Other_Gender) '
            'SELECT %d,BoundingRadius,CombatReach,%d,0 FROM creature_model_info WHERE DisplayID=%d;\n' % (new, sex, old))
open(OUT + 'eunoia.sql', 'w').write(sql + 'COMMIT;\n')
print('Naga: Sirus rows and displays %s' % naga_displays)


# ---------------------------------------------------------------- more races from other open sources
# Alpha Worgen and Alpha Goblin (alpha models, with their own textures moved to Character/WorgenA and GoblinA so they
# do not replace ours), Furbolg (Project Reforged). Files in patch-ZE6.MPQ. Same id rule as the Eunoia races: ids
# <= 63, each sharing the race-mask bit of a race of its own faction.
WORGEN_SRC = 'C:/Users/ilusi/Downloads/worgen/New folder (4)/DBFilesClient/'
THIN_SRC = 'C:/CoA-Build/esteria/thin_dbc/'        # Esteria's Thin Human (Kalibros), tables from make_thin_dbc.py
FURBOLG_SRC = 'C:/Users/ilusi/Downloads/Playable_Races_Isolated_2026-10-04/Playable_Races_Isolated_2026-10-04/ReadyToPort/Shared/DBFilesClient/'
BS = chr(92)
P = lambda *parts: BS.join(parts)
# Medviten/mod-worgoblin-high-elf (AGPL-3.0): Mag'har Orc, Ogre, Dark Iron Dwarf
CREATURE_SRC = 'C:/CoA-Build/creatures/dbc/'
MOD_SRC = 'C:/CoA-Build/mod-worgoblin-high-elf/data/patch-A.MPQ/DBFilesClient/'
# Esteria's Skyborne (Kalibros | Lord of Wen), RetroPorter build: tables of its latest stage
SKY_SRC = 'C:/CoA-Build/esteria/skyborne_dbc/'   # its server tables + the hair tables of its client patch-Z
MECHA_SRC = 'C:/CoA-Build/esteria/mechagnome_dbc/'   # C:/CoA-Build/esteria/make_mechagnome_dbc.py (Esteria's encoding, race 47)
ESTERIA_TABLES = 'C:/CoA-Build/esteria/tables/'   # C:/CoA-Build/esteria/run_tables.py: Esteria's own builders
EXTRA = {
    # our id: source tables, source race, faction, name, look twin, stats race, models (male, female), file name,
    #         helmet prefix, texture folder moved (from, to)
    # look twin Human: Worgen (13) has a worgen/human form switch at creation
    47: (WORGEN_SRC, 12, A, 'Alpha Worgen', 1, 13, (P('Character', 'WorgenA', 'Male', 'WorgenMale.mdx'),
         P('Character', 'WorgenA', 'Female', 'WorgenFemale.mdx')), 'WorgenA', None,
         (P('character', 'worgen', ''), P('Character', 'WorgenA', ''))),
    57: (WORGEN_SRC, 9, H, 'Alpha Goblin', 9, 9, (P('Character', 'GoblinA', 'Male', 'GoblinMale.mdx'),
         P('Character', 'GoblinA', 'Female', 'GoblinFemale.mdx')), 'GoblinA', None,
         (P('character', 'goblin', ''), P('Character', 'GoblinA', ''))),
    # the "native" model: all animations inside (the converted one needed 54 .anim files, 6 missing: crash 0x00684527)
    32: (THIN_SRC, 99, A, 'Thin Human', 1, 1, (P('custom', 'thinhuman', 'native', 'male', 'thinhumanmale.mdx'),
         P('custom', 'thinhuman', 'native', 'male', 'thinhumanmale.mdx')), 'ThinHuman', None, None),
    48: (MOD_SRC, 16, A, 'Dark Iron Dwarf', 3, 3, (P('Character', 'Darkirondwarf', 'male', 'darkirondwarfMale.mdx'),
         P('Character', 'Darkirondwarf', 'female', 'darkirondwarfFemale.mdx')), 'DarkIronDwarf', None, None),
    49: (MOD_SRC, 14, H, "Mag'har Orc", 2, 2, (P('Character', 'Orc', 'Male', 'OrcMale.mdx'),
         P('Character', 'Orc', 'Female', 'OrcFemale.mdx')), 'Maghar', None, None),
    53: (MOD_SRC, 15, H, 'Ogre', 2, 2, (P('Character', 'Ogre', 'Male', 'OgrePC.mdx'),
         P('Character', 'Ogre', 'Female', 'OgreMagePC.mdx')), 'Ogre', None, None),
    # our own: Undead Gnome = the Gnome model with recoloured undead skins (CoA-Build/undeadgnome/make_undead.py)
    51: (OUT, 7, H, 'Undead Gnome', 7, 5, (P('Character', 'Gnome', 'Male', 'GnomeMale.mdx'),
         P('Character', 'Gnome', 'Female', 'GnomeFemale.mdx')), 'GnomeUndead', 'Gn', None),
    # creature models made playable (C:/CoA-Build/creatures/make_creature_races.py): Vampyr, Eredar, Harpy
    # 54 Vampyr and 55 creature Eredar removed 2026-10-07 (Eredar is Eunoia's again)
    56: (CREATURE_SRC, 56, H, 'Harpy', 10, 4, (P('Character', 'Harpy', 'Male', 'HarpyMale.mdx'),
         P('Character', 'Harpy', 'Female', 'HarpyFemale.mdx')), 'Harpy', None, None),
    # test of race ids above 63 (128-race client patch): a copy of the Human; twin bit = Human (Alliance)
    65: (OUT, 1, A, 'Test Race', 1, 1, (P('Character', 'Human', 'Male', 'HumanMale.mdx'),
         P('Character', 'Human', 'Female', 'HumanFemale.mdx')), 'TestRace', 'Hu', None),
    50: (FURBOLG_SRC, 18, A, 'Furbolg', 6, 6, (P('Character', 'Furbolg', 'FurbolgRace.mdx'),
         P('Character', 'Furbolg', 'FurbolgRace.mdx')), 'ReforgedFurbolg', 'Ta', None),
    # Esteria races on 66+ (EsteriaAppearance.dll translates them back to Esteria's ids); a mask twin of the same faction
    72: (SKY_SRC, 53, H, 'Windshaper Skyborne', 10, 10, (P('custom', 'skyborne', 'runtime', 'male', '7478487.m2'),
         P('custom', 'skyborne', 'runtime', 'female', '7478494.m2')), 'SkyborneHorde', None, None),
    77: (SKY_SRC, 52, A, 'High Order Skyborne', 10, 10, (P('custom', 'skyborne', 'runtime', 'male', '7478487.m2'),
         P('custom', 'skyborne', 'runtime', 'female', '7478494.m2')), 'Skyborne', None, None),
    67: (MECHA_SRC, 47, A, 'Mechagnome', 7, 7, (P('custom', 'mechagnome', 'native', 'male', 'mechagnomemale.m2'),
         P('custom', 'mechagnome', 'native', 'female', 'mechagnomefemale.m2')), 'Mechagnome', None, None),
    66: (ESTERIA_TABLES + 'highmountain/', 46, H, 'Highmountain Tauren', 6, 6, (P('custom', 'highmountain', 'native', 'male', 'highmountaintaurenmale.m2'),
         P('custom', 'highmountain', 'native', 'female', 'highmountaintaurenfemale.m2')), 'HighmountainTauren', None, None),
    68: (ESTERIA_TABLES + 'earthen/', 48, A, 'Earthen', 3, 3, (P('custom', 'earthen', 'native', 'male', 'earthendwarfmale.m2'),
         P('custom', 'earthen', 'native', 'female', 'earthendwarffemale.m2')), 'Earthen', None, None),
    69: (ESTERIA_TABLES + 'earthen/', 49, H, 'Earthen', 3, 3, (P('custom', 'earthen', 'native', 'male', 'earthendwarfmale.m2'),
         P('custom', 'earthen', 'native', 'female', 'earthendwarffemale.m2')), 'EarthenHorde', None, None),
    70: (ESTERIA_TABLES + 'haranir/', 51, H, 'Haranir', 4, 4, (P('custom', 'haranir', 'native', 'male', 'harronirmale.m2'),
         P('custom', 'haranir', 'native', 'female', 'harronirfemale.m2')), 'HaranirHorde', None, None),
    71: (ESTERIA_TABLES + 'haranir/', 50, A, 'Haranir', 4, 4, (P('custom', 'haranir', 'native', 'male', 'harronirmale.m2'),
         P('custom', 'haranir', 'native', 'female', 'harronirfemale.m2')), 'Haranir', None, None),
    74: (ESTERIA_TABLES + 'vulpera/', 20, H, 'Vulpera', 19, 19, (P('custom', 'vulpera', 'native', 'male', 'vulperamale.m2'),
         P('custom', 'vulpera', 'native', 'female', 'vulperafemale.m2')), 'VulperaEsteria', None, None),
}


def moved(text, move):
    if move and text.lower().startswith(move[0]):
        return move[1] + text[len(move[0]):]
    return text


cdi, cmd = DBC(OUT + 'CreatureDisplayInfo.dbc'), DBC(OUT + 'CreatureModelData.dbc')
CDI = {r[0]: r for r in cdi.rows}
CMD = {r[0]: r for r in cmd.rows}
ours_races = {r[0]: r for r in DBC(OUT + 'ChrRaces.dbc').rows}
extra_displays = {}                                          # race -> (male display, female display)
model_ids = {}
for rid, (src, srace, side, name, look, stats, models, fname, prefix, move) in EXTRA.items():
    disps = []
    for sex in (0, 1):
        old = CDI[ours_races[look][4 + sex]]
        if models[sex] not in model_ids:
            m = list(CMD[old[1]])
            m[0] = max(CMD) + 1
            m[2] = cmd.string(models[sex])
            CMD[m[0]] = m
            cmd.rows.append(m)
            model_ids[models[sex]] = m[0]
        d = list(old)
        d[0], d[1] = max(CDI) + 1, model_ids[models[sex]]
        d[6] = d[7] = d[8] = 0
        CDI[d[0]] = d
        cdi.rows.append(d)
        disps.append((d[0], old[0], sex))
    extra_displays[rid] = disps
cdi.save(OUT + 'CreatureDisplayInfo.dbc')
cmd.save(OUT + 'CreatureModelData.dbc')

for name in ('ChrRaces.dbc', 'client_ChrRaces.dbc'):
    t = DBC(OUT + name)
    by = {r[0]: r for r in t.rows}
    for rid, (src, srace, side, rname, look, stats, models, fname, prefix, move) in EXTRA.items():
        base = list(by[look])
        base[0], base[1] = rid, 0xC
        base[2], base[13], base[7] = FACTION[side]
        base[4], base[5] = extra_displays[rid][0][0], extra_displays[rid][1][0]
        if prefix:
            base[6] = t.string(prefix)
        base[11] = t.string(fname)
        base[12] = 0
        for k in list(range(14, 30)) + list(range(31, 47)) + list(range(48, 64)):
            base[k] = t.string('')
        for k in (14, 31, 48):
            base[k] = t.string(rname)
        base[68] = 0
        t.rows = [r for r in t.rows if r[0] != rid] + [base]
    t.rows.sort(key=lambda r: r[0])
    t.save(OUT + name)


def merge_extra(name, race_field, id_field=0, strings=()):
    ours = DBC(OUT + name)
    ours.rows = [r for r in ours.rows if r[race_field] not in EXTRA]
    next_id = max(r[id_field] for r in ours.rows) + 1 if id_field is not None else None
    for rid, (src, srace, side, rname, look, stats, models, fname, prefix, move) in EXTRA.items():
        theirs = DBC(src + name)
        for r in theirs.rows:
            if r[race_field] != srace:
                continue
            nr = list(r)
            nr[race_field] = rid
            if id_field is not None:
                nr[id_field] = next_id
                next_id += 1
            for k in strings:
                nr[k] = ours.string(moved(theirs.s(r[k]), move))
            if name == 'CharSections.dbc' and r[3] == 0 and rid in PRECOMPOSED:
                nr[7] |= 8
            if FACE_BLANK and name == 'CharSections.dbc' and r[3] == 1 and rid in (47, 57, 32):
                nr[4], nr[5], nr[6] = ours.string(FACE_PATH % (rid, r[2], r[9], 'L')), ours.string(FACE_PATH % (rid, r[2], r[9], 'U')), ours.string('')
            ours.rows.append(nr)
    ours.save(OUT + name)


merge_extra('CharSections.dbc', 1, 0, (4, 5, 6))
merge_extra('CharHairGeosets.dbc', 1, 0)
merge_extra('CharacterFacialHairStyles.dbc', 0, None)
for tname, field in (('UICameraAppearanceChrRaces.dbc', 1), ('NameGen.dbc', 2), ('EmotesTextSound.dbc', 2),
                     ('CharacterCreationClassDetails.dbc', 2), ('CharacterCreationArchetypeDetails.dbc', 2),
                     ('CharacterCreationShapeshiftDetails.dbc', 2)):
    t = DBC(OUT + tname)
    t.rows = [r for r in t.rows if r[field] not in EXTRA]
    next_id = max(r[0] for r in t.rows) + 1
    for rid, v in EXTRA.items():
        for r in [r for r in t.rows if r[field] == v[4]]:
            nr = list(r)
            nr[field], nr[0] = rid, next_id
            next_id += 1
            t.rows.append(nr)
    t.save(OUT + tname)
so = DBC(OUT + 'CharStartOutfit.dbc', packed=True)
so.raw = [r for r in so.raw if r[4] not in EXTRA]
next_id = max(struct.unpack_from('<I', r)[0] for r in so.raw) + 1
for rid, v in EXTRA.items():
    for r in [r for r in so.raw if r[4] == TEMPLATE[v[2]]]:
        nr = bytearray(r)
        struct.pack_into('<I', nr, 0, next_id)
        nr[4] = rid
        next_id += 1
        so.raw.append(nr)
so.save(OUT + 'CharStartOutfit.dbc')
c = open(OUT + 'CharBaseInfo.dbc', 'rb').read()
pairs = [(c[20 + i * 2], c[21 + i * 2]) for i in range(struct.unpack('<I', c[4:8])[0])]
human = [cl for r, cl in pairs if r == 1]
pairs = [p for p in pairs if p[0] not in EXTRA] + [(rid, cl) for rid in EXTRA for cl in human]
open(OUT + 'CharBaseInfo.dbc', 'wb').write(struct.pack('<4s4I', b'WDBC', len(pairs), 2, 2, 0) + b''.join(bytes(p) for p in pairs))
sql = open(OUT + 'eunoia.sql').read().replace('COMMIT;\n', '')
ids = ','.join(str(r) for r in EXTRA)
for table, col in (('playercreateinfo', 'race'), ('playercreateinfo_item', 'race'), ('playercreateinfo_action', 'race'),
                   ('player_race_stats', 'Race'), ('ascension_custom_class_race', 'race')):
    sql += 'DELETE FROM %s WHERE %s IN (%s);\n' % (table, col, ids)
for rid, (src, srace, side, rname, look, stats, models, fname, prefix, move) in EXTRA.items():
    tpl = TEMPLATE[side]
    sql += 'INSERT INTO playercreateinfo SELECT %d,class,map,zone,position_x,position_y,position_z,orientation FROM playercreateinfo WHERE race=%d;\n' % (rid, tpl)
    sql += 'INSERT INTO playercreateinfo_item SELECT %d,class,itemid,amount,Note FROM playercreateinfo_item WHERE race=%d;\n' % (rid, tpl)
    sql += 'INSERT INTO playercreateinfo_action SELECT %d,class,button,action,type FROM playercreateinfo_action WHERE race=%d;\n' % (rid, tpl)
    sql += 'INSERT INTO player_race_stats SELECT %d,Strength,Agility,Stamina,Intellect,Spirit FROM player_race_stats WHERE Race=%d;\n' % (rid, stats)
    sql += 'INSERT INTO ascension_custom_class_race SELECT DISTINCT class,%d FROM ascension_custom_class_race;\n' % rid
    for new, old, sex in extra_displays[rid]:
        sql += 'DELETE FROM creature_model_info WHERE DisplayID=%d;\n' % new
        sql += ('INSERT INTO creature_model_info (DisplayID,BoundingRadius,CombatReach,Gender,DisplayID_Other_Gender) '
                'SELECT %d,BoundingRadius,CombatReach,%d,0 FROM creature_model_info WHERE DisplayID=%d;\n' % (new, sex, old))
open(OUT + 'eunoia.sql', 'w').write(sql + 'COMMIT;\n')
print('extra races %s: displays %s' % (list(EXTRA), extra_displays))


# ---------------------------------------------------------------- CharSections: no holes the client can fall into
# The creation screen looks up the face (section 1) and the underwear (section 4) with the colour of the chosen skin,
# and a hair / facial hair colour within its style, without checking the result: a missing row is a null pointer
# (0x004EA77F, underwear of a skin colour without one). Eunoia's races have more skin colours than faces and
# underwear. Each missing (race, sex, section, variation, colour) gets the row of the nearest lower colour, and the
# rows are sorted so each (race, sex, section) is one block (the client builds its table from contiguous runs).
# Murlocs (30, 31) are left as they are.
def fill_sections(name, max_skin=None):
    cs = DBC(OUT + name)
    keep = [r for r in cs.rows if r[1] in (30, 31)]
    rows = [r for r in cs.rows if r[1] not in (30, 31)]
    have = {}
    for r in rows:
        have.setdefault((r[1], r[2], r[3], r[8]), {})[r[9]] = r
    skins = {}
    for (race, sex, sec, var), cols in have.items():
        if sec == 0 and var == 0:
            skins[(race, sex)] = max(cols) + 1
    MAX_SKIN = max_skin or max(skins.values())
    next_id = max(r[0] for r in cs.rows) + 1
    added = 0
    for (race, sex, sec, var), cols in list(have.items()):
        if sec >= 5:
            continue
        top = max(cols) + 1
        if sec in (1, 4):                                    # a face and an underwear for each real skin colour
            top = max(top, skins.get((race, sex), 0))
        # (no padding beyond the race's own skins: the random appearance of the creation screen picked padded copies
        #  and showed a body of one colour with a face of another; the crashes it chased were the HD row IDs)
        for c in range(top):
            if c in cols:
                continue
            src = cols[max(k for k in cols if k < c)] if any(k < c for k in cols) else cols[min(cols)]
            nr = list(src)
            nr[0], nr[9] = next_id, c
            next_id += 1
            cols[c] = nr
            rows.append(nr)
            added += 1
    # male-only races (Ice Troll, Forest Troll...) have no female rows: when the previous race left "female" selected,
    # the client looked up a female underwear row before the Lua switched back to male (0x004EA77F). Copy the rows.
    sexes = {}
    for r in rows:
        if r[3] == 0:                                        # a sex counts when it has skins
            sexes.setdefault(r[1], set()).add(r[2])
    for race, have_sex in sexes.items():
        if len(have_sex) == 1:
            only = next(iter(have_sex))
            for r in [r for r in rows if r[1] == race and r[2] == only and r[3] < 5]:
                nr = list(r)
                nr[0], nr[2] = next_id, 1 - only
                next_id += 1
                rows.append(nr)
                added += 1
    # every row usable at creation: the client skips rows without the playable flag (1) and Death Knight-only rows (4),
    # which left empty slots it then read (0x004EA0F4, Fel Orc skin). There is no Death Knight at creation any more.
    for r in rows:
        if r[3] < 5:
            r[7] = (r[7] | 1) & ~4
    rows.sort(key=lambda r: (r[1], r[2], r[3], r[8], r[9]))
    cs.rows = rows + keep
    cs.save(OUT + name)
    print('%s: %d rows added to fill colour holes' % (name, added))
    return MAX_SKIN


# the HD layer (HDCharSections, used with the HD textures) has its own copy of these lookups: same treatment, with
# the skin count of CharSections (Ice Troll female: 1 HD skin, a carried-over index crashed, 0x004EA0F4)
fill_sections('CharSections.dbc')
# HDCharSections is not filled: it has HD faces for some skin colours only, and the client falls back to the normal
# face of the right colour for the others; a copied HD face of another colour put a light face on a dark skin.


# ---------------------------------------------------------------- HD rows keyed like the normal rows
# Ascension's HD layer replaces CharSections rows BY ID with the HDCharSections row of the same ID. Renumbered rows
# made HD rows land on other races (HD 70505 = Human skin over CharSections 70505 = Skeleton skin 0): empty slots,
# creation screen crashes (0x004EA0F4 / 0x004EA77F). Each HD row takes the ID of the normal row with the same race,
# sex, section, variation and colour; one without a normal row gets an ID past the end (it replaces nothing).
cs = DBC(OUT + 'CharSections.dbc')
for new_id, r in enumerate(cs.rows, 1):                  # IDs in file order (the client keeps rows in ID order)
    r[0] = new_id
cs.save(OUT + 'CharSections.dbc')
key_id = {(r[1], r[2], r[3], r[8], r[9]): r[0] for r in cs.rows}
hd = DBC(OUT + 'HDCharSections.dbc')
# Eunoia's skins and faces are HD textures: their races get HD rows too (same rows), so the client lays them out as HD
hd.rows = [r for r in hd.rows if r[1] not in RACES and r[1] != NAGA]
for r in cs.rows:
    if r[1] in RACES or r[1] == NAGA or r[1] in HD_EXTRA:        # + Alpha Worgen / Goblin (, Thin Human): 512 skins
        nr = list(r)
        for k in (4, 5, 6):
            nr[k] = hd.string(cs.s(r[k]))
        hd.rows.append(nr)
next_id = max(r[0] for r in cs.rows) + 1
matched = 0
for r in hd.rows:
    k = (r[1], r[2], r[3], r[8], r[9])
    if k in key_id:
        r[0] = key_id[k]
        matched += 1
    else:
        r[0] = next_id
        next_id += 1
seen = set()
hd.rows = [r for r in hd.rows if not (r[0] in seen or seen.add(r[0]))]
hd.rows.sort(key=lambda r: r[0])
hd.save(OUT + 'HDCharSections.dbc')
print('HDCharSections: %d rows on their normal row ID, %d past the end' % (matched, len(hd.rows) - matched))


# ---------------------------------------------------------------- styles and their texture rows must agree
# A race crashed the creation screen when a hair or facial style had no texture rows (Void Elf female: 15 facial
# styles, no facial hair rows) or a sex had texture rows but no styles (Thin Human female). For the new races: a sex
# without styles gets the other sex's; each style gets rows (transparent texture) in every hair colour.
NEWER = set(RACES) | set(EXTRA) | {NAGA}
hg, fh = DBC(OUT + 'CharHairGeosets.dbc'), DBC(OUT + 'CharacterFacialHairStyles.dbc')
for t, rf, sf, idf in ((hg, 1, 2, 0), (fh, 0, 1, None)):
    nid = max(r[0] for r in t.rows) + 1 if idf is not None else None
    for race in NEWER:
        for sex in (0, 1):
            if not any(r[rf] == race and r[sf] == sex for r in t.rows):
                for r in [r for r in t.rows if r[rf] == race and r[sf] == 1 - sex]:
                    nr = list(r)
                    nr[sf] = sex
                    if idf is not None:
                        nr[idf] = nid
                        nid += 1
                    t.rows.append(nr)
seen = set()                                             # one definition per race, sex and style: Eunoia's Illidari
hg.rows = [r for r in hg.rows if not ((r[1], r[2], r[3]) in seen or seen.add((r[1], r[2], r[3])))]   # Night Elf had 2
seen = set()                                             # (hair + horns) and crashed; Alpha Worgen facial style 0 x2
fh.rows = [r for r in fh.rows if not ((r[0], r[1], r[2]) in seen or seen.add((r[0], r[1], r[2])))]
hg.save(OUT + 'CharHairGeosets.dbc')
fh.save(OUT + 'CharacterFacialHairStyles.dbc')
cs = DBC(OUT + 'CharSections.dbc')
blank = cs.string(BLANK_HD[1])
have = {(r[1], r[2], r[3], r[8]) for r in cs.rows}
tpl_rows = {}                                            # first existing row per (race, sex, section, colour)
for r in cs.rows:
    if r[3] in (2, 3):
        tpl_rows.setdefault((r[1], r[2], r[3], r[9]), r)
hair_colours = {}
for r in cs.rows:
    if r[3] == 3:
        hair_colours[(r[1], r[2])] = max(hair_colours.get((r[1], r[2]), 0), r[9] + 1)
nid = max(r[0] for r in cs.rows) + 1
added = 0
for race in NEWER:
    for sex in (0, 1):
        colours = max(1, hair_colours.get((race, sex), 1))
        for sec, styles in ((3, {r[3] for r in hg.rows if r[1] == race and r[2] == sex}),
                            (2, {r[2] for r in fh.rows if r[0] == race and r[1] == sex})):
            for v in sorted(styles):
                if (race, sex, sec, v) in have:
                    continue
                for c in range(colours):
                    tpl = tpl_rows.get((race, sex, sec, c)) or tpl_rows.get((race, sex, sec, 0))
                    if tpl:
                        cs.rows.append([nid, race, sex, sec, tpl[4], tpl[5], tpl[6], tpl[7], v, c])
                    else:
                        cs.rows.append([nid, race, sex, sec, cs.string('') if sec == 3 else blank, blank, cs.string('') if sec == 2 else blank, 1, v, c])
                    nid += 1
                    added += 1
# face (1) and hair (3) variations inside a race's range but without any row: the client's existence check fails and
# the loader keeps the PREVIOUS character's textures (stale face). Copy variation 0's rows into every such hole.
_byv = {}
for r in cs.rows:
    if r[1] in NEWER and r[3] in (1, 2, 3):
        _byv.setdefault((r[1], r[2], r[3]), {}).setdefault(r[8], []).append(r)
_gap = 0
for (race, sex, sec), vs in _byv.items():
    for v in range(max(vs) + 1):
        if v not in vs:
            for r in vs[min(vs)]:
                nr = list(r); nr[0] = nid; nr[8] = v; nid += 1
                cs.rows.append(nr); _gap += 1
print('variation holes filled with %d rows' % _gap)
# face (1) and underwear (4) rows belong to a skin colour: drop those of colours the race has no skin for (they were
# copied from sources with more face colours than skins; the audit found 252 such references with no texture)
skin_keys = {(r[1], r[2], r[9]) for r in cs.rows if r[3] == 0 and r[8] == 0}
cs.rows = [r for r in cs.rows if not (r[3] in (1, 4) and r[1] in NEWER and (r[1], r[2], r[9]) not in skin_keys)]
cs.rows.sort(key=lambda r: (r[1], r[2], r[3], r[8], r[9]))
for new_id, r in enumerate(cs.rows, 1):
    old = r[0]
    r[0] = new_id
cs.save(OUT + 'CharSections.dbc')
hd = DBC(OUT + 'HDCharSections.dbc')
key_id = {(r[1], r[2], r[3], r[8], r[9]): r[0] for r in cs.rows}
hd.rows = [r for r in hd.rows if r[1] not in NEWER or (r[1], r[2], r[3], r[8], r[9]) in key_id]
nid = max(r[0] for r in cs.rows) + 1
for r in hd.rows:
    k = (r[1], r[2], r[3], r[8], r[9])
    if k in key_id:
        r[0] = key_id[k]
    else:
        r[0] = nid
        nid += 1
hd.rows.sort(key=lambda r: r[0])
hd.save(OUT + 'HDCharSections.dbc')
print('styles: %d texture rows added for styles without one' % added)


# ---------------------------------------------------------------- textures referenced by Eunoia's data that exist nowhere
# (Pandaren facial hair, Illidari scalp overlays: missing from their own client too). A load that fails logs an error and
# leaves a null handle; point them at the transparent filler instead (found by C:\CoA-Build\eunoia\validate_client.py).
import json as _json
if _os.path.exists('C:/CoA-Build/eunoia/missing.json'):
    MISSING = set(_json.load(open('C:/CoA-Build/eunoia/missing.json')))
    for _name in ('CharSections.dbc', 'HDCharSections.dbc'):
        _t = DBC(OUT + _name)
        _n = 0
        for _r in _t.rows:
            if _r[1] in NEWER:
                for _k in (4, 5, 6):
                    _p = _t.s(_r[_k])
                    if _p and _p.lower() in MISSING:
                        _r[_k] = _t.string(BLANK_HD[0] if 'lower' in _p.lower() else BLANK_HD[1])
                        _n += 1
        _t.save(OUT + _name)
        print('%s: %d missing texture references replaced by the transparent filler' % (_name, _n))


# ---------------------------------------------------------------- no pre-composited skins for the imported races
# Rows copied from sources that carry flag 8 (Thin Human's, colour-hole fillers) lose it too; see PRECOMPOSED above.
for _name in ('CharSections.dbc', 'HDCharSections.dbc'):
    _t = DBC(OUT + _name)
    _n = 0
    for _r in _t.rows:
        if _r[1] in NEWER and _r[3] == 0 and _r[7] & 8:
            _r[7] &= ~8
            _n += 1
    _t.save(OUT + _name)
    print('%s: flag 8 cleared on %d skin rows' % (_name, _n))


# ---------------------------------------------------------------- no texture field may point at offset 0
# Offset 0 of Ascension's CharSections string block is the Human male skin (only its own row uses it on purpose).
# Any other 0 (rows made by earlier scripts or copied with a literal 0) becomes the empty string.
for _name in ('CharSections.dbc', 'HDCharSections.dbc'):
    _t = DBC(OUT + _name)
    _empty = _t.string('')
    _n = 0
    for _r in _t.rows:
        for _k in (4, 5, 6):
            if _r[_k] == 0 and not (_r[1] == 1 and _r[2] == 0 and _r[3] == 0 and _r[8] == 0 and _r[9] == 0 and _k == 4):
                _r[_k] = _empty
                _n += 1
    _t.save(OUT + _name)
    print('%s: %d empty texture fields pointed at offset 0 (Human male skin), now empty' % (_name, _n))
# same for the creature textures of the displays added by these scripts (offset 0 = "DragonSkin1Green")
_stock = {r[0] for r in DBC('C:/CoA-Repack/Custom/backups/dbc_original/CreatureDisplayInfo.dbc').rows}
_t = DBC(OUT + 'CreatureDisplayInfo.dbc')
_empty = _t.string('')
_n = 0
for _r in _t.rows:
    if _r[0] not in _stock:
        for _k in (6, 7, 8):
            if _r[_k] == 0:
                _r[_k] = _empty
                _n += 1
_t.save(OUT + 'CreatureDisplayInfo.dbc')
print('CreatureDisplayInfo.dbc: %d empty creature textures of new displays pointed at offset 0, now empty' % _n)


# ---------------------------------------------------------------- faces of the Eunoia races: their own face textures
# Their skins do not all carry the right face (Illidari, Void Elf: a generic face in the skin's face area), so the face
# rows use Eunoia's own face textures again (the "mask" of earlier builds was the Human-skin offset-0 bug drawn over
# them). Per face style and skin colour: Eunoia's row; else the same style of a colour that has the same skin texture
# (Ogre colours 6-17 repeat skins 0-8); else style 0 of that colour; else the face cut from the skin (make_faces.py).
_eu = DBC(EU + 'CharSections.dbc')
_euf = {}
for _r in _eu.rows:
    if _r[3] == 1:
        _l, _u = _eu.s(_r[4]), _eu.s(_r[5])
        if _l and _l.lower() in EU_HAVE and (not _u or _u.lower() in EU_HAVE):
            _euf[(_r[1], _r[2], _r[8], _r[9])] = (_l, _u)
_t = DBC(OUT + 'CharSections.dbc')
_skin = {(_r[1], _r[2], _r[9]): _t.s(_r[4]).lower() for _r in _t.rows if _r[3] == 0 and _r[8] == 0}
import collections as _c
_how = _c.Counter()
_face_of = {}
for _r in _t.rows:
    if _r[3] != 1 or _r[1] not in RACES:
        continue
    _e = RACES[_r[1]][0]
    _v, _col, _sx = _r[8], _r[9], _r[2]
    _same = [c for (rr, ss, c), p in _skin.items() if rr == _r[1] and ss == _sx and p == _skin.get((_r[1], _sx, _col))]
    _pick = _euf.get((_e, _sx, _v, _col))
    _kind = 'own'
    if not _pick:
        _pick = next((_euf[(_e, _sx, _v, c)] for c in sorted(_same) if (_e, _sx, _v, c) in _euf), None); _kind = 'same skin'
    if not _pick:
        _pick = _euf.get((_e, _sx, 0, _col)) or next((_euf[(_e, _sx, 0, c)] for c in sorted(_same) if (_e, _sx, 0, c) in _euf), None); _kind = 'style 0'
    if _pick:
        _r[4], _r[5], _r[6] = _t.string(_pick[0]), _t.string(_pick[1]), _t.string('')
    else:
        _r[4], _r[5], _r[6] = _t.string(FACE_PATH % (_r[1], _sx, _col, 'L')), _t.string(FACE_PATH % (_r[1], _sx, _col, 'U')), _t.string('')
        _kind = 'cut-out'
    _how[_kind] += 1
    _face_of[(_r[1], _r[2], _r[3], _r[8], _r[9])] = (_t.s(_r[4]), _t.s(_r[5]))
# Thin Human: classic body = left half of the retail skin, head = the skin-extra texture (right half), own underwear
for _r in _t.rows:
    if _r[1] == 32 and _r[3] == 0:
        _p = _t.s(_r[4])
        _r[5] = _t.string(_p.replace('skin00_', 'skinextra00_'))
    if _r[1] == 32 and _r[3] in (2, 3):                       # its head is the skin-extra texture: the face areas of
        for _k in ((4, 5, 6) if _r[3] == 2 else (5, 6)):      # the composite are unused, and the borrowed Kul Tiran
            _r[_k] = _t.string('')                            # facial textures are DXT (drawn as solid green there)
    if _r[1] == 32 and _r[3] == 4:
        _base = chr(92).join(['custom', 'thinhuman', 'character', 'thinhuman', 'male', ''])
        _r[4] = _t.string(_base + 'thinhumanmalenakedpelvisskin00_%02d.blp' % min(_r[9], 3))
        _r[5] = _t.string(_base + 'thinhumanmalenakedtorsoskin00_%02d.blp' % min(_r[9], 3))
_t.save(OUT + 'CharSections.dbc')
print('Eunoia faces:', dict(_how))
_h = DBC(OUT + 'HDCharSections.dbc')
_n = 0
for _r in _h.rows:
    _k = (_r[1], _r[2], _r[3], _r[8], _r[9])
    if _k in _face_of:
        _r[4], _r[5], _r[6] = _h.string(_face_of[_k][0]), _h.string(_face_of[_k][1]), _h.string('')
        _n += 1
_h.save(OUT + 'HDCharSections.dbc')
print('HDCharSections: %d face rows follow the normal ones' % _n)


# ---------------------------------------------------------------- no transparent fillers in the face overlays
# Styles without textures got BlankFaceUpper (256x64, 4:1) in BOTH facial slots; in the 2:1 lower-face region the
# client copies past the end of that mip (striped lower face, Void Elf female). Empty strings work now: use them.
for _name in ('CharSections.dbc', 'HDCharSections.dbc'):
    _t = DBC(OUT + _name)
    _e = _t.string('')
    _n = 0
    for _r in _t.rows:
        if _r[1] in NEWER and _r[3] in (2, 3):
            for _k in ((4, 5, 6) if _r[3] == 2 else (5, 6)):
                if 'blankface' in _t.s(_r[_k]).lower():
                    _r[_k] = _e
                    _n += 1
    _t.save(OUT + _name)
    print('%s: %d blank facial/scalp fillers removed' % (_name, _n))


# ---------------------------------------------------------------- Medviten races: Mag'har extra skin, Ogre styles
# Mag'har (49) wears Ascension's Orc model, whose head needs the skin-extra layer: Orc...Skin00_NN_Extra.blp (patch-Q).
# Ogre (53): the module supports skin colour only (its readme); the other choices showed broken head geosets.
_t = DBC(OUT + 'CharSections.dbc')
_n = 0
for _r in _t.rows:
    if _r[1] == 49 and _r[3] == 0 and not _t.s(_r[5]):
        _p = _t.s(_r[4])
        if _p.lower().endswith('.blp'):
            _r[5] = _t.string(_p[:-4] + '_Extra.blp'); _n += 1
_before = len(_t.rows)
_t.rows = [_r for _r in _t.rows if not (_r[1] == 53 and _r[3] in (1, 2, 3) and _r[8] > 0)]
_t.save(OUT + 'CharSections.dbc')
_hg, _fh = DBC(OUT + 'CharHairGeosets.dbc'), DBC(OUT + 'CharacterFacialHairStyles.dbc')
_hg.rows = [_r for _r in _hg.rows if not (_r[1] == 53 and _r[3] > 0)]
_fh.rows = [_r for _r in _fh.rows if not (_r[0] == 53 and _r[2] > 0)]
_hg.save(OUT + 'CharHairGeosets.dbc'); _fh.save(OUT + 'CharacterFacialHairStyles.dbc')
print("Mag'har: %d skin-extra layers; Ogre: %d style rows removed" % (_n, _before - len(_t.rows)))


# ---------------------------------------------------------------- Mag'har = Ascension's Orc look (all of it)
# The module's rows lean on retail Orc colours 9-11 that Ascension's HD Orc model does not fit (dark broken face).
# Mag'har (49) takes a copy of every Orc (2) row: CharSections + HDCharSections (same IDs, HD replaces by ID), hair
# and facial-hair styles.
_t = DBC(OUT + 'CharSections.dbc'); _h = DBC(OUT + 'HDCharSections.dbc')
_t.rows = [r for r in _t.rows if r[1] != 49]
_h.rows = [r for r in _h.rows if r[1] != 49]
_nid = max(max(r[0] for r in _t.rows), max(r[0] for r in _h.rows)) + 1
_orc = sorted([r for r in _t.rows if r[1] == 2], key=lambda r: (r[2], r[3], r[8], r[9]))
_ids = {}
for r in _orc:
    nr = list(r); nr[1] = 49; nr[0] = _nid; _ids[r[0]] = _nid; _nid += 1
    for k in (4, 5, 6): nr[k] = _t.string(_t.s(r[k]))
    _t.rows.append(nr)
for r in [r for r in _h.rows if r[1] == 2]:
    if r[0] in _ids:
        nr = list(r); nr[1] = 49; nr[0] = _ids[r[0]]
        for k in (4, 5, 6): nr[k] = _h.string(_h.s(r[k]))
        _h.rows.append(nr)
_h.rows.sort(key=lambda r: r[0])
_t.save(OUT + 'CharSections.dbc'); _h.save(OUT + 'HDCharSections.dbc')
_hg, _fh = DBC(OUT + 'CharHairGeosets.dbc'), DBC(OUT + 'CharacterFacialHairStyles.dbc')
_hg.rows = [r for r in _hg.rows if r[1] != 49]
_g = max(r[0] for r in _hg.rows) + 1
for r in [r for r in _hg.rows if r[1] == 2]:
    nr = list(r); nr[0] = _g; nr[1] = 49; _g += 1; _hg.rows.append(nr)
_fh.rows = [r for r in _fh.rows if r[0] != 49] + [[49] + list(r[1:]) for r in _fh.rows if r[0] == 2]
_hg.save(OUT + 'CharHairGeosets.dbc'); _fh.save(OUT + 'CharacterFacialHairStyles.dbc')
print("Mag'har: %d Orc rows copied (%d HD)" % (len(_orc), sum(1 for r in _h.rows if r[1] == 49)))


# ---------------------------------------------------------------- Undead Gnome (51): Gnome rows, undead textures
# Every Gnome row (normal + HD, same IDs so HD replaces by ID) copied to 51; skin, skin-extra, face and underwear
# textures point at recoloured copies in the GnomeUndead folder (built by make_undead.py from pairs.json).
import json as _js
_t = DBC(OUT + 'CharSections.dbc'); _h = DBC(OUT + 'HDCharSections.dbc')
_t.rows = [r for r in _t.rows if r[1] != 51]
_h.rows = [r for r in _h.rows if r[1] != 51]
_pairs = {}
def _undead(path, sec):
    pre = 'character' + chr(92) + 'gnome' + chr(92)
    if sec in (0, 1, 4) and path.lower().startswith(pre):
        new = 'Character' + chr(92) + 'GnomeUndead' + chr(92) + path[len(pre):]
        _pairs[path] = new
        return new
    return path
_nid = max(max(r[0] for r in _t.rows), max(r[0] for r in _h.rows)) + 1
_ids = {}
for r in sorted([r for r in _t.rows if r[1] == 7], key=lambda r: (r[2], r[3], r[8], r[9])):
    nr = list(r); nr[1] = 51; nr[0] = _nid; _ids[r[0]] = _nid; _nid += 1
    for k in (4, 5, 6): nr[k] = _t.string(_undead(_t.s(r[k]), r[3]))
    _t.rows.append(nr)
for r in [r for r in _h.rows if r[1] == 7]:
    if r[0] in _ids:
        nr = list(r); nr[1] = 51; nr[0] = _ids[r[0]]
        for k in (4, 5, 6): nr[k] = _h.string(_undead(_h.s(r[k]), r[3]))
        _h.rows.append(nr)
_h.rows.sort(key=lambda r: r[0])
_t.save(OUT + 'CharSections.dbc'); _h.save(OUT + 'HDCharSections.dbc')
_os.makedirs('C:/CoA-Build/undeadgnome', exist_ok=True)
_js.dump(_pairs, open('C:/CoA-Build/undeadgnome/pairs.json', 'w'), indent=0)
print('Undead Gnome: %d rows, %d textures to recolour' % (sum(1 for r in _t.rows if r[1] == 51), len(_pairs)))


# ---------------------------------------------------------------- creature races: model scale of their displays
# (the female Eredar model is small and shown at 3x by its creature displays)
_sc = _js.load(open('C:/CoA-Build/creatures/scales.json'))
_cdi = DBC(OUT + 'CreatureDisplayInfo.dbc')
_by = {r[0]: r for r in _cdi.rows}
for _rid in (56,):
    for _disp, _old, _sex in extra_displays.get(_rid, []):
        _v = _sc.get('%d_%d' % (_rid, _sex), 1.0)
        if _disp in _by and _v != 1.0:
            _by[_disp][4] = struct.unpack('<I', struct.pack('<f', _v))[0]
_cdi.save(OUT + 'CreatureDisplayInfo.dbc')
print('creature races: display scales set', _sc)


# Esteria's Earthen (68/69) and Vulpera (74) replace ours at creation: the old 27 and 19 get the "not playable" flag
# (0x1, as the hidden NPC races) so they have no button; characters already made on them still load.
for name in ('ChrRaces.dbc', 'client_ChrRaces.dbc'):
    t = DBC(OUT + name)
    for r in t.rows:
        if r[0] in (19, 27, 65, 72, 77):    # + Skyborne 72/77: crashed the client, removed 2026-10-07 (to retry later)            # + Test Race 65 (the 128-race test), removed 2026-10-07
            r[1] |= 0x1
    t.save(OUT + name)
print('old Earthen 27 / Vulpera 19 hidden from creation')



# Skeleton (26): its hair texture Character\Skeleton\Hair00_00.blp exists in no archive (checkered squares on the
# hair pieces, 2026-10-08): the hair rows take the skeleton's own skin texture instead
_t = DBC(OUT + 'CharSections.dbc')
_skin = _t.string(BS.join(('Character', 'Skeleton', 'Male', 'SkeletonMaleSkin00_00.blp')))
for _r in _t.rows:
    if _r[1] == 26 and _r[3] == 3 and _t.s(_r[4]).lower().endswith('hair00_00.blp'):
        _r[4] = _skin
_t.save(OUT + 'CharSections.dbc')
print('Skeleton hair texture fixed')


# Murloc player models (make_murloc_model.py): 5 animation lookup entries point past their sequence list; a Murloc
# playing one (emote, mount, spell pose) made the client read garbage: crash 0x008204AE / hang near Murloc bots
# (2026-10-08). Those entries become -1 (animation absent: the client falls back to a valid one).
for _m in ('Creature/Murloc/MurlocPlayer.m2', 'Creature/Murloc/MurlocJump.m2', 'Creature/WhimMurloc/WhimPlayer.m2',
           'Creature/WhimMurloc/WhimGame.m2'):
    _p = OUT + 'model/' + _m
    if not _os.path.exists(_p):
        continue
    _b = bytearray(open(_p, 'rb').read())
    _nseq = struct.unpack_from('<I', _b, 0x1C)[0]
    _nl, _ol = struct.unpack_from('<II', _b, 0x24)
    _fixed = 0
    for _i in range(_nl):
        if struct.unpack_from('<h', _b, _ol + _i * 2)[0] >= _nseq:
            struct.pack_into('<h', _b, _ol + _i * 2, -1)
            _fixed += 1
    open(_p, 'wb').write(_b)
    print('Murloc %s: %d animation lookups past the sequences fixed' % (_m, _fixed))
