-- Dev Menu, part 5: Combat tab in Selected NPC (auto attack + spells it casts in combat, via SmartAI rows)
local D = CoADev
local C, Text, Tip, Button, Edit, Header, MakeList, Send, Toast, S, H = D.C, D.Text, D.Tip, D.Button, D.Edit, D.Header, D.MakeList, D.Send, D.Toast, D.S, D.H
local f = S.subs.combat
local function G() return S.selected and S.selected.guid end
local function Lbl(t, x, y) local l = Text(f, 10, C.dim); l:SetPoint("TOPLEFT", x, y); l:SetText(t); return l end

local cur = {}   -- last CB reply: min, max, speed, mod

-- ---- auto attack
Header(f, "Auto attack"):SetPoint("TOPLEFT", 14, -12)
local now = Text(f, 11, C.text); now:SetPoint("TOPLEFT", 14, -32); now:SetWidth(700)
Lbl("Damage per hit (average)", 14, -54); local eDmg = Edit(f, 90, 24, true); eDmg:SetPoint("TOPLEFT", 14, -68)
Lbl("Attack speed (seconds)", 150, -54); local eSpd = Edit(f, 70, 24); eSpd:SetPoint("TOPLEFT", 150, -68)
Lbl("Damage multiplier", 270, -54); local eMod = Edit(f, 70, 24); eMod:SetPoint("TOPLEFT", 270, -68)
local bApply = Button(f, "Apply", 90, 24, "accent", function()
    if not G() or not cur.mod then return end
    local mod = tonumber(eMod:GetText()) or cur.mod
    local want = tonumber(eDmg:GetText())
    local avg = (cur.min + cur.max) / 2
    if want and avg > 0 and math.abs(want - avg) >= 1 then mod = cur.mod * want / avg end   -- damage = level base x multiplier
    if math.abs(mod - cur.mod) > 0.001 then Send("TSET", G(), "damage", string.format("%.3f", mod), 0) end
    local spd = tonumber(eSpd:GetText())
    if spd and spd > 0 and math.floor(spd * 1000 + 0.5) ~= cur.speed then Send("TSET", G(), "attacktime", math.floor(spd * 1000 + 0.5), 0) end
    Send("CGET", G())
end)
bApply:SetPoint("TOPLEFT", 360, -68)
Tip(bApply, "Apply", "Type the damage you want per hit: the multiplier is worked out for you. Saved on the NPC type (every spawn of it). Use Identity > Make unique first to change one spawn only.")

-- ---- spells it casts
Header(f, "Spells in combat"):SetPoint("TOPLEFT", 14, -106)
local aiNote = Text(f, 10, C.dim); aiNote:SetPoint("TOPLEFT", 150, -110); aiNote:SetWidth(560)
local TGT = { [2] = "current target", [1] = "itself", [5] = "random enemy" }
local mine
mine = MakeList(f, 5, 22, { { w = 50, color = C.dim }, { w = 230 }, { w = 150, size = 10 }, { w = 110, size = 10 }, { w = 60, size = 10 } }, function(d) f.selRow = d; mine:Refresh() end)
mine:SetPoint("TOPLEFT", 14, -126); mine:SetPoint("TOPRIGHT", -14, -126); mine:SetHeight(112)
mine.format = function(d)
    local every = (d.rmin / 1000) .. (d.rmax ~= d.rmin and ("-" .. d.rmax / 1000) or "")
    return { d.spell, d.name, "every " .. every .. "s, first " .. d.first / 1000 .. "s", "on " .. (TGT[d.tgt] or d.tgt), d.chance .. "%" }
end
mine.isSelected = function(d) return d == f.selRow end
local bDel = Button(f, "Remove selected", 130, 22, "danger", function()
    if not f.selRow or not G() then return Toast("Click a spell in the list first", "err") end
    Send("CDEL", G(), f.selRow.id); f.selRow = nil
end)
bDel:SetPoint("TOPRIGHT", mine, "BOTTOMRIGHT", 0, -4)

-- ---- add a spell: search every spell on the server, or what another NPC casts
Lbl("Find a spell: name or id, or  npc:<entry>  for what another mob casts", 14, -246)
local eFind = Edit(f, 300, 24); eFind:SetPoint("TOPLEFT", 14, -260); eFind:SetPlaceholder("e.g. fireball, 133, npc:448  (Enter)")
local page, total = 0, 0
local found
found = MakeList(f, 6, 20, { { w = 55, color = C.dim }, { w = 250 }, { w = 70, size = 10 }, { w = 50, size = 10 } }, function(d) f.pick = d; found:Refresh() end)
found:SetPoint("TOPLEFT", 14, -290); found:SetSize(450, 124)
found.format = function(d) return { d.id, d.name, d.cast == 0 and "instant" or (d.cast / 1000 .. "s cast"), d.range .. " yd" } end
found.isSelected = function(d) return d == f.pick end
local pageTxt = Text(f, 10, C.dim); pageTxt:SetPoint("TOPLEFT", found, "BOTTOMLEFT", 0, -6)
local function Search(pg) page = pg or 0; found.data = {}; found.offset = 0; f.pick = nil; Send("SPSEARCH", eFind:GetText(), page) end
eFind:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Search(0) end)
local bPrev = Button(f, "<", 24, 20, nil, function() if page > 0 then Search(page - 1) end end); bPrev:SetPoint("TOPRIGHT", found, "BOTTOMRIGHT", -28, -2)
local bNext = Button(f, ">", 24, 20, nil, function() if (page + 1) * 30 < total then Search(page + 1) end end); bNext:SetPoint("LEFT", bPrev, "RIGHT", 4, 0)

