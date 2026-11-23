#CS ===========================================================================
; v33: 'Titles' tab (before 'Farm infos'), approved mockup tools/out/v33_titles_mockup.png. No scrolling, three sections:
;
; 1. REPUTATION TITLES (2 x 4): gold name, progress bar to the max rank, Session, Total (current points).
;    Max points (wiki.guildwars.com, verified v33):
;      Asura / Deldrimor / Norn / Ebon Vanguard: rank 10 at 160,000
;        https://wiki.guildwars.com/wiki/Asura_rank  .../Deldrimor_rank  .../Norn_rank  .../Ebon_Vanguard_rank
;      Kurzick / Luxon (allegiance, account): rank 12 at 10,000,000      https://wiki.guildwars.com/wiki/Allegiance_rank
;      Lightbringer: rank 8 at 50,000                                    https://wiki.guildwars.com/wiki/Lightbringer_rank
;      Sunspear: rank 10 at 50,000                                       https://wiki.guildwars.com/wiki/Sunspear_rank
; 2. ZAISHEN CHEST: Zaishen rank (account), 5 points per Zaishen Key opened on a Zaishen Chest, rank 12 at 100,000 (20,000 keys)
;      https://wiki.guildwars.com/wiki/Zaishen_rank  -> keys needed = ceil(max(0, 100000 - points) / 5), 'Maxed' when done;
;      keys owned = Zaishen Keys in inventory + Xunlai storage (the Items panel read).
; 3. CONSUMABLE TITLES: Sweet Tooth | Drunkard | Party Animal, each max (tier 2) 10,000 points:
;      https://wiki.guildwars.com/wiki/Sweet_Tooth  .../Drunkard  .../Party_Animal
;    points, Session, points available in the INVENTORY (bags 1-5, never storage) = sum qty x points of the items the button
;    would use, and a button that uses them one at a time (TitlesConsumeRun).
;
; GWA2 title getters = title array index = GWCA TitleID (GWCA Include/GWCA/Constants/Constants.h, enum class TitleID):
;   Kurzick 5, Luxon 6, Drunkard 7, Sunspear 17, Lightbringer 20, Sweets 34, Asuran 38, Deldrimor 39, Vanguard 40, Norn 41,
;   Party 43, Zaishen 44 (GetKurzickTitle ... GetZaishenTitle in lib/GWA2.au3 use exactly these indexes).
;
; Session = points now - a per-character baseline (independent of storage): taken when attached, the map fully loaded
; (v30 IsMapReadyNow) and two refreshes in a row read the same points; blank until then; a character change re-baselines.
; Refresh: from ItemsPanelRefresh (same rate and safe points, never inside a farm run).
#CE ===========================================================================
#include-once
#include 'BotsHub-Theme-Colors.au3'

Global Const $TITLES_REP_KEYS[] = ['asura', 'deldrimor', 'norn', 'vanguard', 'kurzick', 'luxon', 'lightbringer', 'sunspear']
Global Const $TITLES_REP_NAMES[] = ['Asura', 'Deldrimor', 'Norn', 'Vanguard', 'Kurzick', 'Luxon', 'Lightbringer', 'Sunspear']
Global Const $TITLES_REP_MAX[] = [160000, 160000, 160000, 160000, 10000000, 10000000, 50000, 50000]
Global Const $TITLES_CONSUME_KEYS[] = ['sweets', 'alcohol', 'party']
Global Const $TITLES_CONSUME_HEADERS[] = ['Sweets - Sweet Tooth', 'Alcohol - Drunkard', 'Party - Party Animal']
Global Const $TITLES_CONSUME_TITLE_NAMES[] = ['Sweet Tooth', 'Drunkard', 'Party Animal']
Global Const $TITLES_CONSUME_BUTTONS[] = ['Eat all sweets', 'Drink all alcohol', 'Use all party items']
Global Const $TITLES_CONSUME_WHERE[] = ['Town sweets in outposts, combat sweets in explorables. Skips DP / morale sweets and War Supplies.', _
	'Any PvE area (outpost or explorable). Stops when the points stop increasing.', _
	'Outposts / towns only (not PvP). Tonics: one per 5 s. Crate of Fireworks: guild hall only.']
Global Const $TITLES_CONSUME_MAX = 10000
Global Const $ZAISHEN_TITLE_MAX_POINTS = 100000, $ZAISHEN_POINTS_PER_KEY = 5
; all title keys with a Session (baseline covers every one of them)
Global Const $TITLES_ALL_KEYS[] = ['asura', 'deldrimor', 'norn', 'vanguard', 'kurzick', 'luxon', 'lightbringer', 'sunspear', 'zaishen', 'sweets', 'alcohol', 'party']

; where an item awards points (TitlesItemUsableHere)
Global Const $TITLES_AREA_TOWN = 'town'					; sweets with an outpost speed boost: outposts / towns only
Global Const $TITLES_AREA_EXPLORABLE = 'explorable'		; combat sweets: PvE explorable areas only
Global Const $TITLES_AREA_PVE = 'pve'					; alcohol: any PvE area
Global Const $TITLES_AREA_FESTIVE = 'festive'			; festive items: towns / outposts / guild halls, not PvP outposts
Global Const $TITLES_AREA_GUILDHALL = 'guildhall'		; Crate of Fireworks: guild hall only
Global Const $TITLES_AREA_SKIP_DP = 'skip-dp'			; needs death penalty / low morale: never used by the button
Global Const $TITLES_AREA_SKIP_KEEP = 'skip-keep'		; excluded on request (War Supplies)
Global Const $TITLES_TONIC_DELAY_MS = 5200				; Tonic Tipsiness: 5 s after a standard tonic (wiki Tonic_Tipsiness)
Global Const $TITLES_ITEM_DELAY_MS = 900
Global Const $TITLES_POINTS_WAIT_MS = 2500
Global $titles_sleep_scale = 1							; tests: 0 (no real waiting)

