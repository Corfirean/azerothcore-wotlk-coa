# Character creation for the extra races of gen_eunoia.py (Alpha Worgen 47, Alpha Goblin 57, Furbolg 50): their ids
# in the race name map, icons, and a background scene for their file names. Run after patchlua_eunoia.py.
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
nl = '\r\n' if '\r\n' in src else '\n'
KEY = '-- Local server: extra races (3)'
if KEY not in src:
    code = (KEY + nl
            + 'CHAR_CREATE_RACE_IDS["Alpha Worgen"] = {47}' + nl
            + 'CHAR_CREATE_RACE_IDS["Alpha Goblin"] = {57}' + nl
            + 'CHAR_CREATE_RACE_IDS["Furbolg"] = {50}' + nl
            + 'CHAR_CREATE_RACE_IDS["Thin Human"] = {32}' + nl
            + 'if CHAR_CREATE_MALE_ONLY_RACES then CHAR_CREATE_MALE_ONLY_RACES["Thin Human"] = true end' + nl
            + 'if CHAR_CREATE_EXTRA_RACE_ICONS then' + nl
            + '\tCHAR_CREATE_EXTRA_RACE_ICONS["Alpha Worgen"] = "Interface\\\\Icons\\\\Ability_Mount_WhiteDireWolf"' + nl
            + '\tCHAR_CREATE_EXTRA_RACE_ICONS["Alpha Goblin"] = "Interface\\\\Icons\\\\INV_Misc_Bomb_04"' + nl
            + '\tCHAR_CREATE_EXTRA_RACE_ICONS["Furbolg"] = "Interface\\\\Icons\\\\Ability_Racial_BearForm"' + nl
            + '\tCHAR_CREATE_EXTRA_RACE_ICONS["Thin Human"] = "Interface\\\\Icons\\\\Achievement_Character_Human_Male"' + nl
            + 'end' + nl)
    src = src.rstrip() + nl + nl + code
    open(p, 'wb').write(src.encode('utf-8'))
    print('extra races lua patch applied')
p = 'out/Interface/GlueXML/GlueParent.lua'
glue = open(p, 'rb').read().decode('utf-8')
GKEY = '-- Local server: extra race backgrounds (2)'
if GKEY not in glue:
    a = '\t["DRAKKARITROLL"] = "TROLL", ["TROGLODYTE"] = "GNOME",'
    assert a in glue
    glue = glue.replace(a, a + ' ' + GKEY + nl + '\t["WORGENA"] = "HUMAN", ["GOBLINA"] = "ORC", ["REFORGEDFURBOLG"] = "NIGHTELF", ["THINHUMAN"] = "HUMAN",', 1)
    open(p, 'wb').write(glue.encode('utf-8'))
    print('extra race backgrounds applied')


# Safety net for the "first composite before the textures are ready" effect: the client composites the character
# texture right after a race / sex change and skips every texture that has not finished loading, without ever doing it
# again (changing the skin colour or the sex "fixed" the head by hand). A moment later, cycle the skin colour forward
# and back (what the arrows do, id 1 = skin): same appearance, but the textures are ready and the head is recomposed.
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
nl = '\r\n' if '\r\n' in src else '\n'
RKEY = '-- Local server: recomposite'
if RKEY not in src:
    lua = """-- Local server: recomposite the head once the textures are loaded
COA_RECOMPOSE = { timer = nil, shots = 0 }
do
	local frame = CreateFrame("Frame")
	frame:SetScript("OnUpdate", function(self, elapsed)
		local r = COA_RECOMPOSE
		if not r.timer then return end
		r.timer = r.timer - elapsed
		if r.timer > 0 then return end
		if r.shots > 0 then
			r.shots = r.shots - 1
			r.timer = (r.shots > 0) and 0.9 or nil
			if CharacterCreateFrame and CharacterCreateFrame:IsShown() and C_CharacterCreate and C_CharacterCreate.CycleCustomizationSkipLocked then
				pcall(function()
					C_CharacterCreate.CycleCustomizationSkipLocked(1, 1)
					C_CharacterCreate.CycleCustomizationSkipLocked(1, -1)
				end)
			end
		else
			r.timer = nil
		end
	end)
	local function arm()
		COA_RECOMPOSE.timer = 0.5
		COA_RECOMPOSE.shots = 3
	end
	local oldRace = SetCharacterRace
	function SetCharacterRace(...)
		local a, b, c, d, e = oldRace(...)
		arm()
		return a, b, c, d, e
	end
	local oldSex = SetSelectedSex
	if oldSex then
		function SetSelectedSex(...)
			local a, b, c = oldSex(...)
			arm()
			return a, b, c
		end
	end
end
"""
    src = src.rstrip() + nl + nl + lua.replace('\n', nl)
    open(p, 'wb').write(src.encode('utf-8'))
    print('recomposite safety net applied')


