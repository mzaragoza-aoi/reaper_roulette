# Reaper Roulette Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task by task.

**Goal:** Deliver the specified native RS3 plugin, tests, Mac instructions and versioned ZIP in this folder.

**Architecture:** Pure roster, pool, preferences and reel modules feed a controller. Native views and a small host entry point handle RS3 events and lifecycle. One draw precedes every multi-boss spin.

**Tech Stack:** Lua, native RuneScape client API, Python stdlib for ZIP packaging.

**Spec:** `docs/design.md` and the user's complete build request.

## Global Constraints

- v0.1.0; plugin.json and main.lua at the plugin root.
- All bosses On at 1x; separate enabled flag and integer 1..10 weight.
- Character-keyed local persistence; no reads or writes without identification.
- Only enabled bosses in draws and tiles; no unlock/task prerequisites.
- Non-blocking two-second reel; cancellation must never show stale results.
- Clearly marked placeholder public contact email.

## Review Focus

- Delayed identity, logout/login transitions, and events from an old settings view.
- Failed or malformed persistence without silently replacing good preferences.
- Membership changes during a spin, including non-winning tiles.
- Native panel replacement, hidden ancestors and narrow/short dimensions.
- Reentrant clicks and queued callbacks arriving after cancellation/new spins.

## Task 1: Domain behavior

Files: bosses.lua, pool.lua, preferences.lua, reel.lua, controller.lua, tests/run.lua.

Interfaces: Pool.entries(roster, prefs), Pool.draw(entries, randomInteger), Pool.ticket(entries, ticket); Preferences.load(db, identity, roster), Preferences.save(db, identity, prefs); Reel.new(entries, winner), Reel.advance(spin, seconds), Reel.tiles(entries, position, width, tileWidth); Controller.new(dependencies) with syncIdentity, edit, roll, cancel, open, close.

- [x] Write deterministic tests for all 13 tickets, defaults, disabled weights, two identities, save failure, delayed identity, single/empty pools and independent repeated wins.
- [x] Run `lua tests/run.lua`; confirm missing implementation failures.
- [x] Implement roster and pure modules plus lifecycle controller.
- [x] Run `lua tests/run.lua`; confirm all domain tests pass.

## Task 2: Native integration

Files: main.lua, views.lua, plugin.json, tests/host.lua, tests/native.lua.

Interfaces: Views.ribbon(root, controller), Views.settings(root, controller); views expose refresh, alive, visible and destroy. Host frame callbacks use Event.Draw.timeDeltaSecs. Following the client's permission-toggle failure, identity uses Player.IsAvailable and the valid Player.GetEntity().displayName, with no permission requirement. Name-profile limitations are documented in README.md.

- [x] Add failing host-boundary tests for native layer events, unrestricted player access, pagination, live odds, click suppression, full names, view closure and stale events.
- [x] Implement the documented native UI and entry point.
- [x] Run `lua tests/run.lua` and native tests; confirm lifecycle cleanup and persistence.

## Task 3: Review and delivery

Files: README.md, docs/api-notes.md, scripts/package.py, Reaper_Roulette_v0.1.0.zip.

- [x] Review implementation against the full spec and official documentation.
- [x] Address important findings with regression tests.
- [x] Run full Lua suite, parse all Lua files, validate manifest and ZIP contents, test extracted ZIP.
- [x] Document local evidence versus required native client checks; package only runtime source, tests and documentation.
