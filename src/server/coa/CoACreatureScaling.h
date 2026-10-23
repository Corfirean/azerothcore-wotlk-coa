/* Copyright (C) 2016+ AzerothCore, GNU AGPL v3. */
#ifndef COA_CREATURE_SCALING_H
#define COA_CREATURE_SCALING_H

class Creature;

namespace CreatureScaling
{
using CombatAuthority = bool (*)(Creature const* creature);
void SetCombatAuthority(CombatAuthority authority);

void SetHealthBudgetAuthority(CombatAuthority authority);

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
