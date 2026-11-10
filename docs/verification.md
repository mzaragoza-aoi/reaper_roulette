# Verification evidence

Local test command: `lua tests/run.lua` — **28 passed, 0 failed**.

Local interpreter: **Lua 5.5.1**. The target RuneScape API documents Lua **5.4.8**; a separate 5.4.8 interpreter was not installed on this Mac. The source uses the shared 5.4 syntax and standard-library subset, but host execution remains necessary.

The tests execute the real pool, preferences, reel, controller, view and entry-point code. Only RuneScape-owned globals are replaced with a documented API boundary double. The 10:2:1 draw is checked exhaustively over all 13 ticket values, not statistically. The native double models button toggling, component destruction, ancestor visibility, subscriptions and local database operations; it cannot prove native rendering or disk durability.

Independent read-only review found short-panel overflow and a repeated-save-failure toggle discrepancy. Regression tests reproduced each issue before fixes. The final suite checks controls at 240×200, 200×220 and 425×265, including every settings page and failed-save state. Both findings are fixed; no unresolved code-review findings remain.

Packaging verification (`python3 scripts/package.py`) runs the full suite and syntax validation, validates manifest fields, checks ZIP entries and CRC, and reruns the suite in a temporary extracted directory. The generated checksum is next to the ZIP.

Permission-error regression: the original code failed the new no-Tracking test because rolling remained disabled. The revised entry point uses the documented valid self entity's displayName; both permission arrays are empty. New tests exercise settings and a completed spin with Tracking denied, two named profiles across restart, stale-frame cancellation on name changes, and waiting without database access for missing/invalid entities or empty names.

Blank-Settings regression: the earlier test host incorrectly exposed ui.AlignMode.LEFT. The official enum only has TOPLEFT, CENTRE, BOTTOMRIGHT and JUSTIFY. Restricting the test host and validating AlignTo arguments made the entry-point tests fail at the first label, matching the screenshot's partial construction. Changing the label helper to TOPLEFT makes the 580×300 Settings test render rows and pagination. The roster tests now cover all 66 choices across settings pages, explicitly include Abomination and Char, and verify that expansion preserves existing off/weight values while new entries default to On/1×.

Actual RuneScape-client checks are pending: current beta loader accepting the refreshed permission-free manifest; UI text/clipping at real scale; visible animation cadence; closing and resizing native layers; character switching and delayed entity/name availability; local data surviving client restart. Follow the README checklist. No live-client verification is claimed.
