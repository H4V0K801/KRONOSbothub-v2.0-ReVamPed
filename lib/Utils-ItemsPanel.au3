#CS ===========================================================================
; v23: Main tab 'Items' panel - scrollable list of item totals (inventory + Xunlai storage) grouped by category.
;
; Control: one report-mode ListView (v31: three columns, Item | Session | Total). Each category starts with a header row (upper-case name,
; tinted background via NM_CUSTOMDRAW in WM_NOTIFY_Handler). It sits in the Main tab like the old labels, so the tab control
; shows/hides it; scrolling (bar and mouse wheel) is the ListView's own - no child window, no WM_MOUSEWHEEL/WM_VSCROLL
; handler, no GUIScrollBars bookkeeping. ListView *groups* were tried first: Wine's comctl32 does not draw group headers
; and on Windows they need the comctl32 v6 manifest, so plain header rows are used (same look everywhere).
;
; Counts: item rows = quantity in bags 1-5 (backpack, belt pouch, bags, equipment pack) + Xunlai storage (material
; storage bag 6 and storage panes 8-21). Bag 7 and equipped items are not counted.
; v33: no title rows any more (AMG: titles moved to their own 'Titles' tab, lib/Utils-TitlesTab.au3, refreshed from here);
; Lockpicks (an item) moved from the old TITLES category to the end of Exchangeables.
;
; Storage reading: the bags' item arrays are read straight from game memory (GetBag/GetItemBySlot), the same way the bot
; already stores items and GWToolbox counts pcons - in an outpost, without opening the Xunlai window. Storage is only read in
; outposts; in explorables / while loading the last outpost read is used, marked with '*', and kept in
; cache/xunlai_counts.ini (per character) so it survives restarts.
;
; v31 (AMG: "add a column before the total that tracks only the current session"): columns Item | Session | Total.
; Session = net change since BotsHub started = current total (inventory + storage) - a baseline taken once per character
; per session, at the first COMPLETE read: game attached, map fully loaded (v30 IsMapReadyNow), in an outpost with the
; storage read live (backpack, material storage and Xunlai pane I all readable - never a partial or cached read). A
; character change re-baselines at that character's next complete read. Shown '+N' / '0' / '-N' (consumed, sold, used);
; blank until the baseline exists. Moving items between bags and storage (Store, Empty Tab) nets to 0 since both are
; counted.
;
; Refresh: never inside a farm run. At run start/end (UpdateStats), after inventory management, after Open Storage and,
; while the bot is idle or paused, at most every $ITEMS_PANEL_REFRESH_MS from the main loop.
#CE ===========================================================================

#include-once
#include <GuiListView.au3>
#include <ListViewConstants.au3>
#include <WindowsConstants.au3>
#include <StructureConstants.au3>
#include 'BotsHub-Theme-Colors.au3'
#include 'Utils-TitlesTab.au3'

Global Const $ITEMS_PANEL_REFRESH_MS = 5000
Global Const $ITEMS_PANEL_CATEGORIES[] = ['Elite Tomes', 'Exchangeables', 'Consumable Materials', 'Sweets', 'Party', 'Alcohol']
Global Const $ITEMS_PANEL_CACHE_MARK = '*'
; header row colours (COLORREF = 0xBBGGRR)
; v31: dark theme - custom-draw colours (COLORREF/BGR) derived from the central palette in BotsHub-Theme-Colors.au3
Global Const $ITEMS_PANEL_HEADER_TEXT = ThemeBGR($THEME_ACCENT_GOLD), $ITEMS_PANEL_HEADER_BACK = ThemeBGR($THEME_HEADER_ROW_BG)
Global Const $ITEMS_PANEL_ROW_BACK = ThemeBGR($THEME_INPUT_BG), $ITEMS_PANEL_NAME_TEXT = ThemeBGR($THEME_TEXT)
Global Const $ITEMS_PANEL_TOTAL_TEXT = ThemeBGR($THEME_VALUE), $ITEMS_PANEL_ZERO_TEXT = ThemeBGR($THEME_TEXT_DISABLED)
Global Const $ITEMS_PANEL_GAIN_TEXT = ThemeBGR($THEME_POSITIVE), $ITEMS_PANEL_LOSS_TEXT = ThemeBGR($THEME_NEGATIVE)

Global $items_panel_listview = 0
Global $items_panel_status = 0
; [n][4]: category index, key, label, model ID (0 for the tome total)
Global $items_panel_rows = Null
Global $items_panel_index[]
Global $items_panel_shown[]
Global $items_panel_wanted[]
; ListView index -> category index, for the header rows
Global $items_panel_header_rows[]
; storage counts: Map modelID -> quantity, the time they were read and for which character
Global $items_panel_storage[]
Global $items_panel_storage_time = ''
Global $items_panel_storage_char = ''
Global $items_panel_storage_live = False
Global $items_panel_scans = 0
; v31: listview column indexes
Global Const $ITEMS_PANEL_COL_SESSION = 1, $ITEMS_PANEL_COL_TOTAL = 2
Global Const $ITEMS_PANEL_SESSION_WIDTH = 52, $ITEMS_PANEL_TOTAL_WIDTH = 56
; v31: session baseline (Map modelID -> total at baseline), for which character, when; bags readable at the last scan
Global $items_panel_session_base[]
Global $items_panel_session_char = ''
Global $items_panel_session_ready = False
Global $items_panel_session_time = ''
Global $items_panel_session_shown[]
Global $items_panel_last_readable[]
; v31: ListView index -> row key (custom draw colours the Session cell by sign)
Global $items_panel_key_at[]


