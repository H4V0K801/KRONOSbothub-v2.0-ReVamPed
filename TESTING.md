# BotsHub 2.0 (v10-improved): in-game test checklist

This list combines every live check that is still open from ANALYSIS.md §6–§10. They are in priority order: things that can destroy items come first.

## Before you start
- Use a **test character** with nothing valuable in its bags. Put spare items in the bags for the tests, keep a few free slots, and carry an **Expert or Superior salvage kit** and an ID kit.
- Run AutoIt **as administrator**. The first log line must say `admin yes`.
- Open the log file: `logs/botshub-<date>-<character>.log`, in the BotsHub folder.
- For some checks, set `"debug_logging": true` in your farm config (`conf/farm/...json`) so that Debug lines appear. Set it back afterwards.
- **To see an item's IDs:** attach (Tools → *Attach to Guild Wars*), then type `PrintItemInformationsAt(1, 3)` in the **Manual** field (Setup tab, bottom right) and press **Run**.
  - The two numbers are bag and slot: bag 1 is the backpack, and slots count from 1, left to right and top to bottom.
  - The log prints `[Item] bag 1 slot 3:`, then `ModelID: …`, `ModStruct: …`, `Type: …` and so on.
  - It only reads; nothing is sent to the game.
- **To run the extraction:** check what you want under Inventory → *Extract Components*, press **Apply**, then press Tools → **Manually extract selected components** (v37 name) in an outpost.

## What to send back when something fails
- The test number, and what you saw compared with what you expected.
- The log lines from about 10 lines before to 10 lines after the problem. Copy them from the log file, not the GUI console.
- For item tests: the item's name as shown in game, its upgrades and their values (hover text, or a screenshot), and the `PrintItemInformationsAt` output (`ModelID`, `ModStruct`, `Type`).
- Your BotsHub folder name and which loot/farm config was loaded (the log shows `Loaded … configuration at …`).

---

## P1: salvage and loot (can destroy items)

**1. 20% Enchanting staff wrapping (the original bug)**
- **Do:** use a staff whose only checked upgrade is a *Wrapping of Enchanting (20%)*. Check Extract → Mods → Staff → Suffix - Wrapping → *Of Enchanting (… 20% longer)*. Then press Extract upgrades.
- **Expect:**
  - `[Extract] Item <id> has checked suffix "…" (…) - upgrades on item: … OfEnchanting_Staff (0x00E1) … - salvage slot 1 (fixed: prefix/insignia 0, suffix/rune 1, inscription 2)`;
  - then `step 1/3`, `step 2/3 select component index 1`, `step 3/3`;
  - then `extracted … - item kept` or `- item destroyed`. The wrapping is in your bag.
- **Fail:** a different component was taken (a head, or materials), or the log shows `kit use consumed but "…" still on the item`. Send the log and the item hover text.

**2. +30 Health sword pommel**
- **Do:** same as test 1, with a sword that has a *Pommel of Fortitude (+30)*.
- **Expect:** `OfFortitude_Sword (0x00DD)`, salvage slot 1, then the pommel is extracted.
- **Fail:** send the same as test 1.

**3. Lower rolls are skipped (perfect-only extraction)**
- **Do:** with debug logging on, use a staff with a 15–19% Enchanting wrapping, or a sword with a +20–29 Fortitude pommel. Same options as tests 1 and 2.
- **Expect:**
  - no salvage starts;
  - Debug line `[Extract] Item at <bag>:<slot> has none of the checked upgrades - skipped, no salvage started`;
  - `[Extract] Done. Extracted: 0`.
- **Fail:** a salvage starts on a lower roll. Send the log and the `PrintItemInformationsAt` output.

**4. Slaying values (unconfirmed encoding)**
- **Do:** use a weapon with a *Pommel/Haft/… of <Species> Slaying* at **20%**, and if you have one, another at 15–19%. Check that slaying option and run Extract.
- **Expect:**
  - 20%: `has checked suffix "…Slaying…"`, then extracted;
  - 15–19%: skipped, as in test 3.
- **Fail:** the 20% one is skipped too. This means the game stores the slaying % differently from Py4GW. Send `PrintItemInformationsAt` for the 20% item, which is the most useful single data point.

**5. Salvage session closes after an extraction**
- **Do:** use two items with checked upgrades, where the first keeps another upgrade after extraction. For example, a staff with a checked wrapping and a head, or an armor piece with a checked rune and an insignia. Run Extract once.
- **Expect:**
  - the first item: `extracted … - item kept`, then `survived, …`;
  - the next item starts normally with `step 1/3 start salvage`;
  - `Done. Extracted: 2` (or more).
- **Fail:** `Could not start salvage session - item skipped` or `not confirmed - cancelling session` on the second item. Send the log. This decides whether the bot needs to send an "end salvage" after extracting.

**6. Keep components is perfect-only (side effect)**
- **Do:** use the default loot config on a test character. Put in:
  - an **identified** blue/purple armor piece with a **Minor** rune (e.g. Minor Vigor);
  - one with a **Superior** rune.

  Then type `InventoryManagementBeforeRun()` in the Manual field. This runs your full inventory routine (identify, salvage, sell, store, per your config). It may travel to Eye of the North first, so use a test character only.
