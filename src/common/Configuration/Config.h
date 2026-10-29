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

#ifndef CONFIG_H
#define CONFIG_H

#include "Define.h"
#include <cstdint>
#include <stdexcept>
#include <string_view>
#include <vector>

enum class ConfigSeverity : uint8_t
{
    Skip,
    Warn,
    Error,
    Fatal
};

struct ConfigPolicy
{
    ConfigSeverity defaultSeverity = ConfigSeverity::Warn;
    ConfigSeverity missingFileSeverity = ConfigSeverity::Error;
    ConfigSeverity missingOptionSeverity = ConfigSeverity::Warn;
    ConfigSeverity criticalOptionSeverity = ConfigSeverity::Fatal;
    ConfigSeverity unknownOptionSeverity = ConfigSeverity::Error;
    ConfigSeverity valueErrorSeverity = ConfigSeverity::Error;
};

class AC_COMMON_API ConfigMgr
{
    ConfigMgr() = default;
    ConfigMgr(ConfigMgr const&) = delete;
    ConfigMgr& operator=(ConfigMgr const&) = delete;
    ~ConfigMgr() = default;

public:
    bool LoadAppConfigs(bool isReload = false);
    bool LoadModulesConfigs(bool isReload = false, bool isNeedPrintInfo = true);
    void Configure(std::string const& initFileName, std::vector<std::string> args, std::string_view modulesConfigList = {}, ConfigPolicy policy = {});

    static ConfigMgr* instance();

    /// Adds a module config (plain file name in configs/modules/) that was not known at
    /// compile time, e.g. one declared by a plugin. Must be called before LoadModulesConfigs().
    /// Returns false for a duplicate or a name containing a path.
    bool AddModuleConfigFile(std::string const& fileName);

    bool Reload();

    /// Overrides configuration with environment variables and returns overridden keys
    std::vector<std::string> OverrideWithEnvVariablesIfAny();

    std::string const GetFilename();
    std::string const GetConfigPath();
    [[nodiscard]] std::vector<std::string> const& GetArguments() const;
    std::vector<std::string> GetKeysByString(std::string const& name);

    template<class T>
    T GetOption(std::string const& name, T const& def, bool showLogs = true) const;

    bool isDryRun() { return dryRun; }
    void setDryRun(bool mode) { dryRun = mode; }

private:
    /// Method used only for loading main configuration files (authserver.conf and worldserver.conf)
    bool LoadInitial(std::string const& file, bool isReload = false);
    bool LoadAdditionalFile(std::string file, bool isOptional = false, bool isReload = false);

    template<class T>
    T GetValueDefault(std::string const& name, T const& def, bool showLogs = true) const;

    bool dryRun = false;

    std::vector<std::string /*config variant*/> _moduleConfigFiles;
};

class ConfigException : public std::length_error
{
public:
    explicit ConfigException(std::string const& message) : std::length_error(message) { }
};

template<>
AC_COMMON_API bool ConfigMgr::GetOption<bool>(std::string const& name, bool const& def, bool showLogs) const;

#define sConfigMgr ConfigMgr::instance()

#endif