;~ Panel rows in display order. Built at run time (the item constants are defined in includes after the GUI file).
Func ItemsPanelDefinitions()
	Local $rows[0][4]
	; 1. Elite Tomes - the 10 professions + Total (normal tomes are not counted)
	ItemsPanelAddRow($rows, 0, 'Warrior', $ID_WARRIOR_ELITETOME)
	ItemsPanelAddRow($rows, 0, 'Ranger', $ID_RANGER_ELITETOME)
	ItemsPanelAddRow($rows, 0, 'Monk', $ID_MONK_ELITETOME)
	ItemsPanelAddRow($rows, 0, 'Necromancer', $ID_NECROMANCER_ELITETOME)
	ItemsPanelAddRow($rows, 0, 'Mesmer', $ID_MESMER_ELITETOME)
	ItemsPanelAddRow($rows, 0, 'Elementalist', $ID_ELEMENTALIST_ELITETOME)
	ItemsPanelAddRow($rows, 0, 'Assassin', $ID_ASSASSIN_ELITETOME)
	ItemsPanelAddRow($rows, 0, 'Ritualist', $ID_RITUALIST_ELITETOME)
	ItemsPanelAddRow($rows, 0, 'Paragon', $ID_PARAGON_ELITETOME)
	ItemsPanelAddRow($rows, 0, 'Dervish', $ID_DERVISH_ELITETOME)
	ItemsPanelAddRow($rows, 0, 'Total', 0, 'tome.total')
	; 2. Exchangeables - items turned in / traded to NPCs
	ItemsPanelAddRow($rows, 1, 'Margonite Gemstones', $ID_MARGONITE_GEMSTONE)
	ItemsPanelAddRow($rows, 1, 'Stygian Gemstones', $ID_STYGIAN_GEMSTONE)
	ItemsPanelAddRow($rows, 1, 'Titan Gemstones', $ID_TITAN_GEMSTONE)
	ItemsPanelAddRow($rows, 1, 'Torment Gemstones', $ID_TORMENT_GEMSTONE)
	ItemsPanelAddRow($rows, 1, 'Armbraces of Truth', $ID_ARMBRACE_OF_TRUTH)
	ItemsPanelAddRow($rows, 1, 'Golden Rin Relics', $ID_GOLDEN_RIN_RELIC)
	ItemsPanelAddRow($rows, 1, 'Destroyer Cores', $ID_DESTROYER_CORE)
	ItemsPanelAddRow($rows, 1, 'Glacial Stones', $ID_GLACIAL_STONE)
	ItemsPanelAddRow($rows, 1, 'Diessa Chalices', $ID_DIESSA_CHALICE)
	ItemsPanelAddRow($rows, 1, 'Hammers of Kathandrax', $ID_HAMMER_OF_KATHANDRAX)
	ItemsPanelAddRow($rows, 1, 'War Supplies', $ID_WAR_SUPPLIES)
	ItemsPanelAddRow($rows, 1, 'Ministerial Commendations', $ID_MINISTERIAL_COMMENDATION)
	ItemsPanelAddRow($rows, 1, 'Imperial Commendations', $ID_IMPERIAL_COMMENDATION)
	ItemsPanelAddRow($rows, 1, 'Jade Bracelets', $ID_JADE_BRACELET)
	ItemsPanelAddRow($rows, 1, 'Jadeite Shards', $ID_JADEITE_SHARD)
	ItemsPanelAddRow($rows, 1, 'Amber Chunks', $ID_AMBER_CHUNK)
	ItemsPanelAddRow($rows, 1, 'Burol Ironfist''s Commendations', $ID_BUROL_IRONFISTS_COMMENDATION)
	ItemsPanelAddRow($rows, 1, 'Imperial Guard Requisition Orders', $ID_IMPERIAL_GUARD_REQUISITION_ORDER)
	ItemsPanelAddRow($rows, 1, 'Confessor''s Orders', $ID_CONFESSORS_ORDERS)
	ItemsPanelAddRow($rows, 1, 'Kournan Coins', $ID_KOURNAN_COIN)
	ItemsPanelAddRow($rows, 1, 'Ancient Artifacts', $ID_ANCIENT_ARTIFACT)
	ItemsPanelAddRow($rows, 1, 'Inscribed Secrets', $ID_INSCRIBED_SECRET)
	ItemsPanelAddRow($rows, 1, 'Battle Commendations', $ID_BATTLE_COMMENDATION)
	ItemsPanelAddRow($rows, 1, 'Trade Contracts', $ID_TRADE_CONTRACT)
	ItemsPanelAddRow($rows, 1, 'Monastery Credits', $ID_MONASTERY_CREDIT)
	ItemsPanelAddRow($rows, 1, 'Equipment Requisitions', $ID_EQUIPMENT_REQUISITION)
	ItemsPanelAddRow($rows, 1, 'Copper Zaishen Coins', $ID_COPPER_ZAISHEN_COIN)
	ItemsPanelAddRow($rows, 1, 'Silver Zaishen Coins', $ID_SILVER_ZAISHEN_COIN)
	ItemsPanelAddRow($rows, 1, 'Gold Zaishen Coins', $ID_GOLD_ZAISHEN_COIN)
	ItemsPanelAddRow($rows, 1, 'Victory Tokens', $ID_VICTORY_TOKEN)
	ItemsPanelAddRow($rows, 1, 'Lunar Tokens', $ID_LUNAR_TOKEN)
	ItemsPanelAddRow($rows, 1, 'Wayfarer Marks', $ID_WAYFARER_MARK)
	ItemsPanelAddRow($rows, 1, 'Candy Cane Shards', $ID_CC_SHARD)
	ItemsPanelAddRow($rows, 1, 'Globs of Frozen Ectoplasm', $ID_GLOB_OF_FROZEN_ECTOPLASM)
	; v33: Lockpicks moved here from the removed TITLES category (last Exchangeables row)
	ItemsPanelAddRow($rows, 1, 'Lockpicks', $ID_LOCKPICK)
	; 3. Consumable Materials (not holiday drops; Wintersday Gifts kept here on request) - consets, pcon ingredients
	ItemsPanelAddRow($rows, 2, 'Drake Flesh Chunks', $ID_CHUNK_OF_DRAKE_FLESH)
	ItemsPanelAddRow($rows, 2, 'Drake Kabobs', $ID_DRAKE_KABOB)
	ItemsPanelAddRow($rows, 2, 'Skale Fins', $ID_SKALE_FIN)
	ItemsPanelAddRow($rows, 2, 'Bowls of Skalefin Soup', $ID_BOWL_OF_SKALEFIN_SOUP)
	ItemsPanelAddRow($rows, 2, 'Iboga Petals', $ID_IBOGA_PETAL)
	ItemsPanelAddRow($rows, 2, 'Pahnai Salads', $ID_PAHNAI_SALAD)
	ItemsPanelAddRow($rows, 2, 'Wintersday Gifts', $ID_WINTERSDAY_GIFT)
	ItemsPanelAddRow($rows, 2, 'Essences of Celerity', $ID_ESSENCE_OF_CELERITY)
	ItemsPanelAddRow($rows, 2, 'Grails of Might', $ID_GRAIL_OF_MIGHT)
	ItemsPanelAddRow($rows, 2, 'Armors of Salvation', $ID_ARMOR_OF_SALVATION)
	ItemsPanelAddRow($rows, 2, 'Powerstones of Courage', $ID_POWERSTONE_OF_COURAGE)
	ItemsPanelAddRow($rows, 2, 'Scrolls of Resurrection', $ID_SCROLL_OF_RESURRECTION)
	ItemsPanelAddRow($rows, 2, 'Feathers', $ID_FEATHER)
	ItemsPanelAddRow($rows, 2, 'Piles of Glittering Dust', $ID_PILE_OF_GLITTERING_DUST)
	ItemsPanelAddRow($rows, 2, 'Iron Ingots', $ID_IRON_INGOT)
	ItemsPanelAddRow($rows, 2, 'Bones', $ID_BONE)
	; 4. Sweets
	ItemsPanelAddRow($rows, 3, 'Birthday Cupcakes', $ID_BIRTHDAY_CUPCAKE)
	ItemsPanelAddRow($rows, 3, 'Slices of Pumpkin Pie', $ID_SLICE_OF_PUMPKIN_PIE)
	ItemsPanelAddRow($rows, 3, 'Golden Eggs', $ID_GOLDEN_EGG)
	ItemsPanelAddRow($rows, 3, 'Honeycombs', $ID_HONEYCOMB)
	ItemsPanelAddRow($rows, 3, 'Fruitcakes', $ID_FRUITCAKE)
	ItemsPanelAddRow($rows, 3, 'Sugary Blue Drinks', $ID_SUGARY_BLUE_DRINK)
	ItemsPanelAddRow($rows, 3, 'Chocolate Bunnies', $ID_CHOCOLATE_BUNNY)
	ItemsPanelAddRow($rows, 3, 'Delicious Cakes', $ID_DELICIOUS_CAKE)
	ItemsPanelAddRow($rows, 3, 'Candy Apples', $ID_CANDY_APPLE)
	ItemsPanelAddRow($rows, 3, 'Candy Corn', $ID_CANDY_CORN)
	ItemsPanelAddRow($rows, 3, 'Creme Brulees', $ID_CREME_BRULEE)
	ItemsPanelAddRow($rows, 3, 'Red Bean Cakes', $ID_RED_BEAN_CAKE)
	ItemsPanelAddRow($rows, 3, 'Mandragor Root Cakes', $ID_MANDRAGOR_ROOT_CAKE)
	ItemsPanelAddRow($rows, 3, 'Jars of Honey', $ID_JAR_OF_HONEY)
	ItemsPanelAddRow($rows, 3, 'Krytan Lokum', $ID_KRYTAN_LOKUM)
	ItemsPanelAddRow($rows, 3, 'Minitreats of Purity', $ID_MINITREATS_OF_PURITY)
	ItemsPanelAddRow($rows, 3, 'Blue Rock Candy', $ID_BLUE_ROCK_CANDY)
	ItemsPanelAddRow($rows, 3, 'Green Rock Candy', $ID_GREEN_ROCK_CANDY)
	ItemsPanelAddRow($rows, 3, 'Red Rock Candy', $ID_RED_ROCK_CANDY)
	ItemsPanelAddRow($rows, 3, 'Pumpkin Cookies', $ID_PUMPKIN_COOKIE)
	ItemsPanelAddRow($rows, 3, 'Peppermint Candy Canes', $ID_PEPPERMINT_CC)
	ItemsPanelAddRow($rows, 3, 'Wintergreen Candy Canes', $ID_WINTERGREEN_CC)
	ItemsPanelAddRow($rows, 3, 'Rainbow Candy Canes', $ID_RAINBOW_CC)
	ItemsPanelAddRow($rows, 3, 'Lunar Fortunes (Pig)', $ID_LUNAR_FORTUNE_PIG)
	ItemsPanelAddRow($rows, 3, 'Lunar Fortunes (Rat)', $ID_LUNAR_FORTUNE_RAT)
	ItemsPanelAddRow($rows, 3, 'Lunar Fortunes (Ox)', $ID_LUNAR_FORTUNE_OX)
	ItemsPanelAddRow($rows, 3, 'Lunar Fortunes (Tiger)', $ID_LUNAR_FORTUNE_TIGER)
	ItemsPanelAddRow($rows, 3, 'Lunar Fortunes (Rabbit)', $ID_LUNAR_FORTUNE_RABBIT)
	ItemsPanelAddRow($rows, 3, 'Lunar Fortunes (Dragon)', $ID_LUNAR_FORTUNE_DRAGON)
	ItemsPanelAddRow($rows, 3, 'Lunar Fortunes (Snake)', $ID_LUNAR_FORTUNE_SNAKE)
	ItemsPanelAddRow($rows, 3, 'Lunar Fortunes (Horse)', $ID_LUNAR_FORTUNE_HORSE)
	ItemsPanelAddRow($rows, 3, 'Lunar Fortunes (Sheep)', $ID_LUNAR_FORTUNE_SHEEP)
	ItemsPanelAddRow($rows, 3, 'Lunar Fortunes (Monkey)', $ID_LUNAR_FORTUNE_MONKEY)
	ItemsPanelAddRow($rows, 3, 'Lunar Fortunes (Rooster)', $ID_LUNAR_FORTUNE_ROOSTER)
	ItemsPanelAddRow($rows, 3, 'Lunar Fortunes (Dog)', $ID_LUNAR_FORTUNE_DOG)
	; 5. Party - festive items and party tonics (Party Animal title), Trick-or-Treat Bags
	ItemsPanelAddRow($rows, 4, 'Trick-or-Treat Bags', $ID_TOT)
	ItemsPanelAddRow($rows, 4, 'Ghosts-in-the-Box', $ID_GHOST_IN_THE_BOX)
	ItemsPanelAddRow($rows, 4, 'Squash Serums', $ID_SQUASH_SERUM)
	ItemsPanelAddRow($rows, 4, 'Snowman Summoners', $ID_SNOWMAN_SUMMONER)
	ItemsPanelAddRow($rows, 4, 'Bottle Rockets', $ID_BOTTLE_ROCKET)
	ItemsPanelAddRow($rows, 4, 'Champagne Poppers', $ID_CHAMPAGNE_POPPER)
	ItemsPanelAddRow($rows, 4, 'Sparklers', $ID_SPARKLER)
	ItemsPanelAddRow($rows, 4, 'Crates of Fireworks', $ID_CRATE_OF_FIREWORKS)
	ItemsPanelAddRow($rows, 4, 'Disco Balls', $ID_DISCO_BALL)
	ItemsPanelAddRow($rows, 4, 'Party Beacons', $ID_PARTY_BEACON)
	ItemsPanelAddRow($rows, 4, 'Sinister Automatonic Tonics', $ID_SINISTER_AUTOMATONIC_TONIC)
	ItemsPanelAddRow($rows, 4, 'Transmogrifier Tonics', $ID_TRANSMOGRIFIER_TONIC)
	ItemsPanelAddRow($rows, 4, 'Yuletide Tonics', $ID_YULETIDE_TONIC)
	ItemsPanelAddRow($rows, 4, 'Beetle Juice Tonics', $ID_BEETLE_JUICE_TONIC)
	ItemsPanelAddRow($rows, 4, 'Abyssal Tonics', $ID_ABYSSAL_TONIC)
	ItemsPanelAddRow($rows, 4, 'Cerebral Tonics', $ID_CEREBRAL_TONIC)
	ItemsPanelAddRow($rows, 4, 'Macabre Tonics', $ID_MACABRE_TONIC)
	ItemsPanelAddRow($rows, 4, 'Trapdoor Tonics', $ID_TRAPDOOR_TONIC)
	ItemsPanelAddRow($rows, 4, 'Searing Tonics', $ID_SEARING_TONIC)
	ItemsPanelAddRow($rows, 4, 'Automatonic Tonics', $ID_AUTOMATONIC_TONIC)
	ItemsPanelAddRow($rows, 4, 'Skeletonic Tonics', $ID_SKELETONIC_TONIC)
	ItemsPanelAddRow($rows, 4, 'Boreal Tonics', $ID_BOREAL_TONIC)
	ItemsPanelAddRow($rows, 4, 'Gelatinous Tonics', $ID_GELATINOUS_TONIC)
	ItemsPanelAddRow($rows, 4, 'Phantasmal Tonics', $ID_PHANTASMAL_TONIC)
	ItemsPanelAddRow($rows, 4, 'Abominable Tonics', $ID_ABOMINABLE_TONIC)
	ItemsPanelAddRow($rows, 4, 'Frosty Tonics', $ID_FROSTY_TONIC)
	ItemsPanelAddRow($rows, 4, 'Mischievious Tonics', $ID_MISCHIEVIOUS_TONIC)
	ItemsPanelAddRow($rows, 4, 'Mysterious Tonics', $ID_MYSTERIOUS_TONIC)
	ItemsPanelAddRow($rows, 4, 'Cottontail Tonics', $ID_COTTONTAIL_TONIC)
	ItemsPanelAddRow($rows, 4, 'Zaishen Tonics', $ID_ZAISHEN_TONIC)
	ItemsPanelAddRow($rows, 4, 'Unseen Tonics', $ID_UNSEEN_TONIC)
	ItemsPanelAddRow($rows, 4, 'Spooky Tonics', $ID_SPOOKY_TONIC)
	ItemsPanelAddRow($rows, 4, 'Minutely Mad King Tonics', $ID_MINUTELY_MAD_KING_TONIC)
	; 6. Alcohol
	ItemsPanelAddRow($rows, 5, 'Hunter''s Ale', $ID_HUNTERS_ALE)
	ItemsPanelAddRow($rows, 5, 'Dwarven Ale', $ID_DWARVEN_ALE)
	ItemsPanelAddRow($rows, 5, 'Witch''s Brew', $ID_WITCHS_BREW)
	ItemsPanelAddRow($rows, 5, 'Vials of Absinthe', $ID_VIAL_OF_ABSINTHE)
	ItemsPanelAddRow($rows, 5, 'Eggnog', $ID_EGGNOG)
	ItemsPanelAddRow($rows, 5, 'Bottles of Rice Wine', $ID_BOTTLE_OF_RICE_WINE)
	ItemsPanelAddRow($rows, 5, 'Zehtuka''s Jugs', $ID_ZEHTUKAS_JUG)
	ItemsPanelAddRow($rows, 5, 'Bottles of Juniberry Gin', $ID_BOTTLE_OF_JUNIBERRY_GIN)
	ItemsPanelAddRow($rows, 5, 'Bottles of Vabbian Wine', $ID_BOTTLE_OF_VABBIAN_WINE)
	ItemsPanelAddRow($rows, 5, 'Shamrock Ale', $ID_SHAMROCK_ALE)
	ItemsPanelAddRow($rows, 5, 'Hard Apple Cider', $ID_HARD_APPLE_CIDER)
	ItemsPanelAddRow($rows, 5, 'Flasks of Firewater', $ID_FLASK_OF_FIREWATER)
	ItemsPanelAddRow($rows, 5, 'Spiked Eggnog', $ID_SPIKED_EGGNOG)
	ItemsPanelAddRow($rows, 5, 'Aged Dwarven Ale', $ID_AGED_DWARVEN_ALE)
	ItemsPanelAddRow($rows, 5, 'Bottles of Grog', $ID_BOTTLE_OF_GROG)
	ItemsPanelAddRow($rows, 5, 'Aged Hunter''s Ale', $ID_AGED_HUNTERS_ALE)
	ItemsPanelAddRow($rows, 5, 'Kegs of Aged Hunter''s Ale', $ID_KEG_OF_AGED_HUNTERS_ALE)
	ItemsPanelAddRow($rows, 5, 'Krytan Brandy', $ID_KRYTAN_BRANDY)
	ItemsPanelAddRow($rows, 5, 'Battle Isle Iced Tea', $ID_BATTLE_ISLE_ICED_TEA)
	Return $rows
