# CoA Dynamic Plugin Architecture — отчёт этапов 0–1 (SPK-0, SPK-1 и связанные)

Дата: 2026-10-29. Машина: рабочий ПК владельца (Windows 11, 16 потоков, 31 ГБ RAM, общий с другими задачами).

## Где что лежит

- **Ветка ядра:** `spike/plugin-host` (worktree `C:\games\coa-work\plugin-spike\core`).
  - База: `49d2fec0a739598ad35f2bb0652cae0fe80e4266`.
  - Локальные коммиты `66bbef337f`, `00346a0a62`, `2aaa8c8469`, `259944db6e`.
  - **Не запушено.** Merge и PR не делались.

## Обновление 2 (2026-10-29, после решения владельца по упавшим плагинам)

Этот раздел заменяет таблицу «Пункты G1…» ниже; остальной отчёт описывает первый прогон.

**Сделано после первого отчёта (host fingerprint `242d118a…a3c2`):**

| Пункт | Результат | Доказательство |
|---|---|---|
| Фазы остановки для упавшего плагина (решение владельца: «под барьером») | PASS | `throw-hook-login`: упавший probe прошёл `Stopping` → `Drain` → `Finalize`; его in-process сессия разлогинена, персонаж **сохранён** (`characters.logout_time` 1793248607 → 1793256627, `online=0`), поток присоединён. Хуки упавшего плагина по-прежнему пропускаются. Watchdog в фазах остановки только сообщает о зависании (не завершает процесс, чтобы не потерять сохранение остальных игроков) |
| Барьер для ручных циклов диспетчеризации | PASS (покрытие) | `ExecuteScript`, `IsValidBoolScript`, `GetReturnAIScript`, `ForeachMaps`, `GetCommands`, `DynamicObjectScript::OnUpdate`, `OnPlayerIsClass`, `OnPlayerGetGameModeMask`, `UnitScript::DealDamage`; при отказе плагина берётся нейтральное значение (например, исходный урон). Отдельным тестом с броском **в этих** путях не проверялось |
| DB identity guard в ядре | PASS | `Fixture.ExpectedServerUuid`: проверка всех трёх эффективных `*DatabaseInfo` **до** `StartDB`. Неверный UUID → отказ; переопределение `AC_LOGIN_DATABASE_INFO` на `127.0.0.1:1` → отказ; ни один пул БД не открыт (`report/cases/guard.json`) |
| SPK-5 (реальный ABI-break) | PASS | `probe.dll`, собранный против предыдущего host (`7b46…`), отклонён новым host (`242d…`) до загрузки, оба fingerprint в причине. Изменённые заголовки — `PluginBarrier.h` / `ScriptMgrMacros.h` (не layout класса, используемого плагином; механизм отказа тот же) |
| SPK-6 | PASS | Rust-инспектор без зависимостей (`tools/coa-plugin-inspect`): принимает текущий probe, отклоняет старый fingerprint, DLL без секции и EXE. Fuzz 10 000 мутаций — **0 паник** (6 348 принято, 3 652 отклонено). C++-парсер host фаззингом не проверялся |
| SPK-13 | 100/100 PASS | `report/cases/cycles.json`: каждый цикл — код 0, вход и выход персонажа, поток присоединён, 0 хуков после `Stopping`, статический деструктор после `Finalize`, соединения только с fixture; ready 11.2–16.9 с (медиана 13.9) |
| Регрессия на новом host | PASS | 8 сценариев сбоя без изменений поведения; негативы 12/12 до загрузки |
| SPK-2 (все in-tree модули против SDK) | Измерено | 31 модуль собран против SDK (`plugins/spk2`, `report/spk2-modules.json`). **Компиляция: 30 из 31 без изменений исходников**; `mod-coa-challenges` не компилируется: включает заголовок другого модуля (`CoA.Prestige.API.h`). **Линковка:** 1 модуль (battlehorn) сразу, остальным не хватает **733** различных символов (`Player` 119, `Unit` 87, `WorldObject` 36, `Creature` 20 …), включая глобальные данные (`sAchievementStore` и другие DBC-хранилища — нужен `dllimport`) |

