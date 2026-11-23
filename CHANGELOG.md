# Changelog: BotsHub 2.0 v10-improved

This builds on v10 (see `CHANGELOG-FIXES.md` for v3–v10). Issue IDs (C = critical, H = high, M = medium, L = low) refer to `ANALYSIS.md` §3.

Each entry gives:
- **What** changed;
- **Why** it changed;
- **Benefit**;
- **Verified** by.

Verification keys:
- `AC`: Au3Check clean (0 errors, no new warning kind).
- `UT`: unit tests in `tools/tests` (63 total).
- `DF`: differential test against the original loader.
- `SM`: GUI or headless smoke run under Wine.
- `RV`: line-by-line diff review.

No memory offsets, scan patterns, packet headers, assembly or farm routes were changed. Skill rotations were unchanged up to v17; v18 changes the Shadow Form / Deadly Paradox / Shroud / IAU upkeep at AMG's request (see the v18 entry).

---

## Batch 1: core loops and crash fixes

- **FanFlagHeroes default order** (C1)
  - What: a default flag order for 1, 2, 4 or 6 heroes, and a division-by-zero guard.
  - Why: an empty array was indexed, which crashed the script.
  - Benefit: no crash with incomplete teams.
  - Verified: AC, RV.
- **MoveTo overall timeout** (C6)
  - What: max(45 s, 3× the walk time).
  - Why: it could circle or rubber-band forever.
  - Benefit: the bot can't freeze in movement.
  - Verified: AC, RV.
- **AggroAgent bounds** (C7)
  - What: returns on agent ID 0, a dead foe, or 20 s.
  - Why: it waited forever on a dead or despawned foe.
  - Verified: AC, RV.
- **GoNearestNPCToCoords bounds** (C8)
  - What: 10 s for the NPC to appear, 30 s to reach it; returns True/False.
  - Verified: AC, RV.
- **GoToAgent** (M1)
  - What: initialises `$me` before the first distance check; adds a 30 s timeout.
  - Verified: AC, RV.
- **Per-target kill timeout in UseSkillSequentially** (C9)
  - What: 60 s per target, then re-target. It can be set with the `targetTimeout` option, which is checked for a positive number.
  - Benefit: the fight always ends against invulnerable or unreachable targets.
  - Verified: AC, RV.
- **MoveAggroAndKill returns `$FAIL` on a wipe** (C16, M13)
  - Why: a wipe was reported as success, so stats were wrong and the next step ran on a dead party.
  - Verified: AC, RV.
- **HasRezMemberAlive cache refresh** (H1)
  - What: recomputed when the map or hero IDs change.
  - Why: a stale party from the first farm made wipe detection wrong.
  - Verified: AC, RV.
- **FindHeroesWithRez** (H2)
  - What: one entry per hero.
  - Why: duplicate entries and an array overflow.
  - Verified: AC, RV.
- **CollectHeroesEffects** (M4)
  - What: the hero count is no longer `Static`.
  - Verified: AC, RV.
- **KillFoesInArea** (M3)
  - What: 250 ms sleep while the player is dead.
  - Why: 100% CPU spin.
  - Verified: AC, RV.
- **DistrictTravel** (M2)
  - What: unknown district → one warning + Random EU.
  - Why: a subscript crash on hand-edited configs.
  - Verified: AC, UT.
- **ManageFactionPointsFarm** (C12)
  - What: stops after 3 donations that don't change the balance.
  - Why: an endless loop when the guild isn't allied with that faction.
  - Verified: AC, RV.
- **Same-map-ID loads** (C13)
  - What: the new `WaitForNewInstance()` used by `RobustWaitMapLoading(-1)`.
  - Why: the old instance looked loaded, so the bot moved during the loading screen.
  - Verified: UT (old instance rejected, new accepted, bounded).
- **Passage scrolls** (C15)
  - What: EnterFissureOfWoe and EnterUnderworld return `$PAUSE` when no scroll is found.
  - Why: the bot farmed inside the outpost.
  - Verified: AC, RV.
- **RobustTravelToOutpost** (L4)
  - What: removed a redundant second load wait (~2.5 s per travel); one retry.
  - Verified: AC, RV.
- **OpenPickWindow** (L3)
  - What: `Sleep(20)` in the event loop.
  - Verified: AC.
- **New `lib/BotsHub-Constants.au3`**
  - What: all timeouts and limits are named constants, each with a comment.
  - Why: they used to be magic numbers spread around the code.
  - Benefit: tuning in one place.
  - Verified: AC.

## Batch 2+3: logging, config, session, GUI

- **Leveled file logging** (H11)
  - What:
    - `logs/botshub-<date>[-<character>].log`, with timestamp and level.
    - stdout fallback when there is no console.
    - warning and error counters.
    - Debug level switchable with `run.debug_logging`.
  - Why: headless slaves logged nothing, and the GUI log was lost on exit.
  - Benefit: post-mortem debugging and logs users can send.
  - Verified: SM (file written, levels correct).
- **Console trimming** (M10)
  - What: past 400k characters, the oldest 100k are dropped (with a notice pointing to the log file).
  - Why: the rich-edit control slowed down over long sessions.
  - Verified: AC, RV.
- **`MapExists()` instead of `$map.Exists()`** (M12)
  - What: 6 call sites.
  - Why: the method syntax is undocumented and fragile.
  - Verified: AC, UT.
- **Config loader rewrite** (H3, H4, H5, L1, L2)
  - What:
    - `ConfigGet` (a missing key keeps its default).
    - One `PERSISTED_OPTION_KEYS` list for load and save (19 options that were not saved before).
    - Value clamps (weapon slot 0–4, bags 1–5).
    - File and JSON error handling.
    - `bonder_mode` default `'None'`.
  - Benefit: old, partial or broken configs can't silently wreck the settings; every option survives a restart.
  - Verified: UT (40 tests: partial, invalid, round-trip of value and type, all shipped configs), DF (only the 2 intended differences).
- **Config validation**
  - What: warnings for an unknown farm, district or loot config, empty hero names or builds, and conflicting faction options.
  - Verified: UT (problem counts).
- **Save adds `.json`** (M9)
  - Verified: UT.
- **ApplyConfigToGUI covers all options** (M7)
  - What: covers the newer checkboxes and the Follower controls. The follower name input now has an event handler (M8).
  - Verified: AC, RV.
- **Session statistics (new `lib/Utils-Session.au3`)**
  - What:
    - per-run CSV;
    - a `Session:` line after each run;
    - a summary on exit (runs, success rate, average and longest run, gold change, warnings/errors);
    - Pause isn't counted as a run.
  - Verified: UT (counters, CSV quoting, duration format), SM (summary on exit).
- **Consecutive-failure watchdog** (H10)
  - What: pauses after 10 failed runs in a row.
  - Verified: UT.
- **WM_COMMAND auto-attach removed** (H6)
  - Why: it injected repeatedly and showed MsgBoxes inside the message handler. The OnEvent selection handler keeps the auto-attach feature.
  - Verified: AC, RV.
- **Tools refused during a run** (H7)
  - Why: two scripts drove the character at once.
  - Verified: AC, RV.
- **No double attach** (H8)
  - What: Start and Attach skip the scan and injection when already attached to the same character.
  - Verified: AC, RV.
- **Return on death now works** (M5)
  - What: the first wipe fails the run.
  - Verified: AC, RV.
- **Log chest spawns now works** (M6)
  - Verified: AC, RV.
- **Dead code removed** (L5)
  - Verified: AC.

## Batch 4: bounded farm loops and failure propagation

- **Map entries** (C2, C4, C5)
  - What:
    - 41 entry, portal and door loops bounded with `MapEntryAttemptAllowed` (5 attempts): 24 GoTo/LeaveTo/Enter functions, 14 Froggy/SoO/Tunnels/Voltaic dungeon waits and 3 same-map missions.
    - The functions return `$FAIL`, and 41 call sites now `Return $FAIL`.
    - Tasca and Pongmei unregister their adlibs first.
  - Benefit: no endless loop when a zone can't be reached; the hub's normal retry and watchdog take over.
  - Verified: AC, au3lint (unbounded-loop detector reports 0 for these patterns), UT (exact attempt counts), RV (every hit).
- **Setup loops** (C3)
  - What: Froggy, SoO, SpiritSlaves and Vaettirs are bounded with `SetupAttemptAllowed` (3); the farm returns `$PAUSE`.
  - Verified: AC, UT, RV.
- **Skill loops** (C10)
  - What: 23 spam and recharge-wait loops (including the adlib `UseDeadlyParadox`) get a timer guard (10 s cast, 90 s wait) and `ExitLoop`, so the following code is unchanged.
  - Verified: AC, RV, UT (`CastUntilRecharging` stop/time-out/dead).
- **Hex re-target loops** (C11)
  - What: Raptors and DrakeFlesh, at most 10 re-targets.
  - Verified: AC, RV.
- **Hard run deadline**
  - What: `IsRunFailed()` fails the run after max(4× the expected duration, 30 min).
  - Why: a backstop for the long `While Not IsRunFailed()` loops.
  - Verified: AC, RV.
- **Waits in Corsairs and DrakeFlesh** (H15)
  - What: `WaitForEnemyInRange` 60 s, `WaitForBohseda` 120 s, adrenaline wait 30 s.
  - Verified: AC, RV.
- **Follower headless**
  - What: uses the saved leader name when no GUI exists (M8).
  - Verified: AC, RV.

## Batch 5: recovery and economy

- **Reconnect** (H12)
  - What:
    - `Disconnected()` rewritten: it finds the window by handle or PID, refuses to send keys without one, sends Enter up to 3 times with a wait between tries, and returns True/False.
    - `EnsureGameConnected()` runs before every run. It confirms a disconnect over 30 s: a stuck loading screen, missing agent, or frozen instance clock, where the clock only counts after it was seen advancing. It then reconnects and resets the farm setups, or pauses the hub.
  - Why: there was no reconnect at all, and the old function could loop forever.
  - Benefit: unattended sessions survive network drops.
  - Verified: UT (23 recovery tests, including no false alarm when the clock was never verified). The real dialog still needs a live test.
- **Rare material buying** (H9)
  - What: re-checks the quote and the gold before every purchase; logs the count bought.
  - Why: rising prices made it overspend.
  - Verified: AC, RV.
- **Morale boosters** (M11)
  - What: 500 ms + ping wait, at most 10 per call.
  - Verified: AC, RV.
- **HRCombat per-target timeout** (C9)
  - Verified: AC, RV.

## Final passes

- **Headless dialogs time out** (H13)
  - What: they close after 30 s; the error is also logged; exit code 1. Headless attach failure exits too (C14).
  - Verified: SM (wrong PID and unknown farm both exit 1 in about 35 s).
- **Random 1–3 s gap between runs**
  - Why: run starts were perfectly periodic.
  - Verified: AC, RV.
- **Start-up diagnostics line**
  - What: version, AutoIt, OS, admin rights, folder; warns when not admin.
  - Verified: SM.
- **Heartbeat log lines moved to Debug** (M14)
  - Verified: AC.
- **Slave GUI created only once** (H14)
  - Verified: AC, RV.
- **`targetTimeout` option checked** (must be a positive number)
  - Why: AutoIt quirk, `'' <> Null` is True, so an empty value would have meant a 0 s timeout.
  - Verified: AC, RV.

Totals:
- 49 files changed, about +1115 / −272 lines of code.
- Docs: this file, `ANALYSIS.md`, and the README section.

---

## Item & mod audit (follow-up)

AMG reported that an Expert/Superior salvage kit never pulled a **Wrapping of Enchanting (20%)** off a staff or a **Pommel of Fortitude (+30 Health)** off a sword with *Extract upgrades only*. Root cause, the full ID table audit and the unverified list are in `ANALYSIS.md` §7. New verification key: `MT` = `tools/tests/test_mods.au3` (77 checks).

- **Salvage slot index is fixed by kind** (root cause, critical)
  - What: `SalvageMod()` now always gets prefix/insignia 0, suffix/rune 1, inscription 2 (`lib/Utils-Storage.au3`, `$EXTRACT_COMPONENT_INDEX_MODE` and `ComputeSalvageComponentIndex`). The 'compact' mode was removed.
  - Why: the default 'compact' mode counted only the upgrades present. A staff with just a wrapping, or a sword with just a pommel, got index 0, which is the empty prefix slot. Nothing was salvaged, the 3 s wait timed out, and the session was cancelled. Inscriptions on items with fewer than two mods, and runes on armor without an insignia, were hit the same way.
  - Sources: GWCA `SalvageSessionInfo` (salvagable_1/2/3 = Prefix/Suffix/Inscription); Py4GW MerchantRules, which salvages by slot name; upstream BotsHub `SalvageItem()` (0/1/2).
  - Verified: MT, AC.
- **Prefix and suffix with the same effect are told apart**
  - What: weapon matching reads the upgrade id from the 0x2408 dword that heads each upgrade group, and rejects a group of the wrong kind. This uses a 220-entry upgrade-id table generated from Py4GW.
  - Why: a Hale staff head and a Wrapping of Fortitude both carry `001E4823`. Defensive and Of Defense both carry `05000821`. A checked suffix could match a head, and the bot would then salvage the wrong slot.
  - Verified: MT.
