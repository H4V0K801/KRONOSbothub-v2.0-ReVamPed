# [BotsHub]
BotsHub is an **AutoIt-based automation hub for Guild Wars**, written in AutoIt 😎

It provides a **single framework and interface** to run multiple bot scripts, with shared systems, consistent behavior, and easy extensibility.

> ⚠️ This bot operates autonomously (selling, salvaging, storing items, etc.).  
> Make sure valuable items are safely stored before running it.  
> The authors are not responsible for lost items or unintended behavior.

> ⚠️ Disclaimer: This project is not affiliated with or endorsed by ArenaNet - Guild Wars.

---

## Usage
To use it:

0. Run the game with no add-ons: NO Toolbox, NO cartography, NO reshade, nothing. Also use lowest graphics if possible.
1. Install **AutoIt (≥ 3.3.16.1)** 🛠️
2. Clone or download the repository (`<> Code → Download ZIP`) 📥
3. Extract the archive if needed
4. Run `BotsHub.au3` **using AutoIt** ▶️
5. Select a bot and press **Start** ✅

⚠️ Do **not** run individual bot files from `/src/`.  
⚠️ Make sure the Guild Wars client is running and logged in.

---

## v10-improved: what's new and how to run it

This build is a hardened version of v10. It has the same entry point (`BotsHub.au3`), the same folder layout, and the same farms and builds. It is fully compatible with your existing `conf/` files.
- `CHANGELOG.md` lists every change.
- `ANALYSIS.md` has the full issue report and the **Live testing checklist**.

**Item & mod audit (follow-up):** *Extract upgrades only* now uses the game's fixed salvage slots: prefix/insignia 0, suffix/rune 1, inscription 2. Wrappings, pommels and other suffix-only items are extracted again. Matching also checks the upgrade id, so a Hale head no longer counts as a Wrapping of Fortitude. Details: `ANALYSIS.md` §7.

**Perfect-only extraction (v12):** *Extract upgrades only* now offers only perfect options: max-roll mods and inscriptions, Superior or single-tier runes, and insignias. It extracts an upgrade only when the item carries the max value, so a 19% Enchanting wrapping or a 15% slaying pommel is skipped. Older loot configs still load: removed options are ignored with one warning. Details: `ANALYSIS.md` §8.

**Perfect-only Keep components (v13):** *Keep components* now offers the same 446 perfect options and keeps an item only for a max-roll upgrade. Armor whose only good upgrade is a Minor/Major rune is now salvaged under the default settings, and the rune is lost. Older configs still load, with one warning. Details: `ANALYSIS.md` §9.

**Open Storage on the Tools tab (v14):** opens the Xunlai storage window. Since v17 both Open Storage buttons work like the original: in town, in explorables (view-only) and while a farm runs; they only log a line if you are not attached. Recommendations for further work: `ANALYSIS.md` §11.

**Skill rotation (v18, v20):** Deadly Paradox is cast first and Shadow Form right after it (DP only with 20 energy). v20 put the *timing* of Shadow Form / Deadly Paradox back to what each farm did before v18 (Tasca/Pongmei: every 19.5 s; Magmas: under 5 s left; Margonite/DragonMoss: when recharged; Follower: when dropped). Shroud of Distress keeps the v18 timing (last ~2.5 s). "I Am Unstoppable!" fires when a nearby foe starts Giant Stomp, Agnar's Rage, Wild Blow, Bull's Strike or Irresistible Blow (Titans; v21). Skill slots are read from your bar at run start and logged. Details: `ANALYSIS.md` §15 and §17; in-game checks: `TESTING.md` P5.

**Rune of Major Vigor (v19):** the one Minor/Major rune exempt from the perfect-only rule. Major Vigor can be kept (Keep components), extracted (Extract upgrades only, rune slot 1) and, as a loose rune, stored (v19: Store items → Runes → Major Vigor; since v25: Store items → Components → Runes → All → Major Vigor). Note: if Store items → Armor salvageables → Purple/Gold is ticked, such armor is stored whole instead of extracted. Details: `ANALYSIS.md` §16; in-game checks: `TESTING.md` P6.

