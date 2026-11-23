# BotsHub 2.0, v10-improved: analysis report

Scope: the whole v10 package (`BotHub2.0/`, 80 `.au3` files, about 54.9k lines).
Baseline: upstream commit `ca18c0c` (see `VERSION`) plus the v3–v10 fixes in `CHANGELOG-FIXES.md`.
Target: Guild Wars 1 only.

Constraints followed:
- The entry point (`BotsHub.au3`) and the folder layout are unchanged.
- No memory offsets, patterns, packet headers or assembly were changed.
- No farm routes or skill logic were changed, except to add bounds and failure propagation.

---

## 1. Architecture

### Language and runtime
- AutoIt v3 (3.3.16.1 or later; tested with 3.3.18.0). It must run as 32-bit (x86) with `#RequireAdmin`, under `Opt('MustDeclareVars', True)`.
- The game interface is **GWA2**:
  - `lib/GWA2*.au3` reads process memory with ReadProcessMemory against pattern-scanned offsets.
  - It injects assembly stubs to send packets through a command queue (`Enqueue`/`SendPacket`).
- Storage is SQLite (`lib/SQLite*.au3`, `sqlite3.dll`) for optional loot data collection.

### Layers
```
BotsHub.au3                      entry point, run modes, main state machine, config load/save/validation
 ├─ lib/BotsHub-GUI.au3          GUI (OnEvent mode + WM_COMMAND/WM_NOTIFY handlers), stats, tools tab
 ├─ lib/BotsHub-Constants.au3    NEW: every timeout / retry limit / watchdog knob in one place
 ├─ lib/Utils-Console.au3        leveled logging (console + NEW log file + level filter + counters)
 ├─ lib/Utils-Session.au3        NEW: session statistics, per-run CSV, exit summary, start-up diagnostics
 ├─ lib/GWA2*.au3                memory/packet layer (unchanged except the Disconnected() logic fix)
 ├─ lib/Utils.au3                movement, NPC/agent interaction, combat loops (MoveAggroAndKill, KillFoesInArea...)
 ├─ lib/Utils-Agents.au3         party state, wipe detection (TrackPartyStatus, IsRunFailed, HasRezMemberAlive)
 ├─ lib/Utils-Storage.au3        inventory management: identify/salvage/sell/store/buy, consumables
 ├─ lib/Utils-Shared_Memory.au3  master/slave shared memory (headless multi-client)
 ├─ lib/Build_PW_Heroic-Refrain  Paragon HR build helper
 ├─ src/LoadWaitHelpers.au3      Robust* wrappers, NEW bounded-retry, instance and reconnect helpers
 └─ src/{farms,missions,runs,titles,utilities,vanquishes}/*.au3   57 farm entries (one file per farm)
```

### Run modes
- **GUI mode** (no arguments): pick a character and a farm, then Start/Pause.
- **Headless mode** (4 arguments: `slaveIndex PID characterName farmName`):
  - Started by a master hub.
  - Sends a heartbeat through shared memory.
  - The master can show or hide the slave GUI.

### Main control flow
```
BotsHubMain → SessionStart, diagnostics, FillFarmMap, LoadDefaultRunConfiguration (+ validation), loot config
           → GUI or headless attach (Authentification → InitializeGameClientForGWA2)
BotHubLoop  (UNINITIALIZED → INITIALIZED → RUNNING → WILL_PAUSE → PAUSED → RUNNING)
  └ RunFarmLoop   per run: EnsureGameConnected → inventory management → GeneralFarmSetup (once)
                  → $farm_map[name][1]() → stats / session / watchdog
```

### Farm pattern
Every farm function returns `$SUCCESS` (0), `$FAIL` (1) or `$PAUSE` (2). The usual shape is:
```
XFarm():   If Not setup And SetupX() == FAIL Then Return PAUSE
           If GoToX() == FAIL Then Return FAIL        ← NEW: GoToX is bounded and reports failure
           result = XFarmLoop()                       (MoveAggroAndKill / KillFoesInArea waypoints)
           Resign / travel back; Return result
```
- `$PAUSE` stops loop mode.
- `$FAIL` is counted, and the next run starts again from the outpost.
- AutoIt quirk: `'' == 0`, so a function that returns nothing counts as SUCCESS. This was checked: all 57 farm entry functions end with an explicit `Return`.

### Party and wipe tracking
- `AdlibRegister('TrackPartyStatus', 10000)` counts 10-second ticks in which the player and every rez-capable hero are dead.
- `IsRunFailed()` returns True when any of these holds:
  - more than 5 such ticks;
  - NEW: the first wipe, when "Return on death" is enabled;
  - NEW: the hard run deadline has passed.

### Configuration
- `conf/farm/*.json` holds the run/team/follower options. The keys are dotted (`run.loop_mode`) and are stored as nested objects.
- `conf/loot/*.json` holds the loot tree.
- All option keys live in `$run_options_cache`. `PERSISTED_OPTION_KEYS` (NEW) is the single list that load, save and validation all share.

---

## 2. Method and verification tooling

Everything below was run offline under Linux, using a portable Wine 9.22 and the official AutoIt 3.3.18.0. The tooling lives in `/workspace/gw1bot/tools/` and is not part of the package.

| Tool | What it checks |
|---|---|
| `Au3Check.exe -q -d -w 1..7` (via `tools/verify.sh`) | Full parse, every include resolved, undefined functions, wrong argument counts, undeclared variables. Run after every batch; the warnings are diffed against the original baseline. |
| `tools/au3lint.py` (custom) | Block balance (If/While/For/Switch/Func), duplicate `Func` definitions, calls to functions defined nowhere, and a heuristic **unbounded wait-loop detector**. |
| `tools/bound_entries.py`, `tools/guard_skill_loops.py` | Mechanical, reviewable rewrites of the map-entry and skill-spam loop patterns (dry-run report first, then apply). Every hit was reviewed by hand in the diff. |
| `tools/tests/test_config.au3` (40 tests) | Config loader: partial configs, invalid JSON, clamps, round-trip of every persisted key (value **and type**), all shipped configs, validation (problem counting), save adds `.json`, missing-file handling, session statistics, CSV quoting, duration format. |
| `tools/tests/cmp_o/cmp_n.au3` (differential) | Runs the **original** and the **new** loader on every shipped config and compares every resulting setting. Only the two intended differences show up (`bonder_mode` default, new `debug_logging` key). |
| `tools/tests/test_recovery.au3` (23 tests) | Disconnect detection (frozen clock, stuck loading screen, missing agent, never-verified clock must not raise a false alarm), `Disconnected()` refusing to send keys without a window, bounded attempt helpers (exact attempt counts), `CastUntilRecharging` (stop, time-out, dead player), `RobustWaitMapLoading` (resigns only in explorables), `WaitForNewInstance` (old instance rejected, fresh instance accepted, bounded). Game reads are simulated by stubs. |
| GUI smoke test (Xvfb + Wine) | The real `BotsHub.au3` starts, builds the whole GUI, loads both default configs, validates them, logs to file, and on exit writes the session summary and the CSV. No runtime errors. |
| Headless smoke test | Wrong PID / unknown farm: logs an error, the dialog closes by itself after 30 s, exit code 1. Before the fix, the slave hung forever on a modal box. |

Final state:
- Au3Check: **0 errors**. There are 47 warnings, all "possibly used before declaration" (cross-include global order, benign at run time). The original had 45 of the same kind; the extra ones come from new references to existing globals.
- Block issues: 0. Duplicate functions: 0.
- Unit tests: 63/63 pass. Differential: identical.
- `tools/run_tests.sh` re-runs everything.

---

## 3. Issues found

Severity scale:
- **Critical**: the bot hangs forever, crashes, or reports a wrong result that hides failures.
- **High**: wrong behaviour that costs time, items or gold, or breaks a feature.
- **Medium**: a degraded or broken option, a resource leak, or a fragile path.
- **Low**: cosmetic issues and dead code.

### 3.1 Critical (16 found, 16 fixed)

| ID | Where | Issue | Root cause | Status |
|---|---|---|---|---|
| C1 | `Utils.au3` FanFlagHeroes | Script crash ("array index out of range") with 1, 2, 4 or 6 heroes, e.g. when a hero could not be added. | `Case Else` built an empty array that was then indexed. | Fixed: default order `[1..7]`, plus a divide-by-zero guard when a foe stands on the player. |
| C2 | 24 farms: `GoTo*`/`LeaveTo*`/`Enter*Mission` | Infinite loop when the portal or NPC can't be used (no access to the zone, wrong spawn, blocked portal, failed dialog). | `While GetMapID() <> target` with no attempt limit. Callers ignored the result. | Fixed: `MapEntryAttemptAllowed` (5 attempts). The function returns `$FAIL` and every call site (41 in total) propagates it, so the run fails and the next run retries from the outpost. |
| C3 | Froggy, SoO, SpiritSlaves, Vaettirs setup | Infinite retry of the "run to dungeon" setup. | `While Not $setup ... ContinueLoop` with no limit. | Fixed: `SetupAttemptAllowed` (3 attempts). The farm then returns `$PAUSE`. |
| C4 | Froggy (5), SoO (5), Tunnels (2), Voltaic (2) | Dungeon portal, door and "end of dungeon" waits loop forever if the load is missed. Tunnels even kept trying the door after a party wipe. | `While Not $mapLoaded` / `While Not RobustWaitMapLoading()` with no limit. | Fixed: bounded, and failure propagates (sets `setup=False` where the dungeon state is lost). Tunnels checks `IsRunFailed()` before the door. |
| C5 | Corsairs, Nexus Challenge, Sunspear Armor | Same-map-ID mission entries loop forever. | Spawn-coordinate check with no limit. | Fixed: bounded, and callers propagate `$FAIL`. |
| C6 | `Utils.au3` MoveTo | Can circle or rubber-band forever (IsPlayerMoving stays True, target never reached). | The only bound was "not moving for more than 14 polls". | Fixed: overall timeout of max(45 s, 3× the walk time at base speed). Warns and returns False. |
| C7 | `Utils.au3` AggroAgent | Infinite loop when the foe dies or despawns before aggro. | It waits for an animation change that never comes. | Fixed: returns on ID 0, a dead foe, or after 20 s. |
| C8 | `Utils.au3` GoNearestNPCToCoords | Two infinite loops (no NPC there; NPC unreachable). | No bounds. | Fixed: 10 s / 30 s limits, returns True/False. |
| C9 | UseSkillSequentially, HRCombat | Fight never ends against an invulnerable, unreachable or fleeing target. | It loops while the target is alive. | Fixed: 60 s per-target limit, then re-target (overridable through the `targetTimeout` option). |
| C10 | 23 skill loops in 12 files (incl. the adlib `UseDeadlyParadox`) | `While IsRecharged(x)` spam / `While Not IsRecharged(x)` waits never end when the skill can't be cast (no energy, invalid target, empty slot). An adlib that blocks freezes the whole script. | No time limit. | Fixed: 10 s cast limit, 90 s recharge-wait limit (ExitLoop keeps the following code unchanged). |
| C11 | Raptors, DrakeFlesh | Mark of Pain target selection cycles forever when every nearby foe is already hexed. | `While GetHasHex(target)` cycling targets. | Fixed: at most 10 re-targets. |
| C12 | ManageFactionPointsFarm | Infinite loop donating faction points when the guild isn't allied with that faction. | The donation silently fails, and the loop condition never changes. | Fixed: stops after 3 donations that don't change the balance, with an explicit warning. |
| C13 | Map loading (same map ID transitions) | `WaitMapLoading(-1)` returned at once because the old instance still looked "loaded", so farms moved during the loading screen. | No detection of the instance change. | Fixed: `WaitForNewInstance()` waits until the player agent disappears or the instance clock restarts. It returns at once if the instance is already fresh and is bounded at 20 s; after a timeout the previous load wait runs as before. |
| C14 | Headless start | If attaching failed, the farm still ran against an unattached client (garbage memory reads, random actions). | The `Authentification` result was ignored. | Fixed: logs an error and exits with code 1. |
| C15 | EnterFissureOfWoe / EnterUnderworld | Without a passage scroll the function returned SUCCESS and the farm ran inside the outpost. | Missing `Else` branch. | Fixed: logs an error and returns `$PAUSE`. |
| C16 | MoveAggroAndKill | A party wipe inside the fight handler was reported as SUCCESS. | `ExitLoop` followed by `Return $SUCCESS`. | Fixed: returns `$FAIL`. `MoveAggroAndKillSafeTraps` now returns the result too. |

### 3.2 High (15 found, 15 fixed)

| ID | Where | Issue | Root cause | Status |
|---|---|---|---|---|
| H1 | HasRezMemberAlive | Wipe detection used the rez-hero list of the **first** party of the session, so after a farm or team change, wipes were missed or invented. | `Static` cache that was never refreshed. | Fixed: recomputed when the party signature (map + hero agent IDs) changes. |
| H2 | FindHeroesWithRez | A hero with two rez skills was listed twice; with 7 heroes this overflowed the array. | No `ExitLoop` after a match. | Fixed. |
| H3 | ReadConfigFromJson | A config missing a key (older or hand-edited file) overwrote the default with `""`. For example, a missing `run.loop_mode` meant a pause after every run, and a missing `run.district` sent travel to an invalid district. | `_JSON_Get` returns `""` for absent keys. | Fixed: `ConfigGet(key, default)` changes a setting only when the key is present. |
| H4 | Config load/save | 19 newer options (return on death, log chests, auto-attach, extract upgrades only, skip Am Fah, all follower options...) were never saved or loaded. | They were missing from the hand-written load/save lists. | Fixed: one shared `PERSISTED_OPTION_KEYS` list; round-trip tested. |
| H5 | LoadRunConfiguration | An unreadable or invalid JSON file was applied as empty, wiping the settings. | No FileOpen or parse error handling. | Fixed: error logged, settings kept, returns False. |
| H6 | GUI WM_COMMAND handler | Picking a character could re-inject GWA2 several times and show MsgBoxes **inside a window-message handler** (re-entrancy, frozen GUI). | Auto-attach ran on every combo notification. | Fixed: removed. The OnEvent selection handler already does it once. |
| H7 | Tools tab | Ecto→gold, gold→lockpicks and extract upgrades could run **while a farm was running**, so two scripts drove the character at once. | No state check. | Fixed: refused in RUNNING and WILL_PAUSE. |
| H8 | Start / Attach | Start re-ran the full pattern scan and injection even when already attached through Tools; Attach did the same for the same character. | No "already attached" check. | Fixed. `$attached_for_tools` is now set by any successful attach. |
| H9 | BuyRareMaterialFromMerchantUntilPoor | Could spend far below the configured "poor" threshold. | The amount was computed once from the first quote, but rare material prices rise with every purchase. | Fixed: re-checks the quote and the remaining gold before every buy. |
| H10 | Main loop | A farm failing every run (wrong build, missing access, bad spot) looped forever. | No watchdog. | Fixed: pauses after 10 consecutive failures (`MAX_CONSECUTIVE_FAILED_RUNS`). **v24: removed at AMG's request; replaced by the stuck watchdog (§21.3).** |
| H11 | Logging (headless) | Headless slaves had **no log output at all**. | Logging only wrote to the GUI rich-edit control (handle 0 when headless). | Fixed: daily log file `logs/botshub-YYYY-MM-DD[-character].log`, plus stdout fallback. |
| H12 | GWA2 `Disconnected()` | No reconnect handling at all: the function was never called, its "give up" branch could never be reached (endless loop), and the first attempt waited 60 s. | Branch-order bug; never wired in. | Fixed and wired in: before each run, `EnsureGameConnected()` detects a dropped connection (confirmed over 30 s), presses Reconnect up to 3 times, resets farm setups, or pauses the hub. Never sends keys without a known game window. |
| H13 | Headless error paths | Wrong PID, unknown farm or bad arguments showed a **modal MsgBox that never closed**, so the slave hung forever (the master saw no heartbeat and no exit). | Plain MsgBox. | Fixed: error logged, the dialog closes by itself after 30 s, exit code 1 (tested). |
| H14 | UpdateHeartbeat (slave) | Hiding and then showing the slave GUI created a **second GUI**: duplicate window, every control ID re-assigned. | `CreateBotsHubGUI()` on every "enable GUI" order. | Fixed: created once, then shown/hidden. |
| H15 | Corsairs WaitForEnemyInRange / WaitForBohseda, DrakeFlesh adrenaline wait | Unbounded waits (no enemy ever comes in range; energy/recharge never reached; adrenaline never exactly 130). | No time limit. | Fixed: 60 s / 120 s / 30 s limits. |

### 3.3 Medium (14 found, 14 fixed)

| ID | Where | Issue | Status |
|---|---|---|---|
| M1 | GoToAgent | `$me` was empty on the first distance check, so the distance was measured from (0,0). | Fixed: snapshot first, plus a 30 s timeout. |
| M2 | DistrictTravel | An unknown district name (hand-edited config) crashed with a subscript error. | Fixed: warns once and uses Random EU. |
| M3 | KillFoesInArea | 100% CPU memory-read spin while the player is dead and heroes are still fighting. | Fixed: 250 ms sleep while dead. |
| M4 | CollectHeroesEffects | The hero count was `Static`, so it went stale after a party change. | Fixed. |
| M5 | "Return on death" option | Stored but never read: no effect. | Fixed: `IsRunFailed()` fails the run at the first wipe when it is enabled. |
| M6 | "Log chest spawns" option | Stored but never read. | Fixed: logs gadget, position and map in FindAndOpenChests. |
| M7 | ApplyConfigToGUI | The newer checkboxes and the follower controls were not refreshed when a config was loaded. | Fixed. |
| M8 | Follower | The leader-name input had no event handler, so it was never stored or saved. Headless follower read a GUI control that doesn't exist. | Fixed: event handler; the live GUI value is used when there is a GUI, the saved value otherwise. |
| M9 | Save configuration | FileSaveDialog doesn't add `.json`, so the file was invisible to the config combo and had a mangled name. | Fixed. |
| M10 | Log console | The rich-edit console grew without limit and got slow over long sessions. | Fixed: trimmed at 400k characters (the full history is in the log file). |
| M11 | UseMoraleConsumableIfNeeded | Unbounded, and with a 50 ms wait a laggy connection could burn extra morale boosters before the server update arrived. | Fixed: 500 ms + ping wait, at most 10 boosters per call. |
| M12 | `$map.Exists()` (6 call sites) | A method-call syntax on Maps that isn't documented in AutoIt (it works in 3.3.18 but is fragile). | Fixed: replaced with `MapExists()`. |
| M13 | MoveAggroAndKillSafeTraps | Dropped the MoveAggroAndKill result. | Fixed (part of C16). |
| M14 | UpdateHeartbeat | Two Info lines every 5 s, about 35k log lines a day per slave. | Fixed: moved to Debug level. |

### 3.4 Low (5 found, 5 fixed)

| ID | Issue | Status |
|---|---|---|
| L1 | `follower.bonder_mode` default `'Monk'` is not a value of the Bonder combo. | Fixed: `'None'`. |
| L2 | `run.sort_items` was read twice in ReadConfigFromJson. | Fixed by the rewrite. |
| L3 | OpenPickWindow (dead code) busy-spun at 100% CPU, because `GUIGetMsg` returns immediately in OnEvent mode. | Fixed: `Sleep(20)`. |
| L4 | RobustTravelToOutpost added a redundant ~2.5 s second load wait (TravelToOutpost already waits and verifies) and never retried. | Fixed: no second wait, one retry. |
| L5 | Dead code: an unreachable `$farm == Null` block in RunFarmLoop, `If True Then` in ApplyDeathReturnOption, unused `UpdateInventoryStatus` and `$return_on_death`. | Removed or simplified. |

### 3.5 Found but deliberately not changed (9)

| ID | Sev. | Issue | Reason not changed |
|---|---|---|---|
| N1 | Low | `TrackPartyStatus` counts 10-second ticks while wiped, not distinct wipes, so "6 wipes" can mean one long wipe. | Long-standing upstream design; changing it would change when every farm gives up. "Return on death" now covers the strict case. |
| N2 | Low | "Reset stats" (Tools) only resets the labels; UpdateStats' internal counters keep counting. **Fixed in v15 (§12).** | Cosmetic. The session summary and CSV are the authoritative statistics now. |
| N3 | Low | `ResetBotsSetups()` doesn't list every farm's setup flag. | Upstream comment: those farms travel to their outpost every run by design. |
| N4 | Medium | Same-map-ID missions (Moddok, Nexus, Dajkah, Gemstones) detect "entered" through spawn coordinates. | Can't be improved without live data. Now bounded (C5). |
| N5 | Medium | Follower picks the named leader through the agent struct `Name` field. | Needs live verification; offset and struct layout are out of scope. |
| N6 | Info | 47 Au3Check "possibly used before declaration" warnings. | Cross-include global ordering; harmless at run time (globals are initialised before `BotsHubMain()`). |
| N7 | Low | `IsRunFailed()` logs a Notice on every call once a run has failed. | A few lines per failed run; the loops exit right away. |
| N8 | Low | Several farms ignore their setup function's result (`If Not setup Then SetupX()`). | Every downstream step is now bounded and fails cleanly; changing it would alter when those farms pause. |
| N9 | Info | Chest lookups compare missing Map keys with `Null`. | Verified under AutoIt 3.3.18: a missing key returns `Null`, so it is correct. |

**Totals:**
- Found: 59.
- Fixed: 50 (Critical 16, High 15, Medium 14, Low 5).
- Not changed, with documented reasons: 9.

---

## 4. Improvements (beyond bug fixes)

| Area | Improvement |
|---|---|
| Reliability | Every portal, setup, dungeon, mission, NPC, aggro, fight and skill wait is now bounded. The bounds return `$FAIL`, so the existing hub loop handles recovery and the Pause button keeps working. A per-run hard deadline (max(4× expected duration, 30 min)) backs this up for the long `While Not IsRunFailed()` loops. |
| Recovery | Disconnect detection and reconnect before every run; consecutive-failure watchdog; map-load verification for same-ID transitions; travel retry. |
| Diagnostics | Log file per day and per character; levels in the file; Debug level switchable with `run.debug_logging`; start-up environment line (AutoIt version, OS, admin rights, folder); warning and error counters. |
| Statistics | `logs/runs-YYYY-MM-DD.csv` (date, time, character, farm, result, duration, total gold); one session line after each run; session summary on exit (runs, success rate, average and longest run, gold change, warnings/errors). Works headless too. |
| Config | Partial or old configs are safe; all options persist; config validation (unknown farm, district, loot config, hero names, empty build templates, conflicting faction options) is reported at load time. |
| Maintainability | `lib/BotsHub-Constants.au3` holds every tunable limit; one list of persisted keys; reusable `MapEntryAttemptAllowed` / `SetupAttemptAllowed` / `CastUntilRecharging` / `WaitForSkillRecharge` helpers. |
| Timing | A random 1–3 s gap between runs (it was a fixed 1 s). The existing `RandomSleep` jitter and random-district travel are unchanged. |
| Performance | No busy spins left in dead-player fights or the pick window; console trimming; heartbeat log spam removed. Disconnect check cost: about 1.5 s per run. |

---

## 5. What could not be verified offline

These need a live Guild Wars client:
1. **Memory and packet layer**: all offsets, patterns and injected assembly, including `GetInstanceUpTime` (used by `WaitForNewInstance` and disconnect detection) and the agent struct `Name` field (Follower).
2. **Reconnect**:
   - whether the disconnect dialog really shows as stuck loading, missing agent, or frozen instance clock;
   - whether `{Enter}` triggers Reconnect.
3. **Timing of the new bounds** in real farms: none should trigger in a normal run (they are 3–10× the normal durations). If one does, the log shows which.
4. **Combat behaviour, routes and drops**: unchanged, but only verifiable in game.
5. **Master/slave hub interplay**: heartbeat, GUI show/hide, exit codes seen by the master.
6. **SQLite data collection** against a real database.

---

## 6. Live testing checklist

Do these on a character with **nothing valuable in its inventory**. Keep the log file open: `logs/botshub-<date>-<character>.log`.

**Start-up**
- [ ] The first lines show `BotsHub 2.0 (v10-improved) | AutoIt … | admin yes`. If it says `admin NO`, restart AutoIt as administrator.
- [ ] No `Config check:` warnings with your normal config. If there are any, they name the exact setting.
- [ ] Load a saved config. All Options checkboxes, including *Log chest spawns*, *Auto-attach*, *Return on death* and *Extract upgrades only*, and the Follower tab show the saved values.
- [ ] Save a config with a name typed without `.json`. It appears in the config list.

**Attach**
- [ ] Tools → Attach, then press Start for the same character. The log should **not** show a second injection or scan (`Already attached` / no long pause).
- [ ] With *Auto-attach* ticked, picking a character attaches **once** (one dialog, no repeated boxes).
- [ ] While a farm runs, Tools buttons answer "Pause the farm…" and do nothing.

**Normal runs** (do 3+ runs on 2–3 of your usual farms)
- [ ] Runs behave exactly as before.
- [ ] After each run, `Session: N runs, … ok, … failed` appears.
- [ ] `logs/runs-<date>.csv` gets one line per run, with total gold.
- [ ] **No** `timed out`, `could not be cast within`, `Could not enter … after 5 attempts`, `exceeded its hard deadline` or `Target not killed after 60s` lines during *normal* runs. If you see one, note the farm and the line: that bound is too tight for that spot.
- [ ] Map transitions with the same map ID (Voltaic Justicar area, Urgoz Warren, dungeon floors) don't start moving during the loading screen.

**Failure handling**
- [ ] Pick a farm whose outpost the character can't reach. You should see `Travel failed, retrying once` and `Could not enter … after 5 attempts`, then the run fails (v24: the bot keeps looping; the 10-failure pause was removed, see §21.2).
- [ ] FoW/UW without a passage scroll: `No Passage Scroll … pausing` and the hub pauses (it no longer farms inside the outpost).
- [ ] Tick *Return on death*: at the first party wipe the run fails and the bot returns to the outpost.
- [ ] Untick it: the old behaviour (fails after ~6 wiped checks) is unchanged.
- [ ] A team with 1, 2, 4 or 6 heroes on a farm that flags heroes (SoO): no crash.

**Disconnect** (pull the network cable for ~1 minute between two runs, or wait for a real disconnection)
- [ ] The log shows `Disconnected. Attempting to reconnect.`, then `Reconnected!` (or `Could not reconnect` → `Game client is disconnected, pausing.`).
- [ ] Watch that the Enter key goes to the **Guild Wars** window (it should press the Reconnect button).
- [ ] Also check for false alarms: during a normal session, `Disconnected` must **never** appear.

**Economy**
- [ ] Rare material buying (if used) stops at your threshold; the log shows `Bought N rare materials`.
- [ ] Morale boosters: at most one booster per real morale problem.
- [ ] Faction donation with a guild not allied to that faction: one warning, no endless loop.

**Headless / master-slave** (if you use it)
- [ ] Start a slave with a wrong PID. It exits after ~30 s with an error in its log; it doesn't hang.
- [ ] Toggle the slave GUI off and on twice. Only one window should ever exist.
- [ ] The slave log file doesn't fill with heartbeat lines (set `"debug_logging": true` in the config to see them).