; GUI
Global $titles_tab_built = False
Global $titles_rep_session[8], $titles_rep_total[8], $titles_rep_fill[8], $titles_rep_rest[8]
Global $titles_zaishen_points = 0, $titles_zaishen_fill = 0, $titles_zaishen_rest = 0, $titles_zaishen_session = 0
Global $titles_zaishen_needed = 0, $titles_zaishen_owned = 0
Global $titles_consume_points[3], $titles_consume_fill[3], $titles_consume_rest[3], $titles_consume_session[3]
Global $titles_consume_avail[3], $titles_consume_button[3]
Global $titles_colored[0][3]
Global $titles_shown[]
Global Const $TITLES_REP_BAR_WIDTH = 90, $TITLES_ZAISHEN_BAR_WIDTH = 250, $TITLES_CONSUME_WIDTH = 196
; Session baseline
Global $titles_base[], $titles_pending[], $titles_char = '', $titles_ready = False
; consume tables (built at run time: the item constants are included after the GUI file)
Global $titles_items_sweets = Null, $titles_items_alcohol = Null, $titles_items_party = Null


#Region Item tables
;~ [n][4] = model ID, points, area, name. Points and areas: wiki.guildwars.com, verified v33 (model IDs cross-checked by name
;~ against Py4GW ModelID and GWCA ItemIDs.h).
Func TitlesItemTable($titleKey)
	TitlesLoadItemTables()
	Switch $titleKey
		Case 'sweets'
			Return $titles_items_sweets
		Case 'alcohol'
			Return $titles_items_alcohol
		Case 'party'
			Return $titles_items_party
	EndSwitch
	Return Null
EndFunc


Func TitlesAddItem(ByRef $table, $modelID, $points, $area, $name)
	Local $n = UBound($table)
	ReDim $table[$n + 1][4]
	$table[$n][0] = $modelID
	$table[$n][1] = $points
	$table[$n][2] = $area
	$table[$n][3] = $name
EndFunc