**Решение владельца по модулям CoA (2026-10-29).** Часть CoA-модулей добавляет базовые функции серверов CoA и навсегда остаётся в ядре. Предварительный список (требует подтверждения): challenges, prestige, mythic-plus, path-to-ascension, spellbook, worldforged-upgrades, destiny-weaver, item-recovery, change-potions, ethereal-bazaar, legendary-items, manastorm-endless, custom-races, а также `mod-ascension` (SQL) и client-compat.
- Зависимость challenges → prestige остаётся внутри ядра: API «плагин → плагин» для MVP не нужен.
- 19 оставшимся кандидатам в плагины нужно **487** символов вместо 733; без `mod-coa-raid-difficulty` (269) — около 220.
- Итог около 3.6 тыс. экспортов при лимите PE 65 535.
- Открытый вопрос: остаётся ли raid-difficulty плагином (связан с Content Scaling через FlexHealth); относятся ли боты и Content Scaling к ядру (в roadmap это отдельные этапы 4e–4g).

**Уточнение владельца (2026-10-29):** в ядро также идут lottery, titan-scrolls, craftsmans-codex, dynamic-xp, hero-call-board, portable-sawmill, portablemail, scrolls-of-retreat, teleport-actionbar, treasure-keeper, war-games, woodworking, worldforged-pickups, book-of-artisans, battlehorn, raid-difficulty. Custom Races — **плагин**.
- cfbg (mod-cfbg, кросс-фракционные поля боя) — тоже **в ядро**.
- Плагины из модулей дерева: ah-bot-plus, npc-enchanter, TimeIsTime (уже работает), custom-races.
- Им нужно **82** недостающих символа.
- **Custom Races как плагин.** Ядро само читает `CoACustomRaces.Enable` в 12 местах (`DBCStores.cpp` выбирает `dbc_races`, `AscensionCompat.cpp`, `EsteriaRacials`). Плагином станут только скрипты модуля, DBC-оверлеи и клиентский патч. Чтобы выключенная DLL действительно выключала расы (ADR-5), ядро должно опираться на флаг «плагин custom-races загружен», а не на ключ конфига. Иначе CSM обязан синхронно ставить `CoACustomRaces.Enable = 0` во всех мирах. Нужен отдельный пункт до FV1, а также проверка персонажей кастомных рас при отключённом плагине (вход, отображение, сохранение).

**Решение владельца: боты (Companions и SQUID) и Content Scaling — плагины.** Замер: исходники без изменений (Companions `origin/master`, Scaling `origin/main`, SQUID `origin/coa`), сборка только против SDK (`plugins/ext`, `report/ext-modules.json`):

| Модуль | Компиляция против SDK | Не хватает при линковке | Что требуется от ядра |
|---|---|---|---|
| Companions (106 файлов) | вся | 421 символ (Player 100, Unit 56, WorldSession 22, Group 11, Guild 10 …) | Только экспорт. Существующие правки ядра (login chassis, `Group::GetRolls`, `LFGMgr::GetProposalIdForPlayer`, `OnPetitionOffered`, `AscensionClassServiceBridge`) уже в ядре. `friend class BotMgr` в `Guild.h` даёт доступ к приватному `Guild::_CreateNewBankTab` — заменить узким публичным методом |
| Content Scaling (20) | вся | 43 (включая `CreatureScaling::SetCombatAuthority` / `SetHealthBudgetAuthority` / `HealthMultiplier`, `sMapStore`) | Только экспорт; новые хуки не нужны |
| TBC / WotLK packs | вся | по 4 — все из **самого Scaling** (`CoAContentScaling::Instance`, `ContentPackRegistry::*`) | API «плагин → плагин» или packs внутри DLL Scaling |
| SQUID (728) | 710; 18 файлов не компилируются | — | Инфраструктура `MOD_PLAYERBOTS` в ядре: пул `PlayerbotsDatabase`, statements, транзакции (20 файлов ядра) |