# Medviten/mod-worgoblin-high-elf races (AGPL-3.0): Dark Iron Dwarf 48, Mag'har Orc 49, Ogre 53
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
nl = '\r\n' if '\r\n' in src else '\n'
MKEY = '-- Local server: Medviten races'
if MKEY not in src:
    code = (MKEY + nl
            + 'CHAR_CREATE_RACE_IDS["Dark Iron Dwarf"] = {48}' + nl
            + 'CHAR_CREATE_RACE_IDS["Mag\'har Orc"] = {49}' + nl
            + 'CHAR_CREATE_RACE_IDS["Ogre"] = {53}' + nl
            + 'if CHAR_CREATE_EXTRA_RACE_ICONS then' + nl
            + '\tCHAR_CREATE_EXTRA_RACE_ICONS["Dark Iron Dwarf"] = "Interface\\\\Icons\\\\INV_Misc_Head_Dwarf_01"' + nl
            + '\tCHAR_CREATE_EXTRA_RACE_ICONS["Mag\'har Orc"] = "Interface\\\\Icons\\\\Achievement_Character_Orc_Male"' + nl
            + '\tCHAR_CREATE_EXTRA_RACE_ICONS["Ogre"] = "Interface\\\\Icons\\\\Achievement_Boss_GruulTheDragonkiller"' + nl
            + 'end' + nl)
    src = src.rstrip() + nl + nl + code
    open(p, 'wb').write(src.encode('utf-8'))
    print('Medviten races lua patch applied')
p = 'out/Interface/GlueXML/GlueParent.lua'
glue = open(p, 'rb').read().decode('utf-8')
GKEY = '-- Local server: Medviten race backgrounds'
if GKEY not in glue:
    a = '\t["DRAKKARITROLL"] = "TROLL", ["TROGLODYTE"] = "GNOME",'
    assert a in glue
    glue = glue.replace(a, a + ' ' + GKEY + nl + '\t["DARKIRONDWARF"] = "DWARF", ["MAGHAR"] = "ORC", ["OGRE"] = "ORC",', 1)
    open(p, 'wb').write(glue.encode('utf-8'))
    print('Medviten race backgrounds applied')


# Compact race list: smaller buttons (scale 0.8), 10 per column, room for many more races
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
if 'local perColumn, columnWidth, rowHeight = 7, 170, 66' in src:
    src = src.replace('local perColumn, columnWidth, rowHeight = 7, 170, 66', 'local perColumn, columnWidth, rowHeight, scale = 10, 150, 50, 0.8', 1)
    src = src.replace('32 + column * columnWidth, -75 - row * rowHeight)', '(28 + column * columnWidth) / scale, (-70 - row * rowHeight) / scale)', 1)
    src = src.replace('-32 - column * columnWidth, -75 - row * rowHeight)', '(-28 - column * columnWidth) / scale, (-70 - row * rowHeight) / scale)', 1)
    src = src.replace(chr(9) * 2 + 'button:ClearAllPoints()', chr(9) * 2 + 'button:SetScale(scale)' + nl + chr(9) * 2 + 'button:ClearAllPoints()', 1)
    open(p, 'wb').write(src.encode('utf-8'))
    print('compact race layout applied')


