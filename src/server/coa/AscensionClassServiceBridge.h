#pragma once

#include "Define.h"
#include "AscensionCoATalentData.h"
#include <string>

class Player;

// Minimal, deliberately narrow bridge into AscensionClassService, which is entirely
// private to AscensionCompat.cpp (defined inside a file-local anonymous namespace, no
// other public header). mod-coa-playerbots needs to actually switch spec and spend a
// bot's paid (AECost/TECost > 0) Ascension talent points through the same
// budget-checked, mutually-exclusive-group-aware path a real player's
// `.localspec`/`.localtalent` commands use, instead of writing PlayerSettings and
// learnSpell()-ing spells directly and silently bypassing the budget check and the
// in-memory active-spec bookkeeping GetActiveSpecialization() depends on.
namespace AscensionClassServiceBridge
{
    // Mirrors AscensionClassService::SwitchSpecialization(player, specializationId)
    // exactly. Returns false if specializationId isn't valid for player's class.
    bool SwitchSpecialization(Player* player, uint32 specializationId);

    // Mirrors AscensionClassService::SetTalentRank(player, entry, rank, error) exactly --
    // same validation order, same budget accounting, same free-choice-group mutual
    // exclusion. Returns false and fills `error` with a human-readable reason on failure
    // (wrong class, spec mismatch, level too low, over budget, etc.); on success the
    // player's spellbook and specialization bookkeeping are already updated, no further
    // action needed by the caller.
    bool SetTalentRank(Player* player, AscensionCompatData::CoATalentEntry const& entry, uint32 rank, std::string& error);
}
