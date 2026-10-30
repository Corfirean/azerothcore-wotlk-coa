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

#include "CoaPluginAbiCheck.h"

#ifdef COA_PLUGIN_HOST

CoaAbiCheckScratch CoaAbiScratch = { COA_ABI_CHECK_MAGIC, 0, 0 };

std::size_t CoaAbiCheckHostEntries(CoaAbiCheckEntry* out, std::size_t capacity)
{
    std::size_t n;
    COA_ABI_CHECK_FILL(out, capacity, n);
    return n;
}

#endif