**Exit**
- [ ] Close the hub. The last log line is `Session summary (...)` with runs, success rate, gold change and warning/error counts.

---

## 7. Item & mod audit

### 7.1 Reported problem

With *Extract upgrades only* and an Expert or Superior salvage kit, two upgrades were never pulled off:
- the **Wrapping of Enchanting** ("Enchantments last 20% longer") on staves;
- the **Pommel of Fortitude** (+30 Health) on swords.

Detection was not the problem. Both definitions resolve to the right effect dword:
- the Enchanting leaf → `STRUCT_MOD_OF_ENCHANTING = '1400B822'`, which is IncreaseEnchantmentDuration 0x22B with value 20;
- the Fortitude leaf → `STRUCT_30_HEALTH = '001E4823'`, which is HealthPlus 0x234 with value 30.

The failure was in the salvage step.

### 7.2 Root cause: wrong salvage slot

**Before** (`lib/Utils-Storage.au3`, v10 lines 2979–2983 and 3290–3317):

```autoit
Global Const $EXTRACT_COMPONENT_INDEX_MODE = 'compact'
...
Func ComputeSalvageComponentIndex($kind, $hex, $mode = 'compact')
	...
	Local $weaponUpgrades = CountModStructIdentifier($hex, '3025')
		Case 'rune'
			Return CountModStructIdentifier($hex, '0824') > 0 ? 1 : 0
		Case 'suffix'
			Return $weaponUpgrades >= 2 ? 1 : 0     ; <- only-suffix item -> 0
		Case Else
			Return _Min($weaponUpgrades, 2)          ; <- inscription with 0-1 mods -> 0 or 1
```

'compact' assumed that the slot number is the position among the upgrades actually present. The game's salvage session has **fixed** slots instead:
- GWCA `GameEntities/Item.h` `SalvageSessionInfo` has `salvagable_1` (Prefix), `salvagable_2` (Suffix), `salvagable_3` (Inscription), and `chosen_salvagable` (3 = materials).
- StoC `SalvageSession` carries `salvagable_item_ids[3]`.
- Py4GW `MerchantRules.py` selects the salvage option by slot name (prefix / suffix / inscription).
- Upstream BotsHub `SalvageItem()` sends 0 / 1 / 2.

What happened in game:
1. A staff with only a wrapping, or a sword with only a pommel, got `SalvageMod(0)`, which is the empty prefix slot.
2. Nothing was extracted.
3. `WaitForUpgradeExtraction` timed out after 3 s plus ping, and the session was cancelled (`extraction of … not confirmed - cancelling session, item skipped`).

It worked only when the item also had a prefix. The same bug sent:
- an inscription on an item with fewer than two mods to slot 0 or 1;
- a rune on armor without an insignia to slot 0.

Also, `'0824'` (0x2408) is the generic Upgrade header present on every upgrade, not an insignia marker.

**After** (`lib/Utils-Storage.au3` lines 2994–3004 and 3316–3329):

```autoit
Global Const $EXTRACT_COMPONENT_INDEX_MODE = 'fixed'
Func ComputeSalvageComponentIndex($kind)   ; prefix/insignia 0, suffix/rune 1, inscription 2, unknown -1 (no salvage sent)
```

The `lib/GWA2.au3` `SalvageMod()` comment (line 1531) said "0 for prefix/inscription". It is corrected.

### 7.3 Second cause: wrong component for the same effect

Some upgrades share the exact effect dword. For example:
- Hale staff head (prefix, id 0x9D) and Wrapping of Fortitude (suffix, id 0xDC) are both `001E4823`;
- Defensive (0x91) and Of Defense (0xD2) are both `05000821`.

Matching only checked the effect dword and the '30' marker. So a checked "of Fortitude" matched a Hale head, and the bot then salvaged the suffix slot: empty, or a different wrapping.

The modstruct layout of an upgrade group was confirmed from two sources:
- a GWToolbox item dump (elitepvpers): `0x24080139 0x25300272 0x246801E5 …`, where 0x139 = Silencing_Daggers;
- Py4GW `decoded_modifier.py`.

The layout is `[0x2408 Upgrade, arg = upgrade id] [0x2530 mod tooltip | 0x2532 inscription tooltip] [effect dword(s)]`.

`FindUpgradeGroupForStruct` (`lib/Utils-Items_Modstructs.au3`, line 1552) now:
- reads the upgrade id;
- looks it up in `GetWeaponUpgradeInfoFromId` (line 1598), a table of 220 ids generated from Py4GW `ItemUpgradeId` and `upgrades.py` (Prefix / Suffix / Inscription);
- rejects a group of the wrong kind.

With a known upgrade id, all effect dwords of the group are checked (up to 3), so Zealous, Vampiric, Sundering, To the Pain and similar mods match in either order. An unknown id, or a missing group header, falls back to the old rule (struct directly after the marker), so nothing that matched before is lost.

### 7.4 Salvage flow checks (no change needed)

| Step | Finding |
|---|---|
| Candidate items | Bags 1–4; `IsWeapon` or armor salvageable; blue, purple or gold; identified; not equipped or customized; not protected by Store items. White items are excluded, as before. |
| Kit choice | `FindSalvageKit` = [2991 Expert, 5900 Superior], bags 1–5; uses = value / 8 and value / 10 (GWA2). IDs match GWCA `ItemIDs.h` (`SalvageKit_Expert` 2991, `SalvageKit_Superior` 5900, `SalvageKit` 2992). |
| Kit-use count | `CountRemainingKitUses` divided by 2 for every kit. **Fixed** (`KitValuePerUse`); this mattered for superior ID kits (value / 2.5). |
| Packets | CtoS 0x77 open, 0x78 cancel, 0x79 done, 0x7A materials, 0x7B upgrade (`lib/GWA2_Headers.au3` 97–101) = Py4GW `Packet_enums`. Unchanged. |
| Session ID | WorldContext +0x690 (`StartSalvageWithKit` offsets `[0, 0x18, 0x2C, 0x690]`) = GWCA `WorldContext.h` `salvage_session_id` +0x690. Unchanged. |
| Waits | 800 ms + ping after StartSalvage. Confirmation: item gone, upgrade gone, or kit value dropped, within 3 s + 2×ping. Then CancelSalvage. Unchanged. |
| Space | 1 free slot in bags 1–4 before each extraction. Unchanged. |
| Value match | Exact: only a **20%** Enchanting wrapping and a **+30** Fortitude pommel match (Py4GW ranges 10–20 and 10–30). Lower rolls are not extracted, by design of the tree names. |

### 7.5 Audit counts

**Verified correct against sources:**
- 105 weapon-mod and inscription effect constants: modifier id matches the Py4GW upgrade class, and the value is checked.
- 45 insignia upgrade ids (Py4GW `ItemUpgradeId`).
- Every attribute rune: attribute id per GWCA `Constants::Attribute`; Major/Superior tier upgrade id per Py4GW `AppliesTo<Tier><Profession>Rune`.
- The 4 condition runes (Recovery, Restoration, Clarity, Purity) and the 8 condition inscriptions (Py4GW `Reduced_Ailment`).
- Damage-type and species ids (Py4GW `DamageType`, `ItemBaneSpecies`).
- Condition skill ids for Barbed, Crippling, Cruel, Poisonous, Silencing and Heavy (GWCA `SkillID` 478–486).
- Item type ids (GWCA `ItemType`, Py4GW `ItemType`).
- 837 item model IDs (Py4GW `Model_enums`), including all 25 upgrade-component model IDs (staff head 896, wrapping 908, sword hilt 897, pommel 909…).
- Salvage and identification kits.

**Confirmed wrong and fixed:** 11 data entries, 3 logic errors and 2 wrong comments.

| # | Location | Was | Now | Source |
|---|---|---|---|---|
| 1 | `Utils-Storage.au3` `$EXTRACT_COMPONENT_INDEX_MODE` / `ComputeSalvageComponentIndex` | 'compact' (slot = position among present upgrades) | fixed 0 / 1 / 2 | GWCA `SalvageSessionInfo`; Py4GW MerchantRules; BotsHub `SalvageItem` |
| 2 | `UpgradeDefinitionPresentOnItem` / `HasUpgradeStructInModStruct` | no prefix/suffix check for shared effect dwords | upgrade-id kind check | Py4GW `ItemUpgradeId` + `upgrades.py`; GWToolbox dump |
| 3 | `CountRemainingKitUses` | value / 2 for every kit | `KitValuePerUse` (8 / 10 / 2.5 / 2) | GWA2 / BotsHub `FindKit` divisors |
| 4–13 | `STRUCT_INHERENT_{ILLUSION_MAGIC, INSPIRATION_MAGIC, BLOOD_MAGIC, SOUL_REAPING, CURSES}_HCT` and `_HSR` (10 constants) | HCT = `..149823`, HSR = `..141822` (swapped) | HCT = `..141822`, HSR = `..149823` | Py4GW HalvesCastingTimeAttribute 0x221 / HalvesSkillRechargeAttribute 0x239 |
| 14 | `GWA2_ID_Items.au3` `$ID_LUNAR_TOKENS` | 28433 (= Pumpkin Cookie), listed as festival drop "Lunar Tokens" | alias of 21833, removed from list | GWCA `LunarToken` 21833; Py4GW `Pumpkin_Cookie` 28433 |
| 15 | `GWA2.au3` `SalvageMod` comment | "0 for prefix/inscription, 1 suffix/rune, 2 inscription" | 0 prefix/insignia, 1 suffix/rune, 2 inscription | GWCA |
| 16 | `STRUCT_INSCRIPTION_ONLY_THE_STRONG_SURVIVE` comment | "incorrect" | value `00085828` verified (arg 8 = Weakness) | Py4GW `Reduced_Ailment` |

### 7.6 Unverified: flagged, not changed

| Item | Bot value | Note |
|---|---|---|
| `STRUCT_INSCRIPTION_SHOW_ME_THE_MONEY` | `3200F805` | Decodes to identifier 0x05F, unknown to Py4GW. Py4GW IncreasedSaleValue = 0x25F would read `3200F825`. Needs an in-game modstruct. |
| `STRUCT_INHERENT_OF_*` (19 constants, OS staff "+1 attribute 19/20%") | 7-char partial patterns, e.g. `0118240` | arg1 + AttributePlusOne 0x241 + first char of the next dword. The chance byte is not checked. |
| Vigor runes (`C202E827`/`E927`/`EA27`) and Absorption runes (`EA02E8/E9/EA27`) | | Identifier 0x27E is not defined in Py4GW (tier in the low nibble). Consistent pattern, no second source. |
| Slaying suffixes (`000?8080`) | BaneSpecies 0x008 | Py4GW OfSlaying reads the species from BaneSpecies and the damage % from DamagePlusVsSpecies 0x224 (arg1). Since v12 both are required (+20%), see §8. Not yet seen in a live modstruct. |
| Model IDs that disagree with Py4GW (single source, not changed) | Zaishen Key 28571 (Py4GW 28517); El Jora Tonic 36445 (36455); Jungle Skale Fin 70 (470); Mantis Pincer 815 / Mantid Pincer 829 (Py4GW: swapped); Envoy Sword 36669 (36670); Ceremonial Daggers 968 (15166); Hog's Gluttony 2339 (2439); Censor's Icon ×2 = placeholder 999999 (Py4GW 2096/2097) | Check in game with the item's ModelID. |
| 427 other model IDs | | No same-named entry in Py4GW, so not cross-checked. |
| Rune/insignia item model IDs (`$ID_*_RUNES_*`, `$ID_*_INSIGNIAS_*`, strings) | | Only Superior Vigor 5551 confirmed (Py4GW). |
| Effect-dword order inside multi-effect upgrades | | Not confirmed; both orders are now matched. |
| Session close after a successful extraction | | Py4GW calls FinishSalvage (session done) once the transaction completes. The bot never sends `EndSalvage` (0x79) after an upgrade extraction. Not changed without a live test. |

### 7.7 Tools

- `tools/itemaudit/`: `py4gw_extract.py`, `decode_structs.py`, `crosscheck.py`, `runecheck.py`, `modelcheck.py`, `gen_upgrade_ids.py`, `annotate.py` (reproducible audit).
- `tools/tests/test_mods.au3`: 77 checks on the bot's real functions. It covers:
  - the enchanting staff and the +30 HP sword;
  - Hale vs Fortitude;
  - Zealous and Vampiric in both orders;
  - 40/40 focus, +5e, HCT/HSR, +15^50;
  - armor rune and insignia slots;
  - false positives, the upgrade-id table, kits and label fixes.

### 7.8 Live checks for this change

- [ ] Staff with only a 20% Wrapping of Enchanting, Expert kit: the log shows `upgrades on item: suffix OfEnchanting_Staff (0x00E1) - salvage slot 1`, then `extracted … item kept/destroyed`, and the wrapping is in the inventory.
- [ ] Same with a sword with only a Pommel of Fortitude (`OfFortitude_Sword (0x00DD)`).
- [ ] Staff with a head and a wrapping, wrapping checked: the wrapping is extracted, not the head.
- [ ] Inscription on an item with no mods: slot 2, inscription extracted.
- [ ] Armor with a rune and no insignia: slot 1, rune extracted.
- [ ] After a surviving extraction, the next item starts a new session normally. If it doesn't, the session needs `EndSalvage` (see 7.6).


## 8. Perfect-only extraction (v12 follow-up)

### 8.1 Request

AMG: *"I don't want settings for any mods that are not perfect. I only want it to extract perfect values."*
Scope: the *Extract upgrades only* settings tree (Inventory tab), the shipped loot configs, the matching code and the constants behind it.

### 8.2 What the audit found

Every tree leaf was resolved to its `STRUCT_*` constant (the same rules as `ResolveUpgradeLeafDefinition`) and decoded. Each value was then compared with the max of the matching Py4GW upgrade class: the `ranged(min, max)` and `fixed()` instructions in `upgrades.py`. Tool: `tools/itemaudit/perfect_verify.py`.

- **Before:** 534 leaves: 183 armor (95 kept, 88 removed) and 351 weapon mods/inscriptions.
- **Weapon mods and inscriptions (351):** every label and constant was already the max roll for its item type. Examples:
  - Enchanting 20%; Fortitude +30; Shelter/Warding +7; Defense/Defensive +5.
  - Insightful +5; Adept/Aptitude 20%; Swift/Swiftness 10%; Of the Profession +5; Mastery 20%; Furious 10%; Sundering 20/20.
  - Devotion/Endurance +45; Valor +60.
  - Vampiric 3 on axe/sword/dagger/spear and Vampiric 5 on bow/hammer/scythe. Each is the only Vampiric for that type (Py4GW VampiricMinor vs VampiricMajor maps).
  - Every inscription at its top value. Strength and Honor +15^50, Seize the Day +15, Live for Today +15, Don't Call It a Comeback +7, Down but Not Out +10, Luck of the Draw 20%…
  - Result: 0 non-perfect weapon/inscription entries; 0 maxima differ from Py4GW.
- **But 15 of these upgrades could still extract a lower roll** (59 tree leaves over the weapon types). Their constant pins only the *fixed* part, so the rolled value was never compared:

| Upgrade | Constant pins | Rolled part (Py4GW range) | Leaves |
|---|---|---|---|
| 11 slaying suffixes (Deathbane, Charr, Troll, Pruning, Skeleton, Giant, Dwarf, Tengu, Demon, Ogre, Dragon) | BaneSpecies (species) | DamagePlusVsSpecies 0x224, arg1: 15–20% | 55 (axe, bow, hammer, staff, sword) |
| To the Pain | ArmorMinusAttacking -10 | DamagePlusPercent 0x223, arg2: 14–15% | 1 |
| Brawn over Brains | EnergyMinus -5 | DamagePlusPercent 0x223, arg2: 14–15% | 1 |
| Ignorance is Bliss | EnergyMinus -5 | ArmorPlus 0x210, arg2: 4–5 | 1 |
| Life is Pain | HealthMinus -20 | ArmorPlus 0x210, arg2: 4–5 | 1 |

- **Runes:** 88 Minor/Major tier leaves (including Minor/Major Vigor and Absorption) are not the max tier, so they were removed.
  - Kept: all Superior runes and the single-tier runes (Vitae, Attunement, Recovery, Restoration, Clarity, Purity).
  - All 45 insignias kept: they have one fixed value each.
  - Rune constants are tier-specific (`012CE821` minor, `022CE8210703` major, `032CE8210903` superior Mysticism), so a Superior option never matches a Major rune. This is tested.

### 8.3 Changes

| # | Change | Where |
|---|---|---|
| 1 | 88 Minor/Major rune options removed from the *Extract upgrades only* branch of the 3 shipped loot configs. Files edited line-by-line (format and BOM kept); the result was verified by re-parsing. | `conf/loot/*.json` |
| 2 | `IsPerfectUpgradeOption()`: generated allowlist of the 446 perfect options (relative to the extract root). | `lib/Utils-Items_Modstructs.au3`, region *Perfect-roll extraction* |
| 3 | `GetPerfectRollRequirements()`: for the 15 upgrades above, the extra max-roll effect the same upgrade group must carry (`224:1:20`, `223:2:15`, `210:2:5`). `ResolveUpgradeLeafDefinition` stores it as `definition['requirements']`. | same |
| 4 | `UpgradeGroupMeetsRequirements()`: checks the group's effect dwords by effect id, `(identifier >> 4) & 0x3FF`, and arg byte. The group ends at the next 0x2408. Effect order does not matter. `FindUpgradeGroupForStruct` / `HasUpgradeStructInModStruct` take the new optional `$requirements` parameter (default `''` = old behaviour). | same |
| 5 | `UpgradeDefinitionPresentOnItem()` passes the requirements. This covers candidate selection and both re-checks before the salvage packet. | `lib/Utils-Storage.au3` |
| 6 | Load time: `LoadLootConfiguration()` calls `PruneNonPerfectExtractOptions()` on the parsed JSON before filling the cache. Non-perfect leaves under *Extract upgrades only* are dropped and emptied branches removed. One warning gives the count and lists the leaves that were checked. Nothing else is touched, there is no crash, and the file on disk is not rewritten (saving from the GUI writes the clean tree). | `BotsHub.au3`, `lib/Utils-Items_Modstructs.au3` |
| 7 | `LoadExtractUpgradeDefinitions()` skips any checked leaf that is not a perfect option, with a warning. This matters for the *Keep components* fallback used by configs without an extract branch. | `lib/Utils-Storage.au3` |

**Keep components (superseded by §9):** v12 left the *Keep components* tree unchanged, because pruning it makes the bot salvage or sell armor that carries Minor/Major runes. AMG then approved pruning it too, and v13 does that (§9). Still unchanged: memory offsets, packet headers, the salvage flow and the GUI layout. The tree is data-driven from the config, so the GUI shows only the kept options.

### 8.4 Final list of perfect options kept (446)

