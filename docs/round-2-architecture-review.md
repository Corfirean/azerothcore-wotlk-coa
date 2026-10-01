# Round 2: Architecture Review & Hardening Audit

**Repository**: `mod-coa-content-scaling`  
**Date**: 2026-10-01  
**Scope**: Deep architectural hardening, lifecycle deterministic ordering, ContentEra resolution, encounter ownership & snapshotting, combat stat application, double-damage scaling elimination, item power bands, and generic LFG composition policy.

---

## 1. Executive Summary & Status Matrix

| Component | Audit Summary | Status |
|---|---|---|
| **Lifecycle & Startup Order** | `InitializeLayout()` called in `OnAfterConfigLoad` before expansion packs registered; structural reload race | **[FIXED]** (Phase 2: Finalize() + two-pass OnLoadCustomDatabaseTable startup) |
| **ContentEra Resolution** | Fallback heuristics promoted Classic lvl58-60 mobs/quests to TBC; lack of confidence & source tracing | **[FIXED]** (Phase 3: EraResolutionResult + strict 8-level priority + MAP_UNSPECIFIED) |
| **Instance Profiles & Classic Raids** | Map 509 (AQ20) misclassified as 40-player raid; hardcoded `if (mapId == ...)` logic | **[FIXED]** (Phase 4: InstanceProfileRegistry explicit 20-man AQ20 & raid sizing) |
| **Encounter Locking & Trash Combat** | Any raid trash mob entering/exiting combat locked and unlocked the global instance context | **[FIXED]** (Phase 5 & 6: boss rank/flags check + GlobalScript::OnBeforeSetBossState) |
| **Pull Stats Recalculation** | Bosses kept stale preview HP from spawn if group size changed before pull | **[FIXED]** (Phase 7: RecalculateEncounterCombatStats on boss pull with frozen snapshot) |
| **Double Damage Scaling** | `context.groupDamageScale` was applied to base weapon damage AND again in `ModifyMeleeDamageTaken` | **[FIXED]** (Phase 8: base damage has no groupDamageScale; single runtime damage hook) |
| **Calibrated Flex HP Integration** | `coa_boss_flex` early-returned from `ApplyCreatureScaling`, bypassing armor, AP, mana, and weapon damage | **[FIXED]** (Phase 9: calibrated HP sets health budget without early-return) |
| **Dead Calculated Stats** | `CalculatedCombatBudget::attackPower` and derived stats were never applied to `Creature` | **[FIXED]** (Phase 10: SetStatFlatModifier, UpdateArmor, UpdateAttackPowerAndDamage, UpdateDamagePhysical) |
| **Content vs Group Normalization** | Content normalization was entangled with group scaling; diagnostics could not inspect breakdown | **[FIXED]** (Phase 11: clean separation of content budget and runtime group multipliers) |
| **ItemBudgetScaler Progression** | Naive `targetMaxIlvl = MaxLevel + 25` collapsed Naxx (200), Ulduar (232), and ICC (277) to the same ilvl | **[FIXED]** (Phase 12: ItemPowerBand monotonic tier progression: Naxx < Ulduar < ToC < ICC) |
| **Rating Scaling & Stat Types** | Generic range check (`12..48`) treated ratings, spell power, resources, and resistances uniformly | **[FIXED]** (Phase 13: ItemModCategory enum and rating conversion deflation) |
| **LFG Composition Modes** | Solo queue unconditionally filled 1/1/3 bots in `mod-coa-playerbots`; no partial group support | **[FIXED]** (Phase 14-25: LfgCompositionMode MATCHMAKING, BOT_FILL, CURRENT_PARTY + partial real groups) |
| **LFG Challenge Size** | Challenge size was not propagated from LFG queue to instance context prior to spawn | **[FIXED]** (Phase 26: OnLfgProposalMadeGroup sets instance challengeSize) |
| **Concurrency & Lock Safety** | `CountEffectivePlayers` iterated map players while holding `InstanceScalingMgr::_lock` | **[FIXED]** (Phase 27: CountEffectivePlayers called outside _lock) |
| **Raid Browser / Raid Matchmaking** | Raid LFG matchmaking | **[DEFERRED]** (Out of scope for Round 2, planned for Phase Later) |
| **Full Manual Encounter Adapters** | Scripted mechanical adaptation for all 100+ TBC/WotLK bosses | **[DEFERRED]** (Foundation first; content tuning scheduled for Round 3) |

