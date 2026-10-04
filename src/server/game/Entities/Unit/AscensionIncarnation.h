#ifndef ASCENSION_INCARNATION_H
#define ASCENSION_INCARNATION_H

#include "Define.h"

class Player;

/// Model of the Wardrobe incarnation the player wears for this shapeshift form or form spell,
/// or 0 when none is selected (the form keeps its own model).
uint32 GetAscensionIncarnationDisplay(Player const* player, uint32 form, uint32 spellId);

/// Re-applies the incarnation model when the player changes it while shapeshifted.
void RefreshAscensionIncarnationDisplay(Player* player);

#endif