# Undead Gnome (51): our own race, Gnome model with undead skins
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
nl = '\r\n' if '\r\n' in src else '\n'
UKEY = '-- Local server: Undead Gnome'
if UKEY not in src:
    bs = chr(92) * 2
    code = (UKEY + nl + 'CHAR_CREATE_RACE_IDS["Undead Gnome"] = {51}' + nl
            + 'if CHAR_CREATE_EXTRA_RACE_ICONS then CHAR_CREATE_EXTRA_RACE_ICONS["Undead Gnome"] = "Interface' + bs + 'Icons' + bs
            + 'Achievement_Character_Gnome_Male" end' + nl)
    src = src.rstrip() + nl + nl + code
    open(p, 'wb').write(src.encode('utf-8'))
    print('Undead Gnome lua patch applied')
p = 'out/Interface/GlueXML/GlueParent.lua'
glue = open(p, 'rb').read().decode('utf-8')
UGKEY = '-- Local server: Undead Gnome background'
if UGKEY not in glue:
    a = '\t["DRAKKARITROLL"] = "TROLL", ["TROGLODYTE"] = "GNOME",'
    glue = glue.replace(a, a + ' ' + UGKEY + nl + '\t["GNOMEUNDEAD"] = "SCOURGE",', 1)
    open(p, 'wb').write(glue.encode('utf-8'))
    print('Undead Gnome background applied')


# creature races (C:/CoA-Build/creatures): Vampyr 54, Eredar 55, Harpy 56
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
nl = '\r\n' if '\r\n' in src else '\n'
CKEY = '-- Local server: creature races'
if CKEY not in src:
    bs = chr(92) * 2
    icons = {'Vampyr': 'Spell_Shadow_VampiricAura', 'Eredar': 'Spell_Fire_FelFlameRing', 'Harpy': 'INV_Feather_04'}
    code = CKEY + nl
    for name, rid in (('Vampyr', 54), ('Eredar', 55), ('Harpy', 56)):
        code += 'CHAR_CREATE_RACE_IDS["%s"] = {%d}' % (name, rid) + nl
        code += ('if CHAR_CREATE_EXTRA_RACE_ICONS then CHAR_CREATE_EXTRA_RACE_ICONS["%s"] = "Interface%sIcons%s%s" end'
                 % (name, bs, bs, icons[name])) + nl
    src = src.rstrip() + nl + nl + code
    open(p, 'wb').write(src.encode('utf-8'))
    print('creature races lua patch applied')
p = 'out/Interface/GlueXML/GlueParent.lua'
glue = open(p, 'rb').read().decode('utf-8')
CGKEY = '-- Local server: creature race backgrounds'
if CGKEY not in glue:
    a = '\t["DRAKKARITROLL"] = "TROLL", ["TROGLODYTE"] = "GNOME",'
    glue = glue.replace(a, a + ' ' + CGKEY + nl + '\t["VAMPYR"] = "BLOODELF", ["EREDAR"] = "DRAENEI", ["HARPY"] = "TAUREN",', 1)
    open(p, 'wb').write(glue.encode('utf-8'))
    print('creature race backgrounds applied')