- **Expect:** the Minor-rune armor is salvaged (the rune is lost) and the Superior-rune armor is kept.
- **Fail:** the opposite happens. Send the log and the item names.

**7. Old loot config loads with one warning**
- **Do:** load a loot config saved by v10/v11, for example `conf/loot` from the original v10 download.
- **Expect:**
  - exactly one `[Loot] Ignored 176 non-perfect option(s) under "Keep components" / "Extract Components" …` warning;
  - the Inventory tree shows only Superior/single-tier runes and max-roll mods;
  - everything else in the config is unchanged.
- **Fail:** several warnings, a crash, or other settings changed. Send the log and the config file.

## P2: Tools buttons and item IDs

**8. Open Storage (Tools tab and Setup tab)**
- **Do:** try both buttons in each situation:
  - not attached;
  - in an outpost;
  - in an explorable;
  - during a farm run.
- **Expect (v17: same as the original v10 button):**
  - not attached: no popup, log line `[Storage] Not attached to Guild Wars - use Tools > Attach or start a farm first. Storage not opened.`;
  - outpost/town: the Xunlai window opens, log `[Storage] Xunlai storage window requested`;
  - explorable: the window opens **view-only** (as in the original), log note `[Storage] Explorable area: the game shows the storage window view-only …` then `… requested`;
  - during a farm run (town or explorable): the window opens and the run continues.
- **Fail:** no window although the log says requested, the game crashes, or the running farm misbehaves right after the click (a skipped action / stuck step). Send the log, the map, and whether a farm was running.

**9. Reset session stats**
- **Do:** do 2 or more runs, note the Main tab numbers, then pause the farm. Press Tools → *Reset session stats*, then do one more run. Also press it once during a run.
- **Expect:**
  - `[NOTICE] Before reset - Session summary (…)` with the old numbers, then `Session stats reset (…)`;
  - all Main-tab counters show 0;
  - after the next run, everything counts from zero: Runs 1, experience, titles and items gained during that run only, and the `Session: 1 runs …` line;
  - when you close the hub, the summary covers only the runs since the reset;
  - `runs-<date>.csv` keeps its old lines and adds new ones;
  - during a run: the "Pause the farm…" popup, and nothing is reset.
- **Fail:** some counter keeps the old total, or a run after the reset shows old gains. Send a screenshot of the Main tab and the log.

**10. Disputed item IDs**
- **Do:** for each item you have, put it in the backpack and run `PrintItemInformationsAt(1, <slot>)`. Note the `ModelID`:
  - Zaishen Key: bot 28571, Py4GW 28517;
  - El Jora Tonic: 36445 / 36455;
  - Jungle Skale Fin: 70 / 470;
  - Mantis Pincer: bot 815 / Mantid Pincer: bot 829 (Py4GW has them swapped);
  - Envoy Sword: 36669 / 36670;
  - Ceremonial Daggers: 968 / 15166;
  - Hog's Gluttony: 2339 / 2439;
  - Censor's Icon: bot placeholder; Py4GW 2096/2097.
- Also, for any item with the inscription **"Show me the money!"**, send its `ModStruct`. v36.1 uses `3200F825` (Py4GW IncreasedSaleValue = 0x25F).
- **Send back:** item name, then ModelID. Just a list is fine.

## P3: reliability

**11. Party wipe detection**
- **Do:**
  - with *Return on death* ticked (Setup), let the party wipe once in a farm;
  - with it unticked, do the same.
- **Expect:**
  - ticked: `Party wiped and "Return on death" is enabled, run is considered failed.`, then the bot returns to the outpost;
  - unticked: `Party wiped for the N time` lines, then `Party wiped N times, run is considered failed.` after about 6 checks (one long wipe can count as several).
- **Fail:** the run continues forever, or it fails without a wipe. Send the log.

**12. Reconnect**
- **Do:** between two runs, disconnect the network for about 1 minute, then reconnect.
- **Expect:**
  - `Disconnected. Attempting to reconnect.`, then `Reconnected!`;
  - or, if that doesn't work, `Could not reconnect.` → `Game client is disconnected, pausing.`;
  - the Enter key reaches the Guild Wars window (its Reconnect button);
  - during a normal session without a disconnect, `Disconnected` must never appear.
- **Fail:** send the log, and say whether the GW window showed the reconnect dialog.

**13. Normal runs (regression)**
- **Do:** 3 or more runs on 2–3 of your usual farms.
- **Expect:**
  - the runs behave as before;
  - one `Session: N runs, …` line per run;
  - none of these lines: `timed out`, `could not be cast within`, `Could not enter … after 5 attempts`, `exceeded its hard deadline`, `Target not killed after 60s`.
- **Fail:** send the line, the farm name and where the character was. A limit that is too tight is a one-number fix.
## P4: v16 alignment fixes