EndFunc


;~ Appends one row (key defaults to 'm<modelID>')
Func ItemsPanelAddRow(ByRef $rows, $category, $label, $modelID, $key = '')
	Local $n = UBound($rows)
	ReDim $rows[$n + 1][4]
	$rows[$n][0] = $category
	$rows[$n][1] = $key == '' ? 'm' & $modelID : $key
	$rows[$n][2] = $label
	$rows[$n][3] = $modelID
EndFunc


;~ Loads the row definitions and the lookup maps (idempotent)
Func ItemsPanelLoadDefinitions()
	If IsArray($items_panel_rows) Then Return
	$items_panel_rows = ItemsPanelDefinitions()
	Local $empty[]
	$items_panel_wanted = $empty
	For $i = 0 To UBound($items_panel_rows) - 1
		If $items_panel_rows[$i][3] <> 0 Then $items_panel_wanted[$items_panel_rows[$i][3]] = True
	Next
	; v33: Zaishen Keys are counted too (no row here; the Titles tab shows them next to the Zaishen keys needed)
	$items_panel_wanted[$ID_ZAISHEN_KEY] = True
	; v33: and the Sweet Tooth / Drunkard / Party Animal items (Titles tab 'points available in inventory')
	For $modelID In TitlesAllConsumableModelIDs()
		$items_panel_wanted[$modelID] = True
	Next
