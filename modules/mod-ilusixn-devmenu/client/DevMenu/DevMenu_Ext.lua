-- Dev Menu, part 2: services editors, quest editor (with AI helper), objects & assets editor, emote picker.
local D = CoADev
local C, WHITE, FONT = D.C, D.WHITE, D.FONT
local Shown, Skin, Text, Tip, Button, Edit, Check = D.Shown, D.Skin, D.Text, D.Tip, D.Button, D.Edit, D.Check
local Header, Card, MakeList, Send, Toast, pages, S, H = D.Header, D.Card, D.MakeList, D.Send, D.Toast, D.pages, D.S, D.H

-- ------------------------------------------------------------------ shared helpers
local function G() return S.selected and S.selected.guid end
local function Entry() return S.selected and tonumber(S.selected.entry) end

-- long text goes to the server in chunks, then RSET stores it in one column
local function SendText(tbl, id, col, text)
    text = tostring(text or ""):gsub("\r", ""):gsub("\n", "$B")
    Send("BUFC")
    for i = 1, #text, 200 do Send("BUF", text:sub(i, i + 199)) end
    Send("RSET", tbl, id, col)
end

local function MultiEdit(parent, w, h)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetSize(w, h)
    Skin(sf, { 0.03, 0.035, 0.045, 1 }, C.border)
    local e = CreateFrame("EditBox", nil, sf)
    e:SetMultiLine(true)
    e:SetMaxLetters(0)
    e:SetWidth(w - 12)
    e:SetHeight(h)
    e:SetFont(FONT, 12, "")
    e:SetTextColor(unpack(C.text))
    e:SetTextInsets(6, 6, 4, 4)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnCursorChanged", function(self, x, y, cw, ch)
        local top = -y
        local cur = sf:GetVerticalScroll()
        if top < cur then sf:SetVerticalScroll(top)
        elseif top + ch > cur + h - 8 then sf:SetVerticalScroll(top + ch - h + 8) end
    end)
    e:SetScript("OnEditFocusGained", function() sf:SetBackdropBorderColor(unpack(C.accent)) end)
    e:SetScript("OnEditFocusLost", function() sf:SetBackdropBorderColor(unpack(C.border)) end)
    sf:SetScrollChild(e)
    sf:EnableMouse(true)
    sf:SetScript("OnMouseDown", function() e:SetFocus() end)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, d)
        local mx = math.max(0, e:GetHeight() - h)
        self:SetVerticalScroll(math.max(0, math.min(mx, self:GetVerticalScroll() - d * 20)))
    end)
    sf.edit = e
    function sf:GetText() return e:GetText() end
    function sf:SetText(t) e:SetText(t or "") end
    function sf:HasFocus() return e:HasFocus() end
    return sf
end

local function Label(parent, text, x, y, col)
    local t = Text(parent, 10, col or C.dim)
    t:SetPoint("TOPLEFT", x, y)
    t:SetText(text)
    return t
end

-- chip group: one active at a time
local function Chips(parent, items, x, y, w, onPick)
    local g = { btns = {} }
    for i, it in ipairs(items) do
        local b = Button(parent, it[2], w, 22, "chip", function() g:Set(it[1]); if onPick then onPick(it[1]) end end)
        b:SetPoint("TOPLEFT", x + (i - 1) * (w + 4), y)
        b.v = it[1]
        g.btns[i] = b
    end
    function g:Set(v) self.value = v; for _, b in ipairs(self.btns) do b:SetActive(b.v == v) end end
    return g
end

-- generic record cache from RGET (RH / RR / RX)
local REC, recCur = {}, nil
local recWaiters = {}
H.RH = function(a) recCur = a[2] .. "#" .. a[3]; REC[recCur] = {} end
H.RR = function(a)
    local r = REC[recCur]
    if not r then return end
    if a[3] == "0" or not r[a[2]] then r[a[2]] = a[4] or "" else r[a[2]] = r[a[2]] .. (a[4] or "") end
end
H.RX = function(a)
    local key = a[2] .. "#" .. a[3]
    local fn = recWaiters[key]
    recWaiters[key] = nil
    if fn then fn(REC[key] or {}) end
end
local function GetRecord(tbl, id, fn)
    recWaiters[tbl .. "#" .. id] = fn
    Send("RGET", tbl, id)
end

-- list tables from LGET (LH / LR / LE)
local LISTS, listWaiters = {}, {}
H.LH = function(a) LISTS[a[2]] = {} end
H.LR = function(a)
    local row = {}
    for i = 3, #a do
        local k, v = a[i]:match("^([^=]+)=(.*)$")
        if k then row[k] = v end
    end
    table.insert(LISTS[a[2]], row)
end
H.LE = function(a)
    local fn = listWaiters[a[2]]
    if fn then fn(LISTS[a[2]] or {}) end
end
local function GetList(tbl, key, fn)
    listWaiters[tbl] = fn
    Send("LGET", tbl, key)
end

local idWaiters = {}
H.NI = function(a) local fn = idWaiters[a[2]]; idWaiters[a[2]] = nil; if fn then fn(tonumber(a[3])) end end
local function NewId(kind, fn) idWaiters[kind] = fn; Send("NEWID", kind) end

-- ------------------------------------------------------------------ arrows, compass pad and 3-axis gizmo
local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"   -- plain white circle
local ARROW = "Interface\\Minimap\\MinimapArrow"                    -- plain triangle pointing up
local function RotTex(tex, a)
    local c, s = math.cos(a), math.sin(a)
    local function p(x, y) return 0.5 + (x - 0.5) * c - (y - 0.5) * s, 0.5 + (x - 0.5) * s + (y - 0.5) * c end
    local ulx, uly = p(0, 0); local llx, lly = p(0, 1); local urx, ury = p(1, 0); local lrx, lry = p(1, 1)
    tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end
-- point a texture on screen: deg clockwise from up
local function PointTex(tex, deg) RotTex(tex, -math.rad(deg)) end