- **Multi-effect mods are matched whatever the effect order**
  - What: for groups with a known upgrade id, all up to 3 effect dwords are checked (Zealous, Vampiric, Sundering, To the Pain, Seize the Day…).
  - Why: the old check worked only if the bot's dword came directly after the tooltip dword.
  - Legacy behaviour is kept: a struct directly after a marker, with no group header, still matches.
  - Verified: MT.
- **Extract log shows the upgrades on the item**
  - What: e.g. `suffix OfEnchanting_Staff (0x00E1)`, plus the slot used.
  - Verified: MT.
- **Kit uses**
  - What: `CountRemainingKitUses` uses the same value-per-use divisors as `FindKit` (new `KitValuePerUse`).
  - Why: it divided by 2 for every kit, which over-counted superior identification kits by 25%, so too few were bought.
  - Verified: MT.
- **Kit model IDs**
  - What: unchanged, confirmed correct: 2991 expert, 5900 superior, 2992 basic salvage, 2989 / 5899 identification (GWCA `ItemIDs.h`).
- **HCT/HSR labels swapped for 5 attributes** (data)
  - What: `$STRUCT_INHERENT_{ILLUSION_MAGIC, INSPIRATION_MAGIC, BLOOD_MAGIC, SOUL_REAPING, CURSES}_{HCT,HSR}` held each other's values. They are now correct.
  - Source: Py4GW HalvesCastingTimeAttribute 0x221 vs HalvesSkillRechargeAttribute 0x239. The other 16 attributes already used that scheme.
  - Behaviour: no change, because both constants are always used together.
- **`$ID_LUNAR_TOKENS` = 28433 was the Pumpkin Cookie** (data)
  - What: it is now an alias of `$ID_LUNAR_TOKEN` (21833), and removed from the festival-drop list.
  - Sources: GWCA `LunarToken` 21833; Py4GW `Pumpkin_Cookie` 28433.
  - Behaviour: none in practice, because cookies are matched as DP-removal sweets first.
- **Comments corrected**
  - `SalvageMod()` index comment (`lib/GWA2.au3`).
  - The `Only the strong survive` "incorrect" note: the value `00085828` is right (arg 8 = Weakness).
  - `Show me the money` is flagged as unverified.
- **Per-entry audit comments**
  - What: every `STRUCT_*` constant (383 entries) carries `[v11 audit: …]`: the decoded modifier and its args. Mods and inscriptions also get the Py4GW upgrade, its kind, the item types and the value range. Runes show attribute and tier, insignias their upgrade id.
  - Generated by `tools/itemaudit/annotate.py`.
- **Not changed**
  - Memory offsets, packet headers (salvage 0x77–0x7B match Py4GW `Packet_enums`), farm code and loot-tree names.

## Perfect-only extraction (v12 follow-up)

AMG: only perfect values should be extractable. Details, the full kept list and the unconfirmed items: `ANALYSIS.md` §8. New verification key: `PT` = `tools/tests/test_perfect.au3` (2003 checks) + `tools/itemaudit/perfect_verify.py`.

- **Non-perfect extract options removed**
  - What: 88 Minor/Major rune options were removed from *Extract upgrades only* in the 3 shipped loot configs. 446 remain: Superior and single-tier runes, all 45 insignias, and 351 weapon mods/inscriptions that were already at their max roll.
  - Why: only the max tier/roll should be extractable.
  - Verified: PT, `perfect_verify.py` (351/351 constants equal the Py4GW max).
- **Lower rolls can no longer slip through**
  - What: 11 slaying suffixes, To the Pain, Brawn over Brains, Ignorance is Bliss and Life is Pain (59 leaves) now also require their rolled effect at max on the same upgrade group (+20% vs species, +15% damage, +5 armor). Before, their constant pinned only the fixed part, so any roll matched.
  - Where: `GetPerfectRollRequirements`, `UpgradeGroupMeetsRequirements`, and the optional `$requirements` in `FindUpgradeGroupForStruct` / `HasUpgradeStructInModStruct` (`lib/Utils-Items_Modstructs.au3`); `UpgradeDefinitionPresentOnItem` (`lib/Utils-Storage.au3`).
  - Verified: PT (the mutation check fails 180 checks without it).
- **Saved configs load cleanly**
  - What: non-perfect leaves under *Extract upgrades only* are dropped at load time with one warning listing the checked ones (`PruneNonPerfectExtractOptions`, called from `LoadLootConfiguration`). Other settings are untouched and the file is not rewritten. The *Keep components* fallback also extracts perfect options only.
  - Verified: PT (a v10 config goes from 534 to 446, other roots identical).
- **Not changed**
  - *Keep components* (keep-from-salvage/sell), so default-checked Minor runes are still kept.
  - Offsets, packet headers, the salvage flow and the GUI layout.

## Perfect-only Keep components (v13 follow-up)

AMG approved making *Keep components* perfect-only too. Details: `ANALYSIS.md` §9. New verification key: `KT` = `tools/tests/test_keep.au3` (1284 checks).

- **Non-perfect keep options removed**
  - What: 88 Minor/Major rune options were removed from *Keep components* in the 3 shipped loot configs, leaving 446 (the same list as Extract).
    - Previously default-checked: 16 in Default Loot Configuration and in Loot, e.g. Minor Vigor, Major Vigor, Minor Fast Casting and Major Fast Casting; 1 in Sin Tasca's ChestRun (Major Vigor).
    - The built-in default rune list drops 13 Minor/Major entries.
  - Verified: KT.
- **Keep matching requires the max roll**
  - What: `ContainsValuableUpgrades` now matches weapon mods and inscriptions with `FindUpgradeGroupForStruct` and the same perfect-roll requirements as extraction (`KeepUpgradePresent`, `CreateValuableUpgradeRequirementsMap`, `ModStructToHex`).
    - Lower slaying, To the Pain, Brawn over Brains, Ignorance is Bliss and Life is Pain rolls are no longer kept.
    - Effect order no longer matters.
  - Where: `lib/Utils-Items_Modstructs.au3`.
  - Verified: KT (the mutation check fails 183 checks without it).
- **Old configs load cleanly**
  - What: `PruneNonPerfectUpgradeOptions` (called from `LoadLootConfiguration` in `BotsHub.au3`) prunes both roots with **one** `[Loot] Ignored N ...` warning; a v10 config gives N = 176.
  - Verified: KT, PT.
- **Side effects**
  - Identified armor whose only valuable upgrade is a Minor/Major rune is now salvaged under the default settings, which destroys the rune. It is sold only if the sell options are on (off by default).
  - Weapons with lower rolls are no longer kept by this rule.
- **Not changed**
  - The hardcoded OS-weapon list, offsets, packet headers, the salvage flow and the GUI layout.

## Tools tab: Open Storage (v14)

- **New *Open Storage* button** (Tools → Other tools)
  - What: opens the Xunlai storage window with the existing GWA2 `OpenXunlaiWindow()` (kShowXunlaiChest UI message). No new packet and no NPC walk.
  - Guards (`OpenStorageForTools` / `GetOpenStorageBlockReason` in `BotsHub.au3`):
    - refused while a farm runs and when not attached (`IsAttachedForTools`);
    - refused if the client process is gone;
    - refused while loading or disconnected;
    - refused outside an outpost/town, with a `[Storage]` warning and nothing sent.
  - Verified: `tools/tests/test_storage.au3` (26 checks), static wiring check in `run_tests.sh`, GUI under Xvfb (`tools_tab.png`).
- **Recommendations:** a prioritized list of further improvements is in `ANALYSIS.md` §11 (not implemented).
- **Not changed:** the Options-tab Open Storage button (upstream behaviour), offsets and packet headers.

## v15: guarded Options Open Storage, real Reset session stats, TESTING.md

- **Options tab *Open Storage***
  - What: now goes through `OpenStorageForTools()`, with the same checks as the Tools button (attach, farm not running, client alive, outpost/town only). The tooltip was updated. The button is kept.
  - Verified: static wiring check (both buttons), GUI under Xvfb.
- ***Reset session stats* resets the statistics, not just 4 labels**
  - What gets zeroed:
    - every Main-tab counter (runs, results, timings, chests, experience, titles, gold and items), via `$stats_reset_generation`, with fresh baselines at the next run;
    - the session counters behind the `Session:` line and the exit summary (`SessionResetStats`);
    - the consecutive-failure watchdog and the Q8 count.
  - It logs the old summary first. It is refused while a farm runs.
  - Not reset: the log file and its warning/error counts, the runs CSV, configs, attach state and per-run state. Full table: `ANALYSIS.md` §12.2.
  - Where: `lib/BotsHub-GUI.au3` (`ResetSessionStats`, `ResetStatsLabels`, `UpdateStats`, `UpdateItemStats`) and `lib/Utils-Session.au3` (`SessionResetStats`).
  - Verified: `tools/tests/test_reset.au3` (71 checks; the mutation check fails 24 without the fix).
- **`PrintItemInformationsAt(bag, slot)`**
  - What: a read-only Manual-field helper to report ModelID and ModStruct from the game.
  - Verified: `test_storage` (38 checks in total).
- **`TESTING.md`:** prioritized in-game checklist with the expected log lines and what to send back.

## v16: loot config for AMG, JSON <-> code <-> GUI <-> scripts alignment

- **`conf/loot/AMG Loot.json`** (new)
  - What: AMG's loot config, added under its own name. It is his edit of the v10 *Sin Tasca's ChestRun* config. Every true/false value he chose is kept as he set it.
  - Normalized: the 176 non-perfect Keep/Extract leaves that the bot drops at load time anyway were removed from the file. Two of them were ticked (Major Vigor in Keep and in Extract). The untouched original is kept outside the bot folder (`user_attached.original.json`).
  - Verified: `test_loot_alignment` (the real loader gives the identical cache for the original and the shipped copy, and the copy loads without a warning); GUI under Xvfb.
- **Rare material option names** (bug, upstream)
  - What: `$RARE_MATERIALS_NAMES_ARRAY` now says `Onyx Gemstones`, `Lumps of Charcoal`, `Leather Squares`, exactly like the loot tree.
  - Why: the code built `…Rare Materials.Onyx Gemstone` etc., which is not a tree option, so those 3 materials were **never picked up, stored, sold or salvaged**, whatever was ticked (12 dead options).
  - Benefit: the options work. The JSON side was left alone, so every saved config stays valid.
  - Verified: `test_loot_alignment` (it fails with the old names), alignment checker self-test.
- **`Pick up items.Lockpicks` and `Store items.Trophies.Other trophies` are honored**
  - What: before, the code always returned *yes* for both. Now it reads the option. A config without the option still gets *yes*.
  - Behaviour: unchanged for every shipped config and AMG's, because all of them tick both.
  - Verified: `test_loot_alignment` (ticked, unticked, missing; partial trophy stacks still not stored).
- **`@sell.salvageables.*` flags are set** in `BuildInventoryDerivedFlags`
  - Why: the sell rule read `@sell.salvageables.nothing`, but nothing set it.
  - Behaviour: same result, it is a short-cut.
- **Team tab defaults.** The 24 `team.*` options saved in farm configs now have defaults, equal to the values the Team tab controls start with.
  - Why: they had none, so the value depended on whichever config was loaded first.
  - Verified: checker, `test_config`, and the config differential (0 differences).
- **Complete farm configs.** The 9 files in `conf/farm` now contain all 12 options added since v10 (follower.*, `run.auto_attach`, `debug_logging`, `extract_upgrades_only`, `log_chests`, `return_on_death`, `skip_am_fah`), set to the built-in defaults.
  - Why: before, loading one of these files left those options at whatever value the previously loaded config had.
  - Format: BOM and line endings kept.
- **`tools/alignment/check_alignment.py`** (new) is run by `run_tests.sh`, together with a self-test.
  - What it checks: loot JSONs (BOM, roots, tree vs Default, Keep = Extract, booleans), code-built keys ↔ JSON options both ways, derived flags, run options (defaults ↔ persisted ↔ GUI writes ↔ GUI refresh), farm JSONs (keys, types, farm, loot file, district, heroes, build codes, bonder mode), and farms (GUI list ↔ farm map ↔ functions ↔ descriptions ↔ includes).
  - Reviewed findings left as they are appear as ACCEPTED, with the reason.

## v17: Open Storage buttons back to the original behaviour (AMG's request)

- **Both *Open Storage* buttons** (Tools and Options tabs) call `OpenXunlaiWindow()` like the original v10 Options button. They work in town, in explorables (where the game shows storage view-only) and while a farm is running.
  - Removed: the farm-running refusal and its popup, the outpost-only block, and the loading/disconnected block. If the character is loading or in an explorable, a log note is added and the window is still requested.
  - Kept: if not attached, or the GW client has closed, a log line is written instead of reading memory. No popup.
  - Tooltips: the original text, plus "Also works while a farm is running".
  - Why: user preference. This is how the original button worked; the v14/v15 guards blocked legitimate use.
  - Verified:
    - `test_storage`: 91 checks covering 4 runtime states × 3 map types. Re-adding the old restrictions fails 47 of them.
    - static check in `run_tests.sh`: no farm-running, attach-guard, popup or outpost check left in `OpenStorageForTools`.
    - GUI under Xvfb.