# Eunoia races back (2026-10-07, the creator's approval): Dracthyr 52/58, Void Elf 59, Illidari 60/61, Lightforged 62,
# Nightborne 63. Credits: Furioz, Corruption, Eunoia.
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
nl = '\r\n' if '\r\n' in src else '\n'
EKEY = '-- Local server: Eunoia races (back)'
if EKEY not in src:
    bs = chr(92) * 2
    ids = {'Dracthyr': '54, 58', 'Void Elf': '59', 'Illidari Night Elf': '61', 'Illidari Blood Elf': '60',
           'Lightforged Draenei': '62', 'Nightborne': '63'}
    icons = {'Dracthyr': 'INV_Misc_Head_Dragon_Bronze', 'Void Elf': 'Spell_Shadow_ShadowWordPain',
             'Illidari Night Elf': 'Achievement_Boss_Illidan', 'Illidari Blood Elf': 'Achievement_Boss_Illidan',
             'Lightforged Draenei': 'Spell_Holy_SurgeOfLight', 'Nightborne': 'Spell_Arcane_StarFire'}
    code = EKEY + nl
    for name in ids:
        code += 'CHAR_CREATE_RACE_IDS["%s"] = {%s}' % (name, ids[name]) + nl
        code += ('if CHAR_CREATE_EXTRA_RACE_ICONS then CHAR_CREATE_EXTRA_RACE_ICONS["%s"] = "Interface%sIcons%s%s" end'
                 % (name, bs, bs, icons[name])) + nl
    src = src.rstrip() + nl + nl + code
    open(p, 'wb').write(src.encode('utf-8'))
    print('Eunoia races lua patch applied')
p = 'out/Interface/GlueXML/GlueParent.lua'
glue = open(p, 'rb').read().decode('utf-8')
EGKEY = '-- Local server: Eunoia race backgrounds (back)'
if EGKEY not in glue:
    a = '\t["DRAKKARITROLL"] = "TROLL", ["TROGLODYTE"] = "GNOME",'
    glue = glue.replace(a, a + ' ' + EGKEY + nl + '\t["NIGHTBORNE"] = "NIGHTELF", ["VOIDELF"] = "BLOODELF", '
                        '["DRACTHYR"] = "BLOODELF", ["LIGHTFORGED"] = "DRAENEI", ["NIGHTELF_DH"] = "NIGHTELF", '
                        '["BLOODELF_DH"] = "BLOODELF",', 1)
    open(p, 'wb').write(glue.encode('utf-8'))
    print('Eunoia race backgrounds applied')


# 63 race ids in use: a button for every one (48 left race 49+ without a button: nil index at CharacterCreate.lua:1989)
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
if 'MAX_RACES = 48;' in src:
    open(p, 'wb').write(src.replace('MAX_RACES = 48;', 'MAX_RACES = 64;', 1).encode('utf-8'))
    print('MAX_RACES = 64')


# Eunoia's Broken has a female body (2026-10-07): not a male-only race
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
src2 = src.replace(chr(9) + '["Broken"] = true, ["Fel Orc"] = true,', chr(9) + '["Fel Orc"] = true,', 1)
if src2 != src:
    open(p, 'wb').write(src2.encode('utf-8')); print('Broken not male-only')


# Esteria races (Kalibros | Lord of Wen) on ids 66+: Skyborne Windshaper 72 (Horde), High Order 77 (Alliance)
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
nl = '\r\n' if '\r\n' in src else '\n'
SKEY = '-- Local server: Esteria races (2)'
if SKEY not in src:
    bs = chr(92) * 2
    races = (('Mechagnome', 67, 'INV_Misc_Gear_08'),)   # Skyborne 72/77 removed 2026-10-07 (client crash)
    code = SKEY + nl
    for name, rid, icon in races:
        code += 'CHAR_CREATE_RACE_IDS["%s"] = {%d}' % (name, rid) + nl
        code += ('if CHAR_CREATE_EXTRA_RACE_ICONS then CHAR_CREATE_EXTRA_RACE_ICONS["%s"] = "Interface%sIcons%s%s" end'
                 % (name, bs, bs, icon)) + nl
    src = src.rstrip() + nl + nl + code
    open(p, 'wb').write(src.encode('utf-8'))
    print('Esteria races lua patch applied')