local function Disc(parent, size, col, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(DISC); t:SetSize(size, size); t:SetVertexColor(unpack(col))
    return t
end

-- round flat button with a triangle arrow (deg: 0 up, 90 right, 180 down, 270 left)
local function ArrowButton(parent, deg, size, tip, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local bg = Disc(b, size, C.panel2, "ARTWORK"); bg:SetPoint("CENTER")
    local t = b:CreateTexture(nil, "OVERLAY")
    t:SetTexture(ARROW); t:SetSize(size * 0.62, size * 0.62); t:SetPoint("CENTER")
    PointTex(t, deg)
    b.arrow, b.bg = t, bg
    b:SetScript("OnEnter", function() bg:SetVertexColor(unpack(C.hover)); t:SetVertexColor(unpack(C.accent)) end)
    b:SetScript("OnLeave", function() bg:SetVertexColor(unpack(C.panel2)); t:SetVertexColor(1, 1, 1) end)
    b:SetScript("OnMouseDown", function() t:SetSize(size * 0.54, size * 0.54) end)
    b:SetScript("OnMouseUp", function() t:SetSize(size * 0.62, size * 0.62) end)
    b:SetScript("OnClick", onClick)
    if tip then Tip(b, tip) end
    return b
end

local function TurnButton(parent, left, size, tip, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local bg = Disc(b, size, C.panel2, "ARTWORK"); bg:SetPoint("CENTER")
    local t = b:CreateTexture(nil, "OVERLAY")
    t:SetTexture("Interface\\Buttons\\UI-RefreshButton"); t:SetSize(size * 0.6, size * 0.6); t:SetPoint("CENTER")
    if left then t:SetTexCoord(1, 0, 0, 1) end
    b:SetScript("OnEnter", function() bg:SetVertexColor(unpack(C.hover)); t:SetVertexColor(unpack(C.accent)) end)
    b:SetScript("OnLeave", function() bg:SetVertexColor(unpack(C.panel2)); t:SetVertexColor(1, 1, 1) end)
    b:SetScript("OnClick", onClick)
    if tip then Tip(b, tip) end
    return b
end

-- remote-control style pad: ring with 4 arrows and a centre button, turn buttons below, height on the side
-- nudge(fwd, right, up, turn) gets -1/0/1 units
local function Compass(parent, nudge, center)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(186, 150)
    local pad = CreateFrame("Frame", nil, f)
    pad:SetSize(124, 124); pad:SetPoint("TOPLEFT", 4, 0)
    local rim = Disc(pad, 124, C.border); rim:SetPoint("CENTER")
    local face = Disc(pad, 120, { 0.07, 0.075, 0.09, 1 }); face:SetPoint("CENTER")
    face:SetDrawLayer("BACKGROUND", 1)
    local dirs = { { 0, 1, 0, "Forward" }, { 180, -1, 0, "Back" }, { 270, 0, -1, "Left" }, { 90, 0, 1, "Right" } }
    for _, d in ipairs(dirs) do
        local a = math.rad(d[1])
        local b = ArrowButton(pad, d[1], 34, d[4], function() nudge(d[2], d[3], 0, 0) end)
        b:SetPoint("CENTER", pad, "CENTER", math.sin(a) * 40, math.cos(a) * 40)
        b.bg:SetVertexColor(0, 0, 0, 0)
        b:SetScript("OnLeave", function() b.bg:SetVertexColor(0, 0, 0, 0); b.arrow:SetVertexColor(1, 1, 1) end)
    end
    local ok = CreateFrame("Button", nil, pad)
    ok:SetSize(44, 44); ok:SetPoint("CENTER")
    local okRim = Disc(ok, 44, C.border, "ARTWORK"); okRim:SetPoint("CENTER")
    local okBg = Disc(ok, 40, C.panel2, "ARTWORK"); okBg:SetPoint("CENTER"); okBg:SetDrawLayer("ARTWORK", 1)
    local okT = Text(ok, 10, C.text); okT:SetPoint("CENTER"); okT:SetJustifyH("CENTER"); okT:SetText(center and center.label or "")
    ok:SetScript("OnEnter", function() okBg:SetVertexColor(unpack(C.hover)) end)
    ok:SetScript("OnLeave", function() okBg:SetVertexColor(unpack(C.panel2)) end)
    if center then ok:SetScript("OnClick", center.click); Tip(ok, center.tip or center.label) end
    local tl = TurnButton(f, true, 28, "Turn left", function() nudge(0, 0, 0, 1) end); tl:SetPoint("TOPLEFT", 4, -122)
    local tr = TurnButton(f, false, 28, "Turn right", function() nudge(0, 0, 0, -1) end); tr:SetPoint("TOPLEFT", 100, -122)
    local tt = Text(f, 9, C.dim); tt:SetPoint("TOPLEFT", 36, -132); tt:SetText("turn")
    local up = ArrowButton(f, 0, 30, "Up", function() nudge(0, 0, 1, 0) end); up:SetPoint("TOPLEFT", 146, -20)
    local hl = Text(f, 9, C.dim); hl:SetPoint("TOP", up, "BOTTOM", 0, -8); hl:SetText("height"); hl:SetJustifyH("CENTER")
    local dn = ArrowButton(f, 180, 30, "Down", function() nudge(0, 0, -1, 0) end); dn:SetPoint("TOPLEFT", 146, -74)
    return f
end

-- 3-axis gizmo: drag an arrow to move along that world axis, drag the ring to rotate.
-- opts.move(dx, dy, dz) in steps, opts.rotate(deltaDeg) on release
local function Gizmo(parent, size, opts)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    local R = size / 2 - 10
    local ringDots = {}
    for i = 0, 119 do
        local d = f:CreateTexture(nil, "BACKGROUND")
        d:SetTexture(WHITE); d:SetSize(2, 2)
        local a = i / 120 * 2 * math.pi
        d:SetPoint("CENTER", f, "CENTER", math.cos(a) * R, math.sin(a) * R)
        ringDots[#ringDots + 1] = d
    end
    function f:SetRingColor(r, g, b) for _, d in ipairs(ringDots) do d:SetVertexColor(r, g, b, 0.55) end end
    f:SetRingColor(0.6, 0.62, 0.7)
    local knob = Disc(f, 10, C.accent, "ARTWORK"); knob:Hide()
    f:EnableMouse(true)
    local dragging, a0, acc = false, 0, 0
    local function cursorAng()
        local mx, my = GetCursorPosition()
        local sc = f:GetEffectiveScale()
        local cx, cy = f:GetCenter()
        return math.deg(math.atan2(my / sc - cy, mx / sc - cx))
    end
    f:SetScript("OnMouseDown", function() dragging = true; a0 = cursorAng(); acc = 0; knob:Show() end)
    local lbl = Text(f, 11, C.accent); lbl:SetPoint("BOTTOM", f, "BOTTOM", 0, -14); lbl:SetJustifyH("CENTER")
    f:SetScript("OnMouseUp", function()
        if dragging and math.abs(acc) >= 0.5 then opts.rotate(math.floor(acc + 0.5)) end
        dragging = false; knob:Hide(); lbl:SetText("")
    end)
    f:SetScript("OnUpdate", function()
        if not dragging then return end
        local a = cursorAng()
        local d = a - a0
        if d > 180 then d = d - 360 elseif d < -180 then d = d + 360 end
        acc = acc + d; a0 = a
        knob:ClearAllPoints(); knob:SetPoint("CENTER", f, "CENTER", math.cos(math.rad(a)) * R, math.sin(math.rad(a)) * R)
        lbl:SetText(("rotate %+d°"):format(math.floor(acc + 0.5)))
    end)
    -- world axes drawn like an editor: X north (left), Y west (down-right), Z up
    local AX = {
        { "X", { 0.95, 0.3, 0.3 }, -1, 0.18, { 1, 0, 0 } },
        { "Y", { 0.35, 0.55, 1 }, 0.74, -0.6, { 0, 1, 0 } },
        { "Z", { 0.35, 0.9, 0.45 }, 0, 1, { 0, 0, 1 } },
    }
    local L = R - 18
    for _, ax in ipairs(AX) do
        local n = math.sqrt(ax[3] * ax[3] + ax[4] * ax[4])
        local ux, uy = ax[3] / n, ax[4] / n
        for k = 6, L - 6, 2 do
            local d = f:CreateTexture(nil, "ARTWORK")
            d:SetTexture(WHITE); d:SetVertexColor(ax[2][1], ax[2][2], ax[2][3], 0.95); d:SetSize(3, 3)
            d:SetPoint("CENTER", f, "CENTER", ux * k, uy * k)
        end
        local h = CreateFrame("Button", nil, f)
        h:SetSize(26, 26)
        h:SetPoint("CENTER", f, "CENTER", ux * L, uy * L)
        h:SetFrameLevel(f:GetFrameLevel() + 3)
        local head = h:CreateTexture(nil, "OVERLAY")
        head:SetTexture(ARROW); head:SetSize(24, 24); head:SetPoint("CENTER")
        head:SetVertexColor(unpack(ax[2]))
        PointTex(head, math.deg(math.atan2(ux, uy)))
        local t = Text(f, 11, ax[2], "OUTLINE")
        t:SetPoint("CENTER", f, "CENTER", ux * (L + 18), uy * (L + 18)); t:SetJustifyH("CENTER"); t:SetText(ax[1])
        h:SetScript("OnEnter", function() head:SetVertexColor(1, 1, 1) end)
        h:SetScript("OnLeave", function() head:SetVertexColor(unpack(ax[2])) end)
        Tip(h, ax[1] .. " axis", "Drag along the arrow to slide (one step every 16 pixels). Click: one step. Shift+click: one step back.")
        local hd, sx, sy, moved = false, 0, 0, 0
        h:SetScript("OnMouseDown", function()
            hd = true; moved = 0
            local mx, my = GetCursorPosition(); local sc = f:GetEffectiveScale(); sx, sy = mx / sc, my / sc
        end)
        h:SetScript("OnMouseUp", function()
            if hd and moved == 0 then
                local s = IsShiftKeyDown() and -1 or 1
                opts.move(ax[5][1] * s, ax[5][2] * s, ax[5][3] * s)
            end
            hd = false; lbl:SetText("")
        end)
        h:SetScript("OnUpdate", function()
            if not hd then return end
            local mx, my = GetCursorPosition(); local sc = f:GetEffectiveScale(); mx, my = mx / sc, my / sc
            local along = (mx - sx) * ux + (my - sy) * uy
            local steps = math.floor(math.abs(along) / 16) * (along < 0 and -1 or 1)
            if steps ~= 0 then
                opts.move(ax[5][1] * steps, ax[5][2] * steps, ax[5][3] * steps)
                moved = moved + steps
                sx, sy = sx + ux * 16 * steps, sy + uy * 16 * steps
                lbl:SetText(("%s %+d"):format(ax[1], moved))
            end
        end)
    end
    local c0 = Disc(f, 10, { 1, 1, 1, 1 }, "OVERLAY"); c0:SetPoint("CENTER")
    return f
end

-- ================================================================== EMOTE PICKER (every emote)
do
    local f = CreateFrame("Frame", "CoADevEmotePicker", UIParent)
    f:SetSize(360, 470)
    f:SetPoint("CENTER", 200, 0)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    Skin(f, C.bg, { 0, 0, 0, 1 })
    f:Hide()
    tinsert(UISpecialFrames, "CoADevEmotePicker")
    local t = Text(f, 13, C.text); t:SetPoint("TOPLEFT", 12, -10); t:SetText("All emotes")
    local x = Button(f, "X", 22, 22, nil, function() f:Hide() end); x:SetPoint("TOPRIGHT", -8, -8)
    local search = Edit(f, 336, 24); search:SetPoint("TOPLEFT", 12, -38); search:SetPlaceholder("Search emotes (name or id)")
    local onlyLoop = Check(f, "Only looping actions", function() f:Filter() end)
    onlyLoop:SetPoint("TOPLEFT", 14, -70)
    local list = MakeList(f, 15, 22, { { w = 220 }, { w = 40, color = C.dim, size = 10, right = true }, { w = 40, color = C.accent, size = 10 } }, function(d, btn)
        if not G() then return Toast("Select an NPC first", "err") end
        if btn == "RightButton" or not d[3] then Send("PLAY", G(), d[1]) else Send("EMOTE", G(), d[1]) end
    end)
    list:SetPoint("TOPLEFT", 12, -94)
    list:SetPoint("BOTTOMRIGHT", -12, 34)
    list.format = function(d) return { d[2], d[1], d[3] and "loop" or "" } end
    local hint = Text(f, 10, C.dim); hint:SetPoint("BOTTOMLEFT", 12, 12)
    hint:SetText("Click: set as its looping action (saved)   Right-click: play once")
    function f:Filter()
        local q = search:GetText():lower()
        local out = {}
        for _, e in ipairs(CoADevEmotes) do
            if (not onlyLoop.value or e[3]) and (q == "" or e[2]:lower():find(q, 1, true) or tostring(e[1]) == q) then out[#out + 1] = e end
        end
        list.data = out; list.offset = 0; list:Refresh()
    end
    search:HookScript("OnTextChanged", function() f:Filter() end)
    S.EmotePicker = function() f:Show(); f:Filter() end
end

-- ================================================================== SERVICES (selected NPC)
do
    local f = S.subs.svc
    local section = "vendor"
    local panes = {}
    local secChips = Chips(f, { { "vendor", "Vendor" }, { "trainer", "Trainer" }, { "gossip", "Gossip & text" }, { "other", "Other services" } }, 14, -12, 120, function(v)
        section = v
        for k, p in pairs(panes) do Shown(p, k == v) end
        S.OnServices()
    end)
    for _, k in ipairs({ "vendor", "trainer", "gossip", "other" }) do
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", 0, -40)
        p:SetPoint("BOTTOMRIGHT")
        p:Hide()
        panes[k] = p
    end

    -- ---- vendor
    local vend = panes.vendor
    local vInfo = Label(vend, "", 14, -2)
    local vList = MakeList(vend, 6, 22, { { w = 70, color = C.dim }, { w = 220 }, { w = 70, size = 10 }, { w = 80, size = 10 }, { w = 240, size = 10 } }, function(d) vend.sel = d; vend.list:Refresh(); if vend.OnPick then vend.OnPick(d) end end)
    vend.list = vList
    vList:SetPoint("TOPLEFT", 14, -18)
    vList:SetPoint("TOPRIGHT", -14, -18)
    vList:SetHeight(136)
    vList.format = function(d) return { d.item, d._name ~= "" and d._name or "(unknown item)", d.maxcount ~= "0" and ("stock " .. d.maxcount) or "unlimited", d.incrtime ~= "0" and ("restock " .. d.incrtime .. "s") or "", d.ExtendedCost ~= "0" and (vend.XC and vend.XC[d.ExtendedCost] or ("currency #" .. d.ExtendedCost)) or "gold" } end
    vList.isSelected = function(d) return d == vend.sel end
    local function LoadVendor() if Entry() then GetList("npc_vendor", Entry(), function(rows) vList.data = rows; vList.offset = 0; vend.sel = nil; vList:Refresh(); vInfo:SetText(#rows .. " items sold by every spawn of NPC type " .. Entry()) end) end end
    Label(vend, "Item id", 14, -162); local vi = Edit(vend, 90, 24, true); vi:SetPoint("TOPLEFT", 14, -176)
    Label(vend, "Stock (0 = unlimited)", 112, -162); local vm = Edit(vend, 70, 24, true); vm:SetPoint("TOPLEFT", 112, -176)
    Label(vend, "Restock (s)", 240, -162); local vr = Edit(vend, 70, 24, true); vr:SetPoint("TOPLEFT", 240, -176)
    Label(vend, "Extended cost id", 320, -162); local ve = Edit(vend, 80, 24, true); ve:SetPoint("TOPLEFT", 320, -176)
    local va = Button(vend, "Add item", 100, 24, "accent", function()
        local it = tonumber(vi:GetText())
        if not Entry() or not it then return Toast("Type an item id", "err") end
        Send("LADD", "npc_vendor", "entry=" .. Entry(), "item=" .. it, "maxcount=" .. (tonumber(vm:GetText()) or 0), "incrtime=" .. (tonumber(vr:GetText()) or 0), "ExtendedCost=" .. (tonumber(ve:GetText()) or 0), "slot=0")
        Send("RLOAD"); LoadVendor()
    end)
    va:SetPoint("TOPLEFT", 412, -176)
    local vd = Button(vend, "Remove selected", 130, 24, "danger", function()
        if not vend.sel then return Toast("Click an item in the list first", "err") end
        Send("LDEL", "npc_vendor", "entry=" .. Entry(), "item=" .. vend.sel.item, "ExtendedCost=" .. vend.sel.ExtendedCost)
        Send("RLOAD"); LoadVendor()
    end)
    vd:SetPoint("TOPLEFT", 518, -176)
    local vn = Text(vend, 10, C.dim); vn:SetPoint("TOPLEFT", 14, -206); vn:SetWidth(660)
    vn:SetText("Tick Vendor in Role & faction so players can open the shop. Shift-click an item link into Item id.")
    vi:HookScript("OnTextChanged", function(self)
        local id = self:GetText():match("item:(%d+)")
        if id then self:SetText(id) end
    end)

    -- price & currency of the selected item
    local XC = {}   -- extended cost id -> text, for the list column
    vend.XC = XC
    local selTxt = Label(vend, "Click an item in the list to set its price or currency.", 14, -226, C.accent)
    Label(vend, "Gold price (every vendor)", 14, -244)
    local pg = Edit(vend, 60, 22, true); pg:SetPoint("TOPLEFT", 14, -258)
    local ps = Edit(vend, 36, 22, true); ps:SetPoint("LEFT", pg, "RIGHT", 4, 0)
    local pc = Edit(vend, 36, 22, true); pc:SetPoint("LEFT", ps, "RIGHT", 4, 0)
    local gsc = Text(vend, 10, C.dim); gsc:SetPoint("LEFT", pc, "RIGHT", 6, 0); gsc:SetText("g  s  c")
    local pSet = Button(vend, "Set price", 90, 22, "accent", function()
        if not vend.sel then return Toast("Click an item in the list first", "err") end
        local copper = (tonumber(pg:GetText()) or 0) * 10000 + (tonumber(ps:GetText()) or 0) * 100 + (tonumber(pc:GetText()) or 0)
        Send("IPRICE", vend.sel.item, copper)
    end)
    pSet:SetPoint("TOPLEFT", 200, -258)
    Tip(pSet, "Set price", "The 3.3.5 client shows one gold price per item, so this changes it at every vendor that sells it. Items with a currency below cost only the currency.")
    H.IP = function(a)
        local c = tonumber(a[3]) or 0
        pg:SetText(math.floor(c / 10000)); ps:SetText(math.floor(c / 100) % 100); pc:SetText(c % 100)
    end
    Label(vend, "Currency (badges, emblems, honor, tokens...): search, click one, then Use", 14, -286)
    local xf = Edit(vend, 220, 22); xf:SetPoint("TOPLEFT", 14, -300); xf:SetPlaceholder("emblem, honor, badge, mark...  (Enter)")
    local xl
    xl = MakeList(vend, 3, 20, { { w = 50, color = C.dim }, { w = 560, size = 10 } }, function(d) vend.xsel = d; xl:Refresh() end)
    xl:SetPoint("TOPLEFT", 14, -324); xl:SetPoint("TOPRIGHT", -14, -324); xl:SetHeight(64)
    xl.format = function(d) return { d.id, d.text } end
    xl.isSelected = function(d) return d == vend.xsel end
    xf:SetScript("OnEnterPressed", function(self) self:ClearFocus(); xl.data = {}; xl.offset = 0; Send("XCSEARCH", self:GetText()) end)
    local xUse = Button(vend, "Use for selected item", 160, 22, "accent", function()
        if not vend.sel then return Toast("Click an item in the shop list first", "err") end
        if not vend.xsel then return Toast("Search and click a currency first", "err") end
        Send("VCUR", Entry(), vend.sel.item, vend.sel.ExtendedCost, vend.xsel.id); LoadVendor()
    end)
    xUse:SetPoint("LEFT", xf, "RIGHT", 8, 0)
    local xGold = Button(vend, "Gold only", 90, 22, nil, function()
        if not vend.sel then return Toast("Click an item in the shop list first", "err") end
        Send("VCUR", Entry(), vend.sel.item, vend.sel.ExtendedCost, 0); LoadVendor()
    end)
    xGold:SetPoint("LEFT", xUse, "RIGHT", 4, 0)
    H.XCB = function() xl.data = {} end
    H.XC = function(a) XC[a[2]] = a[3]; xl.data[#xl.data + 1] = { id = a[2], text = a[3] }; xl:Refresh() end
    H.XCE = function(a) if tonumber(a[2]) == 0 then Toast("No currency matches", "err") end; vList:Refresh() end
    vend.OnPick = function(d)
        selTxt:SetText("Selected: " .. (d._name ~= "" and d._name or ("item " .. d.item)) .. (d.ExtendedCost ~= "0" and ("  -  currency " .. (XC[d.ExtendedCost] or ("#" .. d.ExtendedCost))) or "  -  gold"))
        Send("IPRICE", d.item)
        if d.ExtendedCost ~= "0" and not XC[d.ExtendedCost] then Send("XCSEARCH", d.ExtendedCost) end
    end

    -- ---- trainer
    local tr = panes.trainer
    tr.id = nil
    local tInfo = Label(tr, "", 14, -2)
    local tType = Chips(tr, { { "0", "Class" }, { "1", "Mount / riding" }, { "2", "Profession" }, { "3", "Pet" } }, 14, -20, 110)
    Label(tr, "Requirement (class / race / skill id)", 470, -6)
    local tReq = Edit(tr, 80, 22, true); tReq:SetPoint("TOPLEFT", 470, -20)
    local tGreet = Edit(tr, 480, 24); tGreet:SetPoint("TOPLEFT", 14, -48); tGreet:SetPlaceholder("Greeting shown in the trainer window")
    local tSave = Button(tr, "Save trainer", 110, 24, "accent", function()
        if not tr.id then return end
        SendText("trainer", tr.id, "Type", tType.value or "0"); SendText("trainer", tr.id, "Requirement", tReq:GetText()); SendText("trainer", tr.id, "Greeting", tGreet:GetText())
        Send("RLOAD")
    end)
    tSave:SetPoint("LEFT", tGreet, "RIGHT", 8, 0)
    local tNew = Button(tr, "Create a trainer for this NPC", 220, 24, "accent", function()
        if not Entry() then return end
        NewId("trainer", function(id)
            Send("LADD", "creature_default_trainer", "CreatureId=" .. Entry(), "TrainerId=" .. id)
            SendText("trainer", id, "Type", "2"); SendText("trainer", id, "Greeting", "What would you like to learn?")
            Send("RLOAD"); S.OnServices()
        end)
    end)
    tNew:SetPoint("TOPLEFT", 14, -80)
    local tList = MakeList(tr, 8, 22, { { w = 60, color = C.dim }, { w = 250 }, { w = 90, size = 10 }, { w = 60, size = 10 }, { w = 110, size = 10 } }, function(d) tr.sel = d; tr.list:Refresh() end)
    tr.list = tList
    tList:SetPoint("TOPLEFT", 14, -80); tList:SetPoint("TOPRIGHT", -14, -80); tList:SetHeight(180)
    tList.format = function(d) return { d.SpellId, d._name, GetCoinTextureString and GetCoinTextureString(tonumber(d.MoneyCost) or 0) or d.MoneyCost, "lvl " .. d.ReqLevel, d.ReqSkillLine ~= "0" and ("skill " .. d.ReqSkillLine .. " " .. d.ReqSkillRank) or "" } end
    tList.isSelected = function(d) return d == tr.sel end
    Label(tr, "Spell id", 14, -268); local ts = Edit(tr, 80, 24, true); ts:SetPoint("TOPLEFT", 14, -282)
    Label(tr, "Cost (copper)", 100, -268); local tc = Edit(tr, 80, 24, true); tc:SetPoint("TOPLEFT", 100, -282)
    Label(tr, "Level", 186, -268); local tl = Edit(tr, 50, 24, true); tl:SetPoint("TOPLEFT", 186, -282)
    Label(tr, "Skill line", 242, -268); local tk = Edit(tr, 60, 24, true); tk:SetPoint("TOPLEFT", 242, -282)
    Label(tr, "Skill rank", 308, -268); local tkr = Edit(tr, 60, 24, true); tkr:SetPoint("TOPLEFT", 308, -282)
    local function LoadTrainerSpells() if tr.id then GetList("trainer_spell", tr.id, function(rows) tList.data = rows; tList.offset = 0; tr.sel = nil; tList:Refresh() end) end end
    local tAdd = Button(tr, "Teach this spell", 130, 24, "accent", function()
        local sp = tonumber(ts:GetText())
        if not tr.id or not sp then return Toast("Type a spell id", "err") end
        Send("LADD", "trainer_spell", "TrainerId=" .. tr.id, "SpellId=" .. sp, "MoneyCost=" .. (tonumber(tc:GetText()) or 0), "ReqLevel=" .. (tonumber(tl:GetText()) or 1), "ReqSkillLine=" .. (tonumber(tk:GetText()) or 0), "ReqSkillRank=" .. (tonumber(tkr:GetText()) or 0))
        Send("RLOAD"); LoadTrainerSpells()
    end)
    tAdd:SetPoint("TOPLEFT", 376, -282)
    local tDel = Button(tr, "Remove selected", 130, 24, "danger", function()
        if not tr.sel then return Toast("Click a spell first", "err") end
        Send("LDEL", "trainer_spell", "TrainerId=" .. tr.id, "SpellId=" .. tr.sel.SpellId)
        Send("RLOAD"); LoadTrainerSpells()
    end)
    tDel:SetPoint("TOPLEFT", 512, -282)
    ts:HookScript("OnTextChanged", function(self) local id = self:GetText():match("spell:(%d+)") or self:GetText():match("enchant:(%d+)"); if id then self:SetText(id) end end)
    local trWidgets = { tType.btns[1], tType.btns[2], tType.btns[3], tType.btns[4], tReq, tGreet, tSave, tList, ts, tc, tl, tk, tkr, tAdd, tDel }
    local function LoadTrainer()
        if not Entry() then return end
        GetList("creature_default_trainer", Entry(), function(rows)
            tr.id = rows[1] and tonumber(rows[1].TrainerId)
            for _, w in ipairs(trWidgets) do Shown(w, tr.id ~= nil) end
            Shown(tNew, tr.id == nil)
            if not tr.id then tInfo:SetText("This NPC type has no trainer yet."); return end
            tInfo:SetText("Trainer " .. tr.id .. " (shared by every spawn of NPC type " .. Entry() .. "). Tick Trainer in Role & faction.")
            GetRecord("trainer", tr.id, function(r) tType:Set(r.Type or "0"); tReq:SetText(r.Requirement or "0"); tGreet:SetText(r.Greeting or "") end)
            LoadTrainerSpells()
        end)
    end

    -- ---- gossip & text
    local go = panes.gossip
    go.menu, go.root, go.text = nil, nil, nil
    local gInfo = Label(go, "", 14, -2)
    local gBack = Button(go, "Back to the NPC's first menu", 200, 22, nil, function() go.menu = go.root; S.LoadGossip() end)
    gBack:SetPoint("TOPRIGHT", -14, 0)
    local gNew = Button(go, "Create a talk menu for this NPC", 230, 24, "accent", function()
        if not G() then return end
        NewId("gossip", function(mid)
            NewId("npc_text", function(tid)
                SendText("npc_text", tid, "text0_0", "Greetings, $N.")
                SendText("npc_text", tid, "Probability0", "1")
                Send("LADD", "gossip_menu", "MenuID=" .. mid, "TextID=" .. tid)
                Send("RLOAD")
                Send("TSET", G(), "gossip", mid, 0)
                Send("ROLE", G(), bit.bor(tonumber(S.selected.npcflag) or 0, 1))   -- talk menus need the gossip flag
                go.root, go.menu = mid, mid
                S.LoadGossip()
            end)
        end)
    end)
    gNew:SetPoint("TOPLEFT", 14, -22)
    local gL1 = Label(go, "What the NPC says (male players)", 14, -20)
    local gText = MultiEdit(go, 330, 70); gText:SetPoint("TOPLEFT", 14, -34)
    local gL2 = Label(go, "Female players (empty = same)", 352, -20)
    local gTextF = MultiEdit(go, 330, 70); gTextF:SetPoint("TOPLEFT", 352, -34)
    local gSaveT = Button(go, "Save text", 90, 22, "accent", function()
        if not go.text then return end
        SendText("npc_text", go.text, "text0_0", gText:GetText()); SendText("npc_text", go.text, "text0_1", gTextF:GetText())
        SendText("npc_text", go.text, "Probability0", "1")
        Send("RLOAD")
    end)
    gSaveT:SetPoint("TOPLEFT", 14, -108)
    local gTip = Text(go, 10, C.dim); gTip:SetPoint("LEFT", gSaveT, "RIGHT", 10, 0)
    gTip:SetText("$N name   $C class   $R race   Enter = new line")
    local ICON = { [0] = "chat", "bag", "flight", "book", "?", "inn", "money", "talk", "tabard", "battle", "dot" }
    local gList = MakeList(go, 6, 22, { { w = 30, color = C.dim, size = 10 }, { w = 44, color = C.dim, size = 10 }, { w = 380 }, { w = 90, size = 10 }, { w = 100, size = 10 } }, function(d) go.sel = d; go.list:Refresh() end)
    go.list = gList
    gList:SetPoint("TOPLEFT", 14, -136); gList:SetPoint("TOPRIGHT", -14, -136); gList:SetHeight(136)
    local TYPES = { [1] = "talk", [2] = "quests", [3] = "vendor", [4] = "flight", [5] = "trainer", [8] = "inn", [9] = "bank", [10] = "charter", [11] = "tabard", [12] = "battle", [13] = "auction", [14] = "stable", [15] = "repair", [16] = "reset talents", [18] = "dual spec" }
    gList.format = function(d) return { d.OptionID, ICON[tonumber(d.OptionIcon)] or d.OptionIcon, d.OptionText, TYPES[tonumber(d.OptionType)] or ("type " .. d.OptionType), d.ActionMenuID ~= "0" and ("opens menu " .. d.ActionMenuID) or "" } end
    gList.isSelected = function(d) return d == go.sel end
    local gOptText = Edit(go, 330, 24); gOptText:SetPoint("TOPLEFT", 14, -280); gOptText:SetPlaceholder("Option text, e.g.  Tell me about this town.")
    local gL3 = Label(go, "Opens menu id", 352, -268); local gAct = Edit(go, 80, 24, true); gAct:SetPoint("TOPLEFT", 352, -280)
    local gSub = Button(go, "New submenu", 100, 24, nil, function() NewId("gossip", function(id) gAct:SetText(id) end) end)
    gSub:SetPoint("LEFT", gAct, "RIGHT", 6, 0)
    Tip(gSub, "New submenu", "Reserves a new menu id. After adding the option, select it and press Open submenu to write what the NPC answers.")
    -- presets: option type, npc flag, icon, default text
    local PRESETS = {
        { "Talk", 1, 1, 0, "Tell me more." }, { "Shop", 3, 128, 1, "Let me browse your goods." }, { "Train", 5, 16, 3, "Train me." },
        { "Inn", 8, 65536, 5, "Make this inn your home." }, { "Bank", 9, 131072, 6, "I would like to check my deposit box." },
        { "Flight", 4, 8192, 2, "I need a ride." }, { "Stable", 14, 4194304, 0, "I'd like to stable my pet here." },
        { "Auction", 13, 2097152, 6, "I'd like to browse the auctions." }, { "Tabard", 11, 524288, 8, "I want to create a guild crest." },
        { "Battle", 12, 1048576, 9, "I would like to go to the battleground." }, { "Repair", 15, 4096, 1, "I need repairs." },
    }
    local preset = PRESETS[1]
    local pc = {}
    for i, pr in ipairs(PRESETS) do
        local b = Button(go, pr[1], 60, 22, "chip", function()
            preset = pr
            for _, x in ipairs(pc) do x:SetActive(x.pr == pr) end
            if gOptText:GetText() == "" then gOptText:SetText(pr[5]) end
        end)
        b.pr = pr
        b:SetPoint("TOPLEFT", 14 + (i - 1) * 62, -310)
        pc[i] = b
    end
    pc[1]:SetActive(true)
    local gAdd = Button(go, "Add option", 100, 24, "accent", function()
        if not go.menu then return end
        local maxId = -1
        for _, r in ipairs(gList.data or {}) do maxId = math.max(maxId, tonumber(r.OptionID) or 0) end
        local txt = gOptText:GetText() ~= "" and gOptText:GetText() or preset[5]
        Send("LADD", "gossip_menu_option", "MenuID=" .. go.menu, "OptionID=" .. (maxId + 1), "OptionIcon=" .. preset[4], "OptionText=" .. txt:sub(1, 120),
            "OptionType=" .. preset[2], "OptionNpcFlag=" .. preset[3], "ActionMenuID=" .. (tonumber(gAct:GetText()) or 0))
        Send("RLOAD"); gOptText:SetText(""); gAct:SetText(""); S.LoadGossip()
    end)
    gAdd:SetPoint("TOPLEFT", 14, -340)
    local gDel = Button(go, "Remove selected", 120, 24, "danger", function()
        if not go.sel then return Toast("Click an option first", "err") end
        Send("LDEL", "gossip_menu_option", "MenuID=" .. go.menu, "OptionID=" .. go.sel.OptionID)
        Send("RLOAD"); S.LoadGossip()
    end)
    gDel:SetPoint("LEFT", gAdd, "RIGHT", 6, 0)
    local gOpen = Button(go, "Open submenu", 110, 24, nil, function()
        local m = go.sel and tonumber(go.sel.ActionMenuID)
        if not m or m == 0 then return Toast("This option doesn't open a submenu", "err") end
        go.menu = m; S.LoadGossip()
    end)
    gOpen:SetPoint("LEFT", gDel, "RIGHT", 6, 0)
    local gNote = Text(go, 10, C.dim); gNote:SetPoint("LEFT", gOpen, "RIGHT", 10, 0); gNote:SetWidth(230)
    gNote:SetText("Service options need the matching service ticked in Role & faction.")
    local goWidgets = { gL1, gL2, gL3, gText, gTextF, gSaveT, gTip, gList, gOptText, gAct, gSub, gAdd, gDel, gOpen, gNote }
    for _, b in ipairs(pc) do goWidgets[#goWidgets + 1] = b end
    function S.LoadGossip()
        local has = go.menu and go.menu > 0
        for _, w in ipairs(goWidgets) do Shown(w, has) end
        Shown(gNew, not has)
        Shown(gBack, has and go.menu ~= go.root)
        if not has then gInfo:SetText("This NPC type has no talk menu."); return end
        gInfo:SetText("Menu " .. go.menu .. (go.menu == go.root and " (first page, shared by every spawn of this NPC type)" or " (submenu)"))
        GetList("gossip_menu", go.menu, function(rows)
            go.text = rows[1] and tonumber(rows[1].TextID)
            if not go.text then
                NewId("npc_text", function(tid)
                    SendText("npc_text", tid, "text0_0", "...")
                    SendText("npc_text", tid, "Probability0", "1")
                    Send("LADD", "gossip_menu", "MenuID=" .. go.menu, "TextID=" .. tid)
                    Send("RLOAD")
                    go.text = tid
                    gText:SetText("..."); gTextF:SetText("")
                end)
            else
                GetRecord("npc_text", go.text, function(r) gText:SetText((r.text0_0 or ""):gsub("%$B", "\n")); gTextF:SetText((r.text0_1 or ""):gsub("%$B", "\n")) end)
            end
            GetList("gossip_menu_option", go.menu, function(opts) gList.data = opts; gList.offset = 0; go.sel = nil; gList:Refresh() end)
        end)
    end

    -- ---- other services
    local ot = panes.other
    local info = Text(ot, 11, C.text); info:SetPoint("TOPLEFT", 14, -4); info:SetWidth(670)
    info:SetText(table.concat({
        "|cffffc840Innkeeper|r  tick Innkeeper; players can set their hearthstone here. Add an Inn option in Gossip if the NPC has a talk menu.",
        "|cffffc840Banker / Auctioneer / Guild banker|r  tick the service. Works anywhere.",
        "|cffffc840Flight master|r  tick Flight master. Flight paths come from the taxi nodes of the zone (TaxiNodes.dbc), not from the NPC.",
        "|cffffc840Stable master|r  tick Stable master; hunters can stable pets.",
        "|cffffc840Spirit healer|r  tick Spirit healer and put it near a graveyard.",
        "|cffffc840Tabard designer / Guild charter|r  tick the service.",
        "|cffffc840Battlemaster|r  tick Battlemaster; the battleground list comes from battlemaster_entry.",
        "|cffffc840Repair|r  tick Repair together with Vendor.",
        "",
        "Every service can also get a custom line in its talk menu: open Gossip & text and use the presets.",
    }, "\n\n"))

    function S.OnServices()
        if not S.selected then return end
        secChips:Set(section)
        for k, p in pairs(panes) do Shown(p, k == section) end
        if section == "vendor" then LoadVendor()
        elseif section == "trainer" then LoadTrainer()
        elseif section == "gossip" then
            local m = S.adv and tonumber(S.adv.gossip)
            if m then go.root = m; go.menu = go.menu and go.menu ~= 0 and go.rootFor == G() and go.menu or m; go.rootFor = G(); S.LoadGossip() end
        end
    end
    -- the gossip menu id arrives with the Advanced values
    local te = H.TE
    H.TE = function(a) if te then te(a) end; if f:IsShown() and section == "gossip" then S.OnServices() end end
end

-- ================================================================== QUESTS
do
    local p = pages.quests
    local Q = { id = nil, fields = {}, orig = {} }
    local h = Header(p, "Quests"); h:SetPoint("TOPLEFT", 16, -14)
    local search = Edit(p, 220, 26); search:SetPoint("TOPLEFT", 16, -36); search:SetPlaceholder("Search title or id (empty: yours)")
    local list = MakeList(p, 15, 24, { { w = 40, color = C.dim, size = 10 }, { w = 150 } }, function(d) Q.Load(d.id) end)
    list:SetPoint("TOPLEFT", 16, -68); list:SetSize(220, 362)
    list.format = function(d) return { d.lvl, d.title } end
    list.isSelected = function(d) return d.id == Q.id end
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); list.data = {}; Send("QSEARCH", self:GetText()) end)
    H.QB = function() list.data = {} end
    H.QR = function(a) table.insert(list.data, { id = tonumber(a[2]), lvl = a[3], title = a[4] or "" }) end
    H.QE = function(a) list.offset = 0; list:Refresh(); Toast(a[2] .. " quests", "ok") end
    local newTitle = Edit(p, 220, 24); newTitle:SetPoint("TOPLEFT", 16, -438); newTitle:SetPlaceholder("New quest title")
    local giveChk = Check(p, "Given and finished by selected NPC"); giveChk:SetPoint("TOPLEFT", 18, -468); giveChk:Set(true)
    local bNew = Button(p, "Create quest", 105, 26, "accent", function()
        Send("QNEW", newTitle:GetText() ~= "" and newTitle:GetText() or "New quest", giveChk.value and G() or 0)
        newTitle:SetText("")
    end)
    bNew:SetPoint("TOPLEFT", 16, -492)
    local bMine = Button(p, "Selected NPC's", 110, 26, nil, function()
        if not Entry() then return Toast("Select an NPC first", "err") end
        list.data = {}
        GetList("creature_queststarter", Entry(), function(rows)
            for _, r in ipairs(rows) do table.insert(list.data, { id = tonumber(r.quest), lvl = "give", title = r._name }) end
            GetList("creature_questender", Entry(), function(rows2)
                for _, r in ipairs(rows2) do table.insert(list.data, { id = tonumber(r.quest), lvl = "end", title = r._name }) end
                list.offset = 0; list:Refresh()
            end)
        end)
    end)
    bMine:SetPoint("LEFT", bNew, "RIGHT", 5, 0)
    H.QN = function(a) Q.Load(tonumber(a[2])); Send("QSEARCH", "") end

    -- editor
    local ed = CreateFrame("Frame", nil, p)
    ed:SetPoint("TOPLEFT", 250, -10); ed:SetPoint("BOTTOMRIGHT", -12, 10)
    local title = Text(ed, 14, C.text); title:SetPoint("TOPLEFT", 4, -4); title:SetWidth(330)
    local bSave = Button(ed, "Save quest", 100, 26, "accent", function() Q.Save() end)
    bSave:SetPoint("TOPRIGHT", -4, 0)
    local bDel = Button(ed, "Delete", 64, 26, "danger", function() if Q.id then StaticPopup_Show("COA_DEVMENU_QDEL", Q.id) end end)
    bDel:SetPoint("RIGHT", bSave, "LEFT", -6, 0)
    StaticPopupDialogs["COA_DEVMENU_QDEL"] = { text = "Delete quest %s?", button1 = YES, button2 = NO, timeout = 0, hideOnEscape = 1,
        OnAccept = function() Send("QDEL", Q.id); Q.id = nil; Q.Show(); Send("QSEARCH", "") end }
    local tabs, tabBtns = {}, {}
    local TABS = { { "text", "Text" }, { "obj", "Objectives" }, { "rew", "Rewards" }, { "rules", "Rules & chain" }, { "give", "Givers & escort" }, { "ai", "AI helper" } }
    local function ShowTab(k) for key, t in pairs(tabs) do Shown(t, key == k) end; for key, b in pairs(tabBtns) do b:SetActive(key == k) end; Q.tab = k end
    for i, t in ipairs(TABS) do
        local b = Button(ed, t[2], 74, 24, nil, function() ShowTab(t[1]) end)
        b:SetPoint("TOPLEFT", (i - 1) * 77, -34)
        tabBtns[t[1]] = b
        local c = Card(ed)
        c:SetPoint("TOPLEFT", 0, -62); c:SetPoint("BOTTOMRIGHT")
        c:Hide()
        tabs[t[1]] = c
    end
    local empty = Text(ed, 13, C.dim); empty:SetPoint("CENTER"); empty:SetJustifyH("CENTER")
    empty:SetText("Pick a quest on the left or create one.\n\nTip: select the quest giver NPC first,\nthen press Create quest.")

    -- field registry: { tbl, col, widget }
    local function F(tab, tbl, col, label, x, y, w, multiH, numeric)
        local c = tabs[tab]
        Label(c, label, x, y)
        local wd
        if multiH then wd = MultiEdit(c, w, multiH) else wd = Edit(c, w, 22, numeric) end
        wd:SetPoint("TOPLEFT", x, y - 13)
        table.insert(Q.fields, { tbl = tbl, col = col, w = wd, multi = multiH ~= nil, num = numeric })
        return wd
    end
    local QT, QA, QO, QR = "quest_template", "quest_template_addon", "quest_offer_reward", "quest_request_items"

    -- text
    F("text", QT, "LogTitle", "Title", 10, -8, 300)
    F("text", QT, "QuestDescription", "Quest text (what the NPC tells the player)", 10, -46, 440, 92)
    F("text", QT, "LogDescription", "Objectives summary (quest log)", 10, -156, 440, 40)
    F("text", QR, "CompletionText", "Progress text (player comes back unfinished)", 10, -214, 440, 40)
    F("text", QO, "RewardText", "Completion text (player turns it in)", 10, -272, 440, 52)
    F("text", QT, "QuestCompletionLog", "Log text when complete (optional)", 10, -342, 440)
    local tt = Text(tabs.text, 10, C.dim); tt:SetPoint("BOTTOMLEFT", 10, 8); tt:SetText("$N name   $C class   $R race   $G male:female;   Enter = new line")

    -- objectives
    for i = 1, 4 do
        local y = -8 - (i - 1) * 40
        F("obj", QT, "RequiredNpcOrGo" .. i, "Kill / use #" .. i .. " (NPC id, object = -id)", 10, y, 110, nil, true)
        F("obj", QT, "RequiredNpcOrGoCount" .. i, "Count", 170, y, 50, nil, true)
        F("obj", QT, "ObjectiveText" .. i, "Custom objective text (optional)", 230, y, 220)
    end
    for i = 1, 6 do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local x, y = 10 + col * 150, -176 - row * 40
        F("obj", QT, "RequiredItemId" .. i, "Collect item #" .. i, x, y, 80, nil, true)
        F("obj", QT, "RequiredItemCount" .. i, "Count", x + 86, y, 44, nil, true)
    end
    F("obj", QT, "TimeAllowed", "Time limit (seconds, 0 = none)", 10, -264, 110, nil, true)
    F("obj", QT, "RequiredPlayerKills", "Player kills", 170, -264, 60, nil, true)
    F("obj", QT, "StartItem", "Item given at start", 260, -264, 80, nil, true)
    local ot = Text(tabs.obj, 10, C.dim); ot:SetPoint("TOPLEFT", 10, -312); ot:SetWidth(440)
    ot:SetText("Find ids in Browse NPCs / Objects & assets (right-click > Copy entry id). Escort or 'go talk to' quests: use Givers & escort.")

    -- rewards
    F("rew", QT, "RewardXPDifficulty", "XP (0 none ... 8 most)", 10, -8, 60, nil, true)
    F("rew", QT, "RewardMoney", "Money (copper)", 130, -8, 80, nil, true)
    F("rew", QT, "RewardSpell", "Spell cast on player", 230, -8, 80, nil, true)
    F("rew", QT, "RewardTitle", "Title id", 330, -8, 50, nil, true)
    F("rew", QT, "RewardHonor", "Honor", 395, -8, 50, nil, true)
    for i = 1, 4 do
        local x = 10 + (i - 1) * 112
        F("rew", QT, "RewardItem" .. i, "Always gets item " .. i, x, -50, 64, nil, true)
        F("rew", QT, "RewardAmount" .. i, "x", x + 68, -50, 34, nil, true)
    end
    for i = 1, 6 do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local x, y = 10 + col * 150, -96 - row * 40
        F("rew", QT, "RewardChoiceItemID" .. i, "Choice item " .. i, x, y, 80, nil, true)
        F("rew", QT, "RewardChoiceItemQuantity" .. i, "x", x + 86, y, 40, nil, true)
    end
    for i = 1, 5 do
        local x = 10 + (i - 1) * 90
        F("rew", QT, "RewardFactionID" .. i, "Rep faction " .. i, x, -186, 50, nil, true)
        F("rew", QT, "RewardFactionOverride" .. i, "x100", x + 52, -186, 34, nil, true)
    end
    local rt = Text(tabs.rew, 10, C.dim); rt:SetPoint("TOPLEFT", 10, -232); rt:SetWidth(440)
    rt:SetText("Reputation: x100 field is the amount times 100 (250 rep = 25000). Shift-click an item link in chat into an item box to paste its id.")

    -- rules & chain
    local RULES = {
        { QT, "QuestLevel", "Quest level (-1 = player level)" }, { QT, "MinLevel", "Min level" }, { QA, "MaxLevel", "Max level (0 none)" },
        { QT, "QuestInfoID", "Type: 0 normal 1 group 41 PvP 62 raid 81 dungeon" }, { QT, "SuggestedGroupNum", "Suggested players" },
        { QT, "QuestSortID", "Zone id (quest log group)" }, { QT, "AllowableRaces", "Races mask (0 all)" }, { QA, "AllowableClasses", "Classes mask (0 all)" },
        { QT, "Flags", "Flags (8 sharable, 4096 daily, 32768 weekly)" }, { QA, "SpecialFlags", "Special (1 repeatable, 2 event/escort)" },
        { QA, "PrevQuestID", "Needs quest done first" }, { QA, "NextQuestID", "Next quest in chain" }, { QT, "RewardNextQuest", "Auto-offer next quest" },
        { QA, "ExclusiveGroup", "Exclusive group" }, { QA, "BreadcrumbForQuestId", "Breadcrumb for quest" }, { QA, "RequiredSkillID", "Needs skill id" },
        { QA, "RequiredSkillPoints", "Skill points" }, { QA, "RequiredMinRepFaction", "Needs rep faction" }, { QA, "RequiredMinRepValue", "Min rep value" },
    }
    for i, r in ipairs(RULES) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        F("rules", r[1], r[2], r[3], 10 + col * 230, -8 - row * 37, 90, nil, true)
    end

    -- givers & escort
    do
        local c = tabs.give
        local gi = Text(c, 11, C.text); gi:SetPoint("TOPLEFT", 10, -10); gi:SetWidth(440)
        gi:SetText("Select an NPC (target it, then Use my target), then:")
        local function rel(tbl, add)
            if not Q.id or not Entry() then return Toast("Pick a quest and select an NPC", "err") end
            Send(add and "LADD" or "LDEL", tbl, "id=" .. Entry(), "quest=" .. Q.id); Send("RLOAD")
            if add and G() then Send("ROLE", G(), bit.bor(tonumber(S.selected.npcflag) or 0, 3)) end
        end
        local b1 = Button(c, "It gives this quest", 140, 26, "accent", function() rel("creature_queststarter", true) end); b1:SetPoint("TOPLEFT", 10, -32)
        local b2 = Button(c, "It finishes this quest", 150, 26, "accent", function() rel("creature_questender", true) end); b2:SetPoint("LEFT", b1, "RIGHT", 6, 0)
        local b3 = Button(c, "Remove from it", 120, 26, "danger", function() rel("creature_queststarter", false); rel("creature_questender", false) end); b3:SetPoint("LEFT", b2, "RIGHT", 6, 0)
        local hint = Text(c, 10, C.dim); hint:SetPoint("TOPLEFT", 10, -66); hint:SetWidth(440)
        hint:SetText("'Go talk to X' quest: let NPC A give it and NPC B finish it, no objectives needed.")
        local h2 = Header(c, "Escort / follow quest"); h2:SetPoint("TOPLEFT", 10, -100)
        local st = Text(c, 11, C.text); st:SetPoint("TOPLEFT", 10, -124); st:SetWidth(440)
        st:SetText("1. Select the NPC who will walk (it must also give the quest).\n2. Open Path editor and walk the route, pressing Add point here (or /dev point) along the way.\n3. Come back here and press Save escort. When a player accepts the quest the NPC walks the route; the quest completes when it arrives. If it dies, the quest fails.")
        local run = Check(c, "Run instead of walk"); run:SetPoint("TOPLEFT", 12, -206)
        local be = Button(c, "Save escort for selected NPC", 210, 26, "accent", function()
            if not Q.id or not G() then return Toast("Pick a quest and select the NPC", "err") end
            Send("QESCORT", Q.id, G(), run.value and 1 or 0)
        end)
        be:SetPoint("TOPLEFT", 10, -232)
        local bp = Button(c, "Open Path editor", 140, 26, nil, function() D.ShowPage("path") end); bp:SetPoint("LEFT", be, "RIGHT", 6, 0)
    end

    -- AI helper: copy a ready prompt to any AI chat, paste its answer back
    local AIK = {
        { "Title", QT, "LogTitle" }, { "QuestText", QT, "QuestDescription" }, { "Objectives", QT, "LogDescription" },
        { "ProgressText", QR, "CompletionText" }, { "CompletionText", QO, "RewardText" }, { "QuestLevel", QT, "QuestLevel" }, { "MinLevel", QT, "MinLevel" },
        { "Kill1", QT, "RequiredNpcOrGo1" }, { "KillCount1", QT, "RequiredNpcOrGoCount1" }, { "Kill2", QT, "RequiredNpcOrGo2" }, { "KillCount2", QT, "RequiredNpcOrGoCount2" },
        { "Kill3", QT, "RequiredNpcOrGo3" }, { "KillCount3", QT, "RequiredNpcOrGoCount3" }, { "Kill4", QT, "RequiredNpcOrGo4" }, { "KillCount4", QT, "RequiredNpcOrGoCount4" },
        { "ObjectiveText1", QT, "ObjectiveText1" }, { "Item1", QT, "RequiredItemId1" }, { "ItemCount1", QT, "RequiredItemCount1" }, { "Item2", QT, "RequiredItemId2" }, { "ItemCount2", QT, "RequiredItemCount2" },
        { "RewardXP", QT, "RewardXPDifficulty" }, { "RewardMoney", QT, "RewardMoney" },
        { "RewardItem1", QT, "RewardItem1" }, { "RewardItemCount1", QT, "RewardAmount1" }, { "ChoiceItem1", QT, "RewardChoiceItemID1" }, { "ChoiceItem2", QT, "RewardChoiceItemID2" }, { "ChoiceItem3", QT, "RewardChoiceItemID3" },
    }
    local function FieldOf(tbl, col) for _, f in ipairs(Q.fields) do if f.tbl == tbl and f.col == col then return f end end end
    do
        local c = tabs.ai
        Label(c, "1. Describe your idea (who, where, what happens)", 10, -8)
        local idea = MultiEdit(c, 440, 48); idea:SetPoint("TOPLEFT", 10, -21)
        local bBuild = Button(c, "Build prompt", 110, 22, "accent", nil); bBuild:SetPoint("TOPLEFT", 10, -74)
        local lbl = Text(c, 10, C.dim); lbl:SetPoint("LEFT", bBuild, "RIGHT", 8, 0); lbl:SetText("then click the box below, Ctrl+A, Ctrl+C, paste into any AI chat")
        local prompt = MultiEdit(c, 440, 100); prompt:SetPoint("TOPLEFT", 10, -102)
        prompt.edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        Label(c, "2. Paste the AI answer here, then Apply (fills the tabs, press Save quest after checking)", 10, -208)
        local answer = MultiEdit(c, 440, 100); answer:SetPoint("TOPLEFT", 10, -221)
        local bApply = Button(c, "Apply AI answer", 130, 24, "accent", nil); bApply:SetPoint("TOPLEFT", 10, -326)
        local bClear = Button(c, "Clear", 60, 24, nil, function() answer:SetText("") end); bClear:SetPoint("LEFT", bApply, "RIGHT", 6, 0)
        bBuild:SetScript("OnClick", function()
            local giver = S.selected and (S.selected.name .. " (NPC id " .. S.selected.entry .. ", level " .. S.selected.minl .. ")") or "unknown"
            local zone = GetZoneText() .. (GetSubZoneText() ~= "" and (" / " .. GetSubZoneText()) or "")
            local L = {
                "You write quests for a World of Warcraft 3.3.5 private server. Reply ONLY with lines in the form KEY: value, no other text.",
                "Keys you can use: " .. (function() local k = {} for _, a in ipairs(AIK) do k[#k + 1] = a[1] end return table.concat(k, ", ") end)() .. ".",
                "Rules: QuestText 60-150 words in the voice of the quest giver. Use $N for the player's name, $C for class, $R for race, $B for a line break.",
                "Kill/Item values are numeric ids: only use ids I give you, otherwise leave them out. RewardXP is 0-8 (5 is normal). RewardMoney is in copper.",
                "Quest giver: " .. giver .. ". Zone: " .. zone .. ". Player level around " .. UnitLevel("player") .. ".",
                "Idea: " .. idea:GetText():gsub("\n", " "),
                "Current quest (improve it, keep ids):",
            }
            for _, a in ipairs(AIK) do
                local f = FieldOf(a[2], a[3])
                local v = f and f.w:GetText() or ""
                if v ~= "" and v ~= "0" then L[#L + 1] = a[1] .. ": " .. v:gsub("\n", "$B") end
            end
            prompt:SetText(table.concat(L, "\n"))
            prompt.edit:SetFocus()
            prompt.edit:HighlightText()
        end)
        bApply:SetScript("OnClick", function()
            local map = {}
            for _, a in ipairs(AIK) do map[a[1]:lower()] = a end
            local last, n = nil, 0
            for line in (answer:GetText() .. "\n"):gmatch("([^\n]*)\n") do
                local k, v = line:match("^%s*%**([%w ]+)%**%s*:%s*(.*)$")
                local a = k and map[(k:gsub(" ", "")):lower()]
                if a then
                    local f = FieldOf(a[2], a[3])
                    if f then f.w:SetText((v:gsub("%$B", "\n"))); last = f; n = n + 1 end
                elseif last and last.multi and line:match("%S") then
                    last.w:SetText(last.w:GetText() .. "\n" .. line)
                end
            end
            Toast(n .. " fields filled from the AI answer: check them and press Save quest", n > 0 and "ok" or "err")
        end)
    end

    function Q.Show()
        local has = Q.id ~= nil
        Shown(empty, not has)
        for _, b in pairs(tabBtns) do Shown(b, has) end
        Shown(bSave, has); Shown(bDel, has)
        for k, t in pairs(tabs) do Shown(t, has and k == (Q.tab or "text")) end
        for k, b in pairs(tabBtns) do b:SetActive(k == (Q.tab or "text")) end
        list:Refresh()
    end
    function Q.Load(id)
        Q.id = id
        Q.orig = {}
        title:SetText("Quest " .. id)
        for _, tb in ipairs({ QT, QA, QO, QR }) do
            GetRecord(tb, id, function(r)
                for _, f in ipairs(Q.fields) do
                    if f.tbl == tb then
                        local v = (r[f.col] or ""):gsub("%$B", "\n")
                        f.w:SetText(v)
                        Q.orig[tb .. "." .. f.col] = v
                    end
                end
                if tb == QT then title:SetText(("Quest %d   |cff8a8f9c%s|r"):format(id, r.LogTitle or "")) end
            end)
        end
        Q.Show()
    end
    function Q.Save()
        if not Q.id then return end
        local n = 0
        for _, f in ipairs(Q.fields) do
            local v = f.w:GetText()
            if v ~= Q.orig[f.tbl .. "." .. f.col] then
                if f.num and v == "" then v = "0" end
                SendText(f.tbl, Q.id, f.col, v)
                Q.orig[f.tbl .. "." .. f.col] = f.w:GetText()
                n = n + 1
            end
        end
        if n == 0 then return Toast("Nothing changed", "ok") end
        Send("RLOAD")
        Toast(n .. " fields saved", "ok")
    end
    ShowTab("text")
    function p:OnShowPage()
        Q.Show()
        if #(list.data or {}) == 0 then list.data = {}; Send("QSEARCH", "") end
    end
end

-- ================================================================== OBJECTS & ASSETS
do
    local p = pages.objects
    local O = { mode = 0, page = 0, sel = nil, step = 1, turn = 15 }
    local h = Header(p, "Objects & assets"); h:SetPoint("TOPLEFT", 16, -14)
    local mode = Chips(p, { { 0, "Object types" }, { 1, "Every model" }, { 2, "Nearby" } }, 16, -36, 96, function(v) O.mode = v; O.page = 0; O.Search() end)
    mode:Set(0)
    local search = Edit(p, 300, 26); search:SetPoint("TOPLEFT", 16, -64); search:SetPlaceholder("Search: house, crate, barrel, tent, torch...")
    local list = MakeList(p, 15, 24, { { w = 200 }, { w = 70, color = C.dim, size = 10, right = true } }, function(d, btn, ctrl)
        if ctrl then return O.Preview(d) end
        if btn == "RightButton" then return O.Spawn(d) end
        O.pick = d; O.list:Refresh()
        if d.guid then Send("GSEL", d.guid) end
    end)
    O.list = list
    list:SetPoint("TOPLEFT", 16, -96); list:SetSize(300, 362)
    list.format = function(d)
        if d.guid then return { d.name, ("%.1f yd"):format(tonumber(d.dist) or 0) } end
        return { d.name, d.entry ~= 0 and d.entry or ("model " .. d.display) }
    end
    list.isSelected = function(d) return d == O.pick end
    list.onDouble = function(d) O.Preview(d) end
    local pager = Text(p, 10, C.dim); pager:SetPoint("TOPLEFT", 16, -464)
    local bSpawn = Button(p, "Spawn selected here", 150, 26, "accent", function() if O.pick then O.Spawn(O.pick) end end); bSpawn:SetPoint("TOPLEFT", 16, -488)
    local bPrev = Button(p, "3D preview", 90, 26, nil, function() if O.pick then O.Preview(O.pick) end end); bPrev:SetPoint("LEFT", bSpawn, "RIGHT", 6, 0)
    local lh = Text(p, 10, C.dim); lh:SetPoint("TOPLEFT", 16, -520); lh:SetWidth(300)
    lh:SetText("Ctrl+click / double-click: 3D preview   Right-click: spawn at your feet. 'Every model' lists every object model of the game.")
    function O.Search()
        if O.mode == 2 then Send("GNEAR", 60) else list:Search(function(pg) Send("GSEARCH", search:GetText(), pg, O.mode) end) end
    end
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); O.page = 0; if O.mode == 2 then mode:Set(0); O.mode = 0 end; O.Search() end)
    function O.Preview(d)
        if d.guid then return Send("GSEL", d.guid) end
        D.PreviewModel(d.path, d.name, (d.entry ~= 0 and ("Object " .. d.entry .. "   ") or "") .. "Model " .. d.display, { entry = d.entry ~= 0 and d.entry or nil, display = d.display })
    end
    function O.Spawn(d)
        if d.guid then return Send("GDUP", d.guid) end
        Send("GSPAWN", d.entry, d.entry == 0 and d.display or 0)
    end
    H.GB = function(a) list:Begin(a[4]) end
    H.GR = function(a) table.insert(list.data, { entry = tonumber(a[2]), name = a[3] or "", type = a[4], display = tonumber(a[5]), path = a[6] or "" }) end
    H.GE = function(a)
        list:Done()
        pager:SetText(a[2] .. " results (scroll for more)")
    end
    H.GNB = function() list.data = {} end
    H.GN = function(a) table.insert(list.data, { guid = a[2], entry = tonumber(a[3]), name = a[4] or "", dist = a[5] }) end
    H.GNE = function() list.offset = 0; list:Refresh(); pager:SetText(#list.data .. " saved objects within 60 yd") end

    -- selected object
    local c = Card(p)
    c:SetPoint("TOPLEFT", 330, -12); c:SetPoint("BOTTOMRIGHT", -12, 12)
    local nm = Text(c, 13, C.text); nm:SetPoint("TOPLEFT", 10, -10); nm:SetWidth(360)
    local l1 = Text(c, 10, C.dim); l1:SetPoint("TOPLEFT", 10, -30); l1:SetWidth(360)
    local l2 = Text(c, 10, C.dim); l2:SetPoint("TOPLEFT", 10, -44); l2:SetWidth(360)
    local function GG() return O.sel and O.sel.guid end
    local function Op(op, ...) if GG() then Send(op, GG(), ...) else Toast("Select an object first (Select nearest, or Nearby)", "err") end end
    local row = {
        { "Select nearest", 108, "accent", function() Send("GTGT") end },
        { "Move to me", 86, nil, function() Op("GMOVE") end },
        { "Face me", 66, nil, function() Op("GFACE") end },
        { "Go to", 54, nil, function() Op("GGOTO") end },
    }
    local x = 10
    for _, r in ipairs(row) do local b = Button(c, r[1], r[2], 24, r[3], r[4]); b:SetPoint("TOPLEFT", x, -62); x = x + r[2] + 4 end
    local bDup = Button(c, "Duplicate here", 100, 24, nil, function() Op("GDUP") end); bDup:SetPoint("TOPLEFT", 10, -90)
    local b3d = Button(c, "3D", 40, 24, nil, function() if O.sel then D.PreviewModel(O.sel.path, O.sel.name, "Object " .. O.sel.entry, { entry = O.sel.entry }) end end); b3d:SetPoint("LEFT", bDup, "RIGHT", 4, 0)
    local bDel = Button(c, "Delete", 70, 24, "danger", function() if GG() then StaticPopup_Show("COA_DEVMENU_GDEL", O.sel.name) end end); bDel:SetPoint("LEFT", b3d, "RIGHT", 4, 0)
    StaticPopupDialogs["COA_DEVMENU_GDEL"] = { text = "Delete this object from the world?\n\n%s", button1 = YES, button2 = NO, timeout = 0, hideOnEscape = 1, OnAccept = function() Op("GDEL") end }

    local h2 = Header(c, "Fine tune"); h2:SetPoint("TOPLEFT", 10, -122)
    Label(c, "Step", 10, -142)
    local steps = Chips(c, { { 0.05, "0.05" }, { 0.1, "0.1" }, { 0.25, "0.25" }, { 0.5, "0.5" }, { 1, "1 yd" }, { 5, "5 yd" } }, 40, -138, 50, function(v) O.step = v end)
    steps:Set(1)
    Label(c, "Turn", 10, -166)
    local turns = Chips(c, { { 1, "1°" }, { 5, "5°" }, { 15, "15°" }, { 45, "45°" }, { 90, "90°" } }, 40, -162, 50, function(v) O.turn = v end)
    turns:Set(15)
    local pad = Compass(c, function(f, r, u, t) Op("GNUDGE", f * O.step, r * O.step, u * O.step, t * O.turn) end,
        { label = "TO ME", tip = "Move the object to where you stand", click = function() Op("GMOVE") end })
    pad:SetPoint("TOPLEFT", 6, -196)
    local pn = Text(c, 9, C.dim); pn:SetPoint("TOPLEFT", 8, -352); pn:SetWidth(180); pn:SetText("Arrows move relative to where you face")
    -- gizmo: world axes + rotation ring (ring mode picks which rotation the ring drives)
    local rot = {}
    local ringMode = "yaw"
    local RINGC = { yaw = { 0.3, 0.45, 1 }, pitch = { 0.9, 0.25, 0.25 }, roll = { 0.3, 0.85, 0.35 } }
    local giz = Gizmo(c, 170, {
        move = function(dx, dy, dz) Op("GNUDGEW", dx * O.step, dy * O.step, dz * O.step) end,
        rotate = function(d)
            local e = rot[ringMode]
            e:SetText(math.floor((tonumber(e:GetText()) or 0) + d)); O.ApplyRot()
        end,
    })
    giz:SetPoint("TOPLEFT", 196, -188)
    local rm = Chips(c, { { "yaw", "Facing" }, { "pitch", "Tilt fwd" }, { "roll", "Tilt side" } }, 196, -372, 54, function(v)
        ringMode = v; giz:SetRingColor(unpack(RINGC[v]))
    end)
    rm:Set("yaw"); giz:SetRingColor(unpack(RINGC.yaw))
    local h3 = Header(c, "Rotation (degrees)"); h3:SetPoint("TOPLEFT", 10, -404)
    for i, ax in ipairs({ { "yaw", "Facing" }, { "pitch", "Tilt fwd" }, { "roll", "Tilt side" } }) do
        local x0 = 10 + (i - 1) * 120
        Label(c, ax[2], x0, -422)
        local e = Edit(c, 56, 22, true, function() O.ApplyRot() end); e:SetPoint("TOPLEFT", x0 + 18, -436)
        local mi = Button(c, "-", 18, 22, nil, function() e:SetText(math.floor((tonumber(e:GetText()) or 0) - O.turn)); O.ApplyRot() end); mi:SetPoint("RIGHT", e, "LEFT", -1, 0)
        local pl = Button(c, "+", 18, 22, nil, function() e:SetText(math.floor((tonumber(e:GetText()) or 0) + O.turn)); O.ApplyRot() end); pl:SetPoint("LEFT", e, "RIGHT", 1, 0)
        rot[ax[1]] = e
    end
    function O.ApplyRot() Op("GROT", tonumber(rot.yaw:GetText()) or 0, tonumber(rot.pitch:GetText()) or 0, tonumber(rot.roll:GetText()) or 0) end
    local rn = Text(c, 9, C.dim); rn:SetPoint("TOPLEFT", 10, -464); rn:SetWidth(360)
    rn:SetText("Gizmo: drag X / Y / Z to slide on that world axis, drag the ring to rotate. Object size belongs to its type and changes after a restart.")

    -- click an object in the world to select it
    local pickBtn
    local pick = CreateFrame("Frame")
    pick:Hide()
    local hovered = ""
    -- WorldFrame gets no mouse scripts in 3.3.5, so watch the button state while the mouse is over the world
    local wasDown, downName = false, ""
    pick:SetScript("OnUpdate", function()
        local overWorld = GetMouseFocus() == WorldFrame
        if overWorld and GameTooltip:IsShown() and not UnitExists("mouseover") then
            local l = _G["GameTooltipTextLeft1"]
            hovered = l and l:GetText() or ""
        elseif overWorld and not GameTooltip:IsShown() then
            hovered = ""
        end
        local down = IsMouseButtonDown("LeftButton")
        if down and not wasDown then downName = overWorld and hovered or nil end
        if not down and wasDown and downName and overWorld then Send("GPICK", downName) end
        wasDown = down
    end)
    local function SetPick(on)
        Shown(pick, on)
        pickBtn:SetActive(on)
        Toast(on and "Pick mode: left-click an object in the world (Esc or the button again to stop)" or "Pick mode off", "ok")
    end
    pickBtn = Button(c, "Click in world", 104, 24, nil, function() SetPick(not pick:IsShown()) end)
    pickBtn:SetPoint("LEFT", bDel, "RIGHT", 4, 0)
    Tip(pickBtn, "Click an object in the world", "Turn this on, then left-click the object you want to edit. Objects without a tooltip (decorations) are matched to the nearest one in front of you.")
    p:HookScript("OnHide", function() if pick:IsShown() then SetPick(false) end end)

    H.GI = function(a)
        O.sel = { guid = a[2], entry = tonumber(a[3]), name = a[4] or "", display = a[12], type = a[13], path = a[14] or "" }
        nm:SetText(O.sel.name)
        l1:SetText(("GUID %s   Entry %s   Model %s   Type %s"):format(a[2], a[3], a[12], a[13]))
        l2:SetText(("x %.2f   y %.2f   z %.2f"):format(tonumber(a[5]) or 0, tonumber(a[6]) or 0, tonumber(a[7]) or 0))
        local function set(e, v) if not e:HasFocus() then e:SetText(math.floor((tonumber(v) or 0) + 0.5)) end end
        set(rot.yaw, a[9]); set(rot.pitch, a[10]); set(rot.roll, a[11])
        if O.mode == 2 then for _, d in ipairs(list.data) do if d.guid == a[2] then O.pick = d end end; list:Refresh() end
    end
    H.GD = function(a)
        if O.sel and O.sel.guid == a[2] then O.sel = nil; nm:SetText("Nothing selected"); l1:SetText(""); l2:SetText("") end
        if O.mode == 2 then O.Search() end
    end
    nm:SetText("Nothing selected")
    l1:SetText("Stand near an object and press Select nearest,")
    l2:SetText("or switch the list to Nearby.")
    function p:OnShowPage() if #(list.data or {}) == 0 then O.Search() end end
end


-- ================================================================== NPC placement: compass + gizmo
do
    local f = S.placePane
    local pad = Compass(f, function(fw, rt, up, tn)
        if G() then Send("NUDGE", G(), fw * S.step, rt * S.step, up * S.step, tn * S.turn) end
    end, { label = "TO ME", tip = "Move the NPC to where you stand", click = function() if G() then Send("MOVE", G()) end end })
    pad:SetPoint("TOPLEFT", 40, -170)
    local giz = Gizmo(f, 170, {
        move = function(dx, dy, dz) if G() then Send("NUDGEW", G(), dx * S.step, dy * S.step, dz * S.step) end end,
        rotate = function(d)
            if not G() then return end
            local cur = math.deg(tonumber(S.selected.o) or 0)
            Send("SETO", G(), math.floor(cur + d + 0.5))
        end,
    })
    giz:SetPoint("TOPLEFT", 280, -166)
    giz:SetRingColor(0.3, 0.45, 1)
    Label(f, "Facing (degrees)", 480, -176)
    local deg = Edit(f, 70, 24, true, function(self) if G() then Send("SETO", G(), tonumber(self:GetText()) or 0) end end)
    deg:SetPoint("TOPLEFT", 480, -190)
    local hint = Text(f, 9, C.dim); hint:SetPoint("TOPLEFT", 480, -222); hint:SetWidth(200)
    hint:SetText("Drag X / Y / Z to slide on a world axis (X north, Y west, Z up). Drag the ring to turn. Click an axis = one step, Shift+click = one step back.")
    f:HookScript("OnUpdate", function()
        if S.selected and S.selected.o and not deg:HasFocus() then deg:SetText(math.floor(math.deg(tonumber(S.selected.o) or 0) + 0.5)) end
    end)
end

-- ================================================================== PATH: path preview drawing
do
    local p = pages.path

    -- preview: the path seen from above (north up), numbered points, you as a yellow dot
    -- the map lives in its own square window (opens with the Path editor, movable, remembers where you put it)
    local win = CreateFrame("Frame", "CoADevPathMap", UIParent)
    win:SetSize(580, 800); win:SetFrameStrata("DIALOG"); win:SetToplevel(true); win:SetClampedToScreen(true)
    win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetLeft(), self:GetTop()
        IlusixnDevMenuDB.mapPos = { x, y }
    end)
    Skin(win, C.bg or C.panel, C.accentD)
    win:SetResizable(true); win:SetMinResize(580, 600)
    local grip = CreateFrame("Button", nil, win)
    grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown", function() win:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        win:StopMovingOrSizing()
        IlusixnDevMenuDB.mapPos = { win:GetLeft(), win:GetTop() }
        IlusixnDevMenuDB.mapSize = { win:GetWidth(), win:GetHeight() }
    end)
    win:Hide()
    local wt = Header(win, "Path map"); wt:SetPoint("TOPLEFT", 12, -10)
    local wx = Button(win, "X", 22, 22, nil, function() win:Hide() end); wx:SetPoint("TOPRIGHT", -8, -8)
    local function PlaceMap()
        win:ClearAllPoints()
        local sz = IlusixnDevMenuDB.mapSize
        if sz then win:SetSize(math.max(580, sz[1]), math.max(600, sz[2])) end
        local pos = IlusixnDevMenuDB.mapPos
        if pos then win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
        else win:SetPoint("TOPLEFT", CoADevMenuFrame, "TOPRIGHT", 8, 0) end
    end
    local open = Button(p, "Open path map", 160, 28, nil, function() if win:IsShown() then win:Hide() else PlaceMap(); win:Show() end end)
    open:SetPoint("TOPLEFT", 16, -420)
    local card = Card(win)
    card:SetPoint("TOPLEFT", 8, -36); card:SetPoint("BOTTOMRIGHT", -8, 204)
    local ttl = Text(card, 10, C.dim); ttl:SetPoint("TOPLEFT", 8, -8); ttl:SetText("Path preview")
    local canvas = CreateFrame("Frame", nil, card)
    canvas:SetPoint("TOPLEFT", 12, -32); canvas:SetPoint("BOTTOMRIGHT", -12, 10)
    -- view: wheel zooms at the cursor, drag pans, click picks a point
    local zoom, panX, panY, sel = 1, 0, 0, nil
    local view = {}   -- set by Draw: sc, cx, cy, CW, CH
    local bg = canvas:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetTexture(WHITE); bg:SetVertexColor(0.035, 0.045, 0.06, 1)
    -- pooled textures / labels, one pool per layer so lines stay under points
    local pools = {}
    local function Pool(layer, size, col)
        local P = pools[layer]
        if not P then P = { n = 0 }; pools[layer] = P end
        P.n = P.n + 1
        local d = P[P.n]
        if not d then d = canvas:CreateTexture(nil, layer); d:SetTexture(WHITE); P[P.n] = d end
        d:SetVertexColor(unpack(col)); d:ClearAllPoints(); d:Show()
        return d
    end
    -- 3.3.5 frames don't clip their textures: skip what falls outside the map
    local function Inside(x, y, m) m = m or 0; return x >= -m and y >= -m and x <= canvas:GetWidth() + m and y <= canvas:GetHeight() + m end
    local function Dot(layer, x, y, size, col)
        if not Inside(x, y) then return end
        local d = Pool(layer, size, col); d:SetSize(size, size); d:SetPoint("CENTER", canvas, "BOTTOMLEFT", x, y); return d
    end
    local function Rect(x1, y1, x2, y2, col) -- grid line (axis-aligned)
        x1, x2 = math.max(0, x1), math.min(canvas:GetWidth(), x2); y1, y2 = math.max(0, y1), math.min(canvas:GetHeight(), y2)
        if x2 <= x1 or y2 <= y1 then return end
        local d = Pool("BORDER", 1, col); d:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", x1, y1); d:SetPoint("TOPRIGHT", canvas, "BOTTOMLEFT", x2, y2); return d
    end
    local labels, lused = {}, 0
    local function Label(x, y, txt, col, size, anchor)
        if not Inside(x, y, -2) then return end
        lused = lused + 1
        local t = labels[lused]
        if not t then t = Text(canvas, 10, C.text, "OUTLINE"); labels[lused] = t end
        t:SetFont(FONT, size or 10, "OUTLINE"); t:SetTextColor(unpack(col or C.text))
        t:ClearAllPoints(); t:SetPoint(anchor or "BOTTOM", canvas, "BOTTOMLEFT", x, y); t:SetText(txt); t:Show()
    end
    local pts, me = {}, nil
    local LINE, GRID, GRID2 = { 0.95, 0.72, 0.25, 0.9 }, { 1, 1, 1, 0.05 }, { 1, 1, 1, 0.1 }
    local START, END, MID = { 0.3, 0.85, 0.4, 1 }, { 0.95, 0.3, 0.3, 1 }, { 0.9, 0.92, 0.95, 1 }
    local function Draw()
        for _, P in pairs(pools) do for i = 1, P.n do P[i]:Hide() end; P.n = 0 end
        for i = 1, lused do labels[i]:Hide() end
        lused = 0
        local CW, CH = canvas:GetWidth(), canvas:GetHeight()
        if CW < 40 or CH < 40 then return end
        local all = {}
        for _, q in ipairs(pts) do all[#all + 1] = q end
        if me then all[#all + 1] = me end
        if #all == 0 then
            Label(CW / 2, CH / 2, "No path yet: add points, or press Show path", C.dim, 11, "CENTER")
            return
        end
        local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
        for _, q in ipairs(all) do
            minX = math.min(minX, q[1]); maxX = math.max(maxX, q[1]); minY = math.min(minY, q[2]); maxY = math.max(maxY, q[2])
        end
        local pad = 22
        local W, Hh = CW - pad * 2, CH - pad * 2
        local span = math.max(maxX - minX, maxY - minY, 10) * 1.08
        local sc = math.min(W, Hh) / span
        sc = sc * zoom
        local cx, cy = (minX + maxX) / 2 + panX, (minY + maxY) / 2 + panY
        view.sc, view.cx, view.cy, view.CW, view.CH = sc, cx, cy, CW, CH
        -- world +X is north (screen up), world +Y is west (screen left)
        local function S2(q) return CW / 2 - (q[2] - cy) * sc, CH / 2 + (q[1] - cx) * sc end
        -- grid: a round step giving ~6-10 cells, every 5th line brighter
        local step = 1
        for _, s in ipairs({ 1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000 }) do step = s; if span / zoom / s <= 10 then break end end
        local px = step * sc
        local ox, oy = CW / 2 - (math.floor(cy / step) * step - cy) * sc, CH / 2 + (math.floor(cx / step) * step - cx) * sc
        for k = -60, 60 do
            local x = ox + k * px
            if x >= 0 and x <= CW then Rect(x, 0, x + 1, CH, k % 5 == 0 and GRID2 or GRID) end
            local y = oy + k * px
            if y >= 0 and y <= CH then Rect(0, y, CW, y + 1, k % 5 == 0 and GRID2 or GRID) end
        end
        -- scale bar + compass
        Rect(10, 10, 10 + px, 12, MID); Rect(10, 6, 11, 16, MID); Rect(9 + px, 6, 10 + px, 16, MID)
        Label(10 + px / 2, 16, step .. " yd", C.dim, 10)
        Label(CW - 14, CH - 8, "N", C.accent, 12, "TOP"); Dot("ARTWORK", CW - 14, CH - 26, 2, C.accent); Dot("ARTWORK", CW - 14, CH - 30, 2, C.accent)
        -- route: continuous line, closing segment dimmed when it loops
        local function Seg(a, b, col)
            local x1, y1 = S2(a); local x2, y2 = S2(b)
            local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
            if len < 1 then return end
            local n = math.min(math.floor(len), 400)
            for k = 0, n do Dot("BORDER", x1 + (x2 - x1) * k / n, y1 + (y2 - y1) * k / n, 2, col) end
            -- direction chevron at the middle of longer segments
            if len > 30 then
                local mx, my, ux, uy = (x1 + x2) / 2, (y1 + y2) / 2, (x2 - x1) / len, (y2 - y1) / len
                for j = 1, 4 do
                    Dot("ARTWORK", mx - ux * j * 1.5 + uy * j * 1.5, my - uy * j * 1.5 - ux * j * 1.5, 2, col)
                    Dot("ARTWORK", mx - ux * j * 1.5 - uy * j * 1.5, my - uy * j * 1.5 + ux * j * 1.5, 2, col)
                end
            end
        end
        for i = 2, #pts do Seg(pts[i - 1], pts[i], LINE) end
        if #pts > 2 then Seg(pts[#pts], pts[1], { LINE[1], LINE[2], LINE[3], 0.25 }) end
        -- points: start / end bigger, numbers thinned out on long recordings
        local every = math.max(1, math.ceil(#pts / 25))
        for i, q in ipairs(pts) do
            local x, y = S2(q)
            if i == sel then Dot("ARTWORK", x, y, 20, { C.accent[1], C.accent[2], C.accent[3], 0.45 }) end
            local first, last = i == 1, i == #pts
            local col = first and START or last and END or MID
            local sz = (first or last) and 11 or (#pts > 60 and 4 or 7)
            Dot("ARTWORK", x, y, sz + 2, { 0, 0, 0, 0.9 }); Dot("OVERLAY", x, y, sz, col)
            if first then Label(x, y + 8, "Start", START, 10)
            elseif last then Label(x, y + 8, "End (" .. i .. ")", END, 10)
            elseif i == sel or i % math.max(1, math.floor(every / zoom)) == 0 then Label(x, y + 5, tostring(i), i == sel and C.accent or C.dim, i == sel and 11 or 9) end
        end
        if me then
            local x, y = S2(me)
            Dot("ARTWORK", x, y, 14, { C.accent[1], C.accent[2], C.accent[3], 0.25 }); Dot("OVERLAY", x, y, 7, C.accent)
            Label(x + 9, y, "You", C.accent, 10, "LEFT")
        end
        local total = 0
        for i = 2, #pts do total = total + math.sqrt((pts[i][1] - pts[i - 1][1]) ^ 2 + (pts[i][2] - pts[i - 1][2]) ^ 2) end
        ttl:SetText(("Path  |cffe6e8ec%d pts|r  %d yd  x%s"):format(#pts, math.floor(total + 0.5), zoom >= 10 and math.floor(zoom) or ("%.1f"):format(zoom)))
    end
    -- point tools: pick a point (click it on the map or type its number), then act on it.
    -- The same row sits under the map and on the Path editor page.
    local edits = {}
    local function Pick(i)
        sel = (i and pts[i]) and i or nil
        for _, e in ipairs(edits) do e:SetText(sel and tostring(sel) or "") end
        Draw()
    end
    local function Need()
        local n = sel
        if not n or not pts[n] then Toast("Pick a point: click it on the map or type its number", "err") return nil end
        return n
    end
    local function Tools(parent, anchor, x, y)
        local pl = Text(parent, 10, C.dim); pl:SetPoint(anchor, x, y - 4); pl:SetText("Point")
        local pe = Edit(parent, 40, 20, true); pe:SetPoint("LEFT", pl, "RIGHT", 6, 0)
        pe:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Pick(tonumber(self:GetText())) end)
        edits[#edits + 1] = pe
        local prev = pe
        for _, b in ipairs({ { "Go to", 56, function(n) local q = pts[n]; Send("PPT", "go", n, q[1], q[2], q[3] or 0) end, "Teleports you to that point." },
            { "Move here", 80, function(n) Send("PPT", "set", n) end, "Moves that point to where you stand. Edit path first, then Save path." },
            { "Insert after", 86, function(n) Send("PPT", "ins", n) end, "Adds a point where you stand, right after it." },
            { "Delete", 60, function(n) Send("PPT", "del", n); Pick(nil) end, "Removes that point from the recording." } }) do
            local bt = Button(parent, b[1], b[2], 22, nil, function() local n = Need(); if n then b[3](n) end end)
            bt:SetPoint("LEFT", prev, "RIGHT", 10, 0); prev = bt
            Tip(bt, b[1], b[4])
        end
    end
    Tools(win, "BOTTOMLEFT", 14, 176)
    local fit = Button(card, "Fit", 40, 20, nil, function() zoom, panX, panY = 1, 0, 0; Draw() end)
    fit:SetPoint("TOPRIGHT", -8, -5)
    Tip(fit, "Zoom", "Mouse wheel on the map zooms at the cursor, drag to move it, click a point to pick it. Fit shows the whole path.")
    canvas:EnableMouse(true); canvas:EnableMouseWheel(true)
    local function World(mx, my)   -- screen spot on the canvas -> world x (north), y (west)
        local s = canvas:GetEffectiveScale()
        local x, y = mx / s - canvas:GetLeft(), my / s - canvas:GetBottom()
        return view.cx + (y - view.CH / 2) / view.sc, view.cy - (x - view.CW / 2) / view.sc, x, y
    end
    canvas:SetScript("OnMouseWheel", function(_, d)
        if not view.sc then return end
        local wx, wy = World(GetCursorPosition())
        local nz = math.max(1, math.min(60, zoom * (d > 0 and 1.4 or 1 / 1.4)))
        local k = zoom / nz
        -- keep the spot under the cursor in place
        panX = panX + (wx - view.cx) * (1 - k); panY = panY + (wy - view.cy) * (1 - k)
        if nz == 1 then panX, panY = 0, 0 end
        zoom = nz; Draw()
    end)
    local drag
    canvas:SetScript("OnMouseDown", function() local mx, my = GetCursorPosition(); drag = { mx, my, panX, panY, false } end)
    canvas:SetScript("OnMouseUp", function()
        if drag and not drag[5] and view.sc then
            local _, _, x, y = World(GetCursorPosition())
            local best, bd = nil, 14
            for i, q in ipairs(pts) do
                local px, py = view.CW / 2 - (q[2] - view.cy) * view.sc, view.CH / 2 + (q[1] - view.cx) * view.sc
                local d = math.sqrt((px - x) ^ 2 + (py - y) ^ 2)
                if d < bd then best, bd = i, d end
            end
            Pick(best)
        end
        drag = nil
    end)
    canvas:SetScript("OnUpdate", function()
        if not drag or not view.sc then return end
        local mx, my = GetCursorPosition()
        local s = canvas:GetEffectiveScale()
        local dx, dy = (mx - drag[1]) / s, (my - drag[2]) / s
        if math.abs(dx) + math.abs(dy) > 3 then drag[5] = true end
        if drag[5] then panY = drag[4] + dx / view.sc; panX = drag[3] - dy / view.sc; Draw() end
    end)
    H.PLB = function() pts = {} end
    H.PL = function(a) table.insert(pts, { tonumber(a[3]) or 0, tonumber(a[4]) or 0, tonumber(a[5]) or 0 }) end
    H.PLE = function(a) me = { tonumber(a[2]) or 0, tonumber(a[3]) or 0 }; Draw() end
    card:SetScript("OnSizeChanged", Draw)

    -- Saved paths: keep the route in the preview (recording or a shown path) under a name, load it back as the recording
    local function Lib() IlusixnDevMenuDB.paths = IlusixnDevMenuDB.paths or {}; return IlusixnDevMenuDB.paths end
    local sh = Header(p, "Saved paths"); sh:SetPoint("TOPLEFT", 528, -196)
    local ne = Edit(p, 116, 24); ne:SetPoint("TOPLEFT", 528, -220)
    local rows, page, Fill = {}, 0, nil
    local sv = Button(p, "Save", 70, 24, "accent", function() SaveCurrent(ne) end)
    sv:SetPoint("LEFT", ne, "RIGHT", 6, 0)
    local function LoadSaved(e)
        if not e then return end
        Send("PCLEAR")
        for _, q in ipairs(e.pts) do Send("PADDAT", q[1], q[2], q[3] - 0.1) end
        Toast(("Loaded \"%s\": %d points. Select the NPC and Save path."):format(e.name, #e.pts), "ok")
    end
    local function SaveCurrent(edit)
        if #pts < 2 then return Toast("Record or show a path first (2+ points)", "err") end
        local n = edit:GetText(); if n == "" then n = (GetSubZoneText() ~= "" and GetSubZoneText() or GetZoneText()) .. " path" end
        local copy = {}; for i, q in ipairs(pts) do copy[i] = { q[1], q[2], q[3] } end
        table.insert(Lib(), 1, { name = n, zone = GetZoneText(), pts = copy })
        edit:SetText(""); edit:ClearFocus(); page = 0; Fill()
        Toast(("Saved \"%s\" (%d points)"):format(n, #copy), "ok")
    end
    for i = 1, 5 do
        local r = Button(p, "", 164, 24, nil, function(self) LoadSaved(self.e) end)
        r:SetPoint("TOPLEFT", 528, -226 - i * 28)
        Tip(r, "Load path", "Replaces your recording with this path. Then Save path to selected NPC (works for any NPC near it).")
        local x = Button(p, "X", 26, 24, "danger", function()
            if rows[i].e then for k, e in ipairs(Lib()) do if e == rows[i].e then table.remove(Lib(), k) break end end; Fill() end
        end)
        x:SetPoint("LEFT", r, "RIGHT", 4, 0)
        rows[i] = r; r.x = x
    end
    local prev = Button(p, "<", 26, 22, nil, function() page = math.max(0, page - 1); Fill() end)
    prev:SetPoint("TOPLEFT", 528, -394)
    local nxt = Button(p, ">", 26, 22, nil, function() page = page + 1; Fill() end)
    nxt:SetPoint("LEFT", prev, "RIGHT", 4, 0)
    local pinfo = Text(p, 10, C.dim); pinfo:SetPoint("LEFT", nxt, "RIGHT", 8, 0)
    Fill = function()
        local L = Lib()
        page = math.min(page, math.max(0, math.ceil(#L / 5) - 1))
        for i, r in ipairs(rows) do
            local e = L[page * 5 + i]; r.e = e
            r.label:SetText(e and ("%s  |cff8a8f9c(%d)|r"):format(e.name, #e.pts) or "")
            if e then r:Show(); r.x:Show() else r:Hide(); r.x:Hide() end
        end
        pinfo:SetText(#L == 0 and "No saved paths yet" or ("Page %d / %d"):format(page + 1, math.max(1, math.ceil(#L / 5))))
    end
    -- the Path editor's controls, mirrored under the map
    local B = p.btn
    local function Row(y) local f = CreateFrame("Frame", nil, win); f:SetSize(1, 22); f:SetPoint("BOTTOMLEFT", 14, y); return f end
    local function Chain(row, list)
        local prev
        for _, b in ipairs(list) do
            if prev then b:SetPoint("LEFT", prev, "RIGHT", 10, 0) else b:SetPoint("LEFT", row, "LEFT", 0, 0) end
            prev = b
        end
        return prev
    end
    local function Mirror(label, w, src, style) return Button(win, label, w, 22, style, function() src:Click() end) end
    local r1 = Row(130)
    local mAdd, mEv = Mirror("Add point here", 112, B.add, "accent"), Mirror("Every step", 86, B.ev, "chip")
    local mCnt = Text(win, 13, C.text)
    Chain(r1, { mAdd, Mirror("Undo last", 76, B.undo), Mirror("Clear", 56, B.clr), mEv })
    mCnt:SetPoint("LEFT", mEv, "RIGHT", 12, 0)
    local r2 = Row(94)
    local mLoop, mBf = Mirror("Loop", 56, B.loop, "chip"), Mirror("Back and forth", 104, B.bf, "chip")
    local mWalk, mRun = Mirror("Walk", 50, B.walk, "chip"), Mirror("Run", 46, B.run, "chip")
    local wl = Text(win, 10, C.dim); wl:SetText("Wait at ends")
    local mWait = Edit(win, 36, 20, true)
    local last = Chain(r2, { mLoop, mBf, mWalk, mRun })
    wl:SetPoint("LEFT", last, "RIGHT", 16, 0); mWait:SetPoint("LEFT", wl, "RIGHT", 6, 0)
    mWait:SetScript("OnTextChanged", function(self) if self:HasFocus() then p.de:SetText(self:GetText()) end end)
    local r3 = Row(58)
    Chain(r3, { Mirror("Show path", 80, B.show), Mirror("Edit path", 76, B.edit), Mirror("Remove path", 92, B.del, "danger"),
        Mirror("Save path to selected NPC", 190, B.save, "accent") })
    local r4 = Row(20)
    local sl = Text(win, 10, C.dim); sl:SetText("Saved")
    local mName = Edit(win, 110, 20)
    local mSave = Button(win, "Save", 50, 22, "accent", function() SaveCurrent(mName) end)
    local cur = 1
    local mPick = Button(win, "", 150, 22, nil, function() LoadSaved(Lib()[cur]) end)
    Tip(mPick, "Load path", "Replaces your recording with this saved path.")
    local function ShowCur()
        local L = Lib(); cur = math.max(1, math.min(cur, #L))
        mPick.label:SetText(L[cur] and ("%s (%d)"):format(L[cur].name, #L[cur].pts) or "none saved")
    end
    local mPrev = Button(win, "<", 22, 22, nil, function() cur = cur - 1; ShowCur() end)
    local mNext = Button(win, ">", 22, 22, nil, function() cur = cur + 1; ShowCur() end)
    local mDel = Button(win, "X", 22, 22, "danger", function()
        if Lib()[cur] then table.remove(Lib(), cur); Fill() end
    end)
    sl:SetPoint("LEFT", r4, "LEFT", 0, 0); mName:SetPoint("LEFT", sl, "RIGHT", 6, 0)
    mSave:SetPoint("LEFT", mName, "RIGHT", 8, 0); mPrev:SetPoint("LEFT", mSave, "RIGHT", 16, 0)
    mPick:SetPoint("LEFT", mPrev, "RIGHT", 6, 0); mNext:SetPoint("LEFT", mPick, "RIGHT", 6, 0); mDel:SetPoint("LEFT", mNext, "RIGHT", 10, 0)
    local oldFill = Fill
    Fill = function() oldFill(); ShowCur() end
    -- keep the mirrored state in step with the page (both can be clicked)
    local tick = 0
    win:SetScript("OnUpdate", function(_, e)
        tick = tick + e
        if tick < 0.2 then return end
        tick = 0
        mEv:SetActive(B.ev.active); mLoop:SetActive(B.loop.active); mBf:SetActive(B.bf.active)
        mWalk:SetActive(B.walk.active); mRun:SetActive(B.run.active)
        mCnt:SetText(p.cnt:GetText() or "")
        if not mWait:HasFocus() and mWait:GetText() ~= p.de:GetText() then mWait:SetText(p.de:GetText()) end
    end)
    local prevShow = p.OnShowPage
    function p:OnShowPage() if prevShow then prevShow(self) end; Fill(); if not win:IsShown() then PlaceMap(); win:Show() end; Send("PLIST") end
end

-- ================================================================== Replace: turn the selected spawn into another NPC
do
    local f = CreateFrame("Frame", "CoADevReplace", UIParent)
    f:SetSize(520, 440); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetToplevel(true)
    f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    Skin(f, C.bg, { 0, 0, 0, 1 }); f:Hide()
    tinsert(UISpecialFrames, "CoADevReplace")
    local title = Header(f, "Replace selected NPC"); title:SetPoint("TOPLEFT", 14, -12)
    local x = Button(f, "X", 24, 24, nil, function() f:Hide() end); x:SetPoint("TOPRIGHT", -8, -8)
    local mode = "0"
    local search = Edit(f, 300, 24); search:SetPoint("TOPLEFT", 14, -40); search:SetPlaceholder("Name, title or entry id  (Enter)")
    local list
    local function Pick() return list.sel end
    list = MakeList(f, 13, 22, { { w = 70, color = C.dim }, { w = 250 }, { w = 120, size = 10, color = C.dim } }, function(d)
        list.sel = d; list:Refresh()
        if IsControlKeyDown() or IsShiftKeyDown() then   -- Ctrl / Shift + click: 3D preview, shown beside this window
            D.Preview(d.entry, d.name, d.sub)
            local pv = _G.CoADevMenuPreview
            if pv then pv:ClearAllPoints(); pv:SetPoint("LEFT", list:GetParent(), "RIGHT", 8, 0); pv:Raise() end
        end
    end)
    list:SetPoint("TOPLEFT", 14, -104); list:SetPoint("TOPRIGHT", -14, -104); list:SetHeight(288)
    list.format = function(d) return { d.entry, d.name, d.sub ~= "" and ("<" .. d.sub .. ">") or "" } end
    list.isSelected = function(d) return d == list.sel end
    local function Replace(d)
        d = d or Pick()
        if not d then return Toast("Click an NPC in the list first", "err") end
        if not S.selected then return Toast("Select a spawned NPC first", "err") end
        Send("ENTRY", S.selected.guid, d.entry); f:Hide()
    end
    list.onDouble = Replace
    local function Run()
        list.sel = nil; list.data = {}; list.offset = 0; list:Refresh()
        if mode == "cats" then
            local seen = {}
            for _, c in ipairs(IlusixnDevMenuDB.cats or {}) do
                for e, it in pairs(c.items or {}) do
                    local q = search:GetText():lower()
                    if not seen[e] and (q == "" or (it.name or ""):lower():find(q, 1, true) or e == q) then
                        seen[e] = true
                        list.data[#list.data + 1] = { entry = e, name = it.name or "?", sub = c.name or "" }
                    end
                end
            end
            table.sort(list.data, function(a, b) return a.name < b.name end)
            list:Refresh()
        else
            f.waiting = true
            Send("SEARCH", search:GetText(), 0, mode)
        end
    end
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Run() end)
    local chips = Chips(f, { { "0", "All NPCs" }, { "6", "Made by me" }, { "cats", "Favourites & categories" } }, 14, -72, 150, function(v) mode = v; Run() end)
    chips:Set("0")
    local go = Button(f, "Replace", 120, 28, "accent", function() Replace() end); go:SetPoint("BOTTOMRIGHT", -14, 12)
    local note = Text(f, 10, C.dim); note:SetPoint("BOTTOMLEFT", 14, 20); note:SetWidth(360)
    note:SetText("Ctrl or Shift + click: 3D preview. Double-click: replace. Keeps its place, path and spawn settings.")
    local oldSE = H.SE
    H.SE = function(a)
        oldSE(a)
        if f.waiting and f:IsShown() then
            f.waiting = false
            for i, r in ipairs(S.results or {}) do list.data[i] = r end
            list:Refresh()
        end
    end
    S.OpenReplace = function()
        f:Show(); search:SetFocus()
        if #list.data == 0 then Run() end
    end
end
