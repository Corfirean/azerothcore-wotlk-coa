-- Dev Menu, part 5: Share as SQL. Every change the menu makes is tracked; Export writes a re-runnable .sql file
-- (DELETE + INSERT of the rows as they are now) into devmenu_sql/ next to worldserver.
local D = CoADev
local C, Text, Header, Button, Edit, Card, Tip, Send, Toast, p, H = D.C, D.Text, D.Header, D.Button, D.Edit, D.Card, D.Tip, D.Send, D.Toast, D.pages.share, D.H

local h = Header(p, "Share your work as SQL"); h:SetPoint("TOPLEFT", 16, -16)
local info = Text(p, 11, C.text); info:SetPoint("TOPLEFT", 16, -42); info:SetWidth(690); info:SetJustifyH("LEFT")
info:SetText("Every change you make with the menu is added to the change set: placed or deleted NPCs and objects, paths, looks, names, vendors, trainers, talk menus, spells, quests. "
    .. "Export writes one .sql file with those rows exactly as they are now. Anyone can run it on their world database (it is safe to run twice) and see the same NPCs in the same places.")

local cnt = Text(p, 22, C.accent); cnt:SetPoint("TOPLEFT", 16, -104); cnt:SetText("...")
local cntSub = Text(p, 10, C.dim); cntSub:SetPoint("LEFT", cnt, "RIGHT", 10, -2); cntSub:SetText("tracked rows in the change set")

local ah = Header(p, "Add work you did before (or someone else's)"); ah:SetPoint("TOPLEFT", 16, -148)
local rl = Text(p, 11, C.dim); rl:SetPoint("TOPLEFT", 16, -178); rl:SetText("Everything within")
local re = Edit(p, 60, 24, true); re:SetPoint("LEFT", rl, "RIGHT", 8, 0); re:SetText("150")
local yl = Text(p, 11, C.dim); yl:SetPoint("LEFT", re, "RIGHT", 6, 0); yl:SetText("yards of me")
local bArea = Button(p, "Add area", 110, 26, "accent", function() Send("SQLAREA", tonumber(re:GetText()) or 150) end)
bArea:SetPoint("LEFT", yl, "RIGHT", 10, 0)
Tip(bArea, "Add area", "Adds every saved NPC and object around you, with their paths. NPC types made with the menu come with their look, gear, shop and menus.")
local bZone = Button(p, "Add my whole zone", 150, 26, nil, function() Send("SQLAREA", 0) end)
bZone:SetPoint("LEFT", bArea, "RIGHT", 8, 0)
local bAll = Button(p, "Add everything made with Dev Menu", 260, 26, nil, function() Send("SQLALL") end)
bAll:SetPoint("TOPLEFT", 16, -212)
Tip(bAll, "Everything made with Dev Menu", "Every NPC type, object type and quest in the menu's id ranges, and every spawn of them.")

local eh = Header(p, "Export"); eh:SetPoint("TOPLEFT", 16, -262)
local nl = Text(p, 11, C.dim); nl:SetPoint("TOPLEFT", 16, -292); nl:SetText("File name")
local ne = Edit(p, 220, 24); ne:SetPoint("LEFT", nl, "RIGHT", 8, 0); ne:SetText("my_city")
local bExp = Button(p, "Export SQL", 130, 30, "accent", function() Send("SQLEXP", ne:GetText()) end)
bExp:SetPoint("LEFT", ne, "RIGHT", 10, 0)

local outL = Text(p, 10, C.dim); outL:SetPoint("TOPLEFT", 16, -330); outL:SetText("Saved to (on the server machine, click to select and Ctrl+C):")
local out = Edit(p, 690, 24); out:SetPoint("TOPLEFT", 16, -348)
out:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

local clr, armed = nil, false
clr = Button(p, "Clear change set", 150, 26, "danger", function()
    if not armed then
        armed = true; clr:SetLabel("Click again to clear")
        return Toast("Clearing forgets what was tracked (your world is not changed). Click again to confirm.", "err")
    end
    armed = false; clr:SetLabel("Clear change set"); Send("SQLCLR")
end)
clr:SetPoint("TOPLEFT", 16, -388)
Tip(clr, "Clear change set", "Start a new change set, for example after you exported. Nothing in the world is changed.")

local tips = Text(p, 10, C.dim); tips:SetPoint("TOPLEFT", 16, -426); tips:SetWidth(690); tips:SetJustifyH("LEFT")
tips:SetText("Good to know:\n"
    .. "- The file uses this server's ids. The other server should not already use the same spawn ids (or it overwrites them).\n"
    .. "- Dressed NPCs need the Dev Menu module on the other server, or bake them: run 'Bake dressed NPCs' after exporting (gives _baked.sql + a client patch).")

H.SQLN = function(a) cnt:SetText(a[2] or "0") end
H.SQLF = function(a)
    out:SetText(a[2] or ""); out:SetCursorPosition(0)
    Toast(("Exported %s rows"):format(a[3] or "0"), "ok")
end
function p:OnShowPage()
    armed = false; clr:SetLabel("Clear change set"); Send("SQLN") end
