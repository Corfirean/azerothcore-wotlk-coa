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

#include "SpellCandidateFilter.h"
#include <gtest/gtest.h>
#include <vector>

TEST(SpellCandidateFilter, PreservesAllBooleanResultsAndShortCircuitOrder)
{
    for (bool enabled : {false, true})
        for (bool known : {false, true})
            for (bool match : {false, true})
            {
                std::vector<unsigned> calls;
                bool accepted = SpellCandidateFilter::Accept(enabled,
                    [&] { calls.push_back(1); return known; },
                    [&] { calls.push_back(2); return match; });
                EXPECT_EQ(accepted, known && match);
                std::vector<unsigned> expected = enabled ? std::vector<unsigned>{2} : std::vector<unsigned>{1};
                if (enabled ? match : known) expected.push_back(enabled ? 1 : 2);
                EXPECT_EQ(calls, expected);
            }
}

TEST(SpellCandidateFilter, ChecksCurrentMembershipAndCopyFallbackEveryTime)
{
    bool active = true, copy = false, matches = true;
    auto known = [&] { return active || copy; };
    auto match = [&] { return matches; };
    EXPECT_TRUE(SpellCandidateFilter::Accept(true, known, match));
    active = false;
    EXPECT_FALSE(SpellCandidateFilter::Accept(true, known, match));
    copy = true;
    EXPECT_TRUE(SpellCandidateFilter::Accept(true, known, match));
    matches = false;
    EXPECT_FALSE(SpellCandidateFilter::Accept(true, known, match));
}

TEST(SpellCandidateFilter, AvoidsMembershipQueriesOnlyForUnrelatedCandidates)
{
    unsigned queries = 0;
    for (unsigned id = 0; id < 1000; ++id)
        SpellCandidateFilter::Accept(true, [&] { ++queries; return true; }, [&] { return id == 507; });
    EXPECT_EQ(queries, 1u);
    queries = 0;
    for (unsigned id = 0; id < 1000; ++id)
        SpellCandidateFilter::Accept(false, [&] { ++queries; return true; }, [&] { return id == 507; });
    EXPECT_EQ(queries, 1000u);
}