**Extract selected components before selling (v22):** the Options checkbox (was *Extract upgrades only*, which did nothing) now extracts the components checked under Inventory > *Extract upgrades only* in town, after identifying and before salvaging for materials or selling. It buys an Expert Salvage Kit if you have none (max 5 per pass). Items still holding a checked component are never salvaged or sold while it is ticked. The Tools button is now *Manual Selected Component Extract* (items must be in your inventory). Details: `ANALYSIS.md` §19; in-game checks: `TESTING.md` P7.

**Items panel (v23):** the Main tab *Items collected* and *Titles* boxes are now one scrollable list: Elite Tomes (+ Total), Titles (+ Lockpicks), Exchangeables, Consumable Materials, Sweets, Party and Alcohol. Each item shows the **total in inventory + Xunlai storage**. Storage is read in outposts without opening the chest and is cached per character, so a `*` means the storage part is from the last outpost visit. *Informations* is unchanged. Details: `ANALYSIS.md` §20; in-game checks: `TESTING.md` P8.

**v31:**
- **Session column:** the Items panel shows **Item | Session | Total**. *Session* is what you gained (`+N`, green) or lost (`-N`, red) since BotsHub started for the current character. The baseline is taken at your first outpost visit with the game fully loaded, so it stays blank until then. Moving items between inventory and storage doesn't change it, and switching characters starts a new count. Details: `ANALYSIS.md` §27; checks: `TESTING.md` P15.
- **Dark theme:** the whole window is dark with light text, gold section titles, light blue values and coloured console levels. Colours live in `lib/BotsHub-Theme-Colors.au3`.

**v24:**
- **Store Mods:** Inventory > *Store items* > **Mods** (unticked by default). When ticked, the store step puts every loose upgrade component from your bags into Xunlai storage: runes, insignias, weapon mods and inscriptions. *(Replaced in v25 by Store items > Components, see below.)*
- **Stuck watchdog:** the old *pause after 10 failed runs in a row* is gone. If a run makes no progress for 2 minutes (v30: also in towns, during the inventory pass and setup), the bot maps back to the farm's town and counts the run as failed. It then runs the farm setup again from scratch and keeps going. Your stats are kept. A run counts as making progress when the character moves, zones, gains XP (kills), its inventory or gold changes, or it writes a new log line.
- **Map load guard (v30):** after every travel or zone change the bot waits until the map is fully loaded (no loading screen, right map and instance type, your character and party present) before moving, talking, trading or casting; a load that never completes fails the run, and the next run retries.
- **Tools > Empty Tab:** pick a storage tab (I to XIII, or Anniversary) and press *Empty Tab*. Its items move into your inventory one by one, from slot 1. This works in an outpost or town and stops when your inventory is full.
- **Options:** the graphics button now names the action: *Disable Graphics* while the game renders, *Enable Graphics* while it doesn't.

Details: `ANALYSIS.md` §21; in-game checks: `TESTING.md` P9.

**v25: Store items > Components:**
- **Where:** Inventory > *Store items* (open at start) > **Components** (first entry, open) > **Mods** / **Inscriptions** / **Insignias** / **Runes**. The entries are the same perfect-only ones as Keep components, plus Major Vigor.
- **When it runs:** right after *Extract selected components before selling* and **before** any salvage or sale, the ticked loose components go to Xunlai storage. If storage is full, they stay in your bags and the pass continues. Loose components are never sold or salvaged.
- **Replaces:** the v24 *Store items > Mods* leaf and the v19 *Store items > Runes > Major Vigor*, migrated automatically.
- **Older loot files:** they get the new entries unticked at load; press *Save* to keep them.

Details: `ANALYSIS.md` §22; in-game checks: `TESTING.md` P10.

**v26: slaying suffixes (+20% damage vs creatures):**
- *of Deathbane / Charrslaying / … Slaying* at **20%** are now kept, extracted, held and stored when ticked. 15-19% rolls and unticked species are salvaged/sold by your normal rules, on old-school weapons too.
- Old-school weapons are kept for their mods only when the mod is ticked under *Keep components*.

Details: `ANALYSIS.md` §23; in-game checks: `TESTING.md` P11.

**v27: old-school auto-keep:**
- Old-school weapons are no longer kept for inherent mods (15^50, +15% enchanted/stance, inherent zealous/vampiric, +30 health, …), rare skin or not. Salvageable mods (Zealous / Vampiric prefixes, inscriptions) count only when ticked.
- Kept automatically, no tick needed: **q9 + Energy +5**; **wand or focus, q9 or q10**, with halves casting time AND halves skill recharge, each 20% of the item's attribute or 10% of all spells (20/20, 10/10, 20/10, 10/20). A single one never; staves never.