EndFunc


;~ Creates the panel (ListView with category groups + storage status line) in the current GUI / tab
Func ItemsPanelCreate($x, $y, $width, $height)
	ItemsPanelLoadDefinitions()
	; v31: Item | Session | Total (label tips show names cut by the narrower Item column; 0x4000 = LVS_EX_LABELTIP)
	$items_panel_listview = GUICtrlCreateListView('Item|Session|Total', $x, $y, $width, $height - 18, _
		BitOR($LVS_REPORT, $LVS_SINGLESEL, $LVS_NOSORTHEADER, $LVS_SHOWSELALWAYS), _
		BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_DOUBLEBUFFER, 0x4000))
	_GUICtrlListView_SetColumnWidth($items_panel_listview, 0, $width - 4 - 17 - $ITEMS_PANEL_SESSION_WIDTH - $ITEMS_PANEL_TOTAL_WIDTH)
	_GUICtrlListView_SetColumnWidth($items_panel_listview, $ITEMS_PANEL_COL_SESSION, $ITEMS_PANEL_SESSION_WIDTH)
	_GUICtrlListView_SetColumnWidth($items_panel_listview, $ITEMS_PANEL_COL_TOTAL, $ITEMS_PANEL_TOTAL_WIDTH)
	_GUICtrlListView_JustifyColumn($items_panel_listview, $ITEMS_PANEL_COL_SESSION, 1)
	_GUICtrlListView_JustifyColumn($items_panel_listview, $ITEMS_PANEL_COL_TOTAL, 1)
	Local $empty[]
	$items_panel_index = $empty
	$items_panel_shown = $empty
	$items_panel_session_shown = $empty
	$items_panel_key_at = $empty
	$items_panel_header_rows = $empty
	_GUICtrlListView_BeginUpdate($items_panel_listview)
	Local $category = -1
	For $i = 0 To UBound($items_panel_rows) - 1
		If $items_panel_rows[$i][0] <> $category Then
			$category = $items_panel_rows[$i][0]
			Local $header = _GUICtrlListView_AddItem($items_panel_listview, StringUpper($ITEMS_PANEL_CATEGORIES[$category]))
			_GUICtrlListView_AddSubItem($items_panel_listview, $header, '', $ITEMS_PANEL_COL_SESSION)
			_GUICtrlListView_AddSubItem($items_panel_listview, $header, '', $ITEMS_PANEL_COL_TOTAL)
			$items_panel_header_rows[$header] = $category
		EndIf
		Local $index = _GUICtrlListView_AddItem($items_panel_listview, '   ' & $items_panel_rows[$i][2])
		; every row's Session stays blank until the session baseline exists
		Local $sessionText = ''
		_GUICtrlListView_AddSubItem($items_panel_listview, $index, $sessionText, $ITEMS_PANEL_COL_SESSION)
		_GUICtrlListView_AddSubItem($items_panel_listview, $index, '0', $ITEMS_PANEL_COL_TOTAL)
		$items_panel_index[$items_panel_rows[$i][1]] = $index
		$items_panel_key_at[$index] = $items_panel_rows[$i][1]
		$items_panel_shown[$items_panel_rows[$i][1]] = '0'
		$items_panel_session_shown[$items_panel_rows[$i][1]] = $sessionText
	Next
	_GUICtrlListView_EndUpdate($items_panel_listview)
	$items_panel_status = GUICtrlCreateLabel('Storage not read yet: attach, then visit an outpost', $x, $y + $height - 16, $width, 16)
	GUICtrlSetTip($items_panel_listview, 'Item rows: total in your inventory (bags 1-5) + Xunlai storage.' & @CRLF _
		& 'Storage is read in outposts; ' & $ITEMS_PANEL_CACHE_MARK & ' = storage part from the last outpost read.' & @CRLF _
		& 'Session: change since BotsHub started (+ gained, - used/sold), from the first full outpost read.' & @CRLF _
		& 'Scroll with the mouse wheel. Title points: see the Titles tab.')
