-- Dev Menu, part 7: Your character. One-click GM tools on yourself: god mode, levels, gold, mounts, heirlooms, gear sets, flight paths...
local D = CoADev
local C, Text, Header, Button, Edit, Check, Tip, MakeList, Send, Toast, p, H = D.C, D.Text, D.Header, D.Button, D.Edit, D.Check, D.Tip, D.MakeList, D.Send, D.Toast, D.pages.me, D.H

local function Lbl(t, x, y) local l = Text(p, 10, C.dim); l:SetPoint("TOPLEFT", x, y); l:SetText(t); return l end

-- ------------------------------------------------------------------ powers (toggles)
Header(p, "Powers"):SetPoint("TOPLEFT", 16, -14)
local POWERS = {
    { "god", "God mode", "You take no damage and cannot die." },
    { "gm", "GM mode", "The .gm on state: GM flag, can be seen as a GM, immune to most things." },
    { "cast", "Instant cast", "Every spell casts instantly." },
    { "cd", "No cooldowns", "Spells and abilities have no cooldown." },
    { "power", "Infinite power", "Mana, rage and energy never run out: spells cost nothing." },
    { "gmfly", "Fly everywhere", "Flying mount speed without a mount, in every zone." },
    { "water", "Walk on water", "Stand and run on water." },
    { "taxi", "All flight paths", "Every flight master node is unlocked." },
}
local checks = {}
for i, w in ipairs(POWERS) do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local c = Check(p, w[2], function(v) Send("ME", w[1], v and 1 or 0) end)
    c:SetPoint("TOPLEFT", 16 + col * 176, -44 - row * 24)
    Tip(c, w[2], w[3])
    checks[w[1]] = c
end

-- ------------------------------------------------------------------ quick actions
Header(p, "Quick actions"):SetPoint("TOPLEFT", 16, -150)
StaticPopupDialogs["COADEV_GUILD"] = {
    text = "Name of your new guild (2 to 24 letters):", button1 = ACCEPT, button2 = CANCEL, hasEditBox = 1, maxLetters = 24,
    OnAccept = function(self) Send("ME", "guild", self.editBox:GetText()) end,
    EditBoxOnEnterPressed = function(self) Send("ME", "guild", self:GetText()); self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}
local ACTIONS = {
    { "Full heal / revive", { "heal" }, "Revives you if dead and refills health and mana." },
    { "Clear cooldowns", { "cooldowns" } },
    { "Repair everything", { "repair" } },
    { "Reveal the whole map", { "explore" }, "Marks every zone as explored." },
    { "Learn my class spells", { "learn", "class" }, "Every trainer spell, talent and class quest spell for your class." },
    { "Learn all mounts & pets", { "learn", "mounts" }, "Every mount and every companion pet your server has an item for." },
    { "Max my skills", { "learn", "skills" }, "Weapon and profession skills to the maximum for your level." },
    { "Create my guild...", { "guild" }, "Makes a guild with the name you choose and puts you in it as its leader. Only if you have no guild yet." },
}
for i, a in ipairs(ACTIONS) do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local b = Button(p, a[1], 164, 26, nil, function()
        if a[2][1] == "guild" then StaticPopup_Show("COADEV_GUILD") return end
        Send("ME", unpack(a[2])); if a[4] then Send("ME", unpack(a[4])) end
    end)
    b:SetPoint("TOPLEFT", 16 + col * 170, -176 - row * 30)
    if a[3] then Tip(b, a[1], a[3]) end
end

-- ------------------------------------------------------------------ level
Header(p, "Level"):SetPoint("TOPLEFT", 16, -306)
local lvText = Text(p, 11, C.text); lvText:SetPoint("TOPLEFT", 60, -306); lvText:SetText("")
for i, lv in ipairs({ 1, 10, 20, 30, 40, 50, 60, 70, 80 }) do
    local b = Button(p, tostring(lv), 34, 24, "chip", function() Send("ME", "level", lv) end)
    b:SetPoint("TOPLEFT", 16 + (i - 1) * 38, -330)
