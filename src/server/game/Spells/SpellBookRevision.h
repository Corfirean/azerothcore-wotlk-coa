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

#ifndef SPELL_BOOK_REVISION_H
#define SPELL_BOOK_REVISION_H

#define COA_SPELL_BOOK_REVISION 1
#include "DataMap.h"
#include "Define.h"

namespace SpellBookRevision
{
    AC_GAME_API bool TrackingEnabled();
    AC_GAME_API void EnableTracking();
    struct State : DataMap::Base { uint64 value = 1; };

    inline uint64 Get(DataMap const& data)
    {
        auto state = data.Get<State>("spell_revision");
        return state ? state->value : 0;
    }

    inline void Changed(DataMap& data)
    {
        if (!TrackingEnabled()) return;
        ++data.GetDefault<State>("spell_revision")->value;
    }
}

#endif
