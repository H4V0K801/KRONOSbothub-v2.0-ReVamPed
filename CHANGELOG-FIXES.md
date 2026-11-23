# CHANGELOG-FIXES.md

## v3 audit (release-grade) — 2026-11-08 America/Denver

### Tooling
- Installed portable Wine 9.22 amd64-wow64 (Kron4ek) — apt wine packages unavailable (Debian mirror 500).
- Downloaded official AutoIt v3.3.18.0 zip; ran `wine Au3Check.exe -q -d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6 -w 7 -I Include BotsHub.au3`.
- Standalone `src/**/*.au3` Au3Check under Wine fails on relative `../../lib/...` includes (Wine path resolution); **authoritative check is the main BotsHub.au3 entry** (how the bot actually loads).

### Audit passes
| Pass | Au3Check errors | Notes |
|------|-----------------|-------|
| 1 (baseline) | 37 | Map `$var[] = Func()` Au3Check parser limits; EnterTheDeep If/Else; LuxonSilentSurf comma; TrackGroupStatus; Debugger SetData arity; IsTrophyBis; SalvageItemAt; ARRAY_STUFF |
| 2 (after structural + map rewrites) | **0** | 341 warnings (mostly include-order / Local-in-global-scope style) |
| 3 (Follower/Ecto/cache defaults) | **0** | 341 warnings |
| 4 (semantic: dups, invented helpers, farm map, events, cache keys) | n/a | 0 duplicate Funcs; farm map↔combo↔descriptions aligned (56); all GUICtrlSetOnEvent targets exist; no GetInventory() leftover |
| 5 | **0** | Same as pass 3 |
| 6 (final) | **0** | Identical to pass 5 — **no new issues** |

### Critical fixes (user-facing crashes / Tools)
- `src/utilities/EctoToGold.au3`: `GetInventoryGold()` → `GetGoldCharacter()` (already present); **SellEctoToTrader** no longer passes a bag **slot index** into `SellItem` — uses `GetItemBySlot` + `SellItemToTrader($item, 1)`; opens nearest NPC before selling; lockpick path opens nearest merchant first.
- `lib/Utils.au3` `EnterTheDeep`: fixed broken If/ElseIf/Else nesting (scroll-failure `Else` was a sibling of the outer `Else` → syntax/runtime break).
- `src/vanquishes/LuxonSilentSurf.au3` ~L130: missing comma in waypoint row `[-700, 10200 ' ']` → `[-700, 10200, ' ']`.
- `src/vanquishes/Asuran.au3`: `AdlibRegister('TrackGroupStatus')` → `TrackPartyStatus` (real helper in Utils-Agents).
- `lib/Utils-Debugger.au3` `SafeDllStructSetData`: added required `$value` (DllStructSetData needs 3 args).
- `lib/Utils-Storage.au3` `IsTrophyBis($itemID)` used `$item` → param renamed `$item`.
- `lib/Utils-Storage.au3` `SalvageItemAt`: undeclared `$salvageKit` → `GetSalvageKit(False)`.
- `lib/Utils-Storage.au3` `FindAllEmptySlots`: `Local $bagEmptySlots[] = FindEmptySlots(...)` → assign without `[]` (Au3Check + clearer).
- `lib/BotsHub-GUI.au3`: declare empty `$ARRAY_STUFF` for unused `OpenPickWindow`.

### Au3Check map syntax (behavior-preserving)
Au3Check cannot parse `$name[] = MapFromArrays(...)` / `$name[] = SomeFunc()`. Rewrote to:
```
Global|Local $name[]
$name = MapFromArrays(...)
```
in `lib/GWA2_ID_Items.au3`, `lib/GWA2_ID.au3`, `lib/Utils-Items_Modstructs.au3` (dropped redundant `Const` on those maps only).