EndFunc


;~ Sets the Total column of a row (only touches the control when the text changes). False for an unknown key / no panel.
Func ItemsPanelSetValue($key, $value)
	If $items_panel_listview == 0 Or Not MapExists($items_panel_index, $key) Then Return False
	Local $text = String($value)
	If $items_panel_shown[$key] == $text Then Return True
	$items_panel_shown[$key] = $text
	_GUICtrlListView_SetItemText($items_panel_listview, $items_panel_index[$key], $text, $ITEMS_PANEL_COL_TOTAL)
	Return True
EndFunc


;~ Returns the Total column text of a row as displayed ('' for an unknown key)
Func ItemsPanelGetValue($key)
	If $items_panel_listview == 0 Or Not MapExists($items_panel_index, $key) Then Return ''
	Return _GUICtrlListView_GetItemText($items_panel_listview, $items_panel_index[$key], $ITEMS_PANEL_COL_TOTAL)
EndFunc


;~ v31: sets the Session column of a row (only when the text changes). False for an unknown key / no panel.
Func ItemsPanelSetSession($key, $text)
	If $items_panel_listview == 0 Or Not MapExists($items_panel_index, $key) Then Return False
	$text = String($text)
	If $items_panel_session_shown[$key] == $text Then Return True
	$items_panel_session_shown[$key] = $text
	_GUICtrlListView_SetItemText($items_panel_listview, $items_panel_index[$key], $text, $ITEMS_PANEL_COL_SESSION)
	Return True
