-- Dev Menu, part 8: Morph (turn into any model, with preview) and Server (time, weather, places, events and other world tools)
local D = CoADev
local C, Text, Header, Button, Edit, Check, Tip, MakeList, Send, Toast, H, Shown = D.C, D.Text, D.Header, D.Button, D.Edit, D.Check, D.Tip, D.MakeList, D.Send, D.Toast, D.H, D.Shown

-- ====================================================================== MORPH
do
    local p = D.pages.morph
    Header(p, "Morph into any model"):SetPoint("TOPLEFT", 16, -14)
    local search = Edit(p, 240, 24); search:SetPoint("TOPLEFT", 16, -42); search:SetPlaceholder("Creature name or display id (Enter)")
    local list
    local function Run() list:Search(function(pg) Send("MORSEARCH", search:GetText(), pg) end) end
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Run() end)
    local go = Button(p, "Search", 70, 24, "accent", function() Run() end); go:SetPoint("LEFT", search, "RIGHT", 8, 0)

    local model = CreateFrame("DressUpModel", nil, p)
    model:SetPoint("TOPLEFT", 400, -42); model:SetSize(300, 360)
    local bg = p:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetTexture(D.WHITE); bg:SetPoint("TOPLEFT", model); bg:SetPoint("BOTTOMRIGHT", model)
    bg:SetGradientAlpha("VERTICAL", 0.02, 0.02, 0.03, 1, 0.12, 0.12, 0.16, 1)
    local facing, drag, dragX = 0, false, 0
    model:EnableMouse(true); model:EnableMouseWheel(true)
    local zoom = 0
    model:SetScript("OnMouseDown", function() drag = true; dragX = GetCursorPosition() end)
    model:SetScript("OnMouseUp", function() drag = false end)
    model:SetScript("OnMouseWheel", function(self, d) zoom = math.max(-2, math.min(4, zoom + d * 0.4)); self:SetPosition(zoom, 0, 0) end)
    model:SetScript("OnUpdate", function(self) if drag then local x = GetCursorPosition(); facing = facing + (x - dragX) * 0.02; dragX = x; self:SetFacing(facing) end end)

    local sel = { id = nil, name = "", entry = nil }
    local previewing, keep = false, false   -- clicking a row morphs you to preview it; leaving puts you back unless you pressed Apply
    local info = Text(p, 11, C.text); info:SetPoint("TOPLEFT", 400, -410); info:SetWidth(300); info:SetJustifyH("LEFT")
    local tries = 0
    local retry = CreateFrame("Frame"); retry:Hide()
    local Show3D
    retry:SetScript("OnUpdate", function(self, el)
        self.t = (self.t or 0) + el
        if self.t < 0.4 then return end
        self.t = 0; tries = tries + 1
        if sel.entry and p:IsShown() then model:SetCreature(sel.entry); model:SetFacing(facing); model:SetPosition(zoom, 0, 0) end
        if tries >= 6 then self:Hide() end
    end)
    function Show3D()
        -- the server morphs you and sends the data of a creature that uses the model; the panel draws that creature
        if sel.entry and sel.entry > 0 then
            model:SetCreature(sel.entry); tries = 0; retry:Show()
        else
            model:ClearModel()
        end
        model:SetFacing(facing); model:SetPosition(zoom, 0, 0)
        local what = sel.id and ("Display " .. sel.id .. (sel.name ~= "" and ("   " .. sel.name) or "")) or "Pick a model in the list"
        if sel.id and not (sel.entry and sel.entry > 0) then what = what .. "\n(no creature uses this model, so there is no picture here: look at your character)" end
        info:SetText(what .. (previewing and not keep and "\n|cffffc840Preview: you go back to normal when you leave unless you press Apply.|r" or ""))
    end
    local function Preview(id)
        previewing = true; keep = false
        Send("MORPH", id)
    end
    local function Revert()
        if previewing and not keep then Send("MORPH", 0) end
        previewing = false
    end

    list = MakeList(p, 14, 22, { { w = 56, color = C.dim, right = true }, { w = 260 } }, function(d)
        sel = { id = d.id, name = d.name }; Preview(d.id)
    end)
    list:SetPoint("TOPLEFT", 16, -76); list:SetSize(372, 312)
    list.format = function(d) return { tostring(d.id), d.name } end
    list.isSelected = function(d) return sel.id == d.id end
    list.data = {}
    for i, r in ipairs(list.rows) do r:HookScript("OnClick", function() list:Refresh() end) end
    local pager = Text(p, 10, C.dim); pager:SetPoint("TOPLEFT", 16, -396)

    local me = Button(p, "Apply (keep this form)", 190, 30, "accent", function()
        if not sel.id then return Toast("Click a model first", "err") end
        keep = true; previewing = false; Show3D(); Toast("You keep this form until Back to normal or logout", "ok")
    end)
    me:SetPoint("TOPLEFT", 16, -430)
    Tip(me, "Apply", "Clicking a model morphs you into it so you can see it. If you leave this tab or close the menu without Apply, you go back to your own model.")
    local back = Button(p, "Back to normal", 130, 30, "danger", function() keep = false; previewing = false; Send("MORPH", 0) end); back:SetPoint("LEFT", me, "RIGHT", 8, 0)

    Header(p, "Walk through every model id"):SetPoint("TOPLEFT", 16, -478)
    local idE = Edit(p, 80, 24, true); idE:SetPoint("TOPLEFT", 16, -504); idE:SetPlaceholder("display id")
    local goId = Button(p, "Preview", 70, 24, "accent", function() local id = tonumber(idE:GetText()) or 0; sel = { id = id, name = "" }; Preview(id) end); goId:SetPoint("LEFT", idE, "RIGHT", 6, 0)
    local function Step(dir) previewing = true; keep = false; Send("MORSTEP", tonumber(idE:GetText()) or sel.id or 1, dir) end
    local prev = Button(p, "< Previous model", 120, 24, nil, function() Step(-1) end); prev:SetPoint("LEFT", goId, "RIGHT", 14, 0)
    local nxt = Button(p, "Next model >", 110, 24, nil, function() Step(1) end); nxt:SetPoint("LEFT", prev, "RIGHT", 6, 0)
    local tip = Text(p, 10, C.dim); tip:SetPoint("TOPLEFT", 16, -536); tip:SetWidth(690); tip:SetJustifyH("LEFT")
    tip:SetText("Previous / Next morph you into the next model that exists, so you can flip through every one. Press Apply to keep the one you like.")

    local redraw = CreateFrame("Frame"); redraw:Hide()
    redraw:SetScript("OnUpdate", function(self, el) self.t = (self.t or 0) + el; if self.t > 0.4 then self:Hide(); self.t = 0; Show3D() end end)
    H.MORN = function(a)
        local id = tonumber(a[2]) or 0
        if id > 0 then idE:SetText(tostring(id)); sel.id = id; sel.entry = tonumber(a[3]); if not sel.name then sel.name = "" end end
        redraw:Show()
    end
    H.MORB = function(a) list:Begin(a[4]) end
    H.MORR = function(a) table.insert(list.data, { id = tonumber(a[2]), name = a[3] or "" }) end
    H.MORE = function(a)
        list:Done()
        pager:SetText((a[2] or "0") .. " models (scroll for more)")
    end
    p:HookScript("OnHide", Revert)
    D.M:HookScript("OnHide", Revert)
    function p:OnShowPage() if #list.data == 0 then Run() end; Show3D() end
