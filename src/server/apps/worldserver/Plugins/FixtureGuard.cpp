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

#include "FixtureGuard.h"

#ifdef COA_PLUGIN_HOST

#include "Config.h"
#include "Log.h"
#include "MySQLWorkaround.h"
#include "Tokenize.h"
#include <cstdlib>
#include <string>
#include <vector>

namespace
{
    // Returns the server_uuid behind one "host;port;user;password;database" setting, or "" on failure.
    std::string ServerUuidOf(std::string const& info)
    {
        std::vector<std::string_view> parts = Acore::Tokenize(info, ';', true);
        if (parts.size() < 5)
            return "";

        std::string const host(parts[0]), port(parts[1]), user(parts[2]), password(parts[3]);
        MYSQL* mysql = mysql_init(nullptr);
        if (!mysql)
            return "";

        std::string uuid;
        unsigned int const portNumber = static_cast<unsigned int>(std::strtoul(port.c_str(), nullptr, 10));
        if (mysql_real_connect(mysql, host.c_str(), user.c_str(), password.c_str(), nullptr, portNumber, nullptr, 0)
            && !mysql_query(mysql, "SELECT @@server_uuid"))
        {
            if (MYSQL_RES* result = mysql_store_result(mysql))
            {
                if (MYSQL_ROW row = mysql_fetch_row(result))
                    uuid = row[0] ? row[0] : "";
                mysql_free_result(result);
            }
        }
        mysql_close(mysql);
        return uuid;
    }
}

bool Acore::Plugins::CheckFixtureDatabaseIdentity()
{
    std::string const expected = sConfigMgr->GetOption<std::string>("Fixture.ExpectedServerUuid", "", false);
    if (expected.empty())
        return true;

    for (char const* key : { "LoginDatabaseInfo", "WorldDatabaseInfo", "CharacterDatabaseInfo" })
    {
        std::string const actual = ServerUuidOf(sConfigMgr->GetOption<std::string>(key, ""));
        if (actual != expected)
        {
            LOG_FATAL("server.plugins", "Fixture guard: {} answered server_uuid '{}', expected '{}'. Refusing to start before touching any database.",
                key, actual, expected);
            return false;
        }
    }

    LOG_INFO("server.plugins", "Fixture guard: all databases are on server {}.", expected);
    return true;
}

#endif
