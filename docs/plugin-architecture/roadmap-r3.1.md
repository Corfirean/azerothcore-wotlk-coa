# CoA Dynamic Plugin Architecture — технический roadmap (ред. 3)

**Изменения ред. 3:**

| Приоритет | Изменение | Где |
|---|---|---|
| P0 | Готовность плагинов до `StartWorldNetwork` | ADR-3 |
| P0 | Безопасный lifecycle остановки | ADR-12, SPK-13, C11 |
| P0 | Усиленная изоляция fixture | §9.0, SPK-14 |
| P1 | Ограничения ABI-анализатора | ADR-10 |
| P1 | Модель доверия к сторонним DLL | ADR-7 |
| — | План исполнения этапов 0–1 | §16 |

## Context

**Цель.** Перевести CoA Server Manager (CSM) и форк AzerothCore на нативные плагины (`.dll`/`.so`), которые собираются и подключаются независимо от `worldserver`. Конечная цель проекта:
- пользователь вставляет GitHub URL стороннего модуля;
- CSM анализирует его, собирает отдельно в DLL/SO и подключает при следующем старте без пересборки `worldserver`;
- обязательная поддержка Windows и Linux.

**Неподвижные условия:**
- никакого hot-load / hot-unload;
- любые изменения плагинов — только при полностью остановленных мирах;
- никакой потери прогресса;
- главный приоритет — надёжность существующих серверов.

**Статус документа.** Это только план: реализация не начата, файлы не менялись. Предпосылки ТЗ проверены по коду. Редакция 2 учитывает 10 замечаний владельца:
- official-only — только промежуточный этап;
- измерения экспортов вместо утверждений;
- граница исключений и владения памятью;
- изолированные БД для тестов;
- строгие условия binary rollback;
- обеспечение toolchain для обычных пользователей;
- будущая ABI-политика;
- обязательные этапы для Scaling, Companions и SQUID;
- Linux как конечное требование;
- SQL-история SQUID.

**Проверенные ревизии (fetch 2026-10-28):**

| Репозиторий | Ветка | Ревизия |
|---|---|---|
| core (Corfirean/azerothcore-wotlk-coa) | `coa-bots` | `49d2fec0a739598ad35f2bb0652cae0fe80e4266` |
| CSM | `master` | `1dab615` |
| coa-server-build | `main` | `9bf1411` |
| mod-coa-playerbots | `master` | `6a289fc` |
| mod-coa-content-scaling | `main` | `f1caf4e` |
| SQUID (Zyth45/mod-playerbots) | `coa` | `8203e0a3` |

### Структура roadmap

| Этап | Название | Результат | Gate |
|---|---|---|---|
| 0 | Аудит и ADR | Утверждённые решения | G0 |
| 1 | **Прототип** | Доказано: DLL против SDK без relink, единое состояние, граница исключений, измерен экспорт | G1 |
| 2 | **Первая функциональная версия (FV1)** | Host + PluginManager + SDK + официальные prebuilt-плагины + реестр/транзакции CSM; только новые/тестовые установки | G2 |
| 3 | **Миграция существующих пользователей** | Подписанный bridge, opt-in, когорты, legacy поддерживается | G3 |
| 4 | **Полная целевая архитектура** | ABI-эпохи, локальная и удалённая сборка, установка сторонних модулей по URL, Scaling, Companions, SQUID, Linux, остальные модули | G4.x → Final |

Этапы 2–3 — промежуточные. Проект **не считается завершённым**, пока не пройдены все gate этапа 4 (§12).

---

## 1. Current State Audit (доказательства `path:line`)

### 1.1 Ядро: «dynamic modules» фактически не работают

| # | Факт | Доказательство |
|---|---|---|
| 1 | Нет runtime-загрузчика; от `ScriptReloadMgr` остался только комментарий | `worldserver/Main.cpp:285`; `Main.cpp:280` вызывает только статический `AddModulesScripts` |
| 2 | `game` и `coa` всегда `STATIC`; `common`/`shared`/`database` следуют `BUILD_SHARED_LIBS` | `game/CMakeLists.txt:44`; `coa/CMakeLists.txt:15,29`; `common/CMakeLists.txt:48` |
| 3 | Dynamic-модуль линкует `game` целиком (своя копия всех синглтонов) и `coa-interface` без `coa`; при этом `game` зависит от символов `coa` (цикл) | `modules/CMakeLists.txt:247-256`; `game` включает `CoAPortableSession.h`, `AscensionQuestMarkers.h`, `AscensionEquippedGearLoot.h`, реализованные в `coa/` |
| 4 | `ACORE_API_EXPORT_{COMMON,DATABASE,SHARED,GAME}` нигде не определены, поэтому `AC_*_API` никогда не экспортируют | `Define.h:58-95` |
| 5 | Ключевые классы без export-макроса | `ScriptMgr.h:133`, `ScriptObject.h:42`, `World.h:134`, `ObjectMgr.h:737`, `Player.h:1091`, `Unit.h:666`, `WorldSession.h:432`, `Config.h:44` |
| 6 | Состояние `ScriptRegistry<T>` — статические члены шаблона, определённые в заголовке | `ScriptMgr.h:877-882,1024,1028-1031` |
| 7 | Списки модулей, конфигов и SQL задаются при компиляции | `modules/CMakeLists.txt:426-433`; `coa/CMakeLists.txt:49-67`; `Main.cpp:187,318,446-448` |
| 8 | ABI зависит от `MOD_PLAYERBOTS`: vtable `IWorld`, layout `World`, `DATABASE_MASK_ALL`. Regex флага не совпадает с `mod-coa-playerbots` | `IWorld.h:110`; `World.h:232,311`; `DatabaseLoader.h:51`; `modules/CMakeLists.txt:90-98,435-439` |
| 9 | `MOD_MANASTORM_ENDLESS` меняет prepared statements в `database` | `modules/CMakeLists.txt:203-205`; `CharacterDatabase.cpp:908,951` |
| 10 | Module SQL читается из **исходного дерева**, состояние `MODULE`; путь SQUID захардкожен | `BuiltInConfig.cpp:42-45`; `UpdateFetcher.cpp:157-187`; `DBUpdater.cpp:217` |
| 11 | Модульного/скриптового контекста нет; `Unload` удаляет только `ScriptPointerList` | `ScriptMgr.cpp:155-168` |

**Порядок старта и остановки** (`Main.cpp`):
1. `Configure` (:187)
2. `LoadModulesConfigs` (:273)
3. Loaders (:275-280)
4. `ScriptMgr::Initialize` (:289)
5. `StartDB` (:292)
6. `SetInitialWorldSettings` (:322)
7. `OnStartup` (:402)
8. Остановка: `threadPool.reset` (:420), затем `OnShutdown` (:426), затем обратный порядок handles, последним `ScriptMgr::Unload` (:282)

Точка внедрения загрузчика — между :273 и :289.

**Синглтоны.** Все 62 — function-local static в `.cpp` (например, `ScriptMgr.cpp:118`, `World.cpp:149`, `Config.cpp:482`). Если ядро остаётся одним образом, состояние будет единственным.

**Флаги сборки:**
- нет `/GL`/LTO;
- CRT — CMake по умолчанию `/MD`;
- C++20;
- на GCC/Clang `-fvisibility=hidden` включается только при `BUILD_SHARED_LIBS` (`gcc/settings.cmake:58-66`).

