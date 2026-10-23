# NPC Enchanter

Beauregard Boneglitter enchants the gear a player has equipped. Vendored from
[azerothcore/mod-npc-enchanter](https://github.com/azerothcore/mod-npc-enchanter) (AGPL-3.0, see `LICENSE.md`).

Changes for the CoA server:

- `data/sql/db-world`: the NPC is written with `ON DUPLICATE KEY` so the script can be applied again, and two placements are
  added (Orgrimmar and Stormwind, next to the War Games organizer). The original module leaves placing the NPC to a GM.
- `Enchanter.CostCopper`: an optional fee per enchantment (default 0 = free, as in the original).
- `Enchanter.Announce` is off by default (the login message advertising the module).
- `Enchanter.Enable = 0` makes the NPC silent; the Manager's Modules page switches this setting.