- **Removed the "Low lockpicks: N - consider restocking" warning** (upstream v10 code in `ChestRunToward`, printed at every waypoint). AMG asked for no lockpick-amount messages.
  - Root cause of the wrong number: `FindInInventory()` returns the `[bag, slot]` of a lockpick stack, not a count. N was the **bag number** (4 = his lockpicks are in bag 4), and "< 5" was true for any stack outside bag 5.
  - The real counters were correct: `GetInventoryItemCount` and the GUI's `CountTheseItems` sum the Quantity of model 22751 over bags 1-5. No count fix was needed.
  - Unchanged upstream v10 logic: chests are skipped at literally 0 lockpicks, with a one-time "No lockpicks available to open chests" line. The run is not stopped.
  - Verified: `test_chest_logs`, plus a static check in `run_tests.sh` that no lockpick-count message is left.
- **"Taking damage - resynching position with /stuck" log throttled.** The `/stuck` resync itself is unchanged upstream v10 behaviour: a 100 ms Adlib, and at most one `/stuck` every 1.5 s while health drops.
  - Change: only the Notice line is limited, to the first send plus one line per 30 s with a count (e.g. `(18x in the last 30s)`). Every send is still logged at Debug level.
  - Verified: `test_chest_logs`, with the real functions and fast timers.

## v18: skill rotation audit (AMG's request)

- **Shared helper `lib/Utils-ShadowForm.au3`** (new, included by `lib/Utils.au3`): named build constants (14 Shadow Arts, +20% enchantment duration), the refresh window, pure decision functions, DP→SF casting, Shroud upkeep and the Giant Stomp guard. Used by Tasca, Pongmei, Magmas, Follower, DragonMoss, Margonite and Zodiac.
- **Deadly Paradox first, Shadow Form right after it.** Tasca/Pongmei (`ChestFarmCommon`) and Zodiac cast SF first and scheduled DP 750 ms later through an Adlib, so SF never got DP's faster activation/recharge. Now `UseSkillEx(DP)` then `UseSkillEx(SF)` with no sleep in between (UseSkillEx returns about one ping after the stance goes off). The extra `Sleep(200+ping)` after SF and the 5-try SF loop were removed.
  - Verified: `test_sf_rotation` (order checks), static check in `run_tests.sh` (no DP Adlib left), mutation (SF-first fails 6 checks).