EndFunc


;~ v31: returns the Session column text of a row as displayed ('' for an unknown key)
Func ItemsPanelGetSession($key)
	If $items_panel_listview == 0 Or Not MapExists($items_panel_index, $key) Then Return ''
	Return _GUICtrlListView_GetItemText($items_panel_listview, $items_panel_index[$key], $ITEMS_PANEL_COL_SESSION)
EndFunc


;~ v31: '+N' for a gain, '0' for none, '-N' for a loss
Func ItemsPanelFormatDelta($delta)
	$delta = Number($delta)
	If $delta > 0 Then Return '+' & $delta
	Return String($delta)
EndFunc


;~ v31 (pure, unit-tested): keeps the session baseline. $complete = this read is a full live read (map loaded, inventory
;~ and storage readable). A different character drops the baseline; the first complete read for the current character takes
;~ it (total per tracked model = inventory + storage). Returns True when a baseline for $character exists.
Func ItemsPanelSessionObserve($character, ByRef $inventory, ByRef $storage, $complete)
	If $items_panel_session_ready And $character <> $items_panel_session_char Then ItemsPanelSessionReset()
	If $items_panel_session_ready Then Return True
	If Not $complete Or $character == '' Then Return False
	Local $base[]
	For $modelID In MapKeys($items_panel_wanted)
		$base[$modelID] = ItemsPanelMapGet($inventory, $modelID) + ItemsPanelMapGet($storage, $modelID)
	Next
	$items_panel_session_base = $base
	$items_panel_session_char = $character
	$items_panel_session_ready = True
	$items_panel_session_time = @HOUR & ':' & @MIN
	Return True
EndFunc


;~ v31: forget the session baseline (character change)
Func ItemsPanelSessionReset()
	Local $empty[]
	$items_panel_session_base = $empty
	$items_panel_session_char = ''
	$items_panel_session_ready = False
	$items_panel_session_time = ''
EndFunc


;~ v31 (pure): session change of one model given its current total; Null when there is no baseline
Func ItemsPanelSessionDelta($modelID, $total)
	If Not $items_panel_session_ready Then Return Null
	Return $total - ItemsPanelMapGet($items_panel_session_base, $modelID)
EndFunc


;~ v31: a scan is complete for the baseline when the backpack (1), material storage (6) and Xunlai pane I (8) were readable
Func ItemsPanelReadIsComplete()
	Return MapExists($items_panel_last_readable, 1) And MapExists($items_panel_last_readable, 6) And MapExists($items_panel_last_readable, 8)
EndFunc