end
local lvE = Edit(p, 50, 24, true); lvE:SetPoint("TOPLEFT", 16, -360); lvE:SetText("80")
local lvB = Button(p, "Set level", 80, 24, "accent", function() Send("ME", "level", tonumber(lvE:GetText()) or 80) end); lvB:SetPoint("LEFT", lvE, "RIGHT", 8, 0)
Tip(lvB, "Set level", "Sets your level to anything from 1 up to the server maximum. Talent points are recalculated.")

-- ------------------------------------------------------------------ money and points
Header(p, "Gold and points"):SetPoint("TOPLEFT", 16, -398)
local goldText = Text(p, 11, C.text); goldText:SetPoint("TOPLEFT", 190, -398)
local GOLD = { { 1, "+1g" }, { 100, "+100g" }, { 1000, "+1k" }, { 10000, "+10k" }, { 100000, "+100k" } }
for i, g in ipairs(GOLD) do
    local b = Button(p, g[2], 62, 24, "chip", function() Send("ME", "money", g[1]) end)
    b:SetPoint("TOPLEFT", 16 + (i - 1) * 66, -422)
end
local gE = Edit(p, 90, 24, true); gE:SetPoint("TOPLEFT", 16, -452); gE:SetPlaceholder("gold")
local gB = Button(p, "Add gold", 80, 24, "accent", function() Send("ME", "money", tonumber(gE:GetText()) or 0) end); gB:SetPoint("LEFT", gE, "RIGHT", 8, 0)
local gB2 = Button(p, "Take gold", 80, 24, nil, function() Send("ME", "money", -(tonumber(gE:GetText()) or 0)) end); gB2:SetPoint("LEFT", gB, "RIGHT", 6, 0)
local pts = {
    { "Honor +5000", { "honor", 5000 } }, { "Arena +500", { "arena", 500 } },
    { "Frost x100", { "emblem", "frost", 100 } }, { "Triumph x100", { "emblem", "triumph", 100 } }, { "Conquest x100", { "emblem", "conquest", 100 } },
    { "Valor x100", { "emblem", "valor", 100 } },
}
for i, a in ipairs(pts) do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local b = Button(p, a[1], 108, 24, nil, function() Send("ME", unpack(a[2])) end)
    b:SetPoint("TOPLEFT", 16 + col * 112, -484 - row * 28)
end

-- ------------------------------------------------------------------ speed and size
Header(p, "Speed and size"):SetPoint("TOPLEFT", 16, -548)
for i, s in ipairs({ 1, 2, 4, 8, 15 }) do
    local b = Button(p, "x" .. s, 36, 24, "chip", function() Send("ME", "speed", s) end)
    b:SetPoint("TOPLEFT", 16 + (i - 1) * 40, -572)
end
local szl = Text(p, 10, C.dim); szl:SetPoint("TOPLEFT", 216, -578); szl:SetText("size")
for i, s in ipairs({ 0.5, 1, 2, 4 }) do
    local b = Button(p, tostring(s), 26, 24, "chip", function() Send("ME", "scale", s) end)
    b:SetPoint("TOPLEFT", 240 + (i - 1) * 29, -572)
end

-- ------------------------------------------------------------------ right side: heirlooms, sets, any item
local RX = 372
Header(p, "Heirlooms"):SetPoint("TOPLEFT", RX, -14)
local hb1 = Button(p, "Full set for my class", 160, 28, "accent", function() Send("ME", "heirloom", "class") end); hb1:SetPoint("TOPLEFT", RX, -40)
Tip(hb1, "Full heirloom set", "Shoulders, chest, rings, trinkets and weapons your class can use. These are the real heirlooms, they scale to your level.")
local hb2 = Button(p, "Every heirloom", 150, 28, nil, function() Send("ME", "heirloom", "all") end); hb2:SetPoint("LEFT", hb1, "RIGHT", 8, 0)

