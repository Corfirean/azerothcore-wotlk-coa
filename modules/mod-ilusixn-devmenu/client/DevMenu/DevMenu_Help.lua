-- Dev Menu, part 4: Help page (how everything works + how to use it on another server / client)
local D = CoADev
local C, Text, Header = D.C, D.Text, D.Header
local p = D.pages.help

local Y = "|cffffc840"
local G = "|cff8a8f9c"
local E = "|r"
local HELP = {
    Y .. "WHAT IT IS" .. E,
    "Dev Menu edits the live world from inside the game: NPCs, their paths, services and looks, quests and objects. Every change is written to the world database right away and applied without a restart. Only GM accounts can use it (the server checks every request).",
    "",
    Y .. "OPENING IT" .. E,
    "/dev  opens or closes the menu.     /dev point  adds a path point where you stand.     /dev target  selects the NPC you target.",
    "Size and Opacity sliders (bottom left) and the corner grip resize the window. Everything you set is remembered per account.",
    "",
    Y .. "PAGES" .. E,
    Y .. "Browse NPCs" .. E .. "  search every creature by name, title or id. Ctrl+click or double-click: 3D preview. Right-click: spawn, favourites, categories, duplicate as a new NPC, rename the type, copy the id.",
    Y .. "Categories" .. E .. "  your own folders of NPCs plus Favourites.",
    Y .. "Selected NPC" .. E .. "  target an NPC and press Use my target (or tick Follow my target).",
    "   Placement: Move to me, the round pad (moves relative to where you face, centre = to me), the X/Y/Z gizmo (drag an axis to slide on the world axes, drag the ring to turn), exact facing in degrees.",
    "   Actions: stand / wander / walk a path, looping action (work, mine, sit...), All emotes searches every emote the game has.",
    "   Role & faction: services (vendor, trainer, innkeeper, banker...), guard behaviour, faction.",
    "   Combat: set the auto-attack damage per hit and the attack speed; add any spell on the server (search by name or id, or npc:<entry> to copy what another mob casts) with its timer, target and chance. Hostile and friendly NPCs both use them when they fight.",
    "   Identity: name, title, level, model, which NPC a spawn is. Services: shop items, trainer spells, talk menus with options and submenus. Advanced: every stat, flag and kill reputation.",
    "   " .. G .. "Name, level, look, faction and shop belong to the NPC type: every spawn of that type shares them. Tick 'Only this spawn' (or Make unique) to change just one." .. E,
    Y .. "Path editor" .. E .. "  walk and press Add point here at each spot, or turn on Every step (a point every step while you move). Loop or back-and-forth, walk or run, wait at the ends, then Save path to selected NPC. Show path draws an NPC's saved route; Edit path loads it as your recording.",
    "   Path map: its own window (opens with the Path editor, drag the title to move it, drag the corner to resize, X closes, Open path map brings it back). Mouse wheel zooms at the cursor, drag pans, Fit shows everything. Click a point (or type its number) to pick it, then Go to (teleport there), Move here, Insert after or Delete. Every Path editor button is also under the map.",
    "   Saved paths: name + Save keeps the route on the map; load one later as your recording (on the page or with < > under the map), X deletes it.",
    Y .. "Nearby spawns" .. E .. "  saved NPCs around you, nearest first.",
    Y .. "Quests" .. E .. "  create a quest given by the selected NPC; edit text, objectives, rewards, rules and chains; choose who gives and finishes it; make escort quests (the NPC walks a path recorded in the Path editor).",
    "   AI helper: describe the idea, Build prompt, paste it into any AI chat, paste the answer back, Apply. Nothing is sent anywhere by the game.",
    Y .. "Objects & assets" .. E .. "  search object types or every object model, 3D preview, spawn, select (Select nearest, Click in world, Nearby), move, rotate in 3 axes, duplicate, delete.",
    Y .. "Share as SQL" .. E .. "  every change you make is tracked automatically. Add area / Add my whole zone / Add everything made with Dev Menu pull in older work. Export SQL writes devmenu_sql/<date>_<name>.sql next to worldserver: each row as it is now (delete + insert), safe to run twice. Anyone runs it on their world database and gets the same NPCs in the same places. Clear change set starts a new one.",
    "   Dressed NPCs need the Dev Menu module on the other server, or bake them: run 'Bake dressed NPCs' after exporting. It writes <name>_baked.sql (no module needed) and patch-ZZZZZZ.MPQ for the players' Data folder. For HD-face races run 'Capture ON' first and look at each dressed NPC in game, so its real skin is used.",
    Y .. "Create an item" .. E .. "  build an item from A to Z: name, kind (armor, weapon, consumable, other), slot and type, quality, item level, required level, armor or damage, stats, prices, a spell and a description. Pick a look from the item search and see it on your character. Create item saves it at once (a reserved id range, set in the module config), Give me one puts it in your bags, My items lets you edit or delete what you made. Tooltips may need a relog to refresh after an edit.",
    "   Heirloom: tick Stats grow with your level, then pick up to 3 stats and how much each gains per level (0.5 = one point every 2 levels) and the max level. While it is equipped the server adds that bonus live, and the tooltip description says what it does. Needs this module on the server; other servers get a normal item.",
    Y .. "Your character" .. E .. "  one-click GM tools on yourself: God mode, GM mode, instant cast, no cooldowns, infinite mana, fly, walk on water, all flight paths; heal, repair, reveal the map, learn class spells, all mounts, max skills; set level; add gold, honor, arena points and emblems; Reps / faction button (top right of the tab): set every reputation at once or one faction at a time to any standing, and switch to Alliance, Horde (finish by logging out to the character screen) or Neutral (friendly to everyone until you log out); speed and size; the real heirloom set for your class; item sets (PvP seasons, raid tiers, any set by name, click to get the whole set); add any item by id.",
    Y .. "Morph" .. E .. "  turn yourself into any creature model. Search by creature name or display id, click a row for a 3D preview, Morph me (or double click). Previous / Next morph you through every model id that exists. Back to normal undoes it. Morphs are temporary.",
    Y .. "Server" .. E .. "  set the time of day for everyone online (or freeze it), change the weather of your zone, teleport to any game_tele place, switch holiday and world events on or off, go to or bring a player, announce to the server, see who is online, save everyone, and reload common tables after you edit them in the database.",
    Y .. "Create an NPC" .. E .. "  any race, gender, skin, face, hair, every armor slot and weapons. Click a slot for the wardrobe (Ctrl+click an item: try it on yourself). Live preview stands in front of you. Create it here or apply to the selected NPC. Save looks (whole NPC) and outfits (gear only, for many NPCs); share looks with a code.",
    "",
    Y .. "HOW NPC LOOKS WORK ON EVERY CLIENT" .. E,
    "Dressed NPCs use the same trick as the Mirror Image spell: the NPC wears its race's character model and the server tells each client its skin, face, hair and armor. Every unmodified 3.3.5 client shows it, no patch needed. A custom race shows on clients that have that race's files; armor shows everywhere. Weapons are normal NPC equipment.",
    "The wardrobe can only draw your own character with textures, so while it is open the server shows you with the NPC's race and look. You get your real look back when it closes, and before any save, logout or disconnect: the disguise never reaches the database.",
    "",
    Y .. "PUT IT ON ANOTHER SERVER (AzerothCore 3.3.5)" .. E,
    "1.  Copy the folder  mod-ilusixn-devmenu  into  azerothcore/modules/ , re-run CMake and build worldserver. No core changes and no SQL to import.",
    "2.  Optional: copy  conf/mod_ilusixn_devmenu.conf.dist  to your configs/modules as  mod_ilusixn_devmenu.conf .  DevMenu.Enable = 1,  DevMenu.MinSecurity = 2 (GM) or 3 (admin).",
    "3.  Copy  client/DevMenu  into  World of Warcraft/Interface/AddOns/  for every GM. Players don't need it (only for custom-client extra looks, see below).",
    "4.  The module makes its own table (coa_npc_outfit) on first start. Ids it creates: NPC types 9 980 001+, quests 9 990 001+, talk menus 9 998 001+, texts 16 000 001+, trainers 9 980 001+, escort paths 99 800 000+, object types 9 980 001+. If your server already uses these ranges, change the constants at the top of DevMenu.cpp.",
    "5.  It talks only through addon whispers with the prefix CDEV, so it works with any client and next to any other addon.",
    "",
    Y .. "LOOK ADAPTERS (EXTRA LOOK ROWS FOR CUSTOM CLIENTS)" .. E,
    "A normal 3.3.5 client has exactly 5 looks (skin, face, hair style, hair color, facial hair) and Dev Menu covers them all. Custom clients that add more (tattoos, horns...) can plug in an adapter: a few lines of Lua in any addon. Clients without an adapter simply ignore the extra values, so nothing breaks.",
    G .. "DevMenuLookAdapters = DevMenuLookAdapters or {}" .. E,
    G .. "table.insert(DevMenuLookAdapters, {" .. E,
    G .. "    name = \"My client\"," .. E,
    G .. "    IsAvailable = function() return MyClient_SetUnitLook ~= nil end," .. E,
    G .. "    GetOptions = function(race, gender) return { { key = \"tattoo\", label = \"Tattoo\", max = 8 } } end," .. E,
    G .. "    Apply = function(unitGuid, values) MyClient_SetUnitLook(unitGuid, values) end," .. E,
    G .. "})" .. E,
    "An adapter can also own the whole look: give it Encode(race, gender, values) -> {5 bytes}, extra and Decode(race, gender, bytes, extra) -> values, plus Handles(race, gender). Its rows then replace the 5 stock rows for those races. The server sends 'extra' after the stock NPC look data (8 bytes + 'DMX1'); stock clients ignore it. DevMenu_CoA.lua is the one for the CoA / Esteria races.",
    "GetOptions adds rows under the 5 looks in Create an NPC (the list scrolls). The values are saved with the NPC. When any player's client shows that NPC, the server whispers the values and Apply receives the NPC's GUID (\"0xF13...\") and a table like { tattoo = 3 }. How Apply draws them is up to that client (for example a function its own client code exposes).",
    "",
    Y .. "GOOD HABITS" .. E,
    "Back up the world database before big sessions: edits are saved immediately. Use 'Only this spawn' when an NPC type is shared. Changing an object's size, and the held items of a freshly copied NPC type, show after a restart.",
}

local h = Header(p, "Help"); h:SetPoint("TOPLEFT", 16, -14)
local sub = Text(p, 10, C.dim); sub:SetPoint("TOPLEFT", 16, -30); sub:SetText("Made by ilusixn. How everything works, and how to use Dev Menu on any server and client. Scroll with the mouse wheel.")
local sf = CreateFrame("ScrollFrame", nil, p)
sf:SetPoint("TOPLEFT", 16, -48); sf:SetPoint("BOTTOMRIGHT", -16, 12)
local child = CreateFrame("Frame", nil, sf)
child:SetWidth(690)
sf:SetScrollChild(child)
local body = Text(child, 11, C.text)
body:SetPoint("TOPLEFT", 0, 0); body:SetWidth(680); body:SetJustifyV("TOP"); body:SetSpacing(3)
body:SetText(table.concat(HELP, "\n"))
child:SetHeight(body:GetStringHeight() + 20)
sf:EnableMouseWheel(true)
sf:SetScript("OnMouseWheel", function(self, d)
    child:SetHeight(body:GetStringHeight() + 20)
    local mx = math.max(0, child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(mx, self:GetVerticalScroll() - d * 40)))
end)
function p:OnShowPage() child:SetHeight(body:GetStringHeight() + 20) end