;~ NM_CUSTOMDRAW for the panel ListView (called by WM_NOTIFY_Handler).
;~ v31 dark theme: category header rows gold on a dark gold tint; item rows per cell - name light, Session green (+N) /
;~ red (-N) / grey (0 or no baseline yet), Total light blue (grey when 0). Returns the value WM_NOTIFY must return.
Func ItemsPanelCustomDraw($paramNotifyStruct)
	Local $customDraw = DllStructCreate($tagNMLVCUSTOMDRAW, $paramNotifyStruct)
	Local $row = Int(DllStructGetData($customDraw, 'dwItemSpec'))
	Switch DllStructGetData($customDraw, 'dwDrawStage')
		Case $CDDS_PREPAINT
			Return $CDRF_NOTIFYITEMDRAW
		Case $CDDS_ITEMPREPAINT
			If MapExists($items_panel_header_rows, $row) Then
				DllStructSetData($customDraw, 'clrText', $ITEMS_PANEL_HEADER_TEXT)
				DllStructSetData($customDraw, 'clrTextBk', $ITEMS_PANEL_HEADER_BACK)
				Return $CDRF_NEWFONT
			EndIf
			Return $CDRF_NOTIFYSUBITEMDRAW
		Case BitOR($CDDS_ITEMPREPAINT, $CDDS_SUBITEM)
			DllStructSetData($customDraw, 'clrTextBk', $ITEMS_PANEL_ROW_BACK)
			Local $column = Int(DllStructGetData($customDraw, 'iSubItem'))
			DllStructSetData($customDraw, 'clrText', ItemsPanelCellColor($column, ItemsPanelCellText($row, $column)))
			Return $CDRF_NEWFONT
	EndSwitch
	Return $CDRF_DODEFAULT
EndFunc


;~ v38.9: text of a cell for the custom draw, from the texts the panel itself last put in the ListView (ItemsPanelSetValue /
;~ ItemsPanelSetSession / ItemsPanelCreate are the only writers) instead of asking the ListView for it on every paint.
;~ The Item column's colour does not depend on its text. Unknown row: asks the ListView, as before.
Func ItemsPanelCellText($row, $column)
	If MapExists($items_panel_key_at, $row) Then
		Local $key = $items_panel_key_at[$row]
		Switch $column
			Case $ITEMS_PANEL_COL_SESSION
				If MapExists($items_panel_session_shown, $key) Then Return $items_panel_session_shown[$key]
			Case $ITEMS_PANEL_COL_TOTAL
				If MapExists($items_panel_shown, $key) Then Return $items_panel_shown[$key]
			Case 0
				Return ''
		EndSwitch
	EndIf
	Return _GUICtrlListView_GetItemText($items_panel_listview, $row, $column)
EndFunc


;~ Text colour (BGR) of an item-row cell: pure, unit-tested
Func ItemsPanelCellColor($column, $text)
	Local $value = StringReplace($text, '*', '')
	Switch $column
		Case $ITEMS_PANEL_COL_SESSION
			If StringLeft($value, 1) == '+' Then Return $ITEMS_PANEL_GAIN_TEXT
			If StringLeft($value, 1) == '-' Then Return $ITEMS_PANEL_LOSS_TEXT
			Return $ITEMS_PANEL_ZERO_TEXT
		Case $ITEMS_PANEL_COL_TOTAL
			If $value == '' Or $value == '0' Then Return $ITEMS_PANEL_ZERO_TEXT
			Return $ITEMS_PANEL_TOTAL_TEXT
	EndSwitch
	Return $ITEMS_PANEL_NAME_TEXT
EndFunc


;~ True when a game client is attached (memory reads are meaningful)
Func ItemsPanelIsAttached()
	If Not IsDeclared('attached_for_tools') Then Return False
	Return Eval('attached_for_tools') == True
EndFunc


;~ Refreshes the item totals. Not forced: at most every $ITEMS_PANEL_REFRESH_MS. Returns True when the counts were re-read.
Func ItemsPanelRefresh($force = False)
	If $items_panel_listview == 0 Then Return False
	If Not ItemsPanelIsAttached() Then Return False
	Local Static $timer = 0
	If Not $force And $timer <> 0 And TimerDiff($timer) < $ITEMS_PANEL_REFRESH_MS Then Return False
	$timer = TimerInit()
	Local $mapType = GetMapType()
	If $mapType == $ID_LOADING Or GetMyID() == 0 Then Return False

	Local $readable = False
	Local $empty[]
	$items_panel_last_readable = $empty
	Local $inventory = ItemsPanelCountBags(1, 5, $readable)
	Local $character = Eval('character_name')
	; v31: a session baseline is only taken from a complete live read (see ItemsPanelSessionObserve)
	Local $complete = False
	If $mapType == $ID_OUTPOST Then
		Local $storageReadable = False
		Local $storage = ItemsPanelCountBags(6, 21, $storageReadable)
		$complete = $storageReadable And ItemsPanelReadIsComplete() And IsMapReadyNow(-1, $ID_OUTPOST)
		If $storageReadable Then
			$items_panel_storage = $storage
			$items_panel_storage_time = @YEAR & '-' & @MON & '-' & @MDAY & ' ' & @HOUR & ':' & @MIN
			$items_panel_storage_char = $character
			$items_panel_storage_live = True
			ItemsPanelSaveStorageCache($character)
		Else
			$items_panel_storage_live = False
		EndIf
	Else
		$items_panel_storage_live = False
	EndIf
	If Not $items_panel_storage_live And $items_panel_storage_char <> $character Then ItemsPanelLoadStorageCache($character)
	ItemsPanelSessionObserve($character, $inventory, $items_panel_storage, $complete)
	ItemsPanelShowCounts($inventory)
	; v33: Titles tab (own baseline, independent of storage) at the same rate; Zaishen Keys owned = inventory + storage
	Local $keysMark = ($items_panel_storage_time <> '' And Not $items_panel_storage_live) ? $ITEMS_PANEL_CACHE_MARK : ''
	TitlesTabUpdate($character, $inventory, ItemsPanelMapGet($inventory, $ID_ZAISHEN_KEY) + ItemsPanelMapGet($items_panel_storage, $ID_ZAISHEN_KEY), $keysMark)
	Return True