### Tools / Follower end-to-end
- `src/utilities/Follower.au3`: GUI wrote `follower.leader_target` but loop read `follower.follow_leader_target` — now accepts both; wires `follower.perma_sf` via new `FollowerMaintainShadowForm()`; leash from `follower.leash` used in abort range check.
- `BotsHub.au3`: default `$run_options_cache` now includes `run.loop_mode`, `run.hard_mode`, `run.weapon_slot`, follower/* keys, `run.skip_am_fah`, Tools-related flags (prevents Null-key surprises before first GUI event / JSON load).

### Intentionally unchanged / unverifiable without game
- Memory offsets, packet headers, assembly scanners in GWA2/GWA2_Assembly.
- Hero combat / flagging behavior in live maps.
- SQLite runtime against live DB.
- Warnings (341): include-order “possibly used before declaration”, Local-in-global-scope in ID tables, Dim-style style nits — not launch blockers under MustDeclareVars when loaded via BotsHub.

---

Fixes applied for GUI redesign + systematic static debugging (AutoIt x86 Bot Hub).
Au3Check was **not** run (AutoIt/Wine not available on this Linux box); verification was static analysis + coordinate overlap checks.

## TASK 1 — GUI redesign (`lib/BotsHub-GUI.au3`)

| Location | Change | Reason |
|---|---|---|
| CreateBotsHubGUI ~L174 | `$gui_label_status` moved from `(490,445)` to `(490,448)`; tab height `450`→`435` | Status label floated inside tab content and overlapped Options/Farm infos |
| Options Inventory group | Re-spaced inventory-only controls; removed non-inventory checkboxes from this group | New checkboxes (Extract upgrades / Log chests / Auto-attach / Return on death) were drawn on top of Salvage during run / kits / scrolls / collect data |
| Options Other options group | Hosts Log chest spawns, Auto-attach, Return on death; Open Storage + Rendering side-by-side; group height tightened so Manual mode sits below | Clean column layout; Manual label was never created (`$gui_label_manualmode` tipped but undeclared) |
| Options Manual mode | Added `$gui_label_manualmode = GUICtrlCreateLabel('Manual:', …)` + repositioned input/Run | Missing label declaration + overlap with Other options |
| Follower tab | Group wrapper; name label+input on one row; Leash + Bonder on next row; checkboxes on one row | Label "Follow party member…" overlapped Leash range label/input at y~150 |
| Tools tab | Wider groups; evenly spaced Attach / Extract / Reset buttons | Consistency with redesigned tabs |
| Inventory treeview | Height `400`→`380`; Main console `255`→`240`; Titles group `111`→`100` | Fit inside shortened tab |
| Farm infos | `$gui_label_farminformations` height `450`→`250` | Overflowed past window bottom |
| Overlap verification | Programmatic bounding-box pass after redesign | Options/Follower/Tools/Main/Farm infos/Team/Inventory: **0** meaningful overlaps (excluding intentional label↔value / Team Load-Build↔input adjacency) |

Mockups: `/workspace/gui-mockups/*_before.png` and `*_after.png`.

## TASK 2 — Systematic debugging

### Priority runtime fix — farm map subscript (user-reported)

| File:line | Change | Reason |
|---|---|---|
| `BotsHub.au3` `IsKnownFarm()` | New helper: rejects Null/''/`Choose a farm`; requires `MapExists($farm_map, $name)` | `$farm_map[$farm_name]` returned non-accessible when key missing → crash on `$farm[2]` |
| `BotsHub.au3` `BotHubLoop` | Validate with `IsKnownFarm` before `RunFarmLoop`; clear Error message; re-enable Start + combos; `ContinueLoop` (GUI) / `Exit 1` (headless) | Previous check only Null/'' — missed placeholder, typos, free-typed combo text, bad config farms |
| `BotsHub.au3` `RunFarmLoop` | Guard `MapExists` + `IsArray($farm)` **before** `$farm[2]` | Direct cause of `Subscript used on non-accessible variable` at line ~284 |
| `BotsHub.au3` HEADLESS path | Validate farm after reading `$cmdLine[4]` | Same crash path without GUI |
| `lib/BotsHub-GUI.au3` `GuiStartButtonHandler` | Refresh `$farm_name` from combo on Start / resume from pause | Ensures validation sees current combo value |
| Farm combo style | **Kept** `CBS_DROPDOWN` | Autocomplete (`_GUICtrlComboBox_AutoComplete` on `CBN_EDITCHANGE`) needs editable combo; validation covers bad free text |
| `conf/farm/Bog Chest Run Assassin.json` | `"farm": "Bog"` → `"Tasca"` | No farm named Bog in map; config uses same character + `Sin Tasca's ChestRun` loot as Tasca chest runner — remapped to **Tasca**. (README "Bogroot"→Froggy is the dungeon farm, not this chest-run config.) |

#### conf/farm audit (`main.farm` vs `$farm_map` keys)

| Config | farm value | In map? |
|---|---|---|
| Bog Chest Run Assassin.json | Tasca (was Bog) | Yes |
| Custom.json | LDOA | Yes |
| Default Farm Configuration.json | Choose a farm | No (placeholder — now blocked by `IsKnownFarm`) |
| Magmas Run.json | MagmasRun | Yes |
| Norn.json | Norn | Yes |
| Pongmei Lovely Hands.json | Pongmei | Yes |
| Pongmei.json | Pongmei | Yes |
| Rain Stick's.json | MagmasRun | Yes |
| Tasca's Chest Runner.json | Tasca | Yes |

### Missing functions (were commented out or never defined)

| File:line | Change | Reason |
|---|---|---|
| `lib/Utils.au3` | Uncommented `UseHeroSkillEx`, `UseHeroSkillTimed`, `FlagMoveAggroAndKill`, `FlagMoveAggroAndKillInRange` | Called widely from FoW/UW/SoO/Froggy/Deldrimor/DrakeFlesh/Skrees/Zodiac/Kournans/GemstoneMargonite but definitions were commented out → load-time unknown-function errors when those farms run |
| `lib/Utils.au3` | `$flag_move_aggro_kill_options['flagHeroesOnFight'] = True` | Flag* wrappers were identical to non-flag (both False); comment says they flag heroes |
| `lib/Utils.au3` | Added `AllHeroesUseSkill` | Called from `Lightbringer-Sunspear.au3` `SpeedTeam` |
| `src/runs/MagmasRun.au3` | Added `AreFoesInFront` | Called from `MagmasDefendFunction`; undefined |
| `src/utilities/BonderFollower.au3` | Added `MonkBonderFarm` / `EleMonkUWBonderFarm` wrappers | Farm map pointed both entries at `BonderFollowerFarm` with no args → EleMonk always ran as monk default |
| `BotsHub.au3` `FillFarmMap` | Monk/EleMonk entries call the new wrappers | Correct mode dispatch |

### Wrong / broken APIs

| File:line | Change | Reason |
|---|---|---|
| `lib/Utils-Storage.au3` `ExtractUpgradesOnly` | Rewrite loop with `GetBag`/`GetItemBySlot`/`$bags_count` | Called nonexistent `GetBags()`/`GetItems()` |
| `src/utilities/EctoToGold.au3` | `GetInventoryGold`→`GetGoldCharacter()`; `GetStorageGold`→`GetGoldStorage()` | Called nonexistent `GetInventory()`/`GetStorage()` (and would recurse oddly via wrappers) |
| `src/utilities/BonderModes.au3` | `GetHasEffect`→`GetEffect(...) == Null`; recharge via `IsRecharged`; skill ID uses 1-based slot | Nonexistent helpers; slot indexing mismatch with `UseSkill` |
| `src/missions/MinisterialCommendations.au3` | `$ID_Kaineng_Center`→`$ID_KAINENG_CENTER` | Canonical constant name (AutoIt is case-insensitive; clarity) |

### Farm description / includes

| File | Change | Reason |
|---|---|---|
| `lib/BotsHub-GUI.au3` `UpdateFarmDescription` | Case `Omnifarm`→`OmniFarm`; added MagmasRun, Monk Bonder, EleMonk UW Bonder | Dropdown names didn't match Case (OmniFarm) or had no Case |
| `lib/BotsHub-GUI.au3` | `#include BonderFollower.au3` | Needed for bonder skillbar constants in Farm infos |
| `lib/BotsHub-GUI.au3` `GuiOptionsHandler` | Cases for extract/logchests/autoattach/returnondeath/follower controls; Case Else no longer MsgBox | New checkboxes hit Case Else → "not coded yet" MsgBox; options weren't saved to `$run_options_cache` |

### Earlier startup fixes (still present from prior pass)

- Removed duplicate `GuiToolsTabButtonHandler` / `WriteRunSummary` from `BotsHub.au3`
- Global declarations for Tools/Follower GUI vars; Tools Attach/Extract/Reset buttons
- `$ID_LIONS_ARCH_CANTHANS_NEW_YEAR` typo; `$l_s_OpCode`→`$opCode`; `$ID_ECTOPLASM`→`$ID_GLOB_OF_ECTOPLASM`
- Removed helpers calling nonexistent functions; commented dead `Extend_*` calls
- `#AutoIt3Wrapper_UseX64=n` on `BotsHub.au3`

### Block / duplicate / arity

- Duplicate functions after fixes: **0**
- Block balance (If/While/For/Switch/Func): **0** issues found
- Arity mismatches vs definitions: **0** (static)

## Not verifiable without the game / notes

- GWA2 memory offsets, packet headers, detours, skill cast timing heuristics — **not changed** beyond uncommenting existing wrappers
- `FlagMoveAggroAndKill*` behavior depends on `flagHeroesOnFight` + live hero flagging; set True to match comments — confirm in-game vs heavy AoE maps
- `ExtractUpgradesOnly` salvage modes (`Prefix`/`Suffix`/`Inscription`) assume `SalvageItem` supports those strings — verify against live salvage UI
- `OpenPickWindow` still references undefined `$ARRAY_STUFF` inside marked dead-code region — left alone (nothing calls it)
- Runtime logs under `@ScriptDir/logs/*` and `data/items_database.db3` are created at runtime — missing at rest is expected
- Default Farm Configuration intentionally keeps `farm: Choose a farm` (placeholder); Start now errors clearly instead of crashing
- Autocomplete on farm combo requires `CBS_DROPDOWN`; do not switch to `CBS_DROPDOWNLIST` without rewriting the edit-change autocomplete handler
- BonderModes.au3 is mostly superseded by BonderFollower.au3 but was still repaired for consistency if included later

### v3 final check (additional)
- lib/Utils-Storage.au3 TableExists: used undeclared `$lastBatchID` (runtime crash under MustDeclareVars); now uses a Local and returns True/False.
- lib/GWA2.au3 ~504: `$buffStructAddress` assigned without declaration (runtime crash when reading hero buffs); now `Local`.
- Cross-checked all 169 Au3Check "possibly not declared / used before declaration" warnings against Global/Local declarations: remaining ones are globals declared later in include order (safe at runtime).

## v4 - Tools tab: Ecto seller, Lockpick buyer, Extract upgrades (expert/superior salvage)

All three tools now work strictly one step at a time: one item, one request, a ping-aware wait, a confirmation, then the next step. They never batch items or reuse a session.

### Root causes found
1. **Ecto seller and lockpick buyer never ran (confirmed from the code).** Both loops were `While $runtime_status == 'RUNNING'`. From the Tools tab the status is `UNINITIALIZED`/`INITIALIZED`, so the loop body never ran. The tool just logged "Conversion complete. Sold 0".
2. **Ecto seller:** `SellItemToTrader($item, 1)` (lib/GWA2.au3) ignores `$quantity`. It loops over the whole stack, firing quote and sell requests 50 ms apart with no gold-cap check. `IsStorageFull()` deposited 1000 gold on every iteration and reported "storage full" whenever the deposit took longer than 300 ms. The tool also talked to the *nearest* NPC, which may not be the trader.
3. **Lockpick buyer:** bought `Int(gold / 1000)` lockpicks at 1500 each, so the server rejects the purchase as too expensive. `BuyInTown` then retried 10 times, and the outer loop repeated with unchanged gold (a possible endless loop). The merchant position was hard-coded (11, EotN only).
4. **Extract upgrades (crash / "error 7"):** `ExtractUpgradesOnly()` (lib/Utils-Storage.au3):
   - It started an expert-salvage session on **every** item in bags 1-4, including the salvage kit itself, ID kits, ectos, materials and consumables.
   - It then ran 3 back-to-back sessions (Prefix, Suffix, Inscription) on the **same stale item struct**. The game destroys an item when one upgrade is salvaged, so sessions 2 and 3 targeted a deleted item ID.
   - It never cancelled or ended sessions.
   - `FindKit()` searched bags 1-16, which includes material storage and the Xunlai chest, so the "kit" could be one that cannot be used.
   - `SalvageItem`/`StartSalvageWithKit` had unbounded `While` loops.

   Invalid item or kit IDs passed to the injected salvage call are the most likely cause of the client crash. Unexpected salvage packets are the most likely cause of the disconnect "Code 007" (error 7). These two causes are inferred, not reproduced: the headers (0x77-0x7B), the `CommandSalvage` assembly and the scan patterns are byte-identical to upstream caustic-kronos/BotsHub (commit 02e2689).

### Fixes
- `src/utilities/EctoToGold.au3`: fully rewritten.
  - Shared helpers: `ToolsOpenNPC`, which uses known coordinates in EotN and Embark Beach and the nearest NPC elsewhere; `ToolsDepositGold` and `ToolsWithdrawGold`, which confirm the gold change; `ToolsWaitForItemCountChange`.
  - `ConvertEctosToGold`: preflight label check, then one quote (`TraderRequestSell`), then a 100k-cap check that deposits first, then one `TraderSell`, then confirmation (ecto count down or gold up), then the next ecto. It gives up after 3 failed attempts, travelling once to the EotN trader in between.
  - `ConvertGoldToLockpicks`: finds the lockpick by **model ID 22751** in the open merchant's list. If the nearby NPC doesn't sell lockpicks, it falls back to the EotN merchant, and to position 11 only as an unverified fallback. It buys **1 lockpick per call**, confirms the count went up, withdraws storage gold when carried gold is under 1500, and stops when funds run out, the inventory is full, or 3 purchases go unconfirmed.
- `lib/GWA2.au3`: new functions `TraderRequestSell` (clears the stale quote, then a bounded wait for a quote on *this* item ID), `TraderSell`, `IsValidLabelAddress`, `GetMerchantItemPositionByModelID` and `GetSalvageSessionAddress`. `StartSalvageWithKit` retries are now bounded (20).
- `lib/Utils-Storage.au3`:
  - `FindKit` now searches only bags 1-5.
  - The `SalvageItem` start loop is now bounded.
  - `ExtractUpgradesOnly` was rewritten with the new functions `ExtractUpgradesPreflight`, `FindNextUpgradeExtractionCandidate`, `ExtractOneUpgradeFromItem`, `WaitForUpgradeExtraction` and `ExtractItemStillPresent`. The sequence:
    - Preflight: the `CommandSalvage`, `Salvage` and `SalvageGlobal` addresses and the session pointer must be non-zero, otherwise it aborts.
    - Before every salvage it re-reads the kit, requires 1 free slot, and re-scans the inventory for ONE eligible item: an identified blue/purple/gold weapon, armor or salvageable that is not equipped, not customized and not the kit.
    - For component index 0, then 1, then 2: start ONE session, wait 800 ms plus ping, send `SalvageMod(index)`, then wait for the item to disappear, its modstruct to change or the kit's uses to drop. If none of that happens, `CancelSalvage()` and try the next index.
    - If no index works, the item is skipped. Every step is logged with an `[Extract]` prefix.
- Au3Check: 0 errors, 44 warnings (same set as v3; all are pre-existing include-order "possibly used before declaration" notes).

## v5 - Extract upgrades only: extracts ONLY the checked runes, insignias, mods and inscriptions

### What changed
- **New Inventory tree branch `Extract upgrades only`.** It was added to all 3 configs in `conf/loot/*.json` as an exact mirror of `Keep components`:
  - Armor upgrades (per profession, Insignias and Runes)
  - Inscriptions (root, Weapon, Weapon.Martial, Weapon.Spellcasting, Offhand, Offhand.Focus)
  - Mods (per weapon type, Prefix and Suffix groups)

  That is 534 leaves, all unchecked by default. The rest of each file is unchanged, as verified by a JSON diff. If a loaded config has no such branch, the tool warns and uses the `Keep components` selection instead.
- **The same definitions as Keep components.** `ResolveUpgradeLeafDefinition` (lib/Utils-Items_Modstructs.au3) maps a leaf to the same `STRUCT_*` constants with the same naming rules as `CreateValuableRunesAndInsigniasArray`, `CreateValuableModsByWeaponTypeMap` and `CreateValuableInscriptionsByWeaponTypeMap`, and uses `ModNameCleanupHelper`. All 534 leaves resolve to an existing constant (checked offline).
- **Detection follows `ContainsValuableUpgrades`.**
  - Weapon mods must match the item's weapon type and come right after a weapon-upgrade marker ('30').
  - Inscriptions must match the inscription group's item types and come right after an inscription marker ('32').
  - Runes and insignias are matched on armor salvageables, insignia first.
  - All matches must also sit on a 4-byte boundary in the item's mod data.
- **Component index is computed per item** by `ComputeSalvageComponentIndex`.
  - Default 'compact' mode: the index counts only the upgrades the item actually has, in the order prefix/insignia, suffix/rune, inscription. The item's mod data is checked for upgrade markers (0x2530), inscription markers (0x2532) and insignias (0x2408).
  - The 'fixed' index (0/1/2) is logged next to it. Switch with `$EXTRACT_COMPONENT_INDEX_MODE`.
- **ExtractUpgradesOnly rewritten.**
  - Checked leaves are read live from the Inventory tree, or from the loaded config when headless. If nothing is checked, it logs and stops.
  - Items carrying none of the checked upgrades are skipped without opening a salvage session.
  - Otherwise: one item, one session, one component, then confirmation. If not confirmed, the session is cancelled and the item is skipped. Each item is handled at most once per run.
  - Armor pieces (`IsArmor`) are no longer candidates; only armor salvageables are, so spare armor is never destroyed.
- **Constant fix.** `STRUCT_MOD_HEAVY` was 'E601824', a 7-character typo that upstream has too. It is now 'E6016824', following the condition-ID pattern of its siblings (inferred).
- Line refs:
  - lib/Utils-Storage.au3: functions at lines 2910 2958 2997 3069 3104 3141 3167 
  - lib/Utils-Items_Modstructs.au3: 170 1396 1463 1504 1519 
- Au3Check: 0 errors, 45 warnings. The one new warning is `$gui_treeview_lootoptions` "possibly used before declaration": it is a Global in BotsHub-GUI.au3 and is only read at runtime, so it is safe.

### Only verifiable in-game
- Whether the expert salvage window index is 'compact' or 'fixed'. Both are logged per item.
- Whether the upgrade markers are 0x2530/0x2532. This is inferred from `IsWeaponUpgradeStruct`, `IsInscriptionStruct` and the sample in `HasSalvageInscription` ('3E043225').

## v6 - Extract upgrades: selection priority
- When an item carries more than one checked upgrade, the choice is now: **armor = rune before insignia**; **weapons/offhands/shields = inscription, then prefix mod, then suffix mod**. Within the same kind, tree order still decides.
- Changed in lib/Utils-Storage.au3:
  - `FindCheckedUpgradeOnItem` now walks kinds in priority order and returns a `$priorityLog`.
  - New helper `UpgradeDefinitionPresentOnItem` holds the detection rules, unchanged from v5.
  - `FindNextUpgradeExtractionCandidate` and `ExtractUpgradesOnly` pass the priority log through, and a new `[Extract]` log line shows every checked upgrade found and which one was chosen.
- Component index computation (`ComputeSalvageComponentIndex`, compact/fixed) is unchanged: it still reflects the item's actual slots.
- Hardening: Null checks on returned maps and structs now use `IsMap`/`IsDllStruct`.

## v7 - Extract upgrades: items can survive an extraction
- An expert or superior salvage only has a *chance* to destroy the item. `ExtractUpgradesOnly` (lib/Utils-Storage.au3) no longer excludes an item after a successful extraction. When the item survived:
  - it is re-read by ID and its next checked upgrade is chosen by priority (rune > insignia; inscription > prefix > suffix);
  - the component index is recomputed from the item's current remaining slots;
  - this repeats until the item is destroyed, has no checked upgrade left, or reaches `$EXTRACT_MAX_SUCCESSES_PER_ITEM` (3).
- Each step is still one salvage session and one component, with the kit and free slot re-checked before every salvage.
- **Failed** extractions (no change, session cancelled) keep the item excluded for the rest of the run.
- `WaitForUpgradeExtraction` now returns one of:
  - `destroyed`: the item is gone;
  - `upgrade_gone`: the item still exists, but the chosen upgrade is no longer in its modstruct;
  - `kit_used`: a kit use was consumed but the chosen upgrade is still detected, which is logged as a possible component-index problem;
  - `''`: timeout.

  The first three count as success. `ExtractOneUpgradeFromItem` returns `destroyed`, `survived` or `failed`. New helper: `DescribeCheckedUpgradesOnItem`.
- New log line: `[Extract] Item N survived, remaining checked upgrades: ...`, or `... survived, no checked upgrades left`.

## v8 - Store items protection for every salvage path

- Anything matching a checked **Store items** entry is now never salvaged and never has an upgrade extraction attempted on it.
- I kept the existing store rules rather than writing a second copy. The body of `DefaultShouldStoreItem` moved unchanged into `ShouldStoreItemWithCache($item, ByRef $cache)`, and `DefaultShouldStoreItem` now calls it with the global cache, so the Store feature itself behaves the same. The weapon key building in `CheckStoreWeapon` moved into `GetStoreWeaponKey`, which builds `Store items.Weapons and offhands.<Rarity>.<Type>.Req <GetItemReq>`. Gray and red weapons still return no key and are never stored.
- New `IsProtectedByStoreItems($item, $storeCache, $reason)` checks the `Store items.Unidentified gold items` rule (with the same `IsUnidentifiedGoldItem` test the store pipeline uses) and then `ShouldStoreItemWithCache`. `$reason` gives the Store rule that matched.
- New `BuildStoreProtectionCache`: it starts from the applied or loaded config (what the Store feature reads) and overlays the live Inventory tab ticks when the GUI exists. It then recomputes the `@store.*` flags the same way `BuildInventoryDerivedFlags` does. When the bot runs headless, only the config is used.
- `ExtractUpgradesOnly` checks protection while picking each candidate, before any salvage session starts. It logs `[Extract] Item N skipped: protected by Store items (<rule>)` and excludes the item for the rest of the run. The check runs again before each extra pass on an item that survived.
- `DefaultShouldSalvageItem` (used by the regular Salvage items path, `SalvageItems`, `HasItemsToSalvage`, and the equipment bag moves) now returns False for protected items and logs a Debug line.

## v9 - Lockpick buyer buys in batches of 80

- `src/utilities/EctoToGold.au3`: the new constant `$LOCKPICK_BUY_BATCH = 80` sets how many lockpicks one purchase step buys.
- `ConvertGoldToLockpicks($requestedTotal = 0)`: each step makes one `BuyItem` call for `Min(80, remaining requested total, inventory room)`. The quantity is not reduced to what the carried gold covers, because the merchant itself only buys as many as the carried gold pays for. The count increase is what gets recorded as bought. The tool stops when character and storage gold together are under 1500 (out of gold).
- If character gold does not cover the wanted quantity, the tool first withdraws from storage with `ToolsWithdrawGold`, which tops character gold up to the 100k cap.
- The GWA2 `BuyItem(position, amount, unitValue)` takes the quantity and the unit price and writes the total cost (`amount * unitValue`) itself. The tool passes `($position, $quantity, 1500)`.
- New `ToolsLockpickRoom`: counts 250 for each free slot in bags 1-4, plus the space left on existing lockpick stacks under 250. `ToolsHasRoomForLockpick` now uses it.
- New `ToolsWaitForLockpicksBought`: waits until the lockpick count rises by the bought quantity and returns how many actually arrived. If fewer arrive, it is logged as a partial confirmation and counted.
- Unchanged: purchases wait a ping-based delay (`PingSleep(500)`) between each other, the tool stops after 3 unconfirmed purchases in a row, and it stops after an unconfirmed purchase at an unverified merchant position.

## v10 - Lockpick bulk purchase capped to carried gold

- In v9, one `BuyItem(pos, 80, 1500)` bought nothing in-game. The likely cause is that the cost sent was 120,000 while the character carried 100,000. The quantity encoding itself is correct (details below).
- Encoding check:
  - `BuyItem` sets amount, merchant item ID and cost = `amount * value` in `BUY_ITEM_STRUCT`.
  - `CommandBuyItem` (lib/GWA2_Assembly.au3) calls the client's `TransactItem` (cdecl, 9 dwords, `add esp,24`) with these arguments: type 1 (MerchantBuy), gold_give = cost, give = {0, null, null}, gold_recv = 0, recv = {1, &itemID, &amount}.
  - This matches GWCA's `TransactItem(TransactionType, gold_give, TransactionInfo give, gold_recv, TransactionInfo recv)`, where `TransactionInfo = {item_count, item_ids*, item_quantities*}` and `MerchantBuy = 0x1`. Quantity goes in the quantities array, and the item ID is not repeated.
  - The project already buys in bulk the same way: `BuyLockpicksInTown -> BuyInTown -> BuyItem($itemPosition, $amount, $itemPrice)`, and `BuyInTown(..., 10)` for kits.
- `ConvertGoldToLockpicks`: each batch first runs the storage withdrawal (up to 100k carried). It then buys `Min($LOCKPICK_BUY_BATCH, Floor(carried / 1500), remaining requested, room)` in one transaction. The total sent is exactly qty x 1500 and is never more than carried gold.
- Batches are logged as `[Lockpick] batch N: buying Q for Cg` and `[Lockpick] batch N: bought R/Q`. Unchanged: partial arrivals are counted, the tool stops when out of gold, and it stops after 3 unconfirmed batches in a row. There is no single-buy fallback.
