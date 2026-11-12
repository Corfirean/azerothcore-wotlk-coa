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

#include "InterleavedUpdateClock.h"
#include <gtest/gtest.h>
#include <array>

TEST(InterleavedUpdateClock, SpreadsSteadyWorkAndPreservesElapsedTime)
{
    InterleavedUpdateClock clock;
    std::array<unsigned, 3> calls{}, elapsed{};
    for (unsigned frame = 0; frame < 30; ++frame)
    {
        clock.Advance(10, frame % 3 == 0);
        unsigned steadyCalls = 0;
        for (unsigned key = 0; key < 3; ++key)
            if (auto diff = clock.Due(key, key))
            {
                ++calls[key]; elapsed[key] += *diff;
                if (frame >= 3) { ++steadyCalls; EXPECT_EQ(*diff, 30u); }
                EXPECT_FALSE(clock.Due(key, key));
            }
        if (frame >= 3) EXPECT_EQ(steadyCalls, 1u);
    }
    EXPECT_TRUE(clock.Compatible());
    EXPECT_EQ(elapsed[0], 280u);
    EXPECT_EQ(elapsed[1], 290u);
    EXPECT_EQ(elapsed[2], 300u);
}

TEST(InterleavedUpdateClock, DoesNotUpdateDuringIdleCycleAndHandlesLifecycle)
{
    InterleavedUpdateClock clock;
    clock.Advance(10, true);
    EXPECT_EQ(clock.Due(5, 5), 10u);
    clock.Advance(10, false); clock.Advance(10, false); clock.Advance(10, false);
    EXPECT_FALSE(clock.HasWork());
    EXPECT_FALSE(clock.Due(5, 5));
    clock.Forget(5);
    EXPECT_EQ(clock.Size(), 0u);
    clock.Advance(10, true);
    EXPECT_EQ(clock.Due(5, 8), 10u);
    clock.Advance(10, false);
    EXPECT_EQ(clock.Due(5, 11), 10u);
}

TEST(InterleavedUpdateClock, RejectsUnexpectedFullUpdateCadence)
{
    InterleavedUpdateClock clock;
    clock.Advance(10, true);
    clock.Advance(10, true);
    EXPECT_FALSE(clock.Compatible());
    EXPECT_FALSE(clock.HasWork());
}

TEST(InterleavedUpdateClock, IrregularTicksDoNotLoseOrReplayElapsedTime)
{
    InterleavedUpdateClock clock;
    std::array<unsigned, 3> elapsed{};
    unsigned time = 0;
    for (unsigned frame = 0; frame < 60; ++frame)
    {
        unsigned diff = 1 + (frame * 73) % 250;
        time += diff;
        clock.Advance(diff, frame % 3 == 0);
        for (unsigned key = 0; key < 3; ++key)
            if (auto due = clock.Due(key, key))
            {
                elapsed[key] += *due;
                EXPECT_EQ(elapsed[key], time);
                EXPECT_FALSE(clock.Due(key, key));
            }
    }
    EXPECT_TRUE(clock.Compatible());
}