**Особенности `MOD_PLAYERBOTS`, мешающие «всегда включить» инфраструктуру:**
- `PathGenerator` при флаге поднимает предел полигонов пути 74 → 148 **для всего сервера**;
- `DATABASE_MASK_ALL` меняет значение;
- `IWorld` получает новый виртуальный метод;
- путь SQL `modules/mod-playerbots` захардкожен в `DBUpdater`.

Всё это нужно перевести на поведение, управляемое во время работы, и один раз встроить в базовое ядро.

**Пункты G1 после обновления 2:**

| Пункт | Статус |
|---|---|
| SPK-1 (1, 2, 4) | PASS |
| SPK-1 (3) исключения | PASS для всех путей диспетчеризации C++-исключений; SEH (access violation) не перехватывается по дизайну |
| SPK-1 (5) PageHeap / Application Verifier | **НЕ ВЫПОЛНЕНО** — на этой машине IFEO по имени `worldserver.exe` затронет рабочие и чужие серверы; нужна отдельная VM |
| SPK-2 | Измерение выполнено; фактический экспорт и линковка всех модулей — работа FV1 |
| SPK-4 | **ЧАСТИЧНО** — `unit_tests` и старт без регрессий; soak 500 ботов не выполнен (внешних модулей ботов нет в spike-сборке) |
| SPK-5 | PASS |
| SPK-6 | PASS (Rust); C++-парсер host без fuzz |
| SPK-13 | 100 циклов PASS; без Application Verifier / ASan / TSan |
| SPK-14 | **ЧАСТИЧНО** — чистое окружение, ловушки, контроль соединений, guard в ядре — да; AppContainer / сетевой запрет ОС — нет |

