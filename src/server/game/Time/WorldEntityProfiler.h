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

#ifndef WORLD_ENTITY_PROFILER_H
#define WORLD_ENTITY_PROFILER_H

#include "Config.h"
#include "UpdateTime.h"
#include <algorithm>
#include <memory>

namespace WorldEntityProfiler
{
    inline std::unique_ptr<WorldUpdateTime::PhaseScope> Sample(char const* name)
    {
        static uint32 const rate = []
        {
            uint32 configured = sConfigMgr->GetOption<uint32>("World.Performance.EntitySampleRate", 0);
            return configured ? std::clamp(configured, 64u, 65536u) : 0u;
        }();
        if (!rate) return {};
        thread_local uint32 state = 0x9e3779b9u;
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        if (state % rate) return {};
        return std::unique_ptr<WorldUpdateTime::PhaseScope>(
            new WorldUpdateTime::PhaseScope(sWorldUpdateTime.MeasurePhase(name)));
    }
}

#endif
