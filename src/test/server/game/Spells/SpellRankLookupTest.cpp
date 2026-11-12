/*
 * This file is part of the AzerothCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "SpellRankLookup.h"
#include "SpellInfoTestHelper.h"
#include <gtest/gtest.h>
#include <limits>

TEST(SpellRankLookup, NativeAndDirectAgreeAcrossReloadAndMissingMetadata)
{
    auto first = SpellInfoBuilder().WithId(1).BuildUnique();
    auto last = SpellInfoBuilder().WithId(2).BuildUnique();
    auto standalone = SpellInfoBuilder().WithId(3).BuildUnique();
    SpellInfoMap store{nullptr, first.get(), last.get(), standalone.get()};
    SpellChainMap chains;
    auto populate = [&]
    {
        chains[1] = {nullptr, last.get(), first.get(), last.get(), 1};
        chains[2] = {first.get(), nullptr, first.get(), last.get(), 2};
        first->ChainEntry = &chains.at(1);
        last->ChainEntry = &chains.at(2);
    };
    auto compare = [&]
    {
        EXPECT_FALSE(SpellRankLookup::FirstInconsistent(store, chains));
        for (uint32 id : {0u, 1u, 2u, 3u, 4u, std::numeric_limits<uint32>::max()})
            EXPECT_EQ(SpellRankLookup::Find(store, chains, id, true),
                SpellRankLookup::Find(store, chains, id, false));
    };
    populate();
    compare();
    EXPECT_EQ(SpellRankLookup::Find(store, chains, 1, true)->last, last.get());
    first->ChainEntry = nullptr;
    EXPECT_EQ(SpellRankLookup::FirstInconsistent(store, chains), 1u);
    first->ChainEntry = &chains.at(1);
    store[2] = nullptr;
    EXPECT_EQ(SpellRankLookup::FirstInconsistent(store, chains), 2u);
    store[2] = last.get();
    standalone->ChainEntry = first->ChainEntry;
    EXPECT_EQ(SpellRankLookup::FirstInconsistent(store, chains), 3u);
    standalone->ChainEntry = nullptr;
    first->ChainEntry = last->ChainEntry = nullptr;
    chains.clear();
    compare();
    populate();
    compare();
    first->ChainEntry = last->ChainEntry = nullptr;
}