**Вердикты после обновления 2:** SPIKE_PASS — **ДА**. G1_PASS — **НЕТ**. Не закрыты: Application Verifier / sanitizers (нужна отдельная VM), soak с ботами, изоляция на уровне ОС (AppContainer или контейнер). Всё остальное из G1 выполнено.
- **Нетронутая база для сравнения:** worktree `core-base` (detached на 49d2fec0).
- **Плагины, SDK, инструменты, логи:** `C:\games\coa-work\plugin-spike\{plugins,sdk,tools,report}`.
- **Изолированный сервер и БД:** `server\`, `server-base\`, `db\`, `mysql\`.

## Итоговые вердикты

| Вердикт | Значение | Основание |
|---|---|---|
| **SPIKE_PASS** | **ДА** | Все обязательные свойства этапа 1 доказаны на Windows: независимая сборка DLL против SDK, единое состояние ядра, рабочие игровые хуки, отсутствие relink, безопасный порядок lifecycle в проверенных сценариях |
| **G1_PASS** | **НЕТ** | Часть обязательных испытаний G1 выполнена частично или не выполнена (таблица ниже). Подменять их предположениями нельзя |

## Изоляция (п. 1 и 4 условий владельца)

**Рабочая БД:** ни одного подключения, ни одного `CHECKSUM TABLE`, ни одного чтения рабочих datadir или `Settings/database.json`. Рабочие MySQL не останавливались.

**Fixture:**
- **MySQL.** Собственный `mysqld` 8.4.9: программные файлы скопированы из чужого fixture-каталога, без его данных. Свой datadir `plugin-spike\db\data`, порт 3417 (`127.0.0.1`), `server_uuid 41bbc654-…`.
- **Окружение.** Каждый дочерний процесс (`mysqld`, `mysql`, `worldserver`) запускается с явно собранным окружением (allowlist). Родитель несёт ловушки `AC_LOGIN/WORLD/CHARACTER_DATABASE_INFO=127.0.0.1;1;…`, `MYSQL_TCP_PORT=1`, `MYSQL_HOST=192.0.2.1`, `MYSQL_PWD`.
- **Соединения.** Каждый прогон `worldserver` проверялся по PID (`Get-NetTCPConnection`): во **всех** прогонах (более 60) поле `establishedNotToFixture` пустое.
- **Валидатор конфигов.** Отказывает в запуске, если любой `*DatabaseInfo` указывает не на порт fixture. Это сработало на реальных ложных совпадениях, и проверка была уточнена.
- **Данные игры.** Только чтение из `C:\games\source\per-race-evidence\server\Data` (не рабочая установка).
- **Чего нет.** DB identity guard внутри ядра (`@@server_uuid`) **не реализован**. Нет AppContainer или сетевого запрета на уровне ОС. SPK-14 — частично.

## Что сделано в ядре (только при `COA_PLUGIN_HOST=ON`)

- **Экспорт API.** `ACORE_API_EXPORT_*` + `ENABLE_EXPORTS` → `worldserver.lib`. `extern template` для **всех 47** `ScriptRegistry<T>` (сверено со списком явных инстанциаций).
  - Аннотации — минимальный набор: `ConfigMgr`, `Log`, `ScriptMgr::instance`, `PlayerScript`, `UnitScript`, `WorldScript`, `ObjectGuid`, `getWorldInstance`, `WorldSession` (ctor/dtor/`SendPacket`/`LogoutPlayer`/`HandlePlayerLoginFromDB`), `LoginQueryHolder`, `Player::TeleportTo`, `GetOption<…>`.
- **Fingerprint.** Exact-build fingerprint на этапе configure: компилятор, флаги, defines, SHA-256 всех заголовков `src/{common,server/shared,database,game,coa}`.
- **PluginManager.** Lock-файл; sha256, PE-заголовки, импорт-allowlist, секция `.coapl` с fingerprint и путь/junction — всё проверяется **до** `LoadLibraryExW`. Далее:
  - DAG зависимостей;
  - `AddModuleConfigFile`;
  - `PluginsReady` до `StartWorldNetwork`;
  - watchdog (`TerminateProcess`, код `0xC0A1`);
  - фазы `Stopping` / `DrainBeforeDbClose` / `Finalize` (C-дескриптор согласован с ADR-12);
  - boot report.
  - `FreeLibrary` нет.
- **Барьер исключений** в трёх макросах диспетчеризации (471 место): атрибуция по vtable → `Faulted` → `World::StopNow`. Скрипты faulted-плагина далее пропускаются.
- **`ScriptMgr::PurgeScripts`** — отвязка (и удаление до загрузки БД) скриптов плагина при частичной регистрации или неудачном старте.
- **`ScriptMgr::Unload`** очищает и `EnabledHooks` / `ALScripts`.
- **Realm** объявляется (снятие `VERSION_MISMATCH`) только после `OnStartup` и только если ни один плагин не faulted.

## Измерения

| Величина | Baseline (49d2fec0) | Spike host |
|---|---|---|
| `worldserver.exe` | 64.57 МБ | 65.40 МБ |
| PE-экспорты | 22 | **3 160** (минимальный набор аннотаций) |
| `unit_tests` | 6288/6288 PASSED | 6288/6288 PASSED |
| Время до `ready` (5 стартов, без автообновлений БД) | 18.7–19.2 с | 10.9–11.1 с (с 2 плагинами) |

**Время старта.** Сумма залогированных фаз загрузки почти одинакова (9.7 с против 9.3 с). Разница в около 8 с лежит **вне** залогированных фаз и **не объяснена**. Вывод о производительности из этого не делается.

**Публичные символы против экспортов.** В индексе `game.lib` 59 726 внешних символов — это **не** PE-экспорты. Реально экспортируется 3 160 при покрытии лишь малой части API; полный API для всех модулей не измерен (SPK-2 — частично).

**SDK:** 126 include-каталогов, 17 628 заголовков, 164 МБ (в основном boost/openssl из vcpkg). Плюс `worldserver.lib`, `fmt.lib`, CMake-пакет, `sdk.json`. Fingerprint `7b464aae…3e67b`.

**Плагины.** Собраны отдельным CMake-проектом, видящим **только** SDK: в командах сборки 0 путей к дереву или сборке ядра.
- `probe.dll` — 395 КБ, 463 импорта из `worldserver.exe`.
- `time-is-time.dll` — 129 КБ, 349 импортов.
- Копии `game` нет: `game.lib` весит около 500 МБ.
- Импорты: `worldserver.exe`, `KERNEL32`, CRT (`VCRUNTIME140*`, `MSVCP140`, `api-ms-win-crt-*`), `WS2_32`.

**Стоимость итераций.** Недостающие экспорты выявляются ошибками линковки плагина: probe — 3 символа, TimeIsTime — ещё 3. Правка заголовка (`ObjectGuid.h`) означает почти полную пересборку host — около 1.5–2 ч на этой машине. Правка `.cpp` в host — минуты, и fingerprint не меняется.

## Результаты испытаний

| Испытание | Результат | Доказательство |
|---|---|---|
| Сборка DLL строго против SDK | PASS | `plugins/*/CMakeLists.txt`, `report/logs/plugin-*-1[0-3].log` |
| Пересборка DLL не меняет `worldserver.exe` | PASS | probe 0.1.0 → 0.1.1: sha256 DLL `31ef6369…` → `11ba2079…`. `worldserver.exe` `9f49780e…` и mtime без изменений. Неизменённый host загрузил 0.1.1 и вызвал хуки (`world-spike-relinkfree`) |
| Единое состояние ScriptMgr / ScriptRegistry | PASS | `HOSTADDR` = `PROBEADDR` побайтно для `sScriptMgr`, реестров `PlayerScript`/`UnitScript`/`WorldScript`, `sWorld`, `sConfigMgr`, `sLog`; `selfInHostRegistry=true` (`world-spike-normal`) |
| Реальные игровые хуки | PASS | 3 991 вызов `UnitScript::OnDamage` в настоящих боях NPC; `PlayerScript::OnPlayerLogin` / `OnPlayerLogout` через реальный `HandlePlayerLoginFromDB` (in-process сессия без клиента: CoA bot chassis) и `TeleportTo`; `WorldScript::OnStartup` / `OnShutdown` / `OnUpdate`; конфиг плагина загружен (`coa_probe.conf` и `mod-time_is_time.conf` в списке модульных конфигов) |
| Реальный модуль из неизменённых исходников | PASS (с оговоркой) | `mod-TimeIsTime` (копия идентична, проверено `diff -r`) + 1 файл адаптера; в host выключен статически. Загрузился, зарегистрировался, прошёл lifecycle, конфиг загружен. **Срабатывание именно его хуков не наблюдалось независимо:** модуль ничего не логирует, а in-process сессия не имеет клиента для пакета `SETTIMESPEED` |
| Lifecycle остановки | PASS (проверенные сценарии) | `Stopping` (хуки ещё работают: `OnPlayerLogout`, `OnShutdown`) → `DrainBeforeDbClose` (поток плагина присоединён) → `Finalize` → статический деструктор DLL. 0 вызовов хуков после `Stopping` |
| 20 циклов старт/стоп | 20/20 PASS | `report/cases/cycles.json` (ready 11.0–16.4 с) |
| Ошибки до сети (отказ / исключение в регистрации, отказ / исключение / зависание в `onStartup`) | PASS | Порт 8185 не открывался, realm не объявлен, код 1 (зависание: `0xC0A1`, `phase=hang:probe.onStartup`); `report/cases/*.json` |
| Очистка частично зарегистрированных плагинов (п. 3 владельца) | PASS после исправления | Частичная регистрация: 1 скрипт удалён. Неуспешный `onStartup`: скрипты всех незапущенных плагинов отвязаны. Найден и исправлен дефект: «зарегистрированный, но не запущенный» второй плагин оставался в реестрах |
| Исключение в хуке в рабочем мире | PASS | `throw-hook-login`: перехвачено, `Faulted`, штатная остановка, код 1 |
| Отказ в `WorldScript::OnStartup` после `PluginsReady` | PASS | `throw-onstartup` и `fatal-onstartup`: realm **не объявлен** (флаг `VERSION_MISMATCH` остался), мир остановлен. Найден и исправлен дефект атрибуции `ReportFatal` |
| Негативы предзагрузки (12) | 12/12 PASS после исправления | sha256, нет секции, чужой fingerprint, `../`, junction внутрь, junction наружу, EXE вместо DLL, запрещённый импорт, дубль ID, битая строка, цикл, отсутствующая зависимость. Ни одна DLL не загружена. Найден и исправлен дефект: junction внутри `plugins` пропускался |
| Аварийное завершение | Только на fixture | Watchdog завершает процесс без сохранения. До сети `StartDB`/`SetInitialWorldSettings` уже могли писать в БД (п. 2 владельца). Последствия проверены только тем, что следующие старты fixture прошли (20 циклов); целостность данных после `0xC0A1` специально **не** анализировалась |

## Пункты G1, выполненные частично или не выполненные

| Пункт | Статус | Что не сделано |
|---|---|---|
| SPK-1 (5) — PageHeap / Application Verifier | **не выполнено** | AppVerifier включается через IFEO **по имени** `worldserver.exe` и требует администратора; затронул бы рабочие и чужие серверы. Переименовать exe нельзя: плагины импортируют из модуля `worldserver.exe` |
| SPK-1 (3) — исключения | частично | Барьер покрывает 471 вызов через макросы. **Не покрыты** ручные циклы диспетчеризации (`ExecuteScript`, `IsValidBoolScript`, `GetReturnAIScript` и 7 явных циклов, например `UnitScript::DealDamage`) |
| SPK-2 | частично | Измерен только минимальный набор экспортов (3 160). Сборка **всех** P/PC-модулей как плагинов и полный бюджет экспортов не выполнены |
| SPK-4 | частично | `unit_tests` и время старта — да. Soak под нагрузкой (500 ботов) — нет: в spike-сборке нет внешних модулей ботов |
| SPK-5 | частично | Механизм отказа по fingerprint доказан (байт-патч fingerprint, а также наблюдаемая смена fingerprint при правке заголовка). Сценарий «реальное изменение layout `Player` → старая DLL отклонена» не прогонялся |
| SPK-6 | частично | Парсер PE на C++ в host работает на 12 негативах. Rust-парсер для CSM и fuzz 10k входов не сделаны |
| SPK-13 | частично | 20 циклов вместо 100; без Application Verifier / ASan / TSan |
| SPK-14 | частично | Очистка окружения, ловушки и мониторинг соединений — да. DB identity guard в ядре, AppContainer и сетевой запрет ОС — нет |
| SPK-3 (Linux) | не выполнялось | Отдельный gate G4h |
| Равенство сборки `COA_PLUGIN_HOST=OFF` исходной | не проверено | Вне ifdef добавлены только объявления (`AddModuleConfigFile`, объявление `GetOption<bool>`). Бинарное или поведенческое сравнение OFF-сборки не проводилось |

## Найденные блокеры и технические решения

1. **Существующие аннотации `AC_*_API` устарели и ломают сборку при включении экспорта.** Пример: `struct AC_SHARED_API Realm` + `unique_ptr` неполного типа.
   - Решение: начинать с выключенных старых аннотаций; экспортировать по измеренному списку; классы с неполными типами или некопируемыми членами экспортировать на уровне членов, а не классом.
2. **Inline-шаблоны тянут неэкспортированные приватные функции.** Пример: `ObjectGuid::Create<>` → приватный `Global`. Явные инстанциации шаблонных методов не экспортируются вместе с классом (`GetOption<T>`); явные специализации нужно экспортировать и объявлять отдельно (`GetOption<bool>`).
   - Решение: CI-job «собрать все модули против SDK», который выдаёт список недостающих экспортов до релиза. Это и есть SPK-2.
3. **Цена итерации.** Каждая правка публичного заголовка — почти полная пересборка host (около 1.5–2 ч). При этом меняется fingerprint, и все плагины нужно пересобрать.
   - Решение: набирать экспортный набор крупными партиями по результату п. 2. Не держать CI-логику «exact fingerprint» без кэша: нужен sccache/ccache для host и для плагинов.
4. **Faulted-плагин не получает фаз остановки.** Его потоки не присоединяются, а его игровые объекты не сохраняются: in-process сессия и персонаж не разлогинены и не записаны. Для ботов это риск потери прогресса.
   - Решение (на выбор владельца):
     - (а) вызывать `onStopping` / `onDrain` и для faulted-плагина под барьером;
     - (б) host сам разлогинивает сессии, созданные плагином (нужен учёт владения сессиями);
     - (в) для faulted-плагинов — аварийное завершение без сохранения и восстановление из последнего сохранения.
5. **Сторонние модули под актуальный AzerothCore.** Upstream имеет хуки, которых нет в CoA (`OnPlayerCanLearnSpell`, `OnSessionUpdate`, `OnPacketSent`, `OnModuleDatabases*` и др.); в CoA 75 собственных хуков (`report/spk0-coa-hooks.md`). Такие модули могут не собраться против CoA SDK — это нужно учитывать в анализаторе этапа 4d.
6. **Плагины привязаны к имени образа `worldserver.exe`.** Переименование host ломает загрузку; вторичные миры уже копируют exe с тем же именем. Это нужно зафиксировать в контракте.
7. **Allowlist импортов.** Инлайн-код boost::asio даёт импорт `WS2_32.dll`. Allowlist должен формироваться по измерению, а не вручную.
8. **Boot report.** Для дубля ID и цикла зависимостей состояние плагина в отчёте остаётся `Listed` без причины: причина только в логе. Исправить в FV1.
9. **Fingerprint прототипа** не включает commit ядра и хэш экспортов (правка `.cpp` в host оставляет fingerprint неизменным). Для FV1 это нужно добавить по ADR-2.

## Существующие проблемы ядра, не связанные с плагинами

- **Чистая установка БД из исходников 49d2fec0 (AutoSetup) не проходит.** SQL `mod-manastorm-endless` падает на собственных самопроверках (`26_manastorm_cache_molten_core_full_reconstruction.sql`: «pool count mismatch»), затем падают зависимые core pending-обновления.
  - На fixture помечены как применённые 59 SQL-файлов самого модуля и 17 core pending-файлов кэшей Manastorm (`report/fixture-skipped-sql.txt`). Fixture-мир работает **без данных кэшей Manastorm**.
  - Отдельная задача: на рабочие установки не влияет, если они ставятся из готовых баз релиза.
- **CSM:** проверочный старт обновления идёт на **рабочей** БД — изолированы только порты (`update.rs:1878-1930`). Подтверждено SPK-0; уже учтено в roadmap §9.0.
- **`RELEASE.json`** производит сторонний repack, а не coa-server-build; CSM использует его только при импорте.

## Инциденты

**Дважды заканчивалось место на C: (0 МБ).**
- Мои артефакты занимают около 23 ГБ: spike-сборка около 19 ГБ, БД 1.8 ГБ, SDK 0.16 ГБ.
- В те же часы другие задачи на машине тоже записывали данные: около 4 ГБ за 90 минут, больше всего `source\manager-092-issues`. Место затем освобождалось не мной.
- Я удалил только промежуточные файлы своей baseline-сборки (около 11 ГБ, бинарники сохранены).
- Два наблюдаемых `mysqld` из «CoA Server 2» — это training-arena другого агента (порт 43319, запущены в 6:45, до инцидента). Признаков вреда рабочим данным нет. Состояние рабочего MySQL я не проверял, так как не подключался к нему по условиям.
- Сейчас свободно около 28 ГБ.

## Рекомендация

- **GO** на продолжение исследований: архитектура «один host-образ + выборочный экспорт + exact-SDK» работает на Windows.
- **NO-GO** на FV1, пока не закрыты пункты таблицы G1.
- Приоритетный порядок:
  1. SPK-2 полностью (все in-tree P/PC модули против SDK, бюджет экспортов);
  2. барьер для ручных циклов диспетчеризации;
  3. решение по п. 4 (faulted-плагин и владение объектами);
  4. DB identity guard в ядре;
  5. Application Verifier / PageHeap на отдельной VM или машине, где IFEO по имени `worldserver.exe` никого не затронет;
  6. 100 циклов;
  7. реальный ABI-break тест SPK-5;
  8. Rust-инспектор и fuzz для CSM.
