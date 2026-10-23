/* Copyright (C) 2016+ AzerothCore, GNU AGPL v3. */
#ifndef COA_CREATURE_SCALING_H
#define COA_CREATURE_SCALING_H

class Creature;

namespace CreatureScaling
{
// Says who scales a dungeon or raid creature. A module that builds the combat budget of those creatures itself
// registers, once at script load, a predicate that tells whether it owns a given creature. For an owned creature the
// Dungeon, Raid and Map* health and damage multipliers are neutral (1.0), so they never stack on the module's budget.
// The predicate is asked at the moment of scaling, so the outcome does not depend on script registration order. With
// no predicate registered, or when it answers false, CoA.CreatureScaling behaves as configured. Open world creatures
// are never handed over.
using CombatAuthority = bool (*)(Creature const* creature);
void SetCombatAuthority(CombatAuthority authority);

float HealthMultiplier(Creature const* creature);

class TestOverride
{
public:
    TestOverride();
    ~TestOverride();
    TestOverride(TestOverride const&) = delete;
    TestOverride& operator=(TestOverride const&) = delete;
};
}

#endif
