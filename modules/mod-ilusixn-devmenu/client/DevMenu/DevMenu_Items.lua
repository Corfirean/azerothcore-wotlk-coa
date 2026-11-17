-- Dev Menu, part 6: Create an item. Build an item from A to Z (look, type, stats, price, spell), preview it on yourself, make heirlooms
-- whose stats grow per level, and edit what you made before. Items live in the dev id range and are shared with Share as SQL.
local D = CoADev
local C, Text, Header, Button, Edit, Check, Tip, MakeList, Send, Toast, p, H = D.C, D.Text, D.Header, D.Button, D.Edit, D.Check, D.Tip, D.MakeList, D.Send, D.Toast, D.pages.items, D.H
local Skin, Shown = D.Skin, D.Shown

local QC = { [0] = { 0.6, 0.6, 0.6 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 }, { 0.9, 0.8, 0.5 }, { 0.9, 0.8, 0.5 } }
local scan = CreateFrame("GameTooltip", "CoADevItemMakeScan", UIParent, "GameTooltipTemplate")
scan:SetOwner(UIParent, "ANCHOR_NONE")
local function Fetch(id) if id and id > 0 and not GetItemInfo(id) then scan:SetOwner(UIParent, "ANCHOR_NONE"); scan:SetHyperlink("item:" .. id); scan:Hide() end end

