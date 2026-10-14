# Linux and manual download (CoA Custom 1.7)

Download the same `CoA-Custom-1.7.zip` as Windows. There is no extra client-patch installer.

`Install-Custom.bat` and the shipped `worldserver.exe` are Windows programs. There is no CoA Server Manager build for Linux. A Linux host applies the database and data files, then runs a worldserver built from this repository (or Wine for the bats).

## Apply the database

From `apps/coa-custom`, with the MySQL client that can see `acore_world`:

```sh
sh files/sql/apply.sh /path/to/my.cnf
```

`apply.sh` runs every `files/sql/*.sql` in numeric order (`1_world.sql` before `10_*.sql`). The first install widens `creature_template.family` so retail creature families above 127 do not abort the import.

## Copy the data files

Copy onto the server tree:

- `files/dbc/*.dbc` to `Data/dbc/`
- `files/dbc_clientset/CreatureDisplayInfo.dbc` to `Data/dbc_clientset/`
- `files/bots/spellbook.conf` and `files/bots/mod_ahbot.conf` into the worldserver `configs/modules/` folder, if those files are not already there

Copy onto the machine that runs the Ascension client:

- `files/client/*.MPQ` into the client's `Data/` folder
- `files/client/dinput8.dll` next to `Ascension.exe`, if that file is in the package
- everything in `files/client_root/` next to `Ascension.exe`

The game client itself stays Windows.

## Run the server

Build `worldserver` and `authserver` from this fork the same way AzerothCore is built (`cmake` and `make` in a build directory, with the CoA Bots module you use). Point them at the same `acore_auth`, `acore_characters`, and `acore_world` databases the SQL above updated. Do not run the Windows `worldserver.exe` under Wine and expect the batch installer to manage it.