---

## 2. Detailed Findings by Subsystem

### 2.1 Startup Order & Lifecycle
- **Risk [FOUND]**: `ProgressionLayout` was instantiated inside `coa_content_scaling_world::OnAfterConfigLoad` before `coa_tbc_content_world` or `coa_wotlk_content_world` were invoked. As a result, `_tbcEnabled` and `_wotlkEnabled` could evaluate to false, collapsing the layout into Classic-only.
- **Remediation Plan**:
  1. Add `ContentPackRegistry::Finalize()` and `IsFinalized()` flag.
  2. Implement an explicit two-pass startup: Content packs register in phase 1; phase 2 finalizes the registry and constructs an immutable `ProgressionLayout`.
  3. Prohibit structural mutations during reload (log warning: restart required).

### 2.2 ContentEra Resolution
- **Risk [FOUND]**: In `ContentPackRegistry::ResolveEraForCreature` and `ResolveEraForQuest`, `authoredLevel >= 58 && authoredLevel <= 70` assigned `ContentEra::TBC`. If a Classic level 60 creature had `cinfo->expansion == 0` and was in Kalimdor or Eastern Kingdoms, it skipped `mapEra != ContentEra::Classic` and erroneously resolved as TBC.
- **Remediation Plan**:
  1. Introduce `EraResolutionResult { ContentEra era; EraResolutionSource source; float confidence; };`.
  2. Implement strict 8-level resolution priority (explicit overrides > map profiles > content pack boundaries > expansion metadata > zone heuristics > fallback).
  3. Ensure level-based heuristics are strictly a last resort and never override Classic world ownership.