local KINDS = { { "armor", "Armor" }, { "weapon", "Weapon" }, { "cons", "Consumable" }, { "other", "Other" } }
local QUAL = { { 0, "Poor" }, { 1, "Common" }, { 2, "Uncommon" }, { 3, "Rare" }, { 4, "Epic" }, { 5, "Legendary" }, { 7, "Heirloom" } }
local BOND = { { 0, "No binding" }, { 1, "Bind on pickup" }, { 2, "Bind on equip" }, { 3, "Bind on use" } }
local ASLOT = { { 1, "Head" }, { 3, "Shoulders" }, { 5, "Chest" }, { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" }, { 9, "Wrists" }, { 10, "Hands" }, { 16, "Cloak" },
    { 4, "Shirt" }, { 19, "Tabard" }, { 2, "Neck" }, { 11, "Finger" }, { 12, "Trinket" }, { 14, "Shield" }, { 23, "Held in off-hand" } }
local MAT = { { 1, "Cloth" }, { 2, "Leather" }, { 3, "Mail" }, { 4, "Plate" } }
local WTYPE = { { 7, 13, "Sword (1H)" }, { 8, 17, "Sword (2H)" }, { 0, 13, "Axe (1H)" }, { 1, 17, "Axe (2H)" }, { 4, 13, "Mace (1H)" }, { 5, 17, "Mace (2H)" },
    { 15, 13, "Dagger" }, { 13, 13, "Fist weapon" }, { 6, 17, "Polearm" }, { 10, 17, "Staff" }, { 2, 15, "Bow" }, { 3, 26, "Gun" }, { 18, 26, "Crossbow" },
    { 19, 26, "Wand" }, { 16, 25, "Thrown" } }
local STAT = { { 0, "- none -" }, { 7, "Stamina" }, { 4, "Strength" }, { 3, "Agility" }, { 5, "Intellect" }, { 6, "Spirit" }, { 45, "Spell power" }, { 38, "Attack power" },
    { 32, "Crit rating" }, { 36, "Haste rating" }, { 31, "Hit rating" }, { 37, "Expertise rating" }, { 35, "Resilience rating" }, { 12, "Defense rating" },
    { 13, "Dodge rating" }, { 14, "Parry rating" }, { 15, "Block rating" }, { 44, "Armor penetration" }, { 43, "Mana per 5 sec" }, { 46, "Health per 5 sec" },
    { 1, "Health" }, { 39, "Ranged attack power" }, { 47, "Spell penetration" } }
local TRIG = { { 1, "On equip" }, { 0, "On use" }, { 2, "Chance on hit" } }

local cur = { kind = "armor", q = 4, bond = 0, aslot = 1, mat = 4, wtype = 1, trig = 1, bound = false, heir = false }
local edits, cycles = {}, {}

-- ------------------------------------------------------------------ small builders
local function Lbl(t, x, y) local l = Text(p, 10, C.dim); l:SetPoint("TOPLEFT", x, y); l:SetText(t); return l end
local function Field(key, label, x, y, w, numeric, default)
    Lbl(label, x, y)
    local e = Edit(p, w, 22, numeric)
    e:SetPoint("TOPLEFT", x, y - 12)
    if default then e:SetText(default) end
    edits[key] = e
    return e
end
-- click = next, right click = previous
local function Cycle(key, x, y, w, list, labelOf, onChange)
    local b = Button(p, "", w, 22, nil, nil)
    b:SetPoint("TOPLEFT", x, y)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function idx() for i, it in ipairs(list) do if it[1] == cur[key] then return i end end return 1 end
    function b:Paint()
        local it = list[idx()]
        self:SetLabel(labelOf and labelOf(it) or it[#it])
        if key == "q" then local c = QC[cur.q] or QC[1]; self.label:SetTextColor(c[1], c[2], c[3]) end
    end
    b:SetScript("OnClick", function(self, btn)
        local i = idx() + (btn == "RightButton" and -1 or 1)
        if i < 1 then i = #list elseif i > #list then i = 1 end
        cur[key] = list[i][1]
        self:Paint()
        if onChange then onChange() end
    end)
    cycles[key] = b
    b:Paint()
    return b
end
local function Num(key, def) local v = tonumber(edits[key] and edits[key]:GetText()); return v or def end

-- ------------------------------------------------------------------ layout
local h = Header(p, "Create an item"); h:SetPoint("TOPLEFT", 16, -14)
local nameE = Edit(p, 330, 24); nameE:SetPoint("TOPLEFT", 16, -42); nameE:SetPlaceholder("Item name"); edits.name = nameE

Lbl("Kind", 16, -74)
local kindB
local typeB, slotB, matB
local function Layout()
    local k = cur.kind
    if k == "armor" then
        slotB:Show(); matB:Show(); typeB:Hide()
    elseif k == "weapon" then
        slotB:Hide(); matB:Hide(); typeB:Show()
    else
        slotB:Hide(); matB:Hide(); typeB:Hide()
    end
    local armor, weapon = k == "armor", k == "weapon"
    Shown(edits.armor, armor); Shown(edits.blk, armor and cur.aslot == 14)
    for _, key in ipairs({ "dmin", "dmax", "dspd" }) do Shown(edits[key], weapon) end
    for _, l in ipairs(p.labels or {}) do
        if l.only == "armor" then Shown(l, armor) elseif l.only == "weapon" then Shown(l, weapon) end
    end
    if p.updateHeir then p.updateHeir() end
end
kindB = Cycle("kind", 16, -88, 110, KINDS, nil, Layout)
slotB = Cycle("aslot", 132, -88, 130, ASLOT, nil, Layout)
matB = Cycle("mat", 268, -88, 78, MAT)
typeB = Cycle("wtype", 132, -88, 130, WTYPE, function(it) return it[3] end, Layout)
-- weapon type is stored as an index; map it back to sub/inv when saving
cur.wtype = 7
do
    local b = typeB
    local list = WTYPE
    b:SetScript("OnClick", function(self, btn)
        local i = (cur.widx or 1) + (btn == "RightButton" and -1 or 1)
        if i < 1 then i = #list elseif i > #list then i = 1 end
        cur.widx = i; cur.wtype = list[i][1]
        self:SetLabel(list[i][3])
    end)
    cur.widx = 1; b:SetLabel(list[1][3])
end

p.labels = {}
local function OnlyLbl(t, x, y, only) local l = Lbl(t, x, y); l.only = only; table.insert(p.labels, l); return l end

Lbl("Quality", 16, -118); Cycle("q", 16, -132, 110, QUAL)
Lbl("Binding", 132, -118); Cycle("bond", 132, -132, 130, BOND)
Field("ilvl", "Item level", 268, -118, 78, true, "60")
Field("rlvl", "Required level", 16, -160, 78, true, "1")
OnlyLbl("Armor", 100, -160, "armor"); local ae = Edit(p, 78, 22, true); ae:SetPoint("TOPLEFT", 100, -172); ae:SetText("0"); edits.armor = ae
OnlyLbl("Block", 184, -160, "armor"); local be = Edit(p, 78, 22, true); be:SetPoint("TOPLEFT", 184, -172); be:SetText("0"); edits.blk = be
OnlyLbl("Damage min", 100, -160, "weapon"); local dn = Edit(p, 78, 22, true); dn:SetPoint("TOPLEFT", 100, -172); dn:SetText("10"); edits.dmin = dn
OnlyLbl("Damage max", 184, -160, "weapon"); local dx = Edit(p, 78, 22, true); dx:SetPoint("TOPLEFT", 184, -172); dx:SetText("20"); edits.dmax = dx
OnlyLbl("Speed (sec)", 268, -160, "weapon"); local ds = Edit(p, 78, 22); ds:SetPoint("TOPLEFT", 268, -172); ds:SetText("2.0"); edits.dspd = ds
Field("sell", "Sell price (gold)", 16, -202, 78, false, "0")
Field("buy", "Buy price (gold)", 100, -202, 78, false, "0")
Field("stack", "Stack", 184, -202, 78, true, "1")
Field("dur", "Durability", 268, -202, 78, true, "0")

Lbl("Stats (click a stat to change it, right click goes back)", 16, -236)
local statB, statE = {}, {}
for i = 1, 6 do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local x, y = 16 + col * 176, -250 - row * 26
    cur["st" .. i] = 0
    statB[i] = Cycle("st" .. i, x, y, 112, STAT)
    local e = Edit(p, 54, 22, false); e:SetPoint("TOPLEFT", x + 116, y); e:SetText("0"); statE[i] = e
end

local spLbl = Lbl("Spell (click Find to search by name)", 16, -334)
local spE = Edit(p, 78, 22, true); spE:SetPoint("TOPLEFT", 16, -346); edits.sp = spE
Cycle("trig", 100, -346, 130, TRIG)
function p.updateSpell()
    local id = tonumber(spE:GetText())
    if id and id > 0 then spLbl:SetText("Spell: " .. (GetSpellInfo(id) or ("id " .. id))) else spLbl:SetText("Spell (click Find to search by name)") end
end
spE:HookScript("OnTextChanged", function() p.updateSpell() end)

-- spell picker (covers the form): search by name, click to use
local spp = CreateFrame("Frame", nil, p)
Skin(spp, { 0.05, 0.055, 0.07, 0.98 }, C.border)
spp:SetPoint("TOPLEFT", 16, -42); spp:SetSize(698, 470); spp:SetFrameLevel(p:GetFrameLevel() + 30); spp:Hide()
local sph = Header(spp, "Find a spell (click to use it on the item)"); sph:SetPoint("TOPLEFT", 12, -12)
local spS = Edit(spp, 300, 24); spS:SetPoint("TOPLEFT", 12, -40); spS:SetPlaceholder("Spell name or id (Enter)")
local spTotal, spWait = 0, false
local spList
local function SpRun() spList:Search(function(pg) spWait = true; Send("SPSEARCH", spS:GetText(), pg) end) end
spS:SetScript("OnEnterPressed", function(self) self:ClearFocus(); SpRun() end)
local spGo = Button(spp, "Search", 80, 24, "accent", function() SpRun() end); spGo:SetPoint("LEFT", spS, "RIGHT", 8, 0)
spList = MakeList(spp, 15, 22, { { w = 70, color = C.dim }, { w = 400 }, { w = 100, color = C.dim, right = true } }, function(d)
    spE:SetText(tostring(d.id)); spp:Hide(); p.updateSpell()
end)
spList:SetPoint("TOPLEFT", 12, -74); spList:SetSize(672, 340)
spList.format = function(d) return { tostring(d.id), d.name, d.cast > 0 and (d.cast / 1000 .. "s cast") or "instant" } end
spList.data = {}
local spPg = Text(spp, 10, C.dim); spPg:SetPoint("TOPLEFT", 12, -424)
local spX = Button(spp, "Close", 80, 24, nil, function() spp:Hide() end); spX:SetPoint("BOTTOMRIGHT", -12, 12)
local spNone = Button(spp, "No spell", 90, 24, "danger", function() spE:SetText(""); spp:Hide(); p.updateSpell() end); spNone:SetPoint("RIGHT", spX, "LEFT", -8, 0)
local oSPB, oSP, oSPE = H.SPB, H.SP, H.SPE
H.SPB = function(a) if spWait then spList:Begin(1) elseif oSPB then oSPB(a) end end
H.SP = function(a) if spWait then table.insert(spList.data, { id = tonumber(a[2]), name = a[3] or "", cast = tonumber(a[4]) or 0 }) elseif oSP then oSP(a) end end
H.SPE = function(a)
    if spWait then
        spWait = false; spTotal = tonumber(a[2]) or 0; spList.pages = math.ceil(spTotal / 30); spList:Done()
        spPg:SetText(spTotal .. " spells (scroll for more)")
    elseif oSPE then oSPE(a) end
end
local spFind = Button(p, "Find", 62, 22, nil, function() spp:Show(); if #spList.data == 0 then SpRun() end end)
spFind:SetPoint("TOPLEFT", 236, -346)
Tip(spFind, "Find a spell", "Search every spell of the server by name and pick one for the item.")
Lbl("Description", 16, -376); local descE = Edit(p, 330, 22); descE:SetPoint("TOPLEFT", 16, -390); edits.desc = descE
local boundC = Check(p, "Account bound", function(v) cur.bound = v end); boundC:SetPoint("TOPLEFT", 306, -350)

-- ------------------------------------------------------------------ heirloom
local hh = Text(p, 12, C.accent); hh:SetPoint("TOPLEFT", 16, -422); hh:SetText("HEIRLOOM")
local heirC = Check(p, "Stats grow with your level", function(v) cur.heir = v; if p.updateHeir then p.updateHeir() end end)
heirC:SetPoint("LEFT", hh, "RIGHT", 12, 0)
Tip(heirC, "Heirloom", "Made an heirloom: quality 7, account bound. You pick how many points of each stat it gains per level (decimals ok, 0.5 = one point every 2 levels). The bonus follows your level live while it is equipped, up to the max level. The tooltip says it in the description.")
local hrows = {}
for i = 1, 3 do
    cur["hs" .. i] = 0
    local x, y = 16 + (i - 1) * 118, -442
    local b = Cycle("hs" .. i, x, y, 112, STAT)
    local e = Edit(p, 54, 22, false); e:SetPoint("TOPLEFT", x, y - 26); e:SetText("0")
    local t = Text(p, 10, C.dim); t:SetPoint("LEFT", e, "RIGHT", 6, 0); t:SetText("per level")
    hrows[i] = { b = b, e = e, t = t }
end
local hmaxL = Lbl("Max level", 372 - 14, -448)
local hmax = Edit(p, 50, 22, true); hmax:SetPoint("TOPLEFT", 358, -464); hmax:SetText("80"); edits.hmax = hmax
local hpreview = Text(p, 10, C.text); hpreview:SetPoint("TOPLEFT", 16, -498); hpreview:SetWidth(400); hpreview:SetJustifyH("LEFT")
function p.updateHeir()
    local on = cur.heir
    for _, r in ipairs(hrows) do Shown(r.b, on); Shown(r.e, on); Shown(r.t, on) end
    Shown(hmax, on); Shown(hmaxL, on); Shown(hpreview, on)
    if on then
        local lv = UnitLevel("player")
        local parts = {}
        for i, r in ipairs(hrows) do
            local per = tonumber(r.e:GetText()) or 0
            local st = cur["hs" .. i]
            if per > 0 and (st ~= 0 or i == 1) then
                for _, s in ipairs(STAT) do if s[1] == st then table.insert(parts, ("+%d %s"):format(math.floor(per * math.min(lv, tonumber(hmax:GetText()) or 80)), s[2])) end end
            end
        end
        hpreview:SetText(#parts > 0 and ("At your level (" .. lv .. "): " .. table.concat(parts, ", ")) or "Pick a stat and how much it gains per level.")
    end
end
for _, r in ipairs(hrows) do r.e:SetScript("OnTextChanged", function() p.updateHeir() end) end
hmax:SetScript("OnTextChanged", function() p.updateHeir() end)

-- ------------------------------------------------------------------ the look (right side)
local lookH = Header(p, "Look"); lookH:SetPoint("TOPLEFT", 372 + 70, -14)
local dispE = Edit(p, 70, 22, true); dispE:SetPoint("TOPLEFT", 372 + 70, -42); edits.disp = dispE; dispE:SetPlaceholder("display id")
local lookName = Text(p, 10, C.dim); lookName:SetPoint("LEFT", dispE, "RIGHT", 8, 0); lookName:SetWidth(120); lookName:SetJustifyH("LEFT"); lookName:SetText("or pick an item below")
local lookIcon = p:CreateTexture(nil, "ARTWORK"); lookIcon:SetSize(34, 34); lookIcon:SetPoint("TOPRIGHT", p, "TOPRIGHT", -20, -36)
lookIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); lookIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local lookIconL = Text(p, 9, C.dim); lookIconL:SetPoint("TOP", lookIcon, "BOTTOM", 0, -1); lookIconL:SetText("icon")
local function IconOf(id)
    if not id or id <= 0 then return nil end
    local tex = select(10, GetItemInfo(id))
    if not tex then Fetch(id) end
    return tex
end
-- icons in the rows of a list (placed at the right of the row); refreshed a few times while the client loads the items
local iconLists = {}
local iconPoll = CreateFrame("Frame"); iconPoll:Hide()
iconPoll:SetScript("OnUpdate", function(self, el)
    self.t = (self.t or 0) + el
    if self.t < 0.7 then return end
    self.t = 0; self.n = (self.n or 0) + 1
    for _, L in ipairs(iconLists) do if L:IsVisible() then L:Refresh() end end
    if self.n >= 5 then self:Hide() end
end)
local function RowIcons(L, getId, x, extra)
    local orig = L.Refresh
    iconLists[#iconLists + 1] = L
    L.Refresh = function(self)
        orig(self)
        for i, r in ipairs(self.rows) do
            if not r.ic then
                r.ic = r:CreateTexture(nil, "OVERLAY"); r.ic:SetSize(18, 18); r.ic:SetPoint("RIGHT", x, 0); r.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            local d = self.data[self.offset + i]
            local tex = d and IconOf(getId(d))
            r.ic:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
            Shown(r.ic, d ~= nil)
            if extra then extra(r, d) end
        end
        iconPoll.n = 0; iconPoll:Show()
    end
end
local model = CreateFrame("DressUpModel", nil, p)
model:SetPoint("TOPLEFT", 372 + 70, -72); model:SetSize(250, 168)
local mbg = p:CreateTexture(nil, "BACKGROUND", nil, 1)
mbg:SetTexture(D.WHITE); mbg:SetPoint("TOPLEFT", model); mbg:SetPoint("BOTTOMRIGHT", model)
mbg:SetGradientAlpha("VERTICAL", 0.02, 0.02, 0.03, 1, 0.12, 0.12, 0.16, 1)
local facing, drag, dragX = 0, false, 0
model:EnableMouse(true)
model:SetScript("OnMouseDown", function() drag = true; dragX = GetCursorPosition() end)
model:SetScript("OnMouseUp", function() drag = false end)
model:SetScript("OnUpdate", function(self) if drag then local x = GetCursorPosition(); facing = facing + (x - dragX) * 0.02; dragX = x; self:SetFacing(facing) end end)
local lookItem
local function DressLook()
    model:SetUnit("player"); model:Undress()
    if lookItem then model:TryOn("item:" .. lookItem) end
    model:SetFacing(facing)
end
p.DressLook = DressLook

local srch = Edit(p, 190, 22); srch:SetPoint("TOPLEFT", 372 + 70, -282); srch:SetPlaceholder("Search items for a look")
local results, spage, spages = {}, 0, 1
local function SlotIndex()
    local k = cur.kind
    if k == "armor" then
        local m = { [1] = 0, [3] = 1, [4] = 2, [5] = 3, [6] = 4, [7] = 5, [8] = 6, [9] = 7, [10] = 8, [16] = 9, [19] = 10, [14] = 12, [23] = 12 }
        return m[cur.aslot] or 14
    elseif k == "weapon" then
        local inv = 13
        for _, w in ipairs(WTYPE) do if w[1] == cur.wtype then inv = w[2] end end
        return (inv == 15 or inv == 26 or inv == 25) and 13 or 11
    end
    return 14
end
local iconMode   -- an icon name while the list shows items that use that icon
local list = MakeList(p, 8, 22, { { w = 150 }, { w = 40, color = C.dim, right = true } }, function(d)
    lookItem = d.id; dispE:SetText(tostring(d.disp)); lookName:SetText(d.name)
    lookIcon:SetTexture(iconMode and ("Interface\\Icons\\" .. iconMode) or IconOf(d.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
    Fetch(d.id); DressLook()
end)
list:SetPoint("TOPLEFT", 372 + 70, -312); list:SetSize(250, 180)
list.format = function(d) return { d.name, tostring(d.id):sub(1, 6) } end
RowIcons(list, function(d) return d.id end, -4)
list.data = {}
local waiting = false
local function Run()
    list:Search(function(pg)
        waiting = true
        if iconMode then Send("ICONSEARCH", iconMode, pg) else Send("ISEARCH", srch:GetText(), SlotIndex(), pg, "", 1, 1) end
    end)
end
srch:SetScript("OnEnterPressed", function(self) self:ClearFocus(); iconMode = nil; Run() end)
dispE:SetScript("OnEnterPressed", function(self) self:ClearFocus(); lookItem = nil; lookName:SetText("display " .. self:GetText()) end)

-- the look search shares the replies of the wardrobe: only take them while this page asked
local oldIB, oldIR, oldIE = H.IB, H.IR, H.IE
H.IB = function(a) if waiting then list:Begin(a[4]) elseif oldIB then oldIB(a) end end
H.IR = function(a)
    if waiting then Fetch(tonumber(a[2])); table.insert(list.data, { id = tonumber(a[2]), name = a[3] or "", q = tonumber(a[4]) or 1, disp = tonumber(a[5]) or 0 })
    elseif oldIR then oldIR(a) end
end
H.IE = function(a)
    if waiting then waiting = false; list:Done() elseif oldIE then oldIE(a) end
end

-- ------------------------------------------------------------------ build the request, save, list
local function Gold(v) return math.floor((tonumber(v) or 0) * 10000 + 0.5) end
local function Clean(s) return (tostring(s or ""):gsub("[;=~|\t\n]", " ")) end
local function Spec()
    local k, t = cur.kind, {}
    local function put(key, v) table.insert(t, key .. "=" .. tostring(v)) end
    put("id", cur.id or 0); put("name", Clean(nameE:GetText())); put("desc", Clean(descE:GetText()))
    put("q", cur.heir and 7 or cur.q); put("bond", cur.bond); put("ilvl", Num("ilvl", 1)); put("rlvl", Num("rlvl", 0))
    put("sell", Gold(edits.sell:GetText())); put("buy", Gold(edits.buy:GetText())); put("stack", Num("stack", 1)); put("dur", Num("dur", 0))
    put("disp", Num("disp", 0)); put("bound", (cur.bound or cur.heir) and 1 or 0)
    if k == "armor" then
        put("cls", 4); put("inv", cur.aslot)
        local sub = ({ [1] = cur.mat, [3] = cur.mat, [5] = cur.mat, [6] = cur.mat, [7] = cur.mat, [8] = cur.mat, [9] = cur.mat, [10] = cur.mat, [16] = 1, [14] = 6 })[cur.aslot] or 0
        put("sub", sub); put("armor", Num("armor", 0)); put("blk", Num("blk", 0))
    elseif k == "weapon" then
        local w = WTYPE[cur.widx or 1]
        put("cls", 2); put("sub", w[1]); put("inv", w[2])
        put("dmin", Num("dmin", 1)); put("dmax", Num("dmax", 2)); put("dspd", math.floor((tonumber(edits.dspd:GetText()) or 2) * 1000 + 0.5)); put("sheath", w[2] == 17 and 1 or 3)
    elseif k == "cons" then
        put("cls", 0); put("sub", 0); put("inv", 0)
    else
        put("cls", 15); put("sub", 0); put("inv", 0)
    end
    local n = 0
    for i = 1, 6 do
        local st, v = cur["st" .. i], tonumber(statE[i]:GetText()) or 0
        if st ~= 0 and v ~= 0 then n = n + 1; put("s" .. n, st .. ":" .. math.floor(v)) end
    end
    if Num("sp", 0) > 0 then put("sp", Num("sp", 0)); put("spt", cur.trig) end
    if cur.heir then
        local hv = {}
        for i, r in ipairs(hrows) do
            local per, st = tonumber(r.e:GetText()) or 0, cur["hs" .. i]
            if per > 0 and st ~= 0 then table.insert(hv, st .. ":" .. per) end
        end
        put("hv", table.concat(hv, ",")); put("hmax", Num("hmax", 80))
    end
    return table.concat(t, ";")
end
local function Chunked(s)
    Send("BUFC")
    for i = 1, #s, 200 do Send("BUF", s:sub(i, i + 199)) end
end

local saveB
local function Reset()
    cur.id = nil
    nameE:SetText(""); descE:SetText(""); spE:SetText("")
    for _, k in ipairs({ "sell", "buy", "dur" }) do edits[k]:SetText("0") end
    for i = 1, 6 do cur["st" .. i] = 0; statE[i]:SetText("0"); statB[i]:Paint() end
    for i = 1, 3 do cur["hs" .. i] = 0; hrows[i].e:SetText("0"); hrows[i].b:Paint() end
    cur.heir = false; heirC:Set(false); cur.bound = false; boundC:Set(false)
    lookItem = nil; dispE:SetText(""); lookName:SetText("or pick an item below"); lookIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); DressLook(); p.updateSpell()
    saveB:SetLabel("Create item"); Layout()
end
saveB = Button(p, "Create item", 130, 30, "accent", function()
    if nameE:GetText() == "" then return Toast("Give the item a name first", "err") end
    Chunked(Spec()); Send("IMAKE")
end)
saveB:SetPoint("TOPLEFT", 16, -526)
local newB = Button(p, "New item", 90, 30, nil, Reset); newB:SetPoint("LEFT", saveB, "RIGHT", 8, 0)
local giveB = Button(p, "Give me one", 110, 30, nil, function() if cur.id then Send("IGIVE", cur.id, 1) else Toast("Create the item first", "err") end end)
giveB:SetPoint("LEFT", newB, "RIGHT", 8, 0)
Tip(giveB, "Give me one", "Puts the item in your bags so you can try it on and read the tooltip. Heirloom bonuses apply while it is equipped.")
local myB
local idText = Text(p, 10, C.dim); idText:SetPoint("LEFT", giveB, "RIGHT", 10, 0)

-- my items (edit what you made)
local mine = CreateFrame("Frame", nil, p)
Skin(mine, { 0.05, 0.055, 0.07, 0.98 }, C.border)
mine:SetPoint("TOPLEFT", 16, -42); mine:SetSize(698, 470); mine:SetFrameLevel(p:GetFrameLevel() + 20); mine:Hide()
local mh = Header(mine, "Items created (click a row to edit it)"); mh:SetPoint("TOPLEFT", 12, -12)
local mlist = MakeList(mine, 16, 22, { { w = 70, color = C.dim }, { w = 330 }, { w = 90, color = C.dim } }, function(d)
    mine:Hide(); Send("IGET", d.id)
end)
mlist:SetPoint("TOPLEFT", 12, -66); mlist:SetSize(672, 340)
mlist.format = function(d) return { tostring(d.id), d.name, ({ [0] = "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact", "Heirloom" })[d.q] or "" } end
mlist.data = {}
local function Favs() IlusixnDevMenuDB.itemFavs = IlusixnDevMenuDB.itemFavs or {}; return IlusixnDevMenuDB.itemFavs end
mlist.isSelected = function(d) return mlist.sel == d.id end
for i, r in ipairs(mlist.rows) do
    r:HookScript("OnClick", function() local d = mlist.data[mlist.offset + i]; if d then mlist.sel = d.id; mlist:Refresh() end end)
    local give = Button(r, "Give", 44, 18, "accent", function() local d = mlist.data[mlist.offset + i]; if d then Send("IGIVE", d.id, 1) end end)
    give:SetPoint("RIGHT", -6, 0)
    Tip(give, "Give me one", "Puts one in your bags.")
    local star = Button(r, "Fav", 34, 18, nil, function()
        local d = mlist.data[mlist.offset + i]
        if d then Favs()[d.id] = (not Favs()[d.id]) or nil; mlist:Rebuild() end
    end)
    star:SetPoint("RIGHT", give, "LEFT", -4, 0)
    r.star = star
end
RowIcons(mlist, function(d) return d.id end, -126, function(r, d)
    if d and r.star then r.star.label:SetText(Favs()[d.id] and "|cffffc840Fav|r" or "|cff777777fav|r") end
end)
local mdel = Button(mine, "Delete the selected one", 180, 26, "danger", function()
    if mlist.sel then Send("IDEL", mlist.sel); Send("ILIST") end
end)
mdel:SetPoint("BOTTOMLEFT", 12, 12)
local mclose = Button(mine, "Close", 80, 26, nil, function() mine:Hide() end); mclose:SetPoint("BOTTOMRIGHT", -12, 12)
local favOnly = false
local favC = Check(mine, "Favorites only", function(v) favOnly = v; mlist:Rebuild() end)
favC:SetPoint("TOPLEFT", 12, -42)
local mrows = {}
function mlist:Rebuild()
    local out = {}
    for _, d in ipairs(mrows) do if not favOnly or Favs()[d.id] then out[#out + 1] = d end end
    table.sort(out, function(a, b)
        local fa, fb = Favs()[a.id] and 1 or 0, Favs()[b.id] and 1 or 0
        if fa ~= fb then return fa > fb end
        return a.id > b.id
    end)
    self.data = out; self.offset = 0; self:Refresh()
end
H.ILB = function() mrows = {} end
H.ILR = function(a) table.insert(mrows, { id = tonumber(a[2]), name = a[3] or "", q = tonumber(a[4]) or 1, disp = tonumber(a[5]) or 0 }) end
H.ILE = function() mlist:Rebuild() end
H.IDL = function() Send("ILIST") end
myB = Button(p, "Items created", 110, 24, nil, function() Send("ILIST"); mine:Show() end)
myB:SetPoint("TOPRIGHT", -14, -10)

-- edit: the server sends every field back
local loading
H.IGK = function(a)
    loading = loading or {}
    loading[a[2]] = a[3] or ""
end
H.IGE = function()
    local m = loading or {}; loading = nil
    local function N(k, d) return tonumber(m[k]) or d end
    Reset()
    cur.id = N("id", nil)
    nameE:SetText(m.name or ""); descE:SetText(m.desc or "")
    local cls = N("cls", 4)
    cur.kind = cls == 4 and "armor" or cls == 2 and "weapon" or cls == 0 and "cons" or "other"
    cur.q = N("q", 4); cur.bond = N("bond", 0); cur.aslot = N("inv", 1); cur.mat = N("sub", 4)
    if cur.kind == "armor" and cur.aslot == 14 then cur.mat = 4 end
    if cur.kind == "weapon" then
        for i, w in ipairs(WTYPE) do if w[1] == N("sub", 7) then cur.widx = i; cur.wtype = w[1] end end
        typeB:SetLabel(WTYPE[cur.widx or 1][3])
    end
    for _, k in ipairs({ "kind", "q", "bond", "aslot", "mat" }) do if cycles[k] then cycles[k]:Paint() end end
    edits.ilvl:SetText(N("ilvl", 1)); edits.rlvl:SetText(N("rlvl", 0)); edits.armor:SetText(N("armor", 0)); edits.blk:SetText(N("blk", 0))
    edits.dmin:SetText(N("dmin", 0)); edits.dmax:SetText(N("dmax", 0)); edits.dspd:SetText(N("dspd", 2000) / 1000)
    edits.sell:SetText(N("sell", 0) / 10000); edits.buy:SetText(N("buy", 0) / 10000); edits.stack:SetText(N("stack", 1)); edits.dur:SetText(N("dur", 0))
    edits.disp:SetText(N("disp", 0)); lookItem = nil; lookName:SetText("display " .. N("disp", 0))
    edits.sp:SetText(N("sp", 0) > 0 and N("sp", 0) or ""); p.updateSpell(); cur.trig = N("spt", 1); if cycles.trig then cycles.trig:Paint() end
    cur.bound = N("bound", 0) == 1; boundC:Set(cur.bound)
    for i = 1, 6 do
        local s = m["s" .. i]
        if s then local t, v = s:match("(%d+):(-?%d+)"); cur["st" .. i] = tonumber(t); statE[i]:SetText(v) end
        statB[i]:Paint()
    end
    cur.heir = m.hv ~= nil and m.hv ~= ""
    heirC:Set(cur.heir)
    if cur.heir then
        local i = 0
        for part in m.hv:gmatch("[^,]+") do
            i = i + 1
            local t, per = part:match("(%d+):([%d%.]+)")
            if hrows[i] then cur["hs" .. i] = tonumber(t); hrows[i].e:SetText(per); hrows[i].b:Paint() end
        end
        edits.hmax:SetText(N("hmax", 80))
    end
    saveB:SetLabel("Save changes"); idText:SetText("Editing item " .. tostring(cur.id))
    Layout(); DressLook()
end
H.IMK = function(a)
    cur.id = tonumber(a[2]); Fetch(cur.id)
    if mine:IsShown() then Send("ILIST") end
    saveB:SetLabel("Save changes"); idText:SetText("Item " .. a[2])
    model:SetUnit("player"); model:Undress(); if cur.id then model:TryOn("item:" .. cur.id) end
end

local note = Text(p, 10, C.dim); note:SetPoint("TOPLEFT", 16, -566); note:SetWidth(690); note:SetJustifyH("LEFT")
note:SetText("Items are saved at once and show in game right away. A look needs a model that exists in the game files. Edit later with My items.")

function p:OnShowPage() Layout(); DressLook(); p.updateHeir(); if #list.data == 0 and not list.loading then Run() end end
p:SetScript("OnShow", function() DressLook() end)
Layout()

-- ------------------------------------------------------------------ customise icon (the macro icon window)
local icp = CreateFrame("Frame", nil, p)
Skin(icp, { 0.05, 0.055, 0.07, 0.99 }, C.border)
icp:SetPoint("TOPLEFT", 16, -42); icp:SetSize(698, 500); icp:SetFrameLevel(p:GetFrameLevel() + 40); icp:Hide()
local ich = Header(icp, "Choose an icon (like the macro icon window)"); ich:SetPoint("TOPLEFT", 12, -12)
local icons = {}
local function LoadIcons()
    if #icons > 0 then return end
    icons[1] = "INV_MISC_QUESTIONMARK"
    local function Add(n) if n then n = tostring(n):match("[^\\/]*$"); icons[#icons + 1] = n end end
    -- 3.3.5 API (count + info) first; the table-filling API of later clients as a fallback
    if GetNumMacroIcons and GetMacroIconInfo then for i = 1, GetNumMacroIcons() do Add(GetMacroIconInfo(i)) end end
    if GetNumMacroItemIcons and GetMacroItemIconInfo then for i = 1, GetNumMacroItemIcons() do Add(GetMacroItemIconInfo(i)) end end
    if #icons < 10 then
        local t = {}
        if GetMacroIcons then pcall(GetMacroIcons, t) end
        if GetMacroItemIcons then pcall(GetMacroItemIcons, t) end
        for _, n in ipairs(t) do Add(n) end
    end
end
-- only icons that some item look uses can be applied: the server lists them, we keep the matching ones
local usable, usableDone
local function Filter()
    if not usable or not usableDone then return end
    local keep = {}
    for _, n in ipairs(icons) do if usable[n:lower()] then keep[#keep + 1] = n end end
    if #keep > 0 then icons = keep end
end
H.ICU = function(a)
    usable = usable or {}
    for n in (a[4] or ""):gmatch("[^,]+") do usable[n] = true end
    local pg, pages = tonumber(a[2]) or 0, tonumber(a[3]) or 1
    if pg + 1 < pages then Send("ICONUSE", pg + 1) else usableDone = true; Filter(); if icp:IsShown() then icp:GetScript("OnShow")() end end
end
local COLS, ROWS, CELL = 14, 9, 44
local icOff, icCells = 0, {}
local icSlider
local function IcRefresh()
    for i, b in ipairs(icCells) do
        local name = icons[icOff * COLS + i]
        b.name = name
        Shown(b, name ~= nil)
        if name then b.tex:SetTexture("Interface\\Icons\\" .. name) end
    end
end
for i = 1, COLS * ROWS do
    local b = CreateFrame("Button", nil, icp)
    b:SetSize(40, 40); b:SetPoint("TOPLEFT", 14 + ((i - 1) % COLS) * CELL, -44 - math.floor((i - 1) / COLS) * CELL)
    Skin(b, { 0.03, 0.035, 0.045, 1 }, C.border)
    b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetPoint("TOPLEFT", 2, -2); b.tex:SetPoint("BOTTOMRIGHT", -2, 2); b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(C.accent)); icLabel = self.name end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    b:SetScript("OnClick", function(self)
        if not self.name then return end
        iconMode = self.name; icp:Hide()
        lookName:SetText("icon " .. self.name)
        lookIcon:SetTexture("Interface\\Icons\\" .. self.name)
        Run()
    end)
    icCells[i] = b
end
icSlider = CreateFrame("Slider", nil, icp)
icSlider:SetOrientation("VERTICAL"); icSlider:SetSize(12, ROWS * CELL - 4); icSlider:SetPoint("TOPRIGHT", -12, -44)
Skin(icSlider, { 0.03, 0.035, 0.045, 1 }, C.border)
icSlider:SetThumbTexture(D.WHITE); icSlider:GetThumbTexture():SetVertexColor(unpack(C.accent)); icSlider:GetThumbTexture():SetSize(12, 24)
icSlider:SetValueStep(1)
icSlider:SetScript("OnValueChanged", function(self, v) icOff = math.floor(v + 0.5); IcRefresh() end)
icp:EnableMouseWheel(true)
icp:SetScript("OnMouseWheel", function(self, d) icSlider:SetValue(math.max(0, math.min(select(2, icSlider:GetMinMaxValues()), icOff - d * 2))) end)
local icNote = Text(icp, 10, C.dim); icNote:SetPoint("TOPLEFT", 14, -454); icNote:SetWidth(660); icNote:SetJustifyH("LEFT")
icNote:SetText("Click an icon: the list then shows the items that use it. Pick one and your new item gets that look and icon. Only icons that an item look can carry are shown (the game takes the icon from the item's look).")
local icX = Button(icp, "Close", 80, 24, nil, function() icp:Hide() end); icX:SetPoint("BOTTOMRIGHT", -12, 12)
icp:SetScript("OnShow", function()
    LoadIcons()
    if not usableDone and not usable then Send("ICONUSE", 0) end
    Filter()
    icSlider:SetMinMaxValues(0, math.max(0, math.ceil(#icons / COLS) - ROWS)); icSlider:SetValue(0); icOff = 0; IcRefresh()
end)
local icB = Button(p, "Customise icon", 250, 22, nil, function() icp:Show() end)
icB:SetPoint("TOPLEFT", 372 + 70, -250)
Tip(icB, "Customise icon", "Open the icon window: pick any game icon and see which items use it, then take its look.")
