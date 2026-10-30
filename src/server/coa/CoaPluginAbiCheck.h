/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _COA_PLUGIN_ABI_CHECK_H_
#define _COA_PLUGIN_ABI_CHECK_H_

#ifdef COA_PLUGIN_HOST

// Test support for the plugin boundary. The host and a test plugin evaluate the same list of
// data symbols; the plugin compares its view (through dllimport) with the host's, entry by
// entry, and writes to CoaAbiScratch so the host can check the write landed in its own object.

#include "AscensionCoATalentData.h"
#include "DBCStores.h"
#include "LootMgr.h"
#include "Opcodes.h"
#include "RaceMgr.h"
#include "ReputationMgr.h"
#include "ScriptMgr.h"
#include "World.h"
#include <cstddef>
#include <cstdint>

struct CoaAbiCheckEntry
{
    char const* name;
    void const* address; // nullptr for value-only entries
    uint64_t value;
};

struct CoaAbiCheckScratch
{
    uint32_t magic;     // set by the host
    uint32_t writes;    // incremented by the plugin
    uint64_t lastValue; // written by the plugin
};

constexpr uint32_t COA_ABI_CHECK_MAGIC = 0xC0A1AB1Cu;

AC_GAME_API extern CoaAbiCheckScratch CoaAbiScratch;

/// Fills `out` with the host's view; returns the number of entries (at most `capacity`).
AC_GAME_API std::size_t CoaAbiCheckHostEntries(CoaAbiCheckEntry* out, std::size_t capacity);

// ADDR(symbol): the object's address. VALUE(name, expression): a value read through an accessor
// (private statics such as World::_stopEvent or RaceMgr::_maxRaces).
#define COA_ABI_CHECK_LIST(ADDR, VALUE)                                   \
    ADDR(sMapStore)                                                       \
    ADDR(sSpellStore)                                                     \
    ADDR(sChrRacesStore)                                                  \
    ADDR(sChrClassesStore)                                                \
    ADDR(sTalentStore)                                                    \
    ADDR(sFactionStore)                                                   \
    ADDR(sItemSetStore)                                                   \
    ADDR(sTaxiNodesMask)                                                  \
    ADDR(sTaxiPathSetBySource)                                            \
    ADDR(LootTemplates_Creature)                                          \
    ADDR(LootTemplates_Item)                                              \
    ADDR(LootTemplates_Reference)                                         \
    ADDR(opcodeTable)                                                     \
    ADDR(ReputationMgr::PointsInRank)                                     \
    ADDR(ReputationMgr::Reputation_Cap)                                   \
    ADDR(AscensionCompatData::CoATalentEntries)                           \
    ADDR(AscensionCompatData::CoASelectableFreeEntries)                   \
    ADDR(ScriptRegistry<PlayerScript>::ScriptPointerList)                 \
    ADDR(ScriptRegistry<WorldScript>::ScriptPointerList)                  \
    ADDR(ScriptRegistry<UnitScript>::ScriptPointerList)                   \
    ADDR(CoaAbiScratch)                                                   \
    VALUE(World_IsStopped, World::IsStopped())                            \
    VALUE(World_GetExitCode, World::GetExitCode())                        \
    VALUE(RaceMgr_GetMaxRaces, RaceMgr::GetMaxRaces())                    \
    VALUE(RaceMgr_GetAllianceRaceMask, RaceMgr::GetAllianceRaceMask())    \
    VALUE(sMapStore_rows, sMapStore.GetNumRows())                         \
    VALUE(sSpellStore_rows, sSpellStore.GetNumRows())                     \
    VALUE(CoATalentEntries_size, AscensionCompatData::CoATalentEntries.size()) \
    VALUE(Reputation_Cap, ReputationMgr::Reputation_Cap)                  \
    VALUE(PointsInRank_0, ReputationMgr::PointsInRank[0])

/// Expands to code that fills `out` (array of `capacity`) and leaves the count in `n`.
#define COA_ABI_CHECK_FILL(out, capacity, n)                                                             \
    do                                                                                                    \
    {                                                                                                     \
        n = 0;                                                                                            \
        auto add = [&](char const* name, void const* address, uint64_t value)                            \
        {                                                                                                 \
            if (n < (capacity))                                                                           \
                (out)[n++] = CoaAbiCheckEntry{ name, address, value };                                    \
        };                                                                                                \
        COA_ABI_CHECK_LIST(COA_ABI_CHECK_ADDR_, COA_ABI_CHECK_VALUE_)                                     \
    } while (false)
#define COA_ABI_CHECK_ADDR_(symbol) add(#symbol, static_cast<void const*>(&symbol), 0);
#define COA_ABI_CHECK_VALUE_(name, expression) add(#name, nullptr, static_cast<uint64_t>(expression));

#endif

#endif // _COA_PLUGIN_ABI_CHECK_H_
