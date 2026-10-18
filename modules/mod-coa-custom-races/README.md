# mod-coa-custom-races

Server switch of **CoA Custom** вЂ” extra playable races for Conquest of Azeroth (AzerothCore CoA).

| Key | File | Default |
|---|---|---|
| `CoACustomRaces.Enable` | `coa_custom_races.conf` | `0` |

With `CoACustomRaces.Enable = 0` no character of an added race can be created. Existing characters keep their
data, and the original races are never affected.

The races themselves need the rest of the CoA Custom package:

* **Core patches:** branch `coa-custom-1.5-csm` (CoA Custom commits on top of `Corfirean/azerothcore-wotlk-coa`
  `coa-bots`). They handle race ids above 32, display and talent ids above 65535, racials for every race, custom
  race looks, Wardrobe incarnations on forms, and Gnoll / Saberon / Sethrak appearance.
* **World SQL:** `data/sql/db-world/`. It is idempotent, so it can run on every update and never touches player data.
* **Server DBCs:** The packaged `Data/dbc_races/` overlay is loaded while the module is enabled.
* **Client files:** custom race MPQs (`patch-T.MPQ`, `patch-Z*.MPQ`), the hook `dinput8.dll`, and the Esteria runtime
  (`EsteriaAppearance.dll` / `.bin` files) in the client root.

## Integrated release

The race content is adapted from `coa-custom-1.7`, commit
`760e404239693625eab940791b7036316adccf05` in `ilusixn/azerothcore-wotlk-coa`.
The server overlay comes from `CoA-Custom-1.7-main.zip`
(SHA-256 `6aca7204e76568e9818a3c9f76af09c07c1e4bc0f8a1d2376f62350dd7a70c46`).
Existing overlay-only files remain present. The Grummle world data is adapted into
`data/sql/updates/pending_db_world/rev_20261014_10_custom_races_grummle.sql`;
the upstream executable, installer and whole-table replacement scripts are not used.

Manager combines the complete pinned client assets from the previous release with
`CoA-Custom-1.7-client.zip` (SHA-256
`ad389ef486f44f269445f80807b25b214c39fc5d21272b5708bfeac8b1efefa0`).
The new client archive contains only an overlay and cannot replace the complete Esteria runtime.

The `custom-races-grummle-start` gameplay scenario requires `CoACustomRaces.Enable = 1`
and this checkout's `data/dbc/` files staged as the test DataDir's `dbc_races/` overlay.
It checks fresh Grummle racials and the action bar alongside an unchanged stock racial.

## Manager catalog entry (CoA Server Manager)

```json
{
  "id": "coa-custom-races",
  "name": "CoA Custom Races",
  "description": { "en": "Extra playable races: Jinyu, Sethrak, Gnoll, Saberon, Esteria and Eunoia races and more." },
  "repo": "https://github.com/ilusixn/azerothcore-wotlk-coa",
  "conf": "coa_custom_races.conf",
  "enable_key": "CoACustomRaces.Enable",
  "status": "beta",
  "icon": "races"
}
```

## Credits

* **Kalibros** — Esteria races and the Esteria appearance runtime.
* **Uncle Snowzo** (SnowzoCraft) — Jinyu.
* **Dex** — Drakkin (female).
* **Kalibros** — also Drakkin (male) and Drakonid.
* **Westen** — race lore texts.
* **romaindnd89-cmd** — Prof-bard, the Bard profession module and addon (https://github.com/romaindnd89-cmd/Prof-bard).
* **Furioz, Corruption and the Eunoia team** — Eunoia races.
* **SQUID / Zyth45** — CoA playerbots.
* **Corfirean** — CoA Server Manager, CoA Companions and the `coa-bots` core fork.
* **jealous-sound** — the Conquest of Azeroth AzerothCore core.
* **ilusixn** — CoA Custom.