local x0 = 480
Lbl("First cast after (s)", x0, -290); local eFirst = Edit(f, 60, 22); eFirst:SetPoint("TOPLEFT", x0, -304); eFirst:SetText("3")
Lbl("Repeat every (s): min / max", x0, -330); local eMin = Edit(f, 50, 22); eMin:SetPoint("TOPLEFT", x0, -344); eMin:SetText("10")
local eMax = Edit(f, 50, 22); eMax:SetPoint("LEFT", eMin, "RIGHT", 6, 0); eMax:SetText("15")
Lbl("Chance %", x0 + 130, -330); local eCh = Edit(f, 50, 22, true); eCh:SetPoint("TOPLEFT", x0 + 130, -344); eCh:SetText("100")
local tgt = 2
local tBtn
tBtn = Button(f, "Cast on: current target", 200, 22, nil, function()
    tgt = tgt == 2 and 1 or tgt == 1 and 5 or 2
    tBtn:SetText("Cast on: " .. TGT[tgt])
end)
tBtn:SetPoint("TOPLEFT", x0, -372)
local bAdd = Button(f, "Add to NPC", 200, 26, "accent", function()
    if not G() then return end
    if not f.pick then return Toast("Search and click a spell first", "err") end
    local function ms(e, d) return math.floor((tonumber(e:GetText()) or d) * 1000 + 0.5) end
    Send("CADD", G(), f.pick.id, ms(eFirst, 3), ms(eMin, 10), ms(eMax, 15), tgt, tonumber(eCh:GetText()) or 100)
end)
bAdd:SetPoint("TOPLEFT", x0, -400)
Tip(bAdd, "Add to NPC", "Every NPC of this type casts it while fighting, hostile or friendly. Every copy of this NPC type nearby switches right away (one that is fighting switches after the fight).")

-- ---- replies
H.SPB = function() found.data = {} end
H.SP = function(a) found.data[#found.data + 1] = { id = a[2], name = a[3], cast = tonumber(a[4]) or 0, range = a[5] }; found:Refresh() end
H.SPE = function(a)
    total = tonumber(a[2]) or 0
    found:Refresh()
    pageTxt:SetText(total == 0 and "No spell found" or ("Page " .. (page + 1) .. " / " .. math.ceil(total / 30) .. "  (" .. total .. " spells)"))
end
H.CB = function(a)
    cur = { min = tonumber(a[3]) or 0, max = tonumber(a[4]) or 0, speed = tonumber(a[5]) or 2000, mod = tonumber(a[6]) or 1 }
    mine.data = {}; mine.offset = 0; f.selRow = nil
    now:SetText(string.format("Now: %d - %d damage per hit, one hit every %.1fs  (%.0f damage per second)",
        cur.min, cur.max, cur.speed / 1000, (cur.min + cur.max) / 2 / math.max(0.1, cur.speed / 1000)))
    if not eDmg:HasFocus() then eDmg:SetText(math.floor((cur.min + cur.max) / 2)) end
    if not eSpd:HasFocus() then eSpd:SetText(string.format("%.1f", cur.speed / 1000)) end
    if not eMod:HasFocus() then eMod:SetText(string.format("%.2f", cur.mod)) end
    aiNote:SetText(tonumber(a[7]) == 2 and "|cffff9040This NPC type has a C++ script: adding a spell switches it to SmartAI.|r" or "")
end
H.CS = function(a)
    mine.data[#mine.data + 1] = { id = a[2], spell = a[3], name = a[4], rmin = tonumber(a[5]) or 0, rmax = tonumber(a[6]) or 0, first = tonumber(a[7]) or 0, tgt = tonumber(a[8]) or 2, chance = a[9] }
    mine:Refresh()
end
H.CE = function() mine:Refresh() end

-- reload when the tab opens or the selection changes while it is open
local seen
f:HookScript("OnShow", function() seen = nil end)
f:HookScript("OnUpdate", function() if G() and G() ~= seen then seen = G(); Send("CGET", seen) end end)
