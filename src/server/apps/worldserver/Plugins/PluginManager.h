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

#ifndef _PLUGIN_MANAGER_H_
#define _PLUGIN_MANAGER_H_

#ifdef COA_PLUGIN_HOST

#define COA_PLUGIN_HOST_ONLY
#include "CoaPluginApi.h"
#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

// Startup/shutdown-only native plugin loader (spike). Plugins are never unloaded: their images
// stay mapped until the process exits. The only input is plugins/plugins.lock written by the
// manager; the plugins directory is never scanned.
namespace Acore::Plugins
{
    enum class State
    {
        Listed,
        Rejected,       // failed a check before LoadLibrary
        LoadFailed,
        Registered,
        RegisterFailed,
        Started,
        StartupFailed,
        Faulted,
        Stopped
    };

    char const* StateName(State state);

    struct Plugin
    {
        std::string id;
        std::filesystem::path path;
        std::string sha256;
        bool required = true;
        std::vector<std::string> configFiles;
        std::vector<std::string> dependsOn;

        State state = State::Listed;
        std::string reason;
        std::vector<std::string> imports;
        void* module = nullptr;
        uintptr_t imageBegin = 0;
        uintptr_t imageEnd = 0;
        CoaPluginDescriptor const* descriptor = nullptr;
        bool stopping = false;
        bool drained = false;
        bool finalized = false;
        double loadMs = 0;
    };

    class PluginManager
    {
    public:
        static PluginManager* instance();

        /// <directory of worldserver.exe>/plugins
        static std::filesystem::path DefaultDirectory();

        /// Before LoadModulesConfigs: reads the lock file, checks every plugin without loading
        /// it and registers the config files of the accepted ones. False = do not start.
        bool Prepare(std::filesystem::path const& pluginsDir);

        /// Inside ScriptMgr::Initialize (modules loader): load images and register scripts.
        void LoadAndRegister();

        /// PluginsReady: after SetInitialWorldSettings, before the world socket opens.
        bool StartAll();

        /// After WorldScript::OnStartup, before the realm is announced.
        bool HealthyAfterStartup() const;

        void Stopping();
        void DrainBeforeDbClose();
        void Finalize();

        bool IsPluginAddress(void const* address, Plugin const** owner = nullptr) const;
        bool HasFailure() const { return _failed; }
        void WriteReport(char const* phase) const;
        void LogHostAddresses() const;

    private:
        bool ReadLock(std::filesystem::path const& lockFile);
        bool CheckBeforeLoad(Plugin& plugin) const;
        bool ResolveOrder();
        void Fail(Plugin& plugin, State state, std::string reason);
        void Unlink(Plugin& plugin, bool deleteScripts);
        bool RunPhase(Plugin& plugin, char const* phase, CoaPluginStatus (*fn)());

        std::filesystem::path _dir;
        std::vector<Plugin> _plugins; // in load order after ResolveOrder()
        bool _failed = false;
        std::string _phase = "none";
    };
}

#define sPluginMgr Acore::Plugins::PluginManager::instance()

#endif // COA_PLUGIN_HOST

#endif // _PLUGIN_MANAGER_H_