Header(p, "Gear sets"):SetPoint("TOPLEFT", RX, -84)
local srch = Edit(p, 190, 24); srch:SetPoint("TOPLEFT", RX, -110); srch:SetPlaceholder("Set name (Enter)")
local mine = Check(p, "My class only", function() end); mine:SetPoint("LEFT", srch, "RIGHT", 10, 0); mine:Set(true)
local sp, lvlSel = 0, 0
local list
local function Run() list:Search(function(pg) Send("MESETS", srch:GetText(), pg, mine.value and 1 or 0, lvlSel) end) end
srch:SetScript("OnEnterPressed", function(self) self:ClearFocus(); sp = 0; Run() end)
mine:SetScript("PostClick", function() sp = 0; Run() end)
local CH = { "Gladiator", "Wrathful", "Relentless", "Furious", "Deadly", "Hateful", "Savage", "Plate", "Battlegear" }
local cx, cy = RX, -140
for i, n in ipairs(CH) do
    local b = Button(p, n, 10, 22, "chip", function() srch:SetText(n); sp = 0; Run() end)
    b:SetWidth(math.max(40, b.label:GetStringWidth() + 14))
    if cx + b:GetWidth() > RX + 340 then cx = RX; cy = cy - 26 end
    b:SetPoint("TOPLEFT", cx, cy)
    cx = cx + b:GetWidth() + 4
end
-- level filter: sets whose items need that level (1 = levels 1-9, 10 = 10-19 ... 80)
local lvChips = {}
for i, lv in ipairs({ 0, 1, 10, 20, 30, 40, 50, 60, 70, 80 }) do
    local w = lv == 0 and 34 or 29
    local b = Button(p, lv == 0 and "Any" or tostring(lv), w, 22, "chip", function()
        lvlSel = lv; sp = 0
        for _, c in ipairs(lvChips) do c:SetActive(c.v == lvlSel) end
        Run()
    end)
    b.v = lv
    b:SetPoint("TOPLEFT", RX + (i == 1 and 0 or (34 + 4 + (i - 2) * 33)), -194)
    lvChips[i] = b
end
lvChips[1]:SetActive(true)
Tip(lvChips[2], "Level filter", "Show only sets whose pieces need this level range: 1 = levels 1 to 9, 10 = 10 to 19, and so on. Any = no filter.")
list = MakeList(p, 12, 22, { { w = 176 }, { w = 60, color = C.dim, right = true }, { w = 54, color = C.dim, right = true } }, function(d)
    Send("ME", "set", d.id)
end)
list:SetPoint("TOPLEFT", RX, -222); list:SetSize(342, 268)
list.format = function(d) return { d.name, "ilvl " .. d.ilvl, d.count .. " pcs" } end
list.data = {}
Tip(list, "Gear sets", "Click a set to put all its pieces in your bags. Sorted by item level, best first.")
local pager = Text(p, 10, C.dim); pager:SetPoint("TOPLEFT", RX, -499)

Header(p, "Add any item"):SetPoint("TOPLEFT", RX, -530)
local idE = Edit(p, 90, 24, true); idE:SetPoint("TOPLEFT", RX, -556); idE:SetPlaceholder("item id")
local nE = Edit(p, 50, 24, true); nE:SetPoint("LEFT", idE, "RIGHT", 6, 0); nE:SetText("1")
local giveB = Button(p, "Add to my bags", 120, 24, "accent", function() Send("IGIVE", tonumber(idE:GetText()) or 0, tonumber(nE:GetText()) or 1) end)
giveB:SetPoint("LEFT", nE, "RIGHT", 8, 0)

