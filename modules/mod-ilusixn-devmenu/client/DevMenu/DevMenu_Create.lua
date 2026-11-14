-- Dev Menu, part 3: Create an NPC. Any playable race (custom races included), full appearance,
-- every armor slot (transmog-style, any item or raw display id), weapons, gear removal, presets you can share.
-- Uses the Mirror Image look, so it works on every 3.3.5 client without patches.
local D = CoADev
local C, WHITE = D.C, D.WHITE
local Shown, Skin, Text, Tip, Button, Edit, Check = D.Shown, D.Skin, D.Text, D.Tip, D.Button, D.Edit, D.Check
local Header, Card, MakeList, Send, Toast, pages, S, H = D.Header, D.Card, D.MakeList, D.Send, D.Toast, D.pages, D.S, D.H

local p = pages.create
-- addons may not target by code, but a secure button clicked by you may: slot clicks also target the preview NPC,
-- so the wardrobe can draw the race you are making (it draws your target)
local TARGET_PREVIEW = "/targetexact Preview" .. string.char(10) .. "/targetexact Dev outfit preview"
-- A secure frame makes every parent "protected": the whole menu could not be shown or hidden in combat. So the secure buttons live
-- on UIParent, are anchored to the page they belong to, and a small driver keeps them shown, scaled and faded like that page.
local secureSlots = {}
local function SecureSlot(parent)
    local b = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", TARGET_PREVIEW)
    b:RegisterForClicks("LeftButtonUp")
    b.owner = parent
    b.rawPoint = b.SetPoint
    -- no anchor to the menu either (a frame anchored to a secure one is restricted in combat): the driver places it by hand
    b.SetPoint = function(self, point, x, y)
        self.dx, self.dy = x or 0, y or 0
    end
    b:Hide()
    secureSlots[#secureSlots + 1] = b
    return b
end
local slotDriver = CreateFrame("Frame")
slotDriver:SetScript("OnUpdate", function(self, el)
    self.t = (self.t or 0) + el
    if self.t < 0.05 then return end
    self.t = 0
    local safe = not InCombatLockdown()
    for _, b in ipairs(secureSlots) do
        local o = b.owner
        local on = o:IsVisible()
        b:SetAlpha(on and o:GetEffectiveAlpha() or 0)   -- allowed in combat: a button that cannot hide stays invisible
        if safe then
            if on then
                local sc, l, t = o:GetEffectiveScale() / UIParent:GetEffectiveScale(), o:GetLeft(), o:GetTop()
                -- only touch layout when something moved: re-anchoring every tick made the game stall
                -- (a page reload may clear the button's anchor or change its offset: GetNumPoints / dx / dy catch that)
                if l and t and (b.cl ~= l or b.ct ~= t or b.cs ~= sc or b.cdx ~= b.dx or b.cdy ~= b.dy or b:GetNumPoints() == 0) then
                    b.cl, b.ct, b.cs, b.cdx, b.cdy = l, t, sc, b.dx, b.dy
                    b:SetFrameStrata(o:GetFrameStrata()); b:SetFrameLevel(o:GetFrameLevel() + 4)
                    b:SetScale(sc)
                    b:ClearAllPoints()
                    b.rawPoint(b, "TOPLEFT", UIParent, "BOTTOMLEFT", l + (b.dx or 0), t + (b.dy or 0))
                end
                if not b:IsShown() then b:Show() end
            elseif b:IsShown() then
                b:Hide()
            end
        end
    end
end)

-- 3.3.5 only asks the server about an item when a tooltip shows it: use a hidden tooltip, then poll the cache
local scan = CreateFrame("GameTooltip", "CoADevItemScan", UIParent, "GameTooltipTemplate")
scan:SetOwner(UIParent, "ANCHOR_NONE")
local function Fetch(id)
    if id and id > 0 and not GetItemInfo(id) then
        scan:SetOwner(UIParent, "ANCHOR_NONE"); scan:SetHyperlink("item:" .. id); scan:Hide()
        return false
    end
    return true
end
local waiters = {}
local poll = CreateFrame("Frame"); poll:Hide()
poll:SetScript("OnUpdate", function(self, el)
    self.t = (self.t or 0) + el
    if self.t < 0.5 then return end
    self.t = 0; self.n = (self.n or 0) + 1
    for _, fn in pairs(waiters) do fn() end
    if self.n >= 12 then self:Hide() end
end)
local function WaitItems(key, fn) waiters[key] = fn; poll.n = 0; poll:Show() end
local FetchOutfit -- defined below
-- saved variables load after this file runs, so always fetch the tables through DBT()
local function DBT(k) IlusixnDevMenuDB = IlusixnDevMenuDB or {}; IlusixnDevMenuDB[k] = IlusixnDevMenuDB[k] or {}; return IlusixnDevMenuDB[k] end

local SLOTS = {
    { "Head", "INV_Helmet_03" }, { "Shoulders", "INV_Shoulder_02" }, { "Shirt", "INV_Shirt_01" }, { "Chest", "INV_Chest_Chain" },
    { "Waist", "INV_Belt_03" }, { "Legs", "INV_Pants_03" }, { "Feet", "INV_Boots_03" }, { "Wrists", "INV_Bracer_07" },
    { "Hands", "INV_Gauntlets_04" }, { "Back", "INV_Misc_Cape_02" }, { "Tabard", "INV_Shirt_GuildTabard_01" },
    { "Main hand", "INV_Sword_04" }, { "Off hand", "INV_Shield_04" }, { "Ranged", "INV_Weapon_Bow_07" },
}
local FEAT = { { "skin", "Skin" }, { "face", "Face" }, { "hair", "Hair style" }, { "hcol", "Hair color" }, { "facial", "Facial hair" } }

-- the look being edited
local L = { race = 1, gender = 0, skin = 0, face = 0, hair = 0, hcol = 0, facial = 0, items = {} }
for i = 1, #SLOTS do L.items[i] = 0 end
local races, raceInfo = {}, {}   -- raceInfo[race][gender] = { skins, faces, hairs, colors, facials }
-- custom races whose looks live only in the client files report 0-1 options to the server: let those cycle freely
local UNKNOWN_MAX = 32
local function MaxOf(i)
    local n = raceInfo[L.race] and raceInfo[L.race][L.gender] and raceInfo[L.race][L.gender][i] or 0
    if n <= 1 then return UNKNOWN_MAX, true end
    return n, false
end

L.ext = {}   -- extra looks for custom clients: key -> number (see Help > Look adapters)
local function Pack()
    local t = { L.race, L.gender, L.skin, L.face, L.hair, L.hcol, L.facial }
    for i = 1, #SLOTS do t[#t + 1] = L.items[i] end
    local e, keys = {}, {}
    for k in pairs(L.ext) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do e[#e + 1] = k .. "=" .. L.ext[k] end
    return table.concat(t, ",") .. (#e > 0 and (";" .. table.concat(e, ",")):sub(1, 100) or "")
end
local function Unpack(s)
    s = tostring(s)
    local base, ext = s:match("^([^;]*);?(.*)$")
    local v = {}
    for x in base:gmatch("(-?%d+)") do v[#v + 1] = tonumber(x) end
    if #v < 7 + #SLOTS then return false end
    L.race, L.gender, L.skin, L.face, L.hair, L.hcol, L.facial = v[1], v[2], v[3], v[4], v[5], v[6], v[7]
    for i = 1, #SLOTS do L.items[i] = v[7 + i] end
    L.ext = {}
    for k, n in (ext or ""):gmatch("([%w_]+)=(-?%d+)") do L.ext[k] = k == "extra" and n or tonumber(n) end
    DecodeLook()
    return true
end

-- look adapters (optional, per custom client): any addon can add one to this list, before or after we load
DevMenuLookAdapters = DevMenuLookAdapters or {}
local function Adapter()
    for _, a in ipairs(DevMenuLookAdapters) do
        if (not a.IsAvailable or a.IsAvailable()) and (not a.Handles or a.Handles(L.race, L.gender)) then return a end
    end
end
-- "full" adapters (Encode/Decode) own the whole look: their rows replace the 5 stock rows
L.opt = {}
local function FullAdapter() local a = Adapter(); return a and a.Encode and a.Decode and a end
local function EncodeLook()
    local a = FullAdapter()
    if not a then return end
    local b, extra = a.Encode(L.race, L.gender, L.opt)
    L.skin, L.face, L.hair, L.hcol, L.facial = b[1], b[2], b[3], b[4], b[5]
    L.ext = extra and extra > 0 and { extra = string.format("%.0f", extra) } or {}
end
local function DecodeLook()
    local a = FullAdapter()
    if a then L.opt = a.Decode(L.race, L.gender, { L.skin, L.face, L.hair, L.hcol, L.facial }, tonumber(L.ext.extra) or 0) end
end

-- ------------------------------------------------------------------ layout
local h = Header(p, "Create an NPC"); h:SetPoint("TOPLEFT", 16, -14)
local sub = Text(p, 10, C.dim); sub:SetPoint("TOPLEFT", 16, -30)
sub:SetText("Any race, any armor. Dress it, preview it in the world in front of you, then create it or apply it to the selected NPC.")

-- race list
local raceList = MakeList(p, 9, 22, { { w = 150 }, { w = 30, color = C.dim, size = 10, right = true } }, function(d)
    L.race = d.id; p:Refresh(true)
end)
raceList:SetPoint("TOPLEFT", 16, -50); raceList:SetSize(210, 200)
raceList.format = function(d) return { d.name, d.id } end
raceList.isSelected = function(d) return d.id == L.race end

local genders = {}
for i, g in ipairs({ { 0, "Male" }, { 1, "Female" } }) do
    local b = Button(p, g[2], 103, 24, "chip", function() L.gender = g[1]; p:Refresh(true) end)
    b:SetPoint("TOPLEFT", 16 + (i - 1) * 107, -256)
    b.v = g[1]
    genders[i] = b
end

-- appearance: the 5 looks every client has, then any extra rows the client's look adapter offers (scrolls)
local app = CreateFrame("ScrollFrame", nil, p)
app:SetPoint("TOPLEFT", 12, -284); app:SetSize(220, 142)
local appChild = CreateFrame("Frame", nil, app); appChild:SetSize(220, 142)
app:SetScrollChild(appChild)
app:EnableMouseWheel(true)
app:SetScript("OnMouseWheel", function(self, d)
    local mx = math.max(0, appChild:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(mx, self:GetVerticalScroll() - d * 28)))
end)
local appMore = Text(p, 9, C.accent); appMore:SetPoint("TOPRIGHT", app, "BOTTOMRIGHT", -4, 2)
local steppers = {}
local function StepRow(i, label, get, set, maxf)
    local y = -4 - (i - 1) * 28
    local lb = Text(appChild, 11, C.dim); lb:SetPoint("TOPLEFT", 4, y - 5); lb:SetText(label); lb:SetWidth(84)
    local val = Text(appChild, 11, C.text); val:SetPoint("TOPLEFT", 116, y - 5); val:SetWidth(50); val:SetJustifyH("CENTER")
    local function step(d) local mx = maxf(); if IsShiftKeyDown() then d = d * 10 end; set((get() + d) % mx); p:Refresh(true) end   -- Shift: 10 at a time
    local m = Button(appChild, "<", 24, 22, nil, function() step(-1) end); m:SetPoint("TOPLEFT", 88, y)
    local pl = Button(appChild, ">", 24, 22, nil, function() step(1) end); pl:SetPoint("TOPLEFT", 168, y)
    return { lb = lb, val = val, m = m, pl = pl, get = get, maxf = maxf }
end
for i, f in ipairs(FEAT) do
    steppers[i] = StepRow(i, f[2], function() return L[f[1]] end, function(v) L[f[1]] = v end, function() return (MaxOf(i)) end)
    steppers[i].key, steppers[i].idx = f[1], i
end
local extraRows, extraFor = {}, nil
local function Place(r, idx, show)
    local y = -4 - (idx - 1) * 28
    r.lb:ClearAllPoints(); r.lb:SetPoint("TOPLEFT", 4, y - 5)
    r.val:ClearAllPoints(); r.val:SetPoint("TOPLEFT", 116, y - 5)
    r.m:ClearAllPoints(); r.m:SetPoint("TOPLEFT", 88, y)
    r.pl:ClearAllPoints(); r.pl:SetPoint("TOPLEFT", 168, y)
    for _, w in ipairs({ r.lb, r.val, r.m, r.pl }) do if show then w:Show() else w:Hide() end end
end
local function BuildExtra()
    local ad = Adapter()
    local opts = ad and ad.GetOptions and ad.GetOptions(L.race, L.gender) or {}
    local full = FullAdapter() and #opts > 0
    local key = L.race .. ":" .. L.gender .. ":" .. #opts .. ":" .. tostring(full)
    if key == extraFor then return end
    extraFor = key
    for i, st in ipairs(steppers) do Place(st, i, not full) end
    for _, r in ipairs(extraRows) do Place(r, 1, false) end
    local first = full and 0 or #FEAT
    local store = full and L.opt or L.ext
    local keep = {}
    for i, o in ipairs(opts) do
        local r = extraRows[i]
        if not r then
            r = StepRow(first + i, "", function() return 0 end, function() end, function() return 1 end)
            extraRows[i] = r
        end
        r.lb:SetText(o.label or o.key); r.lb:SetTextColor(unpack(C.accent))
        r.get = function() return tonumber(store[o.key]) or 0 end
        local function maxf() return math.max(1, o.max or 1) end
        local function step(d) if IsShiftKeyDown() then d = d * 10 end; store[o.key] = (r.get() + d) % maxf(); if full then EncodeLook() end; p:Refresh(true) end
        r.m:SetScript("OnClick", function() step(-1) end); r.pl:SetScript("OnClick", function() step(1) end)
        r.maxf = maxf
        Place(r, first + i, true)
        keep[o.key] = true
    end
    if full then
        DecodeLook()   -- the current 5 bytes + extra -> this race's options
    else
        L.opt = {}
        for k in pairs(L.ext) do if not keep[k] then L.ext[k] = nil end end
    end
    appChild:SetHeight(8 + (first + #opts) * 28)
    app:SetVerticalScroll(0)
    appMore:SetText(#opts > 0 and ((full and (#opts .. " looks") or ("+" .. #opts .. " more")) .. " (" .. (ad.name or "adapter") .. "), scroll") or "")
end
local rnd = Button(p, "Random", 70, 24, nil, function()
    local info = raceInfo[L.race] and raceInfo[L.race][L.gender]
    local fa = FullAdapter()
    if fa then
        for _, o in ipairs(fa.GetOptions(L.race, L.gender)) do L.opt[o.key] = math.random(0, math.max(1, o.max) - 1) end
        EncodeLook()
    else
        for i, f in ipairs(FEAT) do local mx, unknown = MaxOf(i); L[f[1]] = math.random(0, (unknown and 5 or mx) - 1) end
    end
    p:Refresh(true)
end)
rnd:SetPoint("TOPLEFT", 16, -432)
local mine = Button(p, "Copy mine", 70, 24, nil, function() Send("OMINE") end)
mine:SetPoint("LEFT", rnd, "RIGHT", 4, 0)
local resetB = Button(p, "Reset", 70, 24, nil, function()
    L.skin, L.face, L.hair, L.hcol, L.facial = 0, 0, 0, 0, 0
    L.opt, L.ext = {}, {}
    EncodeLook()
    p:Refresh(true)
end)
resetB:SetPoint("LEFT", mine, "RIGHT", 4, 0)
Tip(resetB, "Reset look", "Every look row back to its first choice. Gear and race stay.")
Tip(mine, "Copy my look", "Your race, face, hair and everything you show, transmog included. Then change what you want.")

-- equipment
local eh = Header(p, "Equipment (click: wardrobe   Ctrl+click: try on yourself)"); eh:SetPoint("TOPLEFT", 240, -50)
local slotRows = {}
local picker -- forward
for i, sl in ipairs(SLOTS) do
    local col, row = math.floor((i - 1) / 7), (i - 1) % 7
    local x, y = 240 + col * 238, -72 - row * 40
    local b = SecureSlot(p)
    b:SetSize(34, 34); b:SetPoint("TOPLEFT", x, y)
    Skin(b, C.panel2, C.border)
    local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetPoint("TOPLEFT", 2, -2); ic:SetPoint("BOTTOMRIGHT", -2, 2)
    ic:SetTexture("Interface\\Icons\\" .. sl[2]); ic:SetDesaturated(true); ic:SetAlpha(0.45)
    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(C.accent))
        local v = L.items[i]
        if v and v > 0 then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. v); GameTooltip:Show() end
    end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.border)); GameTooltip:Hide() end)
    b:SetScript("PostClick", function()
        if IsControlKeyDown() and (L.items[i] or 0) > 0 then DressUpItemLink("item:" .. L.items[i]) return end
        picker:Open(i)
    end)
    local nm = Text(p, 10, C.text); nm:SetPoint("TOPLEFT", x + 40, y - 2); nm:SetWidth(150)
    local e = Edit(p, 80, 18, true); e:SetPoint("TOPLEFT", x + 40, y - 15); e:SetPlaceholder(sl[1])
    e:SetFont(D.FONT, 10, "")
    local function set(v) L.items[i] = v; p:Refresh(true) end
    e:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local t = self:GetText()
        local id = t:match("item:(%d+)") or t:match("^%s*(%d+)%s*$")
        local disp = t:match("^%s*[dD](%d+)")
        set(id and tonumber(id) or disp and -tonumber(disp) or 0)
    end)
    e:HookScript("OnTextChanged", function(self) local id = self:GetText():match("item:(%d+)"); if id then self:SetText(id); set(tonumber(id)) end end)
    local x2 = Button(p, "x", 20, 18, "danger", function() set(0) end); x2:SetPoint("LEFT", e, "RIGHT", 4, 0)
    Tip(x2, "Remove", "Takes this piece off.")
    slotRows[i] = { icon = ic, name = nm, edit = e }
end
local strip = Button(p, "Remove all armor", 120, 24, "danger", function() for i = 1, 11 do L.items[i] = 0 end; p:Refresh(true) end)
strip:SetPoint("TOPLEFT", 240, -356)
local stripW = Button(p, "Remove weapons", 110, 24, nil, function() for i = 12, 14 do L.items[i] = 0 end; p:Refresh(true) end)
stripW:SetPoint("LEFT", strip, "RIGHT", 4, 0)
local fromSel = Button(p, "Copy selected NPC", 130, 24, nil, function() if S.selected then Send("OGET", S.selected.guid) else Toast("Select an NPC first", "err") end end)
fromSel:SetPoint("LEFT", stripW, "RIGHT", 4, 0)
local hint = Text(p, 9, C.dim); hint:SetPoint("TOPLEFT", 240, -384); hint:SetWidth(470)
hint:SetText("Item box: item id, a shift-clicked item link, or d<number> for a raw model (display) id. Armor shows on every client; custom races show on clients that have them.")

-- actions
local ah = Header(p, "Make it"); ah:SetPoint("TOPLEFT", 240, -404)
local auto = Check(p, "Live preview in front of me"); auto:SetPoint("TOPLEFT", 242, -426)
auto:Set(IlusixnDevMenuDB.livePreview ~= false)
auto:HookScript("OnClick", function(self) IlusixnDevMenuDB.livePreview = self.value; if self.value then p:Refresh(true) end end)
local prevB = Button(p, "Preview now", 100, 24, nil, function() Send("OPREV", Pack()) end); prevB:SetPoint("TOPLEFT", 456, -422)
local delPrev = Button(p, "Remove preview", 116, 24, "danger", function()
    auto:Set(false); IlusixnDevMenuDB.livePreview = false   -- otherwise the next change would bring it back
    Send("OPREVDEL")
end)
delPrev:SetPoint("LEFT", prevB, "RIGHT", 4, 0)
Tip(delPrev, "Remove preview", "Removes the preview NPC in front of you and turns off live preview.")
local nameE = Edit(p, 200, 24); nameE:SetPoint("TOPLEFT", 240, -452); nameE:SetPlaceholder("Name of the new NPC")
local create = Button(p, "Create NPC here", 130, 26, "accent", function() Send("OSAVE", 0, Pack(), nameE:GetText()) end)
create:SetPoint("LEFT", nameE, "RIGHT", 6, 0)
Tip(create, "Create NPC here", "Makes a new NPC type with this look and places it where you stand. Edit everything else in Selected NPC.")
local apply = Button(p, "Apply to selected NPC", 150, 26, nil, function()
    if not S.selected then return Toast("Select an NPC first", "err") end
    Send("OSAVE", S.selected.guid, Pack())
end)
apply:SetPoint("TOPLEFT", 240, -482)
Tip(apply, "Apply to selected NPC", "Dresses the selected NPC. If other spawns share its type, it gets its own copy first so they keep their look.")

-- presets (account-wide) + share codes
local ph = Header(p, "Saved looks & outfits"); ph:SetPoint("TOPLEFT", 16, -464)
local lookName = Edit(p, 96, 22); lookName:SetPoint("TOPLEFT", 16, -486); lookName:SetPlaceholder("Look name")
local saveLook = Button(p, "Save", 40, 22, nil, function()
    local n = lookName:GetText()
    if n == "" then return Toast("Type a name for the look", "err") end
    DBT("looks")[n] = Pack(); lookName:SetText(""); p:RefreshLooks(); Toast("Look saved: " .. n, "ok")
end)
saveLook:SetPoint("LEFT", lookName, "RIGHT", 4, 0)
saveLook:SetLabel("Look"); saveLook:SetWidth(48)
Tip(saveLook, "Save look", "Race, face, hair and gear: the whole NPC.")
local function GearCode() local t = {} for i = 1, #SLOTS do t[i] = L.items[i] end return table.concat(t, ",") end
local saveOutfit = Button(p, "Outfit", 56, 22, "accent", function()
    local n = lookName:GetText()
    if n == "" then return Toast("Type a name for the outfit", "err") end
    DBT("outfits")[n] = GearCode(); lookName:SetText(""); Toast("Outfit saved: " .. n .. " (gear only, fits any race)", "ok")
end)
saveOutfit:SetPoint("LEFT", saveLook, "RIGHT", 4, 0)
Tip(saveOutfit, "Save outfit", "Only the gear. Load it on any NPC to dress several NPCs the same way while each keeps its own race and face.")
local function PutGear(code)
    local i = 0
    for v in tostring(code):gmatch("(-?%d+)") do i = i + 1; if i <= #SLOTS then L.items[i] = tonumber(v) end end
end
local pendingGear   -- outfit waiting for the selected NPC's look (see H.OL)
local shareB = Button(p, "Share / import code...", 210, 22, nil, function() StaticPopup_Show("COA_DEVMENU_LOOKCODE") end)
shareB:SetPoint("TOPLEFT", 16, -512)
StaticPopupDialogs["COA_DEVMENU_LOOKCODE"] = {
    text = "Look code: copy it to share (Ctrl+C), or paste someone else's code and press Import.",
    button1 = "Import", button2 = CLOSE, hasEditBox = 1, maxLetters = 300, timeout = 0, hideOnEscape = 1, whileDead = 1,
    OnShow = function(self) local e = _G[self:GetName() .. "EditBox"]; e:SetText("NPCLOOK:" .. Pack()); e:HighlightText(); e:SetFocus() end,
    OnAccept = function(self)
        local t = _G[self:GetName() .. "EditBox"]:GetText():gsub("^NPCLOOK:", "")
        if Unpack(t) then p:Refresh(true); Toast("Look imported", "ok") else Toast("That is not a look code", "err") end
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
}
local looksMenu = CreateFrame("Frame", "CoADevLooksMenu", UIParent, "UIDropDownMenuTemplate")
local loadB = Button(p, "Load a saved look...", 210, 22, nil, function()
    local items, outs = {}, {}
    for n in pairs(DBT("looks")) do items[#items + 1] = n end
    for n in pairs(DBT("outfits")) do outs[#outs + 1] = n end
    table.sort(items); table.sort(outs)
    if #items == 0 and #outs == 0 then return Toast("Nothing saved yet", "err") end
    local menu = { { text = "Looks (whole NPC)", isTitle = true, notCheckable = true } }
    for _, n in ipairs(items) do
        menu[#menu + 1] = { text = n, notCheckable = true, func = function() Unpack(DBT("looks")[n]); p:Refresh(true) end }
    end
    menu[#menu + 1] = { text = "Outfits (gear only)", isTitle = true, notCheckable = true }
    for _, n in ipairs(outs) do
        menu[#menu + 1] = { text = n .. "  |cff8a8f9c- put on this NPC|r", notCheckable = true, func = function() PutGear(DBT("outfits")[n]); p:Refresh(true) end }
        menu[#menu + 1] = { text = n .. "  |cff8a8f9c- dress the selected NPC|r", notCheckable = true, func = function()
            if not S.selected then return Toast("Select an NPC first", "err") end
            pendingGear = DBT("outfits")[n]
            Send("OGET", S.selected.guid)   -- keeps its race and face, see H.OL
        end }
    end
    menu[#menu + 1] = { text = "Delete", isTitle = true, notCheckable = true }
    for _, n in ipairs(items) do menu[#menu + 1] = { text = "|cffff6060x|r  look: " .. n, notCheckable = true, func = function() DBT("looks")[n] = nil; Toast("Deleted " .. n, "ok") end } end
    for _, n in ipairs(outs) do menu[#menu + 1] = { text = "|cffff6060x|r  outfit: " .. n, notCheckable = true, func = function() DBT("outfits")[n] = nil; Toast("Deleted " .. n, "ok") end } end
    EasyMenu(menu, looksMenu, "cursor", 0, 0, "MENU")
end)
loadB:SetPoint("TOPLEFT", 16, -538)
function p:RefreshLooks() end

-- ------------------------------------------------------------------ wardrobe (transmog-style item browser)
do
    local QC = { [0] = { 0.6, 0.6, 0.6, 1 }, { 1, 1, 1, 1 }, { 0.12, 1, 0, 1 }, { 0, 0.44, 0.87, 1 }, { 0.64, 0.21, 0.93, 1 }, { 1, 0.5, 0, 1 }, { 0.9, 0.8, 0.5, 1 }, { 0.9, 0.8, 0.5, 1 } }
    -- camera per slot for the tiles: x = closer, z = up/down, facing
    local CAM = {
        [1] = { 1.5, -0.62, 0 }, [2] = { 1.1, -0.5, 0.3 }, [3] = { 0.7, -0.15, 0 }, [4] = { 0.7, -0.15, 0 }, [5] = { 0.9, 0.05, 0 },
        [6] = { 0.6, 0.35, 0 }, [7] = { 1.0, 0.65, 0.4 }, [8] = { 0.9, 0.05, 0.6 }, [9] = { 0.9, 0.1, 0.6 }, [10] = { 0.3, 0, math.pi },
        [11] = { 0.7, -0.15, 0 }, [12] = { 0.2, 0, 0.6 }, [13] = { 0.2, 0, -0.6 }, [14] = { 0.2, 0, 0.6 },
    }
    local COLS, ROWS = 5, 3
    local PER = COLS * ROWS   -- 15 tiles; the server sends 30 per page, so two views per server page
    local f = CreateFrame("Frame", "CoADevWardrobe", UIParent)
    f:SetSize(940, 600); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetToplevel(true)
    f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
    Skin(f, C.bg, { 0, 0, 0, 1 }); f:Hide()
    tinsert(UISpecialFrames, "CoADevWardrobe")
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", 1, -1); head:SetPoint("TOPRIGHT", -1, -1); head:SetHeight(40)
    Skin(head, C.head, C.head)
    head:EnableMouse(true); head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() f:StartMoving() end)
    head:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    local title = Text(head, 15, C.text); title:SetPoint("LEFT", 14, 0)
    local x = Button(head, "X", 26, 26, nil, function() f:Hide() end); x:SetPoint("RIGHT", -8, 0)
    local hintTop = Text(head, 10, C.dim); hintTop:SetPoint("RIGHT", x, "LEFT", -14, 0)
    hintTop:SetText("Click: put it on the NPC     Ctrl+Click: try it on yourself     Wheel: next / previous page")

    -- slot tabs
    local tabs = {}
    for i, sl in ipairs(SLOTS) do
        local b = SecureSlot(f)
        b:SetSize(34, 34); b:SetPoint("TOPLEFT", 264 + (i - 1) * 38, -50)
        Skin(b, C.panel2, C.border)
        local ic = b:CreateTexture(nil, "ARTWORK"); ic:SetPoint("TOPLEFT", 2, -2); ic:SetPoint("BOTTOMRIGHT", -2, 2)
        b.icon = ic
        b:SetScript("PostClick", function() f:Open(i) end)
        Tip(b, sl[1])
        tabs[i] = b
    end

    -- "on you": the whole outfit tried on your own character, plus what you hover
    local you = CreateFrame("DressUpModel", nil, f)
    you:SetPoint("TOPLEFT", 12, -50); you:SetSize(240, 470)
    local youBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    youBg:SetTexture(WHITE); youBg:SetPoint("TOPLEFT", you); youBg:SetPoint("BOTTOMRIGHT", you)
    youBg:SetGradientAlpha("VERTICAL", 0.02, 0.02, 0.03, 1, 0.12, 0.12, 0.16, 1)
    local youL = Text(f, 10, C.dim); youL:SetPoint("TOPLEFT", you, "BOTTOMLEFT", 0, -6); youL:SetWidth(240)
    youL:SetText("Whole outfit on your character (your race)")
    local youFacing, youZoom, youDrag, youX = 0, 0, false, 0
    you:EnableMouse(true); you:EnableMouseWheel(true)
    you:SetScript("OnMouseDown", function() youDrag = true; youX = GetCursorPosition() end)
    you:SetScript("OnMouseUp", function() youDrag = false end)
    you:SetScript("OnUpdate", function(self)
        if youDrag then local cx = GetCursorPosition(); youFacing = youFacing + (cx - youX) * 0.02; youX = cx; self:SetFacing(youFacing) end
    end)
    you:SetScript("OnMouseWheel", function(self, d) youZoom = math.max(-1, math.min(3, youZoom + d * 0.3)); self:SetPosition(youZoom, 0, 0) end)
    local hoverId
    -- show the NPC being made when it is your target (click the preview in the world), else yourself
    local function ModelUnit()
        return "player"   -- while the wardrobe is open the server shows you with the NPC's race and look
    end
    f.ModelUnit = ModelUnit
    local npcChk = Check(f, "Show as the NPC's race", function(v)
        IlusixnDevMenuDB.wardrobeDisguise = v
        if v then Send("DISGUISE", Pack()) else Send("UNDISGUISE") end
    end)
    npcChk:SetPoint("TOPLEFT", you, "BOTTOMLEFT", 2, -22)
    Tip(npcChk, "Show as the NPC's race", "While the wardrobe is open your character takes the NPC's race, face and hair, so every model here shows the NPC fully textured. You get your own look back when you close it (and before any save).")
    f.npcChk = npcChk
    local function DressYou()
        local u = ModelUnit()
        youL:SetText(f.disguised and "Showing the NPC's race and look" or "Showing you (your race)")
        you:SetUnit(u); you:Undress()
        for i = 1, #SLOTS do
            local v = (i == f.slot and hoverId) or L.items[i]
            if v and v > 0 then you:TryOn("item:" .. v) end
        end
        you:SetFacing(youFacing); you:SetPosition(youZoom, 0, 0)
    end

    local search = Edit(f, 360, 26); search:SetPoint("TOPLEFT", 264, -94); search:SetPlaceholder("Name or id, Enter")
    local none = Button(f, "Nothing in this slot", 150, 26, "danger", function() L.items[f.slot] = 0; p:Refresh(true); f:Paint() end)
    none:SetPoint("LEFT", search, "RIGHT", 8, 0)
    search:SetWidth(240)
    local zl = Text(f, 10, C.dim); zl:SetPoint("BOTTOMLEFT", 560, 18); zl:SetText("Tile zoom")
    local zoomAdj = 0
    local zm = Button(f, "-", 22, 22, nil, function() zoomAdj = zoomAdj - 0.25; f:Paint() end); zm:SetPoint("LEFT", zl, "RIGHT", 6, 0)
    local zp = Button(f, "+", 22, 22, nil, function() zoomAdj = zoomAdj + 0.25; f:Paint() end); zp:SetPoint("LEFT", zm, "RIGHT", 3, 0)

    -- tiles
    local tiles = {}
    local TW, TH = 128, 128
    for i = 1, PER do
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        local t = CreateFrame("Button", nil, f)
        t:SetSize(TW, TH); t:SetPoint("TOPLEFT", 264 + col * (TW + 6), -158 - row * (TH + 6))
        Skin(t, { 0.06, 0.065, 0.08, 1 }, C.border)
        local m = CreateFrame("DressUpModel", nil, t)
        m:SetPoint("TOPLEFT", 2, -2); m:SetPoint("BOTTOMRIGHT", -2, 18)
        m:EnableMouse(false)
        local nm = Text(t, 9, C.text); nm:SetPoint("BOTTOMLEFT", 4, 4); nm:SetPoint("BOTTOMRIGHT", -4, 4); nm:SetJustifyH("CENTER")
        t.model, t.name = m, nm
        t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        t:EnableMouseWheel(true)
        t:SetScript("OnMouseWheel", function(_, d) if d < 0 then f.Next() else f.Prev() end end)
        t:SetScript("OnEnter", function(self)
            local d = self.data
            if not d then return end
            self:SetBackdropBorderColor(unpack(C.accent))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. d.id); GameTooltip:Show()
            hoverId = d.id; DressYou()
        end)
        t:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(unpack(self.data and self.data.id == L.items[f.slot] and C.accent or C.border))
            GameTooltip:Hide(); hoverId = nil; DressYou()
        end)
        t:SetScript("OnClick", function(self)
            local d = self.data
            if not d then return end
            if IsControlKeyDown() then DressUpItemLink("item:" .. d.id) return end
            L.items[f.slot] = d.id
            p:Refresh(true); f:Paint(); DressYou()
            Toast((d.name or "Item") .. " put on the NPC", "ok")
        end)
        tiles[i] = t
    end

    local pager = Text(f, 11, C.dim); pager:SetPoint("BOTTOMLEFT", 264, 16)
    local results, total, spage, spages, view = {}, 0, 0, 1, 0
    -- filters: material / weapon type, sort, only items whose model exists
    local filt = { sub = -1, sort = 1, avail = true }
    local function run() Send("ISEARCH", search:GetText(), f.slot - 1, spage, filt.sub, filt.sort, filt.avail and 1 or 0) end
    local MAT = { { -1, "All" }, { 1, "Cloth" }, { 2, "Leather" }, { 3, "Mail" }, { 4, "Plate" } }
    local W1 = { { 100, "Axe" }, { 104, "Mace" }, { 107, "Sword" }, { 115, "Dagger" }, { 113, "Fist" } }
    local W2 = { { 101, "Axe 2H" }, { 105, "Mace 2H" }, { 108, "Sword 2H" }, { 106, "Polearm" }, { 110, "Staff" }, { 120, "Fishing pole" } }
    local TYPES = {
        armor = MAT,
        main = { { -1, "All" }, unpack(W1) },
        off = { { -1, "All" }, { 6, "Shield" }, { 99, "Held in off-hand" }, unpack(W1) },
        ranged = { { -1, "All" }, { 102, "Bow" }, { 103, "Gun" }, { 118, "Crossbow" }, { 119, "Wand" }, { 116, "Thrown" } },
    }
    for _, w in ipairs(W2) do table.insert(TYPES.main, w) end
    local function typesFor(slot)
        if slot == 12 then return TYPES.main elseif slot == 13 then return TYPES.off elseif slot == 14 then return TYPES.ranged end
        if slot == 3 or slot == 10 or slot == 11 then return nil end   -- shirt, cloak, tabard have no material
        return TYPES.armor
    end
    local chipRow = {}
    local chipBar = CreateFrame("Frame", nil, f); chipBar:SetPoint("TOPLEFT", 264, -126); chipBar:SetSize(660, 24)
    local function BuildChips()
        for _, c in ipairs(chipRow) do c:Hide() end
        local list = typesFor(f.slot)
        if not list then filt.sub = -1; return end
        local x = 0
        for i, it in ipairs(list) do
            local c = chipRow[i]
            if not c then c = Button(chipBar, "", 60, 22, "chip"); chipRow[i] = c end
            c:SetLabel(it[2]); c:SetWidth(math.max(44, c.label:GetStringWidth() + 16))
            c:ClearAllPoints(); c:SetPoint("LEFT", x, 0); x = x + c:GetWidth() + 4
            c:SetScript("OnClick", function() filt.sub = it[1]; spage, view = 0, 0; BuildChips(); run() end)
            c:SetActive(filt.sub == it[1]); c:Show()
        end
    end
    local sortB = Button(f, "Sort: quality", 110, 22, nil, nil)
    sortB:SetPoint("TOPRIGHT", -12, -96)
    local SORTS = { [0] = "name", "quality", "item level" }
    sortB:SetScript("OnClick", function() filt.sort = (filt.sort + 1) % 3; sortB:SetLabel("Sort: " .. SORTS[filt.sort]); spage, view = 0, 0; run() end)
    Tip(sortB, "Sort", "Click to switch: name, quality (best colour first), item level.")
    local availC = Check(f, "Available only", function(v) filt.avail = v; spage, view = 0, 0; run() end)
    availC:SetPoint("RIGHT", sortB, "LEFT", -96, 0); availC:Set(true)
    Tip(availC, "Available only", "Hide items whose model isn't in the game data (they would show nothing).")
    function f.Prev() if view == 1 then view = 0; f:Paint() elseif spage > 0 then spage = spage - 1; view = 1; run() end end
    function f.Next() if view == 0 and #results > PER then view = 1; f:Paint() elseif spage + 1 < spages then spage = spage + 1; view = 0; run() end end
    local prev = Button(f, "< Prev", 70, 24, nil, function() f.Prev() end)
    prev:SetPoint("BOTTOMRIGHT", -88, 12)
    local nxt = Button(f, "Next >", 70, 24, nil, function() f.Next() end)
    nxt:SetPoint("BOTTOMRIGHT", -12, 12)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); spage, view = 0, 0; run() end)

    function f:Paint()
        for i, b in ipairs(tabs) do
            local v = L.items[i]
            local tex = v and v > 0 and select(10, GetItemInfo(v))
            b.icon:SetTexture(tex or ("Interface\\Icons\\" .. SLOTS[i][2]))
            b.icon:SetDesaturated(not tex); b.icon:SetAlpha(tex and 1 or 0.5)
            b:SetBackdropBorderColor(unpack(i == self.slot and C.accent or C.border))
        end
        local cam = CAM[self.slot] or { 0.6, 0, 0 }
        self.missing = 0
        for i, t in ipairs(tiles) do
            local d = results[view * PER + i]
            t.data = d
            if d then
                t:Show()
                local name, _, q = GetItemInfo(d.id)
                if not name then self.missing = self.missing + 1; Fetch(d.id) end
                t.name:SetText(name or d.name); t.name:SetTextColor(unpack(QC[q or d.q] or C.text))
                t.model:SetUnit(ModelUnit()); t.model:Undress()
                t.model:TryOn("item:" .. d.id)
                t.model:SetFacing(cam[3]); t.model:SetPosition(cam[1] + zoomAdj, 0, cam[2])
                t:SetBackdropBorderColor(unpack(d.id == L.items[self.slot] and C.accent or C.border))
            else
                t:Hide()
            end
        end
        local shown = math.max(0, math.min(PER, #results - view * PER))
        pager:SetText(total == 0 and "No items found" or ("%d items   showing %d-%d"):format(total, spage * 30 + view * PER + 1, spage * 30 + view * PER + shown))
    end

    H.IB = function(a) results = {}; total = tonumber(a[2]) or 0; spages = tonumber(a[4]) or 1 end
    H.IR = function(a)
        local id = tonumber(a[2])
        Fetch(id)   -- make the client load it so the model and name can show
        table.insert(results, { id = id, name = a[3] or "", q = tonumber(a[4]) or 1 })
    end
    H.IE = function()
        f:Paint()
        WaitItems("wardrobe", function() if f:IsShown() and (f.missing or 0) > 0 then f:Paint(); DressYou() end end)
    end

    function f:Open(slot)
        self.slot = slot
        title:SetText("Wardrobe   |cffffc840" .. SLOTS[slot][1] .. "|r")
        if not self:IsShown() and IlusixnDevMenuDB.wardrobeDisguise ~= false then Send("DISGUISE", Pack()) end
        if self.slot ~= self.lastSlot then filt.sub = -1 end
        self.lastSlot = slot
        BuildChips()
        self:Show(); spage, view = 0, 0; results = {}
        self:Paint(); DressYou(); run()
    end
    f:SetScript("OnShow", function() DressYou() end)
    f:SetScript("OnHide", function(self)
        if self.disguised then Send("UNDISGUISE") end
        if self.dirty then self.dirty = false; Send("OPREV", Pack()) end
    end)
    -- the player's model changes a moment after the server sends the new look: redraw then
    local redraw = CreateFrame("Frame"); redraw:Hide()
    redraw:SetScript("OnUpdate", function(self, el) self.t = (self.t or 0) + el; if self.t > 0.35 then self:Hide(); self.t = 0; if f:IsShown() then f:Paint(); DressYou() end end end)
    H.DG = function(a)
        f.disguised = a[2] == "1"
        if f.npcChk then f.npcChk:Set(f.disguised) end
        redraw.t = 0; redraw:Show()
    end
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:SetScript("OnEvent", function() if f:IsShown() then f:Paint(); DressYou() end end)
    picker = f
end

-- ------------------------------------------------------------------ refresh + server replies
local pending
local debounce = CreateFrame("Frame"); debounce:Hide()
debounce:SetScript("OnUpdate", function(self, el)
    self.t = (self.t or 0) + el
    if self.t > 0.45 then
        self:Hide()
        -- while the wardrobe is open keep the same preview NPC (so it stays your target); update it on close
        if CoADevWardrobe and CoADevWardrobe:IsShown() then CoADevWardrobe.dirty = true else Send("OPREV", Pack()) end
    end
end)
function p:Refresh(changed)
    -- a race may exist for one gender only: switch to the one it has
    local ri = raceInfo[L.race]
    if ri and not ri[L.gender] then L.gender = ri[0] and 0 or 1 end
    raceList:Refresh()
    for i, b in ipairs(genders) do b:SetActive(b.v == L.gender); b:SetEnabledState(not ri or ri[b.v] ~= nil) end
    local info = raceInfo[L.race] and raceInfo[L.race][L.gender]
    BuildExtra()
    for i, s in ipairs(steppers) do
        local mx, unknown = MaxOf(i)
        s.val:SetText(unknown and ((L[s.key] + 1) .. " / ?") or ((L[s.key] + 1) .. " / " .. mx))
    end
    for i, r in ipairs(extraRows) do
        if r.val:IsShown() then r.val:SetText((r.get() + 1) .. " / " .. r.maxf()) end
    end
    for i, r in ipairs(slotRows) do
        local v = L.items[i] or 0
        if v > 0 then
            local name, _, q, _, _, _, _, _, _, tex = GetItemInfo(v)
            r.name:SetText(name or ("Item " .. v)); r.name:SetTextColor(unpack(q and ({ [0] = { 0.6, 0.6, 0.6, 1 }, { 1, 1, 1, 1 }, { 0.12, 1, 0, 1 }, { 0, 0.44, 0.87, 1 }, { 0.64, 0.21, 0.93, 1 }, { 1, 0.5, 0, 1 } })[q] or C.text))
            if tex then r.icon:SetTexture(tex); r.icon:SetDesaturated(false); r.icon:SetAlpha(1) end
        elseif v < 0 then
            r.name:SetText("Model " .. -v); r.name:SetTextColor(unpack(C.accent))
        else
            r.name:SetText("|cff666b78empty|r")
            r.icon:SetTexture("Interface\\Icons\\" .. SLOTS[i][2]); r.icon:SetDesaturated(true); r.icon:SetAlpha(0.45)
        end
        if not r.edit:HasFocus() then r.edit:SetText(v ~= 0 and (v > 0 and v or ("d" .. -v)) or "") end
    end
    if changed then FetchOutfit() end
    if changed and auto.value and p:IsShown() then debounce.t = 0; debounce:Show() end
end
H.ORB = function() races, raceInfo = {}, {} end
H.OR = function(a)
    local id, g = tonumber(a[2]), tonumber(a[4])
    if not raceInfo[id] then raceInfo[id] = {}; races[#races + 1] = { id = id, name = a[3] or ("Race " .. id), react = "F" } end
    raceInfo[id][g] = { tonumber(a[6]) or 0, tonumber(a[7]) or 0, tonumber(a[8]) or 0, tonumber(a[9]) or 0, tonumber(a[10]) or 0 }
end
H.ORE = function()
    table.sort(races, function(x, y) return x.id < y.id end)
    raceList.data = races; raceList:Refresh(); p:Refresh(false)
end
H.OL = function(a)
    if not Unpack(a[2]) then return end
    if pendingGear and S.selected then
        PutGear(pendingGear); pendingGear = nil
        Send("OSAVE", S.selected.guid, Pack())
        p:Refresh(false)
        return
    end
    p:Refresh(true); Toast("Loaded the look of " .. (a[3] or "?"), "ok")
end
-- the selected NPC has no outfit yet: dress it with the editor's race/face plus the saved gear
local er = H.ER
H.ER = function(a)
    if pendingGear and S.selected and (a[2] or ""):find("no outfit") then
        PutGear(pendingGear); pendingGear = nil
        Send("OSAVE", S.selected.guid, Pack()); p:Refresh(false)
        return Toast("That NPC used a normal model: it now uses the race shown in Create an NPC with this outfit", "ok")
    end
    if er then er(a) end
end
-- item names arrive asynchronously: refresh the slot names when the client learns them
FetchOutfit = function()
    for i = 1, #SLOTS do Fetch(L.items[i]) end
    WaitItems("create", function() if p:IsShown() then p:Refresh(false) end end)
end

function p:OnShowPage()
    if #races == 0 then Send("ORACES") end
    p:Refresh(false)
end

H.XL = function(a)
    local ad = Adapter()
    if not ad or not ad.Apply then return end
    local values = {}
    for k, n in (a[3] or ""):gmatch("([%w_]+)=(-?%d+)") do values[k] = tonumber(n) end
    pcall(ad.Apply, a[2], values)
end