EndFunc


;~ Writes inventory + storage totals into the item rows and the storage status line
Func ItemsPanelShowCounts($inventory)
	Local $haveStorage = $items_panel_storage_time <> ''
	Local $mark = ($haveStorage And Not $items_panel_storage_live) ? $ITEMS_PANEL_CACHE_MARK : ''
	Local $tomeTotal = 0, $tomeDelta = 0
	For $i = 0 To UBound($items_panel_rows) - 1
		Local $modelID = $items_panel_rows[$i][3]
		If $modelID == 0 Then ContinueLoop
		Local $total = ItemsPanelMapGet($inventory, $modelID) + ItemsPanelMapGet($items_panel_storage, $modelID)
		Local $delta = ItemsPanelSessionDelta($modelID, $total)
		If $items_panel_rows[$i][0] == 0 Then
			$tomeTotal += $total
			If IsKeyword($delta) <> 2 Then $tomeDelta += $delta
		EndIf
		ItemsPanelSetValue($items_panel_rows[$i][1], $total & $mark)
		; v31: Session column (blank until the baseline exists; '*' like Total when the storage part is the cached read)
		ItemsPanelSetSession($items_panel_rows[$i][1], IsKeyword($delta) == 2 ? '' : ItemsPanelFormatDelta($delta) & $mark)
	Next
	ItemsPanelSetValue('tome.total', $tomeTotal & $mark)
	ItemsPanelSetSession('tome.total', $items_panel_session_ready ? ItemsPanelFormatDelta($tomeDelta) & $mark : '')
	Local $status
	If $items_panel_storage_live Then
		$status = 'Storage: read in this outpost at ' & StringRight($items_panel_storage_time, 5)
	ElseIf $haveStorage Then
		$status = 'Storage ' & $ITEMS_PANEL_CACHE_MARK & ': last outpost read ' & $items_panel_storage_time
	Else
		$status = 'Storage not read yet: inventory only (visit an outpost)'
	EndIf
	If $items_panel_status <> 0 And GUICtrlRead($items_panel_status) <> $status Then GUICtrlSetData($items_panel_status, $status)
EndFunc


;~ Sums quantities per wanted model ID over bags $firstBag..$lastBag (bag 7 skipped). $readable: a bag with slots was found.
Func ItemsPanelCountBags($firstBag, $lastBag, ByRef $readable)
	Local $counts[]
	$readable = False
	$items_panel_scans += 1
	For $bagIndex = $firstBag To $lastBag
		If $bagIndex == 7 Then ContinueLoop
		Local $bag = GetBag($bagIndex)
		If Not IsDllStruct($bag) Then ContinueLoop
		Local $slots = DllStructGetData($bag, 'Slots')
		If $slots <= 0 Then ContinueLoop
		$readable = True
		$items_panel_last_readable[$bagIndex] = True
		If DllStructGetData($bag, 'ItemsCount') <= 0 Then ContinueLoop
		Local $bagItems = GetBagItemsOf($bagIndex, $bag)
		For $slot = 1 To $slots
			Local $item = $bagItems[$slot - 1]
			If Not IsDllStruct($item) Then ContinueLoop
			Local $modelID = DllStructGetData($item, 'ModelID')
			If $modelID == 0 Or Not MapExists($items_panel_wanted, $modelID) Then ContinueLoop
			$counts[$modelID] = ItemsPanelMapGet($counts, $modelID) + DllStructGetData($item, 'Quantity')
		Next
	Next
	Return $counts
EndFunc


Func ItemsPanelMapGet(ByRef $map, $key)
	If Not MapExists($map, $key) Then Return 0
	Return $map[$key]
EndFunc


Func ItemsPanelCacheFile()
	Return @ScriptDir & '\cache\xunlai_counts.ini'
EndFunc


;~ Persists the last storage read (one INI section per character) - only when it changed
Func ItemsPanelSaveStorageCache($character)
	If $character == '' Then Return False
	Local $data = ''
	For $modelID In MapKeys($items_panel_storage)
		$data &= 'm' & $modelID & '=' & $items_panel_storage[$modelID] & @LF
	Next
	Local Static $lastSaved = ''
	If $lastSaved == $character & '|' & $data Then Return True
	DirCreate(@ScriptDir & '\cache')
	If Not IniWriteSection(ItemsPanelCacheFile(), $character, 'time=' & $items_panel_storage_time & @LF & $data) Then Return False
	$lastSaved = $character & '|' & $data
	Return True
EndFunc


;~ Loads the last storage read for a character from the cache file (empty when none)
Func ItemsPanelLoadStorageCache($character)
	Local $empty[]
	$items_panel_storage = $empty
	$items_panel_storage_time = ''
	$items_panel_storage_char = $character
	If $character == '' Then Return False
	Local $section = IniReadSection(ItemsPanelCacheFile(), $character)
	If @error Then Return False
	For $i = 1 To $section[0][0]
		If $section[$i][0] == 'time' Then
			$items_panel_storage_time = $section[$i][1]
		ElseIf StringLeft($section[$i][0], 1) == 'm' Then
			Local $modelID = Number(StringTrimLeft($section[$i][0], 1))
			If $modelID > 0 And MapExists($items_panel_wanted, $modelID) Then $items_panel_storage[$modelID] = Number($section[$i][1])
		EndIf
	Next
	Return $items_panel_storage_time <> ''
EndFunc
