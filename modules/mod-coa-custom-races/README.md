# mod-coa-custom-races

Custom playable races integration for Ascension / Classless Online Adventures (CoA).
Supports Esteria and ilusixn custom races:
- Thin Human, Haranir, Nightborne, Highmountain Tauren, Void Elf, Lightforged Draenei, Earthen, Vulpera, Dracthyr, etc.
- Extended appearance bytes (Esteria appearance protocol HXE1 / HXE2).
- Murloc and custom NPC player display models.
- Dedicated DBC overlays (`Data/dbc_races/`).

## Configuration
In `coa_custom_races.conf`:
```ini
CoACustomRaces.Enable = 0
CoACustomRaces.BotsEnable = 0
```
When `CoACustomRaces.Enable` is 0 (default), all custom race DBC overrides, race creation, and packet appearance extensions are completely inactive.