p = 'out/Interface/GlueXML/GlueParent.lua'
glue = open(p, 'rb').read().decode('utf-8')
SGKEY = '-- Local server: Esteria race backgrounds (2)'
if SGKEY not in glue:
    a = '\t["DRAKKARITROLL"] = "TROLL", ["TROGLODYTE"] = "GNOME",'
    glue = glue.replace(a, a + ' ' + SGKEY + nl + '\t["SKYBORNE"] = "BLOODELF", ["SKYBORNEHORDE"] = "BLOODELF",', 1)
    open(p, 'wb').write(glue.encode('utf-8'))
    print('Esteria race backgrounds applied')


# race ids above 63 (128-race dinput8): every id up to 127 gets a button slot
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
if 'MAX_RACES = 64;' in src:
    open(p, 'wb').write(src.replace('MAX_RACES = 64;', 'MAX_RACES = 128;', 1).encode('utf-8'))
    print('MAX_RACES = 128')


# Esteria races with their own appearance data (server 6th byte / uint64): Highmountain 66, Earthen 68/69,
# Haranir 70/71, Vulpera 74. Earthen and Vulpera buttons now create Esteria's versions (old ids 27/19 still load).
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
nl = chr(13) + chr(10) if chr(13) + chr(10) in src else chr(10)
NKEY = '-- Local server: Esteria native races'
if NKEY not in src:
    bs = chr(92) * 2
    races = (('Highmountain Tauren', '66', 'Achievement_Character_Tauren_Male'), ('Earthen', '68, 69', None),
             ('Haranir', '71, 70', 'INV_Misc_Herb_19'), ('Vulpera', '74', None))
    code = NKEY + nl
    for name, ids, icon in races:
        code += 'CHAR_CREATE_RACE_IDS["%s"] = {%s}' % (name, ids) + nl
        if icon:
            code += ('if CHAR_CREATE_EXTRA_RACE_ICONS then CHAR_CREATE_EXTRA_RACE_ICONS["%s"] = "Interface%sIcons%s%s" end'
                     % (name, bs, bs, icon)) + nl
    src = src.rstrip() + nl + nl + code
    open(p, 'wb').write(src.encode('utf-8'))
    print('Esteria native races lua patch applied')
p = 'out/Interface/GlueXML/GlueParent.lua'
glue = open(p, 'rb').read().decode('utf-8')
NGKEY = '-- Local server: Esteria native race backgrounds'
if NGKEY not in glue:
    a = '	["DRAKKARITROLL"] = "TROLL", ["TROGLODYTE"] = "GNOME",'
    glue = glue.replace(a, a + ' ' + NGKEY + nl + '	["HIGHMOUNTAINTAUREN"] = "TAUREN", ["EARTHEN"] = "DWARF", '
                        '["EARTHENHORDE"] = "DWARF", ["HARANIR"] = "NIGHTELF", ["HARANIRHORDE"] = "NIGHTELF", '
                        '["VULPERAESTERIA"] = "TROLL",', 1)
    open(p, 'wb').write(glue.encode('utf-8'))
    print('Esteria native race backgrounds applied')


# Mechagnome background: its file string had no entry (PlayGlueAmbience error at GlueParent.lua:535)
p = 'out/Interface/GlueXML/GlueParent.lua'
glue = open(p, 'rb').read().decode('utf-8')
MGKEY = '-- Local server: Mechagnome background'
if MGKEY not in glue:
    a = chr(9) + '["DRAKKARITROLL"] = "TROLL", ["TROGLODYTE"] = "GNOME",'
    nl = chr(13) + chr(10) if chr(13) + chr(10) in glue else chr(10)
    glue = glue.replace(a, a + ' ' + MGKEY + nl + chr(9) + '["MECHAGNOME"] = "GNOME",', 1)
    open(p, 'wb').write(glue.encode('utf-8'))
    print('Mechagnome background applied')