| Group | Options | Count | Entries (each = the max roll, per Py4GW ranges) |
|---|---|---|---|
| Armor | All insignias | 7 | Survivor, Radiant, Stalwart, Brawlers, Blessed, Heralds, Sentrys |
| Armor | All runes | 7 | Vitae, Attunement, Recovery, Restoration, Clarity, Purity, Superior Vigor |
| Armor | Assassin insignias | 4 | Vanguards, Infiltrators, Saboteurs, Nightstalkers |
| Armor | Assassin runes | 4 | Superior Critical Strikes, Superior Dagger Mastery, Superior Deadly Arts, Superior Shadow Arts |
| Armor | Dervish insignias | 2 | Windwalker, Forsaken |
| Armor | Dervish runes | 4 | Superior Earth Prayers, Superior Mysticism, Superior Scythe Mastery, Superior Wind Prayers |
| Armor | Elementalist insignias | 5 | Hydromancer, Geomancer, Pyromancer, Aeromancer, Prismatic |
| Armor | Elementalist runes | 5 | Superior Air Magic, Superior Earth Magic, Superior Energy Storage, Superior Fire Magic, Superior Water Magic |
| Armor | Mesmer insignias | 3 | Virtuosos, Artificers, Prodigys |
| Armor | Mesmer runes | 4 | Superior Domination Magic, Superior Fast Casting, Superior Illusion Magic, Superior Inspiration Magic |
| Armor | Monk insignias | 3 | Wanderers, Disciples, Anchorites |
| Armor | Monk runes | 4 | Superior Divine Favor, Superior Healing Prayers, Superior Protection Prayers, Superior Smiting Prayers |
| Armor | Necromancer insignias | 6 | Bloodstained, Tormentors, Bonelace, Minion Masters, Blighters, Undertakers |
| Armor | Necromancer runes | 4 | Superior Blood Magic, Superior Curses, Superior Death Magic, Superior Soul Reaping |
| Armor | Paragon insignias | 1 | Centurions |
| Armor | Paragon runes | 4 | Superior Command, Superior Leadership, Superior Motivation, Superior Spear Mastery |
| Armor | Ranger insignias | 6 | Frostbound, Pyrebound, Stormbound, Scouts, Earthbound, Beastmasters |
| Armor | Ranger runes | 4 | Superior Beast Mastery, Superior Expertise, Superior Marksmanship, Superior Wilderness Survival |
| Armor | Ritualist insignias | 3 | Shamans, Ghost Forge, Mystics |
| Armor | Ritualist runes | 4 | Superior Channeling Magic, Superior Communing, Superior Restoration Magic, Superior Spawning Power |
| Armor | Warrior insignias | 5 | Knights, Lieutenants, Stonefist, Dreadnought, Sentinels |
| Armor | Warrior runes | 6 | Superior Axe Mastery, Superior Hammer Mastery, Superior Strength, Superior Swordsmanship, Superior Tactics, Superior Absorption |
| Inscriptions | Any item | 2 | Measure for measure (Highly salvageable), Show me the money (Improved sale value) |
| Inscriptions | Weapon | 9 | Strength and honor (Damage +15% while Health is above 50%), Guided by fate (Damage +15% while Enchanted), Dance with death (Damage +15% while in a Stance), Too much information (Damage +15% vs Hexed foes), To the pain (Damage +15% Armor -10 while attacking), Brawn over brain (Damage +15% Energy -5), Vengeance is mine (Damage +20% while Health is below 50%), Dont fear the reaper (Damage +20% while Hexed), Dont think twice (Halves casting time of spells) |
| Inscriptions | Weapon.Martial | 2 | I have the power (Energy +5), Let the memory live again (Halves skill recharge of spells) |
| Inscriptions | Weapon.Spellcasting | 6 | Hale and hearty (Energy +5 while Health is above 50%), Have faith (Energy +5 while Enchanted), Dont call it a come back (Energy +7 while Health is below 50%), I am sorrow (Energy +7 while Hexed), Seize the day (Energy +15 Energy regeneration -1), Aptitude not attitude (Halves casting time of spells of item's attribute) |
| Inscriptions | Offhand.Focus | 13 | Forget me not (Halves skill recharge of spells of item's attribute), Serenity now (Halves skill recharge of spells), Hail to the king (Armor +5 while Health is above 50%), Faith is my shield (Armor +5 while Enchanted), Might makes right (Armor +5 while attacking), Knowing is half the battle (Armor +5 while casting), Man for all seasons (Armor +5 vs Elemental damage), Survival of the fittest (Armor +5 vs Physical damage), Ignorance is bliss (Armor +5 Energy -5), Life is pain (Armor +5 Health -20), Down but not out (Armor +10 while Health is below 50%), Be just and fear not (Armor +10 while hexed), Live for today (Energy +15 Energy regeneration -1) |
| Inscriptions | Offhand | 20 | Master of my domain (Item's attribute +1), Not the face (Armor +10 vs Blunt damage), Leaf on the wind (Armor +10 vs Cold damage), Like a rolling stone (Armor +10 vs Earth damage), Sleep now in the fire (Armor +10 vs Fire damage), Riders on the storm (Armor +10 vs Lightning damage), Through thick and thin (Armor +10 vs Piercing damage), The riddle of steel (Armor +10 vs Slashing damage), Sheltered by faith (Received physical damage -2 while Enchanted), Run for your life (Received physical damage -2 while in a Stance), Nothing to fear (Received physical damage -3 while Hexed), Luck of the draw (Received physical damage -5 - Chance 20%), Fear cuts deeper (Reduces Bleeding duration on you by 20%), I can see clearly now (Reduces Blind duration on you by 20%), Swift as the wind (Reduces Crippled duration on you by 20%), Soundness of mind (Reduces Dazed duration on you by 20%), Strength of body (Reduces Deep Wound duration on you by 20%), Cast out the unclean (Reduces Disease duration on you by 20%), Pure of heart (Reduces Poison duration on you by 20%), Only the strong survive (Reduces Weakness duration on you by 20%) |
| Mods | Axe prefix (Haft) | 13 | Ebon, Fiery, Icy, Shocking, Barbed, Cruel, Crippling, Heavy, Poisonous, Furious, Sundering, Vampiric 3, Zealous |
| Mods | Axe suffix (Grip) | 27 | of Fortitude, Of Defense, Of Shelter, Of Warding, Of Enchanting, Of The Warrior, Of The Ranger, Of The Necromancer, Of The Mesmer, Of The Elementalist, Of The Monk, Of The Ritualist, Of The Assassin, Of The Paragon, Of The Dervish, Of Deathbane, Of Charrslaying, Of Trollslaying, Of Pruning, Of Skeleton Slaying, Of Giant Slaying, Of Dwarf Slaying, Of Tengu Slaying, Of Demon Slaying, Of Ogre Slaying, Of Dragon Slaying, Of Axe Mastery |
| Mods | Bow prefix (String) | 11 | Ebon, Fiery, Icy, Shocking, Barbed, Crippling, Poisonous, Silencing, Sundering, Vampiric 5, Zealous |
| Mods | Bow suffix (Grip) | 27 | of Fortitude, Of Defense, Of Shelter, Of Warding, Of Enchanting, Of The Warrior, Of The Ranger, Of The Necromancer, Of The Mesmer, Of The Elementalist, Of The Monk, Of The Ritualist, Of The Assassin, Of The Paragon, Of The Dervish, Of Deathbane, Of Charrslaying, Of Trollslaying, Of Pruning, Of Skeleton Slaying, Of Giant Slaying, Of Dwarf Slaying, Of Tengu Slaying, Of Demon Slaying, Of Ogre Slaying, Of Dragon Slaying, Of Marksmanship |
| Mods | Dagger prefix (Tang) | 13 | Ebon, Fiery, Icy, Shocking, Barbed, Cruel, Crippling, Poisonous, Silencing, Furious, Sundering, Vampiric 3, Zealous |
| Mods | Dagger suffix (Handle) | 16 | of Fortitude, Of Defense, Of Shelter, Of Warding, Of Enchanting, Of The Warrior, Of The Ranger, Of The Necromancer, Of The Mesmer, Of The Elementalist, Of The Monk, Of The Ritualist, Of The Assassin, Of The Paragon, Of The Dervish, Of Dagger Mastery |
| Mods | Focus suffix (Core) | 6 | of Fortitude, Of Devotion, Of Endurance, Of Valor, Of Aptitude, Of Swiftness |
| Mods | Hammer prefix (Haft) | 10 | Ebon, Fiery, Icy, Shocking, Cruel, Heavy, Furious, Sundering, Vampiric 5, Zealous |
| Mods | Hammer suffix (Grip) | 27 | of Fortitude, Of Defense, Of Shelter, Of Warding, Of Enchanting, Of The Warrior, Of The Ranger, Of The Necromancer, Of The Mesmer, Of The Elementalist, Of The Monk, Of The Ritualist, Of The Assassin, Of The Paragon, Of The Dervish, Of Deathbane, Of Charrslaying, Of Trollslaying, Of Pruning, Of Skeleton Slaying, Of Giant Slaying, Of Dwarf Slaying, Of Tengu Slaying, Of Demon Slaying, Of Ogre Slaying, Of Dragon Slaying, Of Hammer Mastery |
| Mods | Scythe prefix (Snathe) | 13 | Ebon, Fiery, Icy, Shocking, Barbed, Cruel, Crippling, Heavy, Poisonous, Furious, Sundering, Vampiric 5, Zealous |
| Mods | Scythe suffix (Grip) | 16 | of Fortitude, Of Defense, Of Shelter, Of Warding, Of Enchanting, Of The Warrior, Of The Ranger, Of The Necromancer, Of The Mesmer, Of The Elementalist, Of The Monk, Of The Ritualist, Of The Assassin, Of The Paragon, Of The Dervish, Of Scythe Mastery |
| Mods | Shield suffix (Handle) | 4 | of Fortitude, Of Devotion, Of Endurance, Of Valor |
| Mods | Spear prefix (Head) | 14 | Ebon, Fiery, Icy, Shocking, Barbed, Cruel, Crippling, Heavy, Poisonous, Silencing, Furious, Sundering, Vampiric 3, Zealous |
| Mods | Spear suffix (Grip) | 16 | of Fortitude, Of Defense, Of Shelter, Of Warding, Of Enchanting, Of The Warrior, Of The Ranger, Of The Necromancer, Of The Mesmer, Of The Elementalist, Of The Monk, Of The Ritualist, Of The Assassin, Of The Paragon, Of The Dervish, Of Spear Mastery |
| Mods | Staff prefix (Head) | 5 | Hale, Adept, Swift, Insightful, Defensive |
| Mods | Staff suffix (Wrapping) | 30 | of Fortitude, Of Defense, Of Shelter, Of Warding, Of Enchanting, Of The Warrior, Of The Ranger, Of The Necromancer, Of The Mesmer, Of The Elementalist, Of The Monk, Of The Ritualist, Of The Assassin, Of The Paragon, Of The Dervish, Of Deathbane, Of Charrslaying, Of Trollslaying, Of Pruning, Of Skeleton Slaying, Of Giant Slaying, Of Dwarf Slaying, Of Tengu Slaying, Of Demon Slaying, Of Ogre Slaying, Of Dragon Slaying, Of Mastery, Of Devotion, Of Endurance, Of Valor |
| Mods | Sword prefix (Hilt) | 12 | Ebon, Fiery, Icy, Shocking, Barbed, Cruel, Crippling, Poisonous, Furious, Sundering, Vampiric 3, Zealous |
| Mods | Sword suffix (Pommel) | 27 | of Fortitude, Of Defense, Of Shelter, Of Warding, Of Enchanting, Of The Warrior, Of The Ranger, Of The Necromancer, Of The Mesmer, Of The Elementalist, Of The Monk, Of The Ritualist, Of The Assassin, Of The Paragon, Of The Dervish, Of Deathbane, Of Charrslaying, Of Trollslaying, Of Pruning, Of Skeleton Slaying, Of Giant Slaying, Of Dwarf Slaying, Of Tengu Slaying, Of Demon Slaying, Of Ogre Slaying, Of Dragon Slaying, Of Swordmanship |
| Mods | Wand suffix (Wrapping) | 12 | Of Memory, Of Quickening, Of The Warrior, Of The Ranger, Of The Necromancer, Of The Mesmer, Of The Elementalist, Of The Monk, Of The Ritualist, Of The Assassin, Of The Paragon, Of The Dervish |

### 8.5 Unconfirmed

- **Slaying damage dword.** Per Py4GW the slaying % is DamagePlusVsSpecies (0x224, arg1); it has not been seen in a live modstruct. If the game encodes it differently, slaying options will extract nothing (safe failure) rather than a wrong roll. Live check in 8.7.
- **Show me the money** (`3200F805`): fixed-value inscription, so there is no roll to check. The constant itself is still unverified (§7.6).
- **Effect order inside multi-effect groups:** both orders are accepted and tested.
- **Per-type maxima:** Py4GW ranges are per upgrade class, not per item type. Every kept leaf has exactly one class for its item type, and its constant equals that class's max. No case was found where one item type has a lower cap.

### 8.6 Tests

- `tools/itemaudit/perfect_verify.py` (runs in `run_tests.sh`): fails if any kept weapon mod or inscription constant is not the Py4GW max. Current result: 351/351 at max, 0 problems.
- `tools/tests/test_perfect.au3`: 2003 checks on the bot's real functions.
  - The 20% Enchanting staff wrapping accepts 20 only; 19/15/10 are rejected.
  - The +30 Fortitude sword pommel accepts 30 only; 29/25/20/10 are rejected.
  - All 351 weapon mod/inscription leaves:
    - the max roll is accepted on every item type of the leaf;
    - for the 266 ranged ones, max-1 and min are rejected;
    - for the 59 with a companion effect, the fixed part alone is rejected and both effect orders are accepted.
  - Spot checks: +5e, HCT/HSR 20 (40/40 halves), +15^50, Vampiric/Zealous, To the Pain 14% and Demon Slaying 15% rejected. A companion effect in the next group does not count.
  - 95 kept armor options match and 88 removed ones are rejected by the allowlist. Superior does not match Major for Vigor or Mysticism.
  - Load-time pruning:
    - a v10 config goes from 534 to 446 extract leaves with one warning, and all other roots are byte-identical after re-serialization;
    - the single-root v12 helper leaves Keep components to the v13 two-root pruning (§9);
    - the shipped configs need no pruning;
    - a hand-made config reports its checked leaves and loses its emptied branches;
    - non-map input is returned as is.
- **Mutation check:** with the requirements disabled, 180 of these checks fail. Those are the lower rolls that v10/v11 would have extracted.

### 8.7 Live checks

- [ ] Load an older loot config with Minor runes under *Extract upgrades only*: one `[Loot] Ignored 176 non-perfect option(s)` warning (v13: both roots, 88 each), and the tree shows Superior runes only.
- [ ] Sword with a +20% slaying pommel (e.g. Demon Slaying), option checked: the pommel is extracted. With a 15–19% pommel, the item is skipped (no salvage).
- [ ] To the Pain 15% inscription extracted; 14% skipped.
- [ ] Staff with a 20% Enchanting wrapping extracted; 10–19% skipped (no salvage session started).

## 9. Perfect-only Keep components (v13 follow-up)

### 9.1 Request
AMG approved making the *Keep components* tree perfect-only, the same as *Extract upgrades only*. That means:
- remove the non-perfect options from it;
- keep an item only when the upgrade carries the max value;
- clean up old configs at load time with one warning.

### 9.2 What was removed
- **From each shipped loot config:** 88 options were removed from *Keep components*. These are the same 88 Minor/Major runes removed from Extract in v12. 446 options remain, identical to the Extract list in §8.4: 50 runes, 45 insignias and 351 weapon mods/inscriptions. None of the 534 weapon/inscription leaves was removed, because they were already max-roll constants (§8.2). Their lower rolls are now rejected by value instead (§9.3).
- **Configs edited:** `Default Loot Configuration.json`, `Loot.json` and `Sin Tasca's ChestRun.json`. Each was edited line by line, so its BOM and formatting are unchanged.
- **Checked by default before, now removed:**
  - `Default Loot Configuration.json` and `Loot.json` (16 each): Minor Vigor, Major Vigor, Minor Mysticism, Minor Scythe Mastery, Minor Energy Storage, Minor Fast Casting, Minor Inspiration Magic, Major Domination Magic, Major Fast Casting, Minor Divine Favor, Minor Healing Prayers, Minor Protection Prayers, Minor Soul Reaping, Minor Spawning Power, Minor Strength and Minor Tactics.
  - `Sin Tasca's ChestRun.json` (1): Major Vigor.
- **Built-in defaults:** the list used before a config loads (`DefaultCreateValuableRunesAndInsigniasArray`) had 13 Minor/Major rune entries. They are now commented out and marked `v13: not perfect`.

### 9.3 Matching change
- **Before:** the inscribable-weapon keep check, `ContainsValuableUpgrades`, did a plain substring search for the struct right after the `30`/`32` marker. It ignored the rolled value, so a 17% slaying pommel or a +4 Ignorance is Bliss was kept.
- **Now:** the check uses the same group matcher as extraction, `FindUpgradeGroupForStruct`, through `KeepUpgradePresent`. It applies the same perfect-roll requirements (§8.3, `GetPerfectRollRequirements`):
  - `RefreshValuableListsFromCache` builds `$valuable_upgrade_requirements` from the checked Keep leaves, via `CreateValuableUpgradeRequirementsMap`.
  - One struct, `0500B820`, is shared by Brawn over Brains and Ignorance is Bliss. It stores both requirements as `|` alternatives. This is safe because their companion effects differ: +15% damage and +5 armor.
- **Side benefits:**
  - Matching is dword-aligned within one upgrade group.
  - It accepts any effect order.
  - The old "unexpected format" warning is gone.
- **Armor:** runes and insignias already matched by full struct. Removing the Minor/Major leaves is enough, because Superior has a different struct and does not match Major (§8.6).

### 9.4 Load-time cleanup
- `PruneNonPerfectUpgradeOptions` replaces the single-root call in `LoadLootConfiguration`. It prunes both roots and logs **one** warning:
  `[Loot] Ignored N non-perfect option(s) under "Keep components" / "Extract upgrades only" ... - they were checked: <root>: <leaves>; ...`
- A v10/v12 config gives N = 176 (88 + 88).
- Other settings are untouched and the file is not rewritten. The shipped configs produce no warning: a GUI smoke run on the default config logged none.

### 9.5 Behaviour side effects (by design, approved)
- **Armor with Minor/Major runes:**
  - An identified armor salvageable whose only valuable upgrade is a Minor or Major rune is no longer protected by Keep components. Examples are Minor Vigor and Major Fast Casting.
  - With the defaults (`Salvage items.Armor salvageables` Blue/Purple/Gold = true), it **is salvaged**, and the rune is destroyed with it.
  - It is **sold** only if the matching sell option is on. That option is off by default.
  - Superior runes and all insignias are still kept.
- **Weapons:**
  - `ShouldKeepWeapon` no longer keeps a weapon on a lower roll. This covers slaying below 20%, To the Pain or Brawn over Brains below 15%, and Ignorance is Bliss or Life is Pain below +5.
  - Such a weapon falls through to the remaining rules: max stats, low-req or rare skin, and OS rules. It may be salvaged or sold.
- **Before a config loads:** the built-in default list no longer keeps the 13 Minor/Major runes.
- **Not changed (flag):** the hardcoded OS-weapon list, `$valuable_mods_by_os_weapon_type`, is not driven by the tree. It still uses its own constants, and `HasPerfectMods` / `HasAlmostPerfectMods` are unchanged.

### 9.6 Tests
- `tools/tests/test_keep.au3` runs 1284 checks on the bot's real functions. It stubs `GetModStruct` and loads the configs through the GUI's `FillInventoryCacheFromJSON` with every Keep leaf checked.
  - **All 351 weapon mod/inscription leaves:**
    - the max roll is kept on every item type of the leaf;
    - max-1 and min are not kept;
    - for leaves with a companion effect, the fixed part alone is not kept and the reversed order is kept.
  - **Spot checks:**
    - staff Enchanting is kept at 20% only (19/15/10 rejected);
    - sword Fortitude is kept at +30 only (29/20/10 rejected);
    - Demon Slaying is kept at 20%, not at 17%;
    - Ignorance is Bliss is kept at +5, not at +4;
    - Brawn over Brains is kept at 15%, not at 14%.
  - **Armor:**
    - all 95 kept options are matched;
    - Minor/Major Vigor, Minor Mysticism and Major Fast Casting are not kept (v19: Major Vigor is kept again, §16);
    - the valuable list has 95 entries.
  - **Shipped configs:** 446/446 in both roots, no non-perfect leaf, nothing to clean at load.
  - **v10 config:**
    - exactly one warning, "Ignored 176", which names the checked Keep runes;
    - both roots go from 534 to 446;
    - all other roots are byte-identical;
    - an unpruned v10 config kept Minor Vigor armor; after cleanup it does not, and Superior Vigor is still kept.
  - **Hand-made config:** one warning, and the lower-roll Keep entry is named.
- **Mutation check:** with `GetPerfectRollRequirements` disabled, 183 `test_keep` checks fail.
- **Totals:**
  - `test_perfect` 2003/2003 (updated for the two-root pruning);
  - `test_mods` 77/77;
  - `test_config` 40/40;
  - `test_recovery` 23/23;
  - config differential 0;
  - `perfect_verify.py` 351/351;
  - Au3Check 0 errors / 47 warnings, the same set as before, with no duplicate functions.

### 9.7 Live checks
- [ ] Load an old loot config: one `[Loot] Ignored 176 ...` warning, and the Keep tree shows Superior runes only.
- [ ] Identified blue armor with a Minor Vigor rune is salvaged under the default settings. With a Superior Vigor rune it is kept.
- [ ] A sword with a 20% Demon Slaying pommel (Keep checked) is kept; one with 17% is not kept by this rule.

## 10. Tools tab: Open Storage button (v14)

### 10.1 What it reuses
- **Existing function, no new packet:** GWA2's `OpenXunlaiWindow()` (`lib/GWA2.au3`). It enqueues the `kShowXunlaiChest` UI message (`$UIMSG_SHOW_XUNLAI_CHEST = 0x10000040`) through the injected `CommandUIMsg` routine. The structure is filled in `InitializeCommandStructures()` at attach time.
  - The game opens the storage window directly, so no NPC walk is needed.
  - The same call already backs the *Open Storage* button on the Options tab (upstream).
- **Unchanged:** no memory offsets, packet headers or injected code were touched.

### 10.2 Behaviour
- **Button:** *Open Storage* in **Tools → Other tools**, at (511, 174), next to *Reset session stats*. Control: `$gui_button_toolsopenstorage`. Like the other Tools buttons, it is routed through `GuiToolsTabButtonHandler`.
- **New function:** `OpenStorageForTools()` in `BotsHub.au3` runs these checks in order:
  1. `IsAttachedForTools()`, the same guard as the other Tools: refused while a farm is RUNNING/WILL_PAUSE ("Pause the farm…") and when not attached ("Attach to Guild Wars first.").
  2. The client process must still exist (`GetPID()` + `ProcessExists`). If the client was closed after attach, the bot logs a warning and does no memory reads.
  3. `GetMapType()` / `GetMyID()`:
     - loading or no agent → `[Storage] Character is not in game yet (loading or disconnected)…`;
     - explorable (or any non-outpost type) → `[Storage] Xunlai storage is only accessible in an outpost or town - travel to one first. Storage not opened.` and nothing is sent;
     - outpost, town or guild hall (`$ID_OUTPOST`) → `OpenXunlaiWindow()` and `[Storage] Xunlai storage window opened`.
- **Decision logic:** kept in the pure function `GetOpenStorageBlockReason()` so it can be unit-tested.
- **Options-tab button:** left as upstream (unguarded) in v14. Since v15 it goes through the same `OpenStorageForTools()` checks (§12).

### 10.3 Verification
- `tools/tests/test_storage.au3`: 26 checks. It stubs the game reads and `OpenXunlaiWindow`, and covers:
  - outpost opens exactly once;
  - explorable, loading, no agent and an unknown map type send nothing, with one clear warning;
  - a dead or empty PID sends nothing and does no game reads;
  - not attached or farm running sends nothing and does no game reads.
- `run_tests.sh` adds a static wiring check: the button is created inside the Tools tab, uses `GuiToolsTabButtonHandler`, and its `Case` calls `OpenStorageForTools()`.
- **GUI under Xvfb:**
  - the button is visible on the Tools tab (screenshot `tools_tab.png`, delivered next to the zip);
  - clicking it unattached shows "Attach to Guild Wars first.";
  - the tooltip renders.
- **Live check still needed:**
  - [ ] in an outpost, the window opens;
  - [ ] in an explorable, the warning is logged and no window opens.

## 11. Recommendations (not implemented)

They are ordered by value for effort. Impact, effort and risk are rated H/M/L. Risk means the chance of breaking a working farm or losing items. Nothing here changes offsets or packet headers unless the item says *needs live verification first*.

| # | Recommendation | Impact | Effort | Risk |
|---|---|---|---|---|
| 1 | **Live verification pass** of the flagged items: §5, the §6 checklist, the §7.6 unverified constants, and the §8.7 / §9.7 / §10.3 live checks. The most valuable are the slaying % dword (0x224 arg1), `Show me the money` `3200F805`, the 9 model IDs that disagree with Py4GW, and the `EndSalvage` question. One session with a mule settles most of them, and any fix is a one-line constant change. | H | L | L |
| 2 | **Loot "dry run" / decision log.** A Tools button or `run.loot_dry_run` option that walks the inventory and logs, per item, what the bot *would* do and why: keep, store, salvage (and kit and slot), extract or sell. It would reuse `ShouldKeepWeapon`, `ContainsValuableUpgrades`, `FindCheckedUpgradeOnItem` and the sell/salvage predicates without acting. This makes v12/v13-type changes safe to check before items are destroyed. | H | M | L |
| 3 | **Do not salvage away Minor/Major runes (v13 side effect).** Add an option to sell armor with a non-perfect rune to the Rune Trader, or extract the rune and sell it to the trader, instead of destroying it. `TraderRequestSell` / `TraderSell` and `SellItemToTrader` already exist in GWA2. A Minor Vigor or Major Fast Casting is still worth trader gold. | M–H | M | M (trader dialog flow needs a live check) |
| 4 | **More Tools buttons on existing helpers:** *Deposit gold* (`DepositGold` / `BalanceCharacterGold`), *Store materials/unids* (`StoreItemsInXunlaiStorage` with its predicates), *Sort inventory* (`SortInventory`) and *Identify all*. Use the same `IsAttachedForTools` + outpost guard as Open Storage. All the helpers already run in farms. | M | L | L |
| 5 | **[Done in v15, §12]** **One guard for both Open Storage buttons.** Route the Options-tab button through `OpenStorageForTools()`, or remove it, so behaviour is consistent: no remote view-only window in explorables, and no enqueue when not attached. (Before attach, `Enqueue` writes with a null process handle, which is harmless but pointless.) | L | L | L |
| 6 | **Drive the OS-weapon keep list from the tree.** `$valuable_mods_by_os_weapon_type` and `HasPerfectMods` / `HasAlmostPerfectMods` are hardcoded, and they are the last keep rule that does not follow the perfect-only config (§9.5). Move them onto `KeepUpgradePresent` with requirements, behind a tree branch. | M | M | M (changes what OS items are kept) |
| 7 | **Cache the agent array per tick in fight loops.** There are 21 `GetAgentArray` call sites. Each call does one `ReadProcessMemory` per agent (upstream calls it the "much slower" method), and fight and targeting helpers call it repeatedly. A per-100 ms cache in the targeting and aggro helpers would cut CPU and RPM traffic, which matters with several clients on one PC. | M | M | M (stale positions if the cache is too long) |
| 8 | **Wipe counting by distinct wipes (N1)** with a per-farm "max wipes" setting, so "6 wipes" means six wipes. | M | L | M (changes when farms give up) |
| 9 | **Check farm setup results (N8).** `If Not setup Then SetupX()` should stop the run when setup fails (wrong build, missing hero) instead of relying on later bounds. That gives a clearer error and saves a wasted run. | M | M | M |
| 10 | **Session close after extraction.** If a live test shows the salvage session stays open after an upgrade extraction, call the existing `EndSalvage` (0x79) path, as Py4GW does with FinishSalvage. *Needs live verification first.* | M | L | M |
| 11 | **Config schema version + optional save-back.** Stamp loot/farm configs with `"schema": 14`. When pruning (v12/v13) changes a config, offer to save the cleaned file with a `.bak`, instead of warning on every load. | L–M | L | L |
| 12 | **Kit stock planner.** Before a run, compute the salvage/ID kit uses the bag space needs (`KitValuePerUse` exists) and buy the cheapest sufficient kit, rather than a fixed `KIT_AMOUNT`. | L–M | M | L |
| 13 | **[Done in v15, §12]** **Reset stats resets everything (N2).** Clear `UpdateStats`' internal counters, not just the labels. | L | L | L |
| 14 | **CI for the offline suite.** Run `tools/run_tests.sh` (Wine + AutoIt + Xvfb) and Au3Check on every push in a container; the suite takes about 1 minute. Clean up the 47 Au3Check warnings (N6) once CI exists. | M | M | L |
| 15 | **Same-map-ID mission entry (N4).** Replace the spawn-coordinate heuristics for Moddok, Nexus, Dajkah and Gemstones with `GetInstanceUpTime` reset detection (already used by `WaitForNewInstance`) once it is live-verified. | L–M | M | M |

**Suggested order:**
1. Items 1, 5 and 13 together, as one short session.
2. Then 2, and 3 if the v13 rune loss matters to you.
3. Then 4.
4. Items 6–10 only after 1 and 2 are done, since they change in-game behaviour.

## 12. v15: Options Open Storage guarded, real Reset session stats, TESTING.md

### 12.1 Options tab *Open Storage*
- **Change:** the button is kept, but its `GuiOptionsHandler` case now calls `OpenStorageForTools()` instead of `OpenXunlaiWindow()`. It has the same checks as the Tools button (§10.2): farm running, not attached, client gone, loading/disconnected, outpost/town only.
- **Tooltip:** updated. The old one said "view only from explorable areas", which no longer applies.
- **Verified:**
  - the static wiring check in `run_tests.sh` covers both buttons, and fails if the Options case still calls `OpenXunlaiWindow`;
  - GUI under Xvfb: clicking it unattached shows "Attach to Guild Wars first.".

### 12.2 *Reset session stats*: exactly what is reset
- **Refused while a farm is RUNNING/WILL_PAUSE,** with the same "Pause the farm…" popup as the other Tools. It is allowed when paused, idle or not attached, because it doesn't read the game.
- **Order of operations:**
  1. Logs `Before reset - Session summary (…)`, so the old numbers stay in the log.
  2. Resets the counters listed below.
  3. Logs `Session stats reset (…)`.

| Reset | Where | How |
|---|---|---|
| Runs, successes, failures, success ratio, total time, time per run, chests, experience gain, 8 title gains | `UpdateStats` statics (Main tab) | `$stats_reset_generation` is bumped. At its next call (the next run start), `UpdateStats` zeroes its counters and re-reads the experience/title baselines, exactly like its first call. The labels show 0 at once (`ResetStatsLabels`). |
| Gold and gold-item totals, 28 item counters (ectos … jadeite) | `UpdateItemStats` statics | Same mechanism. The pre-run baselines are re-read at the next call, so items moved between the reset and the next run are not counted. |
| `Session:` line, exit summary: runs, successes, failures, pauses, run time, longest run, gold baseline, start time/uptime | `Utils-Session.au3` (`SessionResetStats`) | Zeroed. The gold baseline is re-read at the next run start. |
| Consecutive-failure counter (the 10-failures watchdog) | `$session_consecutive_failures` | Zeroed. Resetting is only possible while no farm runs, so a fresh streak is the expected meaning. |
| Q8 counter | `$sessionQ8Count` | Zeroed (as before). |

**Not reset (on purpose):**
- the log file and its warning/error counters, which describe the log file and are shown in the summary;
- `logs/runs-<date>.csv` (old lines stay, new lines are appended);
- the loot/farm configs and options;
- the attach state, client selection and character;
- farm setup flags;
- the per-run timer and deadline, and the chest map (only used inside a run);
- the exit-summary hook and the CSV on/off setting.

**Verified:** `tools/tests/test_reset.au3`, 71 checks. It uses the real functions on a hidden GUI with real labels, and stubs only the game reads.
- **Two runs:** the labels and the session counters are correct.
- **Running / will pause:** refused, the popup text is seen by a helper process, and nothing changes.
- **After the reset:**
  - every label is 0;
  - every session counter is 0, and the summary says 0 runs;
  - the not-reset items are unchanged.
- **Next run:** it counts from zero with fresh baselines (experience, titles, items and gold gained before the reset or between runs are not counted). The failure streak starts again, and a second reset works.
- **Mutation check:** with the generation bump and `SessionResetStats` removed, 24 checks fail.
- **GUI under Xvfb:** pressing the button logs both lines, and the Main tab shows all zeros (`main_after_reset.png`).

### 12.3 Live-test helper and checklist
- **New `PrintItemInformationsAt(bag, slot)`** (`lib/Utils-Storage.au3`): a read-only helper for the existing Manual field. It logs `PrintItemInformations` for one slot and checks attach, bag/slot range and empty slots. `test_storage` covers it with 12 checks. It is needed to report model IDs and modstructs from the game.
- **`TESTING.md`:** the prioritized in-game checklist (13 tests). Each test says what to do, what to expect and the exact log line, and what to send back on failure.

## 13. v16: AMG's loot config and the JSON <-> code <-> GUI <-> scripts alignment audit

### 13.1 AMG's loot config
- **File:** `conf/loot/AMG Loot.json`. It is UTF-8 with BOM, CRLF and tab indent, like the shipped configs. It shows up in the loot list as *AMG Loot*.
- **What it is:** AMG's edit of the v10 *Sin Tasca's ChestRun.json*.
  - The tree and key order are the same as v10.
  - 292 values differ from v10 Sin Tasca; there are 661 differences from v10 Default and 1470 from v10 Loot.
  - Compared with the current shipped Sin Tasca config, **291** values differ (diff kept outside the bot folder):

| Section | ticked by AMG | unticked by AMG |
|---|---|---|
| Keep components | 38 | 95 |
| Extract upgrades only | 129 | 0 |
| Sell items | 0 | 27 (all 25 rare materials, purple Shield/Sword req 8) |
| Salvage items | 0 | 2 (purple and gold armor salvageables) |

- **Loader result:** the BOM is handled. `LoadLootOptions` opens the file with `$FO_UTF8`, and `test_loot_alignment` proves that BOM+CRLF and no-BOM load to the same cache.
  - The attached file as sent produces exactly one warning, captured from the real `LoadLootConfiguration`: `[Loot] Ignored 176 non-perfect option(s) under "Keep components" / "Extract upgrades only" (only max rolls / Superior runes can be kept or extracted) - they were checked: Keep components: Armor upgrades.All.Runes.Major Vigor; Extract upgrades only: Armor upgrades.All.Runes.Major Vigor`.
  - Nothing else was dropped: no unknown or renamed keys, and no missing ones.
- **Normalization:** only those 176 leaves were removed from the shipped copy. The bot drops them anyway, so the copy loads silently and gives the identical cache (tested). Every other value is his.
  - The ticked Major Vigor (Keep and Extract) can't be kept: Major is not a perfect rune, per the v12/v13 rule. Superior Vigor is ticked in his file. **v19: reversed - Major Vigor is the single exception (§16); the warning now counts 174.**
  - The untouched original (`user_attached.original.json`) is kept outside the bot folder on purpose, so it doesn't appear as a second loot config.

### 13.2 Alignment checker
`tools/alignment/check_alignment.py <BotHub dir> [--extra-loot f.json] [--report out]` is static: it executes nothing. It exits 1 on any ERROR. `run_tests.sh` runs it and expects `errors=0`. It then re-introduces the old rare material names in a scratch copy and expects the checker to fail.
- **Before the v16 fixes:** 60 ERRORs.
- **After:** 0 ERRORs, 41 ACCEPTED, 24-25 WARN.

| # | Mismatch (confirmed) | Fix | Test |
|---|---|---|---|
| 1 | `Onyx Gemstone` / `Lump of Charcoal` / `Leather Square` in code vs `…s` in the tree. Those 3 materials were never picked up, stored, sold or salvaged. Found as 12 code→JSON and 12 JSON→code findings. | code names = tree labels | test_loot_alignment |
| 2 | `Pick up items.Lockpicks` was never read (always picked up) | honored, missing = yes | test_loot_alignment |
| 3 | `Store items.Trophies.Other trophies` was never read (full stacks always stored) | honored, missing = yes | test_loot_alignment |
| 4 | `@sell.salvageables.nothing` was read but never set | set in `BuildInventoryDerivedFlags` | test_loot_alignment |
| 5 | 24 `team.*` persisted options had no default | defaults = the Team tab's initial values | checker, test_config, differential |
| 6 | 9 farm JSONs lacked 12 persisted options (108 keys) | added with the built-in defaults | checker, differential (0 diffs) |

**Checked and aligned (no change needed):**
- the loot tree labels in the GUI: the tree is built from the JSON itself, so GUI labels = JSON keys;
- weapon, rarity, basic material, tome, dye, festival and farmed trophy names, as far as the tree offers them;
- the farm list: 57 farms, GUI list = `AddFarmToFarmMap` = defined functions = Farm-infos descriptions, and every `#include` exists;
- every `main.farm` / `main.loot_configuration` / district / hero name / build code in the farm configs;
- every GUI-written run option is saved and refreshed, except `run.share_memory` (below);
- `follower.follow_leader_target` is only a legacy alias that is read when present.

### 13.3 Flagged, not changed (needs a decision or data)
- **Store options with no store rule:** `Store items.Alcohols`, `Store items.Lockpicks`, `Store items.Quest items.Map pieces`.
  - Adding the rules would change behaviour. Default and Loot.json tick Alcohols, and storing lockpicks could empty a chest-runner's supply.
- **`Festival Items.Jade Wind Orb`** (Pick up/Store): there is no model ID for it in `GWA2_ID_Items.au3`, and I did not invent one.
- **Buy items:** only Lockpicks, Obsidian Shard and Glob of Ectoplasm are implemented (upstream TODO). The other 34 Buy options do nothing.
- **`@pickup.everything`:** read but never set (dead short-cut, harmless).
- **`run.share_memory`:** written by the GUI, never read or saved (dead checkbox).
- **Config-only options** (no GUI control): `run.skip_am_fah`, `run.debug_logging`.
- **Sell/Salvage trophies:** these trees offer 9 of the 15 farmed trophies. The other 6 (Margonite/Stygian/Titan/Torment Gemstone, Diessa Chalice, Golden Rin Relic) count as unticked, explicitly in code.
- **Gold scrolls:** 4 scroll names have no own option and use *Other gold scrolls*.
- **White armor salvageables:** the code looks up `…Armor salvageables.White`, but the tree has no White option, so they are never picked up, sold, salvaged or stored by that rule. This is upstream design.
- **`src/utilities/BonderModes.au3`:** not included anywhere, and its 4 functions are unreferenced (dead file, left in place).
- **The loot cache is not cleared** between loot-config loads. Keys that exist only in a previously loaded file stay. With the current identical trees, only hand-made files are affected.

## 14. v17: Open Storage reverted to the original behaviour (decision reversed)

- **Decision reversed:** §10.2 and §12.1 had blocked *Open Storage* while a farm runs and outside outposts/towns. AMG asked for the original v10 behaviour: the button should be usable in town, in explorables and while the bot is running. That is user preference, and it is what the upstream button did. Both buttons now go through `OpenStorageForTools()`, which calls `OpenXunlaiWindow()` exactly like the original (`kShowXunlaiChest` UI message through the command queue; no NPC, no packet).
- **Removed:**
  - the `IsAttachedForTools()` call, which refused when RUNNING/WILL_PAUSE and showed popups;
  - the outpost-only block;
  - the loading/disconnected block. Calling it during a load is not known to crash; it is a UI message. It now only adds a log note.
- **Kept (cannot block a legit use):**
  - `$attached_for_tools` is false: log `[Storage] Not attached …`. A running farm is always attached, because `Authentification` sets the flag;
  - the GW process is gone: log `[Storage] Guild Wars client not found …`.

  In both cases there are no memory reads and nothing is sent. The original would have queued into a dead or absent process.
- **Notes:**
  - Explorables give the game's view-only storage, as in the original. The tooltip says so, and a log note is added.
  - While a farm runs, the click queues one UI command next to the farm's own commands. The original had the same property. AutoIt runs the GUI event between script lines, so in the worst case one queued farm command is delayed or overwritten. This is possible in theory and is not guarded, as in the original (TESTING.md test 8 asks to watch for it).
- **Tests:** `test_storage` was rewritten for this behaviour (91 checks). The static wiring check now also fails if a farm-running, attach-guard, popup or outpost check comes back.

### 14.1 Chest-run log noise (AMG's log)
- **"Low lockpicks: 4 - consider restocking" at every *Finding Chest*:** this is upstream v10 code (`ChestRunToward`, `src/runs/ChestFarmCommon.au3`); we didn't add it.
  - **Root cause:** `$lockpicks = FindInInventory($ID_LOCKPICK)` returns `[bag, slot]` of the last lockpick stack found in bags 1..`$bags_count`. `$lockpicks[0]` is therefore the bag index. The "4" meant "a lockpick stack is in bag 4", not 4 lockpicks.
  - **Ruled out:**
    - the model ID (22751 is the one used everywhere);
    - storage vs bags (inventory bags 1-5 only, by design);
    - stacks vs quantity: the real counters `GetInventoryItemCount` and `CountTheseItems` sum quantities and were correct.
  - **Fix:** the warning was removed. Nothing else used that value. The upstream skip-chests-at-0 check (`FindAndOpenChests`, `TascaOpenChestsAtWaypoint`, `[0] == 0`, meaning no stack found) is correct and unchanged. It logs "No lockpicks available to open chests" once (WarnOnce) and does not stop the run.
  - **Flag:** that one-time line still exists, but it can only appear at literally 0 lockpicks. The Gold → Lockpicks tool keeps its purchase report lines, which only appear when that button is pressed.
- **"Taking damage - resynching position with /stuck" every 1-2 s:** this is also upstream v10, and identical to our version before v17.
  - `CombatStuckResync` runs as a 100 ms Adlib in Tasca and Pongmei. It sends `/stuck` on any health drop, throttled to one per `$STUCK_REFIRE_INTERVAL` = 1.5 s. Under continuous damage that is one send, and one log line, every ~1.5 s.
  - The `/stuck` behaviour was kept. The Notice line had no behavioural value, so it is now throttled (first + one per 30 s with a count; Debug per send).
  - Not changed: whether `/stuck` every 1.5 s during combat is useful is a gameplay question. It was upstream's intent.

## 15. v18: skill rotation audit (Deadly Paradox / Shadow Form / Shroud / IAU)

AMG's request: find redundant or wrong skill logic, DP must go first and SF right after (DP is an instant stance), the pair needs 20 energy, better Shroud/energy handling, and a pre-emptive IAU on Giant Stomp. Build facts from AMG: every SF character has 14 Shadow Arts and a +20% enchantment duration mod.

### 15.1 Skill data (GW1 wiki, `index.php?title=<skill>&action=raw`, read 2026-11-09)

| Skill | ID (wiki = `GWA2_ID_Skills.au3`) | Type | Energy | Activation | Recharge | Duration |
|---|---|---|---|---|---|---|
| Deadly Paradox | 572 | Stance (Deadly Arts) | 15 | none | 10 s | 5..15 s; Assassin skills activate/recharge 33% faster |
| Shadow Form | 826 | Elite Enchantment Spell (Shadow Arts) | 5 | 1 s | 30 s | 5..21 s |
| Shroud of Distress | 1031 | Enchantment Spell (Shadow Arts) | 10 | 1 s | 45 s | 30..60 s |
| "I Am Unstoppable!" | 2356 | Shout (Norn rank, PvE) | 5 | none | 30 s | 16..20 s |
| Dwarven Stability | 2423 | Enchantment (Deldrimor rank) | 5 | ¼ s | 30 s | 24..30 s |
| Giant Stomp | 530 | Monster attack | - | 4 s, lands after 2 s | 32 s | KD in earshot; all Giants, Jotun Skullsmasher, Summit Beastmaster, Summit Giant Herder |
| Agnar's Rage | 531 | Monster attack | - | 6 s | - | KD in earshot |
| Tremor | 2176 | Monster Shout | 5 | none | 12 s | KD in earshot - instant, cannot be pre-empted |

**Computed for 14 Shadow Arts + 20%** (`ComputeEnchantDurationMs`, wiki progression rounded like the game, then ×1.2):
- Shadow Form: 5 + 16·14/15 = 19.9 → 20 s → **24 s** (`$SF_DURATION_FALLBACK_MS`). With DP: activation 0.67 s, recharge 20 s, so SF is always recharged ~4 s before it ends.
- Shroud of Distress: 30 + 30·14/15 = 58 s → **69.6 s** (`$SOD_DURATION_FALLBACK_MS`). Recharge 45 s.
- Deadly Paradox is a stance: the enchantment mod does not apply. At Deadly Arts 3 (the shipped D/A templates) it lasts 7 s; only Dwarven Stability lengthens stances.
- IAU is a shout: not extended either (20 s at max Norn rank).

The fallback durations are only used when the game's effect list can't be read; normally the remaining time comes from `GetEffectTimeRemaining` (the game's own value, mods included). Because GWA2 warns that the game may keep the old timestamp after a recast, our own cast timer is used as a floor while the effect is on us.

### 15.2 Rules implemented (`lib/Utils-ShadowForm.au3`)
- **Refresh window** `$SF_REFRESH_WINDOW_MS` = `$SOD_REFRESH_WINDOW_MS` = 2500 ms. Recast only when the skill is recharged AND remaining ≤ window; if it isn't recharged by then, it is cast as soon as it is. 2.5 s = DP send (1 ping) + SF send (1 ping) + 0.67 s SF activation + one poll of the run loop (200-500 ms) + ~0.5 s margin, at 150-300 ms ping.
- **DP → SF**: `UseSkillEx(DP)` then `UseSkillEx(SF)`, no sleep. `UseSkillEx` returns about one ping after DP's recharge starts, and the client processes the two in order.
- **Energy**: the pair needs `$SF_COMBO_MIN_ENERGY` = 20 (15 + 5). Below 20 nothing is cast, so DP isn't wasted. With foes near, up to 3 s are waited for energy.
- **Shroud priority**: Shroud is skipped if SF needs a refresh within `$SOD_SF_PRIORITY_MS` = 4 s and casting it would leave less than 20 energy.
- **IAU**: `ChestKnockdownGuard` runs every 200 ms. It looks for a foe within 1250 (earshot 1000 + 250 for movement) whose agent `Skill` field is 530 or 531. IAU fires if it is on the bar, recharged, not already active, 5+ energy, and we are not knocked down or mid-cast.
- **Skill slots** are read from the bar by skill ID at run start; a missing skill = slot 0 = skipped.

### 15.3 Findings by farm (root cause → fix)
- **Tasca + Pongmei (`ChestFarmCommon.au3`)**
  - *Wrong order:* SF was cast first and DP was scheduled 750 ms later by `AdlibRegister('UseDeadlyParadox', 750)`, so SF never got DP's faster activation/recharge, and DP's 7 s mostly ran while SF was already up. → DP then SF.
  - *Energy:* the SF branch accepted 15 energy (`$CHEST_SHADOWFORM_MIN_ENERGY`). At 15-19, DP fired (15) and SF then failed for lack of energy. → 20.
  - *Timing:* fixed 19.5 s timer from the last cast, then "as soon as recharged". With a 24 s SF that recast ~4.5 s early every cycle. Shroud: 62 s timer, no SF priority. → refresh window with the remaining time read from the game.
  - *Redundant:* the 5-try SF loop with `Sleep(20+ping)`, and `Sleep(200+ping)` after SF (UseSkillEx already waits out the activation). Removed.
  - *Slot mismatch (upstream bug):* the constants were 1 DP, 2 DwSt, 3 SoD, 4 FN, 5 SF, 6 DE, 7 DC, 8 HoS. The shipped templates (`OgejwyezHT8I6MHQ3l0kNQ4OIQ`, decoded with `tools/skills/decode_template.py`) are 1 DP, 2 SF, 3 SoD, 4 DwSt, 5 IAU, 6 DE, 7 DC, 8 HoS. Pongmei loads that template, so "Shadow Form" pressed IAU, "Dwarven Stability" pressed SF and "Feigned Neutrality" pressed DwSt. Tasca doesn't load a template; its result depends on AMG's own bar. → detection by skill ID.
  - *Pongmei chests:* `SurviveWhileOpeningChests` cast FN and then DP+SF at once. FN ends when you use a skill, so it was wasted every time. SF was also cast whenever recharged, with a 15e gate. → SF upkeep first; FN only if no SF was cast.
  - *Minor:* the Dwarven Stability gate was 10 energy; it costs 5.
- **Magmas (`MagmasRun.au3`)**
  - Already read the remaining times from the game.
  - DP was cast *alone* when SF had 5-6.5 s left; SF followed only when < 5 s were left, so DP was spent before SF and could drop with DP not yet recharged.
  - The "wait for 20 energy" loop had no time limit.
  - Shroud was recast with 20 s left (wasted ~18 s of a 70 s enchantment).
  - It had the same wrong slot constants as the chest code.
  - → shared helper with the same rules, bounded wait, slot detection, `ChestKnockdownGuard`.
  - The unused `UsingDeadlyParadox` Adlib is kept as a no-op stub.
- **Zodiac:** SF first, DP 750 ms later via Adlib (same pattern). → `CastShadowFormWithParadox`.
  - Checked and not a bug: `AdlibUnRegister(UseZodiacDeadlyParadox)` with a function reference works in AutoIt 3.3.18 (tested: one call, then unregistered).
  - Checked and not a bug: `A Or B And C` parses as `A Or (B And C)`, which is the intent.
- **Vaettirs:** DP, *then* a wait of up to `$SKILL_RECHARGE_WAIT_TIMEOUT` for SF to recharge, then SF. → the wait now comes before DP. The Monk's Protective Spirit between DP and SF is kept (the build needs it). The energy gates (> 20 / > 30) were kept.
- **GemstoneMargonite:**
  - SF was cast whenever recharged. Under Quickening Zephyr (half recharge) that is ~10 s early each time.
  - DP had no energy gate, so DP could leave too little energy for SF.
  - → window + DP only with 20 energy (DP is still skipped under Quickening Zephyr, upstream design: it costs 30% more there).
  - Not changed: IAU is cast whenever recharged with > 8 energy. Its 20 s duration is shorter than its 30 s recharge, so it never overlaps. It is used for armour/cripple there, not knockdown.
- **DragonMoss:** the DP → SF sequences were already in the right order (50 ms sleep, harmless; kept). The kill loop recast SF alone whenever recharged. → `MaintainShadowForm` (window + DP).
- **Follower:** SF was only recast after it had dropped (gap of up to one ping + poll with no SF). → `MaintainShadowForm` (window + DP if on the bar).
- **GemstoneStygian:** correct already (DP + SF only when both are recharged and 20+ energy). Not changed.
- **Not changed, reviewed:**
  - Mantids: SoD, then SF, no DP on its bar.
  - Boreal: SoD below 60% HP; IAU when foes are in casting range or crippled.
  - Raptors, CoF, SpiritSlaves, DrakeFlesh, FoW, Ministerial Commendations, Skrees, Corsairs: these IAU/SoD uses are route-specific, with no SF/DP pair.

### 15.4 Disagreements / unconfirmed
- **20-energy floor = the exact cost, with no margin.** After DP + SF at 20 energy, nothing is left for Shroud, Dwarven Stability or Dark Escape (they follow when energy allows). The floor is a named constant if a margin is wanted. Expertise does not reduce assassin costs.
- **SF alone below 20:** when SF is 0.5 s from dropping and energy is 5-19, SF is cast without DP rather than letting it drop. In a chest run losing SF is worse than missing DP once. This is a deliberate exception to "DP first".
- **The 2.5 s window** assumes ≤ ~300 ms ping. It is one constant.
- **Tasca's bar:** Tasca doesn't load a template, so the slot fix only matters if AMG's bar differs from the upstream layout. The detected slots are logged at run start, so this can be checked.
- **IAU detection** relies on the foe agent's `Skill` field, the same one `IsCasting` uses. It was not observed in game here; TESTING.md test 20 checks it.
- **Tremor** (instant shout) can't be pre-empted. No other knockdown skills were added without verified IDs.

### 15.5 Tests
- `tools/tests/test_sf_rotation.au3` (68 checks) runs the real helper and the real chest-run functions against a simulated skillbar, energy, effect list and foe list. It covers:
  - DP→SF order;
  - exactly 20e;
  - no pair at 19e;
  - SF alone at the last moment;
  - the bounded energy wait;
  - ready early → wait;
  - inside window → cast;
  - window passed → cast immediately;
  - no cast while knocked down, casting or dead;
  - Shroud active / window / SF priority;
  - IAU on Giant Stomp and Agnar's Rage, and not for other skills, far foes, recharge, already active, < 5e, knocked down, mid-cast or IAU not on the bar;
  - slot detection on both layouts and an unreadable bar;
  - the computed durations.
- Mutations (SF first, 15e floor, no window, IAU on any skill) each make it fail.
- `run_tests.sh` also fails if any DP Adlib pattern comes back.

## 16. v19: Rune of Major Vigor - keep, store and extract restored (AMG's request)

AMG: "one thing you need to add back into the bot though is being able to keep, store and salvage major vigors."
Since v12/v13 the load-time perfect-only cleaner removed every Minor/Major rune, so a ticked Major Vigor was dropped and Major Vigor armor was sold or material-salvaged. v19 makes **exactly one** exception: `Armor upgrades.All.Runes.Major Vigor`. No other Minor/Major rune comes back (tests prove Minor Vigor, Major Absorption, Major Fast Casting etc. are still removed).

### 16.1 What was restored and where
- **Keep** (`Keep components.Armor upgrades.All.Runes.Major Vigor`): back in all 4 shipped loot JSONs (ticked, as in the original v10 files) and in `DefaultCreateValuableRunesAndInsigniasArray` (`lib/Utils-Items_Modstructs.au3`, the list used before a config is loaded; v10 had it uncommented, Minor Vigor stays commented). Ticked → `ContainsValuableUpgrades` matches `C202E927`, so the armor is neither sold nor material-salvaged.
- **Extract** (`Extract upgrades only.Armor upgrades.All.Runes.Major Vigor`): back in all 4 JSONs; ticked in `AMG Loot.json` (his attached file had it ticked), unticked in the other three (as v10). It resolves to kind `rune`, struct `C202E927`, expert-salvage slot **1** (suffix/rune).
- **Cleaner exemption:** `tools/itemaudit/perfect_options.py` has `EXCEPTIONS = {'Armor upgrades.All.Runes.Major Vigor'}`; the generated allow-list `IsPerfectUpgradeOption` went 446 → 447 entries (the only addition). The cleaner warning text now says "(only max rolls / Superior runes - plus the Major Vigor exception - can be kept or extracted)".
- **Store** (new option `Store items.Runes.Major Vigor`): the original v10 had no rule for loose runes at all (only armor salvageables by rarity), so "store" needed a new option. `IsLooseMajorVigorRune` (`lib/Utils-Storage.au3`) = item type Upgrade (`$ID_TYPE_UPGRADE` = 8) AND `C202E927` at a dword boundary of the modstruct. `ShouldStoreItemWithCache` stores it when the option is ticked. It is ticked only in `AMG Loot.json`; in the other files it is off (same as before v19: loose runes were never stored). The model ID 5550 is **not** used: it is shared with Recovery/Restoration/Clarity/Purity runes.
- Armor that still has the rune in it is stored by the existing `Store items.Armor salvageables.<rarity>` rule (unchanged).

### 16.2 ID / struct verification
| Rune | Upgrade id | Bot struct (effect dword) | HP | Real dump fragment |
|---|---|---|---|---|
| Minor Vigor | 0x00FF (alt 0x00C2) | `C202E827` | +30 | `FF000824FF013025C202E827` |
| **Major Vigor** | **0x0100** | **`C202E927`** | **+41** | `0001082401023025C202E927` |
| Superior Vigor | 0x0101 | `C202EA27` | +50 | `0101082403023025C202EA27` |

Sources:
- Bot / upstream BotsHub: `$STRUCT_ALL_RUNES_MAJOR_VIGOR = 'C202E927'` (unchanged since v10).
- Py4GW `Py4GWCoreLib/item_mods_src/types.py`: `ItemUpgradeId.OfMinorVigor = 0x00FF`, `OfMinorVigor2 = 0x00C2`, `OfMajorVigor = 0x0100`, `OfSuperiorVigor = 0x0101`; `RuneOfMajorVigor` is a Suffix rune, purple, +41 HP (0x29; Superior 0x32 = 50, Minor 0x1E = 30).
- Real in-game modstruct dumps (elitepvpers, "Store Armors with Runes/Insignias" and the 2017 GW1 bot Upgrades() array listing `'C202E927' ; Rune of Major Vigor`): armor `EA0108240001082401023025C202E9270026C8A3…` and `0001082401023025C202E9270027C8A3000000C0`; loose rune `0000B8250001082401023025C202E927000000C0`. Upgrade dword `00010824` = identifier 0x2408, arg 0x0100 = OfMajorVigor.
- The three structs differ in one byte (E8/E9/EA), and matching for extraction/store is dword-aligned, so Minor/Superior can't be taken for Major (tested on the real dumps).
- **Not verified here (needs game):** that a loose rune reports type 8 and keeps the `C202E927` dword in its modstruct (the dumps say so; TESTING.md test 22 checks it).

### 16.3 Side effect revisited
v12–v13 listed "Major Vigor armor is no longer kept" as an accepted side effect (§9, §13). That is reversed: with Keep ticked, Major Vigor armor is kept (test_keep, both before and after the load cleaner).

### 16.4 Caveat for AMG's config: Store wins over Extract
`AMG Loot.json` has `Store items.Armor salvageables.Purple` and `.Gold` ticked. Since v8, Store protection is checked first: an armor piece that would be stored is never put through a salvage session. Armor with a Major rune is purple (or gold), so with his config **Major Vigor armor is stored whole, not extracted**; extraction only happens on blue armor or once those two Store ticks are cleared. This is the v8 behaviour and was not changed; the log says `[Extract] Item … skipped: protected by Store items (Store items.Armor salvageables.Purple)`.
Keep matching (`ContainsValuableUpgrades`) still uses the original `StringInStr` (not dword-aligned), unchanged since v10.

### 16.5 Shadow Form tunables (question, nothing changed)
The v18 refresh margin and energy floor are **not** GUI or JSON settings. They are named constants in `lib/Utils-ShadowForm.au3`: `$SF_REFRESH_WINDOW_MS = 2500`, `$SOD_REFRESH_WINDOW_MS = 2500`, `$SF_COMBO_MIN_ENERGY = $DP_ENERGY_COST + $SF_ENERGY_COST` (= 20). Changing them means editing that file and restarting the bot.

### 16.6 Tests
- `test_perfect`: Major Vigor is the only Minor/Major leaf allowed; resolves to `C202E927`, kind rune, slot 1; real dumps match Major only; upgrade-id dword 256 (Major) vs 257 (Superior); misaligned hex rejected; prune keeps it and still drops Minor Vigor.
- `test_keep`: Major Vigor armor kept (all ticked, only it ticked, AMG's file as saved, v10 file after the cleaner); not kept when unticked; Superior-only tick doesn't keep Major; default list has Major, not Minor; counts 447; cleaner now drops 174 of the attached file's leaves (was 176).
- `test_loot_alignment`: loose Major Vigor stored with AMG's file, not when unticked, not with Default or the attached file; loose Superior/Minor not matched; Major bytes on a non-upgrade item not matched.
- `check_alignment.py`: 0 errors; the attached file predates the new Store option (2 paths unset → not stored), accepted with that reason.

## 17. v20: Shadow Form / Deadly Paradox timing reverted; IAU on Wild Blow and Bull's Strike

AMG tested v19: "the shadow form and deadly paradox isn't working right ... set it back on its previous timing ... keep the 20 energy & everything else EXCEPT the timing for those 2 skills. keep shroud of distress how it is. HUGE improvement with iau. can you also make IAU react to wild blow or bulls strike as well because of the titans?"

### 17.1 SF/DP timing restored (recovered from `git diff d95d9c5^ d95d9c5`)
| Farm / function | v18/v19 (removed) | v20 = pre-v18 WHEN |
|---|---|---|
| Tasca, Pongmei - `ChestMaintainShadowForm` | recharged AND ≤ 2.5 s left (effect list, own 24 s timer as floor) | 19.5 s after our last SF (`$CHEST_SHADOWFORM_RECAST = 19500`) and recharged; with foes in spellcast range wait ≤ 3 s for 20 energy (`Sleep(250)` loop, as before); nothing under 15 (`$CHEST_SHADOWFORM_MIN_ENERGY = 15`) |
| Pongmei - `SurviveWhileOpeningChests` | via the refresh window | SF recharged and a foe within spellcast + 200, 15 energy (whenever recharged; does not touch the 19.5 s timer, as before) |
| Magmas - `MagmasDefendFunction` | refresh window | game effect list < 5 s left or gone (`$MAGMAS_SF_RECAST_MS = 5000`), SF needed (foes near / in front / forced), SF recharged; wait for 20 energy while foes near (bounded 3 s) |
| Margonite - `MargoniteCheckBuffs` | refresh window | whenever SF is recharged |
| DragonMoss | refresh window | whenever SF is recharged |
| Follower | refresh window | only once SF has dropped, recharged, 5 energy (then `Sleep(50)`) |
| Vaettirs, Zodiac | timing unchanged by v18 | unchanged (v18 only changed the DP→SF order there) |
| FoW Tower of Courage, Stygian, Mantids | never changed | unchanged |

### 17.2 Kept from v18 (HOW, not WHEN)
- **DP first, SF immediately after**, no Adlib / 750 ms gap (`CastShadowFormWithParadox`). Where the old timing conflicted with that (Magmas cast DP alone 5-6.5 s before the SF refresh), DP-first wins and the pair fires at the old SF time; DP is skipped if it is still active (≥ 1 s left), the original Magmas condition.
- **20 energy for DP + SF** (`$SF_COMBO_MIN_ENERGY`): DP is never started below 20. Below 20, SF is cast alone if the farm's OLD minimum is met (chest/Pongmei 15, Magmas/Margonite/DragonMoss/Follower 5 = SF's cost, as their old code had no floor). This replaces v18's "SF alone only 0.5 s before it drops", which needed the effect timer. *Flag:* before v18 the chest at 15-19 energy cast SF and a DP that then failed for energy; now it casts SF alone - same SF timing, DP not wasted.
- Live skill-slot detection + `Skill slots:` line; no Feigned Neutrality right before DP/SF; Magmas wait bounded (3 s); `CanUseSkillNow` (not while knocked down / casting / dead); Dwarven Stability gate 5 energy; no extra 200 ms sleep after SF.
- **Shroud of Distress: unchanged** (`MaintainShroudOfDistress`, 2.5 s window, SF energy priority). Its SF-priority still reads SF's remaining time (effect list + own timer), so `$SF_REFRESH_WINDOW_MS` stays as a constant only for `$SOD_SF_PRIORITY_MS` (4 s).
- **Removed:** `ShadowFormRefreshAction`, `MaintainShadowForm`, `$SF_SOLO_FALLBACK_MS`. New: `ShadowFormPairAction` (pure) and `CastShadowFormPair`.
- Tunables now: `$CHEST_SHADOWFORM_RECAST`/`$CHEST_SHADOWFORM_MIN_ENERGY` (`src/runs/ChestFarmCommon.au3`), `$MAGMAS_SF_RECAST_MS` (`src/runs/MagmasRun.au3`), `$SF_COMBO_MIN_ENERGY` (`lib/Utils-ShadowForm.au3`) - code constants, not GUI/JSON.

### 17.3 Best guesses at what went wrong in game with v18's timing (not verified - no game here)
1. **Own-timer floor too long.** v18 took the larger of the game's remaining time and `24 s − time since our cast` (24 s = 14 Shadow Arts + 20%). If the real SF is shorter (different Shadow Arts/headgear, or the +20% mod not on that weapon set), the bot believed SF still had seconds left when it had already ended → SF dropped before the refresh. The old 19.5 s timer works for any SF ≥ ~20 s.
2. **Game effect timestamps.** GWA2's own comment on `GetEffectTimeRemaining`: the cast timestamp and `GetInstanceUpTime()` disagree, and a recast does not refresh the timestamp until the previous effect ends - so the remaining time can be wrong in both directions.
3. **2.5 s window vs sparse polling.** SF upkeep only runs when the defend function is called (Pongmei: only with a foe within spellcast + 200). A 2.5 s window is easily missed between polls / during chest opening or long moves; the old 19.5 s gate has a ~4.5 s margin and fires on any later poll.
- Shroud uses the same machinery but a 69.6 s duration and a 45 s recharge, so a late refresh by a second or two does not show; that fits "Shroud is fine".

### 17.4 IAU: Wild Blow and Bull's Strike
| Skill | ID | Sources (all agree) | Effect |
|---|---|---|---|
| Giant Stomp | 530 | (v18) | AoE knockdown, 2 s before it lands |
| Agnar's Rage | 531 | (v18) | AoE knockdown |
| **Wild Blow** | **321** | bot `GWA2_ID_Skills.au3`; GWCA `Constants/Skills.h` `SkillID` enum (via gwdevhub/Daybreak's GWCA copy); Py4GW `skill_descriptions.json`; wiki Skill infobox | Melee attack: always critical, unblockable, **ends the target's stance**. **No knockdown.** |
| **Bull's Strike** | **332** | same four sources | Melee attack: knockdown **if the target is moving** |
- Titans (wiki): Burning Titan (Hell's Precipice = the Magmas run) uses Wild Blow; Titan Abomination / Flesh Glutton (Realm of Torment) use Bull's Strike; Icy Brutes have both. The wiki lists no Titans with these skills in the Underworld or the Fissure of Woe.
- Added to `$KD_THREAT_SKILL_IDS` with the same 1250 range and readiness rules (recharged, 5 energy, not active, not knocked down, not mid-cast; 200 ms Adlib). Log: `Knockdown threat (skill 321 Wild Blow) - "I Am Unstoppable!"`.
- **Limitations (honest):**
  - Detection is the foe agent's `Skill` field (the skill it is using), the same field `IsCasting` reads. For attack skills it is set for the swing only (about 1 s, weapon-dependent), not Giant Stomp's 2 s; with a 200 ms poll + one ping IAU (a shout, instant) should usually land first, but it was not observed in game here.
  - The field does not say who is being attacked: IAU can fire when the titan swings at an ally within 1250 (AMG asked for the same range).
  - Against Wild Blow IAU only gives +24 armor; it does **not** protect Deadly Paradox / Dwarven Stability from being ended.
  - Bull's Strike only knocks down a moving target; IAU fires regardless of whether we are moving.

### 17.5 Tests
`test_sf_rotation` (94 checks) now runs the real `ChestMaintainShadowForm`, `SurviveWhileOpeningChests` (Pongmei), `MagmasDefendFunction` and the helper: 19.5 s gate (10 s / 19.4 s no, 19.6 s yes), effect list ignored for the chest timing, Magmas 6 s no / 4.9 s yes / gone yes / DP still active → SF alone, DP only at 20 energy, 15-energy chest minimum, bounded waits, Pongmei whenever-recharged and FN not wasted, Shroud and IAU tests kept, Wild Blow / Bull's Strike fire within 1250 and not beyond / on recharge / active / 4 energy / knocked down, neighbouring IDs 320/333 do not. Mutations: removing the 19.5 s gate fails 5 checks, removing the Titan IDs fails 6.

## 18. v21: IAU on Irresistible Blow (the Titans' follow-up knockdown)

AMG: "what they are coded to do is hit you with wild blow to remove stances, and they have a knockdown ... They follow up with the knockdown."

### 18.1 Titan skill bars (GW wiki monster pages, fetched 2026-11-10)
| Titan | Where | Skills |
|---|---|---|
| **Burning Titan** | Hell's Precipice (Magmas run) | Irresistible Blow, Thrill of Victory, Wild Blow (+ monster Stun Immunity, burning aura) |
| Titan Abomination | Realm of Torment (Domains of Fear/Secrets/Pain, Depths of Madness, Heart of Abaddon, Gate of Madness) | Battle Rage, Bull's Strike, Counter Blow, Irresistible Blow, Mighty Blow |
| Flesh Glutton | Domain of Pain (Faded Memory only) | same as Titan Abomination |
- The knockdown is **Irresistible Blow**: Hammer Attack, 5e, 6 s recharge - "If Irresistible Blow is blocked, your target is knocked down". Thrill of Victory (324) has no knockdown.
- **ID 356** in four sources: wiki infobox, bot `GWA2_ID_Skills.au3` (`$ID_IRRESISTIBLE_BLOW = 356`), GWCA `SkillID` enum, Py4GW `skill_descriptions.json`.
- Why the combo works on us: Wild Blow ends the stance (Dark Escape, Dwarven Stability, Deadly Paradox), then Irresistible Blow - which only knocks down when blocked - meets Shroud of Distress' 75% block chance under 50% Health.
- Counter Blow (357, Abominations) knocks down only an attacking foe; the chest runners do not attack, so it is not added. Nothing else speculative was added.

### 18.2 IAU vs Wild Blow, duration vs gap
- "I Am Unstoppable!" is a **Shout** (wiki infobox, 2356): +24 armor, no knockdown, no Cripple for 16-20 s (Norn rank 0-10), 30 s recharge. Wild Blow ends only stances, so **IAU survives it**.
- Gap: Wild Blow (8 s recharge) and Irresistible Blow (6 s) are both ordinary attacks, so the follow-up is normally the next swing or two (≈ 1-3 s at Titan attack speed; not measured in game). IAU's 16-20 s covers that easily when it is cast on the Wild Blow.
- **Re-trigger:** no separate rule needed - Irresistible Blow is itself a trigger, so if IAU has expired and is recharged when the follow-up starts, IAU fires again (tested). If IAU expired and is still recharging (10-14 s of every 30 s), nothing can be done.

### 18.3 Tests
`test_sf_rotation` (102 checks): Irresistible Blow adjacent → IAU with the named log line; beyond 1250 → no; Wild Blow → IAU, then the follow-up while IAU is active → no second cast; IAU expired + recharged → fires again; IAU recharging → no; Counter Blow (357) and 355 → no. Mutation: removing 356 from the list fails 4 checks.

## 19. v22: "Extract selected components before selling" (AMG's request)

AMG: "lets change that to "Extract selected components before selling" and that's what we should make that checkmark box for. And then on the tool's page you should make it say "Manual Selected Component Extract" and it needs to specified items must be in your inventory. Also if the checkmark box is selected to do those extractions, if there is no expert salvage, buy one then continue."

### 19.1 What was wrong
The Options checkbox *Extract upgrades only* (`run.extract_upgrades_only`, `IsExtractUpgradesOnly()`) was saved and loaded but **nothing read it**: extraction (`ExtractUpgradesOnly()`) only ran from the Tools button. The checkbox did nothing.

### 19.2 New flow (`InventoryManagementBeforeRun`, trade-town outpost)
1. Travel to the trade town; store unidentified gold items (if set); sort (if set); identify all items; collect data (if set).
2. **NEW - if *Extract selected components before selling* is ticked: `ExtractSelectedComponentsBeforeSelling($tradeTown)`**:
   - reads the same list as before (Inventory tab, *Extract upgrades only* branch, perfect-only + Major Vigor), the same per-item logic (fixed salvage slots, one item at a time, survivor loop), bags 1-4, identified items only, not equipped;
   - Store items protection wins: such items are skipped with `[Extract] Item <id> skipped: protected by Store items (<path>)` and are stored whole later;
   - if no identified item holds a checked component: `[Extract] No identified item in bags 1-4 holds a checked component - nothing to extract` (no kit bought, no gold spent).
3. Material salvage (basic kits), sell materials, sell items, buy/balance etc. - unchanged.

Checked (grep + static test): nothing before step 2 sells, salvages or buys anything - `SalvageItems`, `SellItemsToMerchant`, `SellBasicMaterialsToMerchant`, `SellRareMaterialsToMerchant`, `BalanceCharacterGold` and the lockpick/rare-material buys are all after it; no other code path sells or salvages before `InventoryManagementBeforeRun`.

### 19.3 Kits
- Uses an existing Expert or Superior salvage kit first (`FindSalvageKit`, bags 1-5; basic kits cannot pick a component).
- No kit (or the kit runs out mid-pass) **and** a candidate item still needs it → buys **one Expert Salvage Kit (2991, merchant slot 3, 400 gold, 25 uses)** from the trade-town Merchant with the existing `BuyInTown` (withdraws gold from storage if needed), then continues. Same call the bot already uses for its kit restock.
- Cap: **5 kits per pass** (`$EXTRACT_MAX_KIT_BUYS_PER_PASS`, up to 125 extractions / 2000 gold). Every buy is logged: `[Extract] No Expert or Superior salvage kit left - buying an Expert Salvage Kit (2991, 400 gold), n/5 this pass` then `[Extract] Bought an Expert Salvage Kit - continuing`.
- A buy is checked by counting kits before/after (BuyInTown returns nothing on success). Failure (no gold, no merchant, no free slot): `[Extract] Could not buy an Expert Salvage Kit (not enough gold, no merchant or no free slot) - stopping; items still holding a checked component are not salvaged or sold`. Cap reached: `[Extract] Already bought 5 Expert Salvage Kit(s) this pass (cap 5) - stopping; ...`.

### 19.4 Hold: no mod is lost
While the box is ticked, `DefaultShouldSalvageItem` and `DefaultShouldSellItem` refuse any weapon/armor that **still** holds a checked component (`IsHeldForExtraction`), logged as `[Extract] Item <id> not salvaged for materials: still holds checked <kind> "<path>"` / `... not sold: ...`, and a summary `[Extract] N item(s) still hold a checked component - not salvaged for materials or sold this pass`. Covers a failed buy, the cap, a full inventory and a failed salvage session. Store-protected items are not counted (they are stored). Unticked: the hold is off, behaviour identical to v21.
- **Caveat:** an item whose extraction keeps failing stays in the bags pass after pass (it is never sold/salvaged while ticked). Watch for the summary Warn; untick or extract by hand.

### 19.5 Mid-run (explorable)
- **No extraction mid-run:** no merchant to replace a used-up kit, and foes are around during a salvage session (3 steps with waits).
- Mid-run material salvage (*Salvage during run*) uses the same hold, so it does not destroy items still holding a checked component; they wait for the next town pass.
- When mid-run inventory management goes to town, it calls `InventoryManagementBeforeRun($tradeTown)` and so gets the extraction. Fixed on the way: it used to call `InventoryManagementBeforeRun()` without the trade town, i.e. always the EotN default.
- The mid-run hold list is cached for 120 s (no log spam, `LoadExtractUpgradeDefinitions(True)` is quiet).

### 19.6 GUI
- Options checkbox: **"Extract selected components before selling"** (same JSON key `run.extract_upgrades_only`, old configs load unchanged; missing key = unticked). Tooltip: in town, before salvaging for materials and selling, extract the components checked under Inventory > "Extract upgrades only"; buys an Expert Salvage Kit if you have none; held items are not salvaged or sold; Store items protection wins.
- Tools button: **"Manual Selected Component Extract"** (230×30), with the label *"Specified items must be in your inventory (bags 1-4), with an Expert or Superior salvage kit."* and a tooltip (inventory, not equipped, identified; kit needed; Store wins; no kit bought here). Behaviour unchanged: `ExtractUpgradesOnly()` with no auto-buy.
- Smoke screenshots (Xvfb) from the v22 GUI run, kept outside the bot folder.

### 19.7 Tests
`test_extract_flow` (35 checks, mocked GWA2): order travel → identify → extract → salvage → sell; buy when no kit; re-buy when a kit runs out; cap 5 with single-use kits (5 extracted, 2 held, not salvaged/sold); failed buy (no gold / no merchant) keeps the items; Store-only items not extracted and stored; no candidate → no buy; unticked and old config without the key → identical to v21; mid-run ticked/unticked; manual Tools path never buys. Static wiring check in `run_tests.sh`: labels, JSON key, order in `InventoryManagementBeforeRun`, both predicates call the hold.

## 20. v23: Items panel - inventory + storage totals in categories (AMG's request)

AMG: "I don't want it to list the number in my inventory, I want it to list the total number in my inventory and stash. 1: Elite Tomes (all 10 classes plus the total) 2: Titles (include lockpicks here) 3: Exchangeables like doa gems, rin relics, cores, kath hammers, ect... (include armbraces of truth within this category) 4: Consumable Materials (NOT holiday drops) ... kabobs, skalefins, wintersdays gifts, celeritys, grails, armors, power stones, res scrolls, ect... 5: Sweets 6: Party 7: Alchohol". Also: "leave the informations tab how it is".

### 20.1 What changed on the Main tab
- The *Items collected* and *Titles* boxes are replaced by one group **Items (inventory + storage)** in the same footprint (x 330..625, y 39..435).
- The *Informations* box is unchanged, byte for byte (static check in `run_tests.sh` against v10). Gold, gold items, ectos and obsidian are still session gains there.
- The new module is `lib/Utils-ItemsPanel.au3`, and it reuses the bot's item constants and arrays (`GWA2_ID_Items.au3`, `PARTY_TONICS_ARRAY`, `ALCOHOLS_ARRAY`, etc.).

### 20.2 Control: a report-mode ListView with header rows
- **Columns:** a single-selection ListView with *Item* and a right-aligned *Total* column, a full-row select, double buffering and a vertical scrollbar.
- **Scrolling:** the mouse wheel and the scrollbar are native, so there is no WM_MOUSEWHEEL code.
- **Category headers:** each category starts with an UPPERCASE header row, tinted through `NM_CUSTOMDRAW` in the existing `WM_NOTIFY_Handler` (`ItemsPanelCustomDraw`). Item rows are indented.
- **Why not ListView groups:** Wine does not draw group headers, and on Windows they need the comctl32 v6 manifest. The AutoIt3.exe manifest is not guaranteed and compiled scripts may differ.
- **Why not a scrolling child window full of labels:** a ListView created inside the tab item is shown and hidden by the tab automatically. A child GUI would need its own tab show/hide handling and wheel code. It would also need about 300 label controls.
- **Status line:** a line under the list shows where the storage part comes from (20.4).
- **Tooltip:** it explains that the totals are inventory plus Xunlai storage, and that titles are session gains.

### 20.3 Categories and items (157 rows, 148 item IDs, every ID unique)
- **Verification:** `tools/itemaudit/panel_ids_verify.py` checks every row. It writes `tools/itemaudit/panel_ids.txt` and fails the suite on any problem. Current result: problems=0.
- **Pinned sources (snapshot in `panel_id_sources.json`):**
  - Py4GW `apoguita/Py4GW@0819b99 Model_enums.py`
  - GWCA `GregLando113/GWCA@e1bc303 ItemIDs.h`
  - GWToolbox++ `1ce867e InventoryManager.cpp` (its tome → profession switch)
- **Checks:**
  - every model ID equals the bot's own `GWA2_ID_Items.au3` constant and is named the same way in Py4GW;
  - no ID appears twice;
  - every tome is an `*_Elite_Tome` in Py4GW and maps to the same profession in GWToolbox;
  - no regular (non-elite) tome (21796-21805) is in the panel.
- **How many sources each ID has:** 86 IDs also have a GWCA or GWToolbox entry. The other 61 are confirmed only by Py4GW plus the bot's own constant, because GWCA has no entry for them. That covers most exchangeables/currencies, the four Consumable Materials drops, the Party items and the 23 tonics (see the tables).
- **Old items:** every one of the 26 v10 *Items collected* items still has a row (static check), and so do all 8 titles.

#### Elite Tomes (11 rows)

| Row | Model ID | Sources |
|---|---|---|
| Warrior | 21791 | Py4GW `Warrior_Elite_Tome`, GWToolbox profession switch `Warrior` |
| Ranger | 21792 | Py4GW `Ranger_Elite_Tome`, GWToolbox profession switch `Ranger` |
| Monk | 21790 | Py4GW `Monk_Elite_Tome`, GWToolbox profession switch `Monk` |
| Necromancer | 21788 | Py4GW `Necromancer_Elite_Tome`, GWToolbox profession switch `Necromancer` |
| Mesmer | 21787 | Py4GW `Mesmer_Elite_Tome`, GWToolbox profession switch `Mesmer` |
| Elementalist | 21789 | Py4GW `Elementalist_Elite_Tome`, GWToolbox profession switch `Elementalist` |
| Assassin | 21786 | Py4GW `Assassin_Elite_Tome`, GWToolbox profession switch `Assassin` |
| Ritualist | 21794 | Py4GW `Ritualist_Elite_Tome`, GWToolbox profession switch `Ritualist` |
| Paragon | 21795 | Py4GW `Paragon_Elite_Tome`, GWToolbox profession switch `Paragon` |
| Dervish | 21793 | Py4GW `Dervish_Elite_Tome`, GWToolbox profession switch `Dervish` |
| Total | - | sum of the 10 elite tomes |

#### Titles (9 rows)

| Row | Model ID | Sources |
|---|---|---|
| Asura | - | title points gained this session (unchanged v10 logic) |
| Deldrimor | - | title points gained this session (unchanged v10 logic) |
| Norn | - | title points gained this session (unchanged v10 logic) |
| Vanguard | - | title points gained this session (unchanged v10 logic) |
| Kurzick | - | title points gained this session (unchanged v10 logic) |
| Luxon | - | title points gained this session (unchanged v10 logic) |
| Lightbringer | - | title points gained this session (unchanged v10 logic) |
| Sunspear | - | title points gained this session (unchanged v10 logic) |
| Lockpicks | 22751 | Py4GW `Lockpick`, GWCA `Lockpick` |

#### Exchangeables (34 rows)

| Row | Model ID | Sources |
|---|---|---|
| Margonite Gemstones | 21128 | Py4GW `Margonite_Gemstone`, GWCA `MargoniteGem` |
| Stygian Gemstones | 21129 | Py4GW `Stygian_Gemstone`, GWCA `StygianGem` |
| Titan Gemstones | 21130 | Py4GW `Titan_Gemstone`, GWCA `TitanGem` |
| Torment Gemstones | 21131 | Py4GW `Torment_Gemstone`, GWCA `TormentGem` |
| Armbraces of Truth | 21127 | Py4GW `Armbrace_Of_Truth`, GWCA `ArmbraceOfTruth` |
| Golden Rin Relics | 24354 | Py4GW `Golden_Rin_Relic` |
| Destroyer Cores | 27033 | Py4GW `Destroyer_Core` |
| Glacial Stones | 27047 | Py4GW `Glacial_Stone` |
| Diessa Chalices | 24353 | Py4GW `Diessa_Chalice` |
| Hammers of Kathandrax | 22374 | Py4GW `Hammer_of_Kathandrax` |
| War Supplies | 35121 | Py4GW `War_Supplies`, GWCA `Warsupplies` |
| Ministerial Commendations | 36985 | Py4GW `Ministerial_Commendation` |
| Imperial Commendations | 6068 | Py4GW `Imperial_Commendation` |
| Jade Bracelets | 809 | Py4GW `LYNX_20_PLAYFUL,Jade_Bracelet` |
| Jadeite Shards | 6533 | Py4GW `Jadeite_Shard`, GWCA `JadeiteShard` |
| Amber Chunks | 6532 | Py4GW `Amber_Chunk`, GWCA `AmberChunk` |
| Burol Ironfist's Commendations | 29018 | Py4GW `Burol_Ironfists_Commendation` |
| Imperial Guard Requisition Orders  29108 | Py4GW:Imperial_Guard_Requisition_Order | ` |
| Confessor's Orders | 35123 | Py4GW `Confessors_Orders` |
| Kournan Coins | 19195 | Py4GW `Kournan_Coin` |
| Ancient Artifacts | 19182 | Py4GW `Ancient_Artifact` |
| Inscribed Secrets | 19196 | Py4GW `Inscribed_Secret` |
| Battle Commendations | 17081 | Py4GW `Battle_Commendation` |
| Trade Contracts | 17082 | Py4GW `Trade_Contract` |
| Monastery Credits | 5819 | Py4GW `Monastery_Credit` |
| Equipment Requisitions | 5817 | Py4GW `Equipment_Requisition` |
| Copper Zaishen Coins | 31202 | Py4GW `Copper_Zaishen_Coin` |
| Silver Zaishen Coins | 31204 | Py4GW `Silver_Zaishen_Coin` |
| Gold Zaishen Coins | 31203 | Py4GW `Gold_Zaishen_Coin` |
| Victory Tokens | 18345 | Py4GW `Victory_Token` |
| Lunar Tokens | 21833 | Py4GW `Lunar_Token`, GWCA `LunarToken` |
| Wayfarer Marks | 37765 | Py4GW `Wayfarer_Mark` |
| Candy Cane Shards | 556 | Py4GW `Candy_Cane_Shard` |
| Globs of Frozen Ectoplasm | 21509 | Py4GW `Glob_Of_Frozen_Ectoplasm` |

#### Consumable Materials (16 rows)

| Row | Model ID | Sources |
|---|---|---|
| Drake Flesh Chunks | 19185 | Py4GW `Chunk_Of_Drake_Flesh` |
| Drake Kabobs | 17060 | Py4GW `Drake_Kabob`, GWCA `Kabobs` |
| Skale Fins | 19184 | Py4GW `Skale_Fin` |
| Bowls of Skalefin Soup | 17061 | Py4GW `Bowl_Of_Skalefin_Soup`, GWCA `SkalefinSoup` |
| Iboga Petals | 19183 | Py4GW `Iboga_Petal` |
| Pahnai Salads | 17062 | Py4GW `Pahnai_Salad`, GWCA `PahnaiSalad` |
| Wintersday Gifts | 21491 | Py4GW `Wintersday_Gift` |
| Essences of Celerity | 24859 | Py4GW `Essence_Of_Celerity`, GWCA `ConsEssence` |
| Grails of Might | 24861 | Py4GW `Grail_Of_Might`, GWCA `ConsGrail` |
| Armors of Salvation | 24860 | Py4GW `Armor_Of_Salvation`, GWCA `ConsArmor` |
| Powerstones of Courage | 24862 | Py4GW `Powerstone_Of_Courage`, GWCA `Powerstone` |
| Scrolls of Resurrection | 26501 | Py4GW `Scroll_Of_Resurrection`, GWCA `ResScrolls,ResScroll` |
| Feathers | 933 | Py4GW `Feather`, GWCA `Feather` |
| Piles of Glittering Dust | 929 | Py4GW `Pile_Of_Glittering_Dust`, GWCA `PileofGlitteringDust` |
| Iron Ingots | 948 | Py4GW `RACING_BEETLE_20_ELDER,Iron_Ingot`, GWCA `IronIngot` |
| Bones | 921 | Py4GW `POLAR_BEAR_20_PLAYFUL,Bone`, GWCA `Bone` |

#### Sweets (35 rows)

| Row | Model ID | Sources |
|---|---|---|
| Birthday Cupcakes | 22269 | Py4GW `Birthday_Cupcake`, GWCA `Cupcakes` |
| Slices of Pumpkin Pie | 28436 | Py4GW `Slice_Of_Pumpkin_Pie`, GWCA `Pies` |
| Golden Eggs | 22752 | Py4GW `Golden_Egg`, GWCA `Eggs` |
| Honeycombs | 26784 | Py4GW `Honeycomb`, GWCA `Honeycomb` |
| Fruitcakes | 21492 | Py4GW `Fruitcake`, GWCA `Fruitcake` |
| Sugary Blue Drinks | 21812 | Py4GW `Sugary_Blue_Drink`, GWCA `SugaryBlueDrink` |
| Chocolate Bunnies | 22644 | Py4GW `Chocolate_Bunny`, GWCA `ChocolateBunny` |
| Delicious Cakes | 36681 | Py4GW `Delicious_Cake` |
| Candy Apples | 28431 | Py4GW `Candy_Apple`, GWCA `Apples` |
| Candy Corn | 28432 | Py4GW `Candy_Corn`, GWCA `Corns` |
| Creme Brulees | 15528 | Py4GW `Creme_Brulee`, GWCA `CremeBrulee` |
| Red Bean Cakes | 15479 | Py4GW `Red_Bean_Cake`, GWCA `RedBeanCake` |
| Mandragor Root Cakes | 19170 | Py4GW `Mandragor_Root_Cake`, GWCA `MandragorRootCake` |
| Jars of Honey | 31150 | Py4GW `Jar_Of_Honey`, GWCA `JarOfHoney` |
| Krytan Lokum | 35125 | Py4GW `Krytan_Lokum`, GWCA `KrytalLokum` |
| Minitreats of Purity | 30208 | Py4GW `Minitreat_Of_Purity`, GWCA `MinistreatOfPurity` |
| Blue Rock Candy | 31151 | Py4GW `Blue_Rock_Candy`, GWCA `BRC` |
| Green Rock Candy | 31152 | Py4GW `Green_Rock_Candy`, GWCA `GRC` |
| Red Rock Candy | 31153 | Py4GW `Red_Rock_Candy`, GWCA `RRC` |
| Pumpkin Cookies | 28433 | Py4GW `Pumpkin_Cookie`, GWCA `PumpkinCookie` |
| Peppermint Candy Canes | 6370 | Py4GW `Peppermint_Candy_Cane`, GWCA `PeppermintCandyCane` |
| Wintergreen Candy Canes | 21488 | Py4GW `Wintergreen_Candy_Cane`, GWCA `WintergreenCandyCane` |
| Rainbow Candy Canes | 21489 | Py4GW `Rainbow_Candy_Cane`, GWCA `RainbowCandyCane` |
| Lunar Fortunes (Pig) | 29424 | Py4GW `Lunar_Fortune_2007_Pig`, GWCA `LunarPig` |
| Lunar Fortunes (Rat) | 29425 | Py4GW `Lunar_Fortune_2008_Rat`, GWCA `LunarRat` |
| Lunar Fortunes (Ox) | 29426 | Py4GW `Lunar_Fortune_2009_Ox`, GWCA `LunarOx` |
| Lunar Fortunes (Tiger) | 29427 | Py4GW `Lunar_Fortune_2010_Tiger`, GWCA `LunarTiger` |
| Lunar Fortunes (Rabbit) | 29428 | Py4GW `Lunar_Fortune_2011_Rabbit`, GWCA `LunarRabbit` |
| Lunar Fortunes (Dragon) | 29429 | Py4GW `Lunar_Fortune_2012_Dragon`, GWCA `LunarDragon` |
| Lunar Fortunes (Snake) | 29430 | Py4GW `Lunar_Fortune_2013_Snake`, GWCA `LunarSnake` |
| Lunar Fortunes (Horse) | 29431 | Py4GW `Lunar_Fortune_2014_Horse`, GWCA `LunarHorse` |
| Lunar Fortunes (Sheep) | 29432 | Py4GW `Lunar_Fortune_2015_Sheep`, GWCA `LunarSheep` |
| Lunar Fortunes (Monkey) | 29433 | Py4GW `Lunar_Fortune_2016_Monkey`, GWCA `LunarMonkey` |
| Lunar Fortunes (Rooster) | 29434 | Py4GW `Lunar_Fortune_2017_Rooster`, GWCA `LunarRooster` |
| Lunar Fortunes (Dog) | 29435 | Py4GW `Lunar_Fortune_2018_Dog`, GWCA `LunarDog` |

#### Party (33 rows)

| Row | Model ID | Sources |
|---|---|---|
| Trick-or-Treat Bags | 28434 | Py4GW `Trick_Or_Treat_Bag` |
| Ghosts-in-the-Box | 6368 | Py4GW `Ghost_In_The_Box`, GWCA `GhostInTheBox` |
| Squash Serums | 6369 | Py4GW `Squash_Serum` |
| Snowman Summoners | 6376 | Py4GW `Snowman_Summoner` |
| Bottle Rockets | 21809 | Py4GW `Bottle_Rocket` |
| Champagne Poppers | 21810 | Py4GW `Champagne_Popper` |
| Sparklers | 21813 | Py4GW `Sparkler` |
| Crates of Fireworks | 29436 | Py4GW `Crate_Of_Fireworks` |
| Disco Balls | 29543 | Py4GW `Disco_Ball` |
| Party Beacons | 36683 | Py4GW `Party_Beacon` |
| Sinister Automatonic Tonics | 4730 | Py4GW `Sinister_Automatonic_Tonic` |
| Transmogrifier Tonics | 15837 | Py4GW `Transmogrifier_Tonic` |
| Yuletide Tonics | 21490 | Py4GW `Yuletide_Tonic` |
| Beetle Juice Tonics | 22192 | Py4GW `Beetle_Juice_Tonic` |
| Abyssal Tonics | 30624 | Py4GW `Abyssal_Tonic` |
| Cerebral Tonics | 30626 | Py4GW `Cerebral_Tonic` |
| Macabre Tonics | 30628 | Py4GW `Macabre_Tonic` |
| Trapdoor Tonics | 30630 | Py4GW `Trapdoor_Tonic` |
| Searing Tonics | 30632 | Py4GW `Searing_Tonic` |
| Automatonic Tonics | 30634 | Py4GW `Automatonic_Tonic` |
| Skeletonic Tonics | 30636 | Py4GW `Skeletonic_Tonic` |
| Boreal Tonics | 30638 | Py4GW `Boreal_Tonic` |
| Gelatinous Tonics | 30640 | Py4GW `Gelatinous_Tonic` |
| Phantasmal Tonics | 30642 | Py4GW `Phantasmal_Tonic` |
| Abominable Tonics | 30646 | Py4GW `Abominable_Tonic` |
| Frosty Tonics | 30648 | Py4GW `Frosty_Tonic` |
| Mischievious Tonics | 31020 | Py4GW `Mischievious_Tonic` |
| Mysterious Tonics | 31141 | Py4GW `Mysterious_Tonic` |
| Cottontail Tonics | 31142 | Py4GW `Cottontail_Tonic` |
| Zaishen Tonics | 31144 | Py4GW `Zaishen_Tonic` |
| Unseen Tonics | 31172 | Py4GW `Unseen_Tonic` |
| Spooky Tonics | 37771 | Py4GW `Spooky_Tonic` |
| Minutely Mad King Tonics | 37772 | Py4GW `Minutely_Mad_King_Tonic` |

#### Alcohol (19 rows)

| Row | Model ID | Sources |
|---|---|---|
| Hunter's Ale | 910 | Py4GW `Hunters_Ale`, GWCA `HuntersAle` |
| Dwarven Ale | 5585 | Py4GW `Dwarven_Ale`, GWCA `DwarvenAle` |
| Witch's Brew | 6049 | Py4GW `Witchs_Brew`, GWCA `WitchsBrew` |
| Vials of Absinthe | 6367 | Py4GW `Vial_Of_Absinthe`, GWCA `Absinthe` |
| Eggnog | 6375 | Py4GW `Eggnog`, GWCA `Eggnog` |
| Bottles of Rice Wine | 15477 | Py4GW `Bottle_Of_Rice_Wine`, GWCA `Ricewine` |
| Zehtuka's Jugs | 19171 | Py4GW `Zehtukas_Jug`, GWCA `ZehtukasJug` |
| Bottles of Juniberry Gin | 19172 | Py4GW `Bottle_Of_Juniberry_Gin`, GWCA `BottleOfJuniberryGin` |
| Bottles of Vabbian Wine | 19173 | Py4GW `Bottle_Of_Vabbian_Wine`, GWCA `BottleOfVabbianWine` |
| Shamrock Ale | 22190 | Py4GW `Shamrock_Ale`, GWCA `ShamrockAle` |
| Hard Apple Cider | 28435 | Py4GW `Hard_Apple_Cider`, GWCA `Cider` |
| Flasks of Firewater | 2513 | Py4GW `Flask_Of_Firewater`, GWCA `FlaskOfFirewater` |
| Spiked Eggnog | 6366 | Py4GW `Spiked_Eggnog`, GWCA `SpikedEggnog` |
| Aged Dwarven Ale | 24593 | Py4GW `Aged_Dwarven_Ale`, GWCA `AgedDwarvenAle` |
| Bottles of Grog | 30855 | Py4GW `Bottle_Of_Grog`, GWCA `Grog` |
| Aged Hunter's Ale | 31145 | Py4GW `Aged_Hunters_Ale`, GWCA `AgedHuntersAle` |
| Kegs of Aged Hunter's Ale | 31146 | Py4GW `Keg_Of_Aged_Hunters_Ale`, GWCA `Keg` |
| Krytan Brandy | 35124 | Py4GW `Krytan_Brandy`, GWCA `KrytanBrandy` |
| Battle Isle Iced Tea | 36682 | Py4GW `Battle_Isle_Iced_Tea`, GWCA `BattleIsleIcedTea` |

### 20.4 Unsure picks (flagged)
- **War Supplies (35121):** listed under Exchangeables because AMG's list put it there. It is also a personal consumable (pcon).
- **Trick-or-Treat Bags:** placed under Party; they could equally be Sweets.
- **Exchangeables beyond AMG's examples:** the list also includes currencies and trade-ins such as faction-trade items, Zaishen coins, tokens and marks. Faction points themselves are not items, so they are not listed.
- **Basic conset materials:** Feathers, Glittering Dust, Iron Ingots and Bones are included under Consumable Materials as conset materials. They are common crafting materials, so this is a judgement call.
- **Wintersday Gifts:** placed under Consumable Materials because AMG named them there, even though they are a holiday drop.
- **"Kath hammers":** read as **Hammer of Kathandrax (22374)**. The GW wiki API says it is the quest item from Kathandrax's Crusher. Py4GW `Hammer_of_Kathandrax` = 22374.
- **Excluded:** DP/morale items (Refined Jelly, Four-Leaf Clover, Elixir of Valor, Oath of Purity, Seal of the Dragon Empire, Shining Blade Ration). They fit no requested category. Normal tomes are excluded as AMG asked.

### 20.5 Storage verdict: readable in outposts without opening the chest
- **Where storage lives:** in memory as bags 6 (material storage) and 8-21 (14 panes). Bag 7 is unused and is skipped; bag 22 holds equipped items.
- **Evidence:**
  1. This bot's own `StoreItemsInXunlaiStorage`, `FindAllInXunlaiStorage` and `UseItemFromInventory` already read bags 8-21 in outposts without opening the chest.
  2. GWToolbox++ `Pcons.cpp` counts Storage_1..14 on map load when `InstanceType == Outpost`.
  3. GWToolbox's `AccountInventoryWindow` saves the inventory in outposts only.
  4. The GWToolbox hotkey docs say use-item works from storage while in an outpost.
- **Conclusion:** you do not need to open the chest in an outpost.
- **Explorables are not verified,** so the panel treats them as unreliable and never reads storage there.
- **Cache:**
  - each outpost read is saved per character in `cache/xunlai_counts.ini` (`time=` plus `modelID=qty`, written only when something changed);
  - in an explorable, or after a restart before the next outpost visit, the cached storage part is used and the total is marked `*` (for example `12*`);
  - another character gets its own section.
- **Status line:**
  - `Storage: read in this outpost at HH:MM` (live);
  - `Storage *: last outpost read YYYY-MM-DD HH:MM` (cached);
  - `Storage not read yet: inventory only (visit an outpost)`;
  - before attaching: `Storage not read yet: attach, then visit an outpost`.
- **How quantities are read:** bags 1-5 are counted each time; the 16-bit `Quantity` of each stack is added up.

### 20.6 Refresh: cheap and never inside a farm run
- **Forced refreshes, at safe points:**
  - run start and run end (`UpdateStats` → `UpdateItemStats`);
  - the end of `InventoryManagementBeforeRun` (after selling and storing);
  - *Open Storage*, when no run is executing.
- **Idle refresh:** in the idle or paused main loop it refreshes at most every 5 s (`$ITEMS_PANEL_REFRESH_MS`).
- **Never during a run:** no farm file calls it, and the main-loop call is guarded by `$runtime_status <> 'RUNNING'` (static check).
- **Skipped:** when not attached, during a map load (agent ID 0), and in headless mode (no panel).
- **Cost:** a refresh reads at most 21 bags. A value cell is only rewritten when its text changed, so the list does not flicker.

### 20.7 Stats, CSV, Reset
- **Titles:** the title rows keep the v10 logic (points gained this session, set in `UpdateStats`). *Reset session stats* zeroes them, along with the Informations counters.
- **Item totals:** these are absolute counts, so Reset does not touch them.
- **CSV and statistics output:** unchanged.

### 20.8 Tests
- **`test_items_panel` (77 checks):**
  - category order and row counts, plus unique keys and IDs;
  - GUI creation;
  - a live outpost read with mock bags 1-21, including material storage and skipping bag 7 and equipped items;
  - the rate limit, the attach check and the loading-map check;
  - explorable → cache marked `*`;
  - a restart that loads the cache from the INI;
  - a different character;
  - unreadable storage;
  - titles and reset;
  - custom-draw return codes;
  - the headless no-op.
- **Mutation checks:** two code changes were tried, and each one fails the test:
  - not counting material storage → 3 fails;
  - counting bag 7 → 5 fails.
- **Other updated tests:**
  - `test_reset` (78): titles are now read through the panel;
  - `test_storage` (103): Open Storage refreshes the panel only when no run is executing;
  - `test_extract_flow`: stub only.
- **Static checks:**
  - Informations block identical to v10;
  - panel footprint;
  - old labels gone;
  - the 5 refresh hooks;
  - custom draw wired;
  - v10 item coverage.
- **GUI smoke under Xvfb** from the v23 run, kept outside the bot folder.

## 21. v24: Store Mods, stuck watchdog (replaces the 10-fail pause), Tools > Empty Tab, Graphics button labels (AMG's request)

AMG: "Okay one thing we need to add is "Store Mods" into the inventory tab. Also we should remove the "if 10 fails in a row, pause bot" and what we need to add is if you get stuck on the same action for 5 minutes, you map back and start the farm setup over as if the bot hasn't been ran yet except it has and still keeps all of the data. Also are you able to create a tool for the tool tab that where it has a clickable dropdown where you select a storage tab(like I, II, III, to XIII, followed by anniversary bonus tab) and then click a button next to it that says "Empty Tab" which it then begins moving one by one the specified tab selected starting with the first slot into the characters inventory. And also on the options page can we change it from Rendering Enabled to Disable Graphics and then Rendering Disabled to Enable Graphics"

### 21.1 Store Mods (Inventory tab)
- **Where:** new leaf **Store items > Mods** (`Store items.Mods`) in the Inventory tree, between *Runes* and *Basic Materials*. It is added unticked to every shipped loot config, `AMG Loot.json` included. Tick it, then press *Apply* (and *Save*).
- **What it stores:** every **loose upgrade component** in bags 1-5 (item type 8, GWCA `ItemType::Rune_Mod` = 8, the bot's `$ID_TYPE_UPGRADE`): runes, insignias, weapon mods (hilts, hafts, pommels, strings...) and inscriptions. It uses the normal *Store items* step at the end of the trade-town pass (`StoreItemsInXunlaiStorage`, first empty slot in storage panes 8-21). It also counts as Store protection (reason `Store items.Mods`).
- **Interpretation (flagged):** AMG asked for "Store Mods" in the Inventory tab. I read this as storing the loose components rather than weapons that carry mods; weapons already have *Store items > Weapons and offhands*.
- **Why every type-8 component instead of a per-mod list:**
  - The bot only creates loose components by extracting the perfect-only options checked under *Extract upgrades only* / *Keep components*, with the v19 Major Vigor exception. Anything else in your bags as a loose component was put there by you.
  - Nothing ever sells or salvages a type-8 item, so without this option those components stay in the bags for good.
  - Matching each loose weapon mod against the keep list would rely on modstruct layouts of loose components that I could not verify for weapon mods. A silent mismatch would store nothing.
  - So the perfect-only rule is respected by what gets extracted, and Store Mods puts away whatever is there.
- **Major Vigor (v19):** *Store items > Runes > Major Vigor* still works on its own when Mods is unticked. When Mods is ticked, Major Vigor runes are stored as components anyway.
- **Not changed:** the perfect-only options, the Keep/Extract trees and the selling and salvage rules.

### 21.2 Removed: "pause after 10 failed runs in a row"
- **What it was:** a constant, not a GUI option: `MAX_CONSECUTIVE_FAILED_RUNS = 10` from the v10-improved hardening (H10, CHANGELOG "pauses after 10 failed runs in a row").
- **What changed:**
  - the check in `RunFarmLoop`, the constant and `SessionResetConsecutiveFailures()` are removed;
  - failed runs now keep looping;
  - the "N failures in a row" note in the per-run *Session:* log line stays, as information only.
- **Unchanged safety nets:**
  - the per-run hard deadline (`IsRunFailed`, max(4× expected duration, 30 min)) fails the run;
  - "Inventory full" and "client disconnected" still pause, as before.

### 21.3 Stuck watchdog (`lib/Utils-StuckWatchdog.au3`)
- **When it runs:**
  - only while a farm function executes: `RunFarmLoop` calls `StuckWatchdogStart` just before the farm call and `StuckWatchdogStop` / `StuckWatchdogAfterRun` right after it;
  - only when attached;
  - it checks once every 5 s, using AutoIt's timer callback (Adlib), with no extra thread.
- **"Same action":** none of these progress signals for **5 minutes** (`$STUCK_WATCHDOG_TIMEOUT_MS`):
  1. **Map or map type changed:** zoning, entering or leaving an explorable. A **loading screen holds the clock**, however long it takes.
  2. **Movement:** the player is at least **300** units from where the last progress was seen. The anchor moves with each progress event, so slow walking counts. Jitter inside one spot (fighting, body-blocked, rubber-banding) does not count.
  3. **XP gained:** every foe killed near the party gives XP, also at level 20. This is what keeps long legitimate fights in one spot (spirit spawns, defend points, chest waits with foes) from tripping.
  4. **A new log line:** the text was never logged before in this run. Salvaging, merchants, chests, waypoints, quests, dialogs and skill setups all log. The same line repeated in a loop ("Sending /stuck", "Moving to waypoint 3" over and over) is **not** progress, so a loop of known messages still trips. This uses a hook in `Out()` (`LogNoveltyNote`), at every level including Debug, capped at 2000 distinct texts per run.
- **Why these signals:**
  - Position alone would trip long stationary fights.
  - Log lines alone would miss loops.
  - XP is the cheap kill counter that needs no agent scan.
  - The inventory pass (selling, salvaging, storing) runs outside the farm function and is not watched. Its steps log per item anyway.
- **Not watched:** Follower, Monk Bonder, EleMonk UW Bonder and OmniFarm (they follow a human party and may idle), plus Manual Mode, Storage, Tests and TestSuite.
- **When it trips:**
  - It logs `[Stuck] No progress for 5 min (same map, moved less than 300, no XP gained, no new log line) in <farm> - mapping back to <town> and restarting the farm setup (stats kept)`.
  - It sets `$stuck_watchdog_tripped`. `IsRunFailed()` and `CheckStuck()` then fail the run for farms that poll them.
  - It **maps back at once**, from inside the timer callback, so loops that never poll anything are broken by the map change. The target is the **last outpost seen**, normally the farm's own town, where the run started. Eye of the North is the fallback if no outpost was seen yet.
  - If the character is already in that outpost (stuck at an NPC or dialog), it changes district (random EU district) to force a map reload.
- **After the farm function returns:**
  - The run is recorded as **FAILED** in the stats, CSV and session counters. Even a SUCCESS or PAUSE returned by the farm becomes FAIL, so the bot **never pauses** because of this.
  - The character is taken to that outpost if it isn't in one.
  - **Every farm setup flag** is reset (`ResetAllFarmSetupsAfterStuck`): the global setup, all 47 `*_setup` flags (including the ones `ResetBotsSetups` deliberately keeps between loops) and the party-wipe counter. The next run therefore sets up from scratch, exactly like the first run after Start.
  - Kept: all statistics, session counters, title and gold baselines, the CSV, configs, the Items panel and the attach state.
  - Logged: `[Stuck] Recovered (N this session): ...`. The session summary shows `stuck recoveries N` when N > 0.
- **If the farm still does not return,** it trips again after another 5 minutes without progress and logs the attempt number.
- **Limits:**
  - A farm that keeps running in its town after the map back (because it never checks where it is) only ends when its own code returns. The deadline and the re-trips still apply.
  - A character stuck right next to a patrol that keeps dying to party members would gain XP and never trip. That is a deliberate trade-off against false trips in fights.

### 21.4 Tools > Empty Tab
- **GUI:** a new *Empty storage tab* group on the Tools tab: a drop-down list (`I` ... `XIII`, `Anniversary`), an **Empty Tab** button next to it, and a note and tooltip.
- **Tab → bag:** `I`..`XIII` = bags **8..20** (Storage_1..13) and `Anniversary` = bag **21** (Storage_14).
  - Sources: GWCA `Constants.h` `enum class Bag` (6 Material_Storage, 7 Unclaimed_Items, 8-21 Storage_1..Storage_14, 22 Equipped_Items).
  - GWToolbox++ docs `account_inventory.mdx`: "The anniversary storage pane (Storage 14)".
  - Bag 6 is material storage and bag 7 is *unclaimed items*, not a storage tab. Neither is offered.
- **Guards:**
  - attached, and no farm running (the same `IsAttachedForTools()` as the other Tools; it shows the usual "Pause the farm..." or "Attach to Guild Wars first" box);
  - the client is running;
  - **in an outpost or town** with the character loaded. In explorables the game shows storage view-only, so it logs `Items can only be taken out of storage in an outpost or town ...` and moves nothing.
  - It opens the Xunlai window like Open Storage, so you can watch the moves.
- **Moves (`EmptyStorageBag` / `MoveStorageItemToInventory`):**
  - One item at a time, from **slot 1** to the last slot of the tab, into **bags 1-4**. The equipment pack takes only equipment, so it is never a target. Only the configured *Use bags* count is used.
  - **Stacks:** a stackable item first tops up partial stacks (< 250) of the same item already in the bags. Same model and dye colour are required, so dyes of another colour are not merged. The rest goes to the first empty slot. The same move packet is used as the bot's own storing, which relies on the game merging up to 250.
  - Each move is **confirmed** by re-reading the storage slot (up to 3 s), with a random ~0.6 s pause between moves for a human-like pace.
- **Stops cleanly and logs:**
  - **inventory full:** `[Empty Tab] Inventory full - stopped at tab <T> slot <n>. Emptied <k> slot(s); the rest stays in storage.`;
  - a move the game does not confirm;
  - leaving the outpost or a disconnect;
  - a pane that isn't available (not unlocked).
  - Otherwise it logs `Done: storage tab <T> emptied (<k> slot(s) moved ...)` or `already empty`.
  - The Items panel is refreshed afterwards.

### 21.5 Options: graphics button labels
- The button now shows the **action** of a click: **Disable Graphics** while the game renders (yellow, as before) and **Enable Graphics** while rendering is off (green, as before).
- The text is set in the two places that set it: the creation (`GUICtrlCreateButton`, default "Disable Graphics") and `RefreshRenderingButton()`, which runs at start-up from the config and on every click. Behaviour and the `run.disable_rendering` config key are unchanged.

### 21.6 Tests
- **`test_watchdog` (88 checks, real module and real logger):**
  - excluded farms;
  - the trip at 5:00 but not at 4:59;
  - re-trips;
  - movement 299 vs 300, anchor and drift;
  - XP;
  - unreadable XP;
  - map change and loading hold (12 min of loading);
  - new log lines vs repeated ones;
  - start/stop;
  - the trip maps back to the farm town and changes district when already there;
  - FAIL after a trip (also from PAUSE), with setups reset and recoveries counted;
  - the Eye of the North fallback.
  - Mutation checks: no XP signal → 1 fail; loading not held → 1 fail.
- **`test_emptytab` (58 checks, real functions, mocked storage with game-like merge):**
  - the mapping of all 14 tabs;
  - slot-1-first order;
  - stack top-up, dyes and full stacks;
  - inventory full, including a partial top-up;
  - the equipment pack is never used;
  - the bags count is respected;
  - an unconfirmed move;
  - leaving the outpost;
  - a missing pane;
  - an empty tab;
  - the button guards (not attached / running, explorable, loading, no agent, unknown tab) and the outpost run (window opened, panel refreshed).
  - Mutation check: no dye check → 2 fails.
- **`test_loot_alignment` (+19):**
  - `Store items.Mods` present and unticked in all 4 configs;
  - the store decisions with Mods on and off (Superior Vigor, any component, Major Vigor interplay, a non-upgrade item, an old config without the key);
  - `@store.something`.
- **Static (`run_tests.sh`):**
  - every `*_setup` flag in the code is reset after a stuck recovery;
  - the 10-fail pause is gone;
  - the watchdog order around the farm call (before stats and CSV);
  - the IsRunFailed and CheckStuck hooks;
  - the Graphics labels, and the old texts gone;
  - the Empty Tab wiring and guards.
- **Alignment:** the exported attached file now also lacks `Store items.Mods` (accepted, documented).
- **GUI smoke** from the v24 run, kept outside the bot folder.


## 22. v25: Store items > Components > Mods / Inscriptions / Insignias / Runes, stored right after extraction (AMG's request)

AMG: "I can't find where the mods/inscriptions/insignias/runes tabs are under "Store Items" in inventory? I thought we were doing that, and if not can we? It needs to be used and ran after everything is extracted and before anything is sold"
Then: "So when you expand 'Store Items', there should be a components tab that breaks off into those 4 branches."

### 22.1 Why the v24 checkbox wasn't found
- **v24 never had the four branches.** It added one flat leaf, *Store items > Mods*, that stored every loose component. So the mods/inscriptions/insignias/runes tabs AMG looked for did not exist. That was my reading of "Store Mods" in v24 (§21.1), and it was the wrong one.
- **The leaf was easy to miss.** The Inventory tree starts fully collapsed. *Mods* was about the 9th of 17 children of *Store items*, below *Weapons and offhands* and *Armor salvageables*.
- **It doesn't show in older loot files.** The tree only shows keys that are in the loaded loot file (`BuildTreeViewFromCache` draws the cache, and `FillInventoryCacheFromJSON` fills it from the file). v24 put `Store items.Mods` in the four shipped files only. None of the shipped farm configs uses *AMG Loot*: they point to *Default Loot Configuration*, *Loot* or *Sin Tasca's ChestRun*. A loot file that AMG exported or saved himself, like the one he sent, has no `Store items.Mods` key, so the leaf did not appear at all. The same happens if he kept his old `conf/loot` folder when he updated. This is the most likely cause.
- **v25 fixes all three:**
  - the four branches now exist;
  - the tree opens on them;
  - the bot adds the keys to any loot file at load.

### 22.2 The tree (exact GUI path)
**Inventory** tab > **Store items** (already expanded at start) > **Components** (already expanded, first child) > **Mods** / **Inscriptions** / **Insignias** / **Runes** > entries.
- **Mods:** `<Weapon>` > `Prefix - …` / `Suffix - …` > the mod, e.g. *Sword > Suffix - Pommel > of Fortitude (Health +30)*. The layout is the same as *Keep components > Mods*.
- **Inscriptions:** the groups are *(general)*, *Weapon*, *Weapon > Martial*, *Weapon > Spellcasting*, *Offhand*, *Offhand > Focus* and *Offhand > Shield*. The layout is the same as *Keep components > Inscriptions*.
- **Insignias:** `All` / `<Profession>` > the insignia (from *Keep components > Armor upgrades > … > Insignias*).
- **Runes:** `All` / `<Profession>` > the rune (from *Keep components > Armor upgrades > … > Runes*). This includes **Runes > All > Major Vigor**, which moved here from the v19 `Store items.Runes.Major Vigor`. There is one Major Vigor entry, no duplicate.
- **Entries:** exactly the 447 perfect-only leaves of *Keep components* / *Extract upgrades only*, plus the Major Vigor exception. That is 299 mods, 52 inscriptions, 45 insignias and 51 runes.
- **Checkboxes:** ticking **Components** ticks all four branches; ticking a branch, weapon or profession ticks everything under it. This is the tree's normal parent-checkbox behaviour.
- **Unchanged:** the other *Store items* entries (Gold, Consumables, Weapons and offhands, Armor salvageables, materials, …) stay in their places, below Components.
- **Removed:** the v24 *Store items > Mods* leaf and the v19 *Store items > Runes* node. They are replaced and migrated (§22.5).

### 22.3 How a loose component is identified (verified, with limits)
- **What counts as loose:** an item of type 8 in bags 1-5 (`$ID_TYPE_UPGRADE`; GWCA `ItemType::Rune_Mod` = 8, Py4GW `ItemType.Rune_Mod`).
- **The layout.** Py4GW (`item_mods_src/item_modifier_parser.py`, `upgrade_parser.py`, `item_mod.get_target_item_type`) parses a loose upgrade with the same modifiers as an upgrade sitting on an item, plus a **TargetItemType** modifier (`0x25B`, `arg1` = item type the upgrade goes on):
  - `[0x25B8 TargetItemType][0x2408 Upgrade id][0x2530 / 0x2532 tooltip][effect dwords]`
  - The v19 loose rune dumps (Minor/Major/Superior Vigor) show exactly this: `0000B825` (TargetItemType, arg1 0 = armor), then `…0824` (upgrade id), `…3025`, and the effect `C202E927` / `C202EA27`.
- **Matching** (`FindStoreComponentMatch` → `LooseComponentMatchesDefinition`). Each ticked leaf is resolved with the same `ResolveUpgradeLeafDefinition` used by Keep/Extract, and is subject to the same perfect-only rule.
  - **Runes / insignias:** the leaf's identity dword must be present (the same test as on armor and as v19's `IsLooseMajorVigorRune`). So Superior Vigor and Major Vigor are told apart.
  - **Weapon mods:**
    - The effect must sit in an upgrade group whose upgrade id is a prefix or suffix of the ticked kind, with the max-roll requirements. This is the same `FindUpgradeGroupForStruct` matcher used for extraction.
    - The mod must also be **for the ticked weapon**. The weapon comes from the upgrade id, using the 220 Py4GW ids (e.g. `0x00DD` OfFortitude_Sword, `0x00D9` OfFortitude_Axe). If the id is not in the table, the weapon comes from the TargetItemType dword.
    - So an Axe grip of Fortitude is not stored when only *Sword > Pommel > of Fortitude* is ticked.
  - **Inscriptions:** the effect must sit in an inscription group (`0x2532`, inscription upgrade id) with the max-roll requirements. Inscriptions are not weapon-specific.
- **Limitations:**
  - The rune layout is confirmed by real dumps. For loose **weapon mods and inscriptions** I have Py4GW's parser, which treats them like runes, but no in-game dump. The tests build them from that layout.
  - A loose mod whose weapon cannot be determined (an unknown upgrade id and no TargetItemType dword) is **not** stored. It stays in the bags and is still never sold or salvaged. It is not guessed.
  - Please run TESTING P10 test 49, which captures `PrintItemInformationsAt` for one loose mod and one inscription.

### 22.4 When it runs: right after extraction, before any salvage or sale
`InventoryManagementBeforeRun` order (trade town):
1. Store unid golds.
2. Sort.
3. Identify.
4. Collect data.
5. **4b** Extract selected components (v22).
6. **4c (new) Store the components ticked under Store items > Components** (`StoreSelectedComponentsBeforeSelling`). This includes the ones just extracted.
7. Salvage for materials.
8. Sell materials.
9. Sell items.
10. Gold.
11. Buy.
12. The normal Store items step.
- **4c runs whenever something under Components is ticked,** even with the extraction option off. It travels to the trade town first if needed. It logs `[Store] Storing N component(s) ticked under Store items > Components (before salvaging/selling)` and `[Store] Stored N component(s)`.
- **Storage full:** one warning, `[Store] Xunlai storage is full - N component(s) stay in your bags (never sold or salvaged); continuing`. The pass goes on with salvage and selling for the other items.
- **Protection:**
  - Loose components are never salvaged or sold. Before v25 this held only because no rule matched type 8. Now `DefaultShouldSalvageItem` and `DefaultShouldSellItem` both return False for any type-8 item, before every other rule.
  - A ticked component also counts as Store protection (reason `Store items.Components.<leaf>`).
- **Mid-run** (`InventoryManagementMidRun`, in explorables): no Xunlai, so there is no store step. No extraction happens there (v22), and loose components are never salvaged. Anything left is handled at the next town pass.

### 22.5 Older configs and migration (`MigrateStoreComponentOptions`, at every load)
- **Missing keys:** every *Keep components* leaf (or *Extract upgrades only* if Keep is missing) gets its *Store items > Components* leaf, added **unticked** if it's not there. So any loot file shows the four branches, including an old export. Log: `[Loot] Added Store items > Components (447 option(s), unticked) - save the loot configuration to keep them`.
- **v24 `Store items.Mods`:** if it was ticked, every Components leaf is ticked, which matches what it stored before. The key is then removed.
- **v19 `Store items.Runes.Major Vigor`:** its value moves to *Components > Runes > All > Major Vigor*, and the old key is removed.
- **Order:** Components becomes the first child of *Store items*, and nothing else is reordered or changed.
- **Saving:** *Save* writes the new keys into the JSON. On a v25 file the migration changes nothing (tested).
- **AMG's attached export:** it loads with the usual single warning about the 174 non-perfect leaves, and Components is added unticked (screenshot `v25_7`).

### 22.6 AMG Loot.json
Generated by `tools/itemaudit/gen_store_components.py`. Components are ticked **exactly where Keep components or Extract upgrades only is ticked**: 130 of 447 leaves.
- **Mods:** 119.
- **Inscriptions:** 9.
- **Runes:** 2, Superior Vigor and Major Vigor (Major Vigor was also ticked in the v19 store option).
- **Insignias:** 0 (none ticked in Keep/Extract).

The other three shipped configs have every Components leaf unticked; their v19/v24 values were unticked.

The files keep their encoding: AMG Loot, Loot and Sin Tasca's ChestRun have a BOM and CRLF, and the Default config has no BOM, uses LF and ends with a newline.

### 22.7 Behaviour change vs v24
v24 *Mods* stored **every** loose component. v25 stores only the ticked ones. An unticked loose component (for example one you dropped in your bags yourself) stays in the bags and is still never sold or salvaged. To get the v24 behaviour, tick **Components**.

### 22.8 Verification
- **Au3Check:** 0 errors, 47 warnings, identical to v24.
- **New `test_storecomp` (102 checks; the real loader, store decision and step 4c):**
  - the tree layout in all 4 configs;
  - AMG's ticks equal Keep OR Extract;
  - per-group decisions for Mods (weapon-specific, perfect-only, TargetItemType fallback), Inscriptions, Insignias and Runes (Superior ≠ Major ≠ Minor Vigor);
  - group ticks;
  - the memo refreshed on Apply;
  - the protection reason;
  - migration (v24 Mods on/off, v19 Major Vigor, the attached export, no Keep branch, idempotent);
  - step 4c: only ticked items stored, travel, storage full continues, nothing to do = no travel.
- **`test_extract_flow` +9:** the order *extract → store components → salvage → sell*; storage full continues; unticked = the v24 flow; extraction off; mid-run has no store step.
- **`test_loot_alignment` and `test_keep`:** updated for the new keys.
- **Static checks (`run_tests.sh`, with a self-test that must fail):**
  - 4c sits between 4b and every salvage or sale;
  - the type-8 guards come first in the salvage and sell predicates;
  - migration runs between pruning and the cache fill;
  - the tree is expanded;
  - the old keys are gone from code and configs.
- **Mutations (`tools/mutation/mutate_v25.py`):** 11 of 11 caught (weapon check, perfect filter, v24/v19 migration, missing-key add, Components first, memo, storage-full log, unticked stored, step after salvage, step dropped).
- **Alignment:** errors 0. The attached export lacking the 509 new tree paths is accepted and documented.
- **GUI smoke** from the v25 run, kept outside the bot folder:
  - the tree as opened;
  - Mods and Sword;
  - AMG's Runes > All;
  - Inscriptions > Weapon;
  - Insignias;
  - the old export migrated.
- **Not changed:**
  - perfect-only mods with the Major Vigor exception;
  - Open Storage anywhere;
  - no lockpick notifications;
  - the SF/DP pre-v18 timing and IAU;
  - the other loot choices;
  - memory offsets and packet headers.

## 23. v26: slaying suffixes ("+20% damage vs creatures") and 19% rolls kept (AMG's report)

AMG: "so the mods that have +dmg% (vs creatures) aren't salvaging and also it's keeping 19% mods when i only want the 20%."
Then: "check all things regarding the inventory tab and the 20% vs creatures mods".

The "+dmg% (vs creatures)" mods are the slaying suffixes: *of Deathbane* (Undead), *of Charrslaying*, *of Trollslaying*, *of Pruning* (Plants), *of Skeleton / Giant / Dwarf / Tengu / Demon / Ogre / Dragon Slaying*. They give **Damage +15..20% (vs. <species>)** and exist only on Axe grips, Bow grips, Hammer grips, Staff wrappings and Sword pommels (Py4GW `OfSlaying_Axe/Bow/Hammer/Staff/Sword`, upgrade ids `0x00D4`-`0x00D8`).

### 23.1 Root cause 1: slaying suffixes never matched (not extracted, not kept, not held, not stored)
- **How the bot identified a slaying suffix (v11-v25):** the leaf's constant is the **BaneSpecies** dword (`000s8080`, effect `0x008`, `arg1` = species), and the max roll is a requirement on the **DamagePlusVsSpecies** dword (effect `0x224`, `arg1` = damage %, `224:1:20`). `FindUpgradeGroupForStruct` required the BaneSpecies dword to be **one of the effect dwords of the suffix group** (right after the `0x2530` tooltip, up to 3 effects).
- **How Py4GW reads it:** `upgrade_parser.py` builds `DamagePlusVsSpecies` from the `0x224` dword and takes the species from `get_species(modifiers)`, which searches **all the item's modifiers** for BaneSpecies. `OfSlayingUpgrade.upgrade_info` is made of the `0x224` effect only. So the BaneSpecies modifier is an item-wide modifier, not one of the group's effects.
- **Consequence:** on a real weapon the BaneSpecies dword sits outside the suffix group, so the v25 matcher returned "not found" for every slaying leaf, at every roll. Every feature that uses the matcher missed it:
  - *Extract upgrades only* and the *Manual Selected Component Extract* tool (`FindCheckedUpgradeOnItem` → `UpgradeDefinitionPresentOnItem`): the weapon was skipped ("has none of the checked upgrades"). This is AMG's "aren't salvaging".
  - *Extract selected components before selling* hold (`IsHeldForExtraction`): never held.
  - *Keep components* on inscribable weapons (`ContainsValuableUpgrades` → `KeepUpgradePresent`): a 20% slaying weapon was not kept.
  - *Store items > Components* (`LooseComponentMatchesDefinition`): a loose 20% slaying grip/pommel/wrapping was only stored if its BaneSpecies happened to sit inside the group.
- **Why the tests did not catch it:** the v12/v13 tests built the slaying group with the BaneSpecies dword inside the group, which is the layout the matcher expected.

### 23.2 Root cause 2: 19% (and 15-18%) slaying weapons were kept
- `ContainsValuableUpgrades` had two paths. Inscribable weapons used the checked *Keep components* lists with the max-roll matcher. **Old-school (non-inscribable) weapons** used `$valuable_mods_by_os_weapon_type` instead:
  - a **hardcoded** list (`DefaultCreateValuableModsByOSWeaponTypeMap`), never refreshed from the tree (the refresh line was commented out), so AMG's ticks were ignored;
  - matched with an **unaligned `StringInStr`** on the raw modstruct;
  - holding the slaying BaneSpecies dwords for Charr, Trolls, Giants, Dwarves and Tengu on every axe, bow, hammer, staff and sword, **with no roll check**, plus *of the Necromancer* / *of the Ranger* on several weapon types.
- **Consequence:** any old-school weapon with one of those slaying suffixes, at **any** roll (15-20%), ticked or not, was "valuable": `ShouldKeepWeapon` returned True, so it was never salvaged for materials and never sold. This is AMG's "keeping 19% mods".
- **Other percentage families (audit):** every other perfect option's constant pins the max roll in the dword itself (`tools/itemaudit/perfect_verify.py`, regenerated by the suite), so a lower roll is a different dword. The only requirement-based families are slaying (`224:1:20`), To the Pain / Brawn over Brains (`223:2:15`) and Ignorance is Bliss / Life is Pain (`210:2:5`). All of them use strict equality with the max. The OS path was the only place that matched without the requirements. No other off-by-one exists.

### 23.3 Fixes
- **`FindSlayingUpgradeGroup`** (new, `Utils-Items_Modstructs.au3`), called by `FindUpgradeGroupForStruct` for any BaneSpecies constant (`IsBaneSpeciesStruct`). This is the one matcher every feature uses. A slaying leaf matches when both hold:
  1. the item carries a BaneSpecies dword **of that species**, dword-aligned, **anywhere** in the modstruct (Py4GW `get_species`);
  2. a weapon-mod group (`0x2530` marker) that is a **suffix** (a known prefix or inscription id is skipped; a header-less group uses the legacy single-effect rule) carries the DamagePlusVsSpecies effect, or the BaneSpecies itself for the old in-group layout, **and** meets the leaf's requirement `224:1:20` (= exactly 20%).
  - This works whether the BaneSpecies sits after the base stats, before the groups or inside the group (all three are tested).
  - Inscription markers never match a slaying leaf, a misaligned BaneSpecies is ignored, and another species never passes.
  - A suffix id outside Py4GW's `OfSlaying_*` entries is still accepted, so a gap in the id table cannot hide a real slaying suffix (the damage-vs-species effect only exists on slaying suffixes).
- **`ContainsValuableUpgrades`:** old-school weapons now use the same checked *Keep components* lists and max-roll matcher as inscribable ones. The hardcoded list is no longer used for keeping (it stays defined, so nothing else changes), and the unaligned `StringInStr` is gone from the weapon path. Au3Check now reports 46 warnings instead of 47 (the "possibly used before declaration" warning of that list disappeared).
- **Log help:** the Debug line `[Extract] Item at b:s has none of the checked upgrades - skipped` now ends with ` (slaying: species <n>, damage +<x>% vs species)` when the item has a slaying suffix (`DescribeSlayingOnItem`), so an in-game log shows the roll the bot read.
- **Not changed:** memory offsets, packet headers, rotations, the tree layout, other loot settings, and AMG's ticks.

### 23.4 Which mods were affected
- **Bug 1 (never matched):** all 55 slaying leaves (11 species × Axe grip, Bow grip, Hammer grip, Staff wrapping, Sword pommel) in Keep components, Extract upgrades only and Store items > Components. AMG has 7 species ticked on all 5 weapons (Deathbane, Charrslaying, Skeleton, Dwarf, Tengu, Demon, Dragon Slaying), plus *Axe > of Pruning* under Extract.
- **Bug 2 (kept at any roll):** old-school axes, bows, hammers, staves and swords with *of Charrslaying, Trollslaying, Giant Slaying, Dwarf Slaying, Tengu Slaying* (any roll), and old-school weapons with *of the Necromancer* (those five plus wands and daggers) or *of the Ranger* (axes, bows, daggers, hammers, swords). These were kept even when unticked. Now they are kept only when ticked under Keep components **and** at the max roll.
- **Behaviour change:** an old-school weapon is now kept for its mods only when the mod is ticked under *Keep components* (the other `ShouldKeepWeapon` rules — rare skins, perfect OS mods, greens, equipped, customized, unidentified — are unchanged).

### 23.5 Per-feature audit (Inventory tab)

| Feature | Result | Notes |
|---|---|---|
| Keep components (inscribable weapons) | **Fixed** (bug 1) | 20% kept; 15-19% not kept |
| Keep components (old-school weapons) | **Fixed** (bug 2 + bug 1) | ticked 20% kept; 19%/15% and unticked species salvaged/sold per your rules |
| Extract upgrades only | **Fixed** (bug 1) | 20% extracted, suffix slot 1; 15-19% skipped |
| Manual Selected Component Extract tool | **Fixed** (bug 1) | same matcher (`FindNextUpgradeExtractionCandidate` → `FindCheckedUpgradeOnItem`) |
| Extract selected components before selling + hold | **Fixed** (bug 1) | 20% held until extracted; 19% not held, salvaged/sold normally |
| Store items > Components (loose slaying grips/pommels/wrappings) | **Fixed** (bug 1, layout-independent now) | 20% stored when ticked; 19% not stored; never salvaged/sold (type 8) |
| Store items > Weapons and offhands / Armor salvageables | Pass | rarity/type/req only, no mod logic. Note: AMG stores Gold Req 8 weapons whole, so a Gold Req 8 slaying weapon is stored, not extracted (by design: Store items is checked first) |
| Salvage items (materials) | **Fixed** via ShouldKeepWeapon | AMG Loot has no weapon salvage rule ticked, so weapons are only extracted, not salvaged for materials |
| Sell items | **Fixed** via ShouldKeepWeapon | 19% slaying weapons now sold when the rarity/type/req rule is ticked |
| Tree / JSON alignment (4 loot files) | Pass | all 55 slaying leaves under Keep / Extract / Store Components in every file; none on Dagger/Scythe/Spear/Wand/Focus/Shield; AMG's Components ticks = Keep OR Extract (36 slaying leaves) |

### 23.6 Limitation (honest)
- There is still no in-game modstruct dump of a slaying weapon. The fix follows Py4GW's parser exactly and accepts all three plausible positions of the BaneSpecies dword, so it does not depend on the position. It does depend on two Py4GW facts: the effect ids (`0x008`, `0x224`) and the damage % in `arg1` of `0x224`.
- If the 20% one is still skipped in game, the Debug line from §23.3 shows what the bot read, and `PrintItemInformationsAt` for that weapon settles it (TESTING P11 test 52).

### 23.7 Verification
- New `tools/tests/test_slaying.au3` (112 checks): REAL matcher, REAL Keep (inscribable + old-school, with the bot's hardcoded OS list loaded as in game), REAL `LoadExtractUpgradeDefinitions` / `FindCheckedUpgradeOnItem` / `IsHeldForExtraction`, REAL `DefaultShouldSalvageItem` / `DefaultShouldSellItem` → `ShouldKeepWeapon`, REAL `ShouldStoreItemWithCache`, on the real loader with AMG Loot.json, plus the 4-file alignment.
  - Section 52: 990 matcher cases (55 leaves × 3 layouts × 15..20%), only 20% of the right species matches.
  - **Run against the v25 code it fails 46 checks** (44 plus the 2 checks of the new log helper; both bugs reproduced: `tools/out/v26_slaying_v26_vs_v25.log`); against v26 it passes.
- Mutations: `tools/mutation/mutate_v26.py`, 12/12 caught.
- Au3Check: 0 errors, 46 warnings (v25: 47; the only difference is the removed warning above).
- Full suite (`tools/run_tests.sh`): exit 0, every unit test passing; alignment errors 0.

## 24. v27: old-school weapons are no longer kept for their inherent mods; the only OS auto-keeps (AMG's request)

AMG (t33u): "When I want any 'perfect mods' i mean like the ones you can salvage, so those inscriptions yes I want, but the inherent ones? no don't automatically keep, now the zelous or perfect vampiric, yes if I have it selected that I want to extract the mod and sell the item thats what it should do. if it's 15%^50 OS? no, don't automatically keep it. the only OS items i want automatically kept without any filters needing to select it is +5 energy q9 old school weapons and then q9 20% cast and recharge of spells matching the required item attribute (q9 domination 20% cast domination 20% recharge domination) for mainhand, same for offhand."
Clarifications: t36u "also … the q9 mainhand and offhand for 10% spells speed cast/recharge"; t37u "q9 and q10 (q9 & 10 is only for wand and offhand …) +5 still has to be q9"; t38u "if it is a q9 or 10, then 20% with matching attribute and 10% all spells keep it"; t39u "don't include staffs at all, this is just main hand and offhand onehand items"; t40u "20/20 yes 20/10 yes 10/20 yes. single 20% or 10%, no".

### 24.1 What v26 did (root cause of the unwanted keeps)
`ShouldKeepWeapon`, old-school (non-inscribable) branch, after the generic rules:
- **req >= 9:** rare skin (`$MAP_RARE_WEAPONS`) → kept if `HasPerfectMods` or `HasAlmostPerfectMods`; shield / focus / wand → kept if `HasPerfectMods`; anything else → not kept.
- **req < 9:** kept if `HasPerfectMods` or `HasAlmostPerfectMods`, or rare skin + `HasOkayMods`.
- `HasPerfectMods` = the item holds **two** of the hardcoded `DefaultCreatePerfectModsByOSWeaponTypeMap` strings for its type, found with an **unaligned `StringInStr`** on the raw modstruct. Those lists are mostly **inherent** mods: 15^50 / +15% enchanted / +15% stance / -5 energy +15%, zealous / vampiric *strength* (the inherent part), +30 health, armor vs species, +5 energy, HCT/HSR 20% of **any** attribute (the attribute byte was cut off: `'0218240'`), 10% HCT/HSR, etc. `HasAlmostPerfectMods` / `HasOkayMods` just call `HasPerfectMods`.
- **Consequences:** a 15^50 OS axe, a +15% enchanted sword, a q9 shield with +30 health and armor vs demons, a staff with 20/20 Fire, a wand with 20/20 Domination on an Illusion item, a q8/q11/q13 wand with 20/20, an OS q8 +5 energy axe… were **kept whole** without any tick, never salvaged or sold. And the rules AMG wants were missed: a q9 OS axe/sword with inherent +5 energy (not a rare skin, not a shield/focus/wand) was sold; a 10/10 or 20/10 wand/focus was sold (only one of the two strings in the list).

Other whole-weapon auto-keeps found in the audit (unchanged, not mod-based): equipped, customized, green, unidentified, `$MAP_ULTRA_RARE_WEAPONS` (by **model**, e.g. Eternal Bow / BDS / Voltaic - not by mods), *Keep components* ticks (`ContainsValuableUpgrades`, max roll), and the inscribable rules (q9 rare skin, low-req max damage of a good type). The rare-skin OS rules were mod-based, so they are removed with the rest (AMG: "only").

### 24.2 How Zealous / Vampiric are represented
- The salvageable **Zealous** / **Vampiric** hilt, haft, grip … is a prefix upgrade group: `[2408 upgrade id][2530 tooltip][Energy gain on hit / Life draining][-1 regeneration]` (e.g. `Vampiric_Sword` `0x00AA`). It matches the *Keep components* / *Extract upgrades only* leaf with the exact (max) constant, like every other mod.
- The OS lists' "zealous / vampiric **strength**" (`$STRUCT_INHERENT_ZEALOUS_STRENGTH`, `$STRUCT_INHERENT_VAMPIRIC_STRENGTH`) are inherent dwords of old-school weapons, not the salvageable prefix. v27 never keeps a weapon because of them.
- So Zealous / Vampiric follow the ticked lists only: ticked under Extract → held, extracted (perfect roll only), then the bare weapon goes to salvage/sell by the normal rules. Ticked under Keep components → kept (AMG Loot ticks Vampiric under both; Zealous is unticked). Unticked → normal rules.

### 24.3 The fix
`ShouldKeepWeapon`: after the unchanged generic rules (equipped, customized, white, green, unidentified, ultra-rare model, ticked Keep components), an old-school weapon returns **`IsOSAutoKeepWeapon($item)`** and nothing else. The rare-skin / `HasPerfectMods` / `HasAlmostPerfectMods` / `HasOkayMods` OS rules are gone (the functions stay but are no longer called). Inscribable weapons keep their v26 rules exactly.

`IsOSAutoKeepWeapon` (Utils-Storage.au3) reads the item's own modstruct, dword-aligned, with Py4GW's effect ids:
- **Requirement:** `AttributeRequirement` `0x279` (arg1 = attribute, arg2 = level), the same dword as GWA2 `GetItemReq` / `GetItemAttribute` (`GetModStructRequirement`).
- **a) Energy +5:** requirement **9** and an **inherent** `EnergyPlus` `0x22D` +5 (`'0500D822'`), any OS weapon type. `HasInherentEnergyPlusFive` ignores a +5 that belongs to a salvageable upgrade group (`Insightful` staff head, *I have the power!* inscription). +4 or any other value does not count.
- **b) HCT + HSR pair:** **wand** or **focus** (offhand) only, requirement **9 or 10**, staves never. `HasCasterHalvesPair` needs **both**:
  - casting: `HalvesCastingTimeAttribute` `0x221` **20%** with arg2 = the **requirement attribute**, or inherent `HalvesCastingTimeGeneral` `0x220` **10%** (all spells);
  - recharge: `HalvesSkillRechargeAttribute` `0x239` **20%** of the requirement attribute, or inherent `HalvesSkillRechargeGeneral` `0x23A` **10%**.
  - So 20/20, 10/10, 20/10 and 10/20 qualify; a single one never does; 19% / 9% never do; a 20% of another attribute never does.
  - A 10% from a salvageable source does not count: *Swift* staff head, *of Swiftness* focus core, *Don't think twice* (HCT); *of Quickening* wand wrapping, *Serenity now*, *Let the memory live again* (HSR). These are matched by upgrade id in the group header (`IsEffectFromUpgrade`); an effect after the next `2408` header is not part of the earlier group.
- Requirement 9 for +5 energy only; requirement 9 or 10 for the pairs; nothing else is auto-kept.

### 24.4 Before / after (old-school weapons, nothing ticked unless stated)
| Weapon | v26 | v27 |
|---|---|---|
| q9 axe/bow/dagger/hammer/sword, inherent +5 energy, ordinary skin | sold/salvaged | **kept** |
| q8 or q10 +5 energy weapon | q8 kept, q10 sold | sold/salvaged |
| Staff q9 with +5 energy from an Insightful head | Insightful ticked under Keep (AMG Loot) → kept by the tick | same: kept only by the tick; unticked → never auto-kept |
| Wand/focus q9-q10, 20/20 HCT/HSR of its own attribute | kept | kept |
| Wand/focus q9-q10, 10/10, 20/10 or 10/20 | sold | **kept** |
| Wand/focus with a single 20% or a single 10% | sold (single) | sold |
| Wand/focus 20/20 of an attribute that is not its requirement attribute | kept | **sold** |
| Wand/focus 20/20 at q8 / q11 / q13 | kept | **sold** |
| Staff 20/20, 10/10, 20/10 (any req) | kept (rare skin) | **sold** |
| 15^50, +15% enchanted, +15% stance, inherent zealous/vampiric strength (any req, rare skin or not) | kept | **sold** |
| Shield q9, +30 health and armor vs species | kept | **sold** |
| Vampiric hilt (perfect) on an OS sword, ticked Keep + Extract (AMG Loot) | kept | kept (tick), held, extracted; after extraction the sword is sold |
| Zealous hilt ticked under Extract only | extracted, but the sword could be kept by the inherent-mod rules | extracted, then the sword is sold |
| Ultra-rare model (Eternal Bow, BDS, Voltaic…) | kept | kept (by model) |
| Equipped / customized / green / unidentified | kept | kept |
| White weapon | sold | sold |

"Sold" means salvaged or sold by your ticked Salvage / Sell rules (rarity / type / req), or stored by Store items first.

### 24.5 Verification
- New `tools/tests/test_oskeep.au3` (149 checks) on the REAL `ShouldKeepWeapon`, `IsOSAutoKeepWeapon`, `DefaultShouldSalvageItem` / `DefaultShouldSellItem`, `LoadExtractUpgradeDefinitions` / `FindCheckedUpgradeOnItem` / `IsHeldForExtraction` and the real loader with AMG Loot.json:
  - 57: dword encodings equal the bot's audited constants (`$STRUCT_MOD_HCT_10`, `$STRUCT_MOD_HSR_10`, Domination HCT/HSR, `$STRUCT_5_ENERGY`); requirement read like GWA2.
  - 58: wand and focus at q9 and q10: 20/20, 10/10, 20/10, 10/20 kept; **single 20% HCT, single 20% HSR, single 10% HCT, single 10% HSR not kept** (t40u); wrong attribute, 19/20 and 10/9 not kept; q8 / q11 / q13 not kept; staves (20/20, 10/10, 20/10) never; sword / shield never; salvageable 10% sources (of Quickening, of Swiftness, Don't think twice) do not count.
  - 59: +5 energy on axe/bow/dagger/hammer/sword at q9 kept, q8 / q10 not; Insightful head and header-less tooltip groups do not count; +4 not kept.
  - 60: every v26 inherent keep removed (15^50 rare skin, +15% enchanted / stance, zealous / vampiric strength, shield 2 perfect inherents, staff 20/20, wrong-attribute wand, q8 +5e); such an axe is sold and salvaged; a q9 +5e axe is neither.
  - 61: Vampiric (ticked) extracted, kept only through its tick, held until extracted, the bare sword is then not kept; Zealous unticked → not extracted / not kept; Zealous ticked for Extract only → extracted, weapon not kept.
  - 62: unchanged rules (ultra-rare model, equipped, customized, green, white, unidentified, inscribable q9 rare skin).
  - **With the v26 OS branch put back it fails 55 checks** (`tools/out/v27_oskeep_v26_os_branch.log`); with v27 it passes.
- Mutations: `tools/mutation/mutate_v27.py`, 23/23 caught (single HCT / single HSR enough, staves back, req 9 only / any req for pairs, +5e at q10, attribute match dropped for HCT and for HSR, 19% / 9% accepted, salvageable sources counted, Insightful counted, group boundary ignored, +4 energy, requirement byte swapped, v26 branch restored, OS auto-keep removed, ultra-rare dropped, OS rule before the ticked lists).
- Au3Check: 0 errors, 46 warnings (same set as v26).
- `run_tests.sh` now fails if a unit test prints no RESULT line (it silently "passed" when run without a display); run it under `xvfb-run`.

### 24.6 Notes
- The OS auto-keep does not look at the damage / energy / armor ("max stats") of the weapon - AMG asked for these to be kept "without any filters". Before v27 the max-stats check also applied to OS weapons.
- `HasPerfectMods` / `DefaultCreatePerfectModsByOSWeaponTypeMap` are left in the code (unused by the keep logic) so older custom scripts that call them still compile.
- No in-game dump of a 10% HCT/HSR focus is available; the encodings come from the bot's audited constants (Py4GW ids). TESTING P12 lists the checks.

## 25. v29: Inventory "Keep components" removed (AMG's request)

AMG asked to remove the *Keep components* tab/branch. He accepted that items with perfect mods are no longer kept whole: *Extract upgrades only* (with *Extract selected components before selling*) and *Store items > Components* handle the components, then the item is sold.

### 25.1 What read *Keep components* before v29
- `ShouldKeepWeapon` → `ContainsValuableUpgrades`: a weapon with a ticked (max-roll) mod / inscription was kept (never salvaged or sold).
- `DefaultShouldSalvageItem` / `DefaultShouldSellItem`, armor salvageables → `ContainsValuableUpgrades`: armor with a ticked rune / insignia was kept.
- `RefreshValuableListsFromCache` (on load and on *Apply changes*) built the `$valuable_*` lists from the ticks.
- `LoadExtractUpgradeDefinitions`: fallback to the *Keep components* ticks when a loot file had no *Extract upgrades only* branch.
- `MigrateStoreComponentOptions`: Store items > Components leaves seeded from *Keep components* (Extract only when Keep was absent).
- `PruneNonPerfectUpgradeOptions` (`$PERFECT_OPTION_ROOTS`): non-perfect options removed from both roots with one warning.
- Nothing else (farm scripts, pickup, identify, store rules) read it.

### 25.2 What v29 does
- **Tree / files:** the branch is removed from the 4 shipped loot files (line-wise removal, formatting and BOM kept, re-parsed: every other key identical). The GUI tree is built from the loaded cache, so it no longer shows the branch.
- **Old loot files:** `LoadLootConfiguration` removes a *Keep components* root before anything else, without a log line. It never reaches the cache, so it is not shown and *Save* never writes it back. The perfect-only cleaner now only looks at *Extract upgrades only* (the v10 file warns "Ignored 87 …" instead of 174).
- **Keep decisions:** `ShouldKeepWeapon` keeps only equipped, customized, green, unidentified, ultra-rare model, the v27 OS auto-keeps, and the inscribable rare-skin / low-req rules. Armor salvageables: identified ones follow the Salvage / Sell rules (white still sold as before).
- **Extraction / hold:** unchanged. `IsHeldForExtraction` still holds an item (weapon or armor) carrying a ticked perfect component while *Extract selected components before selling* is on, so the component is extracted first. No fallback: without the Extract branch nothing is extracted ("Nothing is checked under Extract upgrades only").
- **Store items > Components:** seeded from *Extract upgrades only* (same 447 leaves; existing ticks kept).
- **Removed code:** `ContainsValuableUpgrades`, `RefreshValuableListsFromCache`, `CreateValuableRunesAndInsigniasArray`, `CreateValuableModsByOSWeaponTypeMap`, `CreateValuableModsByWeaponTypeMap`, `CreateValuableInscriptionsByWeaponTypeMap`, `CreateValuableUpgradeRequirementsMap`, `KeepUpgradePresent`, `TrimCleanupAndEval`, `DefaultCreateValuable*` (4) and the `$valuable_*` globals. `ResolveUpgradeLeafDefinition` (the leaf → modstruct rules) stays: it serves Extract and Store items > Components.
- **Major Vigor exception:** still an Extract option (perfect-only allowlist) and a Store items > Components > Runes > All leaf; AMG ticks both.

### 25.3 Behaviour changes for AMG
| Item | v28 | v29 |
|---|---|---|
| Weapon / shield / focus with a ticked perfect mod or inscription, hold on | kept whole | held → component extracted → salvaged/sold by your rules |
| Same, hold off | kept whole | salvaged/sold with the component in it |
| Blue armor salvageable with a ticked rune / insignia | kept | extracted first (hold on), then sold |
| Purple / gold armor salvageable (AMG Loot) | stored (Store rule) | stored (Store rule, unchanged) |
| q9 OS +5 energy, wand/focus HCT+HSR pairs, ultra-rare, green, unidentified | kept | kept |
| Loose components ticked in Store items > Components | stored | stored |

AMG's 128 Keep ticks were all also ticked under Extract (130), so no ticked component loses its extraction.

### 25.4 Verification
- `tools/tests/test_keep.au3` rewritten (82 checks):
  - 63: the shipped files have no root and load warning-free.
  - 64: a v28 AMG Loot.json fixture with *Keep components* loads with no warning or error, no Keep key, and identical Extract / Store / Salvage / Sell ticks. The v10 file gives one warning (87). Odd shapes are covered (boolean root, non-perfect Keep leaf).
  - 65: weapons are not kept for mods, but are held / extracted. Unchanged keep rules still apply.
  - 66: armor with Superior Vigor is salvaged/sold with the hold off and held with it on; Minor Vigor is not held; unidentified armor is not salvaged.
  - 67: Major Vigor is extracted, held, stored loose, and never sold/salvaged loose.
  - 68: no fallback.
- Adapted: `test_slaying`, `test_oskeep`, `test_storecomp`, `test_perfect`, `test_loot_alignment`; the alignment checker treats a *Keep components* root as a legacy warning.
- **Found while adapting:** two v27 `test_oskeep` checks (a wand whose 10% HSR comes only from the salvageable *of Quickening* wrapping) expected "kept". They passed only because AMG's Keep components tick of *of Quickening* kept the wand; `IsOSAutoKeepWeapon` itself correctly said no. They now expect "not kept".
- Mutations of the removed code dropped from `mutate_v26.py` / `mutate_v27.py`.
- Au3Check: 0 errors, 43 warnings (v28: 46).
- GUI smoke: `tools/out/v29_inventory.png`.


## 26. v30: map load guard before acting after a map change; 2-minute stuck watchdog in towns and explorables (AMG's request)

AMG (pt50u): the bot may get stuck because it starts moving, talking to NPCs, using merchants or dialogs, or casting before the game has fully loaded after a travel or zone change. He also wants the stuck watchdog at **2 minutes, in towns and in explorable zones**.

### 26.1 Audit: map-change paths before v30
| Path | Wait used | Gap |
|---|---|---|
| `WaitMapLoading` (GWA2), behind 13 direct calls, 90 `RobustWaitMapLoading` calls, guild hall travel, `DistrictTravel` / `RandomDistrictTravel` | `GetMyID() <> 0`, `GetMaxAgents() <> 0`, map ID | These switch **before** the map is usable (the map ID can change while the loading screen is still up; agent ID ≠ 0 doesn't mean the agent struct or position exist). No instance type check. One good sample was enough. |
| `TravelToOutpost` (`RobustTravelToOutpost`, town pass, ~120 farm calls) | the above, then `GetMapID() == outpost` | Returned `$SUCCESS` at once when the map ID already matched, even mid-load. The load result was ignored. |
| `ResignAndReturnToOutpost` | the above (10 s) + map ID | With `$ignoreMapID` (explorable shares the outpost ID), the ID check passed while still in the explorable or loading. |
| 26 portal loops `While GetMapID() <> X … RobustWaitMapLoading(X) WEnd` | the above | When the wait timed out but the map ID had switched, the loop exited and the farm ran into a half-loaded map. |
| FoW / UW / Urgoz / Deep entries (Utils) | `WaitMapLoading(X)` + map ID | Same: result ignored. |
| Magma's `EnterChallenge()` | `Sleep(3000)` only | No wait at all before consumables, skills and flags. |
| Zodiac `EnterChallenge()` / return | `RobustWaitMapLoading()` loop | Covered by the central change. |
| Searched for other zone changes (Move/MoveTo followed by a map check with no wait): | none found | |

### 26.2 The guard
- `MapReadyReason` (pure, unit-tested) returns `''` when ready, else the first failing check:
  - loading screen;
  - unknown instance type;
  - no player agent ID;
  - agent array empty;
  - player agent not created;
  - wrong map;
  - wrong instance type;
  - position unreadable or NaN;
  - position not set (0,0);
  - party not populated.
- `WaitMapReady(map = -1, type = -1, timeout = 20000, settle = 2500)`:
  - ready = 3 consecutive passing samples, 250 ms apart. Values aren't all updated at once, and an agent can flicker during an instance swap.
  - then `PingSleep(settle + 250)`, the same settle formula as the old `WaitMapLoading`. `settle < 0` means no settle.
  - timeout → `False`, and `$map_ready_last_reason` says why.
- Grace: position and party are the only checks that use reads not proven by the old code. If all hard checks have passed for 4 s, they are waived with one debug line. A wrong offset then falls back to the pre-v30 behaviour plus the instance-type and agent-struct checks, never to a timeout on every travel.
- `IsMapReadyNow` = one sample, used for the "already there" shortcut so it costs nothing when the map is loaded.
- `ConfirmMapReady(map, name, timeout = 20000)` (Utils): immediate when ready, otherwise waits. On failure it logs `<map> did not finish loading (<reason>) - failing the run` and returns `False`.

### 26.3 Where it is wired
- `WaitMapLoading` → `WaitMapReady` (same signature and return). That covers every `WaitMapLoading` / `RobustWaitMapLoading` caller (13 + 90), the guild hall travel, `DistrictTravel` and `RandomDistrictTravel` (which now return the readiness).
- `TravelToOutpost`: already there → `IsMapReadyNow`, else `WaitMapReady` (20 s). After a travel, an outpost that never finishes loading → `$FAIL`.
- `ResignAndReturnToOutpost`: `WaitMapReady(outpost, $ID_OUTPOST, 20000, 1000)`.
- `ConfirmMapReady`: after all 26 portal loops (`If Not ConfirmMapReady($ID_X) Then Return $FAIL`) and after the 8 FoW / UW / Urgoz / Deep entry checks.
- Magma's: `MagmasWaitForMapType` uses `WaitMapReady(-1, type)`, and is now called after `EnterChallenge()`.
- On timeout, callers get `False` / `$FAIL`. The run fails and the next run retries. `RobustWaitMapLoading` keeps its retry and resign logic.

### 26.4 Watchdog
- Timeout: 2 min (`$STUCK_WATCHDOG_TIMEOUT_MS`).
- Coverage: `RunFarmLoop` starts it right after the connection check, before mid-run inventory, the town pass and global setup. Before v30 it only started around the farm function.
  - A trip during these phases maps back as before. The farm is then skipped for that run (`$FAIL`, setups reset, stats kept).
  - The inventory-full pause path stops the watchdog. If the watchdog tripped, the run returns `$FAIL` (retry), not a pause.
- New progress signal, the inventory signature (Adlib sample, not while loading). It covers:
  - character and storage gold;
  - item counts of bags 1..`$bags_count` and Xunlai tabs 8–21;
  - for the bags, the sums of item ID × (bag·100 + slot), quantity, value and identified bit.
  - Every salvage (kit value), extraction, identify, sale, purchase, store, sort or pick-up changes it. A loop retrying the same item with no effect does not.
- Exclusions: Follower, Monk Bonder, EleMonk UW Bonder, OmniFarm, Manual Mode, Tests and TestSuite. The Storage utility is now watched, since it is a town pass.
- Loading still holds the clock. A `$ID_LOADING` sample (or agent ID 0) is progress and re-anchors.
- **False-trip review at 2 min.** Things that legitimately sit still with no XP, no new log line and no inventory change:
  - Spirit Slaves ball / ally waits (capped at 120 s): now 100 s.
  - Corsairs' Bohseda wait (120 s, fights so usually XP): now 100 s.
  - Glint's stray-foe sweep trigger (150 s): now 100 s, so the farm's own fix runs before the watchdog.
  - Gemstone zoning loops (120 s) walk, so the movement signal applies.
  - WarSupplyKeiran's 120 s exit-countdown loop is itself a stuck guard. Tripping there also ends a run that would fail anyway.
  - Empty Tab is a Tools button outside runs, so it is never watched.
  - Remaining risk: any farm step that waits more than 2 min fully idle (no movement ≥ 300, no kill, no new log text, no item or gold change). None found besides the ones above.

### 26.5 Verification
- `tools/tests/test_mapready.au3` (new, 80 checks): the real GWA2 and Utils functions against a simulated game whose load stages complete at set times. A mutation with 1 stable sample instead of 3 is caught (3 failures).
- `tools/tests/test_watchdog.au3`: 115 checks, re-timed for 2 min. It adds the inventory signature, long town passes, trips in town and no reads while loading.
- `tools/v30_static.py` + its self-test in `run_tests.sh`.
- Au3Check: 0 errors, 43 warnings (unchanged).

## 27. v31: Items panel Session column; dark GUI theme (AMG's request)

AMG (pt51u): "on the main tab for the items (inventory + storage) can we add a column before the total that tracks only the current session?" He also asked for the GUI colours inverted to white text, and then for other accent colours beyond white.

### 27.1 Session column semantics
- Columns: `Item | Session | Total` (`$ITEMS_PANEL_COL_SESSION = 1`, `$ITEMS_PANEL_COL_TOTAL = 2`). Widths: Item 152, Session 52, Total 56 (+17 scrollbar) inside the unchanged 281 px panel. The Item column uses `LVS_EX_LABELTIP`.
- `Session = total(inventory + storage) - baseline[model]`, per model ID. `ItemsPanelSessionDelta` returns `Null` with no baseline, and the cell is blank.
- Baseline (`ItemsPanelSessionObserve`): taken on the first refresh where `$complete` is true **and** a character name is known. `$complete = storage read live this refresh And bags 1, 6, 8 readable (ItemsPanelReadIsComplete) And IsMapReadyNow(-1, $ID_OUTPOST)`. It is stored for every panel model (0 included), so an item first seen later counts from 0.
- Character change → `ItemsPanelSessionReset` → the next complete read rebaselines. Same character → the baseline never moves (a later refresh never overwrites it).
- Inventory ↔ storage moves don't change the sum, so they net to zero. The cached-storage marker `*` is appended as on Total.
- Elite Tomes `Total`: sum of the per-profession deltas. Titles: the gain is the session value (`'+N'`), and title rows start at `0`.
- Why not baseline earlier: in an explorable, or during a load, storage isn't readable, and a baseline without it would show the whole storage as session gain on the next outpost visit.

### 27.2 Dark theme design
- `lib/BotsHub-Theme-Colors.au3` (no dependencies) holds every colour as `$THEME_*` (0xRRGGBB) plus `ThemeBGR()` for COLORREF users (RichEdit, ListView custom draw). Utils-Console, Utils-ItemsPanel and the theme module include it.
- `ThemeApplyDark($gui, $tab, $tabItems)` runs at the end of `CreateBotsHubGUI`. It walks control IDs 1..last and themes by window class/style:
  - `Static`: light text (right-aligned value labels in light blue). Background = page colour if the control's top-left is on a tab page, else the window bar colour. Pictures and icons are skipped, and the tab-page background labels keep the page colour.
  - `Button`: group/checkbox/radio get `SetWindowTheme(h, '', '')` first. Themed (visual styles) drawing ignores `WM_CTLCOLOR*`, which is why checkboxes showed black text on dark. Then colours are set. Push buttons are dark unless registered with `ThemeSetButton` (accent and state colours).
  - Group titles: classic group boxes under Wine draw the caption black whatever the colour. The caption moves to a gold label created inside the group's tab item (`GUISwitch($gui, $tabItem)`), so it shows and hides with its page. The group keeps an empty caption and its frame.
  - `Edit`, `ComboBox`, `SysListView32`, `SysTreeView32`, `msctls_progress32`: dark input background with light text. The tree gets dim lines, and the ListView header gets `DarkMode_ItemsView` (honoured from Windows 10 1809).
  - Tab control: visual styles off and the window procedure subclassed (`DllCallbackRegister` + `GWL_WNDPROC`). `WM_PAINT` paints the strip, page and frame dark, and the tab captions (selected = page colour + gold). `WM_ERASEBKGND` is swallowed. Other messages go to the original procedure, so tab switching is unchanged.
- Loot tree: `ThemeColorTreeBranches` at the end of every `BuildTreeViewFromCache` (load, apply, config change). Items with children are gold, leaves are light.
- Items panel custom draw: category rows gold on a dark gold tint; item rows `CDRF_NOTIFYSUBITEMDRAW` → per-cell colour from the pure `ItemsPanelCellColor(column, text)`.
- Console: RichEdit background `$THEME_CONSOLE_BG`. `Out()` level colours come from `$THEME_LOG_*`.

### 27.3 What can't be fully darkened
- ListView column header (Item / Session / Total): light on Wine and on Windows older than 10 1809. Custom-drawing the header would need subclassing the ListView (its header notifications go to the ListView, not the GUI). Left as is.
- Scrollbars and combo drop-down arrows: system look.
- Progress bar under Wine: Wine ignores `PBM_SETBKCOLOR` / `PBM_SETBARCOLOR` (verified with a standalone script). On Windows with visual styles off it is dark.
- Push-button edges: AutoIt draws coloured buttons itself, and a thin system edge can remain.

### 27.4 Verification
- `tools/tests/test_items_panel.au3`: 145 checks. The session block (section 12) covers: map not ready means no baseline; store and Empty Tab moves net 0; gains, losses and sales; the baseline is stable; the alt-character rebaseline. Pure `ItemsPanelFormatDelta` / `ItemsPanelSessionDelta` / `ItemsPanelCellColor` checks, plus the custom-draw stages.
- `tools/v31_static.py` plus its self-test (`run_tests.sh`).
- GUI smoke under Wine/Xvfb: `tools/gui/gui_shots.sh <prefix>` captures all 7 tabs (tab switching via `ControlCommand TabRight`, `tools/gui/tabright.au3`). `tools/gui/items_panel_shot.sh` renders the real panel and theme with **simulated** bags (two refreshes: baseline, then gains, a loss and a move), labelled "SIMULATED DATA".
- Au3Check: 0 errors, 43 warnings (unchanged).

## 28. v32: clipped Informations labels (AMG's request)

AMG (pt54u): "I think some text in information got cut off".

### 28.1 Cause
- The real GUI font under Wine measures "Time per run:" at 70 px and "Obsidian Shards:" at 88 px. v10 gave them 65 px and 85 px labels, 16 px high. Static controls word-wrap, so the second word line ("run:", "Shards:") fell below the visible 16 px.
- v10 also had "Success Ratio:" (85 px) running under its value cell, the Time value cell at 70 px (needs 73 for "99h 59min 59s"), Time per run at 50 px (needs 51 for "59min 59s") and Gold at 50 px (needs 55 for "9999k999g").
- Not a regression. v23 kept the block byte-identical (a static check enforced it), and the v31 theme only changed colours. The same clipping shows in `v31_before_main.png` (v30) and in v10 (`gui/clip_scan.sh original`).

### 28.2 Fix
| Row cell | v10 | v32 |
|---|---|---|
| left labels (Runs … Time per run) | x 31, 65 px (Success Ratio 85) | x 31, 78 px |
| left values | x 110, 50 px | x 109, 53 px |
| Time label / value | 45 px / x 90, 70 px | 50 px / x 81, 81 px |
| right labels (Experience … Obsidian Shards) | x 180, 65 px (Obsidian 85) | x 170, 90 px |
| right values | x 260, 50 px | x 260, 58 px |
- Group box (21, 39, 300×145), rows (y 64…164), texts, order and variables are unchanged. The console below is untouched, because the rows already fit vertically (13 px text in 16 px cells, last row ends at 180 < 184).
- The static v23 check moved from "byte-identical block" to "same controls, texts and order as v10".

### 28.3 Other tabs (scan of all 115 text controls)
- `tools/gui/clip_scan.au3` measures each label, checkbox, radio and button caption in AutoIt's default GUI font (the only font BotsHub uses). It word-wraps the caption greedily and reports it when the wrapped lines exceed what the control's height shows (or a word is wider than the control).
- Found and fixed (all pre-existing in v10):
  - Options: "Identification kits:" 95 → 106 px (x 148);
  - Options: the three faction radios had auto-width that Wine's font overflowed, now 265 px;
  - Team: "Team member build" 100 → 120 px;
  - Inventory: "Expand all" / "Reduce all" 55 → 63 px buttons (column moved to x 14, the hint label shortened to 56 px so it no longer runs under Apply).
- Result: 0 clipped. v10 has 11; v32 removed none of v10's content. The v10 Titles labels "Ministerial Commendations:" and "Lightbringer:" were clipped too, and have lived in the Items panel since v23.
- Theme-related: none. The v31 group-title labels are sized with `ThemeTextSize` (+4 px).

### 28.4 Verification
- `tools/tests/test_info_fit.au3`, generated by `tools/gen_info_fit.py` from `BotsHub-GUI.au3` at every `run_tests.sh`: 85 checks under Wine (label widths, worst-case values, overlaps, group bounds, 12 rows).
- `tools/gui/clip_scan.sh [improved|original]` (manual GUI smoke): `SCAN n=115 clipped=0`.

## 29. v33: Titles tab; TITLES out of the Items panel (AMG's request, approved mockups)

**Design.** AMG approved `tools/out/v33_titles_mockup.png` and `v33_items_panel_mockup.png` before any code. Later steering placed the tab before *Farm infos*. Nothing in the code depends on the tab index except `GuiTabHandler`, which only looks at index 0 (Main), so inserting the tab is safe. The tab is built from labels, with progress bars as two side-by-side labels because Wine ignores progress-bar colours. Right-aligned values get a trailing space because Wine's right-aligned statics clip the last glyph of texts with several commas. All colours come from `BotsHub-Theme-Colors.au3` and are applied after `ThemeApplyDark`.

**Verified values (wiki.guildwars.com, fetched 2026-11-11).**
| Title | Max | Source | GWA2 getter / GWCA TitleID |
|---|---|---|---|
| Asura, Deldrimor, Norn, Ebon Vanguard | 160,000 (rank 10) | `/wiki/Asura_rank`, `Deldrimor_rank`, `Norn_rank`, `Ebon_Vanguard_rank` | 38, 39, 41, 40 |
| Kurzick, Luxon | 10,000,000 (rank 12) | `/wiki/Allegiance_rank` | 5, 6 |
| Lightbringer | 50,000 (rank 8) | `/wiki/Lightbringer_rank` | 20 |
| Sunspear | 50,000 (rank 10) | `/wiki/Sunspear_rank` | 17 |
| Zaishen | 100,000 (rank 12), 5 points per key | `/wiki/Zaishen_rank` | 44 |
| Sweet Tooth, Drunkard, Party Animal | 10,000 (tier 2) | `/wiki/Sweet_Tooth`, `Drunkard`, `Party_Animal` | 34, 7, 43 |

Item points: `/wiki/Sweet`, `/wiki/Alcohol`, `/wiki/Festive_item`, `/wiki/Tonic`. Areas: Sweet "Consumption Area" column; Alcohol any PvE area; festive items towns/outposts/guild halls, never PvP outposts (`/wiki/Festive_item`, `/wiki/Tonic`); Crate of Fireworks guild hall only (`/wiki/Crate_of_Fireworks`); Tonic Tipsiness 5 s (`/wiki/Tonic_Tipsiness`). The tables are in `TitlesLoadItemTables`. Every GWA2 model ID matches the Py4GW / GWCA name.

**Corrections vs the investigation report.**
1. Crate of Fireworks: guild hall only, not any outpost. The button skips it elsewhere.
2. The festive table has 32 items, not 33.
3. War Supplies are excluded from *Eat all sweets* (AMG's decision), so they are not counted in "points available".
4. Alcohol at drunk level 5: whether points still count is unclear on the wiki, so the loop stops as soon as a drink gives no points.

**Consume loop.** `TitlesConsumeRun` finds the next table item in bags 1-5 that awards points here, reads the title, calls `UseItem`, waits (tonics 5.2 s, other items 0.9 s), then polls the title for up to 2.5 s.
- Gain: logged.
- No gain: alcohol stops; anything else is given up for the pass.
- Map ID / type change, loading or not-in-game: stop.
- Guard: 2000 iterations.
GUI entry `GuiTitlesButtonHandler`: `IsAttachedForTools` (refused while a farm runs), then `ItemsPanelRefresh(True)`.