-- ------------------------------------------------------------------ replies
H.MS = function(a)
    local keys = { "gm", "god", "cast", "cd", "power", "water", "gmchat", "gmfly", "taxi" }
    for i, k in ipairs(keys) do if checks[k] then checks[k]:Set(a[1 + i] == "1") end end
    lvText:SetText("(now " .. (a[11] or "?") .. ")")
    goldText:SetText("you have " .. (a[12] or "?") .. " gold")
end
H.MSB = function(a) list:Begin(a[4]) end
H.MSR = function(a) table.insert(list.data, { id = tonumber(a[2]), name = a[3] or "", ilvl = a[4] or "0", count = a[5] or "0" }) end
H.MSE = function(a)
    list:Done()
    pager:SetText((a[2] or "0") .. " sets (scroll for more)")
end

-- ------------------------------------------------------------------ reputation and faction (covers the right side)
local rp = CreateFrame("Frame", nil, p)
D.Skin(rp, { 0.07, 0.075, 0.09, 1 }, { 0.07, 0.075, 0.09, 1 })
rp:SetPoint("TOPLEFT", RX - 8, -4); rp:SetPoint("BOTTOMRIGHT", -4, 4); rp:SetFrameLevel(p:GetFrameLevel() + 10); rp:Hide()
local STAND = { { -42000, "Hated" }, { 0, "Neutral" }, { 3000, "Friendly" }, { 9000, "Honored" }, { 21000, "Revered" }, { 42000, "Exalted" } }
local pick = 42000
local pickChips = {}
Header(rp, "Faction"):SetPoint("TOPLEFT", 8, -12)
for i, f in ipairs({ { "alliance", "Alliance" }, { "neutral", "Neutral" }, { "horde", "Horde" } }) do
    local b = Button(rp, f[2], 100, 28, i == 1 and "accent" or nil, function() Send("ME", "faction", f[1]) end)
    b:SetPoint("TOPLEFT", 8 + (i - 1) * 106, -38)
    if f[1] == "neutral" then Tip(b, "Neutral", "Friendly to everyone (no one attacks you) until you log out.") else Tip(b, f[2], "Changes your character to the " .. f[2] .. " side (race, start zone, reps). It is finished when you log out to the character screen.") end
end
Header(rp, "Standing"):SetPoint("TOPLEFT", 8, -84)
for i, st in ipairs(STAND) do
    local b = Button(rp, st[2], 52, 24, "chip", function()
        pick = st[1]; for _, c in ipairs(pickChips) do c:SetActive(c.v == pick) end
    end)
    b.v = st[1]; b:SetPoint("TOPLEFT", 8 + (i - 1) * 56, -110); pickChips[i] = b
end
pickChips[6]:SetActive(true)
local allB = Button(rp, "Set ALL reputations to the chosen standing", 330, 26, "accent", function() Send("ME", "rep", "all", pick) end)
allB:SetPoint("TOPLEFT", 8, -142)
Header(rp, "One faction (click to set)"):SetPoint("TOPLEFT", 8, -184)
local rs = Edit(rp, 200, 24); rs:SetPoint("TOPLEFT", 8, -210); rs:SetPlaceholder("Faction name (Enter)")
local rlist
local function RRun() rlist:Search(function(pg) Send("REPSEARCH", rs:GetText(), pg) end) end
rs:SetScript("OnEnterPressed", function(self) self:ClearFocus(); RRun() end)
rlist = MakeList(rp, 12, 22, { { w = 230 }, { w = 80, color = C.dim, right = true } }, function(d)
    Send("ME", "rep", "one", pick, d.id); d.st = pick; rlist:Refresh()
end)
rlist:SetPoint("TOPLEFT", 8, -240); rlist:SetSize(342, 270)
rlist.format = function(d) return { d.name, tostring(d.st) } end
rlist.data = {}
local rpager = Text(rp, 10, C.dim); rpager:SetPoint("TOPLEFT", 8, -520)
H.RPB = function(a) rlist:Begin(a[4]) end
H.RPR = function(a) table.insert(rlist.data, { id = tonumber(a[2]), name = a[3] or "", st = tonumber(a[4]) or 0 }) end
H.RPE = function(a)
    rlist:Done()
    rpager:SetText((a[2] or "0") .. " factions (scroll for more)")