# Esteria's extra customization rows for the Esteria races only (C:/CoA-Build/esteria/esteria_options.lua)
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
OKEY = '-- Local server: Esteria native appearance controls'
if True:                                    # always the current version: it is the last block of the file
    if OKEY in src:
        src = src[:src.index(OKEY)].rstrip()
    nl = chr(13) + chr(10) if chr(13) + chr(10) in src else chr(10)
    block = open('C:/CoA-Build/esteria/esteria_options.lua', encoding='utf-8').read().replace(chr(10), nl)
    src = src.rstrip() + nl + nl + block
    open(p, 'wb').write(src.encode('utf-8'))
    print('Esteria appearance controls applied')


# Esteria's Highmountain Tauren keeps its real size: the creation camera steps back for it (oversized race camera)
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
a = 'CHAR_CREATE_BIG_RACES = { ["Vrykul"] = 1.8 }'
if a in src:
    pass                                    # 2026-10-08: moved to the Customize camera (esteria_options.lua)
    open(p, 'wb').write(src.encode('utf-8'))
    print('Highmountain camera applied')


# CoA Custom 1.4: bonus racial line on the creation screen for the races above 32 (server: CoaBonusRacials in
# ObjectMgr.cpp, by exact race id)
p = 'out/Interface/GlueXML/CharacterCreate.lua'
src = open(p, 'rb').read().decode('utf-8')
BKEY = '-- Local server: bonus racial of the races above 32'
if BKEY in src:
    a = src.index(BKEY)
    b = src.index('-- end bonus racial of the races above 32', a)
    src = src[:a] + src[b + len('-- end bonus racial of the races above 32'):]
nl = chr(13) + chr(10) if chr(13) + chr(10) in src else chr(10)
BONUS = {32: ('NIGHTELF', 1, 'Shadowmeld'), 47: ('ORC', 1, 'Blood Fury'), 48: ('ORC', 1, 'Blood Fury'),
         49: ('TROLL', 1, 'Berserking'), 50: ('NIGHTELF', 1, 'Shadowmeld'), 51: ('GNOME', 1, 'Escape Artist'),
         53: ('TAUREN', 1, 'War Stomp'), 54: ('TAUREN', 1, 'War Stomp'), 55: ('BLOODELF', 3, 'Arcane Torrent'),
         56: ('GNOME', 1, 'Escape Artist'), 57: ('GNOME', 1, 'Escape Artist'), 58: ('TAUREN', 1, 'War Stomp'),
         59: ('NIGHTELF', 1, 'Shadowmeld'), 60: ('TROLL', 1, 'Berserking'), 61: ('BLOODELF', 3, 'Arcane Torrent'),
         62: ('HUMAN', 5, 'Every Man for Himself'), 63: ('BLOODELF', 3, 'Arcane Torrent'), 66: ('DWARF', 1, 'Stoneform'),
         67: ('DWARF', 1, 'Stoneform'), 68: ('TAUREN', 1, 'War Stomp'), 69: ('TAUREN', 1, 'War Stomp'),
         70: ('TROLL', 1, 'Berserking'), 71: ('TROLL', 1, 'Berserking'), 74: ('GNOME', 1, 'Escape Artist')}
code = BKEY + nl + 'if CHAR_CREATE_RACE_BONUS then' + nl
for race, (source, index, name) in sorted(BONUS.items()):
    code += chr(9) + 'CHAR_CREATE_RACE_BONUS[%d] = {"%s", %d, "%s"}' % (race, source, index, name) + nl
code += 'end' + nl + '-- end bonus racial of the races above 32' + nl
k = src.index('-- Local server: Esteria native appearance controls') if '-- Local server: Esteria native appearance controls' in src else len(src)
src = src[:k].rstrip() + nl + nl + code + nl + src[k:]
open(p, 'wb').write(src.encode('utf-8'))
print('bonus racial lines applied')
