/*
 * CoA Custom Races - server master switch (coa_custom_races.conf: CoACustomRaces.Enable).
 *
 * The races themselves (ChrRaces / CharSections ... DBC rows, world SQL, client MPQs) come with the CoA Custom
 * package; the core patches it needs live in the core branch. This module is the switch a server manager toggles:
 * with CoACustomRaces.Enable = 0 no character of an added race can be created. Existing characters keep their data.
 */

#include "Config.h"
#include "Log.h"
#include "ScriptMgr.h"

namespace
{
    bool CustomRacesEnabled = false;

    // The original Wrath races; every other playable race id is a CoA Custom race.
    bool IsStockRace(uint8 race)
    {
        return race >= 1 && race <= 11 && race != 9;
    }
}

class CoACustomRacesConfig : public WorldScript
{
public:
    CoACustomRacesConfig() : WorldScript("CoACustomRacesConfig", { WORLDHOOK_ON_BEFORE_CONFIG_LOAD }) { }

    void OnBeforeConfigLoad(bool /*reload*/) override
    {
        CustomRacesEnabled = sConfigMgr->GetOption<bool>("CoACustomRaces.Enable", false);
        LOG_INFO("server.loading", "CoA Custom Races: {}", CustomRacesEnabled ? "enabled" : "disabled (no new characters of the added races)");
    }
};

class CoACustomRacesAccount : public AccountScript
{
public:
    CoACustomRacesAccount() : AccountScript("CoACustomRacesAccount", { ACCOUNTHOOK_CAN_ACCOUNT_CREATE_CHARACTER }) { }

    bool CanAccountCreateCharacter(uint32 /*accountId*/, uint8 race, uint8 /*charClass*/) override
    {
        return CustomRacesEnabled || IsStockRace(race);
    }
};

void AddCoAHideArmorScripts();

void Addmod_coa_custom_racesScripts()
{
    AddCoAHideArmorScripts();
    new CoACustomRacesConfig();
    new CoACustomRacesAccount();
}