**CRT в установке.** Repack поставляет VC++ runtime app-local в `Core\` рядом с `worldserver.exe` (`vcruntime140*.dll`, `msvcp140*.dll`, `concrt140.dll`; проверено на `C:\games\CoA Server 2\Core`). Следствие: плагин не может требовать CRT новее поставленного.

### 1.2 Измерения символов — что известно и что нет (замечание 2)

Измерение: `dumpbin /linkermember:2` на локальном `coa-work/build-core/.../game.lib` (MSVC 14.51, VS 18 Insiders, RelWithDebInfo, `MODULES=static`).
- **59 726 внешних символов в индексе архива**, из них 1 001 vftable и 140 `instance@`.

**Это не число PE-экспортов.** Индекс архива включает:
- COMDAT-инстанциации inline-функций и шаблонов — они экспортируются, только если помечены;
- символы, которые никогда не понадобятся плагину.

Реальное число экспортов при выборочной аннотации может быть **меньше**. Но может быть и **больше**: `__declspec(dllexport)` на классе экспортирует все члены, включая inline, compiler-generated и инстанцированные шаблоны. К тому же сюда не входят `coa`, `common`, `shared`, `database`.

**Вывод.** Лимит PE (65 535 экспортов на образ — ограничение формата ordinal) — **риск для измерения, а не доказанный блокер**. До SPK-2 никакое архитектурное решение не опирается на это число. Вариант `WINDOWS_EXPORT_ALL_SYMBOLS` отклоняется не из-за лимита, а потому что он не даёт `dllimport` для данных: статические члены `ScriptRegistry<T>`, глобальные переменные. Это проверяется в SPK-1.

### 1.3 CSM (`master` 1dab615)

| Область | Текущее | Gap |
|---|---|---|
| Каталог | `include_str!` (`modules.rs:15`); ошибка разбора даёт пустой список (`:66-70`) | runtime-реестр |
| installed / enabled | `.conf`/`.dist` существует (`:184-185`); `enable_key` (`:191-199`) | нет понятия бинарника |
| Toggle не-ботов | Остановка не требуется (`:296-347`) | общий stop-gate |
| Бот-эксклюзивность | toggle `:385-397`; старт `driver.rs:140,163`; вторичные миры через `multiworld.rs:390` | обобщить до `conflicts` |
| `install.json` | `schema` не проверяется; неизвестные поля **теряются** при перезаписи (`registry.rs:15,48-71`; `update.rs:996`) | отдельный файл реестра |
| Транзакции | `State` `update.rs:30-40`, `Action` без Delete `:44-50`, журнал `txn.json`, `ensure_stopped` по всем мирам `:1782-1795`, `update.lock` `:1338-1381`, `ensure_recovered` `:311-324` | plugin ops, Delete, per-tree |
| Validation | `driver::validate_update(root)` = StartAll на временных портах (`update_isolation.rs:84-123`), но **на рабочей БД** | изолированная БД (замечание 4) |
| Backup | без бинарников и `.realms/*` (`backup.rs:234-279`); Full + stopped-MySQL snapshot (`:439-456`) | расширить |
| Миграции | ledger `coa_manager_migrations(db,id,sha256,status,baseline)` (`migrations.rs:15,68`), adopt (`:478-500`), checksum guard (`:379-388,463-476`) | namespace плагинов |
| Merge конфигов | двусторонний аддитивный (`merge.rs:1-2`); парсер сохраняет текст (`parser.rs:1-4`) | 3-way |
| Multiworld | копируется только top-level `Core/*.dll` (`multiworld.rs:264-276`) | `Core/plugins/**` по allowlist |
| Процессы | идентичность = путь exe + время создания (`process.rs:1-25`) | переиспользовать |
| Linux | `ubuntu:26.04`, `Core` → `/srv/core`; multiworld только Windows (`multiworld.rs:143-147`) | `.so` контракт |
| Сборка | CSM ничего не компилирует | build engine с нуля |

### 1.4 SQL-история SQUID (замечание 10)

Источники: `coa-server-build/scripts/squid_playerbots.py`, CSM `crates/coa-core/src/squid.rs`.

SQUID ведёт **собственные журналы**, отдельные от `updates` и `coa_manager_migrations`:

| Журнал / таблица | Где | Назначение |
|---|---|---|
| `coa_squid_migrations(path VARCHAR(240) PK, sha256 CHAR(64))` | в **каждой** целевой схеме: characters, world, `acore_playerbots` (`squid_playerbots.py:107-108,132,147`) | Запись импортированных SQUID-файлов |
| `coa_squid_pending(path, sha256)` | там же | Маркер незавершённого base-импорта: ставится до импорта (`:159`), снимается в той же пачке (`:160-163`). CSM трактует как «восстановить из бэкапа, не удалять и не повторять» (`squid.rs:44-51`) |
| `coa_bots_installed(file)` | `acore_playerbots` | История исходного SQUID-repack-инсталлятора; учитывается как применённое (`:88-92,169-171`) |
| `updates`, `updates_include`, `version_db_playerbots` | `acore_playerbots` | Штатный DBUpdater ядра (`DBUpdater.cpp:200-217`); исключены из «данных» (`:86`) |
| sha1-история upstream | — | Сопоставление по upstream sha1 с CRLF-нормализацией (`:172-175`) |

**Дополнительные факты:**
- base-импорт выполняет **launcher (`manage.py`) до старта мира**, а не CSM и не ядро;
- base-файл «уже применён», если все таблицы из его определений существуют (`:153-158`);
- regex схем — `acore_(?:world|characters)(?:_wildcard)?` (`:81`), то есть **Reborn не поддерживается** для SQUID;
- CSM только читает журналы (`squid.rs:4-6`).

**Требование к новой системе.** Новые SQL-журналы плагинов не должны подменять или переписывать эти таблицы. Они лишь читают их при adopt (§2 ADR-6).

### 1.5 coa-server-build (`main` 9bf1411)

- **Lock.** `release-lock.json`: компоненты с SHA (`daily-release.py:18-60`); in-tree модули пиннятся только через core SHA.
- **CI:** `-DSCRIPTS=static -DMODULES=static -DUSE_COREPCH=0 /Z7` (`server-binaries.yml:323-338`).
- **MSVC «latest on runner»** (`:250`) — toolchain не закреплён (**блокер SDK**).
- **Linux:** clang в `ubuntu:26.04@sha256`, static Boost (`Dockerfile.linux:12,22,42-52`), unsigned.
- **Qualification gates:** `release-metadata.py:11-13`.
- **Патчи ядра** — это коммиты в `coa-bots`, отдельного шага применения нет.
- `RELEASE.json` не производится, но читается CSM (`layout.rs:248,357`). Источник проверяет SPK-0.

---

## 2. Architecture Decision Records

### ADR-1. Единый host-образ и выборочный экспорт API

**Решение.**
- Ядро (`common + shared + database + game + coa + scripts` + статические core features) остаётся **одним образом**.
- Плагины импортируют из него выборочно экспортированный API.
- Вторая копия `game` в плагине запрещена.

**Варианты:**
- **A (кандидат по умолчанию):** экспорт из `worldserver.exe`.
  - Windows: `ENABLE_EXPORTS` → import library `worldserver.lib`. Linux: `-rdynamic`.
  - Раскладка установки, crash dumps и топология процесса не меняются.
- **B (fallback):** `coa-runtime.dll/.so` + тонкий exe (подход TrinityCore с `TC_GAME_API`).

**Выбор** — по результатам SPK-1/1b/2/4. Цикл `game↔coa` не даёт разделить ядро на несколько образов без отдельного рефакторинга (SPK-2b, только если экспорт не помещается в один образ).

**Набор экспорта** определяется **измерением**: сборка всех in-tree P/PC модулей как плагинов, ошибки линковки дают список, CI хранит отчёт `dumpbin /exports` / `nm -D --defined-only` и бюджет.

### ADR-2. Идентичность сборки (fingerprint) — модель FV1

Плагин FV1 грузится **только** при совпадении `hostAbiFingerprint`:

```json
{"pluginApi":1,"abiEpoch":"<см. ADR-10>","coreCommit":"<40hex>","platform":"windows-x86_64",
 "compiler":{"id":"MSVC","fullVer":"<_MSC_FULL_VER>"},"crt":{"kind":"MD","minRedist":"14.xx.yyyyy"},
 "cxxStd":"20","defines":["MOD_PLAYERBOTS=1",...],"flagsHash":"…",
 "publicHeadersHash":"…","exportsHash":"…"}
```

Где хранится fingerprint:
- **host:** generated header + метаданные релиза;
- **SDK:** `sdk.json`;
- **плагин:** `module.json` **и** именованная секция бинарника (PE `.coapl`, ELF `.note.coa.plugin`). Её читают **парсингом файла без загрузки**.

**Toolchain host-сборок закрепляется:** точная версия MSVC (без Insiders, без «latest»), образ Linux по digest.

### ADR-3. PluginManager в worldserver (только старт и остановка)

**Проверенный порядок `Main.cpp` (ред. 3, P0):**

| Строка | Шаг |
|---|---|
| :298 | realm → `OFFLINE \| VERSION_MISMATCH` |
| :322 | `SetInitialWorldSettings` |
| :367 | **`StartWorldNetwork` — сокет открыт** |
| :387 | снятие `VERSION_MISMATCH` (realm доступен) |
| :402 | `OnStartup` |
| :417 | `WorldUpdateLoop` |

**Следствие.** Штатный `OnStartup` выполняется уже **после** открытия сети. Поэтому готовность плагина нельзя связывать с `OnStartup`.

**Шаги старта:**
1. После `LoadAppConfigs`, до `LoadModulesConfigs` (:273): `Discover → MetadataValidated → CompatibilityChecked → ConfigRegistered` через `ConfigMgr::AddModuleConfigFile`.
2. В `SetModulesLoader` (:280): сначала статические модули, затем `BinaryLoaded → ScriptsRegistered` в топологическом порядке.
3. **Новая фаза `PluginsReady`** — после `SetInitialWorldSettings` (:322) и **до** блока сети (:335/:354):
   - для каждого плагина в топологическом порядке вызывается `onStartup()` (C-thunk, `noexcept`);
   - **Watchdog (ред. 3.1).** Зависший синхронный вызов в DLL **нельзя безопасно прервать** внутри процесса: убийство потока оставляет захваченные блокировки и разрушенное состояние. Поэтому watchdog **не прерывает** вызов:
     - отдельный поток host с таймаутом на каждую фазу плагина пишет в boot report `{pluginId, phase, elapsed}` и стек вызывающего потока (minidump);
     - затем вызывает **аварийное завершение всего процесса** (`TerminateProcess(GetCurrentProcess(), CODE_PLUGIN_HANG)` / `_exit`) — без деструкторов и без сохранения;
     - это допустимо только **до** `StartWorldNetwork`: игроков ещё нет, игровых записей нет;
     - CSM видит код выхода и boot report и при следующем старте может пометить плагин `Quarantined` (по политике);
     - существующий `FreezeDetector` (`MaxCoreStuckTime`, :393) запускается только после сети и этот интервал не покрывает;
   - обязательный плагин, вернувший ошибку, приводит к `World::StopNow(ERROR_EXIT_CODE)`, boot report и штатному выходу **до** `StartWorldNetwork`;
   - realm остаётся `OFFLINE`, RA и SOAP не стартуют (они идут после :335);
   - необязательный упавший плагин: `fatal` (по умолчанию) — то же самое; `quarantine` — пометка на следующий старт, текущий старт тоже прерывается. Частично работающий мир не допускается.
4. `OnStartup` (:402) остаётся для обычных `WorldScript`. Всё необходимое для обслуживания игроков плагин выполняет в `PluginsReady`. Это правило SDK.

   **Отказы в `WorldScript::OnStartup` после `PluginsReady` (ред. 3.1)** всё равно контролируются:
   - вызовы `OnStartup` скриптов, принадлежащих плагинам, проходят через барьер исключений (ADR-9). Исключение → `Faulted` → graceful shutdown;
   - SDK даёт `CoaHost::ReportFatal(reason)` для явного отказа из любого хука. Результат тот же;
   - **под `COA_PLUGIN_HOST` снятие `VERSION_MISMATCH` у realm (сейчас :387) переносится после `OnStartup` (:402)** и выполняется только если ни один плагин не `Faulted`. Сокет открыт, но realm в списке authserver недоступен, а `WorldUpdateLoop` ещё не начался, поэтому сессии игроков не обрабатываются до вердикта;
   - зависание в `OnStartup` контролирует тот же watchdog (процесс завершается до `WorldUpdateLoop`, когда игровых записей ещё нет);
   - тест SPK-13: плагин бросает исключение / вызывает `ReportFatal` / зависает в `OnStartup`. Проверяется: realm так и не стал доступен, нет обработанных сессий, процесс завершился с ожидаемым кодом, boot report содержит причину.
5. Boot report пишется дважды: на `PluginsReady` (готовность) и после `OnStartup` (итог).
6. Проверка в SPK-1/SPK-13: в логе нет принятых сессий раньше маркера `PluginsReady`.

**Handles не освобождаются никогда.** Безопасная остановка — ADR-12.

**Источник списка плагинов** — только `Core/plugins/plugins.lock.json`, который генерирует CSM. Каталог не сканируется.

**Проверки до загрузки:**
- схема манифеста;
- канонический путь внутри `Core/plugins/`, без reparse points;
- sha256 файла;
- fingerprint из секции бинарника;
- таблица импортов: только host, allowlist CRT/системных DLL, версия CRT не выше поставленной;
- DAG зависимостей, дубли, `conflicts`, realm policy;
- запрет на ID, совпадающий со статически встроенным модулем (`COA_STATIC_MODULE_IDS`).

**Загрузка:**
- Windows: `SetDefaultDllDirectories` + `LoadLibraryExW(abs, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | APPLICATION_DIR | SYSTEM32)`;
- Linux: `dlopen(abs, RTLD_NOW | RTLD_LOCAL)`.

**Состояния отказа:** `Disabled`, `Unsupported`, `MissingDependency`, `Incompatible`, `Quarantined`, `LoadFailed`, `StartupFailed`, `Faulted`.

**Startup gate:** если обязательный плагин не стартовал, мир не открывает сокет.

**Boot report:** `Core/logs/plugin-boot-report.json`.

### ADR-12. Безопасный порядок остановки (ред. 3, P0)

**Фактический порядок** (после выхода из `WorldUpdateLoop`, `Main.cpp:417`):
1. `threadPool.reset()` :420
2. `Sidecar Deinit` :422
3. `OnShutdown` :426
4. `return` → деструкторы handles в обратном порядке:
   - cli thread;
   - freeze detector;
   - **`sWorldSocketMgrHandle`**: `KickAll` + `UpdateSessions` — сохранение и логаут игроков **вызывают Player-хуки** (:376-377), `StopNetwork` (:379);
   - soap / ra;
   - **`mapManagementHandle`**: `DeleteAllBattlegrounds`, `OutdoorPvP Die`, `UnloadAll` (Map / Creature / Instance хуки), `OnAfterUnloadAllMaps` (:327-332);
   - metric;
   - **`dbHandle` → `StopDB`** (`OnDatabasesClosing`, закрытие пулов);
   - **`sScriptMgrHandle` → `ScriptMgr::Unload`** (:284) — удаление объектов скриптов.
5. Выход из `main`: atexit-деструкторы статиков **exe** (синглтоны host) → `ExitProcess` → `DLL_PROCESS_DETACH` плагинов → **статические деструкторы плагинов уже после уничтожения синглтонов host**. На Linux порядок `__cxa_finalize` аналогично требует проверки.

**Вывод.** Вызывать очистку плагина на `OnShutdown` **нельзя**: после него ещё работают логауты, выгрузка карт и закрытие БД, и они вызывают хуки плагина.

**Целевой lifecycle** — три фазы, каждая с маркером в логе и boot/shutdown report:

| Фаза | Где | Что разрешено плагину | Что запрещено |
|---|---|---|---|
| `Stopping` | сразу после выхода из `WorldUpdateLoop`, до `threadPool.reset()` | прекратить приём **новой** фоновой работы (флаг), хуки остаются полностью рабочими | освобождать объекты, на которые ссылаются хуки |
| `DrainBeforeDbClose` | в начале `StopDB`, до закрытия пулов (после KickAll и UnloadAll — **проверить**, что эти хуки уже отработали) | join всех собственных потоков, flush в БД, отмена таймеров | новые обращения к БД после возврата |
| `Finalize` | **после** `ScriptMgr::Unload()` | освобождение собственного глобального состояния | любые обращения к API host, кроме логирования до `sLog` teardown |

**Требования к ядру:**
- `ScriptMgr::Unload` должен **полностью** очищать реестры, `EnabledHooks` и `ALScripts`. Сейчас удаляется только `ScriptPointerList` (`ScriptMgr.cpp:155-168`, аудит п.11). Это исправление ядра, без него hooks-dispatch после Unload формально возможен.
- В `ScriptMgr` добавляется флаг `_unloaded`. Любая диспетчеризация после него в debug — assert, в release — лог и пропуск.
- **Статические деструкторы плагинов** не должны обращаться к host. Правило SDK: никаких нетривиальных глобальных объектов в плагине. Шаблон SDK хранит состояние в `static T* g = new T` (намеренная утечка до выхода процесса) или освобождает его в `Finalize`; clang-tidy-проверка в SDK.
- Плагин-потоки: SDK даёт `CoaPluginThread` с обязательным join в `DrainBeforeDbClose`. Host отслеживает незавершённые потоки по счётчику: если при `Finalize` счётчик > 0 — ошибка в shutdown report.
- Аварийные выходы (`World::StopNow(ERROR_EXIT_CODE); return 1;` на :363/:370, ранние ошибки `StartDB`) проходят тот же путь деструкторов. Фазы должны быть идемпотентны и корректны при частично выполненном старте: плагин не получил `onStartup`, значит не получает `Stopping`.

**Подтверждение (SPK-13):**
- трассировщик (тестовый плагин) логирует **каждый** вызов своих хуков с номером фазы;
- assert: после маркера `Finalize` нет ни одного вызова; после `DrainBeforeDbClose` нет обращений к БД из потоков плагина;
- сценарии: штатная остановка с игроками онлайн (in-process сессии) и ботами, `.server shutdown`, аварийный выход до `PluginsReady`, ошибка `StartDB`;
- Application Verifier (handles, heaps, locks) на Windows; ASan + TSan на Linux;
- 100 циклов старт/стоп без расхождений.

### ADR-4. Манифест и реестр

- **`module.json`** (upstream/package) — декларация; CSM читает его без исполнения кода.
- **Реестр установки** — новый `<server>.manager/plugins.json` (`schema: 2`, `deny_unknown_fields`, явная проверка версии). Это не `install.json`: старый CSM теряет неизвестные поля.
- Bridge-манифест повышает `min_manager_version`.
- **Allowlist per world:** `<tree>/Core/plugins/plugins.lock.json`.

### ADR-5. Конфигурация

- `plugin.enabled` в реестре — единственный источник истины о загрузке DLL.
- `<Module>.Enable` — игровая опция. Если DLL выключена, модуль не работает независимо от этой опции.
- Пути конфигов прежние.
- Merge — **3-way** (хранится предыдущий `.dist`):
  - новые ключи добавляются;
  - устаревшие помечаются, но не удаляются;
  - конфликты показываются пользователю.
- Дубли ключей между модулями — ошибка и в CSM, и в `worldserver`.

### ADR-6. SQL

- SQL плагинов применяет **только CSM**: ledger `coa_manager_migrations`, id `plugin:<id>:<migration>`, sha256, целевая схема.
- `worldserver` SQL плагинов не применяет.
- Adopt для перенесённых модулей:
  - совпадение строки `updates` (`state='MODULE'`) по имени **и** hash, затем `baseline=1`;
  - несовпадение — `repair-required`, ничего не исполняется.
- **Внешние журналы — только чтение, никогда не запись:**
  - SQUID: `coa_squid_migrations`, `coa_squid_pending`, `coa_bots_installed`, `updates` / `version_db_playerbots` в `acore_playerbots`;
  - CSM-ledger фиксирует `adoptedFrom` и hash.
- Любая строка в `coa_squid_pending` блокирует операцию.
- Плагин не выполняет DDL в коде: для official это проверяется ревью, для сторонних — предупреждение.

### ADR-7. Доверие

**Три зоны:**
1. подписанные CoA артефакты;
2. сторонний исходник и скрипты сборки;
3. DLL в процессе `worldserver`.

Изоляция сборки защищает машину во время сборки. DLL после этого всё равно исполняется с полными правами `worldserver`. Решающий барьер — явное решение о доверии.

Подпись CoA никогда не ставится на чужой код. Для удалённой сборки чужого кода вводится отдельный вид аттестации: `built-by` / provenance — «собрано CoA build service из commit X», но **не** «доверено CoA» (ADR-11).

**Модель доверия к сторонним DLL (ред. 3, P1).**

**Что CSM может доказать и что нет:**

| Доказывает | НЕ доказывает |
|---|---|
| Идентичность исходника (commit SHA, hash файлов) | Что код не вредоносен (кража учётных данных, бэкдор, команды ОС, порча БД) |
| Что бинарник собран из него (provenance) | Что модуль сохраняет игровые данные корректно во всех сценариях |
| Совместимость ABI с SDK | Что модуль не содержит логических ошибок, race conditions, утечек |
| Что модуль загрузился и прошёл **конкретные** тесты на **конкретных** fixture | Что тестовое покрытие репрезентативно для реальной нагрузки и реальных данных |
| Что плагин объявил в манифесте (SQL, конфиги, хуки) | Что плагин не делает необъявленного (код в процессе не ограничен манифестом) |

**Уровни доверия в реестре:**
- `official-signed` — код ревьюирован и подписан CoA. Не гарантия отсутствия ошибок, но CoA несёт ответственность за исправления;
- `third-party-pinned` — пользователь подтвердил доверие автору и конкретному commit;
- `third-party-unreviewed` — по умолчанию для любого URL.

Для обоих сторонних уровней одинаковые ограничения:
- установка в состоянии `disabled`;
- включение — отдельное явное действие с текстом предупреждения;
- запись `riskAcknowledgement{user, at, commit, textVersion}` в `plugins.json`;
- при обновлении commit подтверждение запрашивается **заново**.

**Обязательные меры защиты данных** при сторонних плагинах — они снижают последствия, но не исключают риск:
- свежая точка восстановления (Full) перед первым включением и перед каждым обновлением;
- предупреждение в UI, что binary rollback после игрового времени со сторонним плагином **не квалифицирован** (§10.6, условие 3) — восстановление только forward fix или ручной план;
- бейдж статуса в UI «сторонний код: CoA не проверял»;
- в diagnostics и crash report — список активных сторонних плагинов, чтобы ошибки ядра и плагина можно было различить;
- рекомендация (не гарантия): держать сервер с недоверенными плагинами отдельно от ценных данных; запуск `worldserver` под отдельной учётной записью ОС ограничивает доступ к файлам пользователя, но **не** к игровой БД и данным процесса.

**Формулировки UI и документации** не используют слова «безопасно», «проверено», «совместимо гарантированно» для сторонних плагинов. Только: «собрано», «загружено», «прошло N тестов совместимости».

### ADR-8. Мультимир

- **Store:** `<server>.manager/plugin-store/<id>/<sha256>/`.
- **Развёртывание:** копия в `<tree>/Core/plugins/<id>/` по allowlist **этого** мира.
- `multiworld::prepare` расширяется на `Core/plugins/**`.
- Enable, конфиги и SQL ledger — по мирам.
- Stop-gate: `ensure_stopped` (все миры) + `update.lock` + повторная проверка перед commit.

### ADR-9. Граница исключений и владения памятью (замечание 3)

**C entrypoints плагина** (`CoaPluginQuery`, `register`, `start`, `shutdown`):
- `extern "C"`, `noexcept`;
- SDK генерирует thunk с `try { … } catch (...) { return CoaStatus::Exception; }` и запись в `CoaPluginError` — фиксированный буфер в памяти плагина;
- исключения **не пересекают** эти точки;
- host проверяет код возврата;
- аргументы и результаты — только POD со `structSize`, без STL-типов;
- строки — `const char*` с временем жизни «пока жив образ плагина» (статическое хранилище плагина).

**Хуки ScriptMgr** — C++-вызовы host → plugin через vtable. Здесь граница исключений обеспечивается **барьером в host**:
- при регистрации `ScriptMgr` запоминает владельца скрипта (`pluginId`) через контекст регистрации (`ScriptMgr::BeginPluginRegistration(id)` / `End`);
- диспетчеризация хуков к скриптам плагинов обёрнута в `try/catch`. На x64 табличная модель исключений: без броска нет накладных расходов, это проверяется бенчмарком в SPK-4;
- при пойманном исключении: лог с `pluginId` и хуком, состояние `Faulted`, начало штатной остановки мира (graceful shutdown с сохранением). Продолжать мир с неизвестным состоянием плагина нельзя;
- политика `quarantine` действует только на **следующий** старт.

**Обратное направление.** Исключения host → plugin: API-функции ядра, вызываемые из плагина, могут бросать (например, `std::bad_alloc`). Контракт SDK: плагин обязан ловить их в своём коде. SDK содержит макрос-обёртку и статическую проверку (clang-tidy профиль), но гарантировать это для чужого кода нельзя. Последняя линия защиты — барьер в host.

**SEH и сигналы** (access violation) не перехватываются как исключения. Crash dump / core с атрибуцией по адресному диапазону модуля попадает в boot/crash report.

**Владение памятью:**
- единый CRT (`/MD`, общая куча UCRT; на Linux — общий libstdc++/glibc), проверяется по fingerprint и импортам;
- объекты `ScriptObject`, созданные плагином, переходят во владение `ScriptMgr` и удаляются host. Это допустимо **только** при едином CRT; образ плагина не выгружается, поэтому vtable живы;
- объекты host (`Player*`, `Unit*`, `WorldSession*`), переданные в хук, принадлежат host. Плагин не хранит их дольше документированного срока жизни; SDK-документ фиксирует срок для каждого типа хука;
- контейнеры STL, переданные по ссылке, не меняют владельца;
- запрещено: `free`/`delete` плагином памяти, полученной из C entrypoint host, и наоборот (кроме `ScriptObject` выше);
- потоки: плагин не вызывает игровой API вне world-потока, кроме явно потокобезопасных функций (список в SDK). Собственные потоки плагин обязан завершить в `onShutdown`.

**Проверки:** SPK-1 (пункты 3–5), тестовая матрица §9.1.

### ADR-10. Будущая ABI-политика (замечание 7)

**FV1** — exact fingerprint. Целевая модель (этап 4a) — **ABI-эпохи**:
- **`abiEpoch`** меняется только при **ломающем** изменении экспортируемого контракта:
  - layout экспортируемого класса (`sizeof` / `offsetof` / база);
  - vtable (новый, удалённый или переставленный virtual, включая добавление в конец базового класса скриптов);
  - сигнатура или удаление экспортируемого символа;
  - значения enum, участвующих в ABI (`PLAYERHOOK_*`, `DATABASE_MASK_ALL`);
  - feature-define, влияющий на layout;
  - мажорная смена CRT или компилятора.
- **`apiLevel`** растёт монотонно при **совместимых** добавлениях: новые экспортируемые функции и классы, новые классы хуков, новые capability.
- **Совместимость:** плагин, собранный под `(E, L)`, загружается на host `(E, L')` при `L' ≥ L`. Сборки ядра без изменения контракта сохраняют эпоху, и **все установленные DLL остаются валидными без пересборки**.

**Механическое вычисление** (никогда не вручную) — CI job `abi-check` сравнивает кандидата с предыдущим релизом:
1. diff списка экспортов (`dumpbin /exports`, `nm -D`);
2. layout-probe: генерируемая единица трансляции со `static_assert(sizeof/offsetof/alignof)` для всех экспортируемых классов, плюс снимок порядка virtual (через clang `-fdump-record-layouts` / `-fdump-vtable-layouts` на Linux-сборке тех же заголовков и сверка на MSVC);
3. на Linux — дополнительно `libabigail abidiff`;
4. diff значений ABI-enum и feature-define.

Любой красный пункт → новая эпоха и **обязательная** пересборка официальных плагинов в том же релизе (§10.5).

**Правила развития ядра** (документ для разработчиков):
- новые хуки добавляются **новыми классами** (`PlayerScript2` / `XxxHooksV2`) или в зарезервированные слоты, а не новым virtual в существующих базовых классах;
- поля в экспортируемые классы — только с эпохой.

**Ограничения анализатора (ред. 3, P1).** Неизменность layout, vtable, экспортов и enum — **необходимое, но не достаточное** условие C++ ABI-совместимости. Анализатор **не видит**:
- изменения тел **inline-функций, шаблонов, `constexpr`/`static constexpr`, default-аргументов, макросов** в публичных заголовках. Плагин содержит **старую** скомпилированную копию, host — новую. Это нарушение ODR: расхождение поведения без изменения символов;
- инстанциации шаблонов в плагине (контейнеры с типами host, `ScriptRegistry`-подобные шаблоны), использующие изменённые inline-члены;
- семантические контракты: пред- и постусловия, владение, время жизни указателей, поток вызова, порядок хуков, единицы измерения, смысл значений полей и конфигов;
- изменения спецификаций исключений, `noexcept`, типов исключений, которые бросает API;
- флаги, влияющие на ODR (`_ITERATOR_DEBUG_LEVEL`, `/Zc:*`, `/vd`, `/permissive`, packing/alignment pragma, `-fno-semantic-interposition`), и разницу в STL/CRT-реализации при обновлении redist;
- внутренние, неэкспортируемые члены, к которым обращается inline-код;
- изменения форматов данных в БД и пакетах.

**Итоговый вердикт «эпоха сохранена»** требует **всех** условий:
1. анализатор: нет изменений экспортов, layout, vtable, enum и define;
2. **inline-surface hash** (нормализованный hash всех inline-, template- и constexpr-определений, макросов и default-аргументов в публичных заголовках SDK) **не изменился**. Если изменился — эпоха меняется, исключение возможно только по ручному ревью с записью обоснования в релизных метаданных;
3. **«семантический changelog» API** не содержит изменённых контрактов: ведётся разработчиками, проверяется на ревью;
4. **бинарные тесты совместимости:** официальные плагины, собранные на SDK **предыдущего** релиза, проходят integration-набор на **новом** host (изолированная БД, §9.0), включая сценарии с данными.

Любое сомнение → новая эпоха. Ложная «совместимость» дороже ненужной пересборки.

**Проверка политики — SPK-10:** набор контрольных изменений, заранее размеченных как safe/breaking. Детектор должен классифицировать 100% из них правильно. Включение эпох разрешено только после SPK-10 и одного полного релизного цикла в «теневом» режиме, когда вердикт пишется в отчёт, но решение ещё принимает exact fingerprint.

### ADR-11. Компилятор и SDK для обычных пользователей Windows (замечание 6)

**Принцип.** CSM **определяет возможности системы**, а не предполагает редакцию Windows. Пользователю ничего не устанавливается молча.

**Пути получения бинарника** (в порядке предпочтения):
1. **Prebuilt official** — подписанный ассет релиза под fingerprint/эпоху. Toolchain не нужен.
2. **Удалённая сборка (Remote Build):**
   - **2a. CoA Build Service** — эфемерные изолированные раннеры. Без сетевого доступа к секретам, без подписывающего ключа релизов в той же среде. Результат подписывается отдельным ключом `build-provenance` (не release key) и аттестацией `{sourceCommit, adapterVersion, sdkFingerprint, logsHash}`. Статус в UI: «собрано сервисом CoA, код не проверен CoA».
   - **2b. Сборка в GitHub Actions пользователя** — CSM генерирует workflow в форке пользователя. Нужен токен GitHub, хранится в OS keychain, минимальные scopes. Артефакт проверяется локально по fingerprint и импортам. Риски: токен, квоты; это явный opt-in.
3. **Локальная сборка** — только если есть совместимый toolchain:
   - **Обнаружение:** `vswhere` (Visual Studio / Build Tools, установленные компоненты и точная версия MSVC), Windows SDK, CMake, Ninja. Сверка с `sdk.json.toolchain` (точная или совместимая версия по правилам SPK-7).
   - **Отсутствует:** мастер установки VS Build Tools через официальный bootstrapper Microsoft с фиксированным набором компонентов и версии (fixed-version bootstrapper / `--channelUri`). Перед этим — честное сообщение об объёме (гигабайты) и лицензии Visual Studio Build Tools. **Юридическая проверка лицензии — обязательный пункт SPK-11** до включения мастера в продукт.
   - **Альтернатива (исследование SPK-12):** clang-cl + lld-link с заголовками MSVC CRT / Windows SDK в Linux-контейнере (WSL2 / Docker). Даёт MSVC-совместимый ABI внутри Linux-песочницы. Требуется доказать ABI-идентичность с host-сборкой MSVC (SPK-1-тесты на такой DLL) и разрешённость лицензий на заголовки.
   - **Cmake/Ninja** — версионированные, загружаются CSM с проверкой hash.

**Изоляция локальной сборки** — CSM выбирает сильнейший **доступный** механизм по результатам проверки (capability probe), а не по названию редакции:
- Windows Sandbox (если компонент включён), Hyper-V VM, WSL2 / Docker (для пути SPK-12);
- иначе AppContainer / restricted token + Job Object (лимиты CPU, RAM, времени, процессов; запрет сети после fetch; отдельный профиль без доступа к `%USERPROFILE%`, credentials, `Settings/database.json`, сокетам CSM).

**Политика:**
- official / pinned-trusted исходники: допускается сборка с Job Object, без полной песочницы, после подтверждения;
- **недоверенные** (сторонние) исходники: локальная сборка разрешена только если probe нашёл механизм, прошедший negative-tests SPK-8. Иначе — только удалённая сборка (2a/2b) или отказ с объяснением.

---

## 3. Module Compatibility Matrix

**Классы:**
- **P** — pure DLL;
- **PC** — DLL при экспорте существующего CoA API;
- **A** — нужен адаптер;
- **CF** — core feature;
- **CD** — client/DB coupled.

| Модуль | Особенности | Класс | Этап |
|---|---|---|---|
| mod-TimeIsTime | WorldScript / PlayerScript, без SQL | P | 1 (прототип) → 2 |
| mod-npc-enchanter (upstream azerothcore) | gossip, 1 world SQL | P | 2 (внешний upstream) |
| mod-ah-bot-plus | prepared stmt `WORLD_SEL_AUCTION_BOT_ITEM_SOURCES` в ядре | A / PC | 2 |
| battlehorn, book-of-artisans, cfbg, lottery, titan-scrolls, craftsmans-codex, dynamic-xp, hero-call-board, portable-sawmill, portablemail, scrolls-of-retreat, teleport-actionbar, treasure-keeper, war-games, woodworking, worldforged-pickups | стандартные хуки; использование CoA-only хуков проверяется в SPK-0 | P | 4i |
| challenges, change-potions, mythic-plus, prestige, destiny-weaver, item-recovery, path-to-ascension, spellbook, worldforged-upgrades | CoA headers | PC | 4i |
| legendary-items, ethereal-bazaar, manastorm-endless | client patches / overlay; manastorm задаёт ABI-define | CD + PC | 4i (manastorm — после выноса define) |
| mod-coa-raid-difficulty | FlexHealth пересекается со scaling | P + conflict | 4e (вместе со scaling) |
| **mod-coa-content-scaling + TBC/WotLK packs** | CoA-хуки в ядре; authority API `SetCombatAuthority` / `SetHealthBudgetAuthority` | PC + exclusive-authority | **4e — обязательный** |
| **mod-coa-playerbots (Companions)** | login chassis, `friend class BotMgr` (`Guild.h:297`), `Group::GetRolls`, `LFGMgr::GetProposalIdForPlayer`, `OnPetitionOffered`, `AscensionClassServiceBridge` | CF → PC после адаптации ядра | **4f — обязательный** |
| **SQUID mod-playerbots** | `MOD_PLAYERBOTS` в 20 файлах ядра, `PlayerbotsDatabase`, `acore_playerbots`, свои журналы (§1.4) | CF; возможность плагина — исследование | **4g — обязательная проверка** |
| mod-coa-custom-races | `DBCStores.cpp:290-298`, 25 DBC, client MPQ | CF + CD | остаётся в ядре (решение пересматривается в 4i) |
| mod-ascension / client-compat | SQL-архив; логика в `src/server/coa` | CF | ядро |

---

## 4. Target Directory Layout

```
<Root>\Core\worldserver.exe                     host (экспорт API)
<Root>\Core\vcruntime140*.dll, msvcp140*.dll    app-local CRT (как сейчас)
<Root>\Core\plugins\plugins.lock.json           allowlist мира
<Root>\Core\plugins\<id>\<id>.dll, module.json [, .pdb]
<Root>\Core\configs\modules\*.conf(.dist)       без изменений
<Root>\Core\logs\plugin-boot-report.json
<Root>\.realms\{secondary,reborn}\Core\plugins\...   копия по allowlist мира
<Root>.manager\plugins.json                     реестр v2
<Root>.manager\plugin-store\<id>\<sha256>\
<Root>.manager\plugins\<id>\{dist-history,analysis,build-logs}\
<Root>.manager\sdk\<fingerprint>\               read-only
<Root>.manager\toolchains\{cmake,ninja}\<ver>\  с hash
<Root>.manager\sources\<repo>\<commit>\         кэш исходников (read-only)
<Root>.manager\build\<job>\                     workspace (удаляется)
<Root>.manager\fixtures\<job>\                  изолированные БД-клоны (удаляются)
```

**Linux:**
- то же под `<Root>/Core/plugins/*.so`, монтируется как `/srv/core/plugins`;
- сборка плагинов — в закреплённом образе по digest;
- multiworld на Linux не поддерживается (как сейчас).

**SDK** (подписанный ассет релиза):

| Путь | Содержимое |
|---|---|
| `sdk.json` | fingerprint, `abiEpoch`, `apiLevel`, toolchain, defines, flags, minRedist |
| `include/` | public + generated |
| `lib/worldserver.lib` | только Windows |
| `cmake/CoAPluginSDKConfig.cmake` | `coa_add_plugin()` генерирует loader, C-thunks, секцию `.coapl` |
| `templates/` | шаблоны плагинов |

---

## 5. Interfaces & Schemas (черновики; утверждаются после прототипа)

**C ABI:**

```c
typedef struct { uint32_t structSize, apiVersion; const char* id; const char* version;
  const char* abiFingerprint; uint32_t abiEpoch, apiLevel;
  /* все указатели — noexcept thunks SDK; nullable, кроме registerScripts */
  CoaStatus (*registerScripts)(const CoaHostInfo*);   /* ScriptsRegistered */
  CoaStatus (*onStartup)(void);                       /* PluginsReady, до сети */
  void      (*onStopping)(void);                      /* ADR-12 Stopping: хуки ещё активны */
  CoaStatus (*onDrainBeforeDbClose)(void);            /* ADR-12: join потоков, flush БД */
  void      (*onFinalize)(void);                      /* ADR-12: после ScriptMgr::Unload */
  const char* (*lastError)(void); } CoaPluginDescriptor;
