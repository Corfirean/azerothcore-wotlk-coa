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

#ifndef INTERLEAVED_UPDATE_CLOCK_H
#define INTERLEAVED_UPDATE_CLOCK_H

#define COA_INTERLEAVED_WORLD_UPDATES 1
#include <algorithm>
#include <cstdint>
#include <limits>
#include <optional>
#include <unordered_map>

class InterleavedUpdateClock
{
public:
    void Advance(std::uint32_t diff, bool full)
    {
        _time += diff;
        _diff = diff;
        if (full)
        {
            if (_started && _phase < 2) _compatible = false;
            _started = true;
            _phase = 0;
        }
        else if (_started && _phase < 3) ++_phase;
    }

    bool Compatible() const { return _compatible; }
    bool Started() const { return _started; }
    bool HasWork() const { return _started && _compatible && _phase < 3; }

    std::optional<std::uint32_t> Due(std::uintptr_t key, std::uint64_t identity)
    {
        if (!HasWork()) return std::nullopt;
        auto [itr, fresh] = _entries.try_emplace(key, Entry{identity, _time, unsigned(identity % 3)});
        if (!fresh && itr->second.identity != identity)
        {
            itr->second = Entry{identity, _time, unsigned(identity % 3)};
            fresh = true;
        }
        if (fresh) return _diff;
        if (!HasWork() || itr->second.phase != _phase || itr->second.last == _time) return std::nullopt;
        return Force(key);
    }

    std::uint32_t Force(std::uintptr_t key)
    {
        auto itr = _entries.find(key);
        if (itr == _entries.end()) return _diff;
        auto elapsed = std::min<std::uint64_t>(_time - itr->second.last, std::numeric_limits<std::uint32_t>::max());
        itr->second.last = _time;
        return std::uint32_t(elapsed);
    }

    void Forget(std::uintptr_t key) { _entries.erase(key); }
    std::size_t Size() const { return _entries.size(); }

private:
    struct Entry { std::uint64_t identity, last; unsigned phase; };
    std::unordered_map<std::uintptr_t, Entry> _entries;
    std::uint64_t _time = 0;
    std::uint32_t _diff = 0;
    unsigned _phase = 3;
    bool _started = false, _compatible = true;
};

#endif
