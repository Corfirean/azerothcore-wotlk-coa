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

#include "SpellBookRevision.h"
#include "SpellRankLookup.h"
#include <gtest/gtest.h>

TEST(SpellBookRevision, StructuralChangesAdvancePerPlayerState)
{
    DataMap first, second;
    SpellBookRevision::EnableTracking();
    EXPECT_EQ(SpellBookRevision::Get(first), 0u);
    SpellBookRevision::Changed(first);
    auto learned = SpellBookRevision::Get(first);
    EXPECT_GT(learned, 0u);
    SpellBookRevision::Changed(first);
    EXPECT_GT(SpellBookRevision::Get(first), learned);
    EXPECT_EQ(SpellBookRevision::Get(second), 0u);
}

TEST(SpellBookRevision, MetadataChangesAdvanceSharedEpoch)
{
    auto before = SpellRankLookup::MetadataEpoch();
    SpellRankLookup::MetadataChanged();
    EXPECT_GT(SpellRankLookup::MetadataEpoch(), before);
}
