# Esteria's Mechagnome (Kalibros | Lord of Wen; RetroPorter from retail 12.1.0.69933) as source tables for gen_eunoia.py:
# the CharSections / CharHairGeosets / CharacterFacialHairStyles rows of mechagnome_race_pack.py tables(), race 47,
# rebuilt from its preparation.json (the "report"). gen_eunoia copies them to our race 67; EsteriaAppearance.dll maps
# 67 back to 47 for its catalogs. Same mixed-radix encoding as Esteria, so the DLL's options line up.
import itertools, json, struct
SRC = 'C:/Users/ilusi/Downloads/RetroPorterWork/mechagnome/integration/preparation.json'
OUT = 'C:/CoA-Build/esteria/mechagnome_dbc/'
LABELS = ("Skin Color", "Face", "Hair Style", "Hair Color", "Facial Hair", "Arm Upgrade",
          "Leg Upgrade", "Modification", "Eye Color", "Paint", "Eyesight", "Eye Style")
B = chr(92)
PREFIX = 'custom' + B + 'mechagnome' + B + 'native'
report = json.load(open(SRC))


class Table:
    def __init__(self):
        self.rows, self.pool, self.index = [], bytearray(b'\0'), {'': 0}

    def s(self, text):
        if text not in self.index:
            self.index[text] = len(self.pool)
            self.pool += text.encode('latin1') + b'\0'
        return self.index[text]

    def save(self, name, fields):
        body = b''.join(struct.pack('<%dI' % fields, *r) for r in self.rows)
        open(OUT + name, 'wb').write(struct.pack('<4s4I', b'WDBC', len(self.rows), fields, fields * 4, len(self.pool))
                                     + body + bytes(self.pool))


def counts(prof):
    return {label: max(1, len(prof['choices'][label])) for label in LABELS}


def material(prof, label, index, target, related=0):
    choice = prof['choices'][label][index]
    return prof['materials'][str(choice['ID'])].get('%d:%d' % (target, related))


sections, hair, facial = Table(), Table(), Table()
next_id, hair_id = 520000, 450100
for gender, sex in enumerate(('male', 'female')):
    prof = report['sexes'][sex]['profile']
    c = counts(prof)
    root = PREFIX + B + sex

    def add(kind, style, color, paths):
        global next_id
        paths = list(paths) + [''] * (3 - len(paths))
        sections.rows.append((next_id, 47, gender, kind, sections.s(paths[0] or ''), sections.s(paths[1] or ''),
                              sections.s(paths[2] or ''), 1 if kind == 1 else 17, style, color))
        next_id += 1

    for eyesight, paint, skin in itertools.product(range(c['Eyesight']), range(c['Paint']), range(c['Skin Color'])):
        encoded = skin + c['Skin Color'] * (paint + c['Paint'] * eyesight)
        add(0, 0, encoded, [root + B + 'body%d.blp' % skin, material(prof, 'Paint', paint, 2)])
        add(4, 0, encoded, [root + B + 'pelvis%d.blp' % skin, root + B + 'torso%d.blp' % skin if gender else ''])
        for beard, face in itertools.product(range(c['Facial Hair']), range(c['Face'])):
            add(1, face + beard * c['Face'], encoded,
                [root + B + 'facelower%d_%d.blp' % (face, skin), root + B + 'faceupper%d_%d.blp' % (face, skin)])
    for leg, arm, style in itertools.product(range(c['Leg Upgrade']), range(c['Arm Upgrade']), range(c['Hair Style'])):
        encoded = style + c['Hair Style'] * (arm + c['Arm Upgrade'] * leg)
        geo = prof['geometry'][str(prof['choices']['Hair Style'][style]['ID'])][0]
        hair.rows.append((hair_id, 47, gender, encoded, geo, int(geo == 0)))
        hair_id += 1
        for eye, color in itertools.product(range(c['Eye Color']), range(c['Hair Color'])):
            add(3, encoded, color + c['Hair Color'] * eye, [material(prof, 'Hair Color', color, 10)])
    for eye_style, modification in itertools.product(range(c['Eye Style']), range(c['Modification'])):
        encoded = modification + c['Modification'] * eye_style
        facial.rows.append((47, gender, encoded, 0, 0, 0, 0, 0))
        for eye, color in itertools.product(range(c['Eye Color']), range(c['Hair Color'])):
            add(2, encoded, color + c['Hair Color'] * eye, [])
    print(sex, c)
sections.save('CharSections.dbc', 10)
hair.save('CharHairGeosets.dbc', 6)
facial.save('CharacterFacialHairStyles.dbc', 8)
print('rows', len(sections.rows), len(hair.rows), len(facial.rows))