- **20-energy gate for the pair** (15 DP + 5 SF). Was 15 in Tasca/Pongmei/Pongmei-chests and none in Margonite. Below 20 nothing is cast (DP is not wasted); exception: SF is 0.5 s from dropping, then SF alone. With foes near, up to 3 s are waited for energy (Magmas' wait had no time limit).
- **Refresh window.** SF and Shroud are recast only when the skill is recharged AND at most `$SF_REFRESH_WINDOW_MS` / `$SOD_REFRESH_WINDOW_MS` = 2.5 s of the effect is left (read from the game's effect list, with our own cast timer as a floor). If the skill is not recharged by then it is cast the moment it is. Replaces the fixed 19.5 s / 62 s timers (Tasca/Pongmei), the 5 s / 6.5 s DP-prep / 20 s Shroud thresholds (Magmas), "whenever recharged" (Pongmei chests, Margonite, DragonMoss) and "only after SF has dropped" (Follower).
- **Shroud of Distress does not starve Shadow Form:** it is skipped if SF needs a refresh within 4 s and casting Shroud would leave less than 20 energy.
- **Pre-emptive "I Am Unstoppable!"** (`ChestKnockdownGuard`, 200 ms Adlib in Tasca, Pongmei, Magmas): fires when a foe within 1250 is casting Giant Stomp (skill 530, 2 s before it lands) or Agnar's Rage (531, 6 s activation); Tremor is an instant shout and cannot be pre-empted, IAU is on the bar, recharged, not active, 5+ energy, and we are not knocked down or mid-cast.
- **Skill slots read from the bar.** The chest code assumed SF in slot 5, DwSt in 2, FN in 4; the shipped Pongmei/Tasca/Magmas templates have SF in 2, DwSt in 4, IAU in 5. Pongmei loads its template, so it cast IAU when it meant SF. Slots are now detected by skill ID at the start of each run (missing skill = skipped) and logged.
- **Smaller fixes:** Vaettirs waits for SF to recharge before DP (was after DP); Pongmei no longer casts Feigned Neutrality right before DP/SF (FN ends when you use a skill); Dwarven Stability gate 10 → 5 energy (its cost).
- Verified: AC (0 errors, warnings identical to v17), `test_sf_rotation` (68 checks), all suites, GUI start-up under Xvfb.

## v19: Rune of Major Vigor - keep, store and extract (AMG's request)

- **Keep:** `Keep components.Armor upgrades.All.Runes.Major Vigor` is back in all 4 shipped loot files (ticked, as in v10) and in the default keep list (`DefaultCreateValuableRunesAndInsigniasArray`). Ticked → Major Vigor armor is neither sold nor salvaged for materials.
- **Extract:** `Extract upgrades only.Armor upgrades.All.Runes.Major Vigor` is back (ticked in `AMG Loot.json`, unticked elsewhere as in v10); rune → expert-salvage slot 1, struct `C202E927` (Py4GW `OfMajorVigor` 0x0100, verified against real dumps; Minor `C202E827` / Superior `C202EA27` are not confused).
- **Store:** new option `Store items.Runes.Major Vigor` stores loose Major Vigor runes (type Upgrade + aligned `C202E927`; the shared model 5550 is not used). Ticked only in `AMG Loot.json`. Armor with the rune is still stored by the rarity rule.
- **Perfect-only cleaner:** one exception, Major Vigor; allow-list 446 → 447. No other Minor/Major rune restored. The attached config now loses 174 leaves (was 176).
- **Note:** with AMG's Store Purple/Gold ticks, Major Vigor armor is stored whole rather than extracted (v8 store protection, unchanged) - ANALYSIS §16.4.
- Verified: AC (0 errors, warnings identical to v18), all suites (test_perfect 2032, test_keep 1319, test_loot_alignment 60, others unchanged), alignment 0 errors - see ANALYSIS.md section 16.

## v20: Shadow Form / Deadly Paradox timing reverted, IAU on Titans (AMG's in-game test of v19)

- **SF/DP timing back to pre-v18, per farm** (AMG: "set it back on its previous timing ... keep the 20 energy & everything else"):
  - Tasca / Pongmei (`ChestMaintainShadowForm`): recast 19.5 s after our last Shadow Form once SF is recharged; up to 3 s wait for 20 energy with foes in spellcast range; nothing under 15 energy.
  - Pongmei while opening chests (`SurviveWhileOpeningChests`): SF whenever recharged with a foe within spellcast + 200, 15 energy.
  - Magmas (`MagmasDefendFunction`): recast when the game's effect list shows < 5 s of SF left (or none), foes near/in front.
  - Margonite: whenever SF is recharged (no DP under Quickening Zephyr, as originally). DragonMoss: whenever recharged. Follower: only once SF has dropped, 5 energy.
  - Vaettirs and Zodiac: their timing was never changed by v18 (only the DP-before-SF order), nothing to restore. FoW Tower of Courage, Stygian, Mantids: never touched.
- **Kept from v18:** DP cast first and SF immediately after (no Adlib, no 750 ms gap); DP only with 20 energy - below 20 SF is cast alone if the farm's old minimum is met; live skill-slot detection and the `Skill slots:` line; no Feigned Neutrality right before DP/SF; Magmas' energy wait bounded to 3 s; Shroud of Distress logic unchanged; all IAU logic.
- **Not restored:** Magmas' separate "DP 5-6.5 s before the SF refresh" step (conflicts with DP-first; DP now goes right before SF, and only if DP is not still active - original condition); the 62 s / 20 s Shroud timers (AMG: keep Shroud).
- **Removed:** the SF refresh window (`ShadowFormRefreshAction`, `MaintainShadowForm`, `$SF_SOLO_FALLBACK_MS`). New shared helper `ShadowFormPairAction` / `CastShadowFormPair` (how to cast, not when).
- **IAU:** Wild Blow (321) and Bull's Strike (332) added to the knockdown threats (same 1250 range, same readiness rules); the log line now names the skill. Wild Blow does not knock down (it ends stances) - see ANALYSIS §17.3.
- Verified: AC (0 errors, warnings identical to v19), `test_sf_rotation` 94 checks (mutations: removing the 19.5 s gate fails 5, removing the Titan IDs fails 6), all suites.

## v21: IAU on Irresistible Blow (Burning Titans' follow-up knockdown)

- AMG: Titans "hit you with wild blow to remove stances ... they follow up with the knockdown". Burning Titan bar (wiki): Irresistible Blow, Thrill of Victory, Wild Blow. The knockdown is **Irresistible Blow (356)**: knockdown if the attack is blocked (Shroud of Distress' 75% block under 50% Health makes that likely).
- Added to `$KD_THREAT_SKILL_IDS` (same 1250 range / readiness rules); log `Knockdown threat (skill 356 Irresistible Blow) - "I Am Unstoppable!"`. Wild Blow stays a trigger.
- No extra re-trigger rule: the threat list itself re-fires IAU on the follow-up if IAU has expired and is recharged.
- Nothing else changed (SF/DP timing, Shroud, 20 energy, slots as in v20).
- Verified: AC (0 errors, 47 warnings, identical to v20), `test_sf_rotation` 102 checks (mutation: dropping 356 fails 4), all suites.

## v22: "Extract selected components before selling" (AMG)

- **Options checkbox wired up:** *Extract upgrades only* was saved but never read. Renamed **"Extract selected components before selling"** (JSON key `run.extract_upgrades_only` kept). When ticked, the trade-town pass extracts the checked components after identifying and **before** material salvage, selling materials and selling items (same list, per-item logic, slots, Store protection).
- **Kits:** uses an Expert/Superior kit; none left and an item still needs one → buys an Expert Salvage Kit (2991, 400 gold) in the trade town and continues; again when it runs out; cap 5 per pass; every buy logged.
- **Hold:** while ticked, items still holding a checked component are never salvaged for materials or sold (failed buy, cap, full bags, failed session) - logged per item plus a summary Warn. Store items protection still wins.
- **Mid-run:** no extraction in explorables (no merchant, foes); mid-run salvage honours the hold; the mid-run town trip now passes the farm's trade town (was always EotN).
- **Tools:** button renamed **"Manual Selected Component Extract"**, resized, with the label "Specified items must be in your inventory (bags 1-4), with an Expert or Superior salvage kit." and a tooltip. Behaviour unchanged (no auto-buy).
- Rotation, IAU and loot settings untouched.
- Verified: AC (0 errors, 47 warnings, identical to v21), new `test_extract_flow` 35 checks, static wiring check, all suites, alignment, SM (Options/Tools screenshots).

## v23: Items panel - inventory + storage totals in categories (AMG)

- **Main tab:** the *Items collected* and *Titles* boxes are replaced by one scrollable **Items (inventory + storage)** list in the same place (a ListView with tinted category header rows; the mouse wheel works). The *Informations* box is unchanged.
- **Totals:** each item row shows the total in the inventory plus Xunlai storage, not the session pickups.
- **Categories, in order:**
  1. Elite Tomes: 10 professions plus Total.
  2. Titles: the 8 session-gain titles plus Lockpicks.
  3. Exchangeables: DoA gems, Armbraces, Rin relics, cores, Kathandrax hammers, commendations, coins, tokens and similar.
  4. Consumable Materials: kabob/soup/salad drops, Wintersday Gifts, conset items and their materials, res scrolls.
  5. Sweets.
  6. Party.
  7. Alcohol.
- **Coverage:** 157 rows and 148 model IDs, all checked against Py4GW, GWCA and GWToolbox (`tools/itemaudit/panel_ids_verify.py`). Every v10 panel item is still listed.
- **Storage:** read from memory in outposts, without opening the chest. Each read is cached per character in `cache/xunlai_counts.ini`. In explorables, and after a restart, the cached storage part is used and the total is marked `*`. A status line under the list shows which one is in use.
- **Refresh:** at run start and end, after the inventory pass, after Open Storage, and at most every 5 s while idle or paused. It never runs during a farm run.
- **Reset:** *Reset session stats* still zeroes the titles and Informations. CSV and stats output are unchanged.
- Rotation, IAU and loot settings are untouched. No memory offsets or packet headers were changed.
- **Verified:**
  - AC: 0 errors, 47 warnings, identical to v22.
  - New `test_items_panel`: 77 checks, with mutation checks.
  - `test_reset` 78, `test_storage` 103, all suites and alignment pass.
  - Static wiring and coverage checks pass.
  - SM: top, middle and bottom screenshots.

## v24: Store Mods, stuck watchdog, Tools > Empty Tab, Graphics labels (AMG)

- **Store Mods:** new *Inventory > Store items > Mods* (unticked in every shipped config). When ticked, the store step puts every loose upgrade component (item type 8: runes, insignias, weapon mods, inscriptions) into Xunlai storage. The loose Major Vigor rule from v19 is unchanged.
- **Removed:** the "pause after 10 failed runs in a row" rule (the `MAX_CONSECUTIVE_FAILED_RUNS` constant and its check). Failed runs keep looping. The hard run deadline is kept.
- **Stuck watchdog (`lib/Utils-StuckWatchdog.au3`):**
  - Trips when a farm run makes no progress for 5 minutes. Progress means a map change, moving 300 or more, XP gained, or a log line never seen before in the run; loading screens hold the clock.
  - On a trip it maps back to the farm's town (a district change if already there) and fails the run (never pauses).
  - It then resets every farm setup flag, so the setup runs again like a first run. Stats, CSV and session counters are kept.
  - Follower, bonder, OmniFarm and utility modes are not watched.
- **Tools > Empty Tab:**
  - A drop-down list (I..XIII, Anniversary = bags 8..20, 21) and an *Empty Tab* button.
  - Moves the tab's items one by one from slot 1 into bags 1-4, topping up stacks first.
  - Only in an outpost or town and not during a run. It stops and logs when the inventory is full.
- **Options:** the rendering button now reads *Disable Graphics* (rendering on) or *Enable Graphics* (rendering off).
- Perfect-only mods with the Major Vigor exception, Open Storage anywhere, no lockpick notifications, the SF/DP timing, IAU and the loot choices are untouched. No memory offsets or packet headers were changed (Empty Tab uses the existing `MoveItem`).
- **Verified:**
  - AC: 0 errors, 47 warnings, identical to v23.
  - New `test_watchdog` 88 and `test_emptytab` 58, both with mutation checks; `test_loot_alignment` 79 (+19).
  - All suites, static wiring checks and alignment pass.
  - SM: Options, Tools (+ drop-down) and Inventory screenshots.


## v25: Store items > Components > Mods / Inscriptions / Insignias / Runes, stored right after extraction (AMG)

- **What:**
  - New Inventory tree branch **Store items > Components** (first child, opened at start) with **Mods**, **Inscriptions**, **Insignias** and **Runes**. It holds the same 447 perfect-only entries as Keep components / Extract upgrades only, plus Major Vigor.
  - A new step **4c** in the trade-town pass stores the ticked loose components right after the extraction (4b) and **before** material salvage and any sale.
  - Storage full: one warning, and the pass continues.
  - Type-8 items are explicitly never salvaged or sold.
- **Replaced:**
  - v24 *Store items > Mods*; when ticked, it migrates to every Components leaf ticked.
  - v19 *Store items > Runes > Major Vigor*, which moved to *Components > Runes > All > Major Vigor*, with no duplicate.
- **Old configs:** missing Components keys are added unticked at load (`MigrateStoreComponentOptions`), so the branches always show, and *Save* persists them.
- **AMG Loot.json:** Components ticked exactly where Keep/Extract is ticked: 130 entries (119 mods, 9 inscriptions, 2 runes). The other configs are unticked. BOMs and line endings are preserved.
- **Why:**
  - AMG could not find the per-group tabs. v24 had only a flat *Mods* leaf, in a collapsed tree, and it was absent from loot files saved before v24.
  - AMG also asked for this to run after extraction and before selling.
- **Identification:**
  - Matching uses the upgrade id, the effect with max-roll requirements and the weapon type (upgrade id or TargetItemType), with the same matchers as extraction.
  - The rune layout is verified on dumps; the weapon-mod and inscription layout comes from the Py4GW parser (no in-game dump yet; TESTING test 49).
  - A mod whose weapon cannot be determined is not stored.
- **Verified:**
  - AC: identical to v24 (0 errors, 47 warnings).
  - New `test_storecomp` (102 checks).
  - `test_extract_flow` 44 (+9).
  - `test_loot_alignment` 80; `test_keep` 1319.
  - v25 static wiring check plus its self-test.
  - 11/11 mutations caught.
  - Alignment errors 0.
  - SM: v25 GUI smoke screenshots, kept outside the bot folder.
  - Details in `ANALYSIS.md` §22.


## v26: slaying suffixes ("+20% damage vs creatures") extracted / kept / stored; 19% rolls no longer kept (AMG)

- **What:**
  - New slaying matcher `FindSlayingUpgradeGroup`, used by `FindUpgradeGroupForStruct` for every *of Deathbane / Charrslaying / Trollslaying / Pruning / … Slaying* leaf. It finds the species (BaneSpecies) anywhere in the item and the +20% (DamagePlusVsSpecies = 20, exactly) in the suffix group.
  - `ContainsValuableUpgrades`: old-school (non-inscribable) weapons use the checked *Keep components* lists and the max-roll matcher, like inscribable ones. The hardcoded, unaligned OS list is no longer used for keeping.
  - Debug log: an item skipped by the extraction shows ` (slaying: species n, damage +x% vs species)`.
- **Why:**
  - Bug 1: the matcher required the BaneSpecies dword inside the suffix group; Py4GW reads it item-wide. A real slaying suffix never matched, so it was not extracted, held, kept or stored (AMG: "aren't salvaging").
  - Bug 2: old-school weapons were kept through a hardcoded list holding the Charr/Troll/Giant/Dwarf/Tengu slaying dwords with no roll check, ignoring the tree. A 19% (or 15%) slaying weapon was never salvaged or sold (AMG: "keeping 19% mods").
- **Benefit:** only the 20% roll of a ticked slaying suffix is kept, extracted, held or stored; 15-19% and unticked species are salvaged/sold by your normal rules.
- **Behaviour change:** an old-school weapon is kept for its mods only if the mod is ticked under Keep components (other keep rules unchanged).
- **Unchanged:** loot files and AMG's ticks (all 55 slaying leaves already present in the 4 files; AMG: 7 species × 5 weapons + Axe Pruning), tree, rotations, offsets, headers.
- **Verified:**
  - AC: 0 errors, 46 warnings (v25: 47; the removed one was the OS list's "possibly used before declaration").
  - New `test_slaying` (112 checks; 46 of them fail on the v25 code, `tools/out/v26_slaying_v26_vs_v25.log`).
  - `test_keep` 1319, `test_extract_flow`, `test_storecomp` unchanged and passing.
  - 12/12 mutations caught (`tools/mutation/mutate_v26.py`).
  - Alignment errors 0.
  - Details in `ANALYSIS.md` §23; in-game checks: `TESTING.md` P11.

## v27: old-school weapons no longer kept for inherent mods; only OS auto-keeps are q9 +5 energy and wand/focus HCT+HSR pairs (AMG)

- **What:**
  - `ShouldKeepWeapon`: an old-school (non-inscribable) weapon is kept only by the generic rules (equipped, customized, green, unidentified, ultra-rare model, ticked *Keep components*) or by the new `IsOSAutoKeepWeapon`. The rare-skin / `HasPerfectMods` / `HasAlmostPerfectMods` / `HasOkayMods` OS rules are removed.
  - `IsOSAutoKeepWeapon` (no tick needed):
    - requirement 9 + inherent Energy +5 (any OS weapon; an Insightful head or *I have the power!* inscription does not count);
    - wand or focus, requirement 9 or 10, halving casting time AND skill recharge: 20% of the item's requirement attribute or inherent 10% of all spells, any mix (20/20, 10/10, 20/10, 10/20). Single HCT or HSR never; staves never; salvageable 10% sources (Swift, of Swiftness, of Quickening, Don't think twice, Serenity now, Let the memory live again) do not count.
  - New modstruct helpers: `GetModStructRequirement`, `ModStructHasEffectArgs`, `HasInherentEffect`, `HasInherentEnergyPlusFive`, `IsEffectFromUpgrade`, `HasCasterHalvesPair`.
  - `run_tests.sh` fails when a unit test prints no RESULT line.
- **Why:** AMG (t33u-t40u): inherent mods (15^50, +15% enchanted/stance, inherent zealous/vampiric strength, +30 health, armor…) must not keep a weapon; salvageable mods (Zealous/Vampiric prefixes, inscriptions) only through his ticks; the only automatic OS keeps are the two rules above. v26 kept OS weapons through a hardcoded, unaligned, attribute-blind "perfect mods" list.
- **Benefit:** OS weapons with only inherent mods are salvaged/sold by your rules; the q9 +5 energy weapons and the 10/10, 20/10, 10/20 casters are now kept; a 20/20 of the wrong attribute, at q8/q11+, or on a staff is no longer kept.
- **Unchanged:** inscribable weapon rules, Store items, Extract, loot files and AMG's ticks, `$MAP_ULTRA_RARE_WEAPONS` (model-based) keep.
- **Verified:**
  - AC: 0 errors, 46 warnings (same set as v26).
  - New `test_oskeep` (149 checks, incl. single 20% / single 10% HCT or HSR not kept on wand and focus at q9 and q10); 55 of them fail with the v26 OS branch (`tools/out/v27_oskeep_v26_os_branch.log`).
  - Full suite passing (`test_keep` 1319, `test_slaying` 112, …); 23/23 mutations caught (`tools/mutation/mutate_v27.py`).
  - Details in `ANALYSIS.md` §24; in-game checks: `TESTING.md` P12.

## v28: BotsHub window icon (AMG's inverted helmet)

- **What:** `assets/icon/BotsHub.png` (AMG's helmet, RGB inverted, transparency kept, 256x256) and `assets/icon/BotsHub.ico` (16, 24, 32, 48, 64, 128, 256). `CreateBotsHubGUI` sets it on the main window with `GUISetIcon(@ScriptDir & '\assets\icon\BotsHub.ico')`, only if the file exists (otherwise the default AutoIt icon, no error). `#AutoIt3Wrapper_Icon=assets\icon\BotsHub.ico` added to `BotsHub.au3` for anyone who compiles it (no effect when running `BotsHub.au3` directly).
- **Why:** AMG: "I only want the icon color inverted … and then to use it for the icon for my bot" (the GWA2 BotsHub); he runs `BotsHub.au3` with AutoIt x86.
- **Benefit:** the window title bar and taskbar show the helmet.
- **Unchanged:** `#NoTrayIcon` (no tray icon), the 'List of stuff' popup (tool window, no icon), everything else.
- **Verified:** AC 0 errors, 46 warnings (same set); GUI smoke under Wine (`tools/out/v28_window_icon.png`).

## v29: Inventory "Keep components" removed (AMG)

- **What:**
  - The *Keep components* branch is gone from the Inventory tree and from the 4 shipped loot files (AMG Loot.json included; 591 lines each, nothing else changed).
  - `LoadLootConfiguration` drops a *Keep components* root from older loot files silently (no warning, no error). It is not in the cache, so it is not in the tree and is never saved back.
  - `ShouldKeepWeapon` no longer keeps a weapon for its mods; armor salvageables are no longer kept for their runes / insignias (`DefaultShouldSalvageItem` / `DefaultShouldSellItem`).
  - Removed code: `ContainsValuableUpgrades`, `RefreshValuableListsFromCache`, `CreateValuable*` / `DefaultCreateValuable*`, `CreateValuableUpgradeRequirementsMap`, `KeepUpgradePresent`, `TrimCleanupAndEval`, the `$valuable_*` globals and their calls (loader, Apply button).
  - Extract: no *Keep components* fallback any more (no branch = "Nothing is checked under Extract upgrades only").
  - Store items > Components is seeded from *Extract upgrades only* only. `$PERFECT_OPTION_ROOTS` = Extract upgrades only.
- **Why:** AMG asked to remove the tab; items with perfect mods are handled by *Extract upgrades only* (+ *Extract selected components before selling*) and *Store items > Components*, then sold.
- **Behaviour changes:**
  - A weapon / shield / focus with a perfect mod or inscription is no longer kept whole. With *Extract selected components before selling* on, it is held, the ticked component is extracted, then the item is salvaged/sold by the normal rules. With it off, it is salvaged/sold with the component in it.
  - Armor salvageables with perfect runes / insignias: same. In AMG Loot purple and gold armor salvageables are stored (Store items rule, unchanged); blue ones are sold after extraction.
  - AMG's Keep ticks (128) were all also ticked under Extract (130), so no ticked component loses its extraction.
- **Unchanged:** the v27 OS auto-keeps, ultra-rare model, green, unidentified, equipped, customized, inscribable rare-skin / low-req rules; the Major Vigor exception (Extract + Store items > Components > Runes > All).
- **Verified:**
  - AC: 0 errors, 43 warnings (v28: 46; the removed globals' warnings are gone).
  - `test_keep` rewritten for v29 (82 checks: shipped files, a v28 AMG Loot.json with Keep components loads warning-free with identical Extract/Store/Salvage/Sell ticks, v10 file, odd shapes, no mod keep, armor, Major Vigor, no fallback).
  - `test_slaying`, `test_oskeep`, `test_storecomp`, `test_perfect`, `test_loot_alignment` adapted. `test_oskeep` found that two v27 checks passed only through the Keep tick (a wand whose 10% HSR comes from a salvageable *of Quickening*); they now correctly expect "not kept".
  - Full suite passing, alignment errors 0 (a legacy *Keep components* root is reported as a warning), GUI smoke `tools/out/v29_inventory.png`.


## v30: map load guard before acting after a map change; stuck watchdog 2 min in towns and explorables (AMG)

- **What (load guard):**
  - New central guard in `lib/GWA2.au3`: `WaitMapReady(map, type, timeout, settle)`, `IsMapReadyNow`, `MapReadySample`, and the pure `MapReadyReason`. A map counts as loaded only when **3 samples in a row** (250 ms apart) show: no loading screen; instance type outpost/explorable (and the expected one when given); player agent ID ≠ 0; agent array populated; the player agent struct exists; the map ID is the expected one; the player's position is set (not 0,0 / NaN); the party list has ≥ 1 member. Then the settle delay. Timeout → `False`, with the reason in `$map_ready_last_reason`. It never sends anything to the game.
  - Safety net: position and party are the only checks that rely on less-proven memory reads. If everything else has been ready for 4 s they are waived (one debug line), so a bad offset falls back to the pre-v30 checks instead of turning every travel into a timeout.
  - `WaitMapLoading` (GWA2) now delegates to `WaitMapReady` with the same signature and return value, so every caller gets the guard: 13 direct calls, 90 `RobustWaitMapLoading` calls, the guild hall travel functions, and `DistrictTravel` / `RandomDistrictTravel`. Both of those now return the readiness.
  - `TravelToOutpost` (used by `RobustTravelToOutpost`, the town pass and ~120 farm call sites): when the map ID already matches, it checks the load finished (immediate when it has; waits otherwise). After a travel it returns `$FAIL` when the outpost never finishes loading. Before, it returned `$SUCCESS` as soon as the map ID matched.
  - `ResignAndReturnToOutpost`: waits for the **outpost** type (with `$ignoreMapID`, the explorable has the same ID, so before it could return while still loading). Timeout raised from 10 s to 20 s.
  - New `ConfirmMapReady(map)` (Utils). Wired into all 26 "walk into the portal until the map ID changes" loops (farms, vanquishes, runs, missions) and the 8 FoW / UW / Urgoz / Deep entries. A map whose ID switched but never finished loading fails the run (`$FAIL`) instead of the bot moving, talking or casting into it.
  - Magma's: `EnterChallenge()` was followed only by `Sleep(3000)`. It now waits for the explorable to be ready before drinking, casting or flagging. `MagmasWaitForMapType` uses the central guard.
- **What (watchdog):**
  - `$STUCK_WATCHDOG_TIMEOUT_MS` is now 2 min (was 5 min).
  - It now starts at the beginning of the run, so it covers the town phases too: mid-run kit purchase, the inventory town pass (identify, extract, store, salvage, sell, buy) and global setup. Before, it only covered the farm function. When it trips during the town phases, the farm is skipped for that run (logged `[Stuck] Tripped before the farm started`). The run counts as failed, and setup runs again from scratch.
  - New progress signal: any inventory change. That covers gold (character and storage), item counts per bag and per Xunlai tab, and for the bags the sums of item ID × slot, quantity, value (kit uses) and the identified flag. Long salvage, extract, store, sell, identify and buy passes keep the watchdog fed even when they log nothing new. A step that retries the same item without effect does not count.
  - The Storage utility (a standalone town pass) is now watched. Follower, Monk Bonder, EleMonk UW Bonder, OmniFarm, Manual Mode and Tests are still excluded. Recovery is unchanged: map back, run failed, all setups reset, stats kept. Loading screens still hold the clock.
  - Bounded farm waits that could end right at 2 min, so the watchdog would race the farm's own fallback, now end earlier. Spirit Slaves ball/ally waits: 120 s → 100 s. Corsairs' Bohseda wait: 120 s → 100 s. Glint's stray-foe sweep: 150 s → 100 s.
- **Why:** AMG suspected the bot gets stuck because it starts acting before the game has fully loaded after a map change. The old wait only checked agent ID, agent count and map ID, which switch before the map is usable. He asked for a 2-minute watchdog in towns and in explorable zones.
- **Verified:**
  - AC: 0 errors, 43 warnings (same as v29).
  - New `test_mapready` (80 checks): every `MapReadyReason` reason (NaN position included); staged loads where the map ID switches long before the loading screen ends; position or party arriving late; an agent flicker that needs 3 stable samples; timeout with no settle; wrong map; wrong type (shared-ID explorable); the 4 s grace never waiving hard checks; the `WaitMapLoading` contract; `TravelToOutpost` (normal travel, already there, ID matched but still loading, no access, load never completes); `DistrictTravel` / `RandomDistrictTravel`; `ConfirmMapReady`; resign + return with a shared ID. Mutation check: 1 stable sample instead of 3 → 3 failures.
  - `test_watchdog` updated for 2 min (115 checks, +26): the inventory signature (kit use, identify, stack change, sort, Xunlai, gold); an 8-minute town pass that changes the inventory never trips; no change trips at 2 min; trips in town (district change); no inventory reads while loading; Storage watched.
  - Static `v30_static.py` (guard wiring, all 26 portal loops, 8 entries, Magma's, watchdog before the town phases) plus its self-test. The v24 order check was adapted (`StuckWatchdogStop()` also on the inventory-full pause path).
  - Full suite passing.

## v31: Items panel Session column; dark GUI theme with an accent palette (AMG)

- **What (Session column):**
  - Main tab > *Items (inventory + storage)* now has three columns: **Item | Session | Total**. *Session* is the net change since BotsHub started for the logged-in character: current total (inventory + Xunlai storage) minus a baseline. It shows `+N`, `0` or `-N` (sold, used or dropped items give negatives). The Elite Tomes *Total* row sums the tome deltas. Title rows show the session gain in both columns (they already counted from 0).
  - Baseline: taken once, on the first **complete** read. That means an outpost, the map fully loaded (v30 `IsMapReadyNow`), Xunlai storage read live (not from the cache), and bags 1, 6 (material storage) and 8 (first storage pane) all readable. A partial or explorable read never sets it. Until then the cells are blank. Switching to another character resets it and takes a new baseline for that character.
  - Moving items between inventory and storage (Empty Tab, Store items, manual moves) leaves Session unchanged, because both sides are counted. A `*` follows Session just as it follows Total when the storage part comes from the cache.
  - The panel keeps its v23 position and size. The Item column narrowed to 152 px; full names appear as label tooltips. The panel tooltip explains the column.
- **What (dark theme):**
  - The whole window is dark with light text: window, tab headers (painted by a subclassed tab control: dark strip, the selected tab lighter with gold text), pages, group boxes, labels, checkboxes, radios, edits, inputs, combos, the loot tree, the Items panel and the console.
  - Accent palette: near-white normal text; gold group titles, Items panel category rows, selected tab and loot-tree branch titles; light blue values (Informations numbers, Items totals); green `+N` and soft red `-N` Session values; muted grey for zero or blank cells and disabled controls; console levels: debug green, info light grey, notice cyan, warning amber, error soft red. Buttons are dark, with blue Start / Open Storage / Run, amber Apply changes / Disable Graphics, green Enable Graphics, red Pause and dark amber "will pause".
  - Every colour is a constant in the new `lib/BotsHub-Theme-Colors.au3`. The new `lib/BotsHub-Theme.au3` applies them once after the GUI is built (`ThemeApplyDark`): visual styles are switched off per checkbox/radio/group/combo/progress (uxtheme `SetWindowTheme`) so the colours stick. Group titles are redrawn as gold labels in their own tab (Wine draws classic group captions black whatever the colour).
  - *Informations* content and layout are unchanged; only colours changed.
  - Known limits: the ListView column header (Item/Session/Total) stays light on Wine and Windows before 10 1809 (dark from Windows 10 1809 via `DarkMode_ItemsView`); scrollbars and combo arrows keep the system look; under Wine the progress bar ignores colours (it is dark on Windows).
- **Why:** AMG asked for a per-session count next to the totals, an inverted (dark, white-text) GUI, and other accent colours for different things.
- **Verified:**
  - AC: 0 errors, 43 warnings (unchanged).
  - `test_items_panel`: 145 checks (+13 on v30 for the session block, +10 colours). It covers: 3 columns with Session before Total; no baseline while the map isn't ready, in an explorable or from cached storage; Store and Empty Tab moves net 0; gains, losses and sold items; the baseline never moving; the alt-character rebaseline; the tome Total delta; per-cell colours (green/red/grey Session, blue/grey Total, gold header rows).
  - New `tools/v31_static.py` (Session wiring, theme applied after the last tab, no `$COLOR_*` or white literals left in the GUI, log and console colours from the palette, accent buttons via `ThemeSetButton`, no colour literals outside the palette) plus its self-test. Full suite passing.
  - SM: Wine/Xvfb screenshots of all 7 tabs before (`tools/out/v31_before_*.png`) and after (`tools/out/v31_dark_*.png`), and of the panel with simulated data (`tools/out/v31_items_panel.png`, produced by `tools/gui/items_panel_shot.sh`).

## v32: Informations labels no longer cut off; other clipped GUI text fixed (AMG)

- **What:**
  - Main tab > *Informations*: "Time per run:" and "Obsidian Shards:" were wider than their labels (65 / 85 px), so they wrapped onto a second line the 16 px label hides, leaving "Time per" and "Obsidian". The label and value cells are now sized to the text: left labels 78 px, right labels 90 px, value cells 53 / 58 px (Time 81 px), all inside the unchanged group box. Same 12 rows, texts and order as v10; nothing else moved.
  - Same check on every tab. Seven more pre-existing cut-offs were fixed:
    - "Identification kits:" (Options);
    - the three faction radios (explicit width; they show for faction farms);
    - "Team member build" (Team);
    - the Inventory tab "Expand all" / "Reduce all" buttons (the button column is now 63 px wide, with Load / Save / the hint / Apply aligned).
- **Cause:** the original v10 layout. The same cut-offs are in v10 (`clip_scan.sh original` reports them all, plus two for v10 labels that v23 removed). Neither v23 nor the v31 theme caused them; the dark theme only made them easier to see. The v31 gold group-title labels are sized to their text and aren't clipped.
- **Verified:**
  - New `test_info_fit` (85 checks, generated by `tools/gen_info_fit.py` from the real geometry and run under Wine with the real font). Every label fits on one line, every value cell fits a worst-case value ("99h 59min 59s", "59min 59s", "9999k999g", "99999999", "99.99 %"), there are no overlaps, and everything sits inside the group. v10's geometry fails 7 of these checks.
  - New `tools/gui/clip_scan.sh`: scans all 115 text controls of the running window for word-wrap clipping. 0 left (v10: 11).
  - The v23 static check now requires the Informations controls, texts and order to match v10, but allows new coordinates.
  - AC 0 errors, 43 warnings. Full suite passing. Screenshots: `tools/out/v32_dark_*.png`.

## v33: Titles tab; TITLES out of the Items panel (AMG, approved mockups)

- **What:**
  - New **Titles** tab, placed before *Farm infos* (Main, Options, Team, Inventory, Tools, Follower, Titles, Farm infos). No scrolling, built to the approved `tools/out/v33_titles_mockup.png`:
    - *Reputation titles* (2 x 4): Asura, Deldrimor, Norn, Vanguard, Kurzick, Luxon, Lightbringer, Sunspear. Each shows a gold name, a progress bar to the max rank (green when maxed), Session (+N, blank until the baseline) and Total.
    - *Zaishen chest*: points / 100,000 with a bar, Session, **Keys needed** = ceil(max(0, 100000 - points) / 5) ('Maxed' when done), and Zaishen Keys owned (inventory + storage) with "N short" or "enough to max".
    - *Consumable titles*: Sweets (Sweet Tooth), Alcohol (Drunkard), Party (Party Animal). Each shows points / 10,000 with a bar, Session, points available in the inventory (bags 1-5 only), where points count, and a button: *Eat all sweets*, *Drink all alcohol*, *Use all party items*.
  - Buttons: one item at a time from the inventory, never storage. Refused during a farm run (same rule as Tools). Only items that award points on the current map are used, the rest are logged as skipped:
    - town sweets in outposts, combat sweets in explorables;
    - death-penalty / morale sweets (Honeycomb, Pumpkin Cookie, Refined Jelly, candy canes) and War Supplies are never used;
    - alcohol in any PvE area; stops when the Drunkard points stop increasing;
    - festive items in towns / outposts / guild halls, not PvP outposts; one tonic per ~5 s (Tonic Tipsiness); Crate of Fireworks in a guild hall only.
    - Points are checked after each item; an item that gives nothing is not used again in that pass.
    - Stops on map change, loading or disconnect. Each item used and the points gained are logged. The stuck watchdog only runs inside farm runs, so it never watches these buttons.
  - Session baseline per character, independent of the storage: two equal reads on a fully loaded map; a character change re-baselines. *Reset session stats* leaves it alone (same as the Items panel Session). Refreshed from `ItemsPanelRefresh` (same rate and safe points).
  - Items panel: the TITLES category is gone. Lockpicks is now the last Exchangeables row. Zaishen Keys and the title consumables are counted in the same inventory read (no extra rows). The old title statics in `UpdateStats` and `ItemsPanelResetTitles` were removed.
  - The farm-configuration combo moved 20 px right (190 px wide) so it no longer covers the eighth tab header.
- **Values:** verified on wiki.guildwars.com (URLs cited in `lib/Utils-TitlesTab.au3`). Title indexes = GWCA `TitleID`. All 76 item model IDs cross-checked by name against Py4GW `ModelID` and GWCA `ItemIDs.h`. See ANALYSIS.md section 29.
- **Verified:**
  - New `test_titles_tab` (110 checks): wiki values, point tables, keys-needed math, where-it-counts matrix, availability, baseline, tab labels and bars, consume loop with simulated bags (map-type filtering, storage never touched, alcohol stop, give-up, guild-hall crate, map change, loading). `test_items_panel` (150) and `test_reset` updated.
  - Static checks updated. `clip_scan` 0 clipped. AC 0 errors, 43 warnings (unchanged). Full suite passing.
  - Screenshots: `tools/out/v33_titles_tab.png` (simulated data), `v33_items_panel.png`, `v33_dark_*.png`.

## v33.1: Raptors W/N only (AMG, explicit approval)

- **What:** `src/farms/Raptors.au3` no longer has a Dervish path. Removed `$DN_RAPTORS_FARMER_SKILLBAR`, the seven Dervish slot constants (`$RAPTORS_SIGNET_OF_MYSTIC_SPEED`, `_MIRAGE_CLOAK`, `_VOW_OF_STRENGTH`, `_ARMOR_OF_SANCTITY`, `_DUST_CLOAK`, `_PIOUS_FURY`, `_EREMITES_ATTACK`), the `Case $ID_DERVISH` setup branch, the two Dervish `Case`s in `RaptorsSurvive` / `KillRaptors`, the three `If ... == $ID_DERVISH` lines and the Eremite's Attack `Else` spike. Any non-Warrior primary now gets the existing `Warn('Should run this farm as warrior')` and setup fails, as other professions already did. Farm infos shows only the W/N template.
- **Why:** the "D/N" template actually decoded to a W/N bar (the warrior bar without Strength), and the script's own comment said the Dervish variant did not work.
- **Benefit:** a Dervish no longer loads a wrong bar and runs a broken rotation.
- **Verified:** every removed identifier was used only in `Raptors.au3` and the Farm infos line (rg over the repo). RV: the Warrior path is unchanged (only Dervish-only lines deleted). AC 0 errors, 43 warnings (identical list to v33). Full suite passing.

## v34: Build Info tab and tab order (AMG, approved mockups v34b/v34c/v34d)

- **What:**
  - The *Options* tab is renamed **Setup**. Tab order is now Main, Setup, **Build Info**, Team, Inventory, Follower, Titles, Tools. The configuration combo still sits clear of the 8th (Tools) header.
  - *Farm infos* is renamed **Build Info**. There is no Load Script button. Selecting a farm in the bottom-left farm combo fills the tab immediately. Until a farm is selected the tab shows "Select a farm to see its builds".
  - Builds are listed with profession, a copyable template code and attributes. Long notes are in a scrollable read-only edit. Online notes are merged in; no source links appear in the GUI.
  - Every farm's bars from the v34 inventory are shown, including the 11 that Farm infos previously hid (Boreal Warrior and Paragon, FoW Tower of Courage hero bars, four Magmas profession bars, three Vaettirs Me/A Fast Casting variants). Gemstones hero rows follow the bot's hero order (1-3 Energy Surge, 4 MM Lich, 5 MM, 6 BiP, 7 ST); the notes no longer claim ST-first.
  - Ele/Monk UW Bonder shows the PvX template `OgNDwcPPT1C3MaRkEyDxDHE0lA` for reference only — the bot does not load it. Monk Bonder is description only (the wrong A/D code is not shown). Raptors stays W/N only (v33.1).
  - Build Info is display-only: no farm script and no loaded template changed.
- **Why:** the old Farm infos tab hid bars, showed broken or wrong bonder codes, and used wiki links; the new tab is the farm's build reference, filled as soon as a farm is chosen.
- **Benefit:** you can copy a template and read the notes without leaving the bot, and the tab matches the approved mockups.
- **Verified:** `test_buildinfo` (empty state, Gemstones order, 11 previously unshown bars, EleMonk/Monk Bonder display rules, no links in any farm's notes). `v31_static` tab-order checks. AC, full suite — see the v34 commit notes.

## v35: Setup tab cleanup and Inventory extract rename (AMG, approved mockups)

- **What:**
  - The Setup tab is laid out as in the approved mockup: Run options, Faction, Inventory management, Other options, and Actions.
  - These controls are removed from the GUI: Auto-attach on character select, Share Memory, Emergency Travel, the Salvage kits and Identification kits combos (kit buys stay the hardcoded 12 salvage / 4 superior identification), Salvage during run (mid-run salvage is forced off; leftover `run.farm_materials_mid_run` keys are accepted and ignored), and Collect data into database (the GUI toggle is gone; `run.collect_data` is still loaded and saved, so existing configs such as Custom.json keep their value; new or missing configs default to off).
  - A new **Salvage into materials** checkbox (`run.salvage_into_materials`) gates all material salvage (town and any other path). For a new user or a missing key it is unticked.
  - **Disable Graphics** is unchanged except that it now sits in the Actions row (same label, 122×22 size, colours, tip and handler).
  - Inventory: *Extract upgrades only* is renamed **Extract Components** and sits before *Salvage items*. Older loot files keep their ticks on load; the new key is written on save.
  - Store-ticked items are never sold. `DefaultShouldSellItem`, `DefaultShouldSellBasicMaterial` and `DefaultShouldSellRareMaterial` now honour `IsProtectedByStoreItems` the same way salvage and extract already did. Town-pass order is still extract → store components → material salvage.
  - `Default Loot Configuration.json` ships fully unticked. `Default Farm Configuration.json` has `salvage_into_materials: false` and no longer lists the removed keys. Pre-existing default-farm ticks (`loop_mode`, `hard_mode`, `consume_consumables`, `donate_faction_points`) are left as they were. AMG Loot.json, Loot.json, Sin Tasca's ChestRun.json and Custom.json were not edited.
- **Why:** the Setup tab had unused or unsafe controls, mid-run salvage and kit-count combos did not match how the bot actually buys kits, and a Store tick did not stop a matching Sell tick from selling the item.
- **Benefit:** a new user starts from empty options; material salvage is opt-in; Store always wins over Sell; the Inventory extract branch has a clearer name; leftover configs still load.
- **Verified:** `test_config` (removed keys parse, mid-run forced off and not written back, `collect_data` kept, missing `salvage_into_materials` stays false). `test_keep` (AMG's 130 extract ticks survive migration, salvage gate, store protection on item and material sell). `test_loot_alignment`, `test_slaying`, `test_storecomp`. Alignment checker accepts legacy extract roots in older loot files and leftover farm keys. AC, full suite, clip scan.

## v36: Minor and Major runes restored on Extract / Store Components (AMG)

- **What:**
  - Minor and Major runes are back in every Inventory-tab branch that already listed Superior runes: **Extract Components > Armor upgrades > (All | each profession) > Runes**, and the mirrored **Store items > Components > Runes** groups. Single-tier All-runes (Vitae, Attunement, Recovery, Restoration, Clarity, Purity) were never removed; **Minor Vigor** is restored next to the existing Major and Superior Vigor leaves. Leaf order matches the pre-v12 tree (Minor, then Major, then Superior, with All.Runes starting at Minor Vigor).
  - These 87 leaves (the same 87 v12 had pruned as "non-perfect") were removed in v12 for perfect-only extraction; v19 had already restored Major Vigor as the only exception. The existing `STRUCT_*` / `ID_*` constants (v11 audit) are reused — no invented mod IDs. Ticking a Minor or Major rune now extracts or stores that rune; the Major Vigor exception and max-roll rules for weapon mods / inscriptions are unchanged.
  - Older loot files are not edited. At load, missing rune leaves are added **unticked** (same pattern as v25 Store Components). `Default Loot Configuration.json` ships with all 87 new leaves present and unticked. AMG Loot.json, Loot.json, Sin Tasca's ChestRun.json and Custom.json were not modified.
- **Why:** AMG asked for Minor and Major runes to be available again wherever Superior runes already appeared, without having to redo his current loot ticks.
- **Benefit:** you can tick Minor or Major runes for extract and store; existing ticks load exactly as they did in v35.
- **Verified:** `test_v36` (tick-preservation vs a v35 loaded-cache snapshot, 174 new leaves unticked, all 138 canonical rune leaves resolve, Minor Vigor dump matches the existing struct). `test_keep` / `test_perfect` / `test_storecomp` / `test_loot_alignment` updated for 534 extract/store-component leaves. AC, full suite, clip scan.

## v36.1: Inventory branch order, Show me the money extract match (AMG, approved mockup)

- **What:**
  - Display-only reorder of the Inventory tab's top-level loot branches in `BuildTreeViewFromCache`: Pick up items, Identify items, Extract Components, Store items, Salvage items, Sell items, Buy items. Loot keys, config paths and farm behaviour are unchanged. Store items stays a single branch (it is used at four points in the town pass and cannot be split by a display-only reorder).
  - `STRUCT_INSCRIPTION_SHOW_ME_THE_MONEY` was a typo (`3200F805`, effect 0x05F, unknown to Py4GW). Ticking **Show me the money (Improved sale value)** therefore never matched a real inscription. It now uses `3200F825` (Py4GW IncreasedSaleValue = 0x25F). A full audit of all 534 Extract Components leaves found this as the only extraction-matching bug; see `tools/out/v36_extract_audit.md`. Saved loot configs were not edited.
- **Why:** AMG asked for the branches to follow execution order (approved `tools/out/v36_inventory_order_mockup.png`) and for extract ticks on mods, runes, insignias and inscriptions to actually extract.
- **Benefit:** The tree reads in town-pass order, and a ticked Show me the money inscription is extracted.
- **Verified:** Tick-preservation vs v36 (AMG Loot.json, Loot.json, Sin Tasca's ChestRun.json ticked sets identical; Default Loot still fully unticked). New `test_extract_leaves` runs every Extract Components leaf through the resolver and matcher. Farm run scripts unchanged. AC, full suite, clip scan.

## v36.2: Masterloot imported as a current-format loot config (AMG)

- **What:**
  - AMG's Masterloot file is shipped as a new `conf/loot/Masterloot.json` in the current tree, next to the other loot configs, so it appears in the Inventory tab's Load dialog. Every mappable checkmark is carried over as-is, including Salvage ticks (already all unticked). `Extract upgrades only` was renamed to `Extract Components`. The 174 v36 Minor/Major rune leaves that were not in Masterloot are present and unticked.
  - `Keep components` has no current equivalent (removed in v29) and is not in the file; those 128 ticked leaves are listed in `tools/out/v36_2_masterloot_import.md`. They were not remapped. AMG Loot.json, Loot.json, Sin Tasca's ChestRun.json and Default Loot were not edited.
- **Why:** AMG asked to transfer all Masterloot settings into the new loot page without re-ticking anything.
- **Benefit:** You can Load `Masterloot.json` and run with those ticks; Store items protection still wins over Sell / Extract / Salvage where paths overlap.
- **Verified:** `test_masterloot` (every mappable original true leaf is ticked; imported file loads through the real loader and matches loading the original; 174 new rune leaves unticked; Salvage still 0). Tick-preservation of the other four loot configs unchanged (`test_v36`). Farm run scripts unchanged. AC, full suite, clip scan.

## v38.12-bridge: GWBridge build, clean public slate, tidier top-right cluster (AMG)

- **What:**
  - Built on the BotsHub auditor's latest bridge build, v38.9.1-bridgeA (GWBridge DLL reads through shared memory, classic GWA2 fallback; Storage Sort minimum 0.10 s per move, as AMG asked), merged with v38.11 (Xunlai chest button, About tab, AMG rename).
  - Top-right cluster: chest (20x20), template combo and save icon (20x20) all at y=10 on the tab-strip row with 7 px gaps; the save icon ends at x=638, inside the tab panel edge. Tab headers use 4 px horizontal padding (text unchanged), so the combo is 170 px and shows "Default Farm Configuration" in full; its drop-down list is 220 px wide. `TopRightClusterLayout()` measures the real end of the About header after the tabs exist and moves the chest and combo so the gaps hold on any font.
  - Clean slate for other players: only `conf/farm/Default Farm Configuration.json`, `conf/loot/Default Loot Configuration.json` and `conf/loot/Masterloot.json` ship. All other farm and loot configurations and all pre-saved hero build templates (the 7 default hero build codes, in the Default config and the built-in defaults) were removed; build loading is off by default, so nothing changes unless a user enters a build. Logs are not shipped. Character names removed from comments and notes.
- **Why:** AMG wants a fresh copy other people can try, with none of his data.
- **Verified:** Au3Check, full test suite, clip scan, screenshots of the top-right cluster and the full window; Tasca.au3, Pongmei.au3 and Masterloot.json byte-identical; ChestFarmCommon.au3 changed in two comment lines only (name).

## v38.11: v38.9 auditor build plus the Xunlai chest button, About tab, narrower template box and AMG rename (AMG)

- **What:** built on AMG's v38.9 build (the BotsHub auditor's performance upgrades, see the v38.9 entry below; every one of its files kept as it was). Added on top:
  - The bot settings template combo is narrower (125 px, was 190) and stays right-justified with the save icon (still at 615).
  - A Xunlai storage chest button sits in the freed space to the left of the combo. It is visible on every tab, uses the existing `OpenStorageForTools()` behaviour (v17: town, explorable, and while a farm is running; only not-attached / client-closed are logged), and has the tooltip 'Open Xunlai storage'. The chest icon is `assets/icon/xunlai_chest.bmp` (plus a PNG of the same art).
  - A new About tab is at the end of the tab strip, after Tools. It has a short write-up of BotsHub 2.0 ("AMG's enhanced edition"), a clickable link to the original BotsHub at https://github.com/caustic-kronos/BotsHub (the repo is caustic-kronos, not kronos-caustic), and a clickable email ("Email AMG at:") to alphametagamma420@gmail.com for addition, optimization, or bug-fix requests. The link and email open with ShellExecute / mailto.
  - Shipped text uses AMG rather than a real name (README, CHANGELOG, TESTING, VERSION, ANALYSIS, in-source comments, including the comments and changelog text added by the v38.9 audit). The loot config previously shipped under a personal name is now `conf/loot/AMG Loot.json` (contents unchanged). `ChestFarmCommon.au3` is protected and unchanged, so its two comment-only mentions remain.
  - The v38.8 window title (character name only) was already in the v38.9 build and is unchanged.
- **Layout note:** AutoIt tab headers live inside the tab control, so the About tab is after Tools in the strip, and the chest button is to the right of the tabs (left of the combo).
- **Why:** AMG asked for the fixes made after v38.8 to be added to his v38.9 build with the auditor upgrades.
- **Verified:** AC, full suite (including the auditor's v38.9 tests and `test_v389` / `test_v3810` for the About tab, chest button and AMG rename), clip scan still only the 4 known Bag 1-4 checkboxes. Pongmei.au3, ChestFarmCommon.au3, Tasca.au3 and Masterloot.json unchanged.

## v38.9: faster memory reads and bag scans, tracked inventory for extraction (AMG)

- **What** (no in-game behaviour change: same values, same decisions, same order, no timing change; audit items from `AUDIT.md`):
  - Memory primitives (`lib/Utils.au3`): `MemoryRead` uses one struct and returns the bytes read in `@extended` as before; `MemoryReadPtr` reads each hop with `ReadProcessMemory` only (no `VirtualQueryEx` per hop; a failed or zero hop gives the same `[0, 0]` as before); new `ReadDword` (value straight from the DllCall, nothing shared, Adlib-safe).
  - `GetAgentByID`, `GetBag`, `GetItemBySlot`, `GetItemByItemID` read directly; `GetSkillbar` resolves the skillbar array once per call and reads the hero count only when entry 0 is not the wanted bar; `GetEffect` reads the agent-effects array and the effect list in one read each (old entry-by-entry path kept for unusual cases); `GetAgentArray` reuses the struct of rejected agents; `GetItemByAgentID` reads the agent's item directly (verified ID and AgentID, old scan as fallback); `GetItemByFilter` reads the item pointer array once; `GetPartySize` resolves the party chain once.
  - Bag scans: new `GetBagItemsOf` / `GetBagItems` read a bag's item pointers in one read. Used by the read-only scans only (kit/slot/count finders, watchdog signature, Items panel, sort snapshot, Titles tab). Action loops (identify, salvage, sell, store, sort moves) still read each slot fresh right before acting. `FindEmptySlots`, `FindAllEmptySlots`, `FindAllInStorages` fill pre-sized arrays.
  - Extraction pass (`ExtractUpgradesOnly`): bags 1-5 are read once, then tracked by item ID. Before each extraction the bag pointer arrays, the item and the kit are re-read and must match the tracked copy byte for byte. After it, the kit must have lost a use (or be gone), the item must still be there (survived) or be gone (destroyed), exactly one new item (the upgrade) may appear in a slot that was empty, and nothing else may change; then only those slots, the kit and the item are re-read. Anything else (unexpected change, no confirmation, kit gone, destination unknown) re-reads all of bags 1-5 before anything else; three such re-reads in a row before an extraction stop the pass with a warning.
  - `CanUseSkillNow` reads the player agent once; `TryPreemptiveIAU` takes energy from the agent it already read.
  - Items panel custom draw colours cells from the texts the panel last set (no ListView text request per cell per paint).
  - New helper `EnqueueAndWaitConsumed` (not used by any bot yet; `Enqueue` unchanged).
- **Not done** (see `AUDIT.md`, "Implemented in v38.9"): Tools/Sort out of the event handler (item 7), kept-open log handle (item 12), deferred character-dropdown scan (item 17), cross-call pointer-chain caching, and the three timing items 4, 10, 11.
- **Why:** AMG asked for the no-behaviour-change performance fixes from the audit, with strict re-reads around extraction.
- **Benefit (MEASURED, cross-process on the box, old v38.8 vs v38.9):** `MemoryReadPtr` 5 levels 2.7x, `GetMyAgent` 2.1x, `IsRecharged`/`GetSkillbar(0)` 3.4x, `GetEffect` 4.6-5.2x, `GetPartySize` 5x, loot `GetItemByAgentID` ~230x, `GetItemByFilter` ~38x, bag scans 6-8x, extraction pass 3-4x.
- **Verified:** `tools/tests/v389` (old functions from 38b9a5f side by side with the new ones on a fake GW memory layout: memory readers, bag scans, the extraction pass in normal and fallback scenarios, the queue helper, the panel draw text). AC, full suite, clip scan. Pongmei.au3, ChestFarmCommon.au3, Tasca.au3 and Masterloot.json unchanged.

## v38.8: game window title is just the character name (AMG)

- **What:**
  - On attach, `InitializeGameClientForGWA2` sets the Guild Wars window title to the character name only (`Charname II`), not `Guild Wars - Charname II`. If the character name is empty, the title is left unchanged so the window is not blanked.
- **Why:** AMG does not want the window title to say Guild Wars - "character name"; he wants it to be just the character name.
- **Benefit:** The game window title is the character name, which is easier to tell apart when several clients are open.
- **Verified:** Confirmed nothing finds the Guild Wars window by title (`GetWindowHandleForProcess` uses `WinGetProcess`; clients via `ProcessList('gw.exe')`). `test_v388` (new title expression and empty-name guard). AC, full suite. Pongmei.au3, ChestFarmCommon.au3, Tasca.au3 and Masterloot.json unchanged.

## v38.7: Follower reads other players' names correctly (AMG)

- **What:**
  - `GetPlayerName` (lib/GWA2.au3) indexes the player array with 80-byte records instead of 76. The current client's player record is 0x50 bytes (name pointer at +0x28), the stride `GetAgentIDByLoginNumber` already used. With 76 bytes, every login number above 0 read the wrong field: login 1 got the encoded name, higher numbers got non-pointer fields (empty). No other player's name could ever be read, so `FollowerResolveLeaderID` never matched a typed name. That is why AMG saw "no party member is named exactly "Charname"" with Charname in the party. The bot's own name comes from a different address (character select), which is why that one looked fine.
  - The follower log lists the names it actually read. The "not found" warning ends with `Party names read: "Charname" (login 3), "Charname II" (login 5), ..., "Charname V" (login 9, you); 3 hero/henchman skipped`. A found leader logs `Follower: following "Charname" (login 3, agent 50). Party names read: ...`. The warning repeats only when the name or the names read change.
  - Names read are trimmed (outer spaces, stray nulls). Matching is still exact and case-sensitive on the trimmed typed name, with self, heroes and henchmen skipped.
- **Not changed:** `GetPartyPlayerLoginNumber` (unused) still steps the party player array by 4 bytes where the records are 12; it is not used by the follower.
- **Why:** AMG's in-game test on v38.6: typing 'Charname' (and 'Charname II', 'A/pCharname II', 'A/P20 Charname II') never matched.
- **Verified:** `test_v387` (the real `GetPlayerName` + `MemoryReadPtr` read a fake 80-byte player array in the test's own memory; AMG's exact party with 3 heroes and the bot as Charname V; the old 76-byte stride reproduces 'not found'). `test_v384` (now also extracts `FollowerReadPlayerName`) still passes. AC, full suite. Pongmei.au3, ChestFarmCommon.au3, Tasca.au3 and Masterloot.json unchanged.

## v38.6: Sorting Inventory fine-tuning, manual Sort now only (AMG)

- **What:**
  - **Manual only.** Sorting runs only when a **Sort now** button is pressed (Tools > Sorting Inventory, or the Storage Setup page). The 'After store in the town pass' and 'On run start' options, their checkboxes, their `after_store` / `on_run_start` layout keys, and both hooks in `InventoryManagementBeforeRun` are removed. Old layouts that still have those keys load normally, and the keys are ignored and not saved back. The town pass no longer calls the sorter at all.
  - **Strict pane order.** The sort goes pane by pane: I, II, … XIII, Anniversary, then Material storage. In each pane it first moves out what doesn't belong (to the bags), then fills it, then re-groups it fully. Only after that does it start on the next pane. Overflow ('If full = Next empty pane') waits for the receiving pane's turn instead of being written ahead. Every pane is re-grouped even if nothing new arrived. If a pane can't be finished (no free slot to re-group), the sort stops instead of moving on.
  - **One move at a time, at least 0.66 s apart.** Every item move in Sort now (empty, fill, re-group, material deposit) and in Tools > Empty Tab goes through one shared gate. It waits until 660 ms have passed since the previous move, sends one move, then waits until the game shows the item has arrived (or 3 s pass) before anything else happens. Before each planned move, the sorter checks that the slots still hold what the plan expects. If they don't, or a move isn't confirmed, it stops with a warning (a full material slot is the exception: it is skipped and the sort carries on).
  - **New Minipets type** (Storage Setup checklist, 16th box), recognised by the game's item type 34 (`$ID_TYPE_MINIPET`).
  - **Festival items** now include all 12 Lunar Fortunes (Pig … Dog, every year) and Lunar Tokens. Lunar Fortune (Horse) used to sort as Consumables. **Consumables** now include Bird's Eye Compass and Stalker's Ration.
  - **Material storage** is always Materials + Rare materials (locked checkboxes, 'Mats + rare (auto)'). Materials are deposited from bags 1-4 into their fixed material slot, one confirmed move at a time. There is no verified GWA2 trigger for the game's **Deposit All Materials** button, so it isn't used. Counts above 255 in material storage are read correctly.
- **Why:** AMG asked for pane-by-pane sorting, no move faster than 0.66 s, minipets / Lunars / compasses / rations included, Material storage set automatically, and (t196u) no automatic sort.
- **Benefit:** Sorting is predictable and never runs inside a farm's town pass. Tasca, Pongmei and every other farm are unaffected.
- **Verified:** `test_v386` (strict pane order with a mocked Xunlai storage, 660 ms gap and one-move-in-flight on Sort now / re-group / material deposit / Empty Tab with a mocked clock and game latency, unconfirmed-move stop, full material slot, locked panes, classification, preset, legacy keys ignored, manual-only). `test_v38` updated for manual-only. AC, full suite, clip scan. Tasca.au3, Pongmei.au3, ChestFarmCommon.au3 and Masterloot.json unchanged.

## v38.5: Tools Convert Gold to Lockpicks pays 1,200g at the Factions discount merchant (AMG)

- **What:**
  - The Tools tab **Convert Gold to Lockpicks** button still talks to the nearest merchant (or the mapped Eye of the North / Embark Beach merchant), and still travels to Eye of the North when that NPC does not sell lockpicks.
  - It finds lockpicks by the only model ID in this repo (`$ID_LOCKPICK` = 22751). If that model is not in the list, it logs every merchant item's model ID (and name, when it can be decoded) and will buy a slot whose name is exactly "Lockpick".
  - GWA2 has no merchant-buy-price API. If the merchant item's Value is exactly 1,200 or 1,500, that is used as the unit price. Otherwise the tool tries 1,500g and, if that buy is not confirmed, retries the **same** merchant at 1,200g (the Factions alliance-owned town price). The price that works is remembered for the rest of the run. Batch size is `Min(80, room, remaining requested, floor(carried gold / that price))` and the gold sent never exceeds carried gold.
  - Log lines include the NPC id and model, item position, model ID, price tried, and the result.
  - Inventory **Buy items > Lockpicks**, `BuyLockpicksInTown`, `BuyInTown`, the town pass, Tasca, Pongmei, ChestFarmCommon and the GUI layout are unchanged.
- **Why:** AMG reported that the Tools button was not buying lockpicks from the Factions discount vendor at 1,200g. The previous tool always sent 1,500g per pick; the server rejects a buy whose gold amount does not match the merchant's price.
- **Verified:** `test_v385` (mocked merchant: 1,500 accepted; 1,200 only accepted, including a retry then remembered price; discount-vendor list and name-fallback model; not stocked so it travels to Eye of the North; gold limits; batch math; three rejected prices stop cleanly). AC, full suite including `test_v383` and `test_v384`, clip scan. Protected files unchanged.

## v38.4: Follower tab Start button and exact leader-name matching (AMG)

- **What:**
  - Follower tab: a **Start Follower** button (150x24, under the options) with the note "Runs the Follower farm. Pause here or with the main button." It selects the Follower farm in the farm combo and presses the main Start (`GuiStartButtonHandler`), so attach, run state, cache invalidation and Pause / Will pause are exactly the Main tab's. The tab button mirrors the main button: Start Follower / Pause / Will pause after this run, and is disabled while another farm runs. The Main tab Start, farm combo and options are unchanged.
  - `FollowerResolveLeaderID`: the typed name is trimmed and compared with each other player's real name from `GetPlayerName()`, exact and case-sensitive (never a substring). The agent struct has no `Name` field, so the old `StringInStr` check never matched and the bot always followed the first other player in party order. The bot's own character and heroes/henchmen are skipped. A typed name that is not in the party returns no leader (the loop waits; one warning per name) instead of following someone else. A blank name keeps the old fallback.
  - `FollowerLoop` drops a stale `$leaderID` when its agent is gone, when that agent's name no longer matches the typed name, or when the typed name changes, so a mid-run name change takes effect on the next loop.
  - `BonderFollowerLoop` resets `$leaderID` on map change, as `FollowerLoop` does.
- **Still broken (not approved, unchanged):** the Bonder Mode combo (saved, but nothing reads it to pick a bonder mode) and the leader TargetID option ("Follow leader target calls": the agent struct has no `TargetID` field, so it always falls back to the nearest enemy).
- **Why:** AMG approved this job: with the main 'Charname' and alts 'Charname Il', 'Charname Ill', 'Charname I V', 'Charname V', the follower could not be pointed at a named character.
- **Verified:** `test_v384` (real `FollowerResolveLeaderID`, `FollowerLoop`, `BonderFollowerLoop` and the real Start handlers on a mocked party: every Charname bot x every typed name, case differences, substrings, spaces/tabs, self-skip, not found, blank fallback, mid-run name change, stale/gone leader, map change; Start/Pause from the tab, from the Main tab, and with another farm). AC, full suite including `test_v383`, clip scan. Pongmei.au3, ChestFarmCommon.au3, Tasca.au3, Masterloot.json, extract/town-pass code and `FillInventoryCacheFromJSON` unchanged.

## v38.3: Inventory tree fills in branches when opened (AMG)

- **What:**
  - `BuildTreeViewFromCache` builds a model of the whole Inventory tree from the loot cache (same nodes, same order, same ticks as the v38.2 full build) but creates only the top-level branches. A branch's children are created the first time it is expanded (`TVN_ITEMEXPANDING` in `WM_NOTIFY_Handler`).
  - Ticks of nodes not created yet live in the model. A parent tick or untick (click or space) sets every descendant, created or not; the upward tri-state (`ToggleCheckboxCascadeUpwards`) is unchanged.
  - Save, Apply and the live extract / store-protection reads walk the model, so they see every node exactly as before. Expand all creates every node first, then expands.
  - The v38.2 in-place Load (same structure: checkmarks only) and the cache invalidation on Load, Apply, every tick change and Start are kept. `FillInventoryCacheFromJSON`, the extract logic and its rescans, the derived flags and Masterloot.json are unchanged.
- **Why:** AMG approved only this: build the main branches at startup and fill each sub-branch the first time it is opened, with every option, tick and Masterloot unchanged.
- **Benefit:** Startup and Load no longer create ~4,600 tree items.
- **Verified:** `test_v383` (every shipped loot file; nodes unexpanded, partly and fully expanded; parent ticks into unexpanded children; Save JSON byte-identical to v38.2; Apply cache and derived flags, extract leaf sets and store protection identical; Save/Load round trips; real expand by message, by another process and by mouse). `test_v372` / `test_v382` adjusted for the lazy tree. AC, full suite, clip scan. Pongmei.au3, ChestFarmCommon.au3, Tasca.au3 and Masterloot.json unchanged.

## v38.2: Faster extract-leaf cache, store-protection cache, leaf fill, and Load checkmarks (AMG)

- **What:**
  - The extract-leaf cache is no longer cleared in `RunFarmLoop`, `InventoryManagementBeforeRun`, or on each looped town pass. It is still cleared on Load, Apply, any Inventory tree tick change, and the Start button press.
  - `BuildStoreProtectionCache` reuses its snapshot until those same invalidation points, so a looped extract pass no longer walks the live Inventory tree every time.
  - Cold `GetCheckedUpgradeLeaves` detects leaves in one pass (parent-prefix has-child map) instead of O(n^2). The checked-leaf set, leaf order, and branch size stay identical.
  - `BuildTreeViewFromCache` / Load updates only checkmarks when the tree structure already matches the cache, and falls back to a full rebuild when it differs. `FillInventoryCacheFromJSON` is unchanged.
- **Why:** AMG approved audit items 1-4 only, as v38.2, with Extract Components behaviour identical (including the per-extraction rescans of the kit, free slots, surviving item, and bags).
- **Benefit:** Looped town passes keep a warm extract-leaf and store-protection cache; a cold leaf fill and a same-structure Load are faster.
- **Verified:** `test_v382` (leaf sets vs the previous O(n^2) walk, store-protection decisions and reuse-until-invalidate, in-place tree ticks vs a full rebuild, cache invalidation on every tick-change path). Existing extract tests including `test_v372`, `test_manual_extract`, `test_v371`, `test_extract_flow`. AC, full suite, clip scan. Pongmei.au3, ChestFarmCommon.au3, Tasca.au3, and Masterloot.json unchanged.

## v38.1: Tasca returns to the Citadel by resign, not map travel (AMG)

- **What:**
  - Before the portal walk in `GoToTascasDemise` (and before setup's walk-out), the bot confirms the character is in the Granite Citadel outpost and fully loaded. The previous `RobustTravelToOutpost` result was ignored. If the character is still in Tasca's Demise or any explorable, it uses `RobustResignAndReturnToOutpost` (up to 3 tries) instead of map-traveling, then re-checks.
  - `$tasca_farm_setup` is set True only after the Citadel is confirmed loaded following setup's walk-out.
  - If the stuck watchdog recovers, or a map-load failure happens, while the Tasca farm is running in an explorable, Tasca resigns back to the Citadel rather than map-traveling. Every other farm keeps its current recovery (map travel) exactly.
  - If resign fails all 3 times, map travel to the Citadel is used only as a last resort. Any such map travel during the Tasca farm sets `$tasca_farm_setup = False` so the next run redoes the setup walk (out to Tasca's Demise and back into the Citadel) to re-establish the quick exit, and that run ends as `$FAIL`.
  - The route, chest logic, and the success rule (end of route alive = SUCCESS, decided before the resign) are unchanged.
- **Why:** AMG approved this Tasca-only change so a stuck or unloading character returns through resign (keeping the Citadel portal shortcut) instead of map-traveling.
- **Benefit:** Tasca recovery no longer throws away the setup walk except when resign really fails; other farms are untouched.
- **Verified:** `test_tasca_recovery` (already in the Citadel, stuck in Tasca's Demise, resign succeeds, resign fails 3× then last-resort travel plus setup reset, watchdog recovery for Tasca vs Vaettirs). Existing `test_watchdog` still covers non-Tasca map-back. AC, full suite, clip scan. Pongmei.au3, ChestFarmCommon.au3, Masterloot, and loot files unchanged.

## v38: Sorting Inventory and Storage Setup (AMG)

- **What:**
  - Tools tab gains a *Sorting Inventory* section with **Setup** and **Sort now**. Setup opens a hidden Storage Setup page (not in the tab row) with a Back button. The page lists Xunlai panes I–XIII, Anniversary and Material storage. Scan storage reads which panes are unlocked (locked panes are grayed `N/A (locked)`; unscanned panes read `not scanned yet`).
  - Each pane has a checklist of item types (Materials, Rare materials, Runes, Insignias, Mods, Inscriptions, Trophies, Tomes as one box, Dyes, Festival items, Golds, Purples, Keys, Consumables, Salvage/ID kits). A pane can mix types. The same type ticked on several panes fills them in list order. Inside a pane, items are grouped by type in checklist order, with the Order rule applied within each type. Adding items re-groups that pane so new items sit with their type; panes that did not change or are already in order are left alone.
  - Fill-order summary, If full (next empty pane or leave in bags), bags to sort, reserved bag slots for kits/consumables, sort rules (order, merge stacks, compact slots). Load / Save / Apply store JSON in `conf/storage`. New-user defaults are all unticked / empty.
  - **Sort now** (Tools and Storage Setup) runs the sort in an outpost or town only, one pane at a time: evict items that do not belong, then fill from the bags and other panes, until assigned items are placed. Unassigned types stay in the bags. If the bags fill mid-sort, carried items go to their correct panes first; if there is truly no space, the sort stops and logs what could not be placed (it will not loop forever).
  - Optional **After store in the town pass** (off by default) runs the same sort in `InventoryManagementBeforeRun` immediately after the store-general step. Optional **On run start** (also off by default) runs it at the start of that function. When both are unticked, the town pass is unchanged aside from two no-op flag checks. The existing Setup "Sort items" bag sort is untouched.
- **Why:** AMG approved the Storage Setup mockup and asked for pane-based sorting with a Sort now button, optional after-store auto sort, and type grouping inside a pane.
- **Benefit:** Xunlai storage can be organized from a saved layout without changing farm behavior until you tick After store or press Sort now.
- **Verified:** `test_v38` (mixed-pane fill order, overflow, locked panes, full bags, reserved slots, unassigned items stay in bags, type grouping and skip-if-in-order / unchanged, JSON round-trip, after-store and on-run-start default off, hook placement and MidRun / SortInventory unchanged). AC, full suite, clip scan. Farm run scripts and loot files unchanged.

## v37: Manually extract selected components (AMG)

- **What:**
  - The Tools-tab button is renamed **"Manually extract selected components"** (wider so the caption is not clipped). It still calls `ExtractUpgradesOnly()` with no arguments: it is **not** gated by the Setup "Extract selected components before selling" checkbox. That checkbox only starts automatic extraction in the town / inventory-full pass (and that pass can buy an Expert kit). The manual button does not buy a kit and does not sell or salvage.
  - `LoadExtractUpgradeDefinitions` now also accepts leftover `'Extract upgrades only'` ticks if a cache was not migrated (the loader already renames that root at load). AMG Loot.json / Loot.json / Sin Tasca's ChestRun.json were not edited; they still use the old root on disk and migrate when loaded.
- **Why:** AMG reported the Tools extract as broken and asked for the new name, and for it to work without the Setup checkbox.
- **Benefit:** The button is clearly named, and the manual path is locked by tests against Masterloot and AMG Loot with the checkbox on or off. Store-protected items stay skipped.
- **Verified:** `test_manual_extract` (loaded ticks, checkbox independence, unprotected axe extracted, Gold Req 8 axe and gold armor skipped, no sell/salvage/kit-buy). Tick-preservation of the four existing loot configs plus Masterloot unchanged. Farm run scripts unchanged. AC, full suite, clip scan.


## v37.1: Gold weapon extract exemptions; armor runes extract then store (AMG)

- **What:**
  - Extraction now skips v27 old-school auto-keep weapons (requirement 9 with inherent Energy +5; wand or focus at requirement 9 or 10 with a halves-casting + halves-recharge pair). They are kept whole, not extracted.
  - In Masterloot.json only, Store items > Armor salvageables > Purple and Gold are unticked (exactly those two leaves). Gold Req 8 weapons of every type and gold shields of every requirement stay Store-ticked. Purple and gold armor salvageables can now have their ticked runes and insignias extracted; the loose components are stored via Store items > Components. Leftover armor is sold (Salvage items > Armor salvageables is unticked, so Salvage into materials does not salvage them).
- **Why:** AMG wants Req 8 gold items and all gold shields stored, other gold weapons (except those exemptions and OS auto-keep) extracted when a ticked perfect mod is present, and purple/gold armor runes extracted then stored as components.
- **Benefit:** Extraction and storage follow that rule on both the manual Tools button and the automatic town pass.
- **Verified:** `test_v371` (Masterloot only: Req 8 gold weapons, gold shields, OS auto-keep wand/offhand, perfect vs non-perfect mods, gold/purple armor runes, leftover armor sold). `test_manual_extract` updated for the armor Store change. Farm run scripts unchanged. AC, full suite, clip scan.


## v37.3: Inventory tree starts fully collapsed (AMG)

- **What:** The Inventory tab tree no longer auto-expands *Store items* and *Store items > Components* at startup or after Load. Only the top-level branches are shown. *Expand all* / *Reduce all* are unchanged.
- **Why:** AMG asked for a fully collapsed tree on open and after Load.
- **Benefit:** A large configuration is easier to scan from the top-level branches without Store items already opened.
- **Verified:** Ticks, Load/Apply, and extraction are unchanged. Farm run scripts and all loot files unchanged. AC, full suite, clip scan.

## v37.2: Faster Inventory tree Load and cached extract-leaf scan (AMG)

- **What:**
  - Inventory tree Load still uses `GUICtrlCreateTreeViewItem` (so `GUICtrlSetState` and the dark-theme branch colours keep working). Redraw is batched with `_GUICtrlTreeView_BeginUpdate` / `EndUpdate`. Control IDs from the previous tree are `GUICtrlDelete`d before a rebuild, so repeated Load no longer leaks IDs.
  - `GetCheckedUpgradeLeaves` caches the Inventory tree walk (or the loaded configuration when there is no GUI). The cache is dropped on Load, on Apply, on any Inventory tree checkbox change, and at run start, so tick changes take effect as before.
- **Why:** AMG approved these two speed-ups if Extract Components stays equivalent and the risk of a break is close to zero.
- **Benefit:** Loading a large configuration (Masterloot) redraws the tree once instead of per item, Load can be clicked repeatedly without running out of control IDs, and extract no longer re-walks the whole tree on every leaf-list read in the same pass.
- **Verified:** `test_v372` (old vs new checked-leaf sets and extraction candidate decisions are identical on Masterloot and several in-memory tick sets; load and scan timings; control IDs do not grow on a second Load). Existing extract tests including `test_manual_extract` and `test_v371`. Farm run scripts and all loot files unchanged. AC, full suite, clip scan.

