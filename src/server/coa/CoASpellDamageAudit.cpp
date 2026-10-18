/* Copyright (C) 2016+ AzerothCore, GNU AGPL v3.
 *
 * Issue #32: a classic-class character lands an oversized hit from a high-tier spell it never really earned -
 * e.g. Deep Freeze (a Frost Mage talent finisher) for ~1700 at level 1, or ~4400-6700 at a GM-boosted level 60
 * with no gear. The character does not even have the spell in its own spellbook (character_spell has no row for
 * it): it is firing through an auto-trigger/proc chain (Fingers of Frost -> Deep Freeze), which bypasses the
 * normal "can you even cast this" check entirely - so gating the cast itself (tried first, via
 * ALLSPELLHOOK_ON_SPELL_CHECK_CAST + Player::HasTalent) never runs for this path. The only hook that reliably
 * fires for a hit regardless of how it was triggered is UnitScript::ModifySpellDamageTaken, used here to zero
 * the hit outright (not clamp) when it is far beyond anything the caster's own level should produce. Applies at
 * every level, not just the early game, since the GM-boost test showed the same exploit at level 60 too.
 */
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "Unit.h"
#include "UnitScript.h"

namespace
{
    // base-points range for the one direct-damage effect of a spell, at the rank actually cast (no talents/gear);
    // used for the log line only - some high-tier abilities (Deep Freeze included) do not expose a plain roll, so
    // the ceiling below never depends on this succeeding.
    bool EffectRange(SpellInfo const* info, int32& lo, int32& hi)
    {
        for (SpellEffectInfo const& effect : info->Effects)
        {
            if (effect.Effect != SPELL_EFFECT_SCHOOL_DAMAGE)
                continue;
            lo = effect.BasePoints + 1;
            hi = effect.BasePoints + 1 + effect.DieSides;
            return true;
        }
        return false;
    }
}

class CoASpellDamageGuard final : public UnitScript
{
public:
    CoASpellDamageGuard() : UnitScript("CoASpellDamageGuard", true, {UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN}) { }

    void ModifySpellDamageTaken(Unit* /*target*/, Unit* attacker, int32& damage, SpellInfo const* spellInfo) override
    {
        if (damage <= 0 || !spellInfo)
            return;
        Player* caster = attacker ? attacker->ToPlayer() : nullptr;
        if (!caster)
            return;
        uint8 const classId = caster->getClass();
        if (classId < CLASS_WARRIOR || classId > CLASS_DRUID) // skip CoA Hero classes (12+): this is about classic ones
            return;
        // generous but bounded: real geared classic-class burst at this level, not a borrowed end-game finisher
        int32 const ceiling = int32(caster->GetLevel()) * 50 + 150;
        if (damage <= ceiling)
            return;
        int32 lo = 0, hi = 0;
        EffectRange(spellInfo, lo, hi);
        LOG_WARN("coa.spelldamage", "ZEROED caster={} race={} class={} level={} spell={} rank-base=[{}-{}] was={} "
            "ceiling={}", caster->GetGUID().ToString(), uint32(caster->getRace()), uint32(classId),
            uint32(caster->GetLevel()), spellInfo->Id, lo, hi, damage, ceiling);
        damage = 0;
    }
};

void AddSC_CoASpellDamageAudit()
{
    new CoASpellDamageGuard();
}
