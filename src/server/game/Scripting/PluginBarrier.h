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

#ifndef _PLUGIN_BARRIER_H_
#define _PLUGIN_BARRIER_H_

#include "Define.h"

#ifdef COA_PLUGIN_HOST

#include <atomic>
#include <exception>

namespace Acore::Plugins
{
    /// Decides whether an exception thrown by a hook belongs to a plugin. Returns true when
    /// it did and was handled (the plugin is marked faulted and the world is being stopped);
    /// false means the script belongs to the host and the exception must propagate as before.
    using FaultHandler = bool (*)(void const* script, char const* hook, std::exception_ptr error);

    AC_GAME_API void SetFaultHandler(FaultHandler handler);
    AC_GAME_API bool HandleFault(void const* script, char const* hook, std::exception_ptr error);

    /// Set once any plugin has faulted; until then dispatch pays only for this load.
    AC_GAME_API extern std::atomic<bool> AnyFaulted;

    /// True for scripts of a faulted plugin: they are skipped for the rest of the process
    /// (including the shutdown path), without touching the registries during dispatch.
    using SuppressHandler = bool (*)(void const* script);
    AC_GAME_API void SetSuppressHandler(SuppressHandler handler);
    AC_GAME_API bool IsSuppressed(void const* script);

    /// Lets plugin code refuse to continue (e.g. from WorldScript::OnStartup) without throwing.
    using FatalHandler = void (*)(void const* caller, char const* reason);
    AC_GAME_API void SetFatalHandler(FatalHandler handler);
    AC_GAME_API void ReportFatal(void const* caller, char const* reason);
}

namespace Acore::Plugins
{
    /// Guarded call for hand-written dispatch loops that use the hook's return value: a plugin
    /// script that throws (or belongs to a faulted plugin) yields `fallback`.
    template<typename R, typename Fn>
    R Guarded(void const* script, char const* hook, R fallback, Fn&& fn)
    {
        if (AnyFaulted.load(std::memory_order_relaxed) && IsSuppressed(script))
            return fallback;
        try
        {
            return fn();
        }
        catch (...)
        {
            if (!HandleFault(script, hook, std::current_exception()))
                throw;
            return fallback;
        }
    }
}

#define COA_PLUGIN_CALL(script, hook, fallback, expr) \
    Acore::Plugins::Guarded(script, hook, fallback, [&]() { return (expr); })

#define COA_PLUGIN_SKIP(script) \
    (Acore::Plugins::AnyFaulted.load(std::memory_order_relaxed) && Acore::Plugins::IsSuppressed(script))

#define COA_PLUGIN_GUARD(script, hook, action) \
    if (!COA_PLUGIN_SKIP(script)) \
    { \
        try { action; } \
        catch (...) { if (!Acore::Plugins::HandleFault(script, hook, std::current_exception())) throw; } \
    }

#define COA_PLUGIN_GUARD_BOOL(script, hook, expr) \
    ([&]() -> bool \
    { \
        if (COA_PLUGIN_SKIP(script)) \
            return false; \
        try { return static_cast<bool>(expr); } \
        catch (...) { if (!Acore::Plugins::HandleFault(script, hook, std::current_exception())) throw; return false; } \
    }())

#else

#define COA_PLUGIN_GUARD(script, hook, action) action;
#define COA_PLUGIN_GUARD_BOOL(script, hook, expr) (expr)
#define COA_PLUGIN_CALL(script, hook, fallback, expr) (expr)

#endif

#endif // _PLUGIN_BARRIER_H_