**14. Onyx / Charcoal / Leather Squares are picked up and stored**
- **Do:** load *AMG Loot* (Inventory → Load, or set `"loot_configuration": "AMG Loot"` in your farm config). Farm until an Onyx Gemstone, a Lump of Charcoal or a Leather Square drops. Then let the bot store (Store items → Rare Materials is ticked in his config).
- **Expect:**
  - the log shows `Loaded loot configuration at …/conf/loot/AMG Loot.json` and no `[Loot] Ignored …` warning;
  - the material is picked up and later stored in Xunlai, like the other rare materials. Before v16 these 3 were left on the ground.
- **Fail:** the material stays on the ground. Send the log and `PrintItemInformationsAt` for one you picked up by hand.

**15. Lockpicks option**
- **Do:** on a chest farm, untick Inventory → Pick up items → *Lockpicks*, press Apply, and let a lockpick drop. Tick it again afterwards.
- **Expect:** unticked, the lockpick is left. Ticked (the default in every shipped config and in AMG's), it is picked up as before.

**16. Chest run log (v17)**
- **Do:** run Tasca's or Pongmei chest run for a few waypoints while taking damage.
- **Expect:**
  - no `Low lockpicks` lines;
  - `Taking damage - resynching position with /stuck` at most about once per 30 s, with `(Nx in the last 30s)`. The character still resyncs as before.
- **Fail:** lockpick-count lines appear, or the character gets stuck more than before. Send the log.

The full original checklist (start-up, attach, economy, headless) is in ANALYSIS.md §6.

## P5: v18 skill rotation

**17. Deadly Paradox → Shadow Form (v20: pre-v18 timing back)**
- **Do:** start Tasca's or Pongmei's chest run (or Magmas) and watch the skillbar and the log for the first minute.
- **Expect:**
  - at run start one line `Skill slots: DP 1, SF 2, SoD 3, DwSt 4, IAU 5, …` that matches your bar (0 = not on the bar);
  - DP lights up and SF starts right after it;
  - **Tasca / Pongmei:** SF is recast about every 19.5-20 s (19.5 s after the last one, as soon as SF is recharged) - like before v18; while opening chests in Pongmei it is recast whenever it is recharged and a foe is close;
  - **Magmas:** SF is recast when less than 5 s of it is left (the effect icon), like before v18 - but now with DP right before it instead of DP 1.5 s earlier.
- **Fail:** SF before DP, SF dropping while you have 15+ energy, or a wrong slot in the `Skill slots` line. Send the log and your template code.

**18. Low energy**
- **Do:** let energy fall below 20 when SF is due (e.g. stand in a fight).
- **Expect:** DP is never used below 20 energy. With foes close the bot waits up to 3 s for 20 energy; then, with 15+ energy (Tasca/Pongmei) or 5+ (Magmas), SF is cast alone. Under 15 (Tasca/Pongmei) nothing is cast.

**19. Shroud of Distress (unchanged from v18/v19)**
- **Expect:** Shroud is recast only in its last ~2-3 s, and not right before an SF refresh when energy is short.

**20. "I Am Unstoppable!" on Giant Stomp (unchanged)**
- **Do:** run past a giant that uses Giant Stomp (wiki users: all Giants, Jotun Skullsmasher, Summit Beastmaster, Summit Giant Herder) with IAU on the bar.
- **Expect:** `Knockdown threat (skill 530 Giant Stomp) - "I Am Unstoppable!"` in the log (v20 adds the skill name), IAU used during the stomp's 2 s, no knockdown.
- **Fail:** knocked down while IAU was recharged and you had 5+ energy. Send the log (it tells whether the stomp was seen).

**20b. "I Am Unstoppable!" on Titans (v20 Wild Blow / Bull's Strike, v21 Irresistible Blow)**
- **Do:** run Magmas (Hell's Precipice) with IAU on the bar. Burning Titans hit with Wild Blow (ends your stance) and follow up with Irresistible Blow (knockdown if you block it - Shroud of Distress gives 75% block under 50% Health).
- **Expect:** `Knockdown threat (skill 321 Wild Blow) - "I Am Unstoppable!"` on the Wild Blow; IAU stays up for the follow-up (it is a shout, Wild Blow does not remove it). If IAU had already run out and is recharged when the follow-up starts: `Knockdown threat (skill 356 Irresistible Blow) - "I Am Unstoppable!"`. Titan Abominations (Realm of Torment): `Knockdown threat (skill 332 Bull's Strike) - "I Am Unstoppable!"`.
- **Know:** IAU lasts 16-20 s (Norn rank) and recharges in 30 s, so for 10-14 s after it ends nothing can be done. Wild Blow still ends Deadly Paradox / Dark Escape / Dwarven Stability (stances). IAU may also fire when a titan swings at someone else within 1250.
- **Fail:** knocked down by a titan while IAU was recharged and you had 5+ energy, or no `Knockdown threat` line at all although a titan hit you with these skills. Send the log lines around it.

## P6: v19 Rune of Major Vigor

Load `AMG Loot.json` (the log shows `Loaded … configuration at …` and **no** `[Loot] Ignored …` warning). In the Inventory tab, *Keep components* and *Extract Components* → Armor upgrades → All → Runes show **Major Vigor** ticked, and *Store items* shows **Runes → Major Vigor** ticked.

**21. Keep**
- **Do:** with a Major Vigor armor piece (hover text "+41 Health" / "Rune of Major Vigor") in the bags, run the normal sell/salvage pass (or a farm loop with selling on).
- **Expect:** the piece is not sold and not salvaged for materials. If Store Purple/Gold is ticked it ends up in Xunlai instead.
- **Fail:** it is sold or salvaged for materials.

**22. Store a loose rune**
- **Do:** put a loose Rune of Major Vigor in bag 1 slot 1, run `PrintItemInformationsAt(1, 1)`, then let the bot store items in town.
- **Expect:** the print shows `Type: 8` and the ModStruct contains `C202E927`; the log shows `Storing items in Xunlai Storage` and the rune moves to Xunlai. A loose Superior Vigor rune (`C202EA27`) is **not** moved by this option.
- **Fail:** not moved: send the print output (type and ModStruct).

**23. Extract**
- **Do:** untick Store items → Armor salvageables → Purple and Gold (otherwise test 24 applies), Apply, put a Major Vigor armor piece in the bags with an Expert/Superior salvage kit, press Tools → **Extract upgrades** in an outpost.
- **Expect:** `[Extract] Item <id> has checked rune "Armor upgrades.All.Runes.Major Vigor" (C202E927) - salvage slot 1 (fixed: prefix/insignia 0, suffix/rune 1, inscription 2)`, then the Rune of Major Vigor in your bags. A Minor or Superior Vigor piece does **not** match Major Vigor.
- **Fail:** wrong rune/insignia taken, or the Major Vigor piece is skipped. Send the log and `PrintItemInformationsAt` for the piece.
- Afterwards set the Store ticks back.

**24. Store wins over Extract (expected with your config)**
- **Do:** with Store Purple/Gold ticked (your file), press Manually extract selected components with a purple Major Vigor piece.
- **Expect:** `[Extract] Item <id> skipped: protected by Store items (Store items.Armor salvageables.Purple)` - the piece is stored whole, nothing is salvaged.

## P7: v22 Extract selected components before selling

Use a loot config with a few components checked under Inventory → *Extract Components* (e.g. `AMG Loot.json`). Setup → tick **Extract selected components before selling** and Apply. Have gold on the character or in storage.

**25. GUI**
- **Do:** look at Setup and Tools.
- **Expect:** Setup shows *Extract selected components before selling* (tooltip mentions buying an Expert Salvage Kit). Tools shows *Manually extract selected components* and the note "Specified items must be in your inventory (bags 1-4), with an Expert or Superior salvage kit." Your old config loads with the box in the same state as before.

**26. Order: extract before selling**
- **Do:** with an Expert kit in bags, 1-2 weapons/armor (unidentified is fine, the pass identifies first) holding a checked component (not Store-protected), start a farm (or let the inventory pass run).
- **Expect, in this order:** identify, then `[Extract] Extract selected components before selling`, `[Extract] <n> checked upgrade(s) read from ...`, `[Extract] Item <id> has checked ...`, `... extracted ...`, `[Extract] Done. Extracted: <n>, failed: 0`, and only **then** the salvage/sell lines. The components are in your bags (or stored if Store says so).
- **Fail:** any sell/salvage line before `[Extract] Done`, or the item was sold/salvaged with its component.

**27. No kit → buy**
- **Do:** as 26 but move all Expert/Superior salvage kits to storage.
- **Expect:** `[Extract] No Expert or Superior salvage kit left - buying an Expert Salvage Kit (2991, 400 gold), 1/5 this pass`, the bot walks to the Merchant, `[Extract] Bought an Expert Salvage Kit - continuing`, then the extraction. 400 gold less.
- **Fail:** no buy, a different item bought (send the log), or it buys with nothing to extract.

**28. Nothing to extract → no buy**
- **Do:** no kits, no item with a checked component.
- **Expect:** `[Extract] No identified item in bags 1-4 holds a checked component - nothing to extract`; no gold spent; selling as usual.

**29. Failed buy protects items**
- **Do:** no kits, under 400 gold on the character **and** in storage, one item with a checked component.
- **Expect:** `[Extract] Could not buy an Expert Salvage Kit (...) - stopping; ...`, then `[Extract] Item <id> not salvaged for materials: still holds checked ...` / `not sold`, and `[Extract] 1 item(s) still hold a checked component - not salvaged for materials or sold this pass`. The item is still in your bags.

**30. Store wins**
- **Do:** an item that Store items protects (e.g. purple Major Vigor armor with Store Purple ticked).
- **Expect:** `[Extract] Item <id> skipped: protected by Store items (...)`, then it is stored whole. No kit bought for it.

**31. Mid-run**
- **Do:** start a farm and reach an explorable with a basic salvage kit and an item that would have been salvaged mid-run in older versions. (The *Salvage during run* checkbox was removed in v35; leftover `farm_materials_mid_run` keys are ignored.)
- **Expect:** mid-run salvage does not run. Extraction still waits for the next town pass.

**32. Unticked = as before**
- **Do:** untick the box, Apply, repeat 26.
- **Expect:** no `[Extract]` lines; salvage/sell exactly as in v21.

**33. Manual button**
- **Do:** with the item and a kit in your inventory, press Tools → *Manually extract selected components* in an outpost; then again with no kit.
- **Expect:** same extraction lines as v21; with no kit `[Extract] No Expert or Superior salvage kit in inventory (bags 1-5) - stopping` and **no** buy.

## P8: v23 Items panel (inventory + storage)

**34. Layout**
- **Do:** start the bot and look at the Main tab.
- **Expect:**
  - *Informations* looks exactly as before.
  - On the right is **Items (inventory + storage)**, a list with the headers ELITE TOMES, TITLES, EXCHANGEABLES, CONSUMABLE MATERIALS, SWEETS, PARTY and ALCOHOL.
  - The mouse wheel scrolls it.
  - Before attaching, the line under it reads `Storage not read yet: attach, then visit an outpost`.

**35. Totals in an outpost (no chest opened)**
- **Do:**
  1. Attach in an outpost and do **not** open the Xunlai chest.
  2. Wait about 5 s, or press Start and then Pause.
- **Expect:**
  - The line reads `Storage: read in this outpost at HH:MM`.
  - Lockpicks, Elite Tomes, ectos in storage and similar show your inventory **plus** storage. Compare 3-4 items against the in-game chest, including one in material storage and one in a later storage pane.
  - Elite Tomes *Total* is the sum of the 10 rows.
- **Fail:** a total equals only your inventory while the item is also in storage. Send the item and both numbers.

**36. Changes are picked up**
- **Do:** in the outpost, move a stack between your inventory and storage, or drop or buy one.
- **Expect:** within about 5 s the total stays the same after a move, and changes after a drop or buy.

**37. Explorable / cache**
- **Do:** leave for an explorable area.
- **Expect:**
  - The line reads `Storage *: last outpost read YYYY-MM-DD HH:MM`.
  - Totals carry a `*`, for example `12*`.
  - Inventory pickups still add to the total at the run end.
- **Do:** close the bot, start it again, attach in an explorable.
- **Expect:** the cached storage part is used and marked `*`, until you are next in an outpost.

**38. Other character**
- **Do:** switch to a character that has never been read, in an explorable.
- **Expect:** `Storage not read yet: inventory only (visit an outpost)`. It must not use the other character's numbers.

**39. Titles and Reset**
- **Do:** farm one run that gains title points, then press *Reset session stats*.
- **Expect:**
  - The title rows show the points gained, as in v22.
  - Reset sets the titles and Informations to 0.
  - Item totals stay the same, because they are absolute counts.

**40. No slowdown in runs**
- **Do:** run 3+ farm runs with the log open.
- **Expect:** no extra delay between actions. The list updates only at run start and end, not during the run.

## P9: v24 Store Mods, stuck watchdog, Empty Tab, Graphics button

**41. Graphics button**
- **Do:** look at Setup > Other options, then click the yellow button twice.
- **Expect:** it reads **Disable Graphics** while the game draws. After a click the game stops drawing and the button turns green and reads **Enable Graphics**. Clicking again brings the graphics back. After a restart, the saved state shows the matching text.

**42. Store Mods** *(v24; replaced in v25 by Store items > Components, see P10)*
- **Do:**
  1. Inventory > expand *Store items* > tick **Mods** > *Apply* (then *Save* your loot config).
  2. Carry 2-3 loose runes, insignias or mods (for example from *Manually extract selected components*) and let a trade-town pass run, or pick the *Storage* farm.
- **Expect:**
  - `Storing items in Xunlai Storage`, then the components are in storage, in the first free slots of your panes.
  - Weapons, armor and other items behave as before.
  - With **Mods** unticked, loose components stay in your bags, except Major Vigor runes when *Runes > Major Vigor* is ticked.
- **Fail:** a component was sold or salvaged, or something that is not a rune, insignia, mod or inscription was stored by this option.

**43. No more pause after 10 failures**
- **Do:** run a farm that fails every time (for example the wrong build, or an outpost you can't reach) for 11+ runs.
- **Expect:** no `runs failed in a row - pausing` line; the bot keeps looping. The *Session:* line still says `N failures in a row`.

**44. Stuck watchdog (safe test)**
- **Do:**
  1. Start a farm.
  2. When the character is in the explorable, take control and park it somewhere it can't move from, or just stand still (Pause won't do, it waits for the run). Don't let it kill anything and don't let new log lines appear: block it against a wall with no foes around.
  3. Wait 5 minutes.
- **Expect:**
  - `[Stuck] No progress for 5 min (...) in <farm> - mapping back to <town> and restarting the farm setup (stats kept)`.
  - The character travels to the farm's town.
  - The run ends with `Run failed after ...`, and `[Stuck] Recovered (1 this session): ...`.
  - The next run performs the farm's **setup** again (the setup log lines you saw on the very first run).
  - Informations counts the run as a failure, and all other counters keep their values. The bot does **not** pause.
- **Fail:** a pause, stats reset, or no setup on the next run.

**45. No false trips**
- **Do:** run your usual farms for an hour, including long fights (Vaettirs, spirit slaves, chest runs).
- **Expect:** no `[Stuck]` line during normal runs. If one appears in a normal run, send the log of the minutes before it.

**46. Empty Tab**
- **Do:**
  1. In an outpost, attach (or with the bot paused), Tools > *Storage tab* = a tab with a few items and some stacks.
  2. Press **Empty Tab**.
- **Expect:**
  - The storage window opens. Items move one by one starting with slot 1, and stacks fill up the same items already in your bags first.
  - `[Empty Tab] Done: storage tab <T> emptied (n slot(s) ...)`.
  - The *Anniversary* entry empties the anniversary pane.
- **Do:** repeat with only 2 free inventory slots.
- **Expect:** 2 items move, then `[Empty Tab] Inventory full - stopped at tab <T> slot <n>. ...`; the rest stays in storage.
- **Do:** try in an explorable, and while a farm runs.
- **Expect:**
  - Explorable: `Items can only be taken out of storage in an outpost or town ...`, nothing moved.
  - While a farm runs: the "Pause the farm..." box.
- **Fail:** an item lost, a wrong tab emptied (send which tab you picked and which one emptied), or the equipment pack used.


## P10: v25 Store items > Components (Mods / Inscriptions / Insignias / Runes)

**47. The tree**
- **Do:** start the bot and open the Inventory tab.
- **Expect:**
  - *Store items* is already open, with **Components** as its first entry, also open, showing **Mods**, **Inscriptions**, **Insignias** and **Runes**.
  - With *AMG Loot* loaded, *Runes > All* shows **Major Vigor** and **Superior Vigor** ticked, and *Inscriptions > Weapon* shows *Strength and honor* and *Dont think twice* ticked: the same ticks as under Keep components.
  - With an old loot file of yours, the log says `[Loot] Added Store items > Components (447 option(s), unticked)`. Press *Save* to keep them.
- **Fail:** no Components entry, or an old *Store items > Mods* / *Store items > Runes* entry is still there.

**48. Stored after extraction, before selling**
- **Do:**
  1. Tick *Extract selected components before selling* (Setup) and a weapon whose mod is ticked both under *Extract Components* and under *Store items > Components > Mods* (e.g. *Sword > Suffix - Pommel > of Fortitude*). Press *Apply*.
  2. Carry that sword and one ordinary item to sell, and let a trade-town pass run.
- **Expect, in this order:**
  1. the `[Extract] …` lines;
  2. `[Store] Storing 1 component(s) ticked under Store items > Components (before salvaging/selling)`;
  3. `[Store] Stored 1 component(s)`;
  4. only then the salvage and sell lines.

  The pommel ends up in Xunlai storage.
- **Fail:** any sell or salvage line before the `[Store]` lines, or the pommel sold or salvaged.

**49. Per-group identification (please send the dumps)**
- **Do:** put one loose item of each kind in bag 1: a weapon mod (e.g. a Sword Pommel of Fortitude), an inscription, an insignia and a rune. For each one, run `PrintItemInformationsAt(1, <slot>)` (see *Before you start*). Then tick only that one entry under Components, *Apply*, and run a town pass. Repeat for the next one.
- **Expect:**
  - Each ticked one is stored, and the others stay in the bags.
  - An *Axe* grip of Fortitude is **not** stored when only *Sword > Pommel > of Fortitude* is ticked.
  - A Major Vigor rune is not stored when only Superior Vigor is ticked.
- **Send back:** the four `ModStruct:` / `Type:` lines, whether it passed or not. They confirm the loose weapon-mod and inscription layout (ANALYSIS §22.3).

**50. Storage full**
- **Do:** fill your Xunlai panes, tick a component you carry, and run a town pass.
- **Expect:**
  - `[Store] Xunlai storage is full - N component(s) stay in your bags (never sold or salvaged); continuing`.
  - Salvage and selling of the other items still happen.
  - The component is still in your bags afterwards.
- **Fail:** the pass stops or pauses, or the component is sold or salvaged.

**51. v24 Store Mods (test 42) is replaced**
- **Do:** load a loot file saved with v24 where *Store items > Mods* was ticked.
- **Expect:** `[Loot] Migrated v24 "Store items.Mods" (ticked: every component ticked)`, and every Components entry ticked.

## P11: v26 slaying suffixes ("+20% damage vs creatures") and 19% rolls

Use **AMG Loot** (or tick the slaying entries yourself) and turn on Debug logging (Setup) for these tests.

**52. A 20% slaying weapon is extracted (please send one dump)**
- **Do:** carry a weapon with a 20% slaying suffix you have ticked, e.g. a sword *of Charrslaying* (Damage +20% vs. Charr). Run `PrintItemInformationsAt(1, <slot>)`, then *Manually extract selected components*.
- **Expect:** `has checked suffix "Mods.Sword.Suffix - Pommel.Of Charrslaying"`, salvage slot 1, then the pommel is extracted.
- **Fail:** the Debug line `… has none of the checked upgrades - skipped … (slaying: species 1, damage +20% vs species)`. Send that line and the `ModStruct:` line.

**53. A 19% (15-18%) slaying weapon is not kept**
- **Do:** carry a weapon with a 15-19% slaying suffix and let a trade-town pass run, with a Sell rule ticked for its rarity/type/req (AMG Loot sells Gold/Purple/Blue/White weapons).
- **Expect:** no extraction for it (Debug: `… skipped … damage +19% vs species`), and it is sold. Same for an old-school (non-inscribable) weapon.
- **Fail:** it stays in your bags after the pass.

**54. Unticked species are not kept**
- **Do:** carry a 20% *of Trollslaying* (or Giant / Ogre / Pruning) weapon, which AMG Loot leaves unticked under Keep components.
- **Expect:** sold by the Sell rule, not extracted (except *Axe > of Pruning*, which is ticked under Extract).

**55. Held until extracted**
- **Do:** tick *Extract selected components before selling* (Setup) and carry a 20% slaying weapon (ticked) plus an ordinary one.
- **Expect:** the slaying suffix is extracted before the sell step; the weapon is not sold while it still holds the suffix.

**56. Loose slaying component stored**
- **Do:** with *Store items > Components > Mods > Sword > Suffix - Pommel > Of Charrslaying* ticked (AMG Loot), carry a loose 20% Sword Pommel of Charrslaying and run a town pass.
- **Expect:** `[Store] Stored 1 component(s)`; it is in Xunlai storage. A 19% one is not stored and is never sold or salvaged.

Note: Gold Req 8 weapons are ticked under *Store items > Weapons and offhands* in AMG Loot, so a Gold Req 8 slaying weapon is stored whole, not extracted (Store items is checked first).

## P12: v27 old-school auto-keep (only q9 +5 energy and wand/focus HCT+HSR pairs)

Use **AMG Loot** with a Sell or Salvage rule ticked for the weapon's rarity/type/req, and Debug logging on. For each item, run `PrintItemInformationsAt(1, <slot>)` before the town pass if the result surprises you and send the `ModStruct:` line.

**57. q9 +5 energy OS weapon kept**
- **Do:** carry a gold/purple q9 old-school (non-inscribable) axe, sword, bow, dagger or hammer with "Energy +5", then run a town pass.
- **Expect:** it stays in your bags. A q8 or q10 one is sold/salvaged.

**58. Wand / focus HCT + HSR pairs kept (q9 and q10)**
- **Do:** carry OS wands or foci, q9 or q10, with: 20% HCT + 20% HSR of the item's own attribute (e.g. Domination Magic 9, "Halves casting time of Domination Magic spells (Chance: 20%)" + "Halves skill recharge of Domination Magic spells (Chance: 20%)"); 10% + 10% (all spells); 20% + 10%; 10% + 20%.
- **Expect:** all kept.

**59. Single HCT or HSR not kept**
- **Do:** carry an OS wand or focus (q9 or q10) with only one of them: a single 20% HCT, a single 20% HSR, a single 10% HCT or a single 10% HSR.
- **Expect:** sold/salvaged by your rules. Same for a 20/20 of another attribute, a q11+ 20/20, and any staff (20/20, 10/10, 20/10).

**60. Inherent-only OS weapons sold**
- **Do:** carry OS weapons with only inherent mods: a 15^50 axe (even a rare skin), a +15% enchanted or stance sword, a q9 shield with +30 health / armor vs species.
- **Expect:** sold/salvaged by your rules, not kept.

**61. Zealous / Vampiric follow the ticks**
- **Do:** carry an OS sword with a perfect Vampiric hilt (ticked under Extract in AMG Loot), with *Extract selected components before selling* on.
- **Expect:** the hilt is extracted first, then the sword is sold/salvaged. A Zealous hilt (unticked) is not extracted and the sword is sold.

**62. Unchanged keeps**
- **Expect:** equipped, customized, green, unidentified and ultra-rare models (e.g. Eternal Bow) are still kept.

Note: Gold Req 8 weapons are ticked under *Store items > Weapons and offhands* in AMG Loot, so they are stored whole (Store items is checked first).

## P13: v29 Keep components removed

Earlier sections that mention *Keep components* (P1-P12) are obsolete for that part: use *Extract Components* instead.

**63. The branch is gone**
- **Do:** open the Inventory tab.
- **Expect:** no *Keep components* between *Identify items* and *Salvage items*.

**64. Old loot file**
- **Do:** *Load* an older loot file that still has *Keep components* (e.g. a v28 AMG Loot.json), then *Save* it under a new name.
- **Expect:** no warning or error in the log; the tree has no *Keep components*; the saved file has none either.

**65. Weapon with a perfect mod**
- **Do:** with *Extract selected components before selling* on (Setup), carry a weapon with a perfect mod ticked under Extract Components and run a town pass.
- **Expect:** the mod is extracted, then the weapon is sold/salvaged by your rules (it is not kept).

**66. Armor with a perfect rune**
- **Do:** same with a blue armor salvageable carrying a ticked Superior rune.
- **Expect:** the rune is extracted, then the armor is sold. Purple/gold ones are stored (your Store items rule).

**67. Major Vigor**
- **Expect:** a Major Vigor rune is still extracted from armor and the loose rune is stored.


## P14: v30 map load guard and 2-minute watchdog

**68. Travel waits for the full load**
- **Do:** start any farm whose town is not the current map (or press Start after a fresh login).
- **Expect:** after `Travelling to <town> (Outpost)` the character stays still until the outpost is fully drawn, then acts. No `did not finish loading` line on a normal travel.

**69. Zone into the explorable**
- **Do:** run a farm that walks into a portal (Feathers, Raptors, a vanquish).
- **Expect:** the character doesn't move, cast or talk during the loading screen; it starts once the explorable is shown.

**70. Slow load (optional)**
- **Do:** throttle your connection or start Guild Wars on a slow disk so a load takes > 20 s.
- **Expect:** `... did not finish loading (<reason>) - failing the run` (or `Map load wait failed`), then `Run failed`, then the next run retries. Never acting inside a loading screen.

**71. Watchdog 2 min in an explorable**
- **Do:** as test 44, but wait **2 minutes**.
- **Expect:** `[Stuck] No progress for 2 min (same map, moved less than 300, no XP gained, no inventory change, no new log line) ...`, map back, run failed, setup again, stats kept.

**72. Watchdog in town**
- **Do:** with a full inventory, start a farm so the town pass runs; when the character reaches the merchant, take control and close the merchant window, then stand still for 2 minutes (if the bot keeps retrying the same thing, that is the stuck case).
- **Expect:** `[Stuck] No progress for 2 min ...`, a district change (already in town), `[Stuck] Tripped before the farm started - skipping this run`, `Run failed`, then the next run performs the town pass and the setup again.

**73. No false trip on a long town pass**
- **Do:** fill all bags with salvageable items (or a long Extract/Store pass) and let the town pass run for several minutes.
- **Expect:** no `[Stuck]` line while items are being salvaged / sold / stored.

## P15: v31 Session column and dark theme

**74. Session baseline**
- **Do:** start BotsHub, attach to a character standing in an outpost and wait for the Items panel status `Storage: read in this outpost`.
- **Expect:** the Session column changes from blank to `0` on every item row (titles were already `0`).

**75. No baseline outside an outpost**
- **Do:** restart BotsHub while the character is in an explorable zone.
- **Expect:** Session stays blank (Totals show with `*` if storage is cached) until you return to an outpost. Then it turns to `0`.

**76. Gains and losses**
- **Do:** run a farm for a few runs, then use or sell a few lockpicks.
- **Expect:** looted items show `+N` in green, and lockpicks show `-N` in soft red when you have fewer than at the start. Total keeps showing inventory + storage.

**77. Moves net to zero**
- **Do:** in an outpost, use Tools > Empty Tab (or move a stack from storage to the inventory by hand), then let the panel refresh.
- **Expect:** Totals and Session unchanged for the moved items.

**78. Character switch**
- **Do:** switch to another character (character combo) and go to an outpost.
- **Expect:** Session is blank and then `0` again for the new character (its own baseline).

**79. Dark theme readability**
- **Do:** open each tab.
- **Expect:** dark background everywhere with light text; gold group titles, gold selected tab and loot-tree branch titles; light blue Informations numbers and Items totals; checkbox and radio labels readable (no black text); disabled controls in grey; console lines in green/grey/cyan/amber/red by level. Known light parts: the Items list column header (on Windows older than 10 1809), scrollbars.

## P16: v32 no clipped text

**80. Informations and other tabs**
- **Do:** open BotsHub and look at Main > Informations, then Setup, Team and Inventory.
- **Expect:** "Time per run:" and "Obsidian Shards:" are written in full, and values aren't cut (try a long session: Time "1h 23min 45s", Gold "1234k567g"). "Identification kits:", "Team member build", "Expand all" and "Reduce all" are written in full.

## P17: v33 Titles tab

**81. Tab and values**
- **Do:** attach, wait one refresh (5 s), open the Titles tab (between Follower and Tools).
- **Expect:**
  - Totals match the in-game Hero panel > Titles.
  - Bars are full and green for maxed titles.
  - Session is blank at first, then 0, then +N after gaining points.
  - Zaishen "Keys needed" = (100,000 - points) / 5, rounded up.
  - Keys owned = Zaishen Keys in inventory + storage.
  - The "Tools" header is not covered by the configuration combo.

**82. Buttons**
- **Do:** in an outpost with a mix of sweets in the backpack and some in storage, press *Eat all sweets*. Repeat in an explorable.
- **Expect:**
  - Outpost: only town sweets are used; explorable: only combat sweets.
  - Honeycomb, candy canes, Pumpkin Cookies, Refined Jelly and War Supplies stay.
  - Storage is untouched.
  - The log lists each item with +points and a final summary.
- **Do:** *Use all party items* in an explorable, then in a town.
- **Expect:** in an explorable nothing is used and the log explains why. In a town, tonics are used about 5 s apart and a Crate of Fireworks is skipped (guild hall only).
- **Do:** while a farm is running, press a button.
- **Expect:** the "Pause the farm..." popup appears and nothing is used.
