# Round 2.1 — Integration Correctness & Lifecycle Hardening Review

| ISSUE | SEVERITY | ROOT CAUSE | FIX | TEST | STATUS |
|---|---|---|---|---|---|
| **1. Challenge Size / Instance ID Mismatch** | CRITICAL | `sInstanceScalingMgr->SetChallengeSize` used group GUID counter, but `InstanceScalingMgr` indexed `(mapId << 32) \| Map::GetInstanceId()`. The actual dungeon instance never read the challenge size. | Introduced `PendingInstanceScalePolicy` (`mapId`, `groupGuid`, `challengeSize`, `compositionMode`, `generation`). When dungeon instance is bound/created and `Map::GetInstanceId()` is known, transfer policy via `OnInstanceMapCreated` to `(mapId << 32) \| instanceId` before creature scaling. | `InstanceScalingMgrTest.ChallengeModeStorage` | FIXED |
| **2. Party Size vs Queue Target vs Challenge Size** | CRITICAL | For `CURRENT_PARTY`, `targetPlayers` was conditionally set to `challengeSize`, mixing queue formation with virtual difficulty. | Strictly separated: `partySize` = real players entering; `queueTargetSize` = `minPlayers` = `currentPartySize` (instant proposal); `challengeSize` = independent virtual scaling (0=adaptive, 1..40=explicit). | `LfgQueuePolicyAcceptanceMatrixTest.AcceptanceMatrixVerification` | FIXED |
| **3. Challenge Size Validation** | HIGH | Invalid challenge sizes were clamped silently without communicating failure to the player. | Enforce strict validation (0 for adaptive, 1..40 for explicit) and reject out-of-range values with an explanatory error message in `.lfgchallenge`. | `LfgQueuePolicyAcceptanceMatrixTest` | FIXED |
| **4. Competing Encounter Start Sources** | CRITICAL | `BossState(IN_PROGRESS)` and `OnUnitEnterCombat(boss)` raced. If `BossState` ran first, snapshot locked with `nullptr` boss, causing subsequent `OnUnitEnterCombat` to skip boss stat calculation. | Unified `EncounterLifecycleSource` (`INSTANCE_SCRIPT > REGISTERED_ADAPTER > CREATURE_FALLBACK`). Authoritative `BeginEncounter`: if already active, attach boss and apply stats once without re-locking. | `EncounterLifecycleSourceHierarchyTest.PriorityAndKeyIntegrity` | FIXED |
| **5. Snapshot Generation & Single Stat Application** | HIGH | Boss stats could be recalculated repeatedly across multiple combat/state callbacks. | Introduced `snapshotGeneration` on context and `lastAppliedScalingGeneration` per boss GUID in `bossAppliedGenerations` map to guarantee single application per pull. | `EncounterLifecycleSourceHierarchyTest` | FIXED |
| **6. Untyped Encounter Keys & Lock Ownership Check** | CRITICAL | Creature entry was mixed with InstanceScript boss indices. `OnEncounterEnd` unlocked without verifying if the ending entity owned the active lock. | Typed `EncounterKey { type, id }` with `std::hash`. `EndEncounter` verifies that the ending entity matches lock owner key. InstanceScript-owned encounters only unlock on `DONE`, `FAIL`, or reset (never on trash/boss death/exit). | `EncounterLifecycleSourceHierarchyTest` | FIXED |
| **7. Multi-Boss Council Encounters & Adds** | HIGH | Encounter assumed 1 boss per snapshot. Adds could trigger lock or change player count. | Council members tracked in `bossGuids` set. Adds inherit active `EncounterScaleSnapshot` without creating locks, ending locks, or altering participant count. | `EncounterLifecycleSourceHierarchyTest` | FIXED |
| **8. Pre-Damage Exploit & Health Transfer Policy** | HIGH | Untouched bosses could inherit pre-combat damage percentages or corrupt scaling HP. | Introduced `EncounterHealthTransferPolicy` (`FULL_ON_PULL`, `PRESERVE_PERCENT`, `PRESERVE_ABSOLUTE`), defaulting to `FULL_ON_PULL` for fresh pulls. | `InstanceScalingMultipliersTest` | FIXED |
| **9. LFG DefaultMode & Provider Capability** | MEDIUM | `CoAContentScaling.LFG.DefaultMode` was only in config/README but not actively read into default variables; no fallback when `mod-coa-playerbots` is absent. | Read `_defaultLfgCompositionMode` and `_defaultLfgChallengeSize`. If `DefaultMode == BOT_FILL` and no bot fill provider is registered, warn and safely fallback to `MATCHMAKING`. | `LfgQueuePolicyAcceptanceMatrixTest` | FIXED |
| **10. Playerbots LFG Intent Gating & Role-Aware Fill** | HIGH | `BotLfgFill.cpp` in playerbots lacked role-aware fill for partial groups (e.g. Tank+DPS -> Healer+2DPS), multi-role assignment, and `LfgFillOperationId` for targeted cleanup. | Implemented role-aware fill for 1T/1H/3D, multi-role player assignment solver, `LfgFillOperationId` tracking, bot creation attempt limits (max 5), and cleanup on queue cancel/timeout. Enforce strict `MATCHMAKING` -> no bots, `CURRENT_PARTY` -> no bots. | Automated compilation and BotLfgFill verification | FIXED |
| **11. Runtime DDL in C++ Startup** | HIGH | `CREATE TABLE IF NOT EXISTS character_coa_lfg_settings` was executed directly from C++ startup code. | Removed DDL from C++ code. Added proper idempotent versioned SQL migration file in `data/sql/db-characters/character_coa_lfg_settings.sql`. | Startup DDL audit | FIXED |
| **12. Settings Persistence & Cache Cleanup** | MEDIUM | Player settings only lived until logout or weren't immediately persisted; in-memory cache grew indefinitely. | Save settings immediately upon command execution; validate stored enums from DB (fallback to default on corrupted data); clean up cache entry on player logout. | Code audit & test verification | FIXED |
| **13. Active Queue Snapshot Immutability & Party Leadership** | HIGH | Changing preferences while queued could corrupt queue state; non-leaders could queue an existing party. | Active queue snapshot is immutable upon Join. Setting changes apply to subsequent queues. Non-leaders cannot initiate `CURRENT_PARTY` queue for the group. | `LFGMgr.cpp` leadership validation | FIXED |
| **14. Multi-Repository Git Synchronization** | CRITICAL | Commits existed locally or only in patch files without being published to respective GitHub remotes. | Synchronized and verified all commits across `mod-coa-content-scaling`, `azerothcore-wotlk-coa` (`coa-bots`), and `mod-coa-playerbots` (`master`). | Commit SHA and remote audit | FIXED |

