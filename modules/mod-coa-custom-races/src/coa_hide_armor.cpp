/*
 * .hidearmor (also /hidearmor with the CoAHideArmor addon): hides every armor piece of your character for everyone
 * (head, shoulders, shirt, chest, waist, legs, feet, wrists, hands, cloak, tabard). Weapons stay. Toggle; it is
 * saved per character (characters database, coa_hide_armor) and comes back at login. The items stay equipped.
 */

#include "Chat.h"
#include "CommandScript.h"
#include "DatabaseEnv.h"
#include "Player.h"
#include "ScriptMgr.h"
#include <mutex>
#include <unordered_set>

using namespace Acore::ChatCommands;

namespace
{
    std::unordered_set<ObjectGuid::LowType> HiddenArmor;
    std::mutex HiddenArmorMutex;

    bool HasHiddenArmor(ObjectGuid::LowType guid)
    {
        std::lock_guard lock(HiddenArmorMutex);
        return HiddenArmor.contains(guid);
    }

    void SetHiddenArmor(ObjectGuid::LowType guid, bool hide)
    {
        std::lock_guard lock(HiddenArmorMutex);
        if (hide)
            HiddenArmor.insert(guid);
        else
            HiddenArmor.erase(guid);
    }

    bool IsArmorSlot(uint8 slot)
    {
        switch (slot)
        {
            case EQUIPMENT_SLOT_HEAD: case EQUIPMENT_SLOT_SHOULDERS: case EQUIPMENT_SLOT_BODY: case EQUIPMENT_SLOT_CHEST:
            case EQUIPMENT_SLOT_WAIST: case EQUIPMENT_SLOT_LEGS: case EQUIPMENT_SLOT_FEET: case EQUIPMENT_SLOT_WRISTS:
            case EQUIPMENT_SLOT_HANDS: case EQUIPMENT_SLOT_BACK: case EQUIPMENT_SLOT_TABARD:
                return true;
            default:
                return false;
        }
    }

    void RefreshArmor(Player* player)
    {
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            if (IsArmorSlot(slot))
                player->SetVisibleItemSlot(slot, player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));
    }
}

class CoAHideArmorPlayer : public PlayerScript
{
public:
    CoAHideArmorPlayer() : PlayerScript("CoAHideArmorPlayer", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_AFTER_SET_VISIBLE_ITEM_SLOT }) { }

    void OnPlayerLogin(Player* player) override
    {
        if (CharacterDatabase.Query("SELECT 1 FROM coa_hide_armor WHERE guid = {}", player->GetGUID().GetCounter()))
        {
            SetHiddenArmor(player->GetGUID().GetCounter(), true);
            RefreshArmor(player);
        }
    }

    void OnPlayerLogout(Player* player) override
    {
        SetHiddenArmor(player->GetGUID().GetCounter(), false);
    }

    void OnPlayerAfterSetVisibleItemSlot(Player* player, uint8 slot, Item* /*item*/) override
    {
        if (IsArmorSlot(slot) && HasHiddenArmor(player->GetGUID().GetCounter()))
        {
            player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENTRYID + (slot * 2), 0);
            player->SetUInt32Value(PLAYER_VISIBLE_ITEM_1_ENCHANTMENT + (slot * 2), 0);
        }
    }
};

class CoAHideArmorCommand : public CommandScript
{
public:
    CoAHideArmorCommand() : CommandScript("CoAHideArmorCommand") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandTable =
        {
            { "hidearmor", HandleHideArmor, SEC_PLAYER, Console::No },
        };
        return commandTable;
    }

    static bool HandleHideArmor(ChatHandler* handler)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;
        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        bool hide = !HasHiddenArmor(guid);
        if (hide)
        {
            SetHiddenArmor(guid, true);
            CharacterDatabase.Execute("REPLACE INTO coa_hide_armor (guid) VALUES ({})", guid);
        }
        else
        {
            SetHiddenArmor(guid, false);
            CharacterDatabase.Execute("DELETE FROM coa_hide_armor WHERE guid = {}", guid);
        }
        RefreshArmor(player);
        handler->PSendSysMessage(hide ? "Armor hidden. Type .hidearmor again to show it." : "Armor shown again.");
        return true;
    }
};

void AddCoAHideArmorScripts()
{
    new CoAHideArmorPlayer();
    new CoAHideArmorCommand();
}