end
local back = Button(rp, "< Back", 70, 24, nil, function() rp:Hide() end); back:SetPoint("TOPRIGHT", -10, -10)
local repB = Button(p, "Reps / faction", 110, 24, nil, function() rp:Show(); RRun() end)
repB:SetPoint("TOPRIGHT", -14, -10)
Tip(repB, "Reputation and faction", "Change every reputation at once, one faction at a time, or switch to the Alliance, Horde or neutral.")

-- ------------------------------------------------------------------ bag presets (kept in your addon data: every character on this account sees them)
local bp = CreateFrame("Frame", nil, p)
D.Skin(bp, { 0.07, 0.075, 0.09, 1 }, { 0.07, 0.075, 0.09, 1 })
bp:SetPoint("TOPLEFT", RX - 8, -4); bp:SetPoint("BOTTOMRIGHT", -4, 4); bp:SetFrameLevel(p:GetFrameLevel() + 10); bp:Hide()
local function Bags() IlusixnDevMenuDB.bags = IlusixnDevMenuDB.bags or {}; return IlusixnDevMenuDB.bags end
local scan = CreateFrame("GameTooltip", "CoADevBagScan", UIParent, "GameTooltipTemplate")
scan:SetOwner(UIParent, "ANCHOR_NONE")
local function ItemName(id)
    local n = GetItemInfo(id)
    if not n then scan:SetOwner(UIParent, "ANCHOR_NONE"); scan:SetHyperlink("item:" .. id); scan:Hide() end
    return n or ("item " .. id)
