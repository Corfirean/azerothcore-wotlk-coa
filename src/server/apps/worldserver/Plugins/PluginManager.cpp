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

#include "PluginManager.h"

#ifdef COA_PLUGIN_HOST

#include "Config.h"
#include "CryptoHash.h"
#include "Log.h"
#include "PluginBarrier.h"
#include "CoaPluginAbiCheck.h"
#include "ScriptMgr.h"
#include "Tokenize.h"
#include "Util.h"
#include "World.h"
#include <algorithm>
#include <cctype>
#include <functional>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <fstream>
#include <map>
#include <mutex>
#include <set>
#include <sstream>
#include <thread>

#if AC_PLATFORM == AC_PLATFORM_WINDOWS
#include <windows.h>
#else
#error "The plugin host spike is Windows-only; the Linux loader is a separate track."
#endif

namespace fs = std::filesystem;
using namespace Acore::Plugins;

namespace
{
    // Process exit code used when a plugin phase hangs (see watchdog below).
    constexpr UINT PLUGIN_HANG_EXIT_CODE = 0xC0A1;

    std::string Lower(std::string text)
    {
        std::transform(text.begin(), text.end(), text.begin(), [](unsigned char c) { return char(std::tolower(c)); });
        return text;
    }

    bool ValidId(std::string const& id)
    {
        if (id.empty() || id.size() > 64)
            return false;
        return std::all_of(id.begin(), id.end(), [](char c) { return (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-'; });
    }

    std::vector<std::string> SplitList(std::string const& text)
    {
        std::vector<std::string> out;
        for (std::string_view item : Acore::Tokenize(text, ',', false))
            if (!item.empty())
                out.emplace_back(item);
        return out;
    }

    std::string JsonEscape(std::string const& text)
    {
        std::string out;
        for (char c : text)
        {
            switch (c)
            {
                case '"': out += "\\\""; break;
                case '\\': out += "\\\\"; break;
                case '\n': out += "\\n"; break;
                case '\r': out += "\\r"; break;
                default:
                    if (static_cast<unsigned char>(c) < 0x20)
                        out += ' ';
                    else
                        out += c;
            }
        }
        return out;
    }

    bool IsAllowedImport(std::string const& dll)
    {
        std::string const name = Lower(dll);
        static std::set<std::string> const allowed = {
            "worldserver.exe", "kernel32.dll", "vcruntime140.dll", "vcruntime140_1.dll",
            "msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll", "msvcp140_atomic_wait.dll", "ws2_32.dll" };
        return allowed.count(name) || name.rfind("api-ms-win-crt-", 0) == 0;
    }

    // Reads only the file bytes; nothing from the image is executed.
    struct PeInfo
    {
        bool ok = false;
        std::string error;
        std::string section; // contents of the .coapl section
        std::vector<std::string> imports;
        std::vector<std::string> hostSymbols; // names imported from worldserver.exe
        uint32_t sizeOfImage = 0;
    };

    PeInfo InspectPe(std::vector<uint8> const& file)
    {
        PeInfo info;
        auto fail = [&](char const* why) { info.error = why; return info; };

        auto read = [&](std::size_t offset, std::size_t size) -> uint8 const*
        {
            return offset <= file.size() && size <= file.size() - offset ? file.data() + offset : nullptr;
        };

        auto dos = reinterpret_cast<IMAGE_DOS_HEADER const*>(read(0, sizeof(IMAGE_DOS_HEADER)));
        if (!dos || dos->e_magic != IMAGE_DOS_SIGNATURE || dos->e_lfanew < 0)
            return fail("not a PE file");

        auto nt = reinterpret_cast<IMAGE_NT_HEADERS64 const*>(read(std::size_t(dos->e_lfanew), sizeof(IMAGE_NT_HEADERS64)));
        if (!nt || nt->Signature != IMAGE_NT_SIGNATURE)
            return fail("bad PE signature");
        if (nt->FileHeader.Machine != IMAGE_FILE_MACHINE_AMD64 || nt->OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC)
            return fail("not an x86_64 image");
        if (!(nt->FileHeader.Characteristics & IMAGE_FILE_DLL))
            return fail("not a DLL");

        info.sizeOfImage = nt->OptionalHeader.SizeOfImage;

        std::size_t const sectionsOffset = std::size_t(dos->e_lfanew) + offsetof(IMAGE_NT_HEADERS64, OptionalHeader) + nt->FileHeader.SizeOfOptionalHeader;
        uint16 const sectionCount = nt->FileHeader.NumberOfSections;
        auto sections = reinterpret_cast<IMAGE_SECTION_HEADER const*>(read(sectionsOffset, sizeof(IMAGE_SECTION_HEADER) * sectionCount));
        if (!sections)
            return fail("truncated section table");

        auto rvaToOffset = [&](uint32_t rva, std::size_t& offset) -> bool
        {
            for (uint16 i = 0; i < sectionCount; ++i)
            {
                IMAGE_SECTION_HEADER const& s = sections[i];
                uint32_t const size = std::max(s.Misc.VirtualSize, s.SizeOfRawData);
                if (rva >= s.VirtualAddress && rva < s.VirtualAddress + size)
                {
                    offset = std::size_t(s.PointerToRawData) + (rva - s.VirtualAddress);
                    return true;
                }
            }
            return false;
        };

        for (uint16 i = 0; i < sectionCount; ++i)
        {
            char name[IMAGE_SIZEOF_SHORT_NAME + 1] = {};
            std::memcpy(name, sections[i].Name, IMAGE_SIZEOF_SHORT_NAME);
            if (std::string(name) != COA_PLUGIN_SECTION)
                continue;

            uint32_t const size = std::min(sections[i].Misc.VirtualSize, sections[i].SizeOfRawData);
            auto data = read(sections[i].PointerToRawData, size);
            if (!data)
                return fail("truncated plugin section");
            info.section.assign(reinterpret_cast<char const*>(data), size);
            info.section.resize(std::strlen(info.section.c_str()));
        }

        IMAGE_DATA_DIRECTORY const& importDir = nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
        if (importDir.VirtualAddress)
        {
            std::size_t offset = 0;
            if (!rvaToOffset(importDir.VirtualAddress, offset))
                return fail("import directory outside sections");

            for (uint32_t n = 0; n < 4096; ++n)
            {
                auto desc = reinterpret_cast<IMAGE_IMPORT_DESCRIPTOR const*>(read(offset + n * sizeof(IMAGE_IMPORT_DESCRIPTOR), sizeof(IMAGE_IMPORT_DESCRIPTOR)));
                if (!desc)
                    return fail("truncated import directory");
                if (!desc->Name)
                    break;

                std::size_t nameOffset = 0;
                if (!rvaToOffset(desc->Name, nameOffset) || nameOffset >= file.size())
                    return fail("import name outside sections");

                std::size_t const end = std::min(file.size(), nameOffset + 260);
                auto const* begin = reinterpret_cast<char const*>(file.data() + nameOffset);
                info.imports.emplace_back(begin, strnlen(begin, end - nameOffset));
                if (_stricmp(info.imports.back().c_str(), "worldserver.exe") != 0)
                    continue;

                // Names this plugin needs from the host, checked against the host's exports before loading.
                std::size_t thunkOffset = 0;
                uint32_t const thunks = desc->OriginalFirstThunk ? desc->OriginalFirstThunk : desc->FirstThunk;
                if (!rvaToOffset(thunks, thunkOffset))
                    return fail("import lookup table outside sections");
                for (uint32_t t = 0; t < 65536; ++t)
                {
                    auto entry = reinterpret_cast<uint64_t const*>(read(thunkOffset + t * sizeof(uint64_t), sizeof(uint64_t)));
                    if (!entry)
                        return fail("truncated import lookup table");
                    if (!*entry)
                        break;
                    if (*entry & IMAGE_ORDINAL_FLAG64)
                    {
                        info.hostSymbols.push_back("#" + std::to_string(*entry & 0xFFFF));
                        continue;
                    }
                    std::size_t hintOffset = 0;
                    if (!rvaToOffset(uint32_t(*entry), hintOffset) || hintOffset + 2 >= file.size())
                        return fail("import name entry outside sections");
                    auto const* symbol = reinterpret_cast<char const*>(file.data() + hintOffset + 2);
                    info.hostSymbols.emplace_back(symbol, strnlen(symbol, std::min<std::size_t>(file.size() - hintOffset - 2, 4096)));
                }
            }
        }

        info.ok = true;
        return info;
    }

    bool HasReparsePoint(fs::path const& path, fs::path const& stopAt)
    {
        for (fs::path p = path; !p.empty() && p != stopAt.parent_path(); p = p.parent_path())
        {
            DWORD const attributes = GetFileAttributesW(p.c_str());
            if (attributes == INVALID_FILE_ATTRIBUTES)
                return true;
            if (attributes & FILE_ATTRIBUTE_REPARSE_POINT)
                return true;
            if (p == stopAt || p == p.parent_path())
                break;
        }
        return false;
    }

    // Watchdog for synchronous plugin calls. A hung call cannot be interrupted safely inside the
    // process. Before the realm is announced the whole process is terminated (nothing has been
    // served yet); during shutdown terminating would also skip saving every other player, so
    // there the hang is only reported.
    class PhaseWatchdog
    {
    public:
        PhaseWatchdog(std::string what, std::chrono::seconds limit, bool terminate = true) : _what(std::move(what))
        {
            _thread = std::thread([this, limit, terminate]
            {
                std::unique_lock<std::mutex> lock(_mutex);
                if (!_cv.wait_for(lock, limit, [this] { return _done; }))
                {
                    sPluginMgr->WriteReport(("hang:" + _what).c_str());
                    if (!terminate)
                    {
                        LOG_FATAL("server.plugins", "Plugin call '{}' has not returned after {}s; shutdown is blocked on it.", _what, limit.count());
                        return;
                    }
                    LOG_FATAL("server.plugins", "Plugin call '{}' did not return within {}s; terminating the process (no saving, no further hooks).", _what, limit.count());
                    sLog->SetSynchronous();
                    TerminateProcess(GetCurrentProcess(), PLUGIN_HANG_EXIT_CODE);
                }
            });
        }

        ~PhaseWatchdog()
        {
            {
                std::lock_guard<std::mutex> lock(_mutex);
                _done = true;
            }
            _cv.notify_all();
            _thread.join();
        }

    private:
        std::string _what;
        std::mutex _mutex;
        std::condition_variable _cv;
        bool _done = false;
        std::thread _thread;
    };

    std::chrono::seconds PhaseTimeout()
    {
        return std::chrono::seconds(std::max(1, sConfigMgr->GetOption<int32>("Plugins.PhaseTimeoutSeconds", 120)));
    }

    bool OnPluginFault(void const* script, char const* hook, std::exception_ptr error)
    {
        Plugin const* owner = nullptr;
        // The object's vtable lives in the image that defined the most derived class.
        void const* vtable = script ? *reinterpret_cast<void const* const*>(script) : nullptr;
        if (!sPluginMgr->IsPluginAddress(vtable, &owner))
            return false;

        std::string what = "unknown exception";
        try { std::rethrow_exception(error); }
        catch (std::exception const& e) { what = e.what(); }
        catch (...) { }

        LOG_FATAL("server.plugins", "Plugin '{}' threw from hook {}: {}. The plugin is marked faulted and the world is stopping.", owner->id, hook, what);
        const_cast<Plugin*>(owner)->state = State::Faulted;
        const_cast<Plugin*>(owner)->reason = std::string("exception in ") + hook + ": " + what;
        AnyFaulted = true;
        World::StopNow(ERROR_EXIT_CODE);
        sPluginMgr->WriteReport("fault");
        return true;
    }

    void MarkFaulted(Plugin& plugin, std::string reason)
    {
        plugin.state = State::Faulted;
        plugin.reason = std::move(reason);
        AnyFaulted = true;
        World::StopNow(ERROR_EXIT_CODE);
        sPluginMgr->WriteReport("fault");
    }

    class PluginFaultInjector : public WorldScript
    {
    public:
        PluginFaultInjector(std::string id, uint32 seconds)
            : WorldScript("plugin_fault_injector", { WORLDHOOK_ON_UPDATE }), _id(std::move(id)), _leftMs(seconds * IN_MILLISECONDS) { }

        void OnUpdate(uint32 diff) override
        {
            if (_done || (_leftMs > diff && (_leftMs -= diff)))
                return;
            _done = true;
            if (Plugin* plugin = sPluginMgr->FindPlugin(_id); plugin && plugin->state == State::Started)
            {
                LOG_FATAL("server.plugins", "Plugin '{}': fault injected by Plugins.Test.FaultPlugin; the world is stopping.", _id);
                MarkFaulted(*plugin, "injected fault (test)");
            }
        }

    private:
        std::string _id;
        uint32 _leftMs;
        bool _done = false;
    };

    bool ShouldSuppress(void const* script)
    {
        Plugin const* owner = nullptr;
        void const* vtable = script ? *reinterpret_cast<void const* const*>(script) : nullptr;
        return sPluginMgr->IsPluginAddress(vtable, &owner) && owner->state == State::Faulted;
    }

    void OnPluginFatal(void const* caller, char const* reason)
    {
        Plugin const* owner = nullptr;
        std::string const id = sPluginMgr->IsPluginAddress(caller, &owner) ? owner->id : std::string("<host>");
        LOG_FATAL("server.plugins", "Plugin '{}' reported a fatal error: {}. The world is stopping.", id, reason ? reason : "");
        if (owner)
        {
            const_cast<Plugin*>(owner)->state = State::Faulted;
            const_cast<Plugin*>(owner)->reason = std::string("ReportFatal: ") + (reason ? reason : "");
        }
        AnyFaulted = true;
        World::StopNow(ERROR_EXIT_CODE);
        sPluginMgr->WriteReport("fatal");
    }
}

char const* Acore::Plugins::StateName(State state)
{
    switch (state)
    {
        case State::Listed: return "Listed";
        case State::Rejected: return "Rejected";
        case State::LoadFailed: return "LoadFailed";
        case State::Registered: return "Registered";
        case State::RegisterFailed: return "RegisterFailed";
        case State::Started: return "Started";
        case State::StartupFailed: return "StartupFailed";
        case State::Faulted: return "Faulted";
        case State::Stopped: return "Stopped";
    }
    return "?";
}

PluginManager* PluginManager::instance()
{
    static PluginManager instance;
    return &instance;
}

fs::path PluginManager::DefaultDirectory()
{
    std::wstring buffer(32768, L'\0');
    DWORD const length = GetModuleFileNameW(nullptr, buffer.data(), DWORD(buffer.size()));
    buffer.resize(length);
    return fs::path(buffer).parent_path() / "plugins";
}

void PluginManager::Fail(Plugin& plugin, State state, std::string reason)
{
    plugin.state = state;
    plugin.reason = std::move(reason);
    _failed = true;
    LOG_ERROR("server.plugins", "Plugin '{}': {} ({})", plugin.id, StateName(state), plugin.reason);
}

bool PluginManager::ReadLock(fs::path const& lockFile)
{
    std::ifstream in(lockFile, std::ios::binary);
    if (!in)
    {
        LOG_INFO("server.plugins", "No plugin lock file at {}: starting without plugins.", lockFile.generic_string());
        return true;
    }

    // One plugin per line: id|relative dll path|sha256|required(0/1)|conf files|depends on
    std::string line;
    std::set<std::string> ids;
    uint32 lineNo = 0;
    while (std::getline(in, line))
    {
        ++lineNo;
        if (!line.empty() && line.back() == '\r')
            line.pop_back();
        if (line.empty() || line[0] == '#')
            continue;

        std::vector<std::string> parts;
        std::stringstream ss(line);
        for (std::string part; std::getline(ss, part, '|');)
            parts.push_back(part);
        while (parts.size() < 6)
            parts.emplace_back();

        if (parts.size() != 6 || !ValidId(parts[0]) || parts[2].size() != 64)
        {
            LOG_ERROR("server.plugins", "plugins.lock line {} is malformed.", lineNo);
            _failed = true;
            return false;
        }

        if (!ids.insert(parts[0]).second)
        {
            LOG_ERROR("server.plugins", "plugins.lock lists plugin '{}' twice.", parts[0]);
            _failed = true;
            return false;
        }

        Plugin plugin;
        plugin.id = parts[0];
        plugin.path = _dir / fs::path(parts[1]);
        plugin.sha256 = Lower(parts[2]);
        plugin.required = parts[3] != "0";
        plugin.configFiles = SplitList(parts[4]);
        plugin.dependsOn = SplitList(parts[5]);
        _plugins.push_back(std::move(plugin));
    }
    return true;
}

bool PluginManager::CheckBeforeLoad(Plugin& plugin) const
{
    std::error_code ec;
    fs::path const dir = fs::canonical(_dir, ec);
    fs::path const file = fs::weakly_canonical(plugin.path, ec);
    auto const rel = file.lexically_relative(dir);
    if (ec || rel.empty() || *rel.begin() == ".." || rel.is_absolute())
    {
        plugin.reason = "path is outside the plugins directory";
        return false;
    }

    // Checked on the path as written: canonicalisation would already have resolved a junction.
    if (HasReparsePoint(fs::absolute(plugin.path).lexically_normal(), fs::absolute(_dir).lexically_normal()))
    {
        plugin.reason = "path is missing or contains a reparse point (symlink/junction)";
        return false;
    }

    std::ifstream in(file, std::ios::binary);
    std::vector<uint8> bytes((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    if (bytes.empty())
    {
        plugin.reason = "file is empty or unreadable";
        return false;
    }

    std::string const digest = Lower(ByteArrayToHexStr(Acore::Crypto::SHA256::GetDigestOf(bytes.data(), bytes.size())));
    if (digest != plugin.sha256)
    {
        plugin.reason = "sha256 mismatch: file " + digest + ", lock " + plugin.sha256;
        return false;
    }

    PeInfo const pe = InspectPe(bytes);
    if (!pe.ok)
    {
        plugin.reason = "PE inspection failed: " + pe.error;
        return false;
    }

    plugin.imports = pe.imports;
    for (std::string const& dll : pe.imports)
    {
        if (!IsAllowedImport(dll))
        {
            plugin.reason = "imports a library outside the allowlist: " + dll;
            return false;
        }
    }

    std::string const expected = std::string("COAPLUGIN1|") + plugin.id + "|" + COA_PLUGIN_ABI_FINGERPRINT;
    if (pe.section != expected)
    {
        plugin.reason = pe.section.empty() ? "no " COA_PLUGIN_SECTION " section (not built with the plugin SDK)"
                                           : "ABI/identity mismatch: plugin '" + pe.section + "', host '" + expected + "'";
        return false;
    }

    // The export set is not part of the fingerprint (it can grow without a header change), so
    // every name the plugin imports from the host is looked up here: a missing one is reported by
    // name instead of the loader's bare "procedure not found", and no plugin code runs.
    HMODULE const host = GetModuleHandleW(nullptr);
    std::vector<std::string> missing;
    for (std::string const& symbol : pe.hostSymbols)
        if (symbol.empty() || symbol[0] == '#' || !GetProcAddress(host, symbol.c_str()))
            missing.push_back(symbol);
    if (!missing.empty())
    {
        plugin.reason = "needs " + std::to_string(missing.size()) + " export(s) this worldserver does not have, first: " + missing.front();
        return false;
    }

    return true;
}

bool PluginManager::ResolveOrder()
{
    std::map<std::string, std::size_t> index;
    for (std::size_t i = 0; i < _plugins.size(); ++i)
        index[_plugins[i].id] = i;

    for (Plugin& plugin : _plugins)
        for (std::string const& dep : plugin.dependsOn)
            if (!index.count(dep))
                Fail(plugin, State::Rejected, "missing dependency " + dep);

    std::vector<Plugin> ordered;
    std::vector<int> mark(_plugins.size(), 0); // 0 new, 1 visiting, 2 done
    bool cycle = false;
    std::function<void(std::size_t)> visit = [&](std::size_t i)
    {
        if (mark[i] == 2)
            return;
        if (mark[i] == 1)
        {
            cycle = true;
            return;
        }
        mark[i] = 1;
        for (std::string const& dep : _plugins[i].dependsOn)
            if (index.count(dep))
                visit(index[dep]);
        mark[i] = 2;
        ordered.push_back(_plugins[i]);
    };

    for (std::size_t i = 0; i < _plugins.size(); ++i)
        visit(i);

    if (cycle)
    {
        LOG_ERROR("server.plugins", "plugins.lock contains a dependency cycle.");
        _failed = true;
        return false;
    }

    _plugins = std::move(ordered);
    return true;
}

bool PluginManager::Prepare(fs::path const& pluginsDir)
{
    _phase = "prepare";
    _dir = pluginsDir;
    Acore::Plugins::SetFaultHandler(&OnPluginFault);
    Acore::Plugins::SetSuppressHandler(&ShouldSuppress);
    Acore::Plugins::SetFatalHandler(&OnPluginFatal);

    if (!ReadLock(_dir / "plugins.lock") || !ResolveOrder())
    {
        WriteReport("prepare");
        return false;
    }

    std::set<std::string> rejected;
    for (Plugin& plugin : _plugins)
    {
        if (plugin.state == State::Rejected)
        {
            rejected.insert(plugin.id);
            continue;
        }

        bool depRejected = std::any_of(plugin.dependsOn.begin(), plugin.dependsOn.end(), [&](std::string const& d) { return rejected.count(d) > 0; });
        if (depRejected)
        {
            Fail(plugin, State::Rejected, "a dependency was rejected");
            rejected.insert(plugin.id);
            continue;
        }

        if (!CheckBeforeLoad(plugin))
        {
            Fail(plugin, State::Rejected, plugin.reason);
            rejected.insert(plugin.id);
            continue;
        }

        for (std::string const& conf : plugin.configFiles)
        {
            if (!sConfigMgr->AddModuleConfigFile(conf))
            {
                Fail(plugin, State::Rejected, "config file '" + conf + "' is invalid or already used by another module");
                rejected.insert(plugin.id);
                break;
            }
        }
    }

    LOG_INFO("server.plugins", "Plugin host ABI {}; {} plugin(s) listed, {} rejected before loading.", COA_PLUGIN_ABI_FINGERPRINT, _plugins.size(), rejected.size());
    WriteReport("prepare");

    // Spike policy: every listed plugin is fatal (no partially working world).
    return !_failed;
}

void PluginManager::Unlink(Plugin& plugin, bool deleteScripts)
{
    if (!plugin.imageBegin)
        return;

    std::size_t const removed = sScriptMgr->PurgeScripts([&](ScriptObject const* script)
    {
        void const* vtable = *reinterpret_cast<void const* const*>(script);
        auto const address = reinterpret_cast<uintptr_t>(vtable);
        return address >= plugin.imageBegin && address < plugin.imageEnd;
    }, deleteScripts);

    LOG_WARN("server.plugins", "Plugin '{}': unlinked {} registered script(s) (deleted: {}).", plugin.id, removed, deleteScripts);
}

void PluginManager::LoadAndRegister()
{
    _phase = "register";
    for (Plugin& plugin : _plugins)
    {
        if (plugin.state != State::Listed)
            continue;

        bool depFailed = std::any_of(plugin.dependsOn.begin(), plugin.dependsOn.end(), [&](std::string const& dep)
        {
            return std::any_of(_plugins.begin(), _plugins.end(), [&](Plugin const& p) { return p.id == dep && p.state != State::Registered; });
        });
        if (depFailed)
        {
            Fail(plugin, State::Rejected, "a dependency failed to register");
            continue;
        }

        auto const begin = std::chrono::steady_clock::now();
        HMODULE module = LoadLibraryExW(plugin.path.c_str(), nullptr,
            LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_APPLICATION_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (!module)
        {
            Fail(plugin, State::LoadFailed, "LoadLibraryExW failed, error " + std::to_string(GetLastError()));
            continue;
        }

        // Handles are kept for the life of the process; there is no FreeLibrary.
        plugin.module = module;
        plugin.imageBegin = reinterpret_cast<uintptr_t>(module);
        auto const* dos = reinterpret_cast<IMAGE_DOS_HEADER const*>(module);
        auto const* nt = reinterpret_cast<IMAGE_NT_HEADERS64 const*>(reinterpret_cast<uint8 const*>(module) + dos->e_lfanew);
        plugin.imageEnd = plugin.imageBegin + nt->OptionalHeader.SizeOfImage;

        auto query = reinterpret_cast<CoaPluginQueryFn>(GetProcAddress(module, COA_PLUGIN_QUERY_SYMBOL));
        CoaPluginDescriptor const* d = query ? query() : nullptr;
        if (!d || d->structSize < sizeof(CoaPluginDescriptor) || d->apiVersion != COA_PLUGIN_API_VERSION
            || !d->id || plugin.id != d->id || !d->abiFingerprint || std::strcmp(d->abiFingerprint, COA_PLUGIN_ABI_FINGERPRINT) != 0
            || !d->registerScripts || !d->onStartup || !d->onStopping || !d->onDrainBeforeDbClose || !d->onFinalize || !d->lastError)
        {
            Fail(plugin, State::LoadFailed, "invalid or mismatching CoaPluginQuery descriptor");
            continue;
        }
        plugin.descriptor = d;

        CoaPluginStatus const status = d->registerScripts();
        plugin.loadMs = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - begin).count();
        if (status != COA_PLUGIN_OK)
        {
            Fail(plugin, State::RegisterFailed, std::string("registerScripts returned ") + std::to_string(status) + ": " + d->lastError());
            // Scripts constructed before the failure are already in the registries. Nothing has
            // looked them up yet (the database is not loaded), so they can be deleted.
            Unlink(plugin, true);
            continue;
        }

        plugin.state = State::Registered;
        LOG_INFO("server.plugins", "Plugin '{}' {} loaded at {:#x} and registered its scripts in {:.1f} ms.", plugin.id, d->version, plugin.imageBegin, plugin.loadMs);
    }

    // Test fixtures only: fault a plugin after N seconds of world updates, through the same steps
    // as an exception in one of its hooks, to check what its shutdown phases still save.
    std::string const faultId = sConfigMgr->GetOption<std::string>("Plugins.Test.FaultPlugin", "", false);
    if (!faultId.empty() && !sConfigMgr->GetOption<std::string>("Fixture.ExpectedServerUuid", "", false).empty())
        new PluginFaultInjector(faultId, sConfigMgr->GetOption<uint32>("Plugins.Test.FaultAfterSeconds", 60, false));

    WriteReport("register");
}

bool PluginManager::RunPhase(Plugin& plugin, char const* phase, CoaPluginStatus (*fn)())
{
    PhaseWatchdog watchdog(plugin.id + "." + phase, PhaseTimeout());
    CoaPluginStatus const status = fn();
    if (status == COA_PLUGIN_OK)
        return true;

    plugin.reason = std::string(phase) + " returned " + std::to_string(status) + ": " + plugin.descriptor->lastError();
    return false;
}

bool PluginManager::StartAll()
{
    _phase = "ready";
    if (_failed)
    {
        // No plugin starts when any failed. Unlink everything that is mapped - including plugins
        // that registered fine but will never start - so the shutdown path (map unload,
        // logouts) cannot run their hooks. Objects stay alive (world is loaded).
        for (Plugin& plugin : _plugins)
        {
            if (plugin.state == State::Registered)
            {
                plugin.state = State::Rejected;
                plugin.reason = "not started: another plugin failed";
            }
            if (plugin.imageBegin)
                Unlink(plugin, false);
        }
        WriteReport("ready");
        return false;
    }

    for (Plugin& plugin : _plugins)
    {
        if (plugin.state != State::Registered)
            continue;

        if (!RunPhase(plugin, "onStartup", plugin.descriptor->onStartup))
        {
            Fail(plugin, State::StartupFailed, plugin.reason);
            Unlink(plugin, false);
            break;
        }

        plugin.state = State::Started;
        plugin.started = true;
        LOG_INFO("server.plugins", "Plugin '{}' is ready.", plugin.id);
    }

    if (_failed)
    {
        // Plugins that never started get no shutdown phases and no further hooks.
        for (Plugin& plugin : _plugins)
            if (plugin.state == State::Registered)
            {
                plugin.state = State::Rejected;
                plugin.reason = "not started: another plugin failed";
                Unlink(plugin, false);
            }
    }

    // A test plugin may have written through the boundary (CoaPluginAbiCheck.h): report what the
    // host's own object holds.
    if (CoaAbiScratch.writes)
        LOG_INFO("server.plugins", "ABICHECK host sees writes={} lastValue={:#x}", CoaAbiScratch.writes, CoaAbiScratch.lastValue);

    WriteReport("ready");
    return !_failed;
}

bool PluginManager::HealthyAfterStartup() const
{
    return !AnyFaulted && std::none_of(_plugins.begin(), _plugins.end(), [](Plugin const& p) { return p.state == State::Faulted; });
}

void PluginManager::ReportShutdownStatus(Plugin& plugin, char const* phase, CoaPluginStatus status)
{
    if (status == COA_PLUGIN_OK)
        return;

    // Shutdown goes on (the other plugins and the core still save), but the failure is recorded:
    // whatever this plugin had not saved or released yet may be lost.
    std::string const reason = std::string(phase) + (status == COA_PLUGIN_EXCEPTION ? " threw: " : " failed: ") + plugin.descriptor->lastError();
    LOG_ERROR("server.plugins", "Plugin '{}': {}", plugin.id, reason);
    // A failed shutdown phase must not end with exit code 0. main() has already taken its return
    // value when drain and finalize run; for those the boot report carries the failure.
    World::StopNow(ERROR_EXIT_CODE);
    _exitCode = ERROR_EXIT_CODE;
    if (plugin.state == State::Started)
    {
        plugin.state = State::Faulted;
        plugin.reason = reason;
    }
    else
        plugin.reason += "; " + reason;
}

bool PluginManager::OwesShutdown(Plugin const& plugin, char const* phase) const
{
    if (!plugin.started || (plugin.state != State::Started && plugin.state != State::Faulted))
        return false;

    // A faulted plugin's hooks stay suppressed, but it still gets its shutdown phases so it can
    // save and release what it owns (sessions, threads). The entry points are noexcept thunks;
    // a crash (SEH) inside them is not contained.
    if (plugin.state == State::Faulted)
        LOG_WARN("server.plugins", "Plugin '{}' is faulted; running {} anyway so it can save and release what it owns.", plugin.id, phase);
    else
        LOG_INFO("server.plugins", "Plugin '{}': {}.", plugin.id, phase);
    return true;
}

void PluginManager::Stopping()
{
    _phase = "stopping";
    // main() returns the exit code it has when the update loop ends; the shutdown handlers that
    // run afterwards may still change World's value.
    _exitCode = World::GetExitCode();
    for (auto it = _plugins.rbegin(); it != _plugins.rend(); ++it)
    {
        if (it->stopping || !OwesShutdown(*it, "Stopping"))
            continue;
        it->stopping = true;
        PhaseWatchdog watchdog(it->id + ".onStopping", PhaseTimeout(), false);
        ReportShutdownStatus(*it, "onStopping", it->descriptor->onStopping());
    }
}

void PluginManager::DrainBeforeDbClose()
{
    _phase = "drain";
    for (auto it = _plugins.rbegin(); it != _plugins.rend(); ++it)
    {
        if (it->drained || !OwesShutdown(*it, "DrainBeforeDbClose"))
            continue;
        it->drained = true;
        PhaseWatchdog watchdog(it->id + ".onDrainBeforeDbClose", PhaseTimeout(), false);
        ReportShutdownStatus(*it, "onDrainBeforeDbClose", it->descriptor->onDrainBeforeDbClose());
    }
}

void PluginManager::Finalize()
{
    _phase = "finalize";
    for (auto it = _plugins.rbegin(); it != _plugins.rend(); ++it)
    {
        if (it->finalized || !OwesShutdown(*it, "Finalize"))
            continue;
        it->finalized = true;
        PhaseWatchdog watchdog(it->id + ".onFinalize", PhaseTimeout(), false);
        ReportShutdownStatus(*it, "onFinalize", it->descriptor->onFinalize());
        if (it->state == State::Started)
            it->state = State::Stopped;
    }
    WriteReport("finalize");
}

void PluginManager::BeforeProcessExit(int exitCode)
{
    if (_exitCode >= 0)
        exitCode = _exitCode;
    // Default 0, a normal return: plugin statics are destroyed at DLL detach, after the core's own
    // statics, so a plugin must not call into the core from a static destructor (SQUID did; fixed
    // there). 1 is kept as an emergency fallback for a plugin that still does.
    int32 const mode = sConfigMgr->GetOption<int32>("Plugins.ExitMode", 0, false);
    if (mode == 2)
    {
        // Diagnostic only. The world, the scripts and the databases are gone; nothing calls into a plugin now.
        for (auto it = _plugins.rbegin(); it != _plugins.rend(); ++it)
        {
            if (!it->module)
                continue;
            LOG_INFO("server.plugins", "Plugin '{}': unloading image before process exit.", it->id);
            FreeLibrary(static_cast<HMODULE>(it->module));
            HMODULE stillLoaded = nullptr;
            if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                    reinterpret_cast<LPCWSTR>(it->imageBegin), &stillLoaded))
                LOG_WARN("server.plugins", "Plugin '{}': image still loaded after FreeLibrary (another reference holds it); its statics run at process exit.", it->id);
            it->module = nullptr;
        }
    }
    else if (mode == 1)
    {
        LOG_INFO("server.plugins", "Ending the process without static destructors (Plugins.ExitMode = 1), exit code {}.", exitCode);
        sLog->SetSynchronous();
        std::fflush(nullptr);
        TerminateProcess(GetCurrentProcess(), static_cast<UINT>(exitCode));
    }
}

Plugin* PluginManager::FindPlugin(std::string const& id)
{
    auto it = std::find_if(_plugins.begin(), _plugins.end(), [&](Plugin const& p) { return p.id == id; });
    return it == _plugins.end() ? nullptr : &*it;
}

bool PluginManager::IsPluginAddress(void const* address, Plugin const** owner) const
{
    auto const a = reinterpret_cast<uintptr_t>(address);
    for (Plugin const& plugin : _plugins)
    {
        if (plugin.imageBegin && a >= plugin.imageBegin && a < plugin.imageEnd)
        {
            if (owner)
                *owner = &plugin;
            return true;
        }
    }
    return false;
}

void PluginManager::LogHostAddresses() const
{
    LOG_INFO("server.plugins", "HOSTADDR sScriptMgr={} PlayerScriptRegistry={} UnitScriptHooks={} WorldScriptRegistry={} sWorld={} sConfigMgr={} sLog={} scriptCount={}",
        static_cast<void const*>(sScriptMgr),
        static_cast<void const*>(&ScriptRegistry<PlayerScript>::ScriptPointerList),
        static_cast<void const*>(&ScriptRegistry<UnitScript>::EnabledHooks),
        static_cast<void const*>(&ScriptRegistry<WorldScript>::ScriptPointerList),
        static_cast<void const*>(sWorld.get()),
        static_cast<void const*>(sConfigMgr),
        static_cast<void const*>(sLog),
        sScriptMgr->GetScriptCount());
}

void PluginManager::WriteReport(char const* phase) const
{
    if (_dir.empty())
        return;

    std::ostringstream out;
    out << "{\n  \"schema\": 1,\n  \"phase\": \"" << JsonEscape(phase) << "\",\n";
    out << "  \"hostAbiFingerprint\": \"" << COA_PLUGIN_ABI_FINGERPRINT << "\",\n";
    out << "  \"anyFaulted\": " << (AnyFaulted ? "true" : "false") << ",\n  \"plugins\": [";
    for (std::size_t i = 0; i < _plugins.size(); ++i)
    {
        Plugin const& p = _plugins[i];
        out << (i ? "," : "") << "\n    {\"id\": \"" << JsonEscape(p.id) << "\", \"state\": \"" << StateName(p.state)
            << "\", \"reason\": \"" << JsonEscape(p.reason) << "\", \"required\": " << (p.required ? "true" : "false")
            << ", \"loadMs\": " << p.loadMs
            << ", \"shutdownPhases\": [" << (p.stopping ? "\"stopping\"" : "") << (p.drained ? ", \"drain\"" : "")
            << (p.finalized ? ", \"finalize\"" : "") << "], \"imports\": [";
        for (std::size_t j = 0; j < p.imports.size(); ++j)
            out << (j ? ", " : "") << "\"" << JsonEscape(p.imports[j]) << "\"";
        out << "]}";
    }
    out << "\n  ]\n}\n";

    fs::path const tmp = _dir / "plugin-boot-report.json.tmp";
    {
        std::ofstream file(tmp, std::ios::binary | std::ios::trunc);
        file << out.str();
    }
    std::error_code ec;
    fs::rename(tmp, _dir / "plugin-boot-report.json", ec);
}

#endif // COA_PLUGIN_HOST