### 2.3 Instance Profiles & Classic Raid Sizes
- **Risk [FOUND]**: `InstanceScaleContext.cpp` used hardcoded `mapId` comparisons. Map 509 (Ruins of Ahn'Qiraj / AQ20) was grouped with 40-man raids (`mapId == 409 || mapId == 469 || mapId == 509 || mapId == 531`).
- **Remediation Plan**:
  1. Define a data-driven `InstanceProfile` struct (`mapId`, `era`, `intendedPlayers`, `tier`, `heroicSupport`, `adaptiveSupport`).
  2. Map all Classic raids explicitly: ZG (20), AQ20 (20), MC (40), BWL (40), AQ40 (40), Naxx Classic (40), Onyxia Classic (40).

### 2.4 Encounter Locking & Pull Stat Recalculation
- **Risk [FOUND]**: Any trash creature entering combat in a raid triggered `OnEncounterStart`, freezing the context for the entire instance. Any trash mob or add exiting combat triggered `OnEncounterEnd`, unlocking the snapshot.
- **Risk [FOUND]**: Boss HP was calculated on creature spawn. If players joined or left the instance before the pull, the boss fought with stale participant scaling.
- **Remediation Plan**:
  1. Create `EncounterScaleSnapshot` tracking `encounterId`, `effectivePlayers`, `challengeSize`, `generation`, and state machine (`IDLE`, `ACTIVE`, `COMPLETED`, `RESETTING`).
  2. Restrict encounter locking to authoritative boss engagements (boss rank, BossAI, or registered encounter adapter).
  3. Recalculate authoritative stats on pull from the locked snapshot, maintaining current HP percentage.
  4. Unlock only on boss victory (`COMPLETED`), wipe/evade (`RESETTING`), or instance unload. Adds dying never prematurely unlocks an active encounter.

### 2.5 Double Damage Scaling & Full Stat Application
- **Risk [FOUND]**: `CombatBudgetProfile::CalculateBudget` multiplied `baseMinDmg` by `context.groupDamageScale`. Then `coa_content_scaling_unit::ModifyMeleeDamageTaken` multiplied outgoing melee damage by `ctx.damageScale` again.
- **Risk [FOUND]**: `coa_boss_flex` override returned early, preventing calculation and application of armor, base weapon damage, attack power, and mana.
- **Risk [FOUND]**: Calculated attack power was never applied to creature fields or updated via `UpdateDamagePhysical`.
- **Remediation Plan**:
  1. Separate `ContentCombatBudget` (base normalized stats) from `GroupScaleMultipliers`.
  2. Remove `groupDamageScale` from permanent creature weapon damage. Apply group damage scaling exclusively at runtime via the damage hook.
  3. Refactor `coa_boss_flex` to act strictly as a provider for the HP budget while allowing all remaining combat stats to be calculated and applied.
  4. Explicitly apply armor (`SetArmor`), attack power (`UNIT_FIELD_ATTACK_POWER`), mana, and call `UpdateDamagePhysical`.

### 2.6 Item Power Bands & Rating Classification
- **Risk [FOUND]**: Items with ilvl > `MaxLevel + 25` were scaled with a single linear ratio `targetMaxIlvl / proto->ItemLevel`, collapsing high-tier raid items (Naxx 200, Ulduar 232, ICC 277) to the identical effective item level on compressed realms.
- **Risk [FOUND]**: `proto->ItemStat` scaling lumped all stats (primary, ratings, resistances, spell power) into an arbitrary numeric range (`12..48`).
- **Remediation Plan**:
  1. Introduce `ItemPowerBand` preserving relative progression between raid tiers (Tier 7 < Tier 8 < Tier 9 < Tier 10).
  2. Implement monotonic ordering guarantee: `effectivePower(A) < effectivePower(B) < effectivePower(C)`.
  3. Classify `ItemMod` types into distinct categories: `PRIMARY_STAT`, `SECONDARY_RATING`, `RESOURCE`, `SPELL_POWER`, `ATTACK_POWER`, `DEFENSE`, `BLOCK_VALUE`, `RESISTANCE`.

### 2.7 LFG Composition Modes & BotLfgFill Hardening
- **Risk [FOUND]**: `mod-coa-playerbots/src/BotLfgFill.cpp` intercepted all solo queues and unconditionally spawned bots to fill a 1 Tank + 1 Healer + 3 DPS group. Players could not queue for solo or partial group runs through Dungeon Finder.
- **Risk [FOUND]**: AzerothCore LFG compatibility checks rejected any queue with fewer than 5 players or non-standard roles.
- **Remediation Plan**:
  1. Introduce `LfgCompositionMode` (`MATCHMAKING`, `BOT_FILL`, `CURRENT_PARTY`).
  2. Add generic core hook `OnResolveLfgQueuePolicy(guid, policy)`.
  3. For `CURRENT_PARTY`, bypass 5-player role requirements, prevent matching with foreign queue entries, and form proposals directly with the current party members.
  4. Update `BotLfgFill` to trigger ONLY when `compositionMode == BOT_FILL`, and add support for partial real groups (e.g. 2 players + 3 bots).
  5. Provide player commands `.lfgmode` and `.lfgchallenge`.

### 2.8 Concurrency & Thread Safety
- **Risk [FOUND]**: `InstanceScalingMgr::GetOrCreateContext` called `CountEffectivePlayers(map)` while holding `_lock`. `CountEffectivePlayers` uses `Map::DoForAllPlayers`, which acquires map locks and iterates sessions, presenting a potential inversion/deadlock hazard.
- **Remediation Plan**:
  1. Refactor locking pattern: query map external state outside the lock, then lock to update internal cache.
