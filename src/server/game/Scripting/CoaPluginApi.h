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

#ifndef _COA_PLUGIN_API_H_
#define _COA_PLUGIN_API_H_

// The only C boundary between worldserver and a plugin. Everything else a plugin does goes
// through the exported C++ API of the exact host build named by COA_PLUGIN_ABI_FINGERPRINT.
// Exceptions never cross these entry points: COA_PLUGIN_DEFINE wraps every call.

#include "CoaPluginAbi.h"
#include <cstdint>

#define COA_PLUGIN_API_VERSION 1u
#define COA_PLUGIN_FINGERPRINT_LENGTH 64
#define COA_PLUGIN_ERROR_LENGTH 512

enum CoaPluginStatus : uint32_t
{
    COA_PLUGIN_OK        = 0,
    COA_PLUGIN_FAILED    = 1, // the plugin reported a failure
    COA_PLUGIN_EXCEPTION = 2  // an exception was caught at the entry point
};

extern "C"
{
    struct CoaPluginDescriptor
    {
        uint32_t structSize;
        uint32_t apiVersion;
        char const* id;
        char const* version;
        char const* abiFingerprint;
        // Startup, in this order. Only registerScripts is mandatory.
        CoaPluginStatus (*registerScripts)();      // inside ScriptMgr::Initialize
        CoaPluginStatus (*onStartup)();            // PluginsReady: before the world socket opens
        // Shutdown, reverse dependency order; only for plugins whose onStartup succeeded.
        void (*onStopping)();                      // hooks still run: stop taking new work
        CoaPluginStatus (*onDrainBeforeDbClose)(); // join own threads, flush DB work
        void (*onFinalize)();                      // after ScriptMgr::Unload: no hook can run
        char const* (*lastError)();
    };

    typedef CoaPluginDescriptor const* (*CoaPluginQueryFn)();
}

#define COA_PLUGIN_QUERY_SYMBOL "CoaPluginQuery"
#define COA_PLUGIN_SECTION ".coapl"

#ifndef COA_PLUGIN_HOST_ONLY

#include <cstdio>
#include <exception>

#if defined(_MSC_VER)
#  define COA_PLUGIN_EXPORT extern "C" __declspec(dllexport)
#  pragma section(".coapl", read)
#  define COA_PLUGIN_SECTION_ATTR __declspec(allocate(".coapl"))
#  define COA_PLUGIN_KEEP_SECTION __pragma(comment(linker, "/INCLUDE:CoaPluginAbiSection"))
#else
#  define COA_PLUGIN_EXPORT extern "C" __attribute__((visibility("default")))
#  define COA_PLUGIN_SECTION_ATTR __attribute__((section(".note.coa.plugin"), used))
#  define COA_PLUGIN_KEEP_SECTION
#endif

namespace CoaPluginDetail
{
    inline char g_lastError[COA_PLUGIN_ERROR_LENGTH] = {};

    inline void SetError(char const* text)
    {
        std::snprintf(g_lastError, sizeof(g_lastError), "%s", text ? text : "");
    }

    template<typename Fn>
    CoaPluginStatus Guard(Fn&& fn) noexcept
    {
        try
        {
            return fn() ? COA_PLUGIN_OK : COA_PLUGIN_FAILED;
        }
        catch (std::exception const& e)
        {
            SetError(e.what());
        }
        catch (...)
        {
            SetError("unknown exception");
        }
        return COA_PLUGIN_EXCEPTION;
    }

    inline char const* LastError() { return g_lastError; }

    template<bool (*Reg)(), bool (*Startup)(), void (*Stopping)(), bool (*Drain)(), void (*Finalize)()>
    struct Entry
    {
        static CoaPluginStatus Register() { return Guard([] { return Reg(); }); }
        static CoaPluginStatus OnStartup() { return Guard([] { return Startup(); }); }
        static void OnStopping() { Guard([] { Stopping(); return true; }); }
        static CoaPluginStatus OnDrain() { return Guard([] { return Drain(); }); }
        static void OnFinalize() { Guard([] { Finalize(); return true; }); }
    };
}

/// Defines the plugin entry point. All five callbacks are plain functions and are required:
///   bool reg(); bool startup(); void stopping(); bool drain(); void finalize();
/// The bool-returning ones report failure by returning false (CoaPluginDetail::SetError gives
/// the reason). Exceptions are caught here and reported as COA_PLUGIN_EXCEPTION.
#define COA_PLUGIN_DEFINE(ID, VERSION, REG, STARTUP, STOPPING, DRAIN, FINALIZE)                       \
    COA_PLUGIN_KEEP_SECTION extern "C" COA_PLUGIN_SECTION_ATTR char const CoaPluginAbiSection[] =                               \
        "COAPLUGIN1|" ID "|" COA_PLUGIN_ABI_FINGERPRINT;                                              \
    namespace                                                                                         \
    {                                                                                                 \
        using CoaEntry = CoaPluginDetail::Entry<&REG, &STARTUP, &STOPPING, &DRAIN, &FINALIZE>;        \
        CoaPluginDescriptor const CoaDescriptor = {                                                   \
            sizeof(CoaPluginDescriptor), COA_PLUGIN_API_VERSION, ID, VERSION,                         \
            COA_PLUGIN_ABI_FINGERPRINT, &CoaEntry::Register, &CoaEntry::OnStartup,                    \
            &CoaEntry::OnStopping, &CoaEntry::OnDrain, &CoaEntry::OnFinalize,                         \
            &CoaPluginDetail::LastError };                                                            \
    }                                                                                                 \
    COA_PLUGIN_EXPORT CoaPluginDescriptor const* CoaPluginQuery() noexcept { return &CoaDescriptor; }

#endif // COA_PLUGIN_HOST_ONLY

#endif // _COA_PLUGIN_API_H_