Func TitlesLoadItemTables()
	If IsArray($titles_items_sweets) Then Return
	; Sweets - https://wiki.guildwars.com/wiki/Sweet (points, 'Consumption Area', 'Spammable')
	Local $sweets[0][4]
	TitlesAddItem($sweets, $ID_FRUITCAKE, 1, $TITLES_AREA_TOWN, 'Fruitcake')
	TitlesAddItem($sweets, $ID_MANDRAGOR_ROOT_CAKE, 1, $TITLES_AREA_TOWN, 'Mandragor Root Cake')
	TitlesAddItem($sweets, $ID_SUGARY_BLUE_DRINK, 1, $TITLES_AREA_TOWN, 'Sugary Blue Drink')
	TitlesAddItem($sweets, $ID_CHOCOLATE_BUNNY, 2, $TITLES_AREA_TOWN, 'Chocolate Bunny')
	TitlesAddItem($sweets, $ID_RED_BEAN_CAKE, 2, $TITLES_AREA_TOWN, 'Red Bean Cake')
	TitlesAddItem($sweets, $ID_JAR_OF_HONEY, 2, $TITLES_AREA_TOWN, 'Jar of Honey')
	TitlesAddItem($sweets, $ID_CREME_BRULEE, 3, $TITLES_AREA_TOWN, 'Creme Brulee')
	TitlesAddItem($sweets, $ID_KRYTAN_LOKUM, 3, $TITLES_AREA_TOWN, 'Krytan Lokum')
	TitlesAddItem($sweets, $ID_MINITREATS_OF_PURITY, 3, $TITLES_AREA_TOWN, 'Minis-treat of Purity')
	TitlesAddItem($sweets, $ID_DELICIOUS_CAKE, 50, $TITLES_AREA_TOWN, 'Delicious Cake')
	TitlesAddItem($sweets, $ID_CANDY_APPLE, 1, $TITLES_AREA_EXPLORABLE, 'Candy Apple')
	TitlesAddItem($sweets, $ID_CANDY_CORN, 1, $TITLES_AREA_EXPLORABLE, 'Candy Corn')
	TitlesAddItem($sweets, $ID_GOLDEN_EGG, 1, $TITLES_AREA_EXPLORABLE, 'Golden Egg')
	TitlesAddItem($sweets, $ID_SLICE_OF_PUMPKIN_PIE, 1, $TITLES_AREA_EXPLORABLE, 'Slice of Pumpkin Pie')
	TitlesAddItem($sweets, $ID_BIRTHDAY_CUPCAKE, 2, $TITLES_AREA_EXPLORABLE, 'Birthday Cupcake')
	TitlesAddItem($sweets, $ID_GREEN_ROCK_CANDY, 3, $TITLES_AREA_EXPLORABLE, 'Green Rock Candy')
	TitlesAddItem($sweets, $ID_BLUE_ROCK_CANDY, 5, $TITLES_AREA_EXPLORABLE, 'Blue Rock Candy')
	TitlesAddItem($sweets, $ID_RED_ROCK_CANDY, 7, $TITLES_AREA_EXPLORABLE, 'Red Rock Candy')
	; not spammable: only usable with death penalty / below +10% morale (wiki Sweet_Tooth notes) - never used by the button
	TitlesAddItem($sweets, $ID_HONEYCOMB, 1, $TITLES_AREA_SKIP_DP, 'Honeycomb')
	TitlesAddItem($sweets, $ID_PUMPKIN_COOKIE, 1, $TITLES_AREA_SKIP_DP, 'Pumpkin Cookie')
	TitlesAddItem($sweets, $ID_REFINED_JELLY, 1, $TITLES_AREA_SKIP_DP, 'Refined Jelly')
	TitlesAddItem($sweets, $ID_WINTERGREEN_CC, 1, $TITLES_AREA_SKIP_DP, 'Wintergreen Candy Cane')
	TitlesAddItem($sweets, $ID_RAINBOW_CC, 1, $TITLES_AREA_SKIP_DP, 'Rainbow Candy Cane')
	TitlesAddItem($sweets, $ID_PEPPERMINT_CC, 2, $TITLES_AREA_SKIP_DP, 'Peppermint Candy Cane')
	; 1 point, explorable - excluded on request (an exchange item)
	TitlesAddItem($sweets, $ID_WAR_SUPPLIES, 1, $TITLES_AREA_SKIP_KEEP, 'War Supplies')
	$titles_items_sweets = $sweets

	; Alcohol - https://wiki.guildwars.com/wiki/Alcohol (any PvE area; points per drink since the 2011-03-03 update)
	Local $alcohol[0][4]
	TitlesAddItem($alcohol, $ID_BOTTLE_OF_RICE_WINE, 1, $TITLES_AREA_PVE, 'Bottle of Rice Wine')
	TitlesAddItem($alcohol, $ID_EGGNOG, 1, $TITLES_AREA_PVE, 'Eggnog')
	TitlesAddItem($alcohol, $ID_DWARVEN_ALE, 1, $TITLES_AREA_PVE, 'Dwarven Ale')
	TitlesAddItem($alcohol, $ID_HARD_APPLE_CIDER, 1, $TITLES_AREA_PVE, 'Hard Apple Cider')
	TitlesAddItem($alcohol, $ID_HUNTERS_ALE, 1, $TITLES_AREA_PVE, 'Hunter''s Ale')
	TitlesAddItem($alcohol, $ID_BOTTLE_OF_JUNIBERRY_GIN, 1, $TITLES_AREA_PVE, 'Bottle of Juniberry Gin')
	TitlesAddItem($alcohol, $ID_SHAMROCK_ALE, 1, $TITLES_AREA_PVE, 'Shamrock Ale')
	TitlesAddItem($alcohol, $ID_BOTTLE_OF_VABBIAN_WINE, 1, $TITLES_AREA_PVE, 'Bottle of Vabbian Wine')
	TitlesAddItem($alcohol, $ID_VIAL_OF_ABSINTHE, 1, $TITLES_AREA_PVE, 'Vial of Absinthe')
	TitlesAddItem($alcohol, $ID_WITCHS_BREW, 1, $TITLES_AREA_PVE, 'Witch''s Brew')
	TitlesAddItem($alcohol, $ID_ZEHTUKAS_JUG, 1, $TITLES_AREA_PVE, 'Zehtuka''s Jug')
	TitlesAddItem($alcohol, $ID_AGED_DWARVEN_ALE, 3, $TITLES_AREA_PVE, 'Aged Dwarven Ale')
	TitlesAddItem($alcohol, $ID_AGED_HUNTERS_ALE, 3, $TITLES_AREA_PVE, 'Aged Hunter''s Ale')
	TitlesAddItem($alcohol, $ID_BOTTLE_OF_GROG, 3, $TITLES_AREA_PVE, 'Bottle of Grog')
	TitlesAddItem($alcohol, $ID_FLASK_OF_FIREWATER, 3, $TITLES_AREA_PVE, 'Flask of Firewater')
	TitlesAddItem($alcohol, $ID_KEG_OF_AGED_HUNTERS_ALE, 3, $TITLES_AREA_PVE, 'Keg of Aged Hunter''s Ale')
	TitlesAddItem($alcohol, $ID_KRYTAN_BRANDY, 3, $TITLES_AREA_PVE, 'Krytan Brandy')
	TitlesAddItem($alcohol, $ID_SPIKED_EGGNOG, 3, $TITLES_AREA_PVE, 'Spiked Eggnog')
	TitlesAddItem($alcohol, $ID_BATTLE_ISLE_ICED_TEA, 50, $TITLES_AREA_PVE, 'Battle Isle Iced Tea')
	$titles_items_alcohol = $alcohol

	; Festive items - https://wiki.guildwars.com/wiki/Festive_item (points); towns/outposts/guild halls, not PvP outposts.
	; Tonics: 2 points except Minutely Mad King 3, Mysterious 5, Spooky 25, Zaishen 3 (https://wiki.guildwars.com/wiki/Tonic);
	; Crate of Fireworks: guild hall only (https://wiki.guildwars.com/wiki/Crate_of_Fireworks).
	Local $party[0][4]
	TitlesAddItem($party, $ID_BOTTLE_ROCKET, 1, $TITLES_AREA_FESTIVE, 'Bottle Rocket')
	TitlesAddItem($party, $ID_CHAMPAGNE_POPPER, 1, $TITLES_AREA_FESTIVE, 'Champagne Popper')
	TitlesAddItem($party, $ID_GHOST_IN_THE_BOX, 1, $TITLES_AREA_FESTIVE, 'Ghost-in-the-Box')
	TitlesAddItem($party, $ID_SNOWMAN_SUMMONER, 1, $TITLES_AREA_FESTIVE, 'Snowman Summoner')
	TitlesAddItem($party, $ID_SPARKLER, 1, $TITLES_AREA_FESTIVE, 'Sparkler')
	TitlesAddItem($party, $ID_SQUASH_SERUM, 1, $TITLES_AREA_FESTIVE, 'Squash Serum')
	TitlesAddItem($party, $ID_BEETLE_JUICE_TONIC, 2, $TITLES_AREA_FESTIVE, 'Beetle Juice Tonic')
	TitlesAddItem($party, $ID_COTTONTAIL_TONIC, 2, $TITLES_AREA_FESTIVE, 'Cottontail Tonic')
	TitlesAddItem($party, $ID_FROSTY_TONIC, 2, $TITLES_AREA_FESTIVE, 'Frosty Tonic')
	TitlesAddItem($party, $ID_MISCHIEVIOUS_TONIC, 2, $TITLES_AREA_FESTIVE, 'Mischievous Tonic')
	TitlesAddItem($party, $ID_SINISTER_AUTOMATONIC_TONIC, 2, $TITLES_AREA_FESTIVE, 'Sinister Automatonic Tonic')
	TitlesAddItem($party, $ID_TRANSMOGRIFIER_TONIC, 2, $TITLES_AREA_FESTIVE, 'Transmogrifier Tonic')
	TitlesAddItem($party, $ID_YULETIDE_TONIC, 2, $TITLES_AREA_FESTIVE, 'Yuletide Tonic')
	TitlesAddItem($party, $ID_CEREBRAL_TONIC, 2, $TITLES_AREA_FESTIVE, 'Cerebral Tonic')
	TitlesAddItem($party, $ID_SEARING_TONIC, 2, $TITLES_AREA_FESTIVE, 'Searing Tonic')
	TitlesAddItem($party, $ID_ABYSSAL_TONIC, 2, $TITLES_AREA_FESTIVE, 'Abyssal Tonic')
	TitlesAddItem($party, $ID_UNSEEN_TONIC, 2, $TITLES_AREA_FESTIVE, 'Unseen Tonic')
	TitlesAddItem($party, $ID_PHANTASMAL_TONIC, 2, $TITLES_AREA_FESTIVE, 'Phantasmal Tonic')
	TitlesAddItem($party, $ID_AUTOMATONIC_TONIC, 2, $TITLES_AREA_FESTIVE, 'Automatonic Tonic')
	TitlesAddItem($party, $ID_BOREAL_TONIC, 2, $TITLES_AREA_FESTIVE, 'Boreal Tonic')
	TitlesAddItem($party, $ID_TRAPDOOR_TONIC, 2, $TITLES_AREA_FESTIVE, 'Trapdoor Tonic')
	TitlesAddItem($party, $ID_MACABRE_TONIC, 2, $TITLES_AREA_FESTIVE, 'Macabre Tonic')
	TitlesAddItem($party, $ID_SKELETONIC_TONIC, 2, $TITLES_AREA_FESTIVE, 'Skeletonic Tonic')
	TitlesAddItem($party, $ID_GELATINOUS_TONIC, 2, $TITLES_AREA_FESTIVE, 'Gelatinous Tonic')
	TitlesAddItem($party, $ID_ABOMINABLE_TONIC, 2, $TITLES_AREA_FESTIVE, 'Abominable Tonic')
	TitlesAddItem($party, $ID_MINUTELY_MAD_KING_TONIC, 3, $TITLES_AREA_FESTIVE, 'Minutely Mad King Tonic')
	TitlesAddItem($party, $ID_ZAISHEN_TONIC, 3, $TITLES_AREA_FESTIVE, 'Zaishen Tonic')
	TitlesAddItem($party, $ID_MYSTERIOUS_TONIC, 5, $TITLES_AREA_FESTIVE, 'Mysterious Tonic')
	TitlesAddItem($party, $ID_SPOOKY_TONIC, 25, $TITLES_AREA_FESTIVE, 'Spooky Tonic')
	TitlesAddItem($party, $ID_DISCO_BALL, 7, $TITLES_AREA_FESTIVE, 'Disco Ball')
	TitlesAddItem($party, $ID_PARTY_BEACON, 50, $TITLES_AREA_FESTIVE, 'Party Beacon')
	TitlesAddItem($party, $ID_CRATE_OF_FIREWORKS, 3, $TITLES_AREA_GUILDHALL, 'Crate of Fireworks')
	$titles_items_party = $party
EndFunc


;~ Every model ID of the three tables (the Items panel counts them in the inventory read)
Func TitlesAllConsumableModelIDs()
	Local $ids[0]
	For $key In $TITLES_CONSUME_KEYS
		Local $table = TitlesItemTable($key)
		For $i = 0 To UBound($table) - 1
			_ArrayAddSimple($ids, $table[$i][0])
		Next
	Next
	Return $ids
EndFunc


Func _ArrayAddSimple(ByRef $array, $value)
	ReDim $array[UBound($array) + 1]
	$array[UBound($array) - 1] = $value
EndFunc


;~ (pure) True when the button uses this item at all (DP/morale sweets and War Supplies never)
Func TitlesItemIsConsumable($area)
	Return $area <> $TITLES_AREA_SKIP_DP And $area <> $TITLES_AREA_SKIP_KEEP
EndFunc


;~ (pure) True when PvP rules apply to an outpost of that region type (no festive items there)
Func TitlesIsPvPRegion($regionType)
	Switch $regionType
		Case 0, 1, 3, 7, 11, 12, 15, 16	; alliance battle, arena, guild battle area, competitive mission, Zaishen battle, Heroes' Ascent, hero battle
			Return True
	EndSwitch
	Return False
EndFunc


;~ (pure) '' when the item awards points on this map, else the reason. $mapType: $ID_OUTPOST / $ID_EXPLORABLE / $ID_LOADING.
Func TitlesItemUsableHere($area, $mapType, $regionType)
	If $area == $TITLES_AREA_SKIP_DP Then Return 'only usable with death penalty / low morale - skipped'
	If $area == $TITLES_AREA_SKIP_KEEP Then Return 'kept (excluded from the button)'
	If $mapType <> $ID_OUTPOST And $mapType <> $ID_EXPLORABLE Then Return 'map loading'
	Switch $area
		Case $TITLES_AREA_TOWN
			If $mapType <> $ID_OUTPOST Then Return 'outposts / towns only'
		Case $TITLES_AREA_EXPLORABLE
			If $mapType <> $ID_EXPLORABLE Then Return 'explorable areas only'
			If TitlesIsPvPRegion($regionType) Then Return 'PvE only'
		Case $TITLES_AREA_PVE
			If TitlesIsPvPRegion($regionType) Then Return 'PvE only'
		Case $TITLES_AREA_FESTIVE
			If $mapType <> $ID_OUTPOST Then Return 'outposts / towns only'
			If TitlesIsPvPRegion($regionType) Then Return 'not in PvP outposts'
		Case $TITLES_AREA_GUILDHALL
			If $mapType <> $ID_OUTPOST Or $regionType <> $ID_REGIONTYPE_GUILDHALL Then Return 'guild hall only'
	EndSwitch
	Return ''
EndFunc


;~ (pure) [points, items] in the inventory counts (Map modelID -> qty) for what the button can use (anywhere)
Func TitlesInventoryPoints($titleKey, ByRef $inventory)
	Local $result[2] = [0, 0]
	Local $table = TitlesItemTable($titleKey)
	For $i = 0 To UBound($table) - 1
		If Not TitlesItemIsConsumable($table[$i][2]) Then ContinueLoop
		If Not MapExists($inventory, $table[$i][0]) Then ContinueLoop
		Local $quantity = $inventory[$table[$i][0]]
		$result[0] += $quantity * $table[$i][1]
		$result[1] += $quantity
	Next
	Return $result
EndFunc
#EndRegion Item tables


#Region Points and baseline
;~ Current points per title key (empty map when $readable is False)
Func TitlesReadPoints($readable)
	Local $points[]
	If Not $readable Then Return $points
	For $key In $TITLES_ALL_KEYS
		$points[$key] = TitlesReadOne($key)
	Next
	Return $points
EndFunc


;~ One title's points (GWA2 getter = GWCA TitleID index, see header)
Func TitlesReadOne($key)
	Switch $key
		Case 'asura'
			Return GetAsuraTitle()
		Case 'deldrimor'
			Return GetDeldrimorTitle()
		Case 'norn'
			Return GetNornTitle()
		Case 'vanguard'
			Return GetVanguardTitle()
		Case 'kurzick'
			Return GetKurzickTitle()
		Case 'luxon'
			Return GetLuxonTitle()
		Case 'lightbringer'
			Return GetLightbringerTitle()
		Case 'sunspear'
			Return GetSunspearTitle()
		Case 'zaishen'
			Return GetZaishenTitle()
		Case 'sweets'
			Return GetSweetTitle()
		Case 'alcohol'
			Return GetDrunkardTitle()
		Case 'party'
			Return GetPartyTitle()
	EndSwitch
	Return 0
EndFunc


;~ Baseline: dropped on a character change, taken when two readable reads in a row are equal. True when it exists.
Func TitlesObserve($character, ByRef $points, $readable)
	If $titles_char <> '' And $character <> $titles_char Then TitlesResetBaseline()
	If $titles_ready Then Return True
	If Not $readable Or $character == '' Or UBound(MapKeys($points)) <> UBound($TITLES_ALL_KEYS) Then Return False
	$titles_char = $character
	Local $stable = UBound(MapKeys($titles_pending)) == UBound($TITLES_ALL_KEYS)
	For $key In $TITLES_ALL_KEYS
		If Not $stable Then ExitLoop
		If $titles_pending[$key] <> $points[$key] Then $stable = False
	Next
	If Not $stable Then
		$titles_pending = $points
		Return False
	EndIf
	$titles_base = $points
	$titles_ready = True
	Return True
EndFunc


Func TitlesResetBaseline()
	Local $empty[]
	$titles_base = $empty
	$titles_pending = $empty
	$titles_char = ''
	$titles_ready = False
EndFunc


;~ (pure) session gain of one title, Null without baseline / current read
Func TitlesDelta($key, ByRef $points)
	If Not $titles_ready Or Not MapExists($points, $key) Or Not MapExists($titles_base, $key) Then Return Null
	Return $points[$key] - $titles_base[$key]
EndFunc


;~ (pure) Zaishen keys still needed to reach the max rank: ceil(max(0, 100000 - points) / 5)
Func ZaishenKeysNeeded($points)
	Local $missing = $ZAISHEN_TITLE_MAX_POINTS - Number($points)
	If $missing <= 0 Then Return 0
	Return Ceiling($missing / $ZAISHEN_POINTS_PER_KEY)
EndFunc


;~ (pure) 1234567 -> '1,234,567'
Func TitlesFormatNumber($value)
	Local $text = String(Abs(Int($value))), $out = ''
	While StringLen($text) > 3
		$out = ',' & StringRight($text, 3) & $out
		$text = StringTrimRight($text, 3)
	WEnd
	Return (Int($value) < 0 ? '-' : '') & $text & $out
EndFunc


;~ (pure) Session text: '' without baseline, '+N' / '0' / '-N'
Func TitlesFormatDelta($delta)
	If IsKeyword($delta) == 2 Then Return ''
	If $delta > 0 Then Return '+' & TitlesFormatNumber($delta)
	Return TitlesFormatNumber($delta)
EndFunc


;~ (pure) fraction 0..1 of the max
Func TitlesFraction($points, $max)
	If $max <= 0 Then Return 0
	If $points >= $max Then Return 1
	If $points <= 0 Then Return 0
	Return $points / $max
EndFunc


;~ (pure) Zaishen lines: [keys needed text, owned text]. $owned < 0 = unknown.
Func ZaishenKeyTexts($points, $owned, $ownedMark = '')
	Local $texts[2]
	Local $needed = ZaishenKeysNeeded($points)
	$texts[0] = ($needed == 0) ? 'Maxed' : TitlesFormatNumber($needed)
	If $owned < 0 Then
		$texts[1] = 'Keys owned (inventory + storage): -'
	ElseIf $needed == 0 Then
		$texts[1] = 'Keys owned (inventory + storage): ' & TitlesFormatNumber($owned) & $ownedMark & ' - title maxed'
	ElseIf $owned >= $needed Then
		$texts[1] = 'Keys owned (inventory + storage): ' & TitlesFormatNumber($owned) & $ownedMark & ' - enough to max'
	Else
		$texts[1] = 'Keys owned (inventory + storage): ' & TitlesFormatNumber($owned) & $ownedMark & ' - ' & TitlesFormatNumber($needed - $owned) & ' short'
	EndIf
	Return $texts
EndFunc
#EndRegion Points and baseline


#Region GUI
Func TitlesReg($id, $color, $bk = -1)
	Local $n = UBound($titles_colored)
	ReDim $titles_colored[$n + 1][3]
	$titles_colored[$n][0] = $id
	$titles_colored[$n][1] = $color
	$titles_colored[$n][2] = $bk
	Return $id
EndFunc


;~ Label; right-aligned texts get a trailing space (Wine's right-aligned statics clip the last glyph of texts with several commas)
Func TitlesLabel($text, $x, $y, $w, $h, $color, $right = False, $bold = False)
	Local $id = GUICtrlCreateLabel($right ? $text & ' ' : $text, $x, $y, $w, $h, $right ? 0x0002 : 0)
	If $bold Then GUICtrlSetFont($id, 8.5, 700)
	Return TitlesReg($id, $color)
EndFunc


;~ Progress bar = two side-by-side labels (Wine ignores progress-bar colours); $fill / $rest receive their IDs
Func TitlesBar($x, $y, $w, $h, ByRef $fill, ByRef $rest)
	$fill = TitlesReg(GUICtrlCreateLabel('', $x, $y, 1, $h), -1, $THEME_VALUE)
	$rest = TitlesReg(GUICtrlCreateLabel('', $x + 1, $y, $w - 1, $h), -1, $THEME_INPUT_BG)
	GUICtrlSetState($fill, $GUI_HIDE)
EndFunc


;~ Creates the tab content (call inside GUICtrlCreateTabItem('Titles')). $handler = OnEvent function of the three buttons.
Func TitlesTabCreate($handler = '')
	TitlesLabel('REPUTATION TITLES', 20, 38, 200, 16, $THEME_ACCENT_GOLD, False, True)
	Local $cols[] = [20, 326]
	For $c = 0 To 1
		TitlesLabel('Title', $cols[$c], 58, 84, 16, $THEME_TEXT_DIM)
		TitlesLabel('Progress to max', $cols[$c] + 88, 58, 92, 16, $THEME_TEXT_DIM)
		TitlesLabel('Session', $cols[$c] + 182, 58, 46, 16, $THEME_TEXT_DIM, True)
		TitlesLabel('Total', $cols[$c] + 232, 58, 66, 16, $THEME_TEXT_DIM, True)
	Next
	TitlesReg(GUICtrlCreateLabel('', 20, 75, 610, 1), -1, $THEME_HEADER_ROW_BG)
	For $i = 0 To 7
		Local $x = $cols[Int($i / 4)], $y = 80 + 20 * Mod($i, 4)
		Local $nameLabel = TitlesLabel($TITLES_REP_NAMES[$i], $x, $y, 84, 16, $THEME_ACCENT_GOLD)
		GUICtrlSetTip($nameLabel, $TITLES_REP_NAMES[$i] & ': max rank at ' & TitlesFormatNumber($TITLES_REP_MAX[$i]) & ' points')
		TitlesBar($x + 88, $y + 4, $TITLES_REP_BAR_WIDTH, 8, $titles_rep_fill[$i], $titles_rep_rest[$i])
		$titles_rep_session[$i] = TitlesLabel('', $x + 182, $y, 46, 16, $THEME_TEXT_DISABLED, True)
		$titles_rep_total[$i] = TitlesLabel('-', $x + 232, $y, 66, 16, $THEME_VALUE, True)
	Next
	TitlesReg(GUICtrlCreateLabel('', 20, 163, 610, 1), -1, $THEME_HEADER_ROW_BG)
	TitlesLabel('ZAISHEN CHEST', 20, 170, 110, 16, $THEME_ACCENT_GOLD, False, True)
	TitlesLabel('Zaishen rank: 5 points per Zaishen Key opened, max 100,000', 130, 170, 360, 16, $THEME_TEXT_DIM)
	TitlesLabel('Points', 20, 190, 50, 16, $THEME_TEXT_DIM)
	$titles_zaishen_points = TitlesLabel('-', 70, 190, 110, 16, $THEME_VALUE, True)
	TitlesBar(190, 194, $TITLES_ZAISHEN_BAR_WIDTH, 8, $titles_zaishen_fill, $titles_zaishen_rest)
	TitlesLabel('Session', 456, 190, 60, 16, $THEME_TEXT_DIM)
	$titles_zaishen_session = TitlesLabel('', 516, 190, 108, 16, $THEME_TEXT_DISABLED, True)
	TitlesLabel('Keys needed', 20, 210, 70, 16, $THEME_TEXT_DIM)
	$titles_zaishen_needed = TitlesLabel('-', 90, 210, 90, 16, $THEME_ACCENT_GOLD, True, True)
	$titles_zaishen_owned = TitlesLabel('Keys owned (inventory + storage): -', 190, 210, 440, 16, $THEME_TEXT)
	TitlesReg(GUICtrlCreateLabel('', 20, 233, 610, 1), -1, $THEME_HEADER_ROW_BG)
	TitlesLabel('CONSUMABLE TITLES', 20, 240, 160, 16, $THEME_ACCENT_GOLD, False, True)
	TitlesLabel('points available = items in your inventory bags only (storage is never used)', 180, 240, 450, 16, $THEME_TEXT_DIM)
	For $i = 0 To 2
		Local $cx = 20 + 207 * $i, $w = $TITLES_CONSUME_WIDTH
		TitlesLabel($TITLES_CONSUME_HEADERS[$i], $cx, 262, $w, 16, $THEME_ACCENT_GOLD, False, True)
		TitlesLabel('Points', $cx, 282, 70, 16, $THEME_TEXT_DIM)
		$titles_consume_points[$i] = TitlesLabel('- / 10,000', $cx + 70, 282, $w - 70, 16, $THEME_VALUE, True)
		TitlesBar($cx, 301, $w, 8, $titles_consume_fill[$i], $titles_consume_rest[$i])
		TitlesLabel('Session', $cx, 314, 70, 16, $THEME_TEXT_DIM)
		$titles_consume_session[$i] = TitlesLabel('', $cx + 70, 314, $w - 70, 16, $THEME_TEXT_DISABLED, True)
		TitlesLabel('In inventory', $cx, 332, 70, 16, $THEME_TEXT_DIM)
		$titles_consume_avail[$i] = TitlesLabel('-', $cx + 70, 332, $w - 70, 16, $THEME_VALUE, True)
		TitlesLabel($TITLES_CONSUME_WHERE[$i], $cx, 352, $w, 42, $THEME_TEXT_DISABLED)
		$titles_consume_button[$i] = GUICtrlCreateButton($TITLES_CONSUME_BUTTONS[$i], $cx, 404, $w, 28)
		GUICtrlSetTip($titles_consume_button[$i], 'Uses every ' & $TITLES_CONSUME_TITLE_NAMES[$i] & ' item in your inventory that awards points on this map, one at a time.' & @CRLF _
			& 'Never touches storage. Not during a farm run. Stops on map change / disconnect. Each item and the points gained are logged.')
		If $handler <> '' Then GUICtrlSetOnEvent($titles_consume_button[$i], $handler)
	Next
	$titles_tab_built = True
EndFunc


;~ Colours of the tab's labels (call after ThemeApplyDark, which recolours every static)
Func TitlesTabApplyColors()
	For $i = 0 To UBound($titles_colored) - 1
		If $titles_colored[$i][1] <> -1 Then GUICtrlSetColor($titles_colored[$i][0], $titles_colored[$i][1])
		GUICtrlSetBkColor($titles_colored[$i][0], $titles_colored[$i][2] == -1 ? $THEME_PANEL_BG : $titles_colored[$i][2])
	Next
EndFunc


;~ Sets a label's text (right-aligned: trailing space) and colour, only when they change
Func TitlesSetText($id, $text, $color = -1, $right = True)
	If $id == 0 Then Return
	Local $shown = $right ? $text & ' ' : $text
	If Not MapExists($titles_shown, $id) Or $titles_shown[$id] <> $shown Then
		$titles_shown[$id] = $shown
		GUICtrlSetData($id, $shown)
	EndIf
	If $color <> -1 And (Not MapExists($titles_shown, 'c' & $id) Or $titles_shown['c' & $id] <> $color) Then
		$titles_shown['c' & $id] = $color
		GUICtrlSetColor($id, $color)
	EndIf
EndFunc


;~ (pure) colour of a Session text
Func TitlesSessionColor($text)
	If StringLeft($text, 1) == '+' Then Return $THEME_POSITIVE
	If StringLeft($text, 1) == '-' Then Return $THEME_NEGATIVE
	Return $THEME_TEXT_DISABLED
EndFunc


;~ Resizes a two-label bar to $fraction (green when full)
Func TitlesSetBar($fill, $rest, $x, $y, $width, $fraction)
	If $fill == 0 Then Return
	Local $fillWidth = Round($width * $fraction)
	Local $id = 'b' & $fill
	If MapExists($titles_shown, $id) And $titles_shown[$id] == $fillWidth Then Return
	$titles_shown[$id] = $fillWidth
	If $fillWidth <= 0 Then
		GUICtrlSetState($fill, $GUI_HIDE)
		GUICtrlSetPos($rest, $x, $y, $width, 8)
	Else
		GUICtrlSetPos($fill, $x, $y, $fillWidth, 8)
		GUICtrlSetBkColor($fill, $fraction >= 1 ? $THEME_POSITIVE : $THEME_VALUE)
		GUICtrlSetState($fill, $GUI_SHOW)
		If $fillWidth >= $width Then
			GUICtrlSetState($rest, $GUI_HIDE)
		Else
			GUICtrlSetPos($rest, $x + $fillWidth, $y, $width - $fillWidth, 8)
			GUICtrlSetState($rest, $GUI_SHOW)
		EndIf
	EndIf
EndFunc


;~ Called by ItemsPanelRefresh (attached, not loading): reads the titles, baseline, shows everything.
;~ $inventory = Items panel inventory counts (bags 1-5), $keysOwned = Zaishen keys in inventory + storage (-1 unknown).
Func TitlesTabUpdate($character, ByRef $inventory, $keysOwned = -1, $ownedMark = '')
	If Not $titles_tab_built Then Return False
	Local $readable = IsMapReadyNow(-1, -1)
	Local $points = TitlesReadPoints($readable)
	TitlesObserve($character, $points, $readable)
	If Not $readable Then Return False
	TitlesTabShow($points, $inventory, $keysOwned, $ownedMark)
	Return True
EndFunc


;~ Writes the values into the tab (separate from the reads: unit-tested with simulated points)
Func TitlesTabShow(ByRef $points, ByRef $inventory, $keysOwned, $ownedMark)
	Local $cols[] = [20, 326]
	For $i = 0 To 7
		Local $key = $TITLES_REP_KEYS[$i]
		Local $x = $cols[Int($i / 4)], $y = 80 + 20 * Mod($i, 4)
		TitlesSetText($titles_rep_total[$i], TitlesFormatNumber($points[$key]))
		Local $session = TitlesFormatDelta(TitlesDelta($key, $points))
		TitlesSetText($titles_rep_session[$i], $session, TitlesSessionColor($session))
		TitlesSetBar($titles_rep_fill[$i], $titles_rep_rest[$i], $x + 88, $y + 4, $TITLES_REP_BAR_WIDTH, TitlesFraction($points[$key], $TITLES_REP_MAX[$i]))
	Next
	TitlesSetText($titles_zaishen_points, TitlesFormatNumber($points['zaishen']) & ' / 100,000')
	TitlesSetBar($titles_zaishen_fill, $titles_zaishen_rest, 190, 194, $TITLES_ZAISHEN_BAR_WIDTH, TitlesFraction($points['zaishen'], $ZAISHEN_TITLE_MAX_POINTS))
	Local $zSession = TitlesFormatDelta(TitlesDelta('zaishen', $points))
	TitlesSetText($titles_zaishen_session, $zSession, TitlesSessionColor($zSession))
	Local $keyTexts = ZaishenKeyTexts($points['zaishen'], $keysOwned, $ownedMark)
	TitlesSetText($titles_zaishen_needed, $keyTexts[0], $keyTexts[0] == 'Maxed' ? $THEME_POSITIVE : $THEME_ACCENT_GOLD)
	TitlesSetText($titles_zaishen_owned, $keyTexts[1], -1, False)
	For $i = 0 To 2
		Local $ckey = $TITLES_CONSUME_KEYS[$i], $cx = 20 + 207 * $i
		TitlesSetText($titles_consume_points[$i], TitlesFormatNumber($points[$ckey]) & ' / 10,000')
		TitlesSetBar($titles_consume_fill[$i], $titles_consume_rest[$i], $cx, 301, $TITLES_CONSUME_WIDTH, TitlesFraction($points[$ckey], $TITLES_CONSUME_MAX))
		Local $cSession = TitlesFormatDelta(TitlesDelta($ckey, $points))
		TitlesSetText($titles_consume_session[$i], $cSession, TitlesSessionColor($cSession))
		Local $available = TitlesInventoryPoints($ckey, $inventory)
		TitlesSetText($titles_consume_avail[$i], '+' & TitlesFormatNumber($available[0]) & ' pts (' & TitlesFormatNumber($available[1]) & ' items)')
	Next
EndFunc


;~ Title key of a consume button ('' for another control)
Func TitlesButtonKey($controlID)
	For $i = 0 To 2
		If $titles_consume_button[$i] == $controlID And $controlID <> 0 Then Return $TITLES_CONSUME_KEYS[$i]
	Next
	Return ''
EndFunc
#EndRegion GUI


#Region Consume
Func TitlesSleep($ms)
	If $titles_sleep_scale > 0 Then Sleep($ms * $titles_sleep_scale)
EndFunc


;~ Index of the title in the consume arrays
Func TitlesConsumeIndex($titleKey)
	For $i = 0 To 2
		If $TITLES_CONSUME_KEYS[$i] == $titleKey Then Return $i
	Next
	Return -1
EndFunc


;~ Row of a model ID in a table, -1 if absent
Func TitlesTableRow(ByRef $table, $modelID)
	For $i = 0 To UBound($table) - 1
		If $table[$i][0] == $modelID Then Return $i
	Next
	Return -1
EndFunc


;~ First inventory item (bags 1-5) of the table usable here and not given up; Null when none. $skipped: Map row -> reason
;~ for rows not usable on this map (filled once per row, with the quantity seen).
Func TitlesFindNextItem(ByRef $table, $mapType, $regionType, ByRef $givenUp, ByRef $skipped, ByRef $row)
	For $bag = 1 To 5
		Local $bagStruct = GetBag($bag)
		If $bagStruct == Null Or $bagStruct == 0 Then ContinueLoop
		Local $slots = DllStructGetData($bagStruct, 'Slots')
		Local $bagItems = GetBagItemsOf($bag, $bagStruct)
		For $slot = 1 To $slots
			Local $item = $bagItems[$slot - 1]
			If DllStructGetData($item, 'ID') == 0 Then ContinueLoop
			Local $r = TitlesTableRow($table, DllStructGetData($item, 'ModelID'))
			If $r < 0 Or MapExists($givenUp, $r) Then ContinueLoop
			Local $reason = TitlesItemUsableHere($table[$r][2], $mapType, $regionType)
			If $reason <> '' Then
				Local $quantity = DllStructGetData($item, 'Quantity')
				$skipped[$r] = (MapExists($skipped, $r) ? $skipped[$r] : 0) + $quantity
				ContinueLoop
			EndIf
			$row = $r
			Return $item
		Next
	Next
	Return Null
EndFunc


;~ Uses every inventory item of the title that awards points on this map, one at a time. Caller: not during a farm run,
;~ attached (GUI checks IsAttachedForTools). Returns the points gained. Stops on map change / loading / disconnect, and
;~ (alcohol) when the points stop increasing; an item that gives no points is given up for the rest of the run.
Func TitlesConsumeRun($titleKey)
	Local $index = TitlesConsumeIndex($titleKey)
	If $index < 0 Then Return 0
	Local $titleName = $TITLES_CONSUME_TITLE_NAMES[$index]
	Local $table = TitlesItemTable($titleKey)
	Local $mapType = GetMapType(), $mapID = GetMapID()
	If GetMyID() == 0 Or ($mapType <> $ID_OUTPOST And $mapType <> $ID_EXPLORABLE) Then
		Warn('[Titles] ' & $titleName & ': character not in game or map loading - nothing used')
		Return 0
	EndIf
	Local $regionType = GetMapRegionType($mapID)
	Local $givenUp[], $skipped[]
	Local $used = 0, $gained = 0, $stopReason = 'no more usable items in the inventory'
	Info('[Titles] ' & $titleName & ': using inventory items that award points here (' & ($mapType == $ID_OUTPOST ? 'outpost' : 'explorable') & ')')
	For $guard = 1 To 2000
		If GetMapID() <> $mapID Or GetMapType() <> $mapType Or GetMyID() == 0 Then
			$stopReason = 'map changed / loading / disconnected - stopped'
			ExitLoop
		EndIf
		Local $row = -1
		Local $item = TitlesFindNextItem($table, $mapType, $regionType, $givenUp, $skipped, $row)
		If $item == Null Then ExitLoop
		Local $before = TitlesReadOne($titleKey)
		UseItem($item)
		TitlesSleep(StringInStr($table[$row][3], 'Tonic') ? $TITLES_TONIC_DELAY_MS : $TITLES_ITEM_DELAY_MS)
		Local $after = TitlesWaitForPoints($titleKey, $before)
		Local $delta = $after - $before
		If $delta > 0 Then
			$used += 1
			$gained += $delta
			Info('[Titles] Used ' & $table[$row][3] & ': +' & $delta & ' ' & $titleName & ' (' & TitlesFormatNumber($after) & ')')
		ElseIf $titleKey == 'alcohol' Then
			$stopReason = 'points stopped increasing after ' & $table[$row][3] & ' - stopped'
			ExitLoop
		Else
			Warn('[Titles] ' & $table[$row][3] & ' gave no ' & $titleName & ' points here - not used again this time')
			$givenUp[$row] = True
		EndIf
	Next
	For $r In MapKeys($skipped)
		Info('[Titles] Skipped ' & $skipped[$r] & 'x ' & $table[$r][3] & ': ' & TitlesItemUsableHere($table[$r][2], $mapType, $regionType))
	Next
	Info('[Titles] ' & $titleName & ': ' & $used & ' item(s) used, +' & TitlesFormatNumber($gained) & ' points (' & $stopReason & ')')
	Return $gained
EndFunc


;~ Title points after a use: polls until they change or $TITLES_POINTS_WAIT_MS passed
Func TitlesWaitForPoints($titleKey, $before)
	Local $timer = TimerInit()
	Local $now = TitlesReadOne($titleKey)
	While $now == $before And $titles_sleep_scale > 0 And TimerDiff($timer) < $TITLES_POINTS_WAIT_MS
		Sleep(100)
		$now = TitlesReadOne($titleKey)
	WEnd
	Return $now
EndFunc
#EndRegion Consume