Details: `ANALYSIS.md` §24; in-game checks: `TESTING.md` P12.

**v28:** the BotsHub window and taskbar use AMG's inverted helmet icon (`assets/icon/BotsHub.ico`). If the file is missing, the default AutoIt icon is shown.

**v29: Keep components removed:** the Inventory tree has no *Keep components* branch any more, and items are no longer kept whole for their mods. Tick what you want under **Extract upgrades only** and turn on *Extract selected components before selling* (Options): the component is extracted, then the item is sold/salvaged. Loose components are stored with *Store items > Components*. Older loot files with *Keep components* still load (the branch is ignored and not saved again). Details: `ANALYSIS.md` §25; in-game checks: `TESTING.md` P13.

**v15:** *Reset session stats* now really resets the counters: see `ANALYSIS.md` §12.2 for exactly what is and isn't reset. **To test in game, follow `TESTING.md`.**

**v16:** (personal loot configs are no longer shipped; only Default and Masterloot.) JSON configs, code, GUI and farm scripts are now cross-checked by `tools/alignment/check_alignment.py`. Fixed with it: Onyx Gemstones, Lumps of Charcoal and Leather Squares were never picked up or stored, the Lockpicks and Other-trophies options were ignored, and the shipped farm configs now list every option. Open items: `ANALYSIS.md` §13.3.

### Setup
1. Install **AutoIt 3.3.16.1 or later** (tested with 3.3.18.0). Run it **as administrator**. The first log line says `admin yes` or `admin NO`.
2. Start Guild Wars (no add-ons), log in, then run `BotsHub.au3`.
3. Pick the character and the farm, then press **Start**. If you already attached from the Tools tab, Start reuses that attachment.

### Logs and statistics (new)
All of these are written to `logs/` next to `BotsHub.au3` (the folder is created automatically):

| File | Content |
|---|---|
| `logs/botshub-YYYY-MM-DD-<character>.log` | Every log line, with time and level (`[INFO]`, `[WARN]`, `[ERROR]`...). Written in headless mode too. Lines logged before a character is attached go to `botshub-YYYY-MM-DD.log`. |
| `logs/runs-YYYY-MM-DD.csv` | One line per run: `date,time,character,farm,result,duration_s,total_gold`. Opens in Excel or Sheets. |

- After every run the console shows a `Session:` line with the runs, successes, failures, success rate and average duration.
- On exit, a `Session summary` adds the gold change and the warning and error counts.
- When asking for help, send the log file: its first line describes your setup (version, AutoIt, OS, admin rights).

### Configuration
- `conf/farm/*.json` works as before. Missing keys now **keep their default value**, so old or hand-edited files are safe.
- All options are saved, including *Return on death*, *Log chest spawns*, *Auto-attach*, *Extract selected components before selling*, *Skip Am Fah* and every Follower setting.
- Invalid JSON is reported and ignored, so your current settings stay.
- At load time, a `Config check:` warning flags:
  - an unknown farm, district or loot configuration;
  - empty hero names or builds;
  - conflicting faction options.
- New optional key, `"run": { "debug_logging": true }`: turns on Debug-level logging (very verbose). The default is `false`.
- Advanced: every timeout and limit is in `lib/BotsHub-Constants.au3`, each with a comment.