end

-- ====================================================================== SERVER
do
    local p = D.pages.server
    Header(p, "Time of day"):SetPoint("TOPLEFT", 16, -14)
    local speed = 1
    local speedChips = {}
    local function SetTime(h, m) Send("SRV", "time", h, m, speed) end
    local TIMES = { { "Dawn", 5, 30 }, { "Morning", 9, 0 }, { "Noon", 12, 0 }, { "Dusk", 18, 30 }, { "Night", 22, 0 }, { "Midnight", 0, 0 } }
    for i, t in ipairs(TIMES) do
        local b = Button(p, t[1], 54, 24, "chip", function() SetTime(t[2], t[3]) end)
        b:SetPoint("TOPLEFT", 16 + (i - 1) * 58, -40)
    end
    local hE = Edit(p, 36, 24, true); hE:SetPoint("TOPLEFT", 16, -72); hE:SetText("12")
    local mE = Edit(p, 36, 24, true); mE:SetPoint("LEFT", hE, "RIGHT", 4, 0); mE:SetText("00")
    local tb = Button(p, "Set time", 80, 24, "accent", function() SetTime(tonumber(hE:GetText()) or 12, tonumber(mE:GetText()) or 0) end); tb:SetPoint("LEFT", mE, "RIGHT", 8, 0)
    for i, s in ipairs({ { 1, "Normal" }, { 0, "Frozen" }, { 10, "x10 fast" } }) do
        local b = Button(p, s[2], 56, 24, "chip", function()
            speed = s[1]
            for _, c in ipairs(speedChips) do c:SetActive(c.v == speed) end
            Toast("Clock speed picked: " .. s[2] .. ". Press a time to apply.", "ok")
        end)
        b.v = s[1]; b:SetPoint("LEFT", tb, "RIGHT", 8 + (i - 1) * 60, 0); speedChips[i] = b
    end
    speedChips[1]:SetActive(true)
    local tnote = Text(p, 10, C.dim); tnote:SetPoint("TOPLEFT", 16, -102); tnote:SetWidth(330); tnote:SetJustifyH("LEFT")
    tnote:SetText("Sets the clock for everyone online. Frozen keeps the time you set. A player's clock goes back to real time when they log in.")

    Header(p, "Weather"):SetPoint("TOPLEFT", 16, -138)
    local grade = 0.6
    local gradeChips = {}
    for i, g in ipairs({ { 0.3, "Light" }, { 0.6, "Medium" }, { 1, "Heavy" } }) do
        local b = Button(p, g[2], 60, 22, "chip", function()
            grade = g[1]; for _, c in ipairs(gradeChips) do c:SetActive(c.v == grade) end
        end)
        b.v = g[1]; b:SetPoint("TOPLEFT", 16 + (i - 1) * 64, -164); gradeChips[i] = b
    end
    gradeChips[2]:SetActive(true)
    for i, w in ipairs({ { 0, "Clear" }, { 1, "Rain" }, { 2, "Snow" }, { 3, "Sandstorm" } }) do
        local b = Button(p, w[2], 76, 26, nil, function() Send("SRV", "weather", w[1], w[1] == 0 and 0 or grade) end)
        b:SetPoint("TOPLEFT", 16 + (i - 1) * 80, -192)
    end
    local wnote = Text(p, 10, C.dim); wnote:SetPoint("TOPLEFT", 16, -224); wnote:SetWidth(330); wnote:SetJustifyH("LEFT")
    wnote:SetText("Changes the weather of the zone you are in. Pick the strength first.")

    Header(p, "Players"):SetPoint("TOPLEFT", 16, -258)
    local nameE = Edit(p, 130, 24); nameE:SetPoint("TOPLEFT", 16, -284); nameE:SetPlaceholder("player name")
    local ap = Button(p, "Go to them", 90, 24, nil, function() Send("SRV", "appear", nameE:GetText()) end); ap:SetPoint("LEFT", nameE, "RIGHT", 6, 0)
    local su = Button(p, "Bring them", 90, 24, nil, function() Send("SRV", "summon", nameE:GetText()) end); su:SetPoint("LEFT", ap, "RIGHT", 6, 0)

    Header(p, "Announce"):SetPoint("TOPLEFT", 16, -324)
    local annE = Edit(p, 250, 24); annE:SetPoint("TOPLEFT", 16, -350); annE:SetPlaceholder("message for the whole server")
    local annB = Button(p, "Send", 70, 24, "accent", function() Send("SRV", "announce", annE:GetText()) end); annB:SetPoint("LEFT", annE, "RIGHT", 6, 0)

    Header(p, "Server"):SetPoint("TOPLEFT", 16, -390)
    local sinfo = Text(p, 11, C.text); sinfo:SetPoint("TOPLEFT", 16, -416); sinfo:SetText("")
    local ib = Button(p, "Refresh", 70, 22, nil, function() Send("SRV", "info") end); ib:SetPoint("TOPLEFT", 16, -438)
    local sv = Button(p, "Save all players", 120, 22, nil, function() Send("SRV", "saveall") end); sv:SetPoint("LEFT", ib, "RIGHT", 6, 0)
    local rl = Text(p, 10, C.dim); rl:SetPoint("TOPLEFT", 16, -472); rl:SetText("Reload a table after editing it in the database")
    local RELOAD = { "creature_template", "gameobject_template", "npc_vendor", "smart_scripts", "gossip_menu", "creature_text", "quest_template", "conditions", "game_tele", "loot_templates" }
    local cx, cy = 16, -490
    for _, n in ipairs(RELOAD) do
        local b = Button(p, n, 10, 22, "chip", function() Send("SRV", "reload", n) end)
        b:SetWidth(math.max(40, b.label:GetStringWidth() + 14))
        if cx + b:GetWidth() > 350 then cx = 16; cy = cy - 26 end
        b:SetPoint("TOPLEFT", cx, cy); cx = cx + b:GetWidth() + 4
    end

    -- right side: places and events
    local RX = 372
    local mode = "places"
    local search = Edit(p, 200, 24); search:SetPoint("TOPLEFT", RX, -42); search:SetPlaceholder("Search (Enter)")
    local chipP = Button(p, "Places", 70, 24, "chip", nil); chipP:SetPoint("TOPLEFT", RX, -14)
    local chipE = Button(p, "Events", 70, 24, "chip", nil); chipE:SetPoint("LEFT", chipP, "RIGHT", 6, 0)
    local list
    list = MakeList(p, 14, 22, { { w = 226 }, { w = 74, color = C.dim, right = true } }, function(d)
        if mode == "places" then Send("SRV", "tele", d.id)
        else Send("SRV", "event", d.active and "stop" or "start", d.id); d.active = not d.active; list:Refresh() end
    end)
    list:SetPoint("TOPLEFT", RX, -76); list:SetSize(342, 312)
    list.format = function(d)
        if mode == "places" then return { d.name, "map " .. d.map } end
        return { d.name, d.active and "ON" or "off" }
    end
    list.data = {}
    local pager = Text(p, 10, C.dim); pager:SetPoint("TOPLEFT", RX, -400)
    local function Run()
        list:Search(function(pg)
            if mode == "places" then Send("SRVTELE", search:GetText(), pg) else Send("SRVEV", search:GetText(), pg) end
        end)
    end
    local function SetMode(m)
        mode = m; list.data = {}; list:Refresh()
        chipP:SetActive(m == "places"); chipE:SetActive(m == "events")
        pager:SetText(""); Run()
    end
    chipP:SetScript("OnClick", function() SetMode("places") end)
    chipE:SetScript("OnClick", function() SetMode("events") end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Run() end)
    local help = Text(p, 10, C.dim); help:SetPoint("TOPLEFT", RX, -428); help:SetWidth(342); help:SetJustifyH("LEFT")
    help:SetText("Places: click to teleport there (the game_tele table, so every .tele name works).\nEvents: click to switch a holiday or world event on or off.")
    local function Rows(a, isEv)
        return { id = tonumber(a[2]), name = a[3] or "", map = a[4], active = a[4] == "1" }
    end
    H.TLB = function(a) list:Begin(a[4]) end
    H.TLR = function(a) table.insert(list.data, Rows(a)) end
    H.TLE = function(a) if mode ~= "places" then return end list:Done(); pager:SetText((a[2] or "0") .. " places (scroll for more)") end
    H.EVB = function(a) list:Begin(a[4]) end
    H.EVR = function(a) table.insert(list.data, Rows(a, true)) end
    H.EVE = function(a) if mode ~= "events" then return end list:Done(); pager:SetText((a[2] or "0") .. " events (scroll for more)") end
    H.SI = function(a)
        local s = tonumber(a[3]) or 0
        sinfo:SetText(("%s players online   up %dd %dh %dm"):format(a[2] or "?", math.floor(s / 86400), math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60)))
    end
    function p:OnShowPage() Send("SRV", "info"); chipP:SetActive(mode == "places"); chipE:SetActive(mode == "events"); if #list.data == 0 then Run() end end
end
