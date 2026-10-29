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

#ifndef ACORE_DBCSTORES_H
#define ACORE_DBCSTORES_H

#include "Common.h"
#include "DBCStore.h"
#include "DBCStructure.h"
#include <list>
#include <string_view>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

typedef std::list<uint32> SimpleFactionsList;

SimpleFactionsList const* GetFactionTeamList(uint32 faction);

// A reputation index belongs to the first faction that uses it; later factions sharing it lose their reputation.
// Returns the released faction IDs with the ID of the faction that keeps the index.
std::vector<std::pair<uint32, uint32>> ReleaseSharedReputationListIds(std::vector<FactionEntry*> const& factions);

char const* GetPetName(uint32 petfamily, uint32 dbclang);
uint32 GetTalentSpellCost(uint32 spellId);
TalentSpellPos const* GetTalentSpellPos(uint32 spellId);

WMOAreaTableEntry const* GetWMOAreaTableEntryByTripple(int32 rootid, int32 adtid, int32 groupid);

// -1 if not found
int32 GetAreaFlagByAreaID(uint32 area_id);
uint32 GetAreaFlagByMapId(uint32 mapid);
AreaTableEntry const* GetAreaEntryByAreaID(uint32 area_id);
AreaTableEntry const* GetAreaEntryByAreaFlagAndMap(uint32 area_flag, uint32 map_id);

uint32 GetVirtualMapForMapAndZone(uint32 mapid, uint32 zoneId);

enum ContentLevels : uint8
{
    CONTENT_1_60 = 0,
    CONTENT_61_70,
    CONTENT_71_80
};
ContentLevels GetContentLevelsForMapAndZone(uint32 mapid, uint32 zoneId);

void Zone2MapCoordinates(float& x, float& y, uint32 zone);
void Map2ZoneCoordinates(float& x, float& y, uint32 zone);

typedef std::map<uint32/*pair32(map, diff)*/, MapDifficulty> MapDifficultyMap;
MapDifficulty const* GetMapDifficultyData(uint32 mapId, Difficulty difficulty);
MapDifficulty const* GetDownscaledMapDifficultyData(uint32 mapId, Difficulty& difficulty);

bool IsSharedDifficultyMap(uint32 mapid);

uint32 const* /*[MAX_TALENT_TABS]*/ GetTalentTabPages(uint8 cls);

uint32 GetLiquidFlags(uint32 liquidType);

PvPDifficultyEntry const* GetBattlegroundBracketByLevel(uint32 mapid, uint32 level);
PvPDifficultyEntry const* GetBattlegroundBracketById(uint32 mapid, BattlegroundBracketId id);

CharStartOutfitEntry const* GetCharStartOutfitEntry(uint8 race, uint8 class_, uint8 gender);

CharSectionsEntry const* GetCharSectionEntry(uint8 race, CharSectionType genType, uint8 gender, uint8 type, uint8 color);

LFGDungeonEntry const* GetLFGDungeon(uint32 mapId, Difficulty difficulty);
LFGDungeonEntry const* GetZoneLFGDungeonEntry(std::string const& zoneName, LocaleConstant locale);

uint32 GetDefaultMapLight(uint32 mapId);

typedef std::unordered_multimap<uint32, SkillRaceClassInfoEntry const*> SkillRaceClassInfoMap;
typedef std::pair<SkillRaceClassInfoMap::iterator, SkillRaceClassInfoMap::iterator> SkillRaceClassInfoBounds;
SkillRaceClassInfoEntry const* GetSkillRaceClassInfo(uint32 skill, uint8 race, uint8 class_);

EmotesTextSoundEntry const* FindTextSoundEmoteFor(uint32 emote, uint32 race, uint32 gender);
typedef std::unordered_map<uint32 /* SkillLine */, std::vector<SkillLineAbilityEntry const*> > SkillLineAbilityIndexBySkillLine;
std::vector<SkillLineAbilityEntry const*> const& GetSkillLineAbilitiesBySkillLine(uint32 skillLine);