---

## Technical Details

### 1. Challenge Size Propagation
Previously, `sInstanceScalingMgr->SetChallengeSize` stored values under the group GUID counter. However, instance lookup is keyed by `(static_cast<uint64>(mapId) << 32) | instanceId`. This meant dungeons never received the player's requested challenge difficulty.

We solved this by:
1. When an LFG proposal successfully forms (`OnLfgProposalMadeGroup`), we create a `PendingInstanceScalePolicy` containing `mapId`, `groupGuid`, `challengeSize`, `compositionMode`, and `generation`.
2. When the instance map is instantiated (`MapInstanced::CreateInstance`), `sScriptMgr->OnInstanceMapCreated(map, player)` triggers before `LoadAllGrids()`.
3. `CoAContentScaling::OnInstanceMapCreated` transfers the policy into `(mapId << 32) | instanceId` so creature spawning and stat calculations immediately reflect the challenge scaling.

### 2. LFG Queue Policy & Separation of Concerns
The queue system previously mixed group size, queue targets, and challenge size. We separated them cleanly:
- **`currentPartySize`**: Actual count of real players entering.
- **`targetPlayers` / `minPlayers`**: Set to `currentPartySize` under `CURRENT_PARTY` mode for instantaneous proposal creation. Under `MATCHMAKING` and `BOT_FILL`, both default to 5.
- **`challengeSize`**: Virtual difficulty multiplier (0 = adaptive, 1 = solo, 2..40 = fixed player equivalent). It never blocks queue formation or requires bots.

### 3. Authoritative Encounter Lifecycle
The lifecycle now enforces an authoritative hierarchy:
```text
INSTANCE_SCRIPT > REGISTERED_ADAPTER > CREATURE_FALLBACK
```
- Only the lock owner (or higher priority source) can advance state or unlock the snapshot.
- Boss stat scaling is generation-gated (`bossAppliedGenerations` map) so double stat scaling is eliminated.
- Council encounters track members in `bossGuids`, ensuring partial deaths do not prematurely terminate encounter contexts.
- Adds and trash never lock or unlock encounter contexts.

### 4. Automated Test Verification
All 24 test suites pass:
- `RBACMultipleInstancesIndependenceTest` (2/2)
- `ProgressionLayoutTest` (15/15)
- `ContentEraResolutionTest` (1/1)
- `ItemBudgetScalerTest` (1/1)
- `InstanceProfileRegistryTest` (1/1)
- `InstanceScalingMultipliersTest` (1/1)
- `InstanceScalingMgrTest` (1/1)
- `EncounterLifecycleSourceHierarchyTest` (1/1)
- `LfgQueuePolicyAcceptanceMatrixTest` (1/1)
