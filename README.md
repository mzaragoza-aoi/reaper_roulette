# Reaper Roulette v0.1.0

A native RuneScape 3 Lua plugin that suggests your next boss. Roll from the plugin ribbon; manage your personal pool using the native Settings gear. Any logged-in character with an enabled boss can roll, regardless of War's Blessing, Reaper's Choice, active tasks, levels or unlocks.

The reel follows `mz/roulette_example.png`: dark panel, equal-width tiles moving right to left, a fixed gold center frame and visible neighboring tiles. The winner's full boss name appears below the reel. The reference image is development material, not a runtime dependency.

**Validation:** the local suite passes, including native API boundary tests. This release has not yet been run inside RuneScape. Use the client checklist below before sharing it publicly.

## Install and enable on Mac

1. Start the RuneScape plugin beta using the links in the official [developer environment instructions](https://developer.runescape.com/rs/tutorial/1helloworld.html#the-developer-environment). Import your save in the beta lobby if needed, then log into a developer world.
2. In Finder, press **Command–Shift–G** and open `~/Jagex/RuneScape-BETA/dev_plugins/`. Create a `reaper_roulette` folder if it does not exist.
3. Extract the ZIP's contents into that folder. `plugin.json` and `main.lua` must be directly inside `reaper_roulette`, with no extra nested folder. This working folder is already in the correct location. For a fresh installation, Terminal commands are:

   ```sh
   mkdir -p "$HOME/Jagex/RuneScape-BETA/dev_plugins/reaper_roulette"
   unzip /path/to/Reaper_Roulette_v0.1.0.zip \
     -d "$HOME/Jagex/RuneScape-BETA/dev_plugins/reaper_roulette"
   ```

4. Open the developer console with **Option/Alt + the key beneath Escape** (normally backtick). Run:

   ```text
   prf
   plist
   pon reaper_roulette
   ```

5. No permissions need to be granted. This build uses the logged-in character's name for local preferences and does not request Tracking, Chat or HTTP access.
6. Open **Plugin Hub → Manage → Reaper Roulette → Settings**. Use **Previous / Next** to reach every boss. Navigation wraps: Next on the last page returns to the first, and Previous on the first page goes to the last. Both buttons are disabled only when the roster fits on one page. Each row has **On / Off**, **− / +** weight controls, and its actual chance (rounded to two decimals). Weight limits are 1× and 10×. Every change saves immediately.
7. Open **Reaper Roulette** from the **Plugins** floating window's ribbon icon. Click **Roll a boss**. Allow approximately two seconds for the gold frame to stop on the selected boss. Try a panel around **425 × 265** interface units; the compact layout also supports **240 × 200**.

If the client cannot find the folder, use `plugins_setpath /Users/YOUR_MAC_USERNAME/Jagex/RuneScape-BETA/dev_plugins`, then `prf` and `plist`. Close the console with the same keyboard shortcut. Use `prl reaper_roulette` after editing source files, and `poff reaper_roulette` to disable it. Ordinary pool changes never require a reload. See [official plugin commands](https://developer.runescape.com/rs/managing.html).

### Updating after the permission error

If the older build shows **“That permission could not be changed. Please try again later.”**, close its Permissions dialog. With the updated files in place, run these developer-console commands in order:

```text
poff reaper_roulette
prf
pon reaper_roulette
```

`prf` rereads the changed manifest. The updated manifest has no required or optional permissions, so the plugin no longer needs the failing Tracking toggle. Then open Settings and test **Roll a boss**. This removes the plugin's dependency on that permission; it does not repair the client's permission dialog. If Tracking still appears as required, the client has retained or loaded an older manifest; restart the beta client and check that its plugin path points to this folder.

### Updating after blank Settings

The build that stopped after **Your boss pool** used an invalid text-alignment enum. This build uses the documented `ui.AlignMode.TOPLEFT`; the test host now rejects unknown alignment values. Close Settings, run `prl reaper_roulette` in the developer console, and reopen Settings. Boss rows and Previous/Next controls should appear. A fresh character's ribbon shows **57 bosses**; saved exclusions reduce that enabled count. If the panel still stops at its heading, check the console for a Lua error and confirm the updated source was reloaded.

## Pool, odds and saved preferences

All 57 boss/encounter choices start **On at 1×**. Existing preferences are preserved when the roster grows; newly added entries default to On/1×. Off bosses have zero tickets and never appear on the reel. Turning a boss Off keeps its weight; changing its weight while Off keeps it excluded. Percentages use only the total enabled weight.

For Rasial 10×, Raksha 2× and Arch-Glacor 1×, the integer draw is 1–13: tickets 1–10 select Rasial, 11–12 Raksha, and 13 Arch-Glacor. The draw happens once before animation. Tile widths are equal, and spins are independent, including repeat winners. One enabled boss wins immediately; an empty pool disables rolling.

Preferences use the documented local PersistentDB and the current character's `Player.GetEntity().displayName`, after checking `isValid`. Jagex explicitly recommends character names or tracking IDs for per-character storage in its [Persistent DB documentation](https://developer.runescape.com/rs/core/persistentdb.html). Different character names have separate pools on this device. Beta and live clients have separate databases. No external requests are made. During login, an unavailable entity or empty name makes the UI wait automatically and offer **Retry**, without reading or writing a shared fallback pool. A failed write keeps the previous settings and displays an error.

Profiles follow the exact character display name: renaming a character starts a new profile, and reusing a name on this device reuses that name's profile. Existing saves from the earlier Tracking-based build remain untouched, but are not automatically associated with a name. This tradeoff allows the plugin to work without a Tracking permission grant.

Closing or replacing the ribbon, leaving the game, changing characters, or changing pool membership cancels a spin and clears its result. Any membership change cancels so disabled neighboring tiles disappear too. Weight-only edits update odds immediately while preserving a spin's original draw.

This plugin suggests a boss only. Reaper's Choice owners can use an eligible suggestion when Death offers a choice; War's Blessing 4 guarantees that opportunity for players who have unlocked Reaper's Choice. The expanded pool also includes encounters that Death cannot assign. Selecting and accepting a task remains the player's in-game action. The personal pool does not automatically filter bosses by the character's combat, quest or encounter-access requirements.

## Local tests and packaging

From the plugin root, with Lua and Python 3 installed:

```sh
lua tests/run.lua
python3 scripts/package.py
```

The packaging script runs all tests, parses every Lua file with `luac`, validates the manifest, builds `Reaper_Roulette_v0.1.0.zip`, checks its contents/CRC, and reruns the tests from an extracted copy. It also writes a `.zip.sha256` checksum. The archive has `plugin.json` at its root and excludes the screenshot, Finder files and scratch material.

Tests cover every requested scenario: all 13 ticket values; unrestricted player access; exclusion from draws and tiles; empty/single pools; off-weight edits and reload; separate characters; delayed identification; repeated clicks; exact final positioning; repeated winners; mid-spin edits; cancellation and stale callbacks; native gear/ribbon wiring; pagination; narrow full-name results; storage errors; short-panel controls; and failed-save toggle recovery. Regression tests also cover saving and spinning without Tracking permission, name profiles surviving restart, and missing/invalid entities or empty names. See [verification notes](docs/verification.md) for the runtime and limitations.

## Check in the actual client

- Confirm manifest loading with no permission grant required, ribbon icon and native Settings gear on the current beta build, with no Lua console errors.
- Inspect fonts, native button states, tile clipping, gold-frame alignment, full-name wrapping and pagination at your UI scale, especially 240 × 200 and 425 × 265 panels. Confirm Next wraps from last to first and Previous wraps from first to last. Test resizing both panels.
- Spin with no blessings, no Reaper's Choice and no active task. Observe roughly two seconds of smooth deceleration; spam clicks and confirm just one spin.
- Disable all bosses, then enable one, then several. Check exact full-name results and live odds. Disable the selected boss mid-spin while both panels are available.
- Close the ribbon or switch characters during a spin, reopen it, and confirm no old winner returns. Also test a world/lobby transition and a plugin reload during animation.
- Set Arch-Glacor to 8×, turn it Off, quit/restart the client, then turn it On. Confirm 8× remains. Repeat with a different character and different preferences; test delayed identification during login.

## Maintenance and public contact

`bosses.lua` is the only roster file. Keep existing IDs stable. New rows default to On/1×. The original 48 Soul Reaper entries remain first, followed by 9 additions from the wiki's broader [combat boss list](https://runescape.wiki/w/Bosses#Combat_bosses) and the requested Char. Croesus and the Gate of Elidinis remain the [skilling boss](https://runescape.wiki/w/Bosses#Skilling_bosses) choices.

The added choices are Abomination, Beastmaster Durzag, Char, Dragith Nurn, Exiled Kalphite Queen, Giant Mimic, Osseous, Tormented wraith and Yakamaru. Use Previous/Next to reach them after the original entries.

ED1, ED2, ED3 and Sanctum of Rebirth each have only their final boss: Seiryu, Black stone dragon, The Ambassador and Nakatra, respectively. Intermediate bosses and WildyWyrm are excluded. Old saved preferences for removed entries stay untouched but cannot add those entries to Settings, the reel or a draw.

Legiones, Dagannoth Kings and the original three Rex Matriarchs remain grouped. Osseous has a separate choice, and the Rex Matriarchs label names its three included bosses. Araxxor/Araxxi form one encounter; normal/hard modes do not create extra entries. Nex and Nex: Angel of Death are separate choices. Sources were checked on **2026-11-10**, using indexed wiki results where direct fetching was blocked or returned an old page. Source details are in [API notes](docs/api-notes.md).

**Before public submission, replace** `REPLACE_WITH_YOUR_PUBLIC_CONTACT_EMAIL@example.com` in `plugin.json` with your public plugin contact email. This is an intentional placeholder.

Source modules: `pool.lua` (ticket math), `preferences.lua` (versioned persistence), `reel.lua` (pure animation), `controller.lua` (state and cancellation), `views.lua` (native UI), and `main.lua` (client integration). Tests use a host boundary double; they do not emulate the game's rendering engine or its on-disk database.
