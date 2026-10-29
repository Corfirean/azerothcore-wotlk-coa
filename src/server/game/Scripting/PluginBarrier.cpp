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

#include "PluginBarrier.h"

#ifdef COA_PLUGIN_HOST

std::atomic<bool> Acore::Plugins::AnyFaulted{ false };

namespace
{
    std::atomic<Acore::Plugins::SuppressHandler> _suppressHandler{ nullptr };
    std::atomic<Acore::Plugins::FaultHandler> _faultHandler{ nullptr };
    std::atomic<Acore::Plugins::FatalHandler> _fatalHandler{ nullptr };
}

void Acore::Plugins::SetFaultHandler(FaultHandler handler)
{
    _faultHandler = handler;
}

bool Acore::Plugins::HandleFault(void const* script, char const* hook, std::exception_ptr error)
{
    FaultHandler handler = _faultHandler;
    return handler && handler(script, hook, error);
}

void Acore::Plugins::SetSuppressHandler(SuppressHandler handler)
{
    _suppressHandler = handler;
}

bool Acore::Plugins::IsSuppressed(void const* script)
{
    SuppressHandler handler = _suppressHandler;
    return handler && handler(script);
}

void Acore::Plugins::SetFatalHandler(FatalHandler handler)
{
    _fatalHandler = handler;
}

void Acore::Plugins::ReportFatal(void const* caller, char const* reason)
{
    if (FatalHandler handler = _fatalHandler)
        handler(caller, reason);
}

#endif