AC_GAME_API extern DBCStorage <AchievementEntry>             sAchievementStore;
AC_GAME_API extern DBCStorage <AchievementCriteriaEntry>     sAchievementCriteriaStore;
AC_GAME_API extern DBCStorage <AchievementCategoryEntry>     sAchievementCategoryStore;
AC_GAME_API extern DBCStorage <AreaTableEntry>               sAreaTableStore;
AC_GAME_API extern DBCStorage <AreaGroupEntry>               sAreaGroupStore;
AC_GAME_API extern DBCStorage <AreaPOIEntry>                 sAreaPOIStore;
AC_GAME_API extern DBCStorage <AuctionHouseEntry>            sAuctionHouseStore;
AC_GAME_API extern DBCStorage <BankBagSlotPricesEntry>       sBankBagSlotPricesStore;
AC_GAME_API extern DBCStorage <BarberShopStyleEntry>         sBarberShopStyleStore;
AC_GAME_API extern DBCStorage <BattlemasterListEntry>        sBattlemasterListStore;
AC_GAME_API extern DBCStorage <ChatChannelsEntry>            sChatChannelsStore;
AC_GAME_API extern DBCStorage <CharStartOutfitEntry>         sCharStartOutfitStore;
AC_GAME_API extern DBCStorage <CharSectionsEntry>            sCharSectionsStore;
AC_GAME_API extern DBCStorage <CharTitlesEntry>              sCharTitlesStore;
AC_GAME_API extern DBCStorage <ChrClassesEntry>              sChrClassesStore;
AC_GAME_API extern DBCStorage <ChrRacesEntry>                sChrRacesStore;
AC_GAME_API extern DBCStorage <CinematicCameraEntry>         sCinematicCameraStore;
AC_GAME_API extern DBCStorage <CinematicSequencesEntry>      sCinematicSequencesStore;
AC_GAME_API extern DBCStorage <CreatureDisplayInfoEntry>     sCreatureDisplayInfoStore;
AC_GAME_API extern DBCStorage <CreatureDisplayInfoExtraEntry> sCreatureDisplayInfoExtraStore;
AC_GAME_API extern DBCStorage <CreatureFamilyEntry>          sCreatureFamilyStore;
AC_GAME_API extern DBCStorage <CreatureModelDataEntry>       sCreatureModelDataStore;
AC_GAME_API extern DBCStorage <CreatureSpellDataEntry>       sCreatureSpellDataStore;
AC_GAME_API extern DBCStorage <CreatureTypeEntry>            sCreatureTypeStore;
AC_GAME_API extern DBCStorage <CurrencyTypesEntry>           sCurrencyTypesStore;
AC_GAME_API extern DBCStorage <DestructibleModelDataEntry>   sDestructibleModelDataStore;
AC_GAME_API extern DBCStorage <DungeonEncounterEntry>        sDungeonEncounterStore;
AC_GAME_API extern DBCStorage <DurabilityCostsEntry>         sDurabilityCostsStore;
AC_GAME_API extern DBCStorage <DurabilityQualityEntry>       sDurabilityQualityStore;
AC_GAME_API extern DBCStorage <EmotesEntry>                  sEmotesStore;
AC_GAME_API extern DBCStorage <EmotesTextEntry>              sEmotesTextStore;
AC_GAME_API extern DBCStorage <EmotesTextSoundEntry>         sEmotesTextSoundStore;
AC_GAME_API extern DBCStorage <FactionEntry>                 sFactionStore;
AC_GAME_API extern DBCStorage <FactionTemplateEntry>         sFactionTemplateStore;
AC_GAME_API extern DBCStorage <GameObjectArtKitEntry>        sGameObjectArtKitStore;
AC_GAME_API extern DBCStorage <GameObjectDisplayInfoEntry>   sGameObjectDisplayInfoStore;
AC_GAME_API extern DBCStorage <GemPropertiesEntry>           sGemPropertiesStore;
AC_GAME_API extern DBCStorage <GlyphPropertiesEntry>         sGlyphPropertiesStore;
AC_GAME_API extern DBCStorage <GlyphSlotEntry>               sGlyphSlotStore;