### Safety nets (new)
| Behaviour | Default |
|---|---|
| Portal, NPC and dungeon entries retry, then fail the run instead of looping forever | 5 attempts (setups: 3) |
| Fights move on from a target that can't be killed | 60 s per target |
| Skill casts and recharge waits can't block | 10 s / 90 s |
| A run that takes far too long is failed | max(4× the farm's expected duration, 30 min) |
| A run stuck on the same thing (v24 stuck watchdog, v30: towns too): maps back to town, counts a failed run, redoes the farm setup, keeps going | 2 min without progress |
| Disconnect check before each run: presses Reconnect, else pauses | 3 attempts |
| *Return on death* option | fails the run at the first party wipe |
| Pause between runs | random 1–3 s |

None of these should trigger during normal play. If one does, the log names the farm and the step.

### Headless (master/slave) mode
`BotsHub.au3 <slaveIndex> <PID> <character> <farm>` works as before. Differences:
- Each slave writes its own log file.
- Errors (wrong PID, unknown farm, attach failure) are logged, any dialog closes by itself after 30 s, and the slave exits with **code 1**. Before, it hung on a modal box.
- Showing and hiding the slave GUI no longer creates duplicate windows.

---

## Features
- Unified interface shared by all bots 🖥️
- Shared inventory, loot, farm, and title tracking 🎯
- Configurable item handling (pickup, identify, salvage, sell, buy, store) 📦
- Farm UI with build, equipment, and contextual information 🛡️
- Modular, plug-and-play bot system 🔌

---

## Existing Bots

### Farms

| Farm									| Purpose / Drops																|
| ------------------------------------- | ----------------------------------------------------------------------------- |
| A Chance Encounter					| Ministerial Commendations, faction skins										|
| Auspicious Beginnings					| War Supplies, festive items, gold, Vanguard points							|
| Cathedral of Flames (Cryptos)			| Rin Relics, Diessa Chalices, bones											|
| Dajkah Inlet Challenge				| Sunspear armor hero pieces													|
| Drake Flesh							| Drake flesh (kebob), golds													|
| Drazach Thicket (DragonMoss)			| Fibers, Gothic Defender, Echovald Shield, Ornate Shield						|
| Fish in a Barrel (Kournans)			| Q8 items, runes																|
| Glint’s Challenge						| Cloth of Brotherhood, hero armor, Destroyer cores								|
| Jaya Bluffs (Sensali)					| Feathers, bones																|
| Minotaurs								| Materials																		|
| Missing Daughter (Jade Brotherhood)	| Q8 items, jade bracelets														|
| Moddok Crevice (Corsairs)				| Runes, Colossal Scimitar, Q8													|
| Nexus Challenge						| Mysterious armor hero pieces													|
| Presearing Iris						| Iris																			|
| Raptors								| Festive items, golds, materials, Asura points									|
| Skale Fins							| Skale fins (soup), low reqs													|
| Skrees								| Spears, feathers, paragon normal and elite tomes								|
| Spirit Slaves							| Q8 items, dust, bones															|
| Vaettirs								| Festive items, golds, materials, Norn points									|
| Wajjun Bazaar (Mantids)				| Celestial weapons, chitin, dust												|
| Zodiac								| Zodiac weapons, Ironwing bows, Vertebreakers, Nephilim Gavels, Amber chunks	|

### Vanquishes / Titles

| Area							| Title / Points						|
| ----------------------------- | ------------------------------------- |
| Ferndale						| Kurzick								|
| Drazach						| Kurzick								|
| Mount Qinkai					| Luxon									|
| Silent Surf					| Luxon									|
| Sulfurous Wastes				| Sunspear, Lightbringer				|
| Mirror of Lyss				| Lightbringer							|
| Magus Stones					| Asura									|
| Varajar Fells					| Norn									|
| Dalada Uplands				| Vanguard								|
| Secret Lair of the Snowmen	| Deldrimor								|
| Pre-Searing					| Legendary Defender of Ascalon (LDOA)	|

### Dungeons / Elite Zones

| Area							| Drops																	|
| ----------------------------- | --------------------------------------------------------------------- |
| Bogroot						| Froggy																|
| Shards of Orr (SoO)			| Dragon Bone Staff														|
| Slaver’s Exile				| Voltaic Spears														|
| FoW							| Obsidian Shards, Obsidian Edge, Shadow weapons						|
| FoW – Tower of Courage		| Obsidian Shards, dust													|
| Domain of Anguish				| Gemstones																|
| City of Torc'qua				| Margonite Gemstones													|
| Ravenheart Gloom				| Torment Gemstones														|
| Stygian Veil					| Stygian Gemstones														|
| Tunnels of the Forsaken		| E-blade																|
| Underworld					| Globs of Ectoplasm													|
| Kilroy						| Alcohol, Glacial Blades, Stone Summit Shield, Summit Warlord Shield	|

### Chest Runs

| Area		| Possible Drops											|
| --------- | --------------------------------------------------------- |
| Boreal	| Glacial Blades											|
| Pongmei	| Faction skins, Q8											|
| Tasca		| Magma Shield, Stone Summit Shield, Summit Warlord Shield	|

### Others
- Follower bot
- Inventory management

---

## Repository Structure
- `BotsHub.au3`: Main launcher script that acts as a hub for all bots.
- `/lib/`: Common shared utility files and GWA2 interfacing logic.
- `/src/`: Plug-and-play bots. Each one is modular and can be independently added or removed.
- `CREDITS.md`, `LICENSE`, `README.md`

---

## Adding Your Own Bots
1. Add `<Name of your bot>.au3` to `src/<folder>/` 📂
2. Add an include line in `BotsHub.au3`:
	```autoit
	#include 'src/<folder>/<Name>.au3'
	```
3. Add the farm to the `$AVAILABLE_FARMS` list with its name <Name> (use | as a separator) ✏️
4. Add a line in `FillFarmMap` with your farm function, inventory space, and duration:
	```autoit
	AddFarmToFarmMap('Asuran', AsuranTitleFarm, 5, $ASURAN_FARM_DURATION)
	```
And that’s it! 🎉 No duplicated logic required.

---

## FAQ
Before reporting bugs, make sure you are using the latest version of AutoIt and BotsHub ⚡

<details>
<summary><strong>Q: The bot is stuck and does not continue or return to town.</strong></summary>

Too many possible causes. Please provide:
- Bot name
- When it stopped (during farm, inventory, travel, etc.)
- Last console logs
- Whether it happens consistently
</details>

<details>
<summary><strong>Q: The game crashes or disconnects.</strong></summary>

Some degree of crash or disconnect is normal and happens to all bots.
If it happens too often, make sure you are running the game at lowest quality and with no add-ons.
</details>

<details>
<summary><strong>Q: My character's name does not appear in the left dropdown.</strong></summary>

Check your system locale. Set it to English and that should fix the problem.
</details>

<details>
<summary><strong>Q: How can I change what items the bot sells?</strong></summary>

Most options are configurable in the interface.  
Advanced customization requires manual file edits ✏️
</details>

<details>
<summary><strong>Q: Heroes are not added or skill bars are not set.</strong></summary>

Not all farms auto-configure heroes.  
Some require manual setup in the **Team** tab or in-game 🛡️
</details>

<details>
<summary><strong>Q: Error: 'Variable subscript badly formatted' (`Local $map[]`).</strong></summary>

Your AutoIt version is too old.  
Update to **AutoIt ≥ 3.3.16.1** 🆙
</details>

<details>
<summary><strong>Q: Error: 'not accessible variable' in `/lib/Utils.au3`.</strong></summary>

Reinstall AutoIt 🔄
</details>

<details>
<summary><strong>Q: The bot sold an expensive item. Can it be recovered?</strong></summary>

No. Items cannot be recovered.  
Always store valuable items before running the bot 💎
</details>

<details>
<summary><strong>Q: Data tracking does not work ('Failed to load sqlite').</strong></summary>

SQLite must be installed and accessible by AutoIt.  
DLL and UDF files are included in the repository
</details>

<details>
<summary><strong>Q: Do you have a 'YYY' bot?</strong></summary>

If it is not listed, it does not exist ❌  
PvP bots will not be added  
You are welcome to create and contribute new bots 👍
</details>

---

## 📌 Planned Features

- 💡🕓 **Improve the Pongmei chest farm with Tasca chest farm capabilities**
- 💡💭 **Pahnai Salad - Iboga Petals farm**
- 💡💭 **Bandit raid**
- 💡💭 **Kappa farm** (shield)
- 🧠💭 **Nicholas the traveler items (gifties)**
- 🧠💭 **Improve crash recovery**

**Legend:**  
Priority → 🔥 High | ⚡ Medium | 💡 Low | 🧠 None  
Status → ✅ Done | 🔄 In progress | 🛠️ Broken | 🕓 Planned | 💭 Wishlist

---

## Dependencies
- [AutoIt JSON UDF](https://github.com/Sylvan86/autoit-json-udf) 📝
- [SQLite UDF](https://www.autoitscript.com/autoit3/pkgmgr/sqlite/) 💾

---

## License
Apache License 2.0 ⚖️ — see the [LICENSE](LICENSE) file

---

## Author

Made by caustic-kronos 😎  
Also known as: Kronos, Night, Svarog

Feel free to reach out or contribute! 💬