/*
 * Copyright (C) 2016+ AzerothCore <www.azerothcore.org>, released under GNU AGPL v3 license.
 */

#include "AscensionIncarnation.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"
#include <map>
#include <unordered_map>

static std::unordered_map<uint32, std::map<uint32, uint32>> CustomRaceDisplays; // (race << 8 | gender) -> idx -> look

static void LoadCustomRaceDisplays()
{
    CustomRaceDisplays.clear();
    if (!sConfigMgr->GetOption<bool>("CoACustomRaces.Enable", false))
        return;

    QueryResult result = WorldDatabase.Query("SELECT race, gender, idx, displayId FROM custom_race_display");
    if (!result)
        return;

    uint32 count = 0;
    do
    {
        Field* fields = result->Fetch();
        CustomRaceDisplays[(fields[0].Get<uint32>() << 8) | fields[1].Get<uint32>()][fields[2].Get<uint32>()] = fields[3].Get<uint32>();
        ++count;
    } while (result->NextRow());
    LOG_INFO("server.loading", ">> Loaded {} custom race looks", count);
}

bool IsAscensionMaleOnlyRace(uint8 race)
{
    if (!sConfigMgr->GetOption<bool>("CoACustomRaces.Enable", false))
        return false;

    // Tuskarr, Taunka, Vrykul, Fel Orc, Forest Troll, Ice Troll, Skeleton: same list as the client's
    // CHAR_CREATE_MALE_ONLY_RACES (patchlua_races.py). A female of these races has no body in the client.
    // Broken (22) has one since it is Eunoia's Broken (gen_eunoia.py). Thin Human (32) and Furbolg (50) have a single
    // model for both: female gear on it stretched across the screen (CoA Custom 1.4).
    switch (race)
    {
        case 15: case 17: case 18: case 23: case 24: case 25: case 26: case 32: case 50:
            return true;
        default:
            return false;
    }
}

bool HasAscensionCustomRaceDisplay(uint8 race, uint8 gender)
{
    if (!sConfigMgr->GetOption<bool>("CoACustomRaces.Enable", false))
        return false;

    auto const itr = CustomRaceDisplays.find((uint32(race) << 8) | gender);
    return itr != CustomRaceDisplays.end() && !itr->second.empty();
}

uint32 GetAscensionCustomRaceDisplay(Player const* player)
{
    if (!player || !sConfigMgr->GetOption<bool>("CoACustomRaces.Enable", false))
        return 0;

    auto const itr = CustomRaceDisplays.find((uint32(player->getRace(true)) << 8) | player->getGender());
    if (itr == CustomRaceDisplays.end() || itr->second.empty())
        return 0;

    // idx = hair style * 32 + skin colour (Whim murloc: armor x body); else the skin colour picks a look
    std::map<uint32, uint32> const& looks = itr->second;
    uint32 const skin = player->GetByteValue(PLAYER_BYTES, 0);
    uint32 const hairStyle = player->GetByteValue(PLAYER_BYTES, 2);
    uint32 display = 0;
    if (auto const look = looks.find(hairStyle * 32 + skin); look != looks.end())
        display = look->second;
    else if (auto const bySkin = looks.find(skin); bySkin != looks.end())
        display = bySkin->second;
    else
        display = std::next(looks.begin(), skin % looks.size())->second;

    LOG_INFO("coa", "Custom race look for {}: race {} gender {} skin {} hair style {} -> display {}",
        player->GetName(), player->getRace(true), player->getGender(), skin, hairStyle, display);
    return display;
}

class CustomRacesWorldScript : public WorldScript
{
public:
    CustomRacesWorldScript() : WorldScript("CustomRacesWorldScript", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        LoadCustomRaceDisplays();
    }
};

void AddSC_CoACustomRaces()
{
    new CustomRacesWorldScript();
}
