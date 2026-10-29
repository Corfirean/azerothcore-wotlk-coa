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

#ifndef _FIXTURE_GUARD_H_
#define _FIXTURE_GUARD_H_

#ifdef COA_PLUGIN_HOST

namespace Acore::Plugins
{
    /// Test fixtures only. When Fixture.ExpectedServerUuid is set, every configured database
    /// (as finally resolved, environment overrides included) must answer with that @@server_uuid
    /// before any pool is opened or any update is applied. False = do not start.
    bool CheckFixtureDatabaseIdentity();
}

#endif

#endif // _FIXTURE_GUARD_H_
