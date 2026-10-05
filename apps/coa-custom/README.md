# CoA Custom 1.1: custom races, vanilla classes, more incarnations

An add-on for the **Jealous-Sound CoA repack `main-20260930-df4dea11` with CoA Bots 1.6**. It installs on top of
them the same way CoA Bots does.

## What's new in 1.1

- **Earthen textures fixed.**
  - Male: the face was a squashed patch. He now uses the Dwarf HD textures his own were copied from.
  - Female: her model was the old pre-HD Dwarf female, which the HD textures don't fit. She now uses the HD Dwarf
    female model, with its faces and hair.
- **The installer backs up your accounts and characters first** (also when uninstalling), into
  `CoA-Custom\character-backups\`. It never deletes these backups.

Updating from 1.0: stop the server, extract the 1.1 zip over your `CoA-Custom` folder, and run
`Install-Custom.bat` again. Your 1.0 backup of the original files is kept for `Uninstall-Custom.bat`.

## What it adds

- **21 extra playable races** on both factions:
  - Goblin, Zandalari Troll, Worgen, High Elf, Tuskarr, Kul Tiran, Taunka, Vrykul, Vulpera.
  - Pandaren (Alliance and Horde), Naga, Broken, Fel Orc, Forest Troll, Ice Troll, Skeleton, Earthen, Drakkari Troll.
  - Murloc (Alliance and Horde): an armored Whim murloc as "male", a classic murloc as "female". Several skin
    colours, and an Armor option from none to four armor sets.
- **Every race can play every class**, CoA and classic.
- **Racials**: each new race uses the racials of a base race, plus one bonus racial borrowed from another race. The
  creation screen shows the bonus racial when you hover the race.
- **Classic (vanilla) classes next to the CoA classes**:
  - Real WotLK spells and talents, using Bronzebeard's level-60 tuning.
  - The spells of level 1 on creation; everything else is bought in the Book of Ascension at the normal price.
  - The classic talent window works.
- **Wardrobe incarnations**:
  - The classic classes' forms and pets.
  - Several CoA forms now wear druid, shaman or warlock incarnations. Bloodmage: Eternal Curse → Cat, Accursed
    Form → Metamorphosis. Reaper: Underwalk → Ghost Wolf, Ghost Form → Travel Form. Starcaller: forms → Moonkin.
  - See `INCARNATIONS.md` for the full list.
- **120 characters** per realm and account.

## Before you start

| You need | Why |
|---|---|
| The CoA repack **main-20260930-df4dea11**, started once and working | This build only matches that release; the installer checks it. |
| **CoA Bots 1.6** installed in it | This package replaces the bot worldserver (it is built with the bots). |
| The Ascension game client | The package installs its own `Data\patch-T.MPQ` there. |

**Back up first** (the installer also backs up your accounts and characters, but a full copy is safest):
1. Stop the server with `Stop_All_Server.bat`.
2. Copy your repack folder somewhere safe.
3. Copy `Data\patch-T.MPQ` from your game folder (if you have one).

## Install

1. Close the game. Stop the server (`Stop_All_Server.bat`).
2. Extract the zip **inside your repack folder**. You get `<repack>\CoA-Custom\`, next to `Start_All_Server.bat`.
3. Run `CoA-Custom\Install-Custom.bat`. It:
   - checks your repack and CoA Bots versions;
   - asks for your Ascension game folder (the one with `Ascension.exe`);
   - backs up your accounts and characters into `CoA-Custom\character-backups\`;
   - backs up everything it will replace into `CoA-Custom\backup\`. This includes `worldserver.exe`, 15 server DBC
     files, `patch-T.MPQ`, two settings templates and the 60 world tables it changes;
   - copies the files, applies `files\sql\1_world.sql`, then starts the server with CoA Bots.
4. Start the game when the worldserver says it is ready.

Want to see what it would do first? Run `Install-Custom.bat --check`; it changes nothing.

After that, start the server with `CoA-Bots\Start_All_Bots.bat`, as with CoA Bots.

## Uninstall

Run `CoA-Custom\Uninstall-Custom.bat`. It puts back the backed-up files and world tables and removes the
`custom_race_display` table.

Characters of the extra races, or race/class pairs only this package allows, can't log in without it.

## Known problems

- The client can crash when you close it (`0x008CFF83`). It started with the extra races; the cause is unknown.
- Tuskarr legs miss a piece: the model has no leg geosets.
- In game the Murloc wears an NPC look, so armor doesn't show on it.
- The Murloc can't preview gear in the Wardrobe.
- Murloc gear is hidden on the character list.

Found a bug? Open an issue on this repository. Say:
- the race, class and gender;
- what you did, and what you expected;
- a screenshot if it's visual. For crashes, add the newest file from `CoA-Bots\Core\Crashes`.

## Source and rebuilding

- **Server C++**: branch `coa-custom` of this fork, 17 commits on top of Jealous-Sound's `df4dea11`. Build it like the
  repack's core, together with Zyth45/mod-playerbots `b9413a1d` (the CoA Bots module).
- **Data and client patch**: the scripts in `scripts\` (Python 3 with `mpyq`, `numpy`, `Pillow`). They read the
  Ascension client and the repack's original DBC files and write the DBCs, SQL, models and Lua of `patch-T.MPQ`.
  - Client pipeline:
    `mpqget.py` → `make_player_models.py` → `make_murloc_model.py` → `gen_races.py` → `gen_race_looks.py` →
    `patchlua*.py` → `build.py`.
  - Classic classes: `gen.py`, `gen2.py`, `gen_talents.py`, `gen_outfits.py`, `gen_racial_combos.py`,
    `gen_appearance_categories.py`.
  - The scripts were written for one machine. Paths such as `C:\CoA-Repack` and `C:\Ascension Local` are at the
    top of each file.
- `files\sql\1_world.sql` is generated. It compares a server with every change against the repack's clean database,
  and is checked by applying it to a clean copy and comparing again.

Most of this work was done with an AI coding assistant, then tested in game.

## Credits

- Jealous-Sound for the CoA core and repack.
- The CoA Bots Squid authors and Zyth45/mod-playerbots.
- AzerothCore.
- The race models, textures and client data come from the Project Ascension client.