end
local curBag, curItem = nil, nil
Header(bp, "Bag presets"):SetPoint("TOPLEFT", 8, -12)
local bback = Button(bp, "< Back", 70, 24, nil, function() bp:Hide() end); bback:SetPoint("TOPRIGHT", -10, -10)
local plist = MakeList(bp, 5, 22, { { w = 240 }, { w = 70, color = C.dim, right = true } }, function(d) curBag = d.bag; curItem = nil; bp:Refresh() end)
plist:SetPoint("TOPLEFT", 8, -40); plist:SetSize(342, 114)
plist.format = function(d) return { d.bag.name, #d.bag.items .. " items" } end
plist.isSelected = function(d) return d.bag == curBag end
local nameE = Edit(bp, 190, 24); nameE:SetPoint("TOPLEFT", 8, -164); nameE:SetPlaceholder("New preset name")
local newB = Button(bp, "Create", 70, 24, "accent", function()
    local n = nameE:GetText(); if n == "" then return Toast("Name the preset first", "err") end
    local b = { name = n, items = {} }; table.insert(Bags(), b); curBag = b; nameE:SetText(""); nameE:ClearFocus(); bp:Refresh()
end)
newB:SetPoint("LEFT", nameE, "RIGHT", 6, 0)
local delB = Button(bp, "Delete preset", 90, 24, "danger", function()
    if not curBag then return end
    for i, b in ipairs(Bags()) do if b == curBag then table.remove(Bags(), i) break end end
    curBag = nil; bp:Refresh()
end)
delB:SetPoint("LEFT", newB, "RIGHT", 6, 0)
local bh = Header(bp, "Items in the selected preset"); bh:SetPoint("TOPLEFT", 8, -204)
local ilist = MakeList(bp, 9, 22, { { w = 210 }, { w = 62, color = C.dim, right = true }, { w = 36, color = C.dim, right = true } }, function(d) curItem = d; bp:Refresh() end)
ilist:SetPoint("TOPLEFT", 8, -230); ilist:SetSize(342, 204)
ilist.format = function(d) return { ItemName(d.it.id), tostring(d.it.id), "x" .. d.it.n } end
ilist.isSelected = function(d) return d == curItem end
local aid = Edit(bp, 130, 24); aid:SetPoint("TOPLEFT", 8, -444); aid:SetPlaceholder("item id or item link")
local acount = Edit(bp, 46, 24, true); acount:SetPoint("LEFT", aid, "RIGHT", 6, 0); acount:SetText("1")
local addB = Button(bp, "Add", 56, 24, "accent", function()
    if not curBag then return Toast("Pick or create a preset first", "err") end
    local txt = aid:GetText() or ""
    local id = tonumber(txt:match("item:(%d+)") or txt)
    if not id then return Toast("Type an item id or shift-click an item link", "err") end
    for _, it in ipairs(curBag.items) do if it.id == id then it.n = it.n + (tonumber(acount:GetText()) or 1); aid:SetText(""); return bp:Refresh() end end
    table.insert(curBag.items, { id = id, n = tonumber(acount:GetText()) or 1 }); aid:SetText(""); bp:Refresh()
end)
addB:SetPoint("LEFT", acount, "RIGHT", 6, 0)
local rmB = Button(bp, "Remove selected", 110, 24, nil, function()
    if not (curBag and curItem) then return end
    for i, it in ipairs(curBag.items) do if it == curItem.it then table.remove(curBag.items, i) break end end
    curItem = nil; bp:Refresh()
end)
rmB:SetPoint("LEFT", addB, "RIGHT", 6, 0)
-- give the items one by one (the server answers each request)
local queue = {}
local qf = CreateFrame("Frame"); qf:Hide()
qf:SetScript("OnUpdate", function(self, el)
    self.t = (self.t or 0) + el
    if self.t < 0.2 then return end
    self.t = 0
    local it = table.remove(queue, 1)
    if it then Send("IGIVE", it.id, it.n) else self:Hide() end
end)
local giveBag = Button(bp, "Put this bag in my bags", 342, 30, "accent", function()
    if not curBag or #curBag.items == 0 then return Toast("This preset is empty", "err") end
    for _, it in ipairs(curBag.items) do table.insert(queue, it) end
    qf:Show(); Toast(("Adding %d items..."):format(#curBag.items), "ok")
end)
giveBag:SetPoint("TOPLEFT", 8, -482)
Tip(giveBag, "Put this bag in my bags", "Adds every item of the preset to the bags of the character you are playing now. Presets are saved with the addon, so any character on this account can use them.")
local bnote = Text(bp, 10, C.dim); bnote:SetPoint("TOPLEFT", 8, -520); bnote:SetWidth(342); bnote:SetJustifyH("LEFT")
bnote:SetText("Click the id box, then shift-click an item to paste its link. Needs room in your bags.")
hooksecurefunc("ChatEdit_InsertLink", function(link) if link and aid:HasFocus() then aid:SetText(link) end end)
function bp:Refresh()
    local d = {}
    for _, b in ipairs(Bags()) do d[#d + 1] = { bag = b } end
    plist.data = d; plist:Refresh()
    local it = {}
    if curBag then for _, x in ipairs(curBag.items) do it[#it + 1] = { it = x } end end
    ilist.data = it; ilist.offset = 0; ilist:Refresh()
    bh:SetText(curBag and ("ITEMS IN " .. curBag.name:upper()) or "ITEMS IN THE SELECTED PRESET")
end
bp:SetScript("OnShow", function(self) self:Refresh() end)
local bagB = Button(p, "Bag presets", 100, 24, nil, function() bp:Show() end)
bagB:SetPoint("TOPRIGHT", -150, -10)
Tip(bagB, "Bag presets", "Make a list of items once, then add all of them to the bags of any character with one click.")

function p:OnShowPage()
    Send("ME", "state")
    if #list.data == 0 then Run() end
end
