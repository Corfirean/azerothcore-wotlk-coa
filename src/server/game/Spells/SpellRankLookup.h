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

#ifndef SPELL_RANK_LOOKUP_H
#define SPELL_RANK_LOOKUP_H

#include "SpellInfo.h"
#include "SpellMgr.h"
#include <optional>
#define COA_SPELL_RANK_METADATA_EPOCH 1

namespace SpellRankLookup
{
    AC_GAME_API uint64 MetadataEpoch();
    AC_GAME_API void MetadataChanged();

    inline SpellChainNode const* Find(SpellInfoMap const& store, SpellChainMap const& chains, uint32 id, bool direct)
    {
        if (direct)
            return id < store.size() && store[id] ? store[id]->ChainEntry : nullptr;
        auto itr = chains.find(id);
        return itr != chains.end() ? &itr->second : nullptr;
    }

    inline std::optional<uint32> FirstInconsistent(SpellInfoMap const& store, SpellChainMap const& chains)
    {
        for (auto const& [id, node] : chains)
            if (id >= store.size() || !store[id] || store[id]->ChainEntry != &node)
                return id;
        for (uint32 id = 0; id < store.size(); ++id)
            if (store[id] && store[id]->ChainEntry && Find(store, chains, id, false) != store[id]->ChainEntry)
                return id;
        return std::nullopt;
    }
}

#endif
