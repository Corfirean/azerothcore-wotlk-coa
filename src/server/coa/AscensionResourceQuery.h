/*
 * mod-ascension-compat
 *
 * Public, read-only resource metadata & live-state query API.
 *
 * AscensionCustomResourceData.h's tables (ResourceDisplays/ResourceGainRules/ResourceCostRules/
 * NativePowerGainRules) describe *most* of each class's real resource behavior, but several
 * classes' true gain/spend/cap logic lives in hand-written per-class code (AscensionPyromancer::
 * Resource, AscensionCultist::Resource, AscensionVenomancer::Resource, AscensionTinker::Resource,
 * AscensionSunCleric::Resource, HandleAscensionReaperResource, HandleAscensionPrimalistEarthshaping
 * Gain, and several classes' own OnSpellCheckCast hooks) and is NOT fully reflected in those
 * tables -- e.g. SunCleric's SolarPower caps at a hardcoded 20 regardless of its ResourceDisplays
 * row, Venomancer's Brood/Exposed caps come from the spell's own CalcMaxAuraStacks, and a handful
 * of classes (Reaper, Ranger, Starcaller, Knight of Xoroth) gate specific casts on custom resource
 * stacks entirely outside ResourceCostRules.
 *
 * This header is the single place other modules (bot AI, tooling) should query real resource
 * state and ability resource requirements from -- never re-derive rules from the raw tables or
 * from a class's own hardcoded constants independently. Every function here is read-only: none of
 * them mutate player state or change any gameplay behavior.
 */

#ifndef ASCENSION_RESOURCE_QUERY_H
#define ASCENSION_RESOURCE_QUERY_H

#include "AscensionCustomResourceData.h"
#include "Define.h"
#include <vector>

class Player;

namespace AscensionCompatData
{
    // One resource "channel" a class can have -- either a native Blizzard power bar (identified
    // by Powers enum value) or a custom stacking aura. A class can have zero, one, or several
    // simultaneously: e.g. Reaper has 3 aura channels (Reaped Soul/Soul Fragment/Soul Infusion)
    // plus native Runic Power; Runemaster has 3 aura channels (arcane/fire/frost sigil) and no
    // resource-shaped native bar; most non-custom classes (13/15/18) have zero aura channels and
    // rely purely on their native power bar, which callers can already read directly via
    // Player::getPowerType()/GetPower()/GetMaxPower() without consulting this API at all.
    struct ResourceChannel
    {
        bool IsNative = false;
        uint8 NativePowerType = 0;  // valid when IsNative (a Powers enum value)
        uint32 AuraSpellId = 0;     // valid when !IsNative
        char const* Name = "";
    };

    // Every resource channel `classId` actually has. Built from ResourceDisplays plus a small,
    // manually-curated set of additions for resources that exist in the class's own C++ code but
    // have no ResourceDisplays row at all (Venomancer's second resource "Exposed", Knight of
    // Xoroth's second resource "Blood") -- see the .cpp for exactly which and why. Reaper's native
    // Runic Power is included explicitly since it's a real, load-bearing part of that class's
    // resource economy (crit-proc bonus generation outside NativePowerGainRules); other classes'
    // native power bars are not listed here since a caller can already read them generically.
    std::vector<ResourceChannel> const& GetResourceChannels(uint8 classId);

    struct ResourceState
    {
        uint32 Current = 0;
        uint32 Maximum = 0;
        bool MaximumKnown = false;
    };

    // Current/maximum for one custom aura-stack resource, matching exactly what that class's own
    // gain/spend code enforces -- not a generic DisplayMaximum-or-StackAmount guess. See the .cpp
    // for the specific classes (SunCleric/Cultist/Tinker) whose real cap is a hardcoded literal
    // that doesn't match their ResourceDisplays row, and Venomancer, whose real cap is dynamic
    // (SpellInfo::CalcMaxAuraStacks) rather than the row's static number. Returns
    // MaximumKnown=false (with Current still valid) when no display row exists and the spell's
    // own CalcMaxAuraStacks resolves to 0 -- callers must not invent a percentage in that case.
    ResourceState QueryAuraResourceState(Player* player, uint32 resourceSpellId);