AC_GAME_API extern DBCStorage <GtBarberShopCostBaseEntry>    sGtBarberShopCostBaseStore;
AC_GAME_API extern DBCStorage <GtCombatRatingsEntry>         sGtCombatRatingsStore;
AC_GAME_API extern DBCStorage <GtChanceToMeleeCritBaseEntry> sGtChanceToMeleeCritBaseStore;
AC_GAME_API extern DBCStorage <GtChanceToMeleeCritEntry>     sGtChanceToMeleeCritStore;
AC_GAME_API extern DBCStorage <GtChanceToSpellCritBaseEntry> sGtChanceToSpellCritBaseStore;
AC_GAME_API extern DBCStorage <GtChanceToSpellCritEntry>     sGtChanceToSpellCritStore;
AC_GAME_API extern DBCStorage <GtNPCManaCostScalerEntry>     sGtNPCManaCostScalerStore;
AC_GAME_API extern DBCStorage <GtOCTClassCombatRatingScalarEntry> sGtOCTClassCombatRatingScalarStore;
AC_GAME_API extern DBCStorage <GtOCTRegenHPEntry>            sGtOCTRegenHPStore;
//extern DBCStorage <GtOCTRegenMPEntry>            sGtOCTRegenMPStore; -- not used currently
AC_GAME_API extern DBCStorage <GtRegenHPPerSptEntry>         sGtRegenHPPerSptStore;
AC_GAME_API extern DBCStorage <GtRegenMPPerSptEntry>         sGtRegenMPPerSptStore;
AC_GAME_API extern DBCStorage <HolidaysEntry>                sHolidaysStore;
AC_GAME_API extern DBCStorage <ItemBagFamilyEntry>           sItemBagFamilyStore;
AC_GAME_API extern DBCStorage <ItemEntry>                    sItemStore;
AC_GAME_API extern DBCStorage <ItemDisplayInfoEntry>         sItemDisplayInfoStore;
AC_GAME_API extern DBCStorage <ItemExtendedCostEntry>        sItemExtendedCostStore;
AC_GAME_API extern DBCStorage <ItemLimitCategoryEntry>       sItemLimitCategoryStore;
AC_GAME_API extern DBCStorage <ItemRandomPropertiesEntry>    sItemRandomPropertiesStore;
AC_GAME_API extern DBCStorage <ItemRandomSuffixEntry>        sItemRandomSuffixStore;
AC_GAME_API extern DBCStorage <ItemSetEntry>                 sItemSetStore;
AC_GAME_API extern DBCStorage <LFGDungeonEntry>              sLFGDungeonStore;
AC_GAME_API extern DBCStorage <LiquidTypeEntry>              sLiquidTypeStore;
AC_GAME_API extern DBCStorage <LockEntry>                    sLockStore;
AC_GAME_API extern DBCStorage <MailTemplateEntry>            sMailTemplateStore;
AC_GAME_API extern DBCStorage <MapEntry>                     sMapStore;
//extern DBCStorage <MapDifficultyEntry>           sMapDifficultyStore; -- use GetMapDifficultyData insteed
AC_GAME_API extern MapDifficultyMap                          sMapDifficultyMap;
AC_GAME_API extern DBCStorage <MovieEntry>                   sMovieStore;
AC_GAME_API extern DBCStorage <NamesReservedEntry>           sNamesReservedStore;
AC_GAME_API extern DBCStorage <NamesProfanityEntry>          sNamesProfanityStore;
AC_GAME_API extern DBCStorage <OverrideSpellDataEntry>       sOverrideSpellDataStore;
AC_GAME_API extern DBCStorage <PowerDisplayEntry>            sPowerDisplayStore;
AC_GAME_API extern DBCStorage <QuestSortEntry>               sQuestSortStore;
AC_GAME_API extern DBCStorage <QuestXPEntry>                 sQuestXPStore;
AC_GAME_API extern DBCStorage <QuestFactionRewEntry>         sQuestFactionRewardStore;
AC_GAME_API extern DBCStorage <RandomPropertiesPointsEntry>  sRandomPropertiesPointsStore;
AC_GAME_API extern DBCStorage <ScalingStatDistributionEntry> sScalingStatDistributionStore;
AC_GAME_API extern DBCStorage <ScalingStatValuesEntry>       sScalingStatValuesStore;
AC_GAME_API extern DBCStorage <SkillLineEntry>               sSkillLineStore;
AC_GAME_API extern DBCStorage <SkillLineAbilityEntry>        sSkillLineAbilityStore;
AC_GAME_API extern SkillLineAbilityIndexBySkillLine          sSkillLineAbilityIndexBySkillLine;
AC_GAME_API extern DBCStorage <SkillRaceClassInfoEntry>      sSkillRaceClassInfoStore;
AC_GAME_API extern DBCStorage <SkillTiersEntry>              sSkillTiersStore;
AC_GAME_API extern DBCStorage <SoundEntriesEntry>            sSoundEntriesStore;
AC_GAME_API extern DBCStorage <SpellCastTimesEntry>          sSpellCastTimesStore;
AC_GAME_API extern DBCStorage <SpellCategoryEntry>           sSpellCategoryStore;
AC_GAME_API extern DBCStorage <SpellAffectEntry>             sSpellAffectStore;
AC_GAME_API extern DBCStorage <SpellDifficultyEntry>         sSpellDifficultyStore;
AC_GAME_API extern DBCStorage <SpellDurationEntry>           sSpellDurationStore;
AC_GAME_API extern DBCStorage <SpellFocusObjectEntry>        sSpellFocusObjectStore;
AC_GAME_API extern DBCStorage <SpellItemEnchantmentEntry>    sSpellItemEnchantmentStore;
AC_GAME_API extern DBCStorage <SpellItemEnchantmentConditionEntry> sSpellItemEnchantmentConditionStore;
AC_GAME_API extern SpellCategoryStore                        sSpellsByCategoryStore;
AC_GAME_API extern PetFamilySpellsStore                      sPetFamilySpellsStore;
AC_GAME_API extern std::unordered_set<uint32>                sPetTalentSpells;
AC_GAME_API extern DBCStorage <SpellRadiusEntry>             sSpellRadiusStore;
AC_GAME_API extern DBCStorage <SpellRangeEntry>              sSpellRangeStore;
AC_GAME_API extern DBCStorage <SpellRuneCostEntry>           sSpellRuneCostStore;
AC_GAME_API extern DBCStorage <SpellShapeshiftFormEntry>     sSpellShapeshiftFormStore;
AC_GAME_API extern DBCStorage <SpellEntry>                   sSpellStore;
AC_GAME_API extern DBCStorage <SpellVisualEntry>             sSpellVisualStore;
AC_GAME_API extern DBCStorage <StableSlotPricesEntry>        sStableSlotPricesStore;
AC_GAME_API extern DBCStorage <SummonPropertiesEntry>        sSummonPropertiesStore;
AC_GAME_API extern DBCStorage <TalentEntry>                  sTalentStore;
AC_GAME_API extern DBCStorage <TalentTabEntry>               sTalentTabStore;
AC_GAME_API extern DBCStorage <TaxiNodesEntry>               sTaxiNodesStore;
AC_GAME_API extern DBCStorage <TaxiPathEntry>                sTaxiPathStore;
AC_GAME_API extern TaxiMask                                  sTaxiNodesMask;
AC_GAME_API extern TaxiMask                                  sOldContinentsNodesMask;
AC_GAME_API extern TaxiMask                                  sHordeTaxiNodesMask;
AC_GAME_API extern TaxiMask                                  sAllianceTaxiNodesMask;
AC_GAME_API extern TaxiMask                                  sDeathKnightTaxiNodesMask;
AC_GAME_API extern TaxiPathSetBySource                       sTaxiPathSetBySource;
AC_GAME_API extern TaxiPathNodesByPath                       sTaxiPathNodesByPath;
AC_GAME_API extern DBCStorage <TeamContributionPointsEntry>  sTeamContributionPointsStore;
AC_GAME_API extern DBCStorage <TotemCategoryEntry>           sTotemCategoryStore;
AC_GAME_API extern DBCStorage <VehicleEntry>                 sVehicleStore;
AC_GAME_API extern DBCStorage <VehicleSeatEntry>             sVehicleSeatStore;
AC_GAME_API extern DBCStorage <WMOAreaTableEntry>            sWMOAreaTableStore;
//extern DBCStorage <WorldMapAreaEntry>           sWorldMapAreaStore; -- use Zone2MapCoordinates and Map2ZoneCoordinates
AC_GAME_API extern DBCStorage <WorldMapOverlayEntry>         sWorldMapOverlayStore;

void LoadDBCStores(std::string const& dataPath);
/// Path of a client DBC in the directory LoadDBCStores read, for tables read with ClientDBC.
std::string GetClientDBCPath(std::string_view fileName);

#endif