/* Порядок вызова: onStopping / onDrainBeforeDbClose — в обратном топологическом
   порядке (зависимые раньше зависимостей); onFinalize — так же. Плагину, не прошедшему
   onStartup, фазы остановки не вызываются. Каждая фаза вызывается не более одного раза. */
extern "C" const CoaPluginDescriptor* CoaPluginQuery(void) noexcept;
```

**`module.json` v1** — поля ТЗ §4.2 плюс:
- `pluginKind: "scriptmgr"`, `onError`;
- `requiredCoreFeatures` (строки capability с версией);
- `hookOwnership` — по категориям ТЗ §10;
- `sqlMigrations[{id, db, file, sha256, destructive, rollbackCompatible?}]`;
- `dataContract{version, tables[], characterDataTouched: bool}` (для ADR rollback, §10.6).

Схема хранится в `coa-server-manager/schemas/plugin-manifest.v1.json`.

**`plugins.json` v2:** `origin`, `source`, `installed`, `worlds{enabled, pending}`, `lastBoot`, `history`, `trust`, `buildProvenance`, `warnings`.

**`plugins.lock.json`:** `{schema, hostFingerprint, abiEpoch, plugins[{id, path, sha256, abiFingerprint|abiEpoch+apiLevel, onError, dependsOn, configFiles}]}`.

**Состояния build job:**
`Fetched → Resolved → Analyzed → AwaitingTrust → ProvisioningToolchain → Building → Built → Inspected → FixtureTested → Installable | Failed | Cancelled`.

**Plugin transaction** — расширение `update.rs`:
- `Action::Delete`;
- target `tree`;
- фазы `Plan → Prepare → Preflight → Snapshot → Apply → Migrate → Validate(isolated) → GuardedFirstStart → Commit/Recover`.

**Boot report:** `{schema, host{fingerprint, abiEpoch, apiLevel}, plugins[{id, state, reason, loadMs}], faults[]}`.

---

## 6. Этап 0 — Аудит и ADR

| ID | Репо | Задача | Приёмка |
|---|---|---|---|
| SPK-0 | все | Закрыть факты: источник `RELEASE.json`; CoA-only хуки (diff с чистым AzerothCore по тегу); какие P-модули используют CoA-хуки; пользователи с изменённым `worldserver.exe`; поведение `driver::validate_update` относительно БД | Таблица фактов |
| ADR-DOC | core `docs/` | ADR-1…11 | **G0:** утверждены владельцем |

---

## 7. Этап 1 — Прототип

**Условия проведения:**
- ветки `spike/plugin-*`;
- копия сервера, **изолированный экземпляр MySQL** (§9.0);
- ничего не попадает в `coa-bots` и релизы.

| ID | Эксперимент | Критерий успеха | При провале |
|---|---|---|---|
| **SPK-1** | Вариант A на Windows: `ENABLE_EXPORTS`, `ACORE_API_EXPORT_*`, аннотации `ScriptMgr`, `ScriptObject`, `PlayerScript`, `UnitScript`, явные экспортируемые инстанциации `ScriptRegistry<T>`, `ConfigMgr`, `Player`, `Unit`, `World`. Тестовая DLL (TimeIsTime-подобная + `UnitScript::OnDamage`) против SDK без relink host. | (1) Хуки срабатывают в реальном логине и бою. (2) Адреса `sWorld`, `sScriptMgr`, `ScriptRegistry<PlayerScript>::ScriptPointerList` совпадают в host и DLL. (3) Исключение в хуке перехвачено барьером host → `Faulted` + graceful shutdown; исключение в C-entrypoint → код возврата. (4) Под Application Verifier / PageHeap нет ошибок кучи при удалении `ScriptObject` host'ом. (5) Импорты DLL — только `worldserver.exe` и CRT; размер соответствует коду модуля, а не `game`. | SPK-1b |
| SPK-1b | Вариант B (`coa-runtime.dll`) | То же | Стоп проекта, пересмотр ADR-1 |
| **SPK-2** | Все in-tree P/PC модули как плагины против SDK; сбор экспортов по ошибкам линковки. **Измерения:** реальные PE-экспорты (`dumpbin /exports worldserver.exe`, число и рост), размер образа, время старта; отдельно для аннотации на уровне классов и на уровне членов | Числа зафиксированы. Если экспорт ≥ 60 000 — SPK-2b (снять цикл `game↔coa`, разделить образы) или аннотация на уровне членов | — |
| SPK-3 | Linux: то же в образе `ubuntu:26.04@sha`, clang, `-fvisibility=hidden` + default на API, `-rdynamic`, `dlopen RTLD_LOCAL`; объединение vague-linkage статиков, static Boost | Критерии SPK-1 (1)–(5), ASan / UBSan чистые | Linux-трек в этапе 4h откладывается до решения; цель не снимается |
| **SPK-4** | Регрессия host с экспортами и барьерами без плагинов: `unit_tests`, startup, soak 500 ботов | Нет новых падений; разница производительности в пределах шума (измерено на одном стенде) | Найти причину до этапа 2 |
| SPK-5 | Плагин против SDK(X) на host(X+1) с изменённым layout `Player` | Отказ до `LoadLibrary` | — |
| SPK-6 | Статический разбор PE/ELF в Rust (`object` / `goblin`): секция, импорты, arch; fuzz | Без паник на 10k испорченных входов | — |
| SPK-7 | Закрепить MSVC в CI; собрать плагин той же и более новой минорной версией; CRT ниже / выше поставленного | Задокументированы допустимые сочетания; FV1 = exact | FV1 только prebuilt |
| **SPK-13** | Lifecycle (ADR-3 `PluginsReady`, ADR-12): фазы, трассировщик хуков, очистка реестров в `Unload`, статические деструкторы, потоки плагина; 100 циклов старт/стоп; ошибки старта до сети | Ни одного вызова хука после `Finalize`; ни одной принятой сессии до `PluginsReady`; Application Verifier / ASan / TSan чистые; при ошибке обязательного плагина сокет не открывался (проверка портом) | Блокер G1 |
| **SPK-14** | Изоляция fixture (§9.0 пп. 1–7): ловушки в окружении, валидатор конфигов, DB identity guard, AppContainer + named pipe на Windows, `--network none` на Linux | Ловушки не видны; запуск с подставленным рабочим портом отклонён; AppContainer-процесс не может открыть TCP к loopback-порту рабочего MySQL; checksum рабочих схем не изменился | Вариант (в): остановка рабочего MySQL на время validation |

**Два разных вердикта (ред. 3.1):**
- **SPIKE_PASS** — прототипы показали, что подход **работоспособен**:
  - SPK-1 полностью (критерии 1–5);
  - базовые сценарии SPK-13;
  - частичные или облегчённые SPK-2 / SPK-4 / SPK-6 допускаются, но в отчёте помечаются как частичные.
  - SPIKE_PASS **не** разрешает начинать FV1.
- **G1_PASS** — только при **полном** выполнении SPK-1 (или 1b), SPK-2, SPK-4 (включая soak под нагрузкой), SPK-5, SPK-6 (включая fuzz), SPK-13 (все сценарии, 100 циклов, Application Verifier) и SPK-14 (выбран и доказан механизм изоляции) на Windows. Любой пропуск, облегчение или «не выполнено» означает G1 не пройден.
- SPK-3 закрывает отдельный gate G4h.

---

## 8. Этап 2 — Первая функциональная версия (FV1)

**Объём:**
- host + PluginManager + SDK;
- официальные prebuilt-плагины: TimeIsTime, npc-enchanter (внешний upstream), ah-bot-plus (адаптер);
- реестр и транзакции CSM.

Только **новые и тестовые установки** (opt-in канал). Миграции существующих пользователей нет.

### 8.1 Core (`azerothcore-wotlk-coa`)

Всё за `option(COA_PLUGIN_HOST)`; при `OFF` получается нынешний монолит.

| ID | Файлы | Изменение | Зависит | Приёмка | Сл. |
|---|---|---|---|---|---|
| C1 | `Define.h`, `apps/CMakeLists.txt`, `compiler/*/settings.cmake` | Export plumbing, visibility | G1 | `unit_tests` зелёные; поведение без изменений | M |
| C2 | `ScriptMgr.h`, `ScriptObject.h`, `ScriptDefines/*`, заголовки `game` / `coa` | Аннотации по списку SPK-2 | C1 | Отчёт и бюджет экспортов в CI | L |
| C3 | `modules/CMakeLists.txt` | ABI-define фиксированы, `coa_build_features.h`, исправлен regex | C1 | Fingerprint содержит defines | S |
| C4 | `Config.{h,cpp}`, `Main.cpp:273` | `AddModuleConfigFile`, дубли ключей → ошибка | — | Unit-тесты | S |
| C5 | новый `apps/worldserver/Plugins/*`, `Main.cpp:275-289,402,420-426` | PluginManager (ADR-3) | C1–C4 | Negative-тесты §9.1 | L |
| C6 | `ScriptMgr.{h,cpp}` | Контекст регистрации `pluginId` + exception barrier (ADR-9) | C5 | Тест броска → `Faulted` + shutdown | M |
| C7 | `Main.cpp` около :374 | Startup gate | C5 | Мир без сокета при отказе обязательного плагина | S |
| C8 | новый header | Capabilities | C5 | Отсутствующая capability → `Unsupported` | S |
| C9 | `modules/CMakeLists.txt:231-289` | Старый `MODULES=dynamic` выводится из эксплуатации или ведёт на SDK | C5 | Понятная ошибка | S |
| C10 | `modules/CMakeLists.txt` | `COA_STATIC_MODULE_IDS`, исключение пилотов из static | C5 | D4-gate | S |
| C11 | `Main.cpp`, `ScriptMgr.cpp:155-168`, `DatabaseLoader` | Фазы `PluginsReady` / `Stopping` / `DrainBeforeDbClose` / `Finalize`; полная очистка реестров в `Unload`; флаг `_unloaded`; `Fixture.Mode` DB identity guard | C5, SPK-13/14 | Критерии SPK-13/14 в CI | M |

### 8.2 coa-server-build

| ID | Задача | Приёмка |
|---|---|---|
| D1 | Закреплённый MSVC / образ для host-сборок | Детерминированный `sdk.json.compiler` |
| D2 | Job `sdk-package` + подпись | Пилотный плагин собирается на чистой машине только по SDK |
| D3 | Job `official-plugins` + подписи + `compatibility-matrix.json` | — |
| D4 | Gate `no-static-duplicates` | В host нет `Addmod_<id>Scripts` выносимых модулей |
| D5 | Qualification gates: `plugin-load`, `plugin-abi-negative`, `zero-plugins-boot`, `exception-barrier` | — |
| D6 | Lock: собственный ref для выносимых модулей | — |

### 8.3 coa-server-manager

| ID | Задача | Приёмка |
|---|---|---|
| F1 | `plugins.json` v2; каталог с `kind: builtin-static \| plugin`; старые id — aliases | Старый `install.json` читается и не теряется |
| F2 | Статусы `discovered / downloaded / compiled / installed / enabled / loaded last boot / health`; `installed` не выводится из `.conf` | — |
| F3 | Plugin-транзакции поверх `update.rs` (Delete, per-tree); Snapshot включает store, `.realms/*/Core/plugins`, конфиги вторичных миров (`backup.rs:234-279`) | Failure injection на каждом шаге → recover |
| F4 | `multiworld::prepare` копирует `Core/plugins/**` по allowlist; удаляет только управляемое | — |
| F5 | Stop-gate на все plugin-операции; `pending` хранится только в реестре | Попытка при запущенном вторичном мире → отказ |
| F6 | Обобщённые `conflicts` (CSM, launcher, `worldserver`) | Взаимоисключение ботов во всех трёх местах |
| F7 | 3-way merge `.dist` | Комментарии и значения сохраняются |
| F8 | **Изолированный validation-старт** (§9.0) вместо старта на рабочей БД | Рабочая БД не изменена (проверено hash до и после) |
| F9 | Static inspect (SPK-6 в продукт); чтение boot report | — |
| F10 | UI: список по мирам, enable / disable «после остановки», причины отказа, откат | — |

**G2 (FV1 готова):**
- 3 плагина (CoA-owned, внешний upstream, адаптированный) собраны **отдельно**, загружены без relink на чистой установке;
- тестовые матрицы §9.1–9.2 зелёные;
- zero-plugins boot;
- negative ABI.

---

## 9. Тестовая инфраструктура и матрица

### 9.0 Изоляция БД (замечание 4)

**Все integration / fixture / validation тесты** выполняются на **отдельном экземпляре MySQL**:
- собственный `mysqld` из `mysql/bin` repack (или контейнер на Linux);
- временный `--datadir` в `<meta>/fixtures/<job>`;
- `--port` случайный, bind на `127.0.0.1`;
- отдельные учётные данные;
- `pid-file` в каталоге fixture.

**Заполнение:**
- **(а)** копия datadir из **остановленного** MySQL-снимка (переиспользовать `mysql_snapshot.rs`, `backup.rs:439-456`);
- **(б)** logical import последнего Full-бэкапа;
- **(в)** синтетические fixture-БД для CI.

**Правила:**
- `worldserver` / `authserver` fixture получают конфиги, указывающие **только** на этот экземпляр;
- перед стартом CSM проверяет, что в сгенерированных конфигах нет порта или сокета рабочего MySQL (иначе — отказ);
- после теста экземпляр останавливается по **проверенному PID / identity** (никогда по имени образа), каталог удаляется;
- если места на диске недостаточно для клона — validation не выполняется и установка **не продолжается автоматически**; пользователь выбирает: освободить место или «guarded first start» (ниже).

**Усиленная изоляция fixture-серверов (ред. 3, P0)** — защита в глубину, все уровни обязательны.

1. **Чистое окружение процесса.**
   - fixture `mysqld`, `worldserver`, `authserver` и launcher запускаются с **явно сформированным** блоком окружения (`CreateProcessW lpEnvironment` / `execve envp` / `docker run --env-file`), не с унаследованным;
   - allowlist: `SystemRoot`, `windir`, `ComSpec`, `PATHEXT`, `TEMP`/`TMP` (каталог fixture), минимальный `PATH` (каталоги fixture + System32), `NUMBER_OF_PROCESSORS`;
   - **все** остальные удаляются, явно включая:
     - `AC_*` — `ConfigMgr` переопределяет любые ключи, в том числе `LoginDatabaseInfo`/`WorldDatabaseInfo`/`CharacterDatabaseInfo`/`PlayerbotsDatabaseInfo` (`Config.cpp:453-466,530,568,633`), и `AC_CONFIG_POLICY` (`:741`);
     - `MYSQL_HOST`, `MYSQL_TCP_PORT`, `MYSQL_UNIX_PORT`, `MYSQL_PWD`, `MYSQL_HOME`, `MYSQL_TEST_LOGIN_FILE`, `LIBMYSQL_*`;
     - `PYTHON*`, `COA_*`.
   - Тест: harness выставляет в родительском процессе ловушки `AC_LOGIN_DATABASE_INFO=127.0.0.1;<prod port>;…` и `MYSQL_TCP_PORT=<prod>`; fixture обязан их **не** увидеть (дамп окружения дочернего процесса через тестовый плагин).
2. **Сгенерированные конфиги.**
   - Все `*DatabaseInfo` указывают только на fixture-экземпляр (named pipe / Unix socket предпочтительно, иначе случайный TCP-порт).
   - Preflight-валидатор отклоняет запуск, если в любом конфиге fixture-дерева (включая `modules/*.conf` и `.realms/*`) найден хост, порт, pipe или socket рабочего MySQL, известный из `Settings/database.json`, или пароль рабочего пользователя.
   - `my.ini`/`my.cnf` fixture генерируется явно; запуск с `--no-defaults` / `--defaults-file=<fixture>`, чтобы клиент и сервер не читали глобальные option-файлы.
3. **Идентичность БД (DB identity guard).**
   - Клон datadir запускается с **удалённым `auto.cnf`**, поэтому получает новый `server_uuid`; CSM записывает его как ожидаемый.
   - В `worldserver` и `authserver` (только при `Fixture.Mode=1`, ключ задаёт сгенерированный конфиг) после подключения каждого пула выполняется `SELECT @@server_uuid, @@port, @@datadir`. Несовпадение с `Fixture.ExpectedServerUuid` → немедленный `exit` до любых записей. Это изменение ядра входит в SPK-14 / C11.
   - CSM дополнительно проверяет, что `server_uuid` рабочего MySQL ≠ ожидаемого.
4. **Технический сетевой запрет доступа к рабочему MySQL** — по capability probe выбирается сильнейший доступный механизм:
   - **(а) контейнер / VM** с отдельным сетевым namespace (Docker `--network none` + socket mount; WSL2 / Hyper-V) — рабочий MySQL недостижим физически;
   - **(б) Windows без контейнеров:** fixture-процессы в **AppContainer** без loopback-исключения. AppContainer по умолчанию не может подключаться к loopback, следовательно к `127.0.0.1:<prod>`. Fixture-MySQL доступен ему через **named pipe** с ACL для SID этого AppContainer. Осуществимость (libmysql по pipe, работа `worldserver` в AppContainer, доступ к Data/maps) — **SPK-14**;
   - **(в) если ни (а), ни (б) не доступны или не прошли SPK-14:** отдельная учётная запись в рабочем MySQL **не** используется для fixture. Вместо этого рабочий MySQL на время validation **должен быть остановлен** штатно (по проверенному PID / identity, никогда по имени образа) — тогда он недостижим. Это допустимо только когда все миры и так остановлены (plugin-операции требуют этого). Если остановка невозможна — validation не выполняется, установка не продолжается автоматически.
5. **Учётные данные.** Fixture использует собственного пользователя, созданного в клоне. Пароли рабочих пользователей в клоне заменяются случайными до старта fixture-процессов, чтобы утёкшие рабочие учётные данные не работали и обратно.
6. **Сетевые службы fixture.** `Ra.Enable=0`, `SOAP.Enabled=0`, world/auth bind только `127.0.0.1` на случайных портах. В варианте (б) — вообще без внешних соединений: тестовые сессии создаются внутри процесса тестовым плагином.
7. **Аудит после теста.** Сравнение checksum (`CHECKSUM TABLE` по всем таблицам или hash содержимого) рабочих схем до и после: ни одного изменения. Иначе — инцидент в отчёте и блок операции.

**Guarded first start на рабочей БД** — это не тест, а контролируемый первый запуск:
- после Full backup;
- realm закрыт для игроков (`allowedSecurityLevel` / флаг realm offline);
- проверяется boot report;
- только потом realm открывается.

### 9.1 Loader / API

| Категория | Тесты |
|---|---|
| unit (core) | manifest, DAG / циклы, дубли, path traversal / junction / symlink, arch, fingerprint / epoch, capability, дубли конфиг-ключей |
| binary ABI (Win / Linux) | единые адреса синглтонов и реестров; RTTI `dynamic_cast` через границу; удаление `ScriptObject` host'ом под PageHeap / ASan; CRT-версия импортов |
| exception boundary | бросок в каждом C-entrypoint → код; бросок в хуке → `Faulted` + graceful shutdown с сохранением; `bad_alloc` из API host внутри плагина пойман |
| integration (изолированная БД) | `PlayerScript` / `UnitScript` в реальном логине и бою; детерминированный порядок нескольких плагинов |
| lifecycle | нет callback после `OnShutdown`; потоки плагина завершены; DLL не выгружается |
| negative | файл вне `plugins/`; подмена hash; ID статического модуля; CRT новее поставленного |

### 9.2 CSM

- URL parsing (owner / repo, `tree/ref/subdir`, tag, SHA, мусор, shell-метасимволы).
- Вредоносные архивы (symlink, `..`, zip bomb, 100k файлов).
- Модуль с `patches/` → `requires-core-update`.
- Cache hit / miss при смене исходника и SDK.
- Бот-эксклюзивность в UI, launcher и `worldserver`.
- 3-way merge.
- SQL: один раз; delta; cleanup только с явным подтверждением.
- Failure injection на каждом шаге транзакции.
- Сериализация конкурентных операций.
- Отказ при работающем вторичном мире.
- Validation **не трогает** рабочую БД: сравнение checksum таблиц до и после.

### 9.3 Миграция и данные

**Fixtures:**
- текущий stable; base; 2 предыдущих stable;
- imported `repack-v1`; изменённый `worldserver`;
- частичный SQL; 600 ботов;
- CoA + Wildcard; CoA + Reborn;
- Linux Docker;
- custom races + патч клиента;
- portable characters;
- SQUID с `coa_bots_installed` (оригинальный SQUID-repack);
- SQUID с `coa_squid_pending` (прерванный импорт);
- прерывание bridge на каждом состоянии.

**Отпечатки данных до и после:**
- characters, inventory, bank, mail, guild, quests, talents / spells, achievements;
- accounts, bots, `acore_playerbots`, lockouts, races, portable ownership;
- все журналы: `updates`, `coa_manager_migrations`, `coa_squid_migrations`, `coa_squid_pending`, `coa_bots_installed`.

**Функционально:** логин, выбор персонажа, бот, группа, данж со scaling.

### 9.4 Rollback compatibility (CI, на изолированной БД; для §10.6)

Последовательность «новая сборка → сценарий игровой активности → стоп → старая сборка на той же БД»:
1. Новая сборка + сценарий: логин, лут, почта, аукцион, торговля, гильдия, квесты, использование функций плагинов, бот-активность.
2. Остановка.
3. **Старая** сборка на той же БД.
4. Проверки: старт, загрузка всех персонажей, отпечатки, отсутствие удалённых или «неизвестных» предметов, сообщений или ауры.

Результат — `rollback-qualified` пары версий.

### 9.5 Производительность

Startup и tick-time, soak 500 ботов — на одном стенде. Публикуются только измерения.

---

## 10. Этап 3 — Миграция существующих пользователей

**Принцип.** Bridge-релиз функционально эквивалентен текущему монолиту. Статичными остаются боты, scaling, races и CoA core. Плагинами выпускаются только модули FV1. Каждый следующий вынос модуля — отдельный проверенный релиз (этап 4).

### 10.1 Inventory (read-only)

- Классы установки: `legacy-static | new-dynamic | mixed-or-unknown | customized`.
- Признаки: подписанный manifest, `coreCommit`, hash `worldserver.exe`, `original_hashes`, `managed_files`, все SQL-журналы, включая SQUID, `.realms/*`.
- `customized` или unknown → bridge недоступен, ручной план; legacy-сборка не удаляется.

### 10.2 Bridge package

- `Kind::Update` с `Compatibility.pluginHost{fingerprint, abiEpoch, sdk}` и `min_manager_version`;
- host без статических копий модулей FV1 (gate D4);
- плагины FV1, их манифесты, `plugins.lock.json` по умолчанию.

### 10.3 Выполнение (транзакция `update.rs`)

1. Таблица «старый модуль → плагин», enable-состояния сохраняются.
2. **Preflight:**
   - все миры остановлены, lock;
   - место на диске (включая клон для изолированной validation);
   - права;
   - signed hashes;
   - нет строк в `coa_squid_pending`, нет незавершённых транзакций.
3. Download / verify / staging до любых изменений.
4. **Full recovery point:**
   - БД всех миров, включая `acore_playerbots`;
   - конфиги main и `.realms/*`;
   - бинарники;
   - stopped-MySQL snapshot.
5. Фиксация enable-флагов, `realm-profiles`, **всех** журналов (включая SQUID — только чтение).
6. **Apply:**
   - атомарная замена бинарников;
   - `plugins.json` / lock во все деревья;
   - SQL модулей FV1 — adopt (имя + hash), без исполнения.
7. **Validate на изолированном клоне** (§9.0): все миры, boot report, бот-эксклюзивность, отпечатки клона до и после.
8. **Guarded first start** на рабочей БД с закрытым realm → boot report → открытие.
9. **Commit.** Ошибка до открытия realm → полный restore (`update.rs:1313`).

### 10.4 Rollout

- Opt-in.
- Cohort 1: тестовая копия владельца.
- Cohort 2: добровольцы.
- Затем отдельный канал `plugin-edge` / `plugin-stable` параллельно с `edge` / `stable`.
- Legacy-монолит выпускается и обновляется в течение согласованного периода.
- Опубликованные артефакты и каналы не переписываются.

### 10.5 Обновление ядра после bridge

| Ситуация | Действие |
|---|---|
| Тот же fingerprint / эпоха | Плагины сохраняются |
| Новая эпоха | Требуются совместимые версии **всех** включённых плагинов: official — из того же релиза; сторонние — пересборка в staging до commit. Иначе update отклоняется с планом действий |

### 10.6 Binary rollback после начала эксплуатации (замечание 5)

Отсутствие DDL **не** считается доказательством совместимости. Например, старый `worldserver` может удалить при загрузке персонажа предмет с неизвестным `entry`, созданный плагином.

Binary-only откат на версию V_old после игрового времени разрешён, **только если выполнены все условия:**
1. Пара `(V_new → V_old)` помечена в `compatibility-matrix.json` как `rollback-qualified` по CI-тесту §9.4 на этой платформе.
2. В ledger после bridge-commit нет миграций, кроме помеченных `rollbackCompatible: [V_old…]` и подтверждённых тем же тестом.
3. Набор включённых плагинов отображается 1:1 на статические модули V_old с той же семантикой конфигов. Ни один плагин, отсутствующий в V_old (сторонний или новый official), не включался с момента commit. Это проверяется по `lastBoot`-истории реестра.
4. Для каждого включённого плагина `dataContract.version` поддерживается V_old.
5. Перед откатом делается Full backup **текущего** состояния. Откат — новая транзакция с журналом, не восстановление старого дампа.
6. После отката — guarded first start и проверка отпечатков на изолированном клоне, затем открытие realm.

Если хотя бы одно условие не выполнено — **только forward fix** или согласованный ручной data-migration план.

Автоматическое восстановление старого дампа БД после появления игрового прогресса **запрещено всегда**.

---

## 11. Этап 4 — Полная целевая архитектура (обязательные подэтапы)

Порядок: 4a и 4b — первыми; 4c–4d зависят от 4b; 4e–4g могут идти параллельно после G2; 4h — независимый трек; 4i — постепенно.

### 4a. ABI-эпохи (ADR-10)

| ID | Задача | Приёмка |
|---|---|---|
| SPK-10 | Набор контрольных safe / breaking изменений | 100% правильная классификация |
| ABI-1 (build) | Job `abi-check`: экспорты, layout-probe, vtable-dump, enum / define diff, `abidiff` | — |
| ABI-2 (core) | Правила развития хуков (новые классы / слоты); документ | — |
| ABI-3 (CSM / core) | Loader и CSM принимают `(epoch, apiLevel)` | — |
| — | Теневой режим на 1 полном релизном цикле | — |

**G4a:** теневой вердикт совпал с ручной экспертизой на всех релизах цикла; затем включение.

### 4b. Локальная сборка official модулей из pinned SHA

- D7 source fetch (HTTPS API tarball, без `git` hooks, защита архивов);
- D9 build engine (job state machine, Job Object, логи с redaction);
- D11 кэш (ключ: commit + adapter + SDK fingerprint / epoch + flags + target);
- D12 fixture-тест на изолированной БД.

**Приёмка:**
- изменение исходника → пересборка только плагина;
- смена эпохи → инвалидация кэша;
- cold / warm бенчмарк измерен и опубликован.

### 4c. Обеспечение toolchain и удалённая сборка (ADR-11)

| ID | Задача |
|---|---|
| TC-1 | Capability probe: `vswhere`, Windows SDK, компоненты Windows Sandbox / Hyper-V / WSL2 / Docker, AppContainer |
| SPK-11 | Лицензия VS Build Tools для пользователей CSM; fixed-version bootstrapper |
| TC-2 | Мастер установки (после SPK-11) |
| SPK-12 | clang-cl + MSVC headers в Linux-песочнице: ABI-идентичность с host MSVC (тесты SPK-1) и лицензии |
| SPK-8 | Изоляция untrusted build: negative-тесты (нет доступа к профилю, сети, credentials, сокетам CSM) |
| RB-1 | CoA Build Service: эфемерные раннеры, ключ `build-provenance`, аттестации, квоты, abuse-политика |
| RB-2 | Сборка в GitHub Actions пользователя: генерация workflow, keychain-токен, проверка артефакта |

**G4c:** пользователь без среды разработки получает плагин хотя бы одним путём (prebuilt / remote / мастер). Untrusted-сборка доступна только через механизм, прошедший SPK-8, или удалённо.

### 4d. Установка сторонних модулей по GitHub URL — **конечная цель**

| ID | Задача |
|---|---|
| D8 | Статический анализатор: loader, хуки и классы против экспортированного API SDK, SQL, конфиги, CMake-нестандартности, признаки core patches, клиентские ассеты. Вердикт `supported \| adaptable \| requires-core-update \| unsupported \| needs-review` + evidence |
| AD-1 | Версионированные адаптеры (recipe + patch manifest, хранятся отдельно от upstream, применяются к snapshot) |
| UX-1 | «Добавить по ссылке» → анализ → trust-подтверждение → сборка (4b / 4c) → inspect → fixture на изолированной БД → установка disabled → явное включение |
| UP-1 | Обновления: сравнение pinned SHA с ref / release, diff, перепроверка анализа и ABI |

**G4d:**
- минимум 2 внешних upstream ScriptMgr-модуля, не авторства CoA, установлены по URL, собраны без relink и загружены;
- модуль с core patch надёжно отклонён;
- вредоносные входы отклонены.

### 4e. Content Scaling (+ TBC / WotLK packs, raid-difficulty) — обязательный

| ID | Задача |
|---|---|
| SC-1 (core) | Экспорт authority API `CreatureScaling::SetCombatAuthority` / `SetHealthBudgetAuthority`, `LocalLevelScaling`, CoA-хуков из `core-hooks.patch` (уже в ядре); capability `coa.scaling.authority@1` |
| SC-2 | Hook ownership: `exclusive-authority` для health budget / level; конфликт с raid-difficulty FlexHealth объявлен в манифестах |
| SC-3 | Packs как зависимые плагины (`dependsOn: content-scaling`) |
| SC-4 (тесты, изолированная БД) | Регрессия двойного масштабирования здоровья (`changelog.d/20261023-dungeon-health-ownership.md`): trash = A, а не 6.75A; без скачков HP при смене группы; порядок pull / spawn; scaling + raid-difficulty одновременно |
| SC-5 | Миграция пользователей: отдельный bridge-шаг (§10) с adopt `character_coa_lfg_settings` |

**G4e:** тесты SC-4 зелёные; bridge-шаг на fixtures.

### 4f. CoA Playerbots (Companions) — обязательный

| ID | Задача |
|---|---|
| SPK-9 | Инвентаризация core-изменений из `docs/core-patches.md` и их ABI-цены |
| BOT-1 (core) | Заменить `friend class BotMgr` (`Guild.h:297`) узким публичным API; экспорт login chassis (`IWorld::AddQueryHolderCallback`, `LoginQueryHolder`), `Group::GetRolls`, `LFGMgr::GetProposalIdForPlayer`, `OnPetitionOffered`, `AscensionClassServiceBridge` — как capability `coa.bots.chassis@1` |
| BOT-2 | Плагин mod-coa-playerbots; потоки: подтвердить, что всё на world tick |
| BOT-3 (тесты, изолированная БД) | 600 ботов, логин / логаут, группы, лут, LFG, BG fill, петиции, смена спеков; soak; graceful shutdown |
| BOT-4 | Bridge-шаг: состояние ботов и аккаунтов сохраняется, отпечатки совпадают |

**G4f:** BOT-3 без регрессий против static-сборки на том же стенде.

### 4g. SQUID mod-playerbots — обязательная проверка

| ID | Задача |
|---|---|
| SQ-1 | Исследование: может ли SQUID стать плагином, если core-часть `MOD_PLAYERBOTS` (`PlayerbotsDatabase` pool, `DATABASE_MASK_ALL`, `WorldSession` / `MotionMaster` / `PathGenerator` ветки) **всегда** скомпилирована в host и управляется в runtime. Оценить ABI-стоимость, изменения в 20 файлах, влияние на Companions |
| SQ-2 | SQL-контракт: плагинная система **не** пишет в `coa_squid_migrations` / `coa_squid_pending` / `coa_bots_installed`; launcher (`squid_playerbots.py`) остаётся владельцем base-импорта либо переносится в CSM **без смены формата журналов** с тестами эквивалентности. Блокировка при `coa_squid_pending`. Reborn не поддерживается (regex `:81`) — сохранить явный отказ |
| SQ-3 | Взаимоисключение с Companions на трёх уровнях (CSM, launcher, `worldserver` `conflicts`) |
| SQ-4 (тесты, изолированная БД) | Fixtures: `coa_bots_installed`, прерванный импорт, CoA + Wildcard, большие random-bot наборы |

**G4g:**
- **либо** SQUID поставляется плагином с зелёными SQ-2…SQ-4;
- **либо** формально задокументировано, почему SQUID остаётся core feature с конкретными блокерами, и это решение утверждено владельцем.

Проверка обязательна; результат — одно из двух.

### 4h. Linux `.so` — обязательный конечный трек

| ID | Задача |
|---|---|
| L-1 | SPK-3 → host с `-rdynamic` и visibility в Linux-сборке; SDK для Linux |
| L-2 | Подписание Linux-пайплайна (сейчас `linux-unsigned`) — без него нет production |
| L-3 | CSM Docker: `/srv/core/plugins`, сборка плагинов в закреплённом образе |
| L-4 | Qualification Linux-gates (аналог §9 на Docker) |

**G4h:** Linux qualification пройдена, артефакты подписаны.

### 4i. Остальные модули

Постепенный вынос P / PC / CD модулей (§3) по одному на релиз: каждый с adopt SQL, тестами хуков и bridge-шагом. Custom races и client-compat пересматриваются отдельно; по умолчанию остаются core.

---

## 12. Граф зависимостей и Go/No-Go

```
G0 → Этап1(SPK-0..7) → G1 → C1..C10 + D1..D6 + F1..F10 → G2 (FV1)
G2 → Этап3 bridge → G3
G2 → 4a(SPK-10, ABI-1..3) → G4a
G2 → 4b → 4c(TC, SPK-8/11/12, RB) → 4d → G4d
G2 → 4e → G4e ;  G2 → SPK-9 → 4f → G4f ;  G2 → SQ-1 → 4g → G4g
SPK-3 → 4h → G4h ;  G3 + 4a → 4i
Final = G3 ∧ G4a ∧ G4c ∧ G4d ∧ G4e ∧ G4f ∧ G4g ∧ G4h + release gates ТЗ §18.4
```

| Gate | Условие |
|---|---|
| **G0** | ADR утверждены |
| **G1** | Прототип доказан |
| **G2** | FV1 |
| **G3** | Bridge на всех fixtures: отпечатки совпадают, rollback до открытия realm проверен, legacy запускается и обновляется |
| **G4x** | См. подэтапы |
| **Final** | Конечная цель ТЗ: сторонний модуль по URL на Windows **и** Linux, ABI-эпохи, Scaling / Companions перенесены, SQUID решён |

---

## 13. Safety Plan (сводно)

1. Проверки до загрузки (ADR-3); `SetDefaultDllDirectories`; абсолютные пути; allowlist.
2. Граница исключений и памяти (ADR-9); `Faulted` → graceful shutdown.
3. Явное предупреждение о полных правах DLL; untrusted — только через проверенную изоляцию или удалённо (ADR-11).
4. Все тесты и validation — на изолированных БД (§9.0); рабочая БД затрагивается только guarded first start после Full backup.
5. Redaction секретов в логах, отчётах и zip.
6. Внешние журналы (SQUID, `updates`) — только чтение.
7. Binary rollback — только по §10.6; DB rollback после прогресса — никогда автоматически.
8. Data cleanup плагина — отдельная транзакция с двойным подтверждением.

---

## 14. Самые опасные зависимости

1. Объём и стабильность экспортируемого API: реальное число экспортов не измерено (SPK-2); цикл `game↔coa`.
2. Плавающий MSVC в CI (D1) — без него fingerprint и эпохи бессмысленны.
3. CRT app-local: плагин, собранный новее поставленного redist, может не загрузиться или вести себя некорректно — проверка импортов и `minRedist`.
4. Validation сейчас идёт на рабочей БД (`driver::validate_update`) — F8 обязателен до G2.
5. `install.json` теряет поля в старых CSM → отдельный `plugins.json` + `min_manager_version`.
6. `multiworld::prepare` копирует только top-level DLL (F4).
7. Adopt SQL и SQUID-журналы: ошибочное распознавание может привести к повторному base-импорту → только имя + hash, блок при сомнении.
8. Лицензия на распространение / установку toolchain (SPK-11 / 12) — может закрыть локальный путь, тогда остаётся удалённая сборка.

## 15. Open Questions (решаются экспериментом или владельцем)

1. Вариант A или B (SPK-1 / 1b / 4).
2. Реальный размер экспорта и нужен ли SPK-2b.
3. Допустимые расхождения компилятора и CRT (SPK-7).
4. Механизм изоляции untrusted build по результатам probe и SPK-8; лицензии (SPK-11 / 12).
5. Кто эксплуатирует CoA Build Service и с какими квотами (владелец).
6. Длительность legacy-поддержки и политика `onError` по умолчанию (владелец; в плане `fatal`).
7. SQUID: плагин или обоснованный core feature (G4g).

## 16. Исполнение: только этап 0 и экспериментальный этап 1 (разрешено владельцем после утверждения)

### 16.1 Границы

**Что делается:**
- только SPK-0, ADR-документы и прототипы этапа 1:
  - SPK-1, SPK-13, SPK-5, SPK-6;
  - измерительная часть SPK-2 и SPK-4 в объёме, нужном для вердикта;
  - SPK-14 — в части, нужной для изоляции самих экспериментов;
- SPK-3 (Linux), SPK-7 (закрепление CI), SPK-8/10/11/12 — не выполняются, только отмечаются в отчёте.

**Чего не делаю:**
- не меняю production и рабочие установки (`C:\games\CoA Server 2`, `C:\games\CoA Server Manager`), их `mysqld` (PID 49328, 55588) и чужой fixture `mysqld` (PID 61248);
- не делаю релизов, push в `coa-bots`/`master`/`main`, merge, PR, миграций пользователей, не трогаю каналы;
- коммиты — только локально, в отдельных ветках. Push ветки — только с разрешения владельца;
- общие рабочие деревья других агентов не трогаю: `C:\games\coa-core-fork` и `C:\games\coa-work\core*` не переключаю. Работаю в **новом git worktree**.

### 16.2 Рабочее окружение (новые каталоги)

| Путь | Назначение |
|---|---|
| `C:\games\coa-work\plugin-spike\core` | `git worktree add -b spike/plugin-host <path> 49d2fec0` из `C:\games\coa-core-fork` |
| `C:\games\coa-work\plugin-spike\build` | отдельный build-каталог |
| `C:\games\coa-work\plugin-spike\sdk` | экспортированный SDK |
| `C:\games\coa-work\plugin-spike\plugins\<name>` | плагины, отдельные CMake-проекты: собираются **только** против SDK, без доступа к дереву ядра |
| `C:\games\coa-work\plugin-spike\server` | изолированная копия сервера (runtime) |
| `C:\games\coa-work\plugin-spike\db` | отдельный экземпляр MySQL |
| `C:\games\coa-work\plugin-spike\report` | измерения, логи, итоговый отчёт |

**Сборка:**
- MSVC через vcvars, Ninja, RelWithDebInfo;
- `MODULES=static` — только in-tree модули; внешние bots/scaling на первом проходе не добавляются, это отмечается в отчёте;
- параметры как в CI: `USE_COREPCH=0`, `/Z7`;
- сборка в фоне (detached), ограниченный параллелизм, чтобы не исчерпать 31 ГБ RAM на общей машине;
- контроль свободного места: остановиться, если на C: < 15 ГБ.

**Изолированная БД:**
- отдельный `mysqld` из бинарников MySQL репака, запущенный **с `--no-defaults`-эквивалентом** (`--defaults-file` нашего каталога), с новым datadir, своим портом (свободным, проверяется перед стартом), bind `127.0.0.1`, собственным root-паролем;
- **данные рабочих серверов не копируются**: базы создаются с нуля встроенным AutoSetup ядра (`Updates.AutoSetup`, `SourceDirectory` = spike worktree);
- остановка — только по сохранённому PID, проверенному по пути exe;
- процессы fixture запускаются с очищенным окружением (§9.0 п.1).

**Полный запрет доступа к рабочей БД на этапах 0–1 (ред. 3.1):**
- никаких подключений к рабочим `mysqld`, никаких `CHECKSUM TABLE`;
- никакого чтения рабочих datadir, никакого чтения `Settings/database.json` и рабочих `.conf` с учётными данными;
- никакой остановки или перезапуска рабочих `mysqld`;
- рабочие процессы и порты только **наблюдаются** со стороны ОС (список процессов, слушающие порты), чтобы выбрать свободный порт и не пересечься.

**Доказательство изоляции** — средствами самого fixture, без обращения к рабочей БД:
- fixture-конфиги генерируются только с нашим портом и паролем;
- окружение очищено, ловушки `AC_*DatabaseInfo` / `MYSQL_*` в родителе указывают на **заведомо несуществующий** адрес (`127.0.0.1:1`), а не на рабочий порт;
- DB identity guard прототипа: `worldserver` после подключения проверяет `@@server_uuid` нашего экземпляра и `@@datadir` внутри `plugin-spike\db`, иначе завершается до любых записей;
- общий лог подключений (`general_log`) **нашего** `mysqld` показывает все сеансы fixture;
- `netstat` / `Get-NetTCPConnection` по PID fixture-процессов во время прогона подтверждает, что они соединены только с портом нашего `mysqld` (и с loopback-клиентом, если он используется). Соединения с любым другим портом MySQL — остановка экспериментов.

**Данные игры** (maps, vmaps, mmaps, dbc): переиспользуются **только для чтения**. Указываю `DataDir` на существующий каталог данных или делаю копию, если путь не позволяет читать без записи.

### 16.3 Шаги

| № | Шаг | Результат |
|---|---|---|
| 0.1 | SPK-0: источник `RELEASE.json`; CoA-only хуки (diff с чистым AzerothCore по тегу); пользователи с изменённым `worldserver.exe`; `driver::validate_update` и БД | `report/spk0-facts.md` |
| 0.2 | ADR-1…12 в `docs/plugin-architecture/` в spike-ветке (локальный коммит) | Документы для G0 |
| 1.1 | Baseline-сборка без изменений + замер: размер `worldserver.exe`, `dumpbin /exports` (≈0), время старта на изолированной БД | baseline-метрики |
| 1.2 | C1-прототип: `ENABLE_EXPORTS`, `ACORE_API_EXPORT_*`, аннотации минимального набора (`ScriptMgr`, `ScriptObject`, `PlayerScript`, `UnitScript`, `WorldScript`, `ScriptRegistry<T>` для них, `ConfigMgr`, `Player`, `Unit`, `World`, `Log`) | `worldserver.lib` |
| 1.3 | Мини-PluginManager (lock-файл, sha256, `LoadLibraryExW` с ограниченным поиском, `CoaPluginQuery`, C-thunks, барьер исключений, фазы ADR-3/ADR-12, boot/shutdown report) | Прототип, не продуктовый код |
| 1.4 | SDK-экспорт (include + `worldserver.lib` + cmake config) и **отдельный** CMake-проект `probe-plugin`: хуки `OnPlayerLogin`, `OnDamage`, `OnStartup`; дамп адресов синглтонов/реестров; режимы «бросить исключение» в хуке и в entrypoint; трассировщик фаз; дамп окружения | `probe-plugin.dll` |
| 1.5 | **Проверка «без relink»:** после сборки host зафиксировать sha256 `worldserver.exe`; собрать и пересобрать плагин; hash host не меняется; плагин грузится | Доказательство |
| 1.6 | Порт `mod-TimeIsTime` как второго плагина из неизменённых исходников модуля через адаптер SDK; в host он исключён из static (проверка `Addmod_TimeIsTimeScripts` отсутствует в host) | Реальный модуль работает |
| 1.7 | Игровые проверки на изолированном сервере: создание аккаунта и персонажа через консоль. Вход — либо тестовой сессией внутри процесса, либо реальным клиентом владельца (только если он сам предложит; клиент не запускаю) | Хуки сработали в реальном логине и бою |
| 1.8 | SPK-13: 100 циклов старт/стоп, трассировка, ошибочные старты (обязательный плагин падает до сети → проверка, что порт не открывался), Application Verifier на `worldserver` | Lifecycle-отчёт |
| 1.9 | SPK-5 (fingerprint-mismatch) и SPK-6 (Rust-парсер PE + fuzz) — минимальные прототипы | Negative-тесты |
| 1.10 | SPK-2 (измерение): аннотирование до компилируемости ещё 2–3 P-модулей; `dumpbin /exports` count; сравнение class-level vs member-level на примере `Player` | Таблица экспортов |
| 1.11 | SPK-4 (облегчённый): `unit_tests` на spike-сборке против baseline; время старта и tick-time без нагрузки (500-bot soak — только если ресурсы машины позволяют; иначе в отчёте «не выполнено») | Регрессия / нет |
| 1.12 | Итоговый отчёт: измерения, тесты (pass/fail с логами), найденные блокеры. Два отдельных вердикта: **SPIKE_PASS** (да/нет) и **G1_PASS** (да/нет) — с перечнем каждого невыполненного или частичного пункта. Пропущенные проверки не заменяются предположениями | `report/stage1-verdict.md` + краткое резюме владельцу |

### 16.4 Остановка экспериментов

Эксперименты прекращаются и владелец уведомляется, если:
- обнаружено любое обращение к рабочим БД или процессам;
- нехватка диска или памяти угрожает другим работам на машине;
- найден блокер, требующий архитектурного решения владельца.

## Verification плана

- Каждое утверждение §1 воспроизводится через `git -C <repo> show <sha>:<path>`.
- Замер символов: `dumpbin /linkermember:2 game.lib` (это не PE exports — см. §1.2).
- Реализация начинается только после утверждения; первая работа — SPK-0 / SPK-1 в ветке `spike/*` на копии сервера с изолированным MySQL.