    // One custom-resource requirement a specific already-resolved ability has (classId +
    // resolvedSpellId -- use the resolved rank, not the profile's root spell id, since a rule's
    // FirstSpellId/LastSpellId range is matched against the real cast spell id). Resolved from
    // ResourceCostRules (first matching row wins, exactly mirroring AscensionResourceService::
    // CheckCast/OnSpellCast's own first-match-then-break semantics -- these tables never define
    // more than one requirement per spell today) PLUS every hardcoded special-case gate found by a
    // full audit of every OnSpellCheckCast/CanPrepare in this module (see the .cpp for the
    // per-class list -- Reaper's Generate Soul, Ranger's Advantage, Starcaller's Lunar Phase,
    // Knight of Xoroth's Demonfire (via the real AscensionXoroth::Spender predicate, not a
    // hand-copied id list) and Blood, Venomancer's Brood (via the real AscensionVenomancer::
    // Spender predicate), Cultist's conditional Insanity spend, Sun Cleric's DawnCast, Tinker's
    // Mechsuit). Returns an empty vector when the ability has no custom resource requirement at
    // all (most abilities, most classes) -- callers must still separately check the spell's native
    // DBC power cost via SpellInfo::CalcPowerCost, which this function deliberately does not
    // duplicate. Does NOT cover Necromancer's minion-capacity gate (a different resource shape --
    // see QueryMinionCapacityCost) or a pure aura-presence/absence gate with no numeric resource
    // behind it (see QueryAbilityAuraGates).
    //
    // Conditional requirements: RequiredAuraSpellId/ForbiddenAuraSpellId (0 = no condition) say
    // when this requirement actually applies -- e.g. Cultist's 40-Insanity spend is only a real
    // requirement while the Madness aura is ABSENT (ForbiddenAuraSpellId = Madness); while Madness
    // is up the ability needs no Insanity at all (see AscensionCultist::Resource's own comment on
    // why a decrease is silently dropped there). This function returns the requirement's static
    // shape unconditionally (cacheable by classId+spellId, independent of which player asks); the
    // caller evaluates RequiredAuraSpellId/ForbiddenAuraSpellId against the real player to decide
    // whether it's active right now.
    struct ResourceRequirement
    {
        uint32 ResourceSpellId = 0;
        uint32 Amount = 0;
        ResourceConsumption Consumption = ResourceConsumption::None;
        uint32 PreserveCostAuraSpellId = 0;
        uint8 PreserveCostChancePercent = 0;
        uint32 RequiredAuraSpellId = 0;   // requirement only active while this aura IS present
        uint32 ForbiddenAuraSpellId = 0;  // requirement only active while this aura is ABSENT
    };
    std::vector<ResourceRequirement> QueryAbilityResourceRequirements(uint8 classId, uint32 resolvedSpellId);

    // A pure aura-presence/absence cast gate with no numeric resource economy behind it -- e.g.
    // Sun Cleric's DawnCast additionally requires the Dawn aura to be ABSENT (on top of its real
    // SolarPower>=20 numeric requirement, which IS in QueryAbilityResourceRequirements). Kept
    // separate from ResourceRequirement rather than faked as a 0/1 aura-stack resource, per this
    // module's own review guidance: don't force a binary aura-state check into a numeric-resource
    // shape just to reuse one model.
    struct AuraGate
    {
        uint32 AuraSpellId = 0;
        bool RequireAbsent = true;  // true: this gate blocks the cast while the aura IS present;
                                     // false: blocks while the aura is ABSENT
    };
    std::vector<AuraGate> QueryAbilityAuraGates(uint8 classId, uint32 resolvedSpellId);

    // Necromancer's minion-capacity economy (classId 23) is a different resource *shape* entirely
    // -- an active-summon counter (AscensionNecromancer::Capacity/Used), not an aura-stack or
    // native power bar -- so it gets its own tiny query pair rather than being forced into
    // ResourceRequirement. Both call straight through to AscensionNecromancer's own real
    // Capacity/Used/Cost functions (never reimplemented here); Cost specifically needs a live
    // Player because at least one spell's real cost depends on a talent aura
    // (AscensionNecromancer::Cost's own 500331 special case), so it is intentionally NOT
    // classId+spellId cacheable the way ResourceRequirement is. Returns {0, 0} / 0 for every class
    // other than Necromancer.
    struct MinionCapacityState
    {
        uint32 Current = 0;  // currently-used capacity (live minion count, already pruned of dead/
                              // despawned/out-of-map summons)
        uint32 Maximum = 0;
    };
    MinionCapacityState QueryMinionCapacityState(Player* player);
    uint32 QueryMinionCapacityCost(Player* player, uint32 resolvedSpellId);

    // One resource this ability potentially generates (classId + resolvedSpellId), resolved from
    // ResourceGainRules (custom aura, IsNative=false) and NativePowerGainRules (native power bar,
    // IsNative=true), matched by spell id range the same way the runtime event handlers do.
    // Event-gated gains keep their Event/RequiredAuraSpellId/ForbiddenAuraSpellId/ChancePercent so
    // a caller can tell "always generates on cast" apart from "may generate depending on what
    // happens next" -- this is metadata only (what CAN this ability generate), not a prediction of
    // what it WILL generate on any given cast.
    struct ResourceGain
    {
        bool IsNative = false;
        uint32 ResourceSpellId = 0;  // valid when !IsNative
        uint8 NativePowerType = 0;   // valid when IsNative
        int32 Amount = 0;
        ResourceGainEvent Event = ResourceGainEvent::Cast;
        uint32 RequiredAuraSpellId = 0;
        uint32 ForbiddenAuraSpellId = 0;
        uint8 ChancePercent = 100;
    };
    std::vector<ResourceGain> QueryAbilityResourceGains(uint8 classId, uint32 resolvedSpellId);
}

#endif // ASCENSION_RESOURCE_QUERY_H
