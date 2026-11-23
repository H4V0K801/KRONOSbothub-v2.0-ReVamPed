#CS ===========================================================================
; Author: caustic-kronos (aka Kronos, Night, Svarog)
; Contributors: Gahais, JackLinesMatthews
; Copyright 2025 caustic-kronos
;
; Licensed under the Apache License, Version 2.0 (the 'License');
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
; http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an 'AS IS' BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
#CE ===========================================================================

#include-once
#include 'SQLite.au3'
#include 'SQLite.dll.au3'
#include 'GWA2.au3'
#include 'GWA2_Assembly.au3'
#include 'GWA2_Headers.au3'
#include 'GWA2_ID.au3'
#include 'GWA2_ID_Items.au3'
#include 'GWA2_ID_Maps.au3'
#include 'GWA2_ID_Skills.au3'
#include 'Utils.au3'
#include 'Utils-Agents.au3'
#include 'Utils-Console.au3'
#include 'Utils-Items_Modstructs.au3'
#include 'Utils-Storage.au3'

; v22: Expert Salvage Kits bought per 'before selling' pass at most (25 uses each = up to 125 extractions, 2000 gold)
Global Const $EXTRACT_MAX_KIT_BUYS_PER_PASS = 5
Global Const $EXTRACT_GUARD_REFRESH_MS = 120000
; v22: checked definitions while 'Extract selected components before selling' protects items from material salvage / selling
Global $extract_guard_definitions = Null
; v37.2: cache of GetCheckedUpgradeLeaves (the Inventory tree walk is slow). Invalidated on Load, Apply,
; any Inventory tree checkbox change, and at run start so tick changes take effect as before.
Global $extract_states_cache_valid = False
Global $extract_states_cache[]
Global $extract_states_cache_source = ''
Global $extract_leaves_cache[]
Global $extract_branchsize_cache[]
; v38.2: store-protection map, rebuilt only after a tick change (same invalidation as extract leaves)
Global $store_protection_cache_valid = False
Global $store_protection_cache[]
Global $store_protection_cache_source = ''
Global $store_protection_cache_rebuilds = 0


;~ v25: Store items > Components root and its four groups (see #Region Store components)
Global Const $STORE_COMPONENTS_ROOT = 'Store items.Components'
Global Const $STORE_COMPONENT_GROUPS[] = ['Mods', 'Inscriptions', 'Insignias', 'Runes']
; v35: Inventory extract branch name; $EXTRACT_TREE_ROOT_LEGACY is accepted on load (ticks preserved)
Global Const $EXTRACT_TREE_ROOT = 'Extract Components'
Global Const $EXTRACT_TREE_ROOT_LEGACY = 'Extract upgrades only'


#Region Inventory Management
;~ Function to deal with inventory before farm run
Func InventoryManagementBeforeRun($tradeTown = $ID_EYE_OF_THE_NORTH)
	; v38.6: no storage sort here - sorting is manual only (Sort now)
	; v38.2: extract-leaf / store-protection caches are kept across looped town passes
	; Clarity rename
	Local $cache = $inventory_management_cache
	; Operations order :
	; 1-Store unids if desired
	; 2-Sort items
	; 3-Identify items
	; 4-Collect data
	; 4b-v22: Extract selected components before selling (Options tab checkbox, run.extract_upgrades_only)
	; 4c-v25: Store the loose components ticked under Store items > Components (right after 4b, before any salvage or sale)
	; 5-Salvage
	; 6-Sell materials
	; 7-Sell items
	; 8-Balance character gold level
	; 9-Buy ectoplasm/obsidian with surplus
	; 10-Store items
	If $cache['Store items.Unidentified gold items'] And HasGoldUnidentifiedItems() Then
		If GetMapType() <> $ID_OUTPOST Then TravelToOutpost($tradeTown, $district_name)
		StoreItemsInXunlaiStorage(IsUnidentifiedGoldItem)
	EndIf
	If $run_options_cache['run.sort_items'] Then SortInventory()
	If $cache['@identify.something'] And HasUnidentifiedItems() Then
		TravelToOutpost($tradeTown, $district_name)
		IdentifyItems()
	EndIf
	If $run_options_cache['run.collect_data'] Then
		ConnectToDatabase()
		InitializeDatabase()
		CompleteModelLookupTable()
		CompleteUpgradeLookupTable()
		StoreAllItemsData()
		DisconnectFromDatabase()
	EndIf
	; v22: extraction BEFORE salvaging for materials and selling; while the option is on, items still holding a checked
	; component are not salvaged for materials or sold (IsHeldForExtraction) until the end of this pass
	If IsExtractUpgradesOnly() Then ExtractSelectedComponentsBeforeSelling($tradeTown)
	; v25: the loose components ticked under Store items > Components (the ones just extracted included) go to Xunlai storage
	; BEFORE material salvage and selling. Storage full = logged, the pass continues (loose components are never sold or salvaged).
	If $cache['@store.components.something'] Then StoreSelectedComponentsBeforeSelling($tradeTown)
	If $cache['@salvage.something'] And HasItemsToSalvage() Then
		TravelToOutpost($tradeTown, $district_name)
		SalvageItems()
		If $bags_count == 5 And MoveItemsOutOfEquipmentBag() > 0 Then SalvageItems()
		;SalvageInscriptions()
		;UpgradeWithSalvageInscriptions()
		;SalvageMaterials()
	EndIf
	If $cache['@sell.materials.something'] And (HasBasicMaterialsToTrade() Or HasRareMaterialsToTrade()) Then
		TravelToOutpost($tradeTown, $district_name)
		; If we have more than 60k, we risk running into the situation we cannot sell because we're too rich, so we store some in xunlai
		If GetGoldCharacter() > 60000 Then BalanceCharacterGold(10000)
		If $cache['@sell.materials.basic.something'] And HasBasicMaterials() Then SellBasicMaterialsToMerchant()
		If $cache['@sell.materials.rare.something'] And HasRareMaterials() Then SellRareMaterialsToMerchant()
	EndIf
	If $cache['@sell.something'] And HasItemsToSell() Then
		TravelToOutpost($tradeTown, $district_name)
		; If we have more than 60k, we risk running into the situation we cannot sell because we're too rich, so we store some in xunlai
		If GetGoldCharacter() > 60000 Then BalanceCharacterGold(10000)
		SellItemsToMerchant()
	EndIf
	; Max gold in Xunlai chest is 1000 platinums
	If $cache['Store items.Gold'] Then
		If GetMapType() <> $ID_OUTPOST Then TravelToOutpost($tradeTown, $district_name)
		BalanceCharacterGold(10000)
	EndIf
	; TODO: generalize this for all materials
	If GetGoldCharacter() > 10000 Then
		If $cache['Buy items.Lockpicks'] Then
			Local $lockpicksToBuy = Floor((GetGoldCharacter() - 10000) / 1500)
			If $lockpicksToBuy > 0 Then BuyLockpicksInTown($lockpicksToBuy)
		ElseIf $cache['Buy items.Rare Materials.Obsidian Shard'] Then
			TravelToOutpost($tradeTown, $district_name)
			BuyRareMaterialFromMerchantUntilPoor($ID_OBSIDIAN_SHARD, 10000, $ID_GLOB_OF_ECTOPLASM)
		ElseIf $cache['Buy items.Rare Materials.Glob of Ectoplasm'] Then
			TravelToOutpost($tradeTown, $district_name)
			BuyRareMaterialFromMerchantUntilPoor($ID_GLOB_OF_ECTOPLASM, 10000, $ID_OBSIDIAN_SHARD)
		EndIf
	EndIf
	If $cache['@store.something'] Then
		If GetMapType() <> $ID_OUTPOST Then TravelToOutpost($tradeTown, $district_name)
		StoreItemsInXunlaiStorage()
	EndIf
	; v38.6: no storage sort in the town pass - sorting is manual only (Sort now)
	$extract_guard_definitions = Null
	; v23: Items panel totals after selling/storing (no-op headless / without the panel)
	ItemsPanelRefresh(True)
	ResetBotsSetups()
	Return $PAUSE
EndFunc


;~ Function to deal with inventory during farm to preserve inventory space
Func InventoryManagementMidRun($tradeTown = $ID_EYE_OF_THE_NORTH)
	; Operations order :
	; 1-Check if we have at least 1 identification kit and 1 salvage kit
	; 2-If not, buy until we have 4 identification kits and 12 salvaged kits
	; 3-Sort items
	; 4-Identify items
	; 5-Salvage
	Local Static $superiorIdentificationKits = [$ID_SUPERIOR_IDENTIFICATION_KIT]
	Local Static $salvageKits = [$ID_SALVAGE_KIT, $ID_SALVAGE_KIT_2]
	If GetInventoryKitCount($superiorIdentificationKits) < 1 Or GetInventoryKitCount($salvageKits) < 1 Then
		Info('Buying kits for passive inventory management')
		TravelToOutpost($tradeTown, $district_name)
		; Since we are in trade town, might as well clear inventory (v22: in THIS trade town - it used the Eye of the North
		; default; the extraction before selling runs inside it when ticked)
		InventoryManagementBeforeRun($tradeTown)
		BuyKitsForMidRun()
		Return True
	EndIf
	If $run_options_cache['run.sort_items'] Then SortInventory()
	If $inventory_management_cache['@identify.something'] And HasUnidentifiedItems() Then IdentifyItems(False)
	; v22: no extraction in explorables (no merchant to replace a kit, foes around); with 'Extract selected components before
	; selling' on, mid-run material salvage leaves items holding a checked component for the town pass
	If IsExtractUpgradesOnly() Then $extract_guard_definitions = GetExtractGuardDefinitionsCached()
	If $inventory_management_cache['@salvage.something'] Then
		SalvageItems(False)
		If $bags_count == 5 And MoveItemsOutOfEquipmentBag() > 0 Then SalvageItems()
	EndIf
	$extract_guard_definitions = Null
	Return False
EndFunc


;~ Sort the inventory in this order :
Func SortInventory()
	Info('Sorting inventory')
	;						0-Lockpicks 1-Books	2-Consumables	3-Trophies	4-Tomes	5-Materials	6-Others	7-Armor Salvageables[Gold,	8-Purple,	9-Blue	10-White]	11-Weapons [White,	12-Blue,	13-Purple,	14-Gold,	15-Green]	16-Armor (Armor salvageables, weapons and armor start from the end)
	Local $itemsCounts = [	0,			0,		0,				0,			0,		0,			0,			0,							0,			0,		0,			0,					0,			0,			0,			0,			0]
	Local $bagsSizes[6]
	Local $bagsSize = 0
	Local $bag, $item, $itemID, $rarity
	Local $items[80]
	Local $k = 0
	For $bagIndex = 1 To $bags_count
		$bag = GetBag($bagIndex)
		$bagsSizes[$bagIndex] = DllStructGetData($bag, 'slots')
		$bagsSize += $bagsSizes[$bagIndex]
		For $slot = 1 To $bagsSizes[$bagIndex]
			$item = GetItemBySlot($bagIndex, $slot)
			$itemID = DllStructGetData(($item), 'ModelID')

			If DllStructGetData($item, 'ID') == 0 Then ContinueLoop
			$items[$k] = $item
			$k += 1
			; Weapon
			If IsWeapon($item) Then
				$rarity = GetRarity($item)
				If ($rarity == $RARITY_GOLD) Then
					$itemsCounts[14] += 1
				ElseIf ($rarity == $RARITY_PURPLE) Then
					$itemsCounts[13] += 1
				ElseIf ($rarity == $RARITY_BLUE) Then
					$itemsCounts[12] += 1
				ElseIf ($rarity == $RARITY_GREEN) Then
					$itemsCounts[15] += 1
				ElseIf ($rarity == $RARITY_WHITE) Then
					$itemsCounts[11] += 1
				EndIf
			; ArmorSalvage
			ElseIf IsArmorSalvageItem($item) Then
				$rarity = GetRarity($item)
				If ($rarity == $RARITY_GOLD) Then
					$itemsCounts[7] += 1
				ElseIf ($rarity == $RARITY_PURPLE) Then
					$itemsCounts[8] += 1
				ElseIf ($rarity == $RARITY_BLUE) Then
					$itemsCounts[9] += 1
				ElseIf ($rarity == $RARITY_WHITE) Then
					$itemsCounts[10] += 1
				EndIf
			; Trophies
			ElseIf IsTrophy($itemID) Then
				$itemsCounts[3] += 1
			; Consumables
			ElseIf IsConsumable($itemID) Then
				$itemsCounts[2] += 1
			; Materials
			ElseIf IsMaterial($item) Then
				$itemsCounts[5] += 1
			; Lockpick
			ElseIf ($itemID == $ID_LOCKPICK) Then
				$itemsCounts[0] += 1
			; Tomes
			ElseIf IsTome($itemID) Then
				$itemsCounts[4] += 1
			; Armor
			ElseIf IsArmor($item) Then
				$itemsCounts[16] += 1
			; Books
			ElseIf IsBook($item) Then
				$itemsCounts[1] += 1
			; Others
			Else
				$itemsCounts[6] += 1
			EndIf
		Next
	Next


	Local $itemsPositions[17]
	$itemsPositions[0] = 1
	$itemsPositions[16] = $bagsSize + 1 - $itemsCounts[16]
	For $i = 1 To 6
		$itemsPositions[$i] = $itemsPositions[$i - 1] + $itemsCounts[$i - 1]
	Next
	For $i = 15 To 7 Step -1
		$itemsPositions[$i] = $itemsPositions[$i + 1] - $itemsCounts[$i]
	Next


	Local $bagAndSlot
	Local $category
	For $item In $items
		$itemID = DllStructGetData($item, 'ModelID')
		If $itemID == 0 Then ExitLoop

		; Weapon
		If IsWeapon($item) Then
			$rarity = GetRarity($item)
			If ($rarity == $RARITY_GOLD) Then
				$category = 14
			ElseIf ($rarity == $RARITY_PURPLE) Then
				$category = 13
			ElseIf ($rarity == $RARITY_BLUE) Then
				$category = 12
			ElseIf ($rarity == $RARITY_GREEN) Then
				$category = 15
			ElseIf ($rarity == $RARITY_WHITE) Then
				$category = 11
			EndIf
		; ArmorSalvage
		ElseIf isArmorSalvageItem($item) Then
			$rarity = GetRarity($item)
			If ($rarity == $RARITY_GOLD) Then
				$category = 7
			ElseIf ($rarity == $RARITY_PURPLE) Then
				$category = 8
			ElseIf ($rarity == $RARITY_BLUE) Then
				$category = 9
			ElseIf ($rarity == $RARITY_WHITE) Then
				$category = 10
			EndIf
		; Trophies
		ElseIf IsTrophy($itemID) Then
			$category = 3
		; Consumables
		ElseIf IsConsumable($itemID) Then
			$category = 2
		; Materials
		ElseIf IsMaterial($item) Then
			$category = 5
		; Lockpick
		ElseIf ($itemID == $ID_LOCKPICK) Then
			$category = 0
		; Tomes
		ElseIf IsTome($itemID) Then
			$category = 4
		; Armor
		ElseIf IsArmor($item) Then
			$category = 16
		; Books
		ElseIf IsBook($item) Then
			$category = 1
		; Others
		Else
			$category = 6
		EndIf

		$bagAndSlot = GetBagAndSlotFromGeneralSlot($bagsSizes, $itemsPositions[$category])
		Debug('Moving item ' & DllStructGetData($item, 'ModelID') & ' to bag ' & $bagAndSlot[0] & ', position ' & $bagAndSlot[1])
		MoveItem($item, $bagAndSlot[0], $bagAndSlot[1])
		$itemsPositions[$category] += 1
		RandomSleep(50)
	Next
EndFunc


;~ Return True if the item should be picked up
;~ Only pick rare materials, black and white dyes, lockpicks, gold items and green items
Func PickOnlyImportantItem($item)
	Local $itemID = DllStructGetData(($item), 'ModelID')
	Local $dyeColor = DllStructGetData($item, 'DyeColor')
	Local $rarity = GetRarity($item)
	If IsRareMaterial($item) Then
		Return True
	ElseIf ($itemID == $ID_DYES) Then
		Return (($dyeColor == $ID_BLACK_DYE) Or ($dyeColor == $ID_WHITE_DYE))
	ElseIf ($itemID == $ID_LOCKPICK) Then
		Return True
	ElseIf ($rarity == $RARITY_GOLD) Then
		Return True
	ElseIf ($rarity == $RARITY_GREEN) Then
		Return True
	ElseIf $rarity <> $RARITY_WHITE And IsWeapon($item) And IsLowReqMaxDamage($item) Then
		Return True
	EndIf
	Return False
EndFunc


;~ Return True if the item should be picked up - default to False
Func DefaultShouldPickItem($item)
	; Clarity rename
	Local $cache = $inventory_management_cache
	If $cache['@pickup.nothing'] Then Return False
	If $cache['@pickup.everything'] Then Return True

	Local $itemID = DllStructGetData(($item), 'ModelID')
	Local $rarity = GetRarity($item)

	; ---------------------------------------- Money ----------------------------------------
	If (($itemID == $ID_MONEY) And (GetGoldCharacter() < 99000)) Then
		Return $cache['Pick up items.Gold']
	; --------------------------------------- Weapons ---------------------------------------
	ElseIf IsWeapon($item) Then
		Return CheckPickupWeapon($item)
	; --------------------------------- Armor salvageables ---------------------------------
	ElseIf isArmorSalvageItem($item) Then
		Local $rarityName = $RARITY_NAMES_FROM_IDS[$rarity]
		Return $cache['Pick up items.Armor salvageables.' & $rarityName]
	; --------------------------- Consumables, Alcohols, Party & Sweets ---------------------------
	ElseIf IsAlcohol($itemID) Then
		If $MAP_MINOR_ALCOHOLS[$itemID] <> Null Then Return $cache['Pick up items.Alcohols.Minor (1pt)']
		If $MAP_MAJOR_ALCOHOLS[$itemID] <> Null Then Return $cache['Pick up items.Alcohols.Major (3pt)']
		If $MAP_SUPERIOR_ALCOHOLS[$itemID] <> Null Then Return $cache['Pick up items.Alcohols.Superior (50pt)']
		Return False
	ElseIf IsFestive($itemID) Or IsPartyTonic($itemID) Then
		If $MAP_MINOR_PARTY[$itemID] <> Null Then Return $cache['Pick up items.Party.Minor (1-2pt)']
		If $MAP_MAJOR_PARTY[$itemID] <> Null Then Return $cache['Pick up items.Party.Major (3-7pt)']
		If $MAP_SUPERIOR_PARTY[$itemID] <> Null Then Return $cache['Pick up items.Party.Superior (25-50pt)']
		Return False
	ElseIf IsTownSweet($itemID) Then
		If $MAP_MINOR_SWEETS[$itemID] <> Null Then Return $cache['Pick up items.Sweets.Minor (1-2pt)']
		If $MAP_MAJOR_SWEETS[$itemID] <> Null Then Return $cache['Pick up items.Sweets.Major (3pt)']
		If $MAP_SUPERIOR_SWEETS[$itemID] <> Null Then Return $cache['Pick up items.Sweets.Superior (50pt)']
		Return False
	ElseIf IsConsumable($itemID) Then
		Return $cache['Pick up items.Consumables']
	ElseIf IsSpecialDrop($itemID) Then
		Local $festivalDropName = $SPECIAL_DROP_NAMES_FROM_IDS[$itemID]
		Return $cache['Pick up items.Festival Items.' & $festivalDropName]
	; --------------------------------------- Trophies ---------------------------------------
	ElseIf IsTrophy($itemID) Then
		If $MAP_FARMED_TROPHIES[$itemID] <> Null Then Return $cache['Pick up items.Trophies.' & $FARMED_TROPHIES_NAMES_FROM_ID[$itemID]]
		Return $cache['Pick up items.Trophies.Other trophies']
	; -------------------------------------- Materials --------------------------------------
	ElseIf IsBasicMaterial($item) Then
		Local $materialName = $BASIC_MATERIAL_NAMES_FROM_IDS[$itemID]
		Return $cache['Pick up items.Basic Materials.' & $materialName]
	ElseIf IsRareMaterial($item) Then
		Local $materialName = $RARE_MATERIAL_NAMES_FROM_IDS[$itemID]
		Return $cache['Pick up items.Rare Materials.' & $materialName]
	; ---------------------------------------- Tomes ----------------------------------------
	ElseIf IsRegularTome($itemID) Then
		Local $tomeName = $REGULAR_TOME_NAMES_FROM_IDS[$itemID]
		Return $cache['Pick up items.Tomes.Normal.' & $tomeName]
	ElseIf IsEliteTome($itemID) Then
		Local $tomeName = $ELITE_TOME_NAMES_FROM_IDS[$itemID]
		Return $cache['Pick up items.Tomes.Elite.' & $tomeName]
	; --------------------------------------- Scrolls ---------------------------------------
	ElseIf IsGoldScroll($itemID) Then
		Local $scrollName = $GOLD_SCROLL_NAMES_FROM_IDS[$itemID]
		Local $pickup = $cache['Pick up items.Scrolls.Gold.' & $scrollName]
		If $pickup <> Null Then Return $pickup
		Return $cache['Pick up items.Scrolls.Gold.Other gold scrolls']
	ElseIf IsBlueScroll($itemID) Then
		Return $cache['Pick up items.Scrolls.Blue']
	; ----------------------------------------- Keys -----------------------------------------
	ElseIf IsKey($itemID) Then
		Return $cache['Pick up items.Keys']
	ElseIf ($itemID == $ID_LOCKPICK) Then
		; option 'Pick up items.Lockpicks' (missing from an old config = picked up, as before)
		Return $cache['Pick up items.Lockpicks'] <> False
	; ----------------------------------------- Dyes -----------------------------------------
	ElseIf ($itemID == $ID_DYES) Then
		Local $dyeColorID = DllStructGetData($item, 'DyeColor')
		Local $dyeColorName = $DYE_NAMES_FROM_IDS[$dyeColorID]
		Return $cache['Pick up items.Dyes.' & $dyeColorName]
	; --------------------------------- Gizmos & Quest items ---------------------------------
	ElseIf ($itemID == $ID_JAR_OF_INVIGORATION) Then
		Return False
	ElseIf IsMapPiece($itemID) Then
		Return $cache['Pick up items.Quest items.Map pieces']
	ElseIf IsMiniature($item) Then
		Return True
	; ----------------------------------- Other stackables -----------------------------------
	ElseIf IsStackable($item) Then
		Return True
	EndIf
	Return False
EndFunc


;~ Return True if the item should be salvaged - default to false
Func IsSalvageIntoMaterialsEnabled()
	Return MapExists($run_options_cache, 'run.salvage_into_materials') And $run_options_cache['run.salvage_into_materials']
EndFunc


Func DefaultShouldSalvageItem($item)
	; Clarity rename
	Local $cache = $inventory_management_cache
	If $cache['@salvage.nothing'] Then Return False
	; v35: Setup 'Salvage into materials' is the master switch (unticked = no material salvage)
	If Not IsSalvageIntoMaterialsEnabled() Then Return False
	; v8: anything matching a checked 'Store items' entry is never salvaged
	Local $storeReason = ''
	If IsProtectedByStoreItems($item, $inventory_management_cache, $storeReason) Then
		Debug('Salvage skipped for item ' & DllStructGetData($item, 'ID') & ': protected by Store items (' & $storeReason & ')')
		Return False
	EndIf
	; v22: still holds a checked component (Extract selected components before selling)
	If IsHeldForExtraction($item, 'salvaged for materials') Then Return False
	; v25: a loose upgrade component (rune, insignia, weapon mod, inscription) is never salvaged
	If IsLooseUpgradeComponent($item) Then Return False

	Local $itemID = DllStructGetData($item, 'ModelID')
	Local $rarity = GetRarity($item)
	If $rarity == $RARITY_GREEN Then
		Return False
	; --------------------------------------- Weapons ---------------------------------------
	ElseIf IsWeapon($item) Then
		If Not DllStructGetData($item, 'IsMaterialSalvageable') Then Return False
		If $cache['@salvage.weapons.nothing'] Then Return False
		If Not CheckSalvageWeapon($item) Then Return False
		Return Not ShouldKeepWeapon($item)
	; --------------------------------- Armor salvageables ---------------------------------
	ElseIf IsArmorSalvageItem($item) Then
		If $cache['@salvage.salvageables.nothing'] Then Return False
		Local $rarityName = $RARITY_NAMES_FROM_IDS[$rarity]
		If Not $cache['Salvage items.Armor salvageables.' & $rarityName] Then Return False
		; v29: no Keep components any more - ticked runes/insignias are extracted first (Extract upgrades only + hold), then salvaged
		Return IsIdentified($item)
	; --------------------------------------- Trophies ---------------------------------------
	ElseIf IsTrophy($itemID) Then
		If $MAP_FARMED_TROPHIES[$itemID] <> Null Then
			Local $shouldSalvage = $cache['Salvage items.Trophies.' & $FARMED_TROPHIES_NAMES_FROM_ID[$itemID]]
			Return $shouldSalvage == Null ? False : $shouldSalvage
		EndIf
		; Do not salvage Nick items and items that salvage into rare materials
		If $MAP_NICHOLAS_ITEMS[$itemID] <> Null Then Return False
		; - FIXME: salvage once we can salvage with higher salvage kit
		If $MAP_RARE_MATERIALS_TROPHIES[$itemID] <> Null Then Return False
		; Salvage items that salvage into feathers, dust, bones and fiber
		If $MAP_FEATHER_TROPHIES[$itemID] <> Null Then Return True
		If $MAP_DUST_TROPHIES[$itemID] <> Null Then Return True
		If $MAP_BONES_TROPHIES[$itemID] <> Null Then Return True
		If $MAP_FIBER_TROPHIES[$itemID] <> Null Then Return True
		Return False
	; -------------------------------------- Materials --------------------------------------
	ElseIf IsRareMaterial($item) Then
		Local $materialName = $RARE_MATERIAL_NAMES_FROM_IDS[$itemID]
		Return $cache['Salvage items.Rare Materials.' & $materialName]
	EndIf
	Return False
EndFunc


;~ Return True if the item should be sold to the merchant - default to false
Func DefaultShouldSellItem($item)
	; Clarity rename
	Local $cache = $inventory_management_cache
	If $cache['@sell.nothing'] Then Return False
	; v35: anything matching a checked 'Store items' entry is never sold
	Local $storeReason = ''
	If IsProtectedByStoreItems($item, $inventory_management_cache, $storeReason) Then
		Debug('Sell skipped for item ' & DllStructGetData($item, 'ID') & ': protected by Store items (' & $storeReason & ')')
		Return False
	EndIf
	; v22: still holds a checked component (Extract selected components before selling)
	If IsHeldForExtraction($item, 'sold') Then Return False
	; v25: a loose upgrade component (rune, insignia, weapon mod, inscription) is never sold
	If IsLooseUpgradeComponent($item) Then Return False

	Local $itemID = DllStructGetData(($item), 'ModelID')
	Local $rarity = GetRarity($item)

	If DllStructGetData($item, 'Value') == 0 Then
		Return False
	ElseIf $rarity == $RARITY_GREEN Then
		Return False
	; --------------------------------------- Weapons ---------------------------------------
	ElseIf IsWeapon($item) Then
		If $cache['@sell.weapons.nothing'] Then Return False
		If Not CheckSellWeapon($item) Then Return False
		Return Not ShouldKeepWeapon($item)
	; --------------------------------- Armor salvageables ---------------------------------
	ElseIf isArmorSalvageItem($item) Then
		If $cache['@sell.salvageables.nothing'] Then Return False
		Local $rarityName = $RARITY_NAMES_FROM_IDS[$rarity]
		If Not $cache['Sell items.Armor salvageables.' & $rarityName] Then Return False
		; v29: no Keep components any more - ticked runes/insignias are extracted first (Extract upgrades only + hold), then sold
		Return $rarity == $RARITY_WHITE Or IsIdentified($item)
	; --------------------------------------- Trophies ---------------------------------------
	ElseIf IsTrophy($itemID) Then
		If $MAP_FARMED_TROPHIES[$itemID] <> Null Then
			Local $shouldSell = $cache['Sell items.Trophies.' & $FARMED_TROPHIES_NAMES_FROM_ID[$itemID]]
			Return $shouldSell == Null ? False : $shouldSell
		EndIf
		; Do not sell Nick items and items that salvage into rare materials
		If $MAP_NICHOLAS_ITEMS[$itemID] <> Null Then Return False
		If $MAP_RARE_MATERIALS_TROPHIES[$itemID] <> Null Then Return False
		; Do not sell items that salvage into feathers, dust, bones and fiber
		If $MAP_FEATHER_TROPHIES[$itemID] <> Null Then Return False
		If $MAP_DUST_TROPHIES[$itemID] <> Null Then Return False
		If $MAP_BONES_TROPHIES[$itemID] <> Null Then Return False
		If $MAP_FIBER_TROPHIES[$itemID] <> Null Then Return False
		; Sell the rest
		Return True
	; --------------------------------------- Scrolls ---------------------------------------
	ElseIf IsBlueScroll($itemID) Then
		Return $cache['Sell items.Scrolls.Blue']
	ElseIf IsGoldScroll($itemID) Then
		Local $scrollName = $GOLD_SCROLL_NAMES_FROM_IDS[$itemID]
		Local $shouldSell = $cache['Sell items.Scrolls.Gold.' & $scrollName]
		If $shouldSell <> Null Then Return $shouldSell
		Return $cache['Sell items.Scrolls.Gold.Other gold scrolls']
	; ----------------------------------------- Keys -----------------------------------------
	ElseIf IsKey($itemID) Then
		Return $cache['Sell items.Keys']
	EndIf
	Return False
EndFunc


;~ Return True if the item should be stored in Xunlai Storage - default to false
Func DefaultShouldStoreItem($item)
	Return ShouldStoreItemWithCache($item, $inventory_management_cache)
EndFunc


;~ v8: the Store items rules, evaluated on an explicit cache (body of DefaultShouldStoreItem, unchanged).
;~ Used by DefaultShouldStoreItem (global cache, store behaviour unchanged) and by the salvage protection (live GUI ticks).
Func ShouldStoreItemWithCache($item, ByRef $cache)
	If $cache['@store.nothing'] Then Return False

	Local $itemID = DllStructGetData(($item), 'ModelID')
	Local $rarity = GetRarity($item)
	Local $quantity = DllStructGetData($item, 'Quantity')

	; --------------------------------------- Weapons ---------------------------------------
	If IsWeapon($item) Then
		;Return ShouldKeepWeapon($item)
		Local $storeWeaponKey = GetStoreWeaponKey($item)
		Return $storeWeaponKey <> '' And $cache[$storeWeaponKey] == True
	; --------------------------------- Armor salvageables ---------------------------------
	ElseIf isArmorSalvageItem($item) Then
		Local $rarityName = $RARITY_NAMES_FROM_IDS[$rarity]
		Return $cache['Store items.Armor salvageables.' & $rarityName]
	; ------------- v25: loose upgrade components - Store items > Components > Mods/Inscriptions/Insignias/Runes -------------
	ElseIf IsLooseUpgradeComponent($item) Then
		Return FindStoreComponentMatch($item, $cache) <> ''
	; ------------------------------------- Consumables -------------------------------------
	ElseIf IsConsumable($itemID) Then
		If $quantity <> 250 Then Return False
		Return $cache['Store items.Consumables']
	ElseIf IsSpecialDrop($itemID) Then
		Local $festivalDropName = $SPECIAL_DROP_NAMES_FROM_IDS[$itemID]
		Return $cache['Store items.Festival Items.' & $festivalDropName]
	; --------------------------------------- Trophies ---------------------------------------
	ElseIf IsTrophy($itemID) Then
		If $MAP_FARMED_TROPHIES[$itemID] <> Null Then Return $cache['Store items.Trophies.' & $FARMED_TROPHIES_NAMES_FROM_ID[$itemID]]
		If $quantity <> 250 Then Return False
		; option 'Store items.Trophies.Other trophies' (missing from an old config = stored, as before)
		Return $cache['Store items.Trophies.Other trophies'] <> False
	; -------------------------------------- Materials --------------------------------------
	ElseIf IsBasicMaterial($item) Then
		Local $materialName = $BASIC_MATERIAL_NAMES_FROM_IDS[$itemID]
		Return $cache['Store items.Basic Materials.' & $materialName]
	ElseIf IsRareMaterial($item) Then
		Local $materialName = $RARE_MATERIAL_NAMES_FROM_IDS[$itemID]
		Return $cache['Store items.Rare Materials.' & $materialName]
	; ----------------------------------------- Tomes -----------------------------------------
	ElseIf IsRegularTome($itemID) Then
		Local $tomeName = $REGULAR_TOME_NAMES_FROM_IDS[$itemID]
		Return $cache['Store items.Tomes.Normal.' & $tomeName]
	ElseIf IsEliteTome($itemID) Then
		Local $tomeName = $ELITE_TOME_NAMES_FROM_IDS[$itemID]
		Return $cache['Store items.Tomes.Elite.' & $tomeName]
	; --------------------------------------- Scrolls ---------------------------------------
	ElseIf IsGoldScroll($itemID) Then
		Local $scrollName = $GOLD_SCROLL_NAMES_FROM_IDS[$itemID]
		Local $shouldStore = $cache['Store items.Scrolls.Gold.' & $scrollName]
		If $shouldStore <> Null Then Return $shouldStore
		Return $cache['Store items.Scrolls.Gold.Other gold scrolls']
	ElseIf IsBlueScroll($itemID) Then
		Return $cache['Store items.Scrolls.Blue']
	; ----------------------------------------- Keys -----------------------------------------
	ElseIf IsKey($itemID) Then
		Return $cache['Store items.Keys']
	; ----------------------------------------- Dyes -----------------------------------------
	ElseIf ($itemID == $ID_DYES) Then
		Local $dyeColorID = DllStructGetData($item, 'DyeColor')
		Local $dyeColorName = $DYE_NAMES_FROM_IDS[$dyeColorID]
		Return $cache['Store items.Dyes.' & $dyeColorName]
	EndIf
	Return False
EndFunc


;~ Return True if weapon item should not be sold or salvaged
;~ v27 (AMG): an old-school (non-inscribable) weapon is never kept whole because of its inherent (non-salvageable) mods any more -
;~ the ONLY OS auto-keeps are IsOSAutoKeepWeapon (q9 + inherent Energy +5; wand or focus q9-q10 halving casting time AND skill
;~ recharge - 20% of the item's attribute or 10% of all spells, any mix). Staves have no OS auto-keep.
;~ Salvageable upgrades (prefix/suffix mods incl. Zealous / Vampiric, inscriptions) only count through the ticked
;~ 'Extract upgrades only' list (extracted, then the weapon is salvaged/sold). v29: 'Keep components' removed (AMG) - a weapon is
;~ never kept whole for its mods any more.
Func ShouldKeepWeapon($item)
	Local Static $lowReqValuableWeaponTypes = [$ID_TYPE_SWORD, $ID_TYPE_OFFHAND, $ID_TYPE_SHIELD, $ID_TYPE_DAGGER, $ID_TYPE_SCYTHE, $ID_TYPE_SPEAR]
	Local Static $lowReqValuableWeaponTypesMap = MapFromArray($lowReqValuableWeaponTypes)

	Local $rarity = GetRarity($item)
	Local $itemID = DllStructGetData($item, 'ModelID')
	; Keeping equipped items
	If DllStructGetData($item, 'Equipped') Then Return True
	; Keeping customized items
	If DllStructGetData($item, 'Customized') <> 0 Then Return True
	; Throwing white items
	If $rarity == $RARITY_WHITE Then Return False
	; Keeping green items
	If $rarity == $RARITY_GREEN Then Return True
	; Keeping unidentified items
	If Not IsIdentified($item) Then Return True
	; Keeping super-rare items, good in all cases, items (BDS, voltaic, etc) - by model, not by mods
	If $MAP_ULTRA_RARE_WEAPONS[$itemID] <> Null Then Return True
	; v27: OS - Old School weapon without inscription: only IsOSAutoKeepWeapon, nothing else (no rare-skin / inherent-mod rules)
	If Not IsInscribable($item) Then Return IsOSAutoKeepWeapon($item)
	; Throwing items without good damage/energy/armor
	If Not IsMaxStatsForReq($item) Then Return False
	; Inscribable are kept only if : 1) rare skin and q9 2) low Req of a good type
	If IsLowReqMaxDamage($item) And $lowReqValuableWeaponTypesMap[DllStructGetData($item, 'type')] <> Null Then Return True
	If GetItemReq($item) == 9 And $MAP_RARE_WEAPONS[$itemID] <> Null Then Return True
	Return False
EndFunc


;~ v27: the only old-school weapons kept automatically (no tick needed), AMG's rules (t35u-t39u):
;~  a) requirement 9 and an INHERENT Energy +5 (Py4GW EnergyPlusUpgrade = inherent 'I have the power', martial weapons:
;~     OS axes, bows, daggers, hammers, swords) - an Insightful staff head (+5 energy prefix, salvageable) does not count;
;~  b) wand (main hand) or focus (off hand), requirement 9 or 10, halving BOTH casting time and skill recharge, each either 20% of the
;~     item's requirement attribute or an inherent 10% of all spells (HasCasterHalvesPair): 20/20 (e.g. Domination Magic 9,
;~     HCT Domination 20%, HSR Domination 20%), 10/10, 20% HCT + 10% HSR, 10% HCT + 20% HSR. Staves never (t39u: one-handed only).
;~     Swift / of Quickening / of Swiftness / inscriptions (salvageable 10% sources) do not count.
Func IsOSAutoKeepWeapon($item)
	Local $hex = ModStructToHex(GetModStruct($item))
	If $hex == '' Then Return False
	Local $attribute = -1
	Local $requirement = GetModStructRequirement($hex, $attribute)
	If $requirement == 9 And HasInherentEnergyPlusFive($hex) Then Return True
	; HCT/HSR pairs: one-handed casters only - wand (main hand) and focus (off hand), requirement 9 or 10; never staves (t39u)
	Switch DllStructGetData($item, 'type')
		Case $ID_TYPE_WAND, $ID_TYPE_OFFHAND
			If $requirement <> 9 And $requirement <> 10 Then Return False
		Case Else
			Return False
	EndSwitch
	Return HasCasterHalvesPair($hex, $attribute)
EndFunc


;~ Return true if basic material should be sold to the material merchant
Func DefaultShouldSellBasicMaterial($item)
	If Not IsBasicMaterial($item) Then Return False
	Local $storeReason = ''
	If IsProtectedByStoreItems($item, $inventory_management_cache, $storeReason) Then Return False
	Local $materialID = DllStructGetData($item, 'ModelID')
	Local $materialName = $BASIC_MATERIAL_NAMES_FROM_IDS[$materialID]
	Return $inventory_management_cache['Sell items.Basic Materials.' & $materialName]
EndFunc


;~ Return true if rare material should be sold to the rare material merchant
Func DefaultShouldSellRareMaterial($item)
	If Not IsRareMaterial($item) Then Return False
	Local $storeReason = ''
	If IsProtectedByStoreItems($item, $inventory_management_cache, $storeReason) Then Return False
	Local $materialID = DllStructGetData($item, 'ModelID')
	Local $materialName = $RARE_MATERIAL_NAMES_FROM_IDS[$materialID]
	Return $inventory_management_cache['Sell items.Rare Materials.' & $materialName]
EndFunc


;~ Return true if a weapon should be picked up
Func CheckPickupWeapon($weaponItem)
	Local $weaponRarity = GetRarity($weaponItem)
	If $weaponRarity == $RARITY_RED Then Return True
	If $weaponRarity == $RARITY_GRAY Then Return False
	If $weaponRarity <> $RARITY_WHITE And IsLowReqMaxDamage($weaponItem) Then Return True
	Local $itemID = DllStructGetData($weaponItem, 'ModelID')
	If $weaponRarity <> $RARITY_WHITE And $RARE_WEAPONS_TO_PICK[$itemID] <> Null And IsMaxStatsForReq($weaponItem) Then Return True

	Local $weaponRarityName = $RARITY_NAMES_FROM_IDS[$weaponRarity]
	Local $weaponType = DllStructGetData($weaponItem, 'Type')
	Local $weaponTypeName = $WEAPON_NAMES_FROM_TYPES[$weaponType]
	Local $weaponReq = GetItemReq($weaponItem)
	Return $inventory_management_cache['Pick up items.Weapons and offhands.' & $weaponRarityName & '.' & $weaponTypeName & '.Req ' & $weaponReq]
EndFunc


Func CheckSalvageWeapon($weaponItem)
	Local $weaponRarity = GetRarity($weaponItem)
	If $weaponRarity == $RARITY_GREEN Or $weaponRarity == $RARITY_GRAY Or $weaponRarity == $RARITY_RED Then Return False
	Local $weaponRarityName = $RARITY_NAMES_FROM_IDS[$weaponRarity]
	Local $weaponType = DllStructGetData($weaponItem, 'Type')
	Local $weaponTypeName = $WEAPON_NAMES_FROM_TYPES[$weaponType]
	Local $weaponReq = GetItemReq($weaponItem)
	Return $inventory_management_cache['Salvage items.Weapons and offhands.' & $weaponRarityName & '.' & $weaponTypeName & '.Req ' & $weaponReq]
EndFunc


Func CheckSellWeapon($weaponItem)
	Local $weaponRarity = GetRarity($weaponItem)
	If $weaponRarity == $RARITY_GREEN Or $weaponRarity == $RARITY_GRAY Or $weaponRarity == $RARITY_RED Then Return False
	Local $weaponRarityName = $RARITY_NAMES_FROM_IDS[$weaponRarity]
	Local $weaponType = DllStructGetData($weaponItem, 'Type')
	Local $weaponTypeName = $WEAPON_NAMES_FROM_TYPES[$weaponType]
	Local $weaponReq = GetItemReq($weaponItem)
	Return $inventory_management_cache['Sell items.Weapons and offhands.' & $weaponRarityName & '.' & $weaponTypeName & '.Req ' & $weaponReq]
EndFunc


Func CheckStoreWeapon($weaponItem)
	Local $storeWeaponKey = GetStoreWeaponKey($weaponItem)
	Return $storeWeaponKey <> '' And $inventory_management_cache[$storeWeaponKey] == True
EndFunc


;~ v8: Store tree key for a weapon: 'Store items.Weapons and offhands.<Rarity>.<Weapon type>.Req <req>' ('' for gray/red, never stored)
Func GetStoreWeaponKey($weaponItem)
	Local $weaponRarity = GetRarity($weaponItem)
	If $weaponRarity == $RARITY_GRAY Or $weaponRarity == $RARITY_RED Then Return ''
	Local $weaponRarityName = $RARITY_NAMES_FROM_IDS[$weaponRarity]
	Local $weaponType = DllStructGetData($weaponItem, 'Type')
	Local $weaponTypeName = $WEAPON_NAMES_FROM_TYPES[$weaponType]
	Local $weaponReq = GetItemReq($weaponItem)
	Return 'Store items.Weapons and offhands.' & $weaponRarityName & '.' & $weaponTypeName & '.Req ' & $weaponReq
EndFunc


;~ v19: True for a loose Rune of Major Vigor (an upgrade item, e.g. one extracted from armor): it carries the Major Vigor effect
;~ dword C202E927 (dword-aligned). Minor (C202E827) and Superior (C202EA27) Vigor do not match. The model ID (5550) is shared with
;~ other purple runes (Recovery, Restoration, Clarity, Purity), so it is not used.
;~ v24: a loose upgrade component in the bags - rune, insignia, weapon mod (hilt, haft, pommel, string...) or inscription:
;~ item type 8 (GWCA ItemType::Rune_Mod, Py4GW ItemType.Rune_Mod). Nothing is ever sold or salvaged as this type.
Func IsLooseUpgradeComponent($item)
	Return DllStructGetData($item, 'type') == $ID_TYPE_UPGRADE
EndFunc


Func IsLooseMajorVigorRune($item)
	If DllStructGetData($item, 'type') <> $ID_TYPE_UPGRADE Then Return False
	Return HasUpgradeStructInModStruct(GetModStructHex($item), $STRUCT_ALL_RUNES_MAJOR_VIGOR)
EndFunc


#Region Store protection (v8) - any item matching a checked 'Store items' entry is exempt from ALL salvaging
;~ True if the Store items rules (same predicate as the Store feature) protect the item. $reason = matching Store rule.
Func IsProtectedByStoreItems($item, ByRef $storeCache, ByRef $reason)
	$reason = ''
	If $storeCache['Store items.Unidentified gold items'] == True And IsUnidentifiedGoldItem($item) Then
		$reason = 'Store items.Unidentified gold items'
		Return True
	EndIf
	If Not ShouldStoreItemWithCache($item, $storeCache) Then Return False
	If IsWeapon($item) Then
		$reason = GetStoreWeaponKey($item)
	ElseIf IsArmorSalvageItem($item) Then
		$reason = 'Store items.Armor salvageables.' & $RARITY_NAMES_FROM_IDS[GetRarity($item)]
	ElseIf IsLooseUpgradeComponent($item) Then
		$reason = $STORE_COMPONENTS_ROOT & '.' & FindStoreComponentMatch($item, $storeCache)
	Else
		$reason = 'Store items rule for model ' & DllStructGetData($item, 'ModelID')
	EndIf
	Return True
EndFunc


;~ Store ticks to protect with: the applied/loaded configuration (what the Store feature uses), overlaid with the LIVE
;~ Inventory tab ticks when the GUI exists (so a tick not yet applied still protects). Derived '@store.*' flags recomputed
;~ exactly like BuildInventoryDerivedFlags.
Func BuildStoreProtectionCache(ByRef $source)
	; v38.2: reuse the snapshot until InvalidateExtractLeavesCache (Load / Apply / tick / Start)
	If $store_protection_cache_valid Then
		$source = $store_protection_cache_source
		Return $store_protection_cache
	EndIf
	Local $cache[]
	For $key In MapKeys($inventory_management_cache)
		If $key == 'Store items' Or StringLeft($key, 12) == 'Store items.' Then $cache[$key] = $inventory_management_cache[$key]
	Next
	$source = 'the loaded loot configuration'
	If $gui_treeview_lootoptions Then
		Local $states[]
		IterateOverTreeView($states, $gui_treeview_lootoptions, Null, '', AddLeafStateToMap)
		For $key In MapKeys($states)
			If $key == 'Store items' Or StringLeft($key, 12) == 'Store items.' Then $cache[$key] = $states[$key]
		Next
		$source = 'the Inventory tab (live)'
	EndIf
	Local $storeSomething = False, $storeSomeWeapons = False
	Local $weaponsPrefix = 'Store items.Weapons and offhands'
	For $key In MapKeys($cache)
		If Not $cache[$key] Then ContinueLoop
		$storeSomething = True
		If $key == $weaponsPrefix Or StringLeft($key, StringLen($weaponsPrefix) + 1) == $weaponsPrefix & '.' Then $storeSomeWeapons = True
	Next
	$cache['@store.something'] = $storeSomething
	$cache['@store.nothing'] = Not $storeSomething
	$cache['@store.weapons.something'] = $storeSomeWeapons
	$cache['@store.weapons.nothing'] = Not $storeSomeWeapons
	; v25: the checked component definitions are resolved lazily (GetStoreComponentDefinitions) from these ticks
	$cache['@store.components.something'] = IsAnyStoreComponentChecked($cache)
	$store_protection_cache = $cache
	$store_protection_cache_source = $source
	$store_protection_cache_valid = True
	$store_protection_cache_rebuilds += 1
	Return $cache
EndFunc
#EndRegion Store protection


#Region Store components (v25) - Store items > Components > Mods / Inscriptions / Insignias / Runes
;~ The leaves mirror 'Extract upgrades only' (perfect-only + the Major Vigor exception), regrouped:
;~   Store items.Components.Mods.<Weapon>.<Prefix - X|Suffix - Y>.<name>  <->  Mods.<Weapon>.<Prefix - X|Suffix - Y>.<name>
;~   Store items.Components.Inscriptions.<group>.<name>                    <->  Inscriptions.<group>.<name>
;~   Store items.Components.Insignias.<All|Profession>.<name>              <->  Armor upgrades.<All|Profession>.Insignias.<name>
;~   Store items.Components.Runes.<All|Profession>.<name>                  <->  Armor upgrades.<All|Profession>.Runes.<name>
;~ (right-hand side = path relative to the Keep/Extract roots, resolved by ResolveUpgradeLeafDefinition)
;~ ($STORE_COMPONENTS_ROOT / $STORE_COMPONENT_GROUPS are declared at the top of this file)


;~ 'Runes.All.Superior Vigor' -> 'Armor upgrades.All.Runes.Superior Vigor'; Mods/Inscriptions unchanged; '' if not a component leaf path
Func StoreComponentToUpgradePath($relativePath)
	Local $parts = StringSplit($relativePath, '.')
	If $parts[0] < 2 Then Return ''
	Switch $parts[1]
		Case 'Mods', 'Inscriptions'
			Return $relativePath
		Case 'Insignias', 'Runes'
			If $parts[0] <> 3 Then Return ''
			Return 'Armor upgrades.' & $parts[2] & '.' & $parts[1] & '.' & $parts[3]
	EndSwitch
	Return ''
EndFunc


;~ Inverse of StoreComponentToUpgradePath: Keep/Extract relative path -> path relative to Store items.Components ('' if none)
Func UpgradePathToStoreComponent($relativePath)
	Local $parts = StringSplit($relativePath, '.')
	If $parts[0] < 2 Then Return ''
	Switch $parts[1]
		Case 'Mods', 'Inscriptions'
			Return $relativePath
		Case 'Armor upgrades'
			If $parts[0] <> 4 Then Return ''
			If $parts[3] <> 'Insignias' And $parts[3] <> 'Runes' Then Return ''
			Return $parts[3] & '.' & $parts[2] & '.' & $parts[4]
	EndSwitch
	Return ''
EndFunc


;~ True if any leaf under Store items.Components is ticked in $cache
Func IsAnyStoreComponentChecked(ByRef $cache)
	Local $prefix = $STORE_COMPONENTS_ROOT & '.'
	Local $prefixLength = StringLen($prefix)
	For $key In MapKeys($cache)
		If StringLeft($key, $prefixLength) <> $prefix Then ContinueLoop
		If $cache[$key] == True Then Return True
	Next
	Return False
EndFunc


;~ Definitions (ResolveUpgradeLeafDefinition maps + 'storePath') of the ticked Store items.Components leaves, resolved once per
;~ cache and memoised in it under '@store.components.definitions' (BuildInventoryDerivedFlags drops the memo on every apply/load).
;~ Group nodes (Components, Mods, Mods.Axe...) are skipped: a key is a group when another key continues it with '.'.
;~ A ticked leaf that does not resolve is logged and ignored.
Func GetStoreComponentDefinitions(ByRef $cache)
	If MapExists($cache, '@store.components.definitions') Then Return $cache['@store.components.definitions']
	Local $prefix = $STORE_COMPONENTS_ROOT & '.'
	Local $prefixLength = StringLen($prefix)
	Local $groups[]
	Local $keys = MapKeys($cache)
	For $key In $keys
		If StringLeft($key, $prefixLength) <> $prefix Then ContinueLoop
		Local $lastDot = StringInStr($key, '.', 0, -1)
		If $lastDot > 0 Then $groups[StringLeft($key, $lastDot - 1)] = True
	Next
	Local $definitions[UBound($keys) + 1]
	Local $count = 0
	For $key In $keys
		If StringLeft($key, $prefixLength) <> $prefix Then ContinueLoop
		If $cache[$key] <> True Then ContinueLoop
		If MapExists($groups, $key) Then ContinueLoop
		Local $relativePath = StringTrimLeft($key, $prefixLength)
		Local $upgradePath = StoreComponentToUpgradePath($relativePath)
		; same perfect-only rule (max roll / Superior rune, Major Vigor exception) as Extract upgrades only
		If $upgradePath == '' Or Not IsPerfectUpgradeOption($upgradePath) Then
			Warn('[Store] Ignored component option "' & $key & '" (not a perfect upgrade option)')
			ContinueLoop
		EndIf
		Local $definition = ResolveUpgradeLeafDefinition($upgradePath)
		If Not IsMap($definition) Then
			Warn('[Store] Ignored component option "' & $key & '" (no upgrade definition)')
			ContinueLoop
		EndIf
		$definition['storePath'] = $relativePath
		$definitions[$count] = $definition
		$count += 1
	Next
	ReDim $definitions[$count]
	$cache['@store.components.definitions'] = $definitions
	Return $definitions
EndFunc


;~ Path (relative to Store items.Components) of the first ticked component this LOOSE upgrade item is, or ''.
Func FindStoreComponentMatch($item, ByRef $cache)
	If Not IsLooseUpgradeComponent($item) Then Return ''
	If MapExists($cache, '@store.components.something') And $cache['@store.components.something'] <> True Then Return ''
	Local $definitions = GetStoreComponentDefinitions($cache)
	If UBound($definitions) == 0 Then Return ''
	Local $hex = GetModStructHex($item)
	If $hex == '' Then Return ''
	For $definition In $definitions
		If LooseComponentMatchesDefinition($definition, $hex) Then Return $definition['storePath']
	Next
	Return ''
EndFunc


;~ True if the modstruct of a LOOSE upgrade item (type 8) is the upgrade of $definition.
;~ A loose component carries the same upgrade group as the upgrade applied to an item (Py4GW ItemModifierParser parses both the
;~ same way): [0x25B8 TargetItemType][0x2408 Upgrade id][tooltip 0x2530 rune/insignia | 0x2530 weapon mod | 0x2532 inscription]
;~ [effect dwords]. Verified on the v19 loose rune dumps (Minor/Major/Superior Vigor).
;~  - runes/insignias: the definition struct is the identity dword (same test as on armor, IsLooseMajorVigorRune)
;~  - weapon mods: the effect must be in a group headed by a prefix/suffix upgrade id of the checked kind (FindUpgradeGroupForStruct),
;~    with the max-roll requirements, AND the mod must be for the checked weapon: the weapon of the upgrade id (Py4GW table, e.g.
;~    0x0139 Silencing_Daggers), or the TargetItemType dword when the id is not in the table
;~  - inscriptions: same group test with the inscription marker and kind (inscriptions are not weapon-specific)
Func LooseComponentMatchesDefinition($definition, $hex)
	If $definition['armor'] Then Return HasUpgradeStructInModStruct($hex, $definition['struct'])
	Local $marker = ($definition['kind'] == 'inscription') ? $STRUCT_INSCRIPTION : $STRUCT_WEAPON_UPGRADE
	Local $upgradeId = FindUpgradeGroupForStruct($hex, $definition['struct'], $marker, $definition['kind'], $definition['requirements'])
	If $upgradeId < 0 Then Return False
	If $definition['kind'] == 'inscription' Then Return True
	Local $weaponType = GetLooseComponentWeaponType($hex, $upgradeId)
	; unknown weapon: not stored (a mod for another weapon must not pass for the ticked one)
	If $weaponType == -1 Then Return False
	For $type In $definition['types']
		If $type == $weaponType Then Return True
	Next
	Return False
EndFunc


;~ Weapon item type a loose weapon mod is for: from its upgrade id (Py4GW item type names) or else from its TargetItemType dword
;~ (identifier 0x25B8, arg1 = item type - Py4GW TargetItemTypeProperty(item_type=ItemType(arg1))). -1 if unknown.
Func GetLooseComponentWeaponType($hex, $upgradeId)
	Local $info = ($upgradeId > 0) ? GetWeaponUpgradeInfoFromId($upgradeId) : ''
	If $info <> '' Then
		Local $parts = StringSplit($info, '|')
		Switch $parts[3]
			Case 'Daggers'
				Return $ID_TYPE_DAGGER
			Case 'Offhand'
				Return $ID_TYPE_OFFHAND
			Case 'Any'
			Case Else
				Local $type = GetWeaponTypeFromName($parts[3])
				If $type <> -1 Then Return $type
		EndSwitch
	EndIf
	For $i = 1 To StringLen($hex) - 7 Step 8
		If GetModStructDwordIdentifier($hex, $i) == '25B8' Then Return GetModStructDwordArgByte($hex, $i, 1)
	Next
	Return -1
EndFunc


;~ v25 step 4c of InventoryManagementBeforeRun: store every loose component ticked under Store items > Components, right after
;~ the extraction (4b) and before material salvage / selling. Xunlai full: one warning, the rest stays in the bags, the pass goes on
;~ (loose components are never sold or salvaged: DefaultShouldSellItem / DefaultShouldSalvageItem). Returns the number stored.
Func StoreSelectedComponentsBeforeSelling($tradeTown = $ID_EYE_OF_THE_NORTH)
	Local $toStore = 0
	Local $item
	For $bagIndex = 1 To $bags_count
		Local $bag = GetBag($bagIndex)
		Local $bagItems = GetBagItemsOf($bagIndex, $bag)
		For $i = 1 To UBound($bagItems)
			$item = $bagItems[$i - 1]
			If DllStructGetData($item, 'ID') == 0 Then ContinueLoop
			If FindStoreComponentMatch($item, $inventory_management_cache) <> '' Then $toStore += 1
		Next
	Next
	If $toStore == 0 Then
		Debug('[Store] No loose component ticked under Store items > Components in the bags')
		Return 0
	EndIf
	If GetMapType() <> $ID_OUTPOST Then TravelToOutpost($tradeTown, $district_name)
	Info('[Store] Storing ' & $toStore & ' component(s) ticked under Store items > Components (before salvaging/selling)')
	Local $stored = 0
	For $bagIndex = 1 To $bags_count
		Local $bag = GetBag($bagIndex)
		For $i = 1 To DllStructGetData($bag, 'slots')
			$item = GetItemBySlot($bagIndex, $i)
			If DllStructGetData($item, 'ID') == 0 Then ContinueLoop
			Local $match = FindStoreComponentMatch($item, $inventory_management_cache)
			If $match == '' Then ContinueLoop
			If Not StoreItemInXunlaiStorage($item) Then
				Warn('[Store] Xunlai storage is full - ' & ($toStore - $stored) & ' component(s) stay in your bags (never sold or salvaged); continuing')
				Return $stored
			EndIf
			Debug('[Store] Stored ' & $match)
			$stored += 1
			RandomSleep(50)
		Next
	Next
	Info('[Store] Stored ' & $stored & ' component(s)')
	Return $stored
EndFunc


;~ v25 load-time migration of a parsed loot configuration (JSON maps), so ANY config - shipped, saved or exported by an older
;~ version - shows Store items > Components:
;~  - every Extract upgrades only leaf (v29: Keep components removed) gets its Store items.Components leaf, added
;~    unticked when missing (existing ticks kept)
;~  - v24 'Store items.Mods' (one flag) = True ticks every component leaf; the key is removed
;~  - v19 'Store items.Runes.Major Vigor' moves to Store items.Components.Runes.All.Major Vigor; the old key is removed
;~  - Components becomes the first child of Store items (other entries keep their order)

;~ v35: rename the Inventory extract branch. Old loot files keep their ticks.
Func MigrateExtractTreeRoot($jsonLootOptions)
	If Not IsMap($jsonLootOptions) Then Return $jsonLootOptions
	If MapExists($jsonLootOptions, $EXTRACT_TREE_ROOT_LEGACY) Then
		If Not MapExists($jsonLootOptions, $EXTRACT_TREE_ROOT) Then
			$jsonLootOptions[$EXTRACT_TREE_ROOT] = $jsonLootOptions[$EXTRACT_TREE_ROOT_LEGACY]
		EndIf
		MapRemove($jsonLootOptions, $EXTRACT_TREE_ROOT_LEGACY)
	EndIf
	Return $jsonLootOptions
EndFunc

;~ v36: canonical Inventory rune leaves (Minor/Major/Superior and the single-tier All runes), in the
;~ pre-v12 tree order. Used to add missing leaves (unticked) so older loot files show them without
;~ changing any existing tick.
Func RuneLeavesForProfession($profession)
	Switch $profession
		Case 'All'
			Local $leaves[] = ['Minor Vigor', 'Vitae', 'Attunement', 'Major Vigor', 'Recovery', 'Restoration', 'Clarity', 'Purity', 'Superior Vigor']
			Return $leaves
		Case 'Assassin'
			Local $leaves[] = ['Minor Critical Strikes', 'Minor Dagger Mastery', 'Minor Deadly Arts', 'Minor Shadow Arts', 'Major Critical Strikes', 'Major Dagger Mastery', 'Major Deadly Arts', 'Major Shadow Arts', 'Superior Critical Strikes', 'Superior Dagger Mastery', 'Superior Deadly Arts', 'Superior Shadow Arts']
			Return $leaves
		Case 'Dervish'
			Local $leaves[] = ['Minor Earth Prayers', 'Minor Mysticism', 'Minor Scythe Mastery', 'Minor Wind Prayers', 'Major Earth Prayers', 'Major Mysticism', 'Major Scythe Mastery', 'Major Wind Prayers', 'Superior Earth Prayers', 'Superior Mysticism', 'Superior Scythe Mastery', 'Superior Wind Prayers']
			Return $leaves
		Case 'Elementalist'
			Local $leaves[] = ['Minor Air Magic', 'Minor Earth Magic', 'Minor Energy Storage', 'Minor Water Magic', 'Minor Fire Magic', 'Major Air Magic', 'Major Earth Magic', 'Major Energy Storage', 'Major Fire Magic', 'Major Water Magic', 'Superior Air Magic', 'Superior Earth Magic', 'Superior Energy Storage', 'Superior Fire Magic', 'Superior Water Magic']
			Return $leaves
		Case 'Mesmer'
			Local $leaves[] = ['Minor Domination Magic', 'Minor Fast Casting', 'Minor Illusion Magic', 'Minor Inspiration Magic', 'Major Domination Magic', 'Major Fast Casting', 'Major Illusion Magic', 'Major Inspiration Magic', 'Superior Domination Magic', 'Superior Fast Casting', 'Superior Illusion Magic', 'Superior Inspiration Magic']
			Return $leaves
		Case 'Monk'
			Local $leaves[] = ['Minor Divine Favor', 'Minor Healing Prayers', 'Minor Protection Prayers', 'Minor Smiting Prayers', 'Major Healing Prayers', 'Major Protection Prayers', 'Major Smiting Prayers', 'Major Divine Favor', 'Superior Divine Favor', 'Superior Healing Prayers', 'Superior Protection Prayers', 'Superior Smiting Prayers']
			Return $leaves
		Case 'Necromancer'
			Local $leaves[] = ['Minor Blood Magic', 'Minor Curses', 'Minor Death Magic', 'Minor Soul Reaping', 'Major Blood Magic', 'Major Curses', 'Major Death Magic', 'Major Soul Reaping', 'Superior Blood Magic', 'Superior Curses', 'Superior Death Magic', 'Superior Soul Reaping']
			Return $leaves
		Case 'Paragon'
			Local $leaves[] = ['Minor Command', 'Minor Leadership', 'Minor Motivation', 'Minor Spear Mastery', 'Major Command', 'Major Leadership', 'Major Motivation', 'Major Spear Mastery', 'Superior Command', 'Superior Leadership', 'Superior Motivation', 'Superior Spear Mastery']
			Return $leaves
		Case 'Ranger'
			Local $leaves[] = ['Minor Beast Mastery', 'Minor Expertise', 'Minor Marksmanship', 'Minor Wilderness Survival', 'Major Beast Mastery', 'Major Expertise', 'Major Marksmanship', 'Major Wilderness Survival', 'Superior Beast Mastery', 'Superior Expertise', 'Superior Marksmanship', 'Superior Wilderness Survival']
			Return $leaves
		Case 'Ritualist'
			Local $leaves[] = ['Minor Channeling Magic', 'Minor Communing', 'Minor Restoration Magic', 'Minor Spawning Power', 'Major Channeling Magic', 'Major Communing', 'Major Restoration Magic', 'Major Spawning Power', 'Superior Channeling Magic', 'Superior Communing', 'Superior Restoration Magic', 'Superior Spawning Power']
			Return $leaves
		Case 'Warrior'
			Local $leaves[] = ['Minor Absorption', 'Minor Axe Mastery', 'Minor Hammer Mastery', 'Minor Strength', 'Minor Swordsmanship', 'Minor Tactics', 'Major Absorption', 'Major Axe Mastery', 'Major Hammer Mastery', 'Major Strength', 'Major Swordsmanship', 'Major Tactics', 'Superior Axe Mastery', 'Superior Hammer Mastery', 'Superior Strength', 'Superior Swordsmanship', 'Superior Tactics', 'Superior Absorption']
			Return $leaves
	EndSwitch
	Local $none[0]
	Return $none
EndFunc


Func EnsureRuneLeaves($jsonLootOptions)
	If Not IsMap($jsonLootOptions) Then Return $jsonLootOptions
	If MapExists($jsonLootOptions, $EXTRACT_TREE_ROOT) And IsMap($jsonLootOptions[$EXTRACT_TREE_ROOT]) Then
		$jsonLootOptions[$EXTRACT_TREE_ROOT] = EnsureRuneLeavesOnExtractRoot($jsonLootOptions[$EXTRACT_TREE_ROOT])
	EndIf
	If MapExists($jsonLootOptions, $EXTRACT_TREE_ROOT_LEGACY) And IsMap($jsonLootOptions[$EXTRACT_TREE_ROOT_LEGACY]) Then
		$jsonLootOptions[$EXTRACT_TREE_ROOT_LEGACY] = EnsureRuneLeavesOnExtractRoot($jsonLootOptions[$EXTRACT_TREE_ROOT_LEGACY])
	EndIf
	Return $jsonLootOptions
EndFunc


Func EnsureRuneLeavesOnExtractRoot($root)
	If Not IsMap($root) Then Return $root
	If Not MapExists($root, 'Armor upgrades') Or Not IsMap($root['Armor upgrades']) Then Return $root
	Local $armor = $root['Armor upgrades']
	Local $professions[] = ['All', 'Assassin', 'Dervish', 'Elementalist', 'Mesmer', 'Monk', 'Necromancer', 'Paragon', 'Ranger', 'Ritualist', 'Warrior']
	For $profession In $professions
		If Not MapExists($armor, $profession) Or Not IsMap($armor[$profession]) Then ContinueLoop
		Local $group = $armor[$profession]
		If Not MapExists($group, 'Runes') Or Not IsMap($group['Runes']) Then ContinueLoop
		$group['Runes'] = MergeRuneLeaves($group['Runes'], RuneLeavesForProfession($profession))
		$armor[$profession] = $group
	Next
	$root['Armor upgrades'] = $armor
	Return $root
EndFunc


Func MergeRuneLeaves($existing, $desired)
	Local $out[]
	For $name In $desired
		If MapExists($existing, $name) Then
			$out[$name] = $existing[$name]
		Else
			$out[$name] = False
		EndIf
	Next
	For $name In MapKeys($existing)
		If Not MapExists($out, $name) Then $out[$name] = $existing[$name]
	Next
	Return $out
EndFunc

Func MigrateStoreComponentOptions($jsonLootOptions)
	If Not IsMap($jsonLootOptions) Then Return $jsonLootOptions
	If Not MapExists($jsonLootOptions, 'Store items') Or Not IsMap($jsonLootOptions['Store items']) Then Return $jsonLootOptions
	Local $store = $jsonLootOptions['Store items']
	Local $mods24 = Null, $majorVigor19 = Null
	If MapExists($store, 'Mods') And Not IsMap($store['Mods']) Then
		$mods24 = ($store['Mods'] == True)
		MapRemove($store, 'Mods')
	EndIf
	If MapExists($store, 'Runes') And IsMap($store['Runes']) Then
		Local $runes = $store['Runes']
		If MapExists($runes, 'Major Vigor') Then
			$majorVigor19 = ($runes['Major Vigor'] == True)
			MapRemove($runes, 'Major Vigor')
		EndIf
		If UBound(MapKeys($runes)) == 0 Then
			MapRemove($store, 'Runes')
		Else
			$store['Runes'] = $runes
		EndIf
	EndIf
	Local $components[]
	If MapExists($store, 'Components') And IsMap($store['Components']) Then $components = $store['Components']
	Local $source = Null
	If MapExists($jsonLootOptions, $EXTRACT_TREE_ROOT) And IsMap($jsonLootOptions[$EXTRACT_TREE_ROOT]) Then
		$source = $jsonLootOptions[$EXTRACT_TREE_ROOT]
	ElseIf MapExists($jsonLootOptions, $EXTRACT_TREE_ROOT_LEGACY) And IsMap($jsonLootOptions[$EXTRACT_TREE_ROOT_LEGACY]) Then
		$source = $jsonLootOptions[$EXTRACT_TREE_ROOT_LEGACY]
	EndIf
	; group order Mods, Inscriptions, Insignias, Runes for groups created here
	For $group In $STORE_COMPONENT_GROUPS
		If Not MapExists($components, $group) Then
			Local $emptyGroup[]
			$components[$group] = $emptyGroup
		EndIf
	Next
	Local $added = 0
	If IsMap($source) Then $components = AddStoreComponentLeaves($components, $source, '', $added)
	If $mods24 == True Then $components = SetAllJsonLeaves($components, True)
	If $majorVigor19 == True And MapExists($components, 'Runes') And MapExists($components['Runes'], 'All') _
		And MapExists($components['Runes']['All'], 'Major Vigor') Then
		Local $runesGroup = $components['Runes']
		Local $allRunes = $runesGroup['All']
		$allRunes['Major Vigor'] = True
		$runesGroup['All'] = $allRunes
		$components['Runes'] = $runesGroup
	EndIf
	; drop groups left empty (no Extract upgrades only at all)
	For $group In $STORE_COMPONENT_GROUPS
		If IsMap($components[$group]) And UBound(MapKeys($components[$group])) == 0 Then MapRemove($components, $group)
	Next
	Local $newStore[]
	If UBound(MapKeys($components)) > 0 Then $newStore['Components'] = $components
	For $key In MapKeys($store)
		If $key == 'Components' Then ContinueLoop
		$newStore[$key] = $store[$key]
	Next
	$jsonLootOptions['Store items'] = $newStore
	If $added > 0 Then Info('[Loot] Added Store items > Components (' & $added & ' option(s), unticked) - save the loot configuration to keep them')
	If $mods24 <> Null Then Info('[Loot] Migrated v24 "Store items.Mods" (' & ($mods24 ? 'ticked: every component ticked' : 'unticked') & ') to Store items > Components')
	If $majorVigor19 <> Null Then Info('[Loot] Moved "Store items.Runes.Major Vigor" (' & ($majorVigor19 ? 'ticked' : 'unticked') & ') to Store items > Components > Runes > All')
	Return $jsonLootOptions
EndFunc


;~ Walk an Extract upgrades only (sub)tree and add the matching Store items.Components leaves that are missing (unticked)
Func AddStoreComponentLeaves($components, $node, $relativePath, ByRef $added)
	For $key In MapKeys($node)
		Local $childPath = ($relativePath == '') ? $key : ($relativePath & '.' & $key)
		If IsMap($node[$key]) Then
			$components = AddStoreComponentLeaves($components, $node[$key], $childPath, $added)
		Else
			Local $storePath = UpgradePathToStoreComponent($childPath)
			If $storePath == '' Then ContinueLoop
			Local $parts = StringSplit($storePath, '.', $STR_NOCOUNT)
			If Not JsonLeafExists($components, $parts, 0) Then
				$components = SetJsonLeaf($components, $parts, 0, False)
				$added += 1
			EndIf
		EndIf
	Next
	Return $components
EndFunc


Func JsonLeafExists($node, ByRef $parts, $index)
	If Not IsMap($node) Or Not MapExists($node, $parts[$index]) Then Return False
	If $index == UBound($parts) - 1 Then Return Not IsMap($node[$parts[$index]])
	Return JsonLeafExists($node[$parts[$index]], $parts, $index + 1)
EndFunc


Func SetJsonLeaf($node, ByRef $parts, $index, $value)
	If $index == UBound($parts) - 1 Then
		$node[$parts[$index]] = $value
		Return $node
	EndIf
	Local $child[]
	If MapExists($node, $parts[$index]) And IsMap($node[$parts[$index]]) Then $child = $node[$parts[$index]]
	$node[$parts[$index]] = SetJsonLeaf($child, $parts, $index + 1, $value)
	Return $node
EndFunc


Func SetAllJsonLeaves($node, $value)
	For $key In MapKeys($node)
		If IsMap($node[$key]) Then
			$node[$key] = SetAllJsonLeaves($node[$key], $value)
		Else
			$node[$key] = $value
		EndIf
	Next
	Return $node
EndFunc
#EndRegion Store components
#EndRegion Inventory Management


#Region Empty storage tab (v24 Tools tab)
;~ Xunlai storage tabs as the game numbers them, and their bag indexes (GWCA Constants.h enum Bag: 6 Material_Storage,
;~ 7 Unclaimed_Items, 8-21 Storage_1..Storage_14; GWToolbox docs: "The anniversary storage pane (Storage 14)").
Global Const $STORAGE_TAB_NAMES[] = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII', 'XIII', 'Anniversary']
Global Const $STORAGE_TAB_FIRST_BAG = 8
; random pause between two moves (ms) - human-like pace, also gives the server time to answer
Global Const $EMPTY_TAB_MOVE_PAUSE_MS = 600
Global Const $EMPTY_TAB_MOVE_TIMEOUT_MS = 3000


;~ Bag index of a storage tab name ('I'..'XIII' -> 8..20, 'Anniversary' -> 21), 0 if unknown
Func StorageTabBagIndex($tabName)
	For $i = 0 To UBound($STORAGE_TAB_NAMES) - 1
		If $STORAGE_TAB_NAMES[$i] == $tabName Then Return $STORAGE_TAB_FIRST_BAG + $i
	Next
	Return 0
EndFunc


;~ Combo box list ('I|II|...|Anniversary')
Func StorageTabComboList()
	Local $list = ''
	For $name In $STORAGE_TAB_NAMES
		$list &= ($list == '' ? '' : '|') & $name
	Next
	Return $list
EndFunc


;~ Moves every item of the storage bag into the inventory (bags 1-4), one by one from slot 1. Stackable items first top up
;~ partial stacks of the same item in the inventory, then go to the first empty slot. Stops when the inventory is full,
;~ when a move is not confirmed by the game, or when the character leaves the outpost. Returns the number of slots emptied.
Func EmptyStorageBag($bagIndex, $tabLabel)
	Local $bag = GetBag($bagIndex)
	Local $slots = ($bag == Null) ? 0 : DllStructGetData($bag, 'slots')
	If $slots <= 0 Then
		Warn('[Empty Tab] Storage tab ' & $tabLabel & ' is not available (pane not unlocked, or storage not loaded) - nothing moved')
		Return 0
	EndIf
	Local $lastInventoryBag = _Min($bags_count, 4)
	Info('[Empty Tab] Emptying storage tab ' & $tabLabel & ' (bag ' & $bagIndex & ', ' & $slots & ' slots) into bags 1-' & $lastInventoryBag)
	Local $emptied = 0, $items = 0
	For $slot = 1 To $slots
		Local $item = GetItemBySlot($bagIndex, $slot)
		If DllStructGetData($item, 'ID') == 0 Then ContinueLoop
		$items += 1
		If GetMapType() <> $ID_OUTPOST Or GetMyID() == 0 Then
			Warn('[Empty Tab] Left the outpost or disconnected - stopped at tab ' & $tabLabel & ' slot ' & $slot & '. Emptied ' & $emptied & ' slot(s).')
			Return $emptied
		EndIf
		Local $result = MoveStorageItemToInventory($item, $bagIndex, $slot, $lastInventoryBag)
		Switch $result
			Case 'full'
				Warn('[Empty Tab] Inventory full - stopped at tab ' & $tabLabel & ' slot ' & $slot & '. Emptied ' & $emptied & ' slot(s); the rest stays in storage.')
				Return $emptied
			Case 'failed'
				Warn('[Empty Tab] The game did not confirm moving the item in tab ' & $tabLabel & ' slot ' & $slot & ' (lag?) - stopped. Emptied ' & $emptied & ' slot(s).')
				Return $emptied
		EndSwitch
		$emptied += 1
		RandomSleep($EMPTY_TAB_MOVE_PAUSE_MS)
	Next
	If $items == 0 Then
		Info('[Empty Tab] Storage tab ' & $tabLabel & ' is already empty')
	Else
		Info('[Empty Tab] Done: storage tab ' & $tabLabel & ' emptied (' & $emptied & ' slot(s) moved to the inventory)')
	EndIf
	Return $emptied
EndFunc


;~ Moves one storage item into bags 1..$lastInventoryBag. Returns 'moved', 'full' (no room) or 'failed' (not confirmed).
;~ A stack that only partly fits on existing stacks keeps its remainder in storage only if no empty slot is left ('full').
Func MoveStorageItemToInventory($item, $bagIndex, $slot, $lastInventoryBag)
	Local $itemID = DllStructGetData($item, 'ID')
	Local $modelID = DllStructGetData($item, 'ModelID')
	If IsStackable($item) Then
		For $invBag = 1 To $lastInventoryBag
			Local $invSlots = DllStructGetData(GetBag($invBag), 'slots')
			For $invSlot = 1 To $invSlots
				Local $stack = GetItemBySlot($invBag, $invSlot)
				If DllStructGetData($stack, 'ID') == 0 Or DllStructGetData($stack, 'ModelID') <> $modelID Then ContinueLoop
				If DllStructGetData($stack, 'DyeColor') <> DllStructGetData($item, 'DyeColor') Then ContinueLoop
				If DllStructGetData($stack, 'Quantity') >= 250 Then ContinueLoop
				If Not StorageMoveConfirmed($item, $bagIndex, $slot, $invBag, $invSlot) Then Return 'failed'
				$item = GetItemBySlot($bagIndex, $slot)
				If DllStructGetData($item, 'ID') <> $itemID Then Return 'moved'
				RandomSleep($EMPTY_TAB_MOVE_PAUSE_MS / 2)
			Next
		Next
	EndIf
	Local $emptySlot = FindFirstEmptySlot(1, $lastInventoryBag)
	If $emptySlot[0] == 0 Then Return 'full'
	If Not StorageMoveConfirmed($item, $bagIndex, $slot, $emptySlot[0], $emptySlot[1]) Then Return 'failed'
	Return 'moved'
EndFunc


;~ True once the storage slot no longer holds $itemID with $quantity (moved away or merged), False after the timeout
Func WaitStorageSlotChanged($bagIndex, $slot, $itemID, $quantity)
	Local $timer = TimerInit()
	While TimerDiff($timer) < $EMPTY_TAB_MOVE_TIMEOUT_MS
		Sleep(100)
		Local $now = GetItemBySlot($bagIndex, $slot)
		If DllStructGetData($now, 'ID') <> $itemID Then Return True
		If DllStructGetData($now, 'Quantity') <> $quantity Then Return True
	WEnd
	Return False
EndFunc
#EndRegion Empty storage tab


#Region Buying/selling items from/to merchant
;~ Buys an identification kit.
Func BuyIdentificationKit($amount = 1)
	BuyItem(5, $amount, 100)
EndFunc


;~ Buys a superior identification kit.
Func BuySuperiorIdentificationKit($amount = 1)
	BuyItem(6, $amount, 500)
	RandomSleep(1000)
EndFunc


;~ Buys a basic salvage kit.
Func BuySalvageKit($amount = 1)
	BuyItem(2, $amount, 100)
	RandomSleep(1000)
EndFunc


;~ Buys an expert salvage kit.
Func BuyExpertSalvageKit($amount = 1)
	BuyItem(3, $amount, 400)
	RandomSleep(1000)
EndFunc


;~ Buys an expert salvage kit.
Func BuySuperiorSalvageKit($amount = 1)
	BuyItem(4, $amount, 2000)
	RandomSleep(1000)
EndFunc


;~ Buy salvage kits in town
Func BuySalvageKitInTown($amount = 1)
	While $amount > 10
		BuyInTown($ID_SALVAGE_KIT, 2, 100, 10, False)
		$amount -= 10
	WEnd
	If $amount > 0 Then BuyInTown($ID_SALVAGE_KIT, 2, 100, $amount, False)
EndFunc


;~ Buy expert salvage kits in town
Func BuyExpertSalvageKitInTown($amount = 1)
	While $amount > 10
		BuyInTown($ID_EXPERT_SALVAGE_KIT, 3, 400, 10, False)
		$amount -= 10
	WEnd
	If $amount > 0 Then BuyInTown($ID_EXPERT_SALVAGE_KIT, 3, 400, $amount, False)
EndFunc


;~ Buy superior salvage kits in town
Func BuySuperiorSalvageKitInTown($amount = 1)
	While $amount > 10
		BuyInTown($ID_SUPERIOR_SALVAGE_KIT, 4, 2000, 10, False)
		$amount -= 10
	WEnd
	If $amount > 0 Then BuyInTown($ID_SUPERIOR_SALVAGE_KIT, 4, 2000, $amount, False)
EndFunc


;~ Buy superior identification kits in town
Func BuySuperiorIdentificationKitInTown($amount = 1)
	While $amount > 10
		BuyInTown($ID_SUPERIOR_IDENTIFICATION_KIT, 6, 500, 10, False)
		$amount -= 10
	WEnd
	If $amount > 0 Then BuyInTown($ID_SUPERIOR_IDENTIFICATION_KIT, 6, 500, $amount, False)
EndFunc


;~ Buy lockpicks in town
Func BuyLockpicksInTown($amount = 1)
	If $amount > 0 Then BuyInTown($ID_LOCKPICK, 11, 1500, $amount, True)
EndFunc


;~ Sell general items to trader
Func SellItemsToMerchant($shouldSellItem = DefaultShouldSellItem, $dryRun = False, $tradeTown = $ID_EYE_OF_THE_NORTH)
	Info('Selling items')
	TravelToOutpost($tradeTown, $district_name)
	Debug('Moving to merchant to sell items')
	UseCitySpeedBoost()
	; in Embark Beach, move to spot to avoid getting stuck on obstacles
	If $tradeTown == $ID_EMBARK_BEACH Then MoveTo(1950, 0)
	Local $npcCoordinates = NPCCoordinatesInTown($tradeTown, 'Merchant')
	MoveTo($npcCoordinates[0], $npcCoordinates[1])
	Local $merchant = GetNearestNPCToCoords($npcCoordinates[0], $npcCoordinates[1])
	GoToNPC($merchant)
	RandomSleep(250)

	Local $item, $itemID
	For $bagIndex = 1 To $bags_count
		Local $bag = GetBag($bagIndex)
		For $i = 1 To DllStructGetData($bag, 'slots')
			$item = GetItemBySlot($bagIndex, $i)
			$itemID = DllStructGetData($item, 'ModelID')
			If $itemID <> 0 Then
				If $shouldSellItem($item) Then
					If Not $dryRun Then
						SellItem($item, DllStructGetData($item, 'Quantity'))
						RandomSleep(250)
					EndIf
				Else
					If $dryRun Then Info('Will not sell item at ' & $bagIndex & ':' & $i)
				EndIf
			EndIf
		Next
	Next
EndFunc


;~ Sell basic materials to materials merchant in town
Func SellBasicMaterialsToMerchant($shouldSellMaterial = DefaultShouldSellBasicMaterial, $tradeTown = $ID_EYE_OF_THE_NORTH)
	Info('Selling basic materials')
	TravelToOutpost($tradeTown, $district_name)
	Debug('Moving to materials merchant')
	UseCitySpeedBoost()
	; in Embark Beach, move to spot to avoid getting stuck on obstacles
	If $tradeTown == $ID_EMBARK_BEACH Then MoveTo(1950, 0)
	Local $npcCoordinates = NPCCoordinatesInTown($tradeTown, 'Basic material trader')
	MoveTo($npcCoordinates[0], $npcCoordinates[1])
	Local $materialTrader = GetNearestNPCToCoords($npcCoordinates[0], $npcCoordinates[1])
	GoToNPC($materialTrader)
	RandomSleep(250)

	Local $item
	For $bagIndex = 1 To _Min(4, $bags_count)
		Local $bag = GetBag($bagIndex)
		For $i = 1 To DllStructGetData($bag, 'slots')
			$item = GetItemBySlot($bagIndex, $i)
			If $shouldSellMaterial($item) Then
				SellItemToTrader($item)
			EndIf
		Next
	Next
EndFunc


;~ Sell rare materials to rare materials merchant in town
Func SellRareMaterialsToMerchant($shouldSellMaterial = DefaultShouldSellRareMaterial, $tradeTown = $ID_EYE_OF_THE_NORTH)
	Info('Selling rare materials')
	TravelToOutpost($tradeTown, $district_name)
	Debug('Moving to rare materials merchant')
	UseCitySpeedBoost()
	; in Embark Beach, move to spot to avoid getting stuck on obstacles
	If $tradeTown == $ID_EMBARK_BEACH Then MoveTo(1950, 0)
	Local $npcCoordinates = NPCCoordinatesInTown($tradeTown, 'Rare material trader')
	MoveTo($npcCoordinates[0], $npcCoordinates[1])
	Local $materialTrader = GetNearestNPCToCoords($npcCoordinates[0], $npcCoordinates[1])
	GoToNPC($materialTrader)
	RandomSleep(250)

	Local $item
	For $bagIndex = 1 To _Min(4, $bags_count)
		Local $bag = GetBag($bagIndex)
		For $i = 1 To DllStructGetData($bag, 'slots')
			$item = GetItemBySlot($bagIndex, $i)
			If $shouldSellMaterial($item) Then
				SellItemToTrader($item)
			EndIf
		Next
	Next
EndFunc


;~ Buy rare material from rare materials merchant in town
Func BuyRareMaterialFromMerchant($materialModelID, $amount, $tradeTown = $ID_EYE_OF_THE_NORTH)
	TravelToOutpost($tradeTown, $district_name)
	Debug('Moving to rare materials merchant')
	UseCitySpeedBoost()
	; in Embark Beach, move to spot to avoid getting stuck on obstacles
	If $tradeTown == $ID_EMBARK_BEACH Then MoveTo(1950, 0)
	Local $npcCoordinates = NPCCoordinatesInTown($tradeTown, 'Rare material trader')
	MoveTo($npcCoordinates[0], $npcCoordinates[1])
	Local $materialTrader = GetNearestNPCToCoords($npcCoordinates[0], $npcCoordinates[1])
	GoToNPC($materialTrader)
	RandomSleep(250)

	For $i = 1 To $amount
		TraderRequest($materialModelID)
		RandomSleep(250)
		Local $traderPrice = GetTraderCostValue()
		Debug('Buying for ' & $traderPrice)
		TraderBuy()
		RandomSleep(250)
	Next
	; TODO: add safety net to check amount of items bought and buy some more if needed
EndFunc


;~ Buy rare material from rare materials merchant in town until you have little or no money left
;~ Possible issue if you provide a very low poorThreshold and the price of an item hike up enough to reduce your money to less than 0
;~ So please only use with $poorThreshold > 5k
Func BuyRareMaterialFromMerchantUntilPoor($materialModelID, $poorThreshold = 20000, $backupMaterialModelID = Null, $tradeTown = $ID_EYE_OF_THE_NORTH)
	Info('Buying rare materials')
	RobustTravelToOutpost($tradeTown, $district_name)
	If CountSlots(1, 4) == 0 Then
		Warn('No room in inventory to buy rare materials, tick some checkboxes to clear inventory')
		Return
	EndIf
	Debug('Moving to rare materials merchant')
	UseCitySpeedBoost()
	; in Embark Beach, move to spot to avoid getting stuck on obstacles
	If $tradeTown == $ID_EMBARK_BEACH Then MoveTo(1950, 0)
	Local $npcCoordinates = NPCCoordinatesInTown($tradeTown, 'Rare material trader')
	MoveTo($npcCoordinates[0], $npcCoordinates[1])
	Local $materialTrader = GetNearestNPCToCoords($npcCoordinates[0], $npcCoordinates[1])
	GoToNPC($materialTrader)
	RandomSleep(250)

	Local $IDMaterialToBuy = $materialModelID
	TraderRequest($IDMaterialToBuy)
	RandomSleep(250)
	Local $traderPrice = GetTraderCostValue()
	If $traderPrice <= 0 Then
		Error('Could not get trader price for the original material')
		If ($backupMaterialModelID <> Null) Then
			TraderRequest($backupMaterialModelID)
			RandomSleep(250)
			Local $traderPrice = GetTraderCostValue()
			If $traderPrice <= 0 Then Return
			$IDMaterialToBuy = $backupMaterialModelID
			Notice('Falling back to backup material')
		Else
			Return
		EndIf
	EndIf
	Local $amount = Floor((GetGoldCharacter() - $poorThreshold) / $traderPrice)
	Info('Buying ' & $amount & ' items for ' & $traderPrice)
	; Rare material prices go up after every purchase: re-check the quote and the gold left before each buy,
	; otherwise the initial estimate could spend well below the 'poor' threshold
	Local $bought = 0
	While $amount > 0
		If $traderPrice <= 0 Then ExitLoop
		If GetGoldCharacter() - $traderPrice < $poorThreshold Then ExitLoop
		TraderBuy()
		RandomSleep(250)
		$bought += 1
		TraderRequest($IDMaterialToBuy)
		RandomSleep(250)
		$traderPrice = GetTraderCostValue()
		$amount -= 1
	WEnd
	Info('Bought ' & $bought & ' rare materials')
EndFunc


;~ Buy merchant items in town
;~ FIXME: error if total price is superior to 100k, add a loop for that
;~ FIXME: error if amount is superior to 250, add another loop for that
Func BuyInTown($itemID, $itemPosition, $itemPrice, $amount = 1, $stackable = False, $tradeTown = $ID_EYE_OF_THE_NORTH)
	TravelToOutpost($tradeTown, $district_name)
	If GetGoldCharacter() < $amount * $itemPrice And GetGoldStorage() > $amount * $itemPrice - 1 Then
		WithdrawGold($amount * $itemPrice)
		RandomSleep(500)
	EndIf

	Debug('Moving to merchant to buy items')
	UseCitySpeedBoost()
	; in Embark Beach, move to spot to avoid getting stuck on obstacles
	If $tradeTown == $ID_EMBARK_BEACH Then MoveTo(1950, 0)
	Local $npcCoordinates = NPCCoordinatesInTown($tradeTown, 'Merchant')
	MoveTo($npcCoordinates[0], $npcCoordinates[1])
	Local $merchant = GetNearestNPCToCoords($npcCoordinates[0], $npcCoordinates[1])
	GoToNPC($merchant)
	RandomSleep(500)

	Local $xunlaiTemporarySlot = Null
	Local $spaceNeeded = $stackable ? 1 : $amount
	; There is no space in inventory, we need to store things in Xunlai to buy items
	If (CountSlots(1, 4) < $spaceNeeded) Then
		$xunlaiTemporarySlot = FindChestEmptySlots()
		If UBound($xunlaiTemporarySlot) < $spaceNeeded Then
			Error('Not enough space in inventory and storage to buy anything')
			Return False
		EndIf

		For $i = 0 To $spaceNeeded - 1
			MoveItem(GetItemBySlot(1, $i + 1), $xunlaiTemporarySlot[2 * $i], $xunlaiTemporarySlot[2 * $i + 1])
		Next
	EndIf

	Local $itemCount = GetInventoryItemCount($itemID)
	Local $targetItemCount = $itemCount + $amount
	Local $tryCount = 0
	While $itemCount < $targetItemCount
		If $tryCount == 10 Then Return False
		BuyItem($itemPosition, $amount, $itemPrice)
		RandomSleep(1000)
		$tryCount += 1
		$itemCount = GetInventoryItemCount($itemID)
	WEnd

	RandomSleep(500)
	If $xunlaiTemporarySlot <> Null Then
		Local $freeSpace = $stackable ? 1 : $amount
		For $i = 0 To $freeSpace - 1
			MoveItem(GetItemByModelID($itemID), $xunlaiTemporarySlot[2 * $i], $xunlaiTemporarySlot[2 * $i + 1])
		Next
	EndIf
EndFunc


;~ Buy kits for mid run salvage to preserve inventory space during run
Func BuyKitsForMidRun()
	; constants to determine how many kits should be in player's inventory
	Local Static $requiredSalvageKitUses = 300				; = 12 salvage kits with 25 uses,
	Local Static $requiredIdentificationKitUses = 400		; = 4 superior identification kits with 100 uses

	Local $salvageUses = CountRemainingKitUses($ID_SALVAGE_KIT)
	Local $salvageKitsRequired = KitsRequired($requiredSalvageKitUses - $salvageUses, $ID_SALVAGE_KIT)
	Local $identificationUses = CountRemainingKitUses($ID_SUPERIOR_IDENTIFICATION_KIT)
	Local $identificationKitsRequired = KitsRequired($requiredIdentificationKitUses - $identificationUses, $ID_SUPERIOR_IDENTIFICATION_KIT)

	If $salvageKitsRequired > 0 Then BuySalvageKitInTown($salvageKitsRequired)
	If $identificationKitsRequired > 0 Then BuySuperiorIdentificationKitInTown($identificationKitsRequired)
EndFunc
#EndRegion Buying/selling items from/to merchant


#Region Identification and salvage
;~ Get the number of uses of a kit
Func GetKitUsesLeft($kitID)
	Local $kitStruct = GetModStruct($kitID)
	Return Int('0x' & StringMid($kitStruct, 11, 2))
EndFunc


;~ Returns item ID of basic salvage kit in inventory.
Func FindBasicSalvageKit()
	Local $kits = [$ID_SALVAGE_KIT, $ID_SALVAGE_KIT_2]
	Return FindKit($kits)
EndFunc


;~ Returns item ID of salvage kit in inventory (except basic)
Func FindSalvageKit()
	Local $kits = [$ID_EXPERT_SALVAGE_KIT, $ID_SUPERIOR_SALVAGE_KIT]
	Return FindKit($kits)
EndFunc


;~ Returns item ID of identification kit in inventory.
Func FindIdentificationKit()
	Local $kits = [$ID_IDENTIFICATION_KIT, $ID_SUPERIOR_IDENTIFICATION_KIT]
	Return FindKit($kits)
EndFunc


;~ Returns kits
Func GetInventoryKitCount($enabledModelIDs)
	Local $kitCount = 0
	Local $item, $modelID

	For $i = 1 To 4
		Local $bagItems = GetBagItems($i)
		For $j = 1 To UBound($bagItems)
			$item = $bagItems[$j - 1]
			$modelID = DllStructGetData($item, 'ModelID')

			; Skip this item if model is not in our list
			If Not FindKitArrayContainsHelper($enabledModelIDs, $modelID) Then ContinueLoop
			$kitCount += 1
		Next
	Next
	Return $kitCount
EndFunc


;~ Returns kit
Func FindKit($enabledModelIDs)
	Local $kit = Null
	Local $uses = 101
	Local $item, $modelID, $kitUses

	; v4: only inventory bags (1-4) and equipment pack (5). Bags 6+ are material storage / Xunlai chest:
	; a kit found there cannot be used and starting a salvage/identify with it sends invalid IDs to the client.
	For $i = 1 To _Min(5, $bags_count)
		Local $bagItems = GetBagItems($i)
		For $j = 1 To UBound($bagItems)
			$item = $bagItems[$j - 1]
			$modelID = DllStructGetData($item, 'ModelID')

			; Skip this item if model is not in our list
			If Not FindKitArrayContainsHelper($enabledModelIDs, $modelID) Then ContinueLoop
			; v38.9: uses-per-model rule moved to KitUsesForFindKit (shared with the tracked extraction pass), unchanged
			$kitUses = KitUsesForFindKit($modelID, DllStructGetData($item, 'Value'))
			If $kitUses < $uses Then
				$uses = $kitUses
				$kit = $item
			EndIf
		Next
	Next
	Return $kit
EndFunc


;~ v38.9: FindKit's uses left for a kit model and merchant value (unknown models are never picked, as before)
Func KitUsesForFindKit($modelID, $value)
	Switch $modelID
		Case $ID_SALVAGE_KIT, $ID_SALVAGE_KIT_2
			Return $value / 2
		Case $ID_EXPERT_SALVAGE_KIT
			Return $value / 8
		Case $ID_SUPERIOR_SALVAGE_KIT
			Return $value / 10
		Case $ID_IDENTIFICATION_KIT
			Return $value / 2
		Case $ID_SUPERIOR_IDENTIFICATION_KIT
			Return $value / 2.5
	EndSwitch
	Return 1e9
EndFunc


;~ Return True if item is present in array of items, else False - duplicate in Utils
Func FindKitArrayContainsHelper($itemsArray, $itemModelID)
	For $itemArrayModelID In $itemsArray
		If $itemArrayModelID == $itemModelID Then Return True
	Next
	Return False
EndFunc


;~ Function to calculate remaining count of uses of kits present in inventory, of modelID provided as parameter
Func CountRemainingKitUses($kitModelID)
	Local $allKitUses = 0
	Local $item, $itemModelID, $kitUses

	For $i = 1 To 4
		Local $bagItems = GetBagItems($i)
		For $j = 1 To UBound($bagItems)
			$item = $bagItems[$j - 1]
			$itemModelID = DllStructGetData($item, 'ModelID')
			If $itemModelID <> $kitModelID Then ContinueLoop
			; v11: same value-per-use divisors as FindKit (was / 2 for every kit: superior ID kit uses were over-counted by 25%)
			$kitUses = DllStructGetData($item, 'Value') / KitValuePerUse($kitModelID)
			$allKitUses = $allKitUses + $kitUses
		Next
	Next
	Return $allKitUses
EndFunc


;~ v11: merchant value of ONE kit use, by kit model (GWA2/BotsHub FindKit divisors): basic salvage 2, expert salvage 8,
;~ superior salvage 10, identification 2, superior identification 2.5 (2 for unknown models, the previous behaviour)
Func KitValuePerUse($kitModelID)
	Switch $kitModelID
		Case $ID_EXPERT_SALVAGE_KIT
			Return 8
		Case $ID_SUPERIOR_SALVAGE_KIT
			Return 10
		Case $ID_SUPERIOR_IDENTIFICATION_KIT
			Return 2.5
	EndSwitch
	Return 2
EndFunc


;~ Function to calculate required number of kits to perform required number of kit actions
Func KitsRequired($requiredkitUses, $kitModelID)
	Local $usesPerKit
	Switch $kitModelID
		Case $ID_PERFECT_SALVAGE_KIT, $ID_CHARR_SALVAGE_KIT
			$usesPerKit = 5
		Case $ID_SALVAGE_KIT_2
			$usesPerKit = 10
		Case $ID_IDENTIFICATION_KIT, $ID_SALVAGE_KIT, $ID_EXPERT_SALVAGE_KIT
			$usesPerKit = 25
		Case $ID_SUPERIOR_IDENTIFICATION_KIT, $ID_SUPERIOR_SALVAGE_KIT
			$usesPerKit = 100
	EndSwitch
	Return Ceiling($requiredkitUses / $usesPerKit)
EndFunc


#Region Identification
;~ Identify items from inventory
Func IdentifyItems($buyKit = True)
	Info('Identifying items')
	For $bagIndex = 1 To $bags_count
		Local $bag = GetBag($bagIndex)
		Local $item
		For $i = 1 To DllStructGetData($bag, 'slots')
			$item = GetItemBySlot($bagIndex, $i)
			If DllStructGetData($item, 'ID') == 0 Then ContinueLoop
			If Not IsIdentified($item) Then
				Local $rarity = GetRarity($item)
				Local $rarityName = $RARITY_NAMES_FROM_IDS[$rarity]
				If Not $inventory_management_cache['Identify items.' & $rarityName] Then ContinueLoop

				Local $identificationKit = FindIdentificationKit()
				If $identificationKit == Null Then
					If $buyKit Then
						BuySuperiorIdentificationKitInTown()
					Else
						Return False
					EndIf
				EndIf
				IdentifyItem($item)
				RandomSleep(100)
			EndIf
		Next
	Next
	Return True
EndFunc


;~ Identifies all items in a bag.
Func IdentifyBag($bag, $identifyWhiteItems = False, $identifyGoldItems = True)
	Local $item
	For $i = 1 To DllStructGetData($bag, 'Slots')
		$item = GetItemBySlot(DllStructGetData($bag, 'index'), $i)
		If DllStructGetData($item, 'ID') == 0 Then ContinueLoop
		If GetRarity($item) == $RARITY_WHITE And Not $identifyWhiteItems Then ContinueLoop
		If GetRarity($item) == $RARITY_GOLD And Not $identifyGoldItems Then ContinueLoop
		IdentifyItem($item)
	Next
EndFunc
#Region Identification


#Region Salvage
;~ Salvage items from inventory, only items specified by configuration in GUI interface
Func SalvageItems($buyKit = True)
	Info('Salvaging items')
	Local $kit = GetSalvageKit($buyKit)
	If $kit == 0 Then Return False
	Local $uses = DllStructGetData($kit, 'Value') / 2

	Local $movedItem = Null
	If (CountSlots(1, 4) < 1) Then
		; There is no space in inventory, we need to store something in Xunlai chest to start the salvage
		Local $xunlaiTemporarySlot = FindChestFirstEmptySlot()
		$movedItem = GetItemBySlot(_Min(4, $bags_count), 1)
		MoveItem($movedItem, $xunlaiTemporarySlot[0], $xunlaiTemporarySlot[1])
	EndIf

	Local $trophiesAndMaterialItems[60]
	Local $trophyAndMaterialIndex = 0
	For $bagIndex = 1 To _Min(4, $bags_count)
		Local $bagSize = DllStructGetData(GetBag($bagIndex), 'slots')
		For $slot = 1 To $bagSize
			Local $item = GetItemBySlot($bagIndex, $slot)
			If DllStructGetData($item, 'ID') = 0 Then ContinueLoop

			Local $itemID = DllStructGetData($item, 'ModelID')
			If IsTrophy($itemID) Then
				If $inventory_management_cache['@salvage.trophies.nothing'] Then ContinueLoop
				; Trophies should be salvaged at the end, because they create a lot of materials
				$trophiesAndMaterialItems[$trophyAndMaterialIndex] = $item
				$trophyAndMaterialIndex += 1
			ElseIf IsRareMaterial($item) Then
				If $inventory_management_cache['@salvage.materials.nothing'] Then ContinueLoop
				; Rare materials should be salvaged at the end, because they create a lot of materials
				$trophiesAndMaterialItems[$trophyAndMaterialIndex] = $item
				$trophyAndMaterialIndex += 1
			Else
				If DefaultShouldSalvageItem($item) Then
					SalvageItem($item, $kit)
					$uses -= 1
					If $uses < 1 Then
						$kit = GetSalvageKit($buyKit)
						If $kit == Null Then Return False
						$uses = DllStructGetData($kit, 'Value') / 2
					EndIf
				EndIf
			EndIf
		Next
	Next

	; Moving removed item back from Xunlai chest to empty slot in inventory to check it to salvage it too
	If $movedItem <> Null Then
		Local $bagEmptySlot = FindFirstEmptySlot(1, _Min(4, $bags_count))
		MoveItem($movedItem, $bagEmptySlot[0], $bagEmptySlot[1])
		If DefaultShouldSalvageItem($movedItem) Then
			SalvageItem($movedItem, $kit)
			$uses -= 1
			If $uses < 1 Then
				$kit = GetSalvageKit($buyKit)
				If $kit == Null Then Return False
				$uses = DllStructGetData($kit, 'Value') / 2
			EndIf
		EndIf
	EndIf

	For $i = 0 To $trophyAndMaterialIndex - 1
		If DefaultShouldSalvageItem($trophiesAndMaterialItems[$i]) Then
			For $k = 0 To DllStructGetData($trophiesAndMaterialItems[$i], 'Quantity') - 1
				SalvageItem($trophiesAndMaterialItems[$i], $kit)
				$uses -= 1
				If $uses < 1 Then
					$kit = GetSalvageKit($buyKit)
					If $kit == Null Then Return False
					$uses = DllStructGetData($kit, 'Value') / 2
				EndIf
			Next
		EndIf
	Next
EndFunc


;~ Get a salvage kit from inventory, or buy one if not present
;~ Returns the kit or 0 if it was not found and not bought
Func GetSalvageKit($buyKit = True)
	Local $kit = FindBasicSalvageKit()
	If $kit == Null And $buyKit Then
		BuySalvageKitInTown()
		$kit = FindBasicSalvageKit()
	EndIf
	Return $kit
EndFunc


;~ Salvage an item based on its position in the inventory
Func SalvageItemAt($bagIndex, $slot)
	Local $item = GetItemBySlot($bagIndex, $slot)
	If DllStructGetData($item, 'ID') = 0 Then Return
	If DefaultShouldSalvageItem($item) Then
		Local $salvageKit = GetSalvageKit(False)
		If $salvageKit == 0 Or $salvageKit == Null Then Return
		SalvageItem($item, $salvageKit)
	EndIf
EndFunc


;~ Salvage the given item - FIXME: fails for weapons/armorsalvageable when using expert kits and better because they open a window
Func SalvageItem($item, $salvageKit, $salvageType = 'Materials')
	Local $rarity = GetRarity($item)
	; v4: bounded (was an infinite loop when the salvage session pointer could not be read)
	Local $startTries = 0
	While Not StartSalvageWithKit($item, $salvageKit)
		$startTries += 1
		If $startTries >= 20 Then
			Warn('Could not start salvage session for item ' & DllStructGetData($item, 'ID'))
			Return False
		EndIf
		PingSleep(50)
	WEnd
	PingSleep(600)
	If $rarity == $RARITY_gold Or $rarity == $RARITY_purple Then
		ValidateSalvage()
		PingSleep(600)
	EndIf
	Switch $salvageType
		Case 'Materials'
			SendPacket(0x4, $HEADER_SALVAGE_MATERIALS)
		Case 'Prefix'
			SendPacket(0x8, $HEADER_SALVAGE_UPGRADE, 0)
		Case 'Suffix'
			SendPacket(0x8, $HEADER_SALVAGE_UPGRADE, 1)
		Case 'Inscription'
			SendPacket(0x8, $HEADER_SALVAGE_UPGRADE, 2)
		Case Else
			Return False
	EndSwitch
	PingSleep(50)
	Return True
EndFunc
#EndRegion Salvage
#EndRegion Identification and salvage


#Region Inventory and Chest Storage
;~ Move items to the equipment bag
Func MoveItemsToEquipmentBag()
	If $bags_count < 5 Then Return
	Local $equipmentBagEmptySlots = FindEmptySlots(5)
	Local $countEmptySlots = UBound($equipmentBagEmptySlots) / 2
	If $countEmptySlots < 1 Then
		Debug('No space in equipment bag to move the items to')
		Return
	EndIf

	Local $cursor = 1
	For $bagIndex = 4 To 1 Step -1
		For $slot = 1 To DllStructGetData(GetBag($bagIndex), 'slots')
			Local $item = GetItemBySlot($bagIndex, $slot)
			If DllStructGetData($item, 'ID') <> 0 And (isArmor($item) Or IsWeapon($item)) Then
				If $countEmptySlots < 1 Then
					Debug('No space in equipment bag to move the items to')
					Return
				EndIf
				MoveItem($item, 5, $equipmentBagEmptySlots[$cursor])
				$cursor += 2
				$countEmptySlots -= 1
				RandomSleep(50)
			EndIf
		Next
	Next
EndFunc


;~ Move all items out of the equipment bag so they can be salvaged
Func MoveItemsOutOfEquipmentBag()
	Local $equipmentBag = GetBag(5)
	Local $inventoryEmptySlots = FindAllEmptySlots(1, 4)
	Local $countEmptySlots = UBound($inventoryEmptySlots) / 2
	Local $cursor = 0
	If $countEmptySlots <= $cursor Then
		Warn('No space in inventory to move the items out of the equipment bag')
		Return 0
	EndIf

	For $slot = 1 To DllStructGetData($equipmentBag, 'slots')
		If $countEmptySlots <= $cursor Then
			Warn('No space in inventory to move the items out of the equipment bag')
			Return 0
		EndIf
		Local $item = GetItemBySlot(5, $slot)
		If DllStructGetData($item, 'ModelID') <> 0 Then
			If IsArmor($item) Then ContinueLoop
			If Not DefaultShouldSalvageItem($item) Then ContinueLoop
			MoveItem($item, $inventoryEmptySlots[2 * $cursor], $inventoryEmptySlots[2 * $cursor + 1])
			$cursor += 1
			RandomSleep(50)
		EndIf
	Next
	Return $cursor
EndFunc


;~ helper function for StoreEverythingInXunlaiStorage function
Func StoreAllItems($item = Null)
	Return True
EndFunc


;~ Store all items in the Xunlai Storage
Func StoreEverythingInXunlaiStorage()
	StoreItemsInXunlaiStorage(StoreAllItems)
EndFunc


;~ Store selected items in the Xunlai Storage
Func StoreItemsInXunlaiStorage($shouldStoreItem = DefaultShouldStoreItem)
	Info('Storing items in Xunlai Storage')
	Local $item, $itemID
	For $bagIndex = 1 To $bags_count
		Local $bag = GetBag($bagIndex)
		For $i = 1 To DllStructGetData($bag, 'slots')
			$item = GetItemBySlot($bagIndex, $i)
			$itemID = DllStructGetData($item, 'ModelID')
			If $itemID <> 0 And $shouldStoreItem($item) Then
				Debug('Moving ' & $bagIndex & ':' & $i)
				If Not StoreItemInXunlaiStorage($item) Then Return False
				RandomSleep(50)
			EndIf
		Next
	Next
EndFunc


;~ Store an item in the Xunlai Storage
Func StoreItemInXunlaiStorage($item)
	Local $existingStacks
	Local $itemID, $storageSlot, $amount
	$itemID = DllStructGetData($item, 'ModelID')
	$amount = DllStructGetData($item, 'Quantity')

	If IsMaterial($item) Then
		Local $materialStorageLocation = $MAP_MATERIAL_LOCATION[$itemID]
		Local $materialInStorage = GetItemBySlot(6, $materialStorageLocation)
		Local $countMaterial = DllStructGetData($materialInStorage, 'Equipped') * 256 + DllStructGetData($materialInStorage, 'Quantity')
		MoveItem($item, 6, $materialStorageLocation)
		PingSleep(50)
		$materialInStorage = GetItemBySlot(6, $materialStorageLocation)
		Local $newCountMaterial = DllStructGetData($materialInStorage, 'Equipped') * 256 + DllStructGetData($materialInStorage, 'Quantity')
		If $newCountMaterial - $countMaterial == $amount Then Return True
		$amount = DllStructGetData($item, 'Quantity')
	EndIf
	If (IsStackable($item) Or IsMaterial($item)) And $amount < 250 Then
		$existingStacks = FindAllInXunlaiStorage($item)
		For $bagIndex = 0 To UBound($existingStacks) - 1 Step 2
			Local $existingStack = GetItemBySlot($existingStacks[$bagIndex], $existingStacks[$bagIndex + 1])
			Local $existingAmount = DllStructGetData($existingStack, 'Quantity')
			If $existingAmount < 250 Then
				Debug('To ' & $existingStacks[$bagIndex] & ':' & $existingStacks[$bagIndex + 1])
				MoveItem($item, $existingStacks[$bagIndex], $existingStacks[$bagIndex + 1])
				PingSleep(50)
				$amount = $amount + $existingAmount - 250
				If $amount <= 0 Then Return True
			EndIf
		Next
	EndIf
	$storageSlot = FindChestFirstEmptySlot()
	If $storageSlot[0] == 0 Then
		Warn('Storage is full')
		Return False
	EndIf
	Debug('To ' & $storageSlot[0] & ':' & $storageSlot[1])
	MoveItem($item, $storageSlot[0], $storageSlot[1])
	PingSleep(50)
	Return True
EndFunc


;~ Turns the bag index and the slot index into a general index
Func GetGeneralSlot($bagsSizes, $bag, $slot)
	Local $generalSlot = $slot
	For $i = 1 To $bag - 1
		$generalSlot += $bagsSizes[$i]
	Next
	Return $generalSlot
EndFunc


;~ Turns a general index into the bag index and the slot index
Func GetBagAndSlotFromGeneralSlot($bagsSizes, $generalSlot)
	Local $bagAndSlot[2]
	Local $i = 1
	For $i = 1 To 4
		If $generalSlot <= $bagsSizes[$i] Then
			$bagAndSlot[0] = $i
			$bagAndSlot[1] = $generalSlot
			Return $bagAndSlot
		Else
			$generalSlot -= $bagsSizes[$i]
		EndIf
	Next
	$bagAndSlot[0] = $i
	$bagAndSlot[1] = $generalSlot
	Return $bagAndSlot
EndFunc


;~ Helper function for sorting function - allows moving an item via a generic position instead of with both bag and position
Func GenericMoveItem($bagsSizes, $item, $genericSlot)
	Local $i = 1
	For $i = 1 To 4
		If $genericSlot <= $bagsSizes[$i] Then
			Debug('to bag ' & $i & ' position ' & $genericSlot)
			;MoveItem($item, $i, $genericSlot)
			Return
		Else
			$genericSlot -= $bagsSizes[$i]
		EndIf
	Next
	Debug('to bag ' & $i & ' position ' & $genericSlot)
	;MoveItem($item, $i, $genericSlot)
EndFunc


;~ Balance character gold to the amount given - mode 0 = full balance, mode 1 = only withdraw, mode 2 = only deposit
Func BalanceCharacterGold($goldAmount, $mode = 0)
	Info('Balancing characters gold')
	Local $goldCharacter = GetGoldCharacter()
	Local $goldStorage = GetGoldStorage()
	If $goldCharacter > $goldAmount And $mode <> 1 Then
		; We want to deposit
		Local $goldToDeposit = $goldCharacter - $goldAmount
		If $goldStorage > (1000000 - $goldToDeposit) Then
			Warn('Too much moneyz in Xunlai, you are a rich bitch.')
		Else
			DepositGold($goldToDeposit)
			Info('Deposited gold')
		EndIf
		Return True
	ElseIf $goldCharacter < $goldAmount And $mode <> 2 Then
		; We want to withdraw
		Local $goldToWithdraw = $goldAmount - $goldCharacter
		If $goldStorage < ($goldToWithdraw) Then
			Warn('Not enough moneyz in Xunlai, you poor bastard.')
		Else
			WithdrawGold($goldToWithdraw)
			Info('Withdrawn gold')
		EndIf
		Return True
	Else
		Warn('Cannot balance characters gold.')
		Return False
	EndIf
EndFunc


;~ Deposit gold into storage.
Func DepositGold($amount = 0)
	Local $storageGold = GetGoldStorage()
	Local $characterGold = GetGoldCharacter()

	If $amount > 0 And $characterGold >= $amount Then
		$amount = $amount
	Else
		$amount = $characterGold
	EndIf
	If $storageGold + $amount > 1000000 Then $amount = 1000000 - $storageGold
	ChangeGold($characterGold - $amount, $storageGold + $amount)
EndFunc


;~ Withdraw gold from storage.
Func WithdrawGold($amount = 0)
	Local $storageGold = GetGoldStorage()
	Local $characterGold = GetGoldCharacter()

	If $amount <= 0 Or $storageGold < $amount Then
		$amount = $storageGold
	EndIf

	If $characterGold + $amount > 100000 Then $amount = 100000 - $characterGold

	ChangeGold($characterGold + $amount, $storageGold - $amount)
EndFunc
#EndRegion Inventory and Chest storage


#Region Loot items
;~ Loot items around character
Func PickUpItems($survivalFunction = Null, $shouldPickItem = DefaultShouldPickItem, $range = $RANGE_COMPASS)
	If $inventory_management_cache['@pickup.nothing'] Then Return

	Local $item
	Local $agentID
	Local $deadlock
	Local $agents = GetAgentArray($ID_AGENT_TYPE_ITEM)
	Local $me = GetMyAgent()
	For $agent In $agents
		If IsPlayerDead() Then Return
		If Not GetCanPickUp($agent) Then ContinueLoop
		If GetDistance($me, $agent) > $range Then ContinueLoop

		$agentID = DllStructGetData($agent, 'ID')
		$item = GetItemByAgentID($agentID)

		If ($shouldPickItem($item)) Then
			If $survivalFunction <> Null Then $survivalFunction()
			If Not GetAgentExists($agentID) Then ContinueLoop
			PickUpItem($item)
			$deadlock = TimerInit()
			While IsPLayerAlive() And GetAgentExists($agentID) And TimerDiff($deadlock) < 10000
				PingSleep(100)
			WEnd
		EndIf
	Next

	If $bags_count == 5 And CountSlots(1, 3) == 0 Then
		MoveItemsToEquipmentBag()
	EndIf
EndFunc


;~ Tests if an item is assigned to you.
Func GetAssignedToMe($agent)
	Return DllStructGetData($agent, 'Owner') == GetMyID()
EndFunc


;~ Tests if you can pick up an item.
Func GetCanPickUp($agent)
	Return GetAssignedToMe($agent) Or DllStructGetData($agent, 'Owner') = 0
EndFunc
#EndRegion Loot items


#Region Count and find items
;~ Find all empty slots in the given bag
Func FindEmptySlots($bagIndex)
	Local $bag = GetBag($bagIndex)
	; v38.9: one bulk read of the bag; result pre-sized and trimmed once (was a ReDim per _ArrayAdd)
	Local $bagItems = GetBagItemsOf($bagIndex, $bag)
	Local $emptySlots[2 * UBound($bagItems)]
	Local $count = 0
	Local $item
	For $slot = 1 To UBound($bagItems)
		$item = $bagItems[$slot - 1]
		If DllStructGetData($item, 'ID') == 0 Then
			$emptySlots[$count] = $bagIndex
			$emptySlots[$count + 1] = $slot
			$count += 2
		EndIf
	Next
	ReDim $emptySlots[$count]
	Return $emptySlots
EndFunc


;~ Find first empty slot in chest
Func FindChestFirstEmptySlot()
	Return FindFirstEmptySlot(8, 21)
EndFunc


;~ Find first empty slot in bags from firstBag to lastBag
Func FindFirstEmptySlot($firstBag, $lastBag)
	Local $bagEmptySlot[] = [0, 0]
	For $i = $firstBag To $lastBag
		$bagEmptySlot[1] = FindEmptySlot($i)
		If $bagEmptySlot[1] <> 0 Then
			$bagEmptySlot[0] = $i
			Return $bagEmptySlot
		EndIf
	Next
	Return $bagEmptySlot
EndFunc


;~ Find the first empty slot in the given bag
Func FindEmptySlot($bagIndex)
	Local $item
	Local $bagItems = GetBagItems($bagIndex)
	For $slot = 1 To UBound($bagItems)
		$item = $bagItems[$slot - 1]
		If DllStructGetData($item, 'ID') = 0 Then Return $slot
	Next
	; slots are indexed from 1, 0 if no empty slot found
	Return 0
EndFunc


;~ Find all empty slots in inventory
Func FindInventoryEmptySlots()
	Return FindAllEmptySlots(1, $bags_count)
EndFunc


;~ Find all empty slots in chest
Func FindChestEmptySlots()
	Return FindAllEmptySlots(8, 21)
EndFunc


;~ Find all empty slots in the given bags
Func FindAllEmptySlots($firstBag, $lastBag)
	; v38.9: one ReDim per bag instead of _ArrayAdd (same content, same order)
	Local $emptySlots[0] = []
	For $i = $firstBag To $lastBag
		Local $bagEmptySlots = FindEmptySlots($i)
		Local $count = UBound($emptySlots), $added = UBound($bagEmptySlots)
		If $added == 0 Then ContinueLoop
		ReDim $emptySlots[$count + $added]
		For $k = 0 To $added - 1
			$emptySlots[$count + $k] = $bagEmptySlots[$k]
		Next
	Next
	Return $emptySlots
EndFunc


;~ Count available slots in the inventory
Func CountSlots($fromBag = 1, $toBag = $bags_count)
	Local $bag
	Local $availableSlots = 0
	; If bag is missing it just will not count (Slots = 0, ItemsCount = 0)
	For $i = $fromBag To $toBag
		$bag = GetBag($i)
		$availableSlots += DllStructGetData($bag, 'Slots') - DllStructGetData($bag, 'ItemsCount')
	Next
	Return $availableSlots
EndFunc


;~ Counts open slots in the Xunlai storage chest
Func CountSlotsChest()
	Local $chestTab
	Local $availableSlots = 0
	For $i = 8 To 21
		$chestTab = GetBag($i)
		$availableSlots += 25 - DllStructGetData($chestTab, 'ItemsCount')
	Next
	Return $availableSlots
EndFunc


;~ Returns true if there are materials in inventory
Func HasMaterials()
	Return HasInInventory(IsMaterial)
EndFunc


;~ Returns true if there are basic materials in inventory
Func HasBasicMaterials()
	Return HasInInventory(IsBasicMaterial)
EndFunc


;~ Returns true if there are rare materials in inventory
Func HasRareMaterials()
	Return HasInInventory(IsRareMaterial)
EndFunc


;~ Returns true if there are unidentified items in inventory
Func HasUnidentifiedItems()
	Return HasInInventory(IsUnidentified)
EndFunc


;~ Returns true if there are unidentified items in inventory
Func HasGoldUnidentifiedItems()
	Return HasInInventory(IsUnidentifiedGoldItem)
EndFunc


;~ Returns true if there are items in inventory that user selected to salvage in the GUI interface
Func HasItemsToSalvage($shouldSalvageItem = DefaultShouldSalvageItem)
	Return HasInInventory($shouldSalvageItem)
EndFunc


;~ Returns true if there are items in inventory that user selected to sell (merchant)
Func HasItemsToSell($shouldSellItem = DefaultShouldSellItem)
	Return HasInInventory($shouldSellItem)
EndFunc


;~ Returns true if there are basic materials in inventory that user selected to sell (trader)
Func HasBasicMaterialsToTrade($shouldSellMaterial = DefaultShouldSellBasicMaterial)
	Return HasInInventory($shouldSellMaterial)
EndFunc


;~ Returns true if there are basic materials in inventory that user selected to sell (trader)
Func HasRareMaterialsToTrade($shouldSellMaterial = DefaultShouldSellRareMaterial)
	Return HasInInventory($shouldSellMaterial)
EndFunc


;~ Returns true if there are items in inventory satisfying condition
Func HasInInventory($condition)
	Local $item, $itemID
	For $bagIndex = 1 To $bags_count
		Local $bag = GetBag($bagIndex)
		Local $bagItems = GetBagItemsOf($bagIndex, $bag)
		For $i = 1 To UBound($bagItems)
			$item = $bagItems[$i - 1]
			If $condition($item) Then Return True
		Next
	Next
	Return False
EndFunc


;~ Counts black dyes in inventory
Func GetBlackDyeCount()
	Return GetInventoryItemCount($ID_BLACK_DYE)
EndFunc


;~ Counts birthday cupcakes in inventory
Func GetBirthdayCupcakeCount()
	Return GetInventoryItemCount($ID_BIRTHDAY_CUPCAKE)
EndFunc


;~ Counts gold items in inventory
Func CountGoldItems()
	Local $goldItemsCount = 0
	Local $item
	For $bagIndex = 1 To $bags_count
		Local $bag = GetBag($bagIndex)
		Local $bagItems = GetBagItemsOf($bagIndex, $bag)
		For $i = 1 To UBound($bagItems)
			$item = $bagItems[$i - 1]
			If DllStructGetData($item, 'ID') = 0 Then ContinueLoop
			If ((IsWeapon($item) Or IsArmorSalvageItem($item)) And GetRarity($item) == $RARITY_GOLD) Then $goldItemsCount += 1
		Next
	Next
	Return $goldItemsCount
EndFunc


;~ Destroy all items that fit the provided modelIDs
Func DestroyFromInventory($mapItemIDs)
	For $bagIndex = 1 To $bags_count
		Local $bag = GetBag($bagIndex)
		Local $bagSize = DllStructGetData($bag, 'Slots')
		For $slot = 1 To $bagSize
			Local $item = GetItemBySlot($bagIndex, $slot)
			If $mapItemIDs[DllStructGetData($item, 'ModelID')] <> Null Then
				DestroyItem($item)
				RandomSleep(1000)
			EndIf
		Next
	Next
EndFunc


;~ Look for any of the given items in bags and return bag and slot of an item, [0, 0] if none are present (positions start at 1)
Func FindAnyInInventory(ByRef $itemIDs)
	Local $itemBagAndSlot[2]
	$itemBagAndSlot[0] = $itemBagAndSlot[1] = 0

	For $bagIndex = 1 To $bags_count
		Local $bag = GetBag($bagIndex)
		Local $bagSize = DllStructGetData($bag, 'Slots')
		Local $bagItems = GetBagItemsOf($bagIndex, $bag)
		For $slot = 1 To $bagSize
			Local $item = $bagItems[$slot - 1]
			For $itemID in $itemIDs
				If(DllStructGetData($item, 'ModelID') == $itemID) Then
					$itemBagAndSlot[0] = $bag
					$itemBagAndSlot[1] = $slot
				EndIf
			Next
		Next
	Next
	Return $itemBagAndSlot
EndFunc


;~ Look for an item in inventory
Func FindInInventory($itemID)
	Return FindInStorages(1, $bags_count, $itemID)
EndFunc


;~ Look for an item in xunlai storage
Func FindInXunlaiStorage($itemID)
	Return FindInStorages(8, 21, $itemID)
EndFunc


;~ Look for an item in xunlai storage
Func FindInInventoryOrXunlaiStorage($itemID)
	Local $result = FindInInventory($itemID)
	If $result[0] <> 0 Then Return $result
	Return FindInXunlaiStorage($itemID)
EndFunc


;~ Look for an item in storages from firstBag to lastBag and return bag and slot of the item, [0, 0] else (bags and slots are indexed from 1 as in GWToolbox)
Func FindInStorages($firstBag, $lastBag, $itemID)
	Local $item
	Local $itemBagAndSlot[] = [0, 0]

	For $bagIndex = $firstBag To $lastBag
		Local $bag = GetBag($bagIndex)
		Local $bagSize = DllStructGetData($bag, 'Slots')
		Local $bagItems = GetBagItemsOf($bagIndex, $bag)
		For $slot = 1 To $bagSize
			$item = $bagItems[$slot - 1]
			If(DllStructGetData($item, 'ModelID') == $itemID) Then
				$itemBagAndSlot[0] = $bagIndex
				$itemBagAndSlot[1] = $slot
			EndIf
		Next
	Next
	Return $itemBagAndSlot
EndFunc


;~ Look for an item in storages from firstBag to lastBag and return bag and slot of the item, [0, 0] else
Func FindAllInStorages($firstBag, $lastBag, $item)
	; v38.9: pre-sized result trimmed once at the end (was a ReDim per _ArrayAdd)
	Local $itemBagsAndSlots[64], $found = 0
	Local $itemID = DllStructGetData($item, 'ModelID')
	Local $dyeColor = ($itemID == $ID_DYES) ? DllStructGetData($item, 'DyeColor') : -1
	Local $storageItem

	For $bagIndex = $firstBag To $lastBag
		Local $bag = GetBag($bagIndex)
		Local $bagSize = DllStructGetData($bag, 'Slots')
		Local $bagItems = GetBagItemsOf($bagIndex, $bag)
		For $slot = 1 To $bagSize
			$storageItem = $bagItems[$slot - 1]
			If (DllStructGetData($storageItem, 'ModelID') == $itemID) And ($dyeColor == -1 Or DllStructGetData($storageItem, 'DyeColor') == $dyeColor) Then
				If $found + 2 > UBound($itemBagsAndSlots) Then ReDim $itemBagsAndSlots[2 * UBound($itemBagsAndSlots)]
				$itemBagsAndSlots[$found] = $bagIndex
				$itemBagsAndSlots[$found + 1] = $slot
				$found += 2
			EndIf
		Next
	Next
	ReDim $itemBagsAndSlots[$found]
	Return $itemBagsAndSlots
EndFunc


;~ Look for an item in inventory
Func FindAllInInventory($item)
	Return FindAllInStorages(1, $bags_count, $item)
EndFunc


;~ Look for an item in xunlai storage
Func FindAllInXunlaiStorage($item)
	Return FindAllInStorages(8, 21, $item)
EndFunc


;~ Counts anything in inventory
Func GetInventoryItemCount($itemID)
	Local $amountItem = 0
	Local $bag
	Local $item
	For $i = 1 To $bags_count
		$bag = GetBag($i)
		Local $bagSize = DllStructGetData($bag, 'Slots')
		Local $bagItems = GetBagItemsOf($i, $bag)
		For $j = 1 To $bagSize
			$item = $bagItems[$j - 1]

			If $MAP_DYES[$itemID] <> Null Then
				If (DllStructGetData($item, 'ModelID') == $ID_DYES) And (DllStructGetData($item, 'DyeColor') == $itemID) Then $amountItem += DllStructGetData($item, 'Quantity')
			Else
				If DllStructGetData($item, 'ModelID') == $itemID Then $amountItem += DllStructGetData($item, 'Quantity')
			EndIf
		Next
	Next
	Return $amountItem
EndFunc


;~ Count quantity of each item in inventory, specified in provided array of items
;~ Returns a corresponding array of counters, of the same size as provided array
Func CountTheseItems($itemArray)
	Local $arraySize = UBound($itemArray)
	Local $counts[$arraySize]
	For $bagIndex = 1 To 5
		Local $bag = GetBag($bagIndex)
		Local $slots = DllStructGetData($bag, 'Slots')
		Local $bagItems = GetBagItemsOf($bagIndex, $bag)
		For $slot = 1 To $slots
			Local $item = $bagItems[$slot - 1]
			Local $itemID = DllStructGetData($item, 'ModelID')
			For $i = 0 To $arraySize - 1
				If $itemID == $itemArray[$i] Then
					$counts[$i] += DllStructGetData($item, 'Quantity')
					ExitLoop
				EndIf
			Next
		Next
	Next
	Return $counts
EndFunc
#EndRegion Count and find items


#Region Use Items
;~ Use morale booster on team
Func UseMoraleConsumableIfNeeded($forceUse = False)
	If (Not $forceUse And Not $run_options_cache['run.consume_consumables']) Then Return $FAIL
	; Team member with malus is obtained from last member to first, to remove malus from character last
	Local $teamMemberWithMalus = GetTeamMemberWithTooMuchMalus()
	; Bounded, and waits long enough for the morale update to arrive from the server: with a 50ms wait a laggy
	; connection could see the old malus again and burn several extra boosters
	Local $boostersUsed = 0
	While $teamMemberWithMalus >= 0 And $boostersUsed < 10
		Local $usedMoraleBooster = False
		; Using solo morale booster first to keep team wide boosters for heroes
		If $teamMemberWithMalus == 0 Then $usedMoraleBooster = UseFirstAvailableConsumable($SOLO_DP_REMOVAL)
		If Not $usedMoraleBooster Then $usedMoraleBooster = UseFirstAvailableConsumable($TEAM_DP_REMOVAL)
		If Not $usedMoraleBooster Then
			Return $FAIL
		Else
			$boostersUsed += 1
			PingSleep(500)
		EndIf
		$teamMemberWithMalus = GetTeamMemberWithTooMuchMalus()
	WEnd
	Return $SUCCESS
EndFunc


;~ Use first item from given consumables list found in inventory
Func UseFirstAvailableConsumable($consumables)
	For $consumable In $consumables
		Local $slot = FindInInventory($consumable)
		If $slot[0] <> 0 Then
			UseItemBySlot($slot[0], $slot[1])
			Return True
		EndIf
	Next
	Return False
EndFunc


;~ Use Armor of Salvation, Essence of Celerity and Grail of Might
Func UseConset($forceUse = False)
	If (Not $forceUse And Not $run_options_cache['run.use_consets']) Then Return
	If GetEffectTimeRemaining(GetEffect($ID_ARMOR_OF_SALVATION_EFFECT)) <= 0 Then UseConsumable($ID_ARMOR_OF_SALVATION, True)
	If GetEffectTimeRemaining(GetEffect($ID_ESSENCE_OF_CELERITY_EFFECT)) <= 0 Then UseConsumable($ID_ESSENCE_OF_CELERITY, True)
	If GetEffectTimeRemaining(GetEffect($ID_GRAIL_OF_MIGHT_EFFECT)) <= 0 Then UseConsumable($ID_GRAIL_OF_MIGHT, True)
EndFunc


;~ Use a summoning stone
Func UseSummoningStone($forceUse = False, $preferredSummon = Null)
	If (Not $forceUse And Not $run_options_cache['run.consume_consumables']) Then Return False
	If GetEffectTimeRemaining(GetEffect($ID_SUMMONING_SICKNESS)) > 0 Then Return False
	If $preferredSummon <> Null Then
		If UseConsumable($preferredSummon) Then Return True
	EndIf

	Local $itemCounts = CountTheseItems($SUMMONING_STONES_ARRAY)
	For $i = 0 To UBound($SUMMONING_STONES_ARRAY) - 1
		; Skipping merchant
		If $SUMMONING_STONES_ARRAY[$i] == $ID_MERCHANT_SUMMON Then ContinueLoop
		If $itemCounts[$i] > 0 Then
			If UseConsumable($SUMMONING_STONES_ARRAY[$i]) == $SUCCESS Then Return True
		EndIf
	Next
	Return False
EndFunc


;~ Uses a consumable from inventory or xunlai, if present
Func UseCitySpeedBoost($forceUse = False)
	If (Not $forceUse And Not $run_options_cache['run.consume_consumables']) Then Return $FAIL
	If GetMapType() <> $ID_OUTPOST Then Return $FAIL
	If GetEffectTimeRemaining(GetEffect($ID_SUGAR_JOLT_SHORT)) > 0 Or GetEffectTimeRemaining(GetEffect($ID_SUGAR_JOLT_LONG)) > 0 Then Return $SUCCESS
	Local $consumableSlot = FindInInventoryOrXunlaiStorage($ID_SUGARY_BLUE_DRINK)
	If $consumableSlot[0] <> 0 Then
		UseItemBySlot($consumableSlot[0], $consumableSlot[1])
	Else
		$consumableSlot = FindInInventoryOrXunlaiStorage($ID_CHOCOLATE_BUNNY)
		If $consumableSlot[0] <> 0 Then UseItemBySlot($consumableSlot[0], $consumableSlot[1])
	EndIf
	Return $SUCCESS
EndFunc


;~ Uses an item from inventory or chest, if present
Func UseItemFromInventory($itemID, $forceUse = False, $checkXunlaiChest = True)
	Local $consumableItemBagAndSlot
	If $checkXunlaiChest == True And GetMapType() == $ID_OUTPOST Then
		$consumableItemBagAndSlot = FindInStorages(1, 21, $itemID)
	Else
		$consumableItemBagAndSlot = FindInStorages(1, $bags_count, $itemID)
	EndIf

	Local $consumableBag = $consumableItemBagAndSlot[0]
	Local $consumableSlot = $consumableItemBagAndSlot[1]
	If $consumableBag <> 0 And $consumableSlot <> 0 Then
		UseItemBySlot($consumableBag, $consumableSlot)
		Return $SUCCESS
	Else
		Return $FAIL
	EndIf
EndFunc


;~ Uses a consumable from inventory or chest, if present
Func UseConsumable($consumableID, $forceUse = False, $checkXunlaiChest = True)
	If (Not $forceUse And Not $run_options_cache['run.consume_consumables']) Then Return
	If Not IsConsumable($consumableID) Then
		Warn('Provided item model ID might not correspond to consumable')
		Return $FAIL
	EndIf
	Local $result = UseItemFromInventory($consumableID, $forceUse, $checkXunlaiChest)
	If $result == $SUCCESS Then Info('Consumable ' & $consumableID & ' used successfully')
	If $result == $FAIL Then Warn('Could not find specified consumable in inventory')
	Return $result
EndFunc


;~ Uses a scroll from inventory or chest, if present
Func UseScroll($scrollID, $forceUse = False, $checkXunlaiChest = True)
	If Not IsBlueScroll($scrollID) And Not IsGoldScroll($scrollID) Then
		Warn('Provided item model ID might not correspond to scroll')
		Return $FAIL
	EndIf
	Local $result = UseItemFromInventory($scrollID, $forceUse, $checkXunlaiChest)
	If $result == $SUCCESS Then Info('Scroll used successfully')
	If $result == $FAIL Then Warn('Could not find specified scroll in inventory')
	Return $result
EndFunc


;~ Uses the Item from $bag at position $slot (positions start at 1)
Func UseItemBySlot($bagIndex, $slot)
	If $bagIndex > 0 And $slot > 0 Then
		If IsPlayerAlive() And GetMapType() <> $ID_LOADING Then
			Local $item = GetItemBySlot($bagIndex, $slot)
			SendPacket(8, $HEADER_Item_USE, DllStructGetData($item, 'ID'))
		EndIf
	EndIf
EndFunc
#EndRegion Use Items


#Region Items tests
;~ Print Item informations
Func PrintItemInformations($item)
	Info('ID: ' & DllStructGetData($item, 'ID'))
	Info('ModStruct: ' & GetModStruct($item))
	Info('ModStructSize: ' & DllStructGetData($item, 'ModStructSize'))
	Info('ModelFileID: ' & DllStructGetData($item, 'ModelFileID'))
	Info('Type: ' & DllStructGetData($item, 'Type'))
	Info('DyeColor: ' & DllStructGetData($item, 'DyeColor'))
	Info('Value: ' & DllStructGetData($item, 'Value'))
	Info('Interaction: ' & DllStructGetData($item, 'Interaction'))
	Info('ModelID: ' & DllStructGetData($item, 'ModelID'))
	Info('ItemFormula: ' & DllStructGetData($item, 'ItemFormula'))
	Info('IsMaterialSalvageable: ' & DllStructGetData($item, 'IsMaterialSalvageable'))
	Info('Quantity: ' & DllStructGetData($item, 'Quantity'))
	Info('Equipped: ' & DllStructGetData($item, 'Equipped'))
	Info('Profession: ' & DllStructGetData($item, 'Profession'))
	Info('Type2: ' & DllStructGetData($item, 'Type2'))
	Info('Slot: ' & DllStructGetData($item, 'Slot'))
EndFunc


;~ v15 live-test helper (TESTING.md), for the Options tab 'Manual' field: PrintItemInformationsAt(1, 3) logs ModelID, ModStruct, etc.
;~ of the item in bag 1 (backpack) slot 3. Read-only: memory reads only, nothing is sent to the game.
Func PrintItemInformationsAt($bagIndex, $slot)
	$bagIndex = Number(StringStripWS($bagIndex, 3))
	$slot = Number(StringStripWS($slot, 3))
	If GetProcessHandle() == '' Or GetProcessHandle() == 0 Then
		Warn('[Item] Not attached to Guild Wars - attach first (Tools > Attach to Guild Wars)')
		Return False
	EndIf
	If $bagIndex < 1 Or $bagIndex > 21 Or $slot < 1 Then
		Warn('[Item] Usage: PrintItemInformationsAt(bag, slot) - bag 1-5 inventory (1 = backpack), 8-21 Xunlai panes; slot from 1')
		Return False
	EndIf
	Local $bag = GetBag($bagIndex)
	If Not IsDllStruct($bag) Or $slot > DllStructGetData($bag, 'slots') Then
		Warn('[Item] Bag ' & $bagIndex & ' does not exist or has fewer than ' & $slot & ' slots')
		Return False
	EndIf
	Local $item = GetItemBySlot($bagIndex, $slot)
	If Not IsDllStruct($item) Or DllStructGetData($item, 'ID') == 0 Then
		Warn('[Item] No item in bag ' & $bagIndex & ' slot ' & $slot)
		Return False
	EndIf
	Info('[Item] bag ' & $bagIndex & ' slot ' & $slot & ':')
	PrintItemInformations($item)
	Return True
EndFunc


;~ Get the item maximum damage
Func GetItemMaxDmg($item)
	Local $type = DllStructGetData($item, 'Type')
	Local $modString = GetModStruct($item)
	Local $position = 0
	Switch $type
		Case $ID_TYPE_OFFHAND
			$position = StringInStr($modString, 'C867') - 2
		Case $ID_TYPE_SHIELD
			$position = StringInStr($modString, 'B8A7') - 2
		Case Else
			$position = StringInStr($modString, 'A8A7') - 2
	EndSwitch
	If $position <= 0 Then Return 0
	Return Int('0x' & StringMid($modString, $position, 2))
EndFunc


;~ Get the item minimum damage
Func GetItemMinDmg($item)
	Local $type = DllStructGetData($item, 'Type')
	Local $modString = GetModStruct($item)
	Local $position = 0
	Switch $type
		Case $ID_TYPE_OFFHAND
			$position = StringInStr($modString, 'C867') - 2
		Case $ID_TYPE_SHIELD
			$position = StringInStr($modString, 'B8A7') - 2
		Case Else
			$position = StringInStr($modString, 'A8A7') - 4
	EndSwitch
	If $position <= 0 Then Return 0
	Return Int('0x' & StringMid($modString, $position, 2))
EndFunc


;~ Get staff base energy
Func GetStaffEnergy($staffItem)
	Local $modString = GetModStruct($staffItem)
	Local $position = StringInStr($modString, 'C862') - 2
	If $position <= 0 Then Return 0
	Return Int('0x' & StringMid($modString, $position, 2))
EndFunc


;~ Get staff base HSR chance (chance to Half Skill Recharge of spells)
Func GetStaffHSR($staffItem)
	Local $modString = GetModStruct($staffItem)
	Local $position = StringInStr($modString, 'A823') - 2
	If $position <= 0 Then Return 0
	Return Int('0x' & StringMid($modString, $position, 2))
EndFunc


;~ Return True if the item is a kit or a lockpick - used in Storage Bot to not sell those
Func IsGeneralItem($itemID)
	Return $MAP_GENERAL_ITEMS[$itemID] <> Null
EndFunc


;~ Returns true if the item is an armor salvage
Func IsArmorSalvageItem($item)
	Return DllStructGetData($item, 'type') == $ID_TYPE_ARMOR_SALVAGE
EndFunc


;~ Returns true if the item is a book
Func IsBook($item)
	Return DllStructGetData($item, 'type') == $ID_TYPE_BOOK
EndFunc


;~ Returns true if the item is stackable
Func IsStackable($item)
	Return BitAND(DllStructGetData($item, 'Interaction'), 0x80000) <> 0
EndFunc


;~ Returns true if the item is inscribable
Func IsInscribable($item)
	Return BitAND(DllStructGetData($item, 'Interaction'), 0x08000000) <> 0
EndFunc


;~ Returns true if the item is a material, basic or rare
Func IsMaterial($item)
	Return DllStructGetData($item, 'Type') == 11 And $MAP_ALL_MATERIALS[DllStructGetData($item, 'ModelID')] <> Null
EndFunc


;~ Returns true if the item is a basic material
Func IsBasicMaterial($item)
	;Return DllStructGetData($item, 'Type') == 11 And $MAP_BASIC_MATERIALS[DllStructGetData($item, 'ModelID')] <> Null
	Return DllStructGetData($item, 'Type') == 11 And BitAND(DllStructGetData($item, 'Interaction'), 0x20) <> 0
EndFunc


;~ Returns true if the item is a rare material
Func IsRareMaterial($item)
	;Return DllStructGetData($item, 'Type') == 11 And $MAP_RARE_MATERIALS[DllStructGetData($item, 'ModelID')] <> Null
	Return DllStructGetData($item, 'Type') == 11 And Not IsBasicMaterial($item)
EndFunc


;~ Returns true if the item is a consumable
Func IsConsumable($itemID)
	Return IsAlcohol($itemID) Or IsFestive($itemID) Or IsTownSweet($itemID) Or IsPCon($itemID) Or IsDPRemovalSweet($itemID) Or _
		IsSummoningStone($itemID) Or IsPartyTonic($itemID) Or IsEverlastingTonic($itemID) Or IsConset($itemID)
EndFunc


;~ Returns true if the item is 1 of 3 conset items: Essence of Celerity, Armor of Salvation, Grail of Might
Func IsConset($itemID)
	Return $MAP_CONSETS[$itemID] <> Null
EndFunc


;~ Returns true if the item is an alcohol
Func IsAlcohol($itemID)
	Return $MAP_ALCOHOLS[$itemID] <> Null
EndFunc


;~ Returns true if the item is a festive item
Func IsFestive($itemID)
	Return $MAP_FESTIVE[$itemID] <> Null
EndFunc


;~ Returns true if the item is a sweet
Func IsTownSweet($itemID)
	Return $MAP_TOWN_SWEETS[$itemID] <> Null
EndFunc


;~ Returns true if the item is a PCon
Func IsPCon($itemID)
	Return $MAP_SWEET_PCONS[$itemID] <> Null
EndFunc


;~ Return true if the item is a sweet removing doubl... death penalty
Func IsDPRemovalSweet($itemID)
	Return $MAP_DP_REMOVAL_SWEETS[$itemID] <> Null
EndFunc


;~ Return true if the item is a special drop
Func IsSpecialDrop($itemID)
	Return $MAP_SPECIAL_DROPS[$itemID] <> Null
EndFunc


;~ Return true if the item is a miniature
Func IsMiniature($item)
	Return DllStructGetData($item, 'Type') == 34
EndFunc


;~ Return true if the item is a consumable of any kind
Func IsConsumableBis($item)
	Return DllStructGetData($item, 'Type') == 9
EndFunc


;~ Return true if the item is a trophy (polymock piece included)
Func IsTrophyBis($item)
	Return DllStructGetData($item, 'Type') == 30
EndFunc


;~ Return true if the item is a summoning stone
Func IsSummoningStone($itemID)
	Return $MAP_SUMMONING_STONES[$itemID] <> Null
EndFunc


;~ Return true if the item is a party tonic
Func IsPartyTonic($itemID)
	Return $MAP_PARTY_TONICS[$itemID] <> Null
EndFunc


;~ Return true if the item is an everlasting tonic
Func IsEverlastingTonic($itemID)
	Return $MAP_EL_TONICS[$itemID] <> Null
EndFunc


;~ Return true if the item is a reward trophy
Func IsRewardTrophy($itemID)
	Return $MAP_REWARD_TROPHIES[$itemID] <> Null
EndFunc


;~ Return true if the item is a trophy
Func IsTrophy($itemID)
	Return $MAP_TROPHIES[$itemID] <> Null Or $MAP_REWARD_TROPHIES[$itemID] <> Null
EndFunc


;~ Return true if the item is an armor
Func IsArmor($item)
	Return $MAP_ARMOR_TYPES[DllStructGetData($item, 'type')] <> Null
EndFunc


;~ Return true if the item is a weapon
Func IsWeapon($item)
	Return $MAP_WEAPON_TYPES[DllStructGetData($item, 'type')] <> Null
EndFunc


;~ Return true if the item is a weapon mod
Func IsWeaponMod($itemID)
	Return $MAP_WEAPON_MODS[$itemID] <> Null
EndFunc


;~ Return true if the item is a tome
Func IsTome($itemID)
	Return $MAP_TOMES[$itemID] <> Null
EndFunc


;~ Return true if the item is a regular tome
Func IsRegularTome($itemID)
	Return $MAP_REGULAR_TOMES[$itemID] <> Null
EndFunc


;~ Return true if the item is an elite tome
Func IsEliteTome($itemID)
	Return $MAP_ELITE_TOMES[$itemID] <> Null
EndFunc


;~ Return true if the item is a gold scroll
Func IsGoldScroll($itemID)
	Return $MAP_GOLD_SCROLLS[$itemID] <> Null
EndFunc


;~ Return true if the item is a blue scroll
Func IsBlueScroll($itemID)
	Return $MAP_BLUE_SCROLLS[$itemID] <> Null
EndFunc


;~ Return true if the item is a key
Func IsKey($itemID)
	Return $MAP_KEYS[$itemID] <> Null
EndFunc


;~ Return true if the item is a map piece
Func IsMapPiece($itemID)
	Return $MAP_MAP_PIECES[$itemID] <> Null
EndFunc


;~ Identify is an item is q0-q8 with max damage
Func IsLowReqMaxDamage($item)
	If Not IsWeapon($item) Then Return False
	Local $requirement = GetItemReq($item)
	Return $requirement < 9 And IsMaxStatsForReq($item) And IsMinReqForDamage($item)
EndFunc


;~ Identify if an item is q0 with max damage
Func IsNoReqMaxDamage($item)
	If Not IsWeapon($item) Then Return False
	Local $requirement = GetItemReq($item)
	Return $requirement == 0 And IsMaxStatsForReq($item) And IsMinReqForDamage($item)
EndFunc


;~ Identify if an item has max damage for its requirement
Func IsMaxDamageForReq($item)
	If Not IsWeapon($item) Then Return False
	Local $type = DllStructGetData($item, 'Type')
	Local $requirement = GetItemReq($item)
	Local $damage = GetItemMaxDmg($item)
	Local $weaponMaxDamages = $WEAPONS_MAX_DAMAGE_PER_LEVEL[$type]
	Local $maxDamage = $weaponMaxDamages[$requirement]
	If $damage == $maxDamage Then Return True
	Return False
EndFunc


;~ Identify if an item has max stats (damage, energy, armor, HSR) for its requirement
Func IsMaxStatsForReq($item)
	If Not IsWeapon($item) Then Return False
	Local $type = DllStructGetData($item, 'Type')
	Local $requirement = GetItemReq($item)

	Local $maxDamage = GetItemMaxDmg($item)
	Local $weaponMaxDamages = $WEAPONS_MAX_DAMAGE_PER_LEVEL[$type]
	Local $weaponMaxDamage = $weaponMaxDamages[$requirement]
	If $maxDamage <> $weaponMaxDamage Then Return False

	Local $minDamage = GetItemMinDmg($item)
	Local $weaponMinDamages = $WEAPONS_MIN_DAMAGE_PER_LEVEL[$type]
	Local $weaponMinDamage = $weaponMinDamages[$requirement]
	If $minDamage <> $weaponMinDamage Then Return False

	If $type == $ID_TYPE_STAFF Then
		Local $staffEnergy = GetStaffEnergy($item)
		Local $staffMaxEnergy = $STAFF_MAX_ENERGY_PER_LEVEL[$requirement]
		If $staffEnergy <> $staffMaxEnergy Then Return False

		Local $staffHSR = GetStaffHSR($item)
		Local $staffMaxHSR = $STAFF_MAX_HSR_PER_LEVEL[$requirement]
		If $staffHSR <> $staffMaxHSR Then Return False
	EndIf

	Return True
EndFunc


;~ Identify if an item has the minimum req for its (upper bound) damage
Func IsMinReqForDamage($item)
	If Not IsWeapon($item) Then Return False

	Local $type = DllStructGetData($item, 'Type')
	Local $requirement = GetItemReq($item)

	Local $maxDamage = GetItemMaxDmg($item)
	Local $weaponMinReqs = $WEAPONS_MIN_REQ_PER_MAX_DAMAGE[$type]
	Local $minReq = $weaponMinReqs[$maxDamage]
	Return $minReq <> Null And $requirement == $minReq
EndFunc


;~ Returns true if an item has a 'Salvageable' inscription
Func HasSalvageInscription($item)
	Local $salvageableInscription[] = ['1F0208243E0432251', '0008260711A8A7000000C', '0008261323A8A7000000C', '00082600011826900098260F1CA8A7000000C']
	Local $modstruct = GetModStruct($item)
	For $salvageableModStruct in $salvageableInscription
		If StringInStr($modstruct, $salvageableModStruct) Then Return True
	Next
	Return False
EndFunc
#EndRegion Items tests


#Region Reading items data
;~ Read data from item at bagIndex and slot and print it in the console
Func ReadOneItemData($bagIndex, $slot)
	Info('bag;slot;rarity;modelID;ID;type;attribute;requirement;stats;nameString;mods;quantity;value')
	Local $output = GetOneItemData($bagIndex, $slot)
	If $output == '' Then Return
	Info($output)
EndFunc


;~ Read data from all items in inventory and print it in the console
Func ReadAllItemsData()
	Info('bag;slot;rarity;modelID;ID;type;attribute;requirement;stats;nameString;mods;quantity;value')
	Local $item, $output
	For $bagIndex = 1 To $bags_count
		Local $bag = GetBag($bagIndex)
		For $slot = 1 To DllStructGetData($bag, 'slots')
			$output = GetOneItemData($bagIndex, $slot)
			If $output == '' Then ContinueLoop
			Info($output)
			RandomSleep(250)
		Next
	Next
EndFunc


;~ Get data from an item into a string
Func GetOneItemData($bagIndex, $slot)
	Local $item = GetItemBySlot($bagIndex, $slot)
	Local $output = ''
	If DllStructGetData($item, 'ID') <> 0 Then
		$output &= $bagIndex & ';'
		$output &= $slot & ';'
		$output &= DllStructGetData($item, 'rarity') & ';'
		$output &= DllStructGetData($item, 'ModelID') & ';'
		$output &= DllStructGetData($item, 'ID') & ';'
		$output &= DllStructGetData($item, 'Type') & ';'
		$output &= GetOrDefault(GetItemAttribute($item) & ';', '')
		$output &= GetOrDefault(GetItemReq($item) & ';', '')
		$output &= GetOrDefault(GetItemMaxDmg($item) & ';', '')
		$output &= DllStructGetData($item, 'NameString') & ';'
		$output &= GetModStruct($item) & ';'
		$output &= DllStructGetData($item, 'quantity') & ';'
		$output &= GetOrDefault(DllStructGetData($item, 'Value') & ';', 0)
	EndIf
	Return $output
EndFunc
#EndRegion Reading items data


#Region Database
Global $sqlite_db

#Region Tables
; Those tables are built automatically and one is completed by the user
Global Const $TABLE_DATA_RAW = 'DATA_RAW'
Global Const $SCHEMA_DATA_RAW = ['batch', 'bag', 'slot', 'model_ID', 'type_ID', 'min_stat', 'max_stat', 'requirement', 'attribute_ID', 'name_string', 'OS', 'modstruct', 'quantity', 'value', 'rarity_ID', 'dye_color', 'ID']
							;address ? interaction ? model_file_ID ? name enc ? desc enc ? several modstruct (4, 8 ?) - identifier, arg1, arg2

Global Const $TABLE_DATA_USER = 'DATA_USER'
Global Const $SCHEMA_DATA_USER = ['batch', 'bag', 'slot', 'rarity', 'type', 'requirement', 'attribute', 'value', 'name', 'OS', 'prefix', 'suffix', 'inscription', 'type_ID', 'model_ID', 'name_string', 'modstruct', 'dye_color', 'ID']

Global Const $TABLE_DATA_SALVAGE = 'DATA_SALVAGE'
Global Const $SCHEMA_DATA_SALVAGE = ['batch', 'model_ID', 'material', 'amount']

; Those 3 lookups are filled directly when database is created
Global Const $TABLE_LOOKUP_ATTRIBUTE = 'LOOKUP_ATTRIBUTE'
Global Const $SCHEMA_LOOKUP_ATTRIBUTE = ['attribute_ID', 'attribute']

Global Const $TABLE_LOOKUP_RARITY = 'LOOKUP_RARITY'
Global Const $SCHEMA_LOOKUP_RARITY = ['rarity_ID', 'rarity']

Global Const $TABLE_LOOKUP_TYPE = 'LOOKUP_TYPE'
Global Const $SCHEMA_LOOKUP_TYPE = ['type_ID', 'type']

; Those lookups are built from the data table filled by the user
Global Const $TABLE_LOOKUP_MODEL = 'LOOKUP_MODEL'
Global Const $SCHEMA_LOOKUP_MODEL = ['type_ID', 'model_ID', 'model_name', 'OS']

Global Const $TABLE_LOOKUP_UPGRADES = 'LOOKUP_UPGRADES'
Global Const $SCHEMA_LOOKUP_UPGRADES = ['OS', 'upgrade_type', 'weapon', 'effect', 'hexa', 'name', 'propagate']
#EndRegion Tables


;~ Connect to the database storing information about items
Func ConnectToDatabase()
	_SQLite_Startup()
	If @error Then Exit MsgBox(16, 'SQLite Error', 'Failed to start SQLite')
	FileChangeDir(@ScriptDir)
	$sqlite_db = _SQLite_Open('data\items_database.db3')
	If @error Then Exit MsgBox(16, 'SQLite Error', 'Failed to open database: ' & _SQLite_ErrMsg())
	;_SQLite_SetSafeMode(False)
	Info('Opened database at ' & @ScriptDir & '\data\items_database.db3')
EndFunc


;~ Disconnect from the database
Func DisconnectFromDatabase()
	_SQLite_Close()
	_SQLite_Shutdown()
EndFunc


;~ Create tables and views and fill the ones that need it
Func InitializeDatabase()
	CreateTable($TABLE_LOOKUP_ATTRIBUTE, $SCHEMA_LOOKUP_ATTRIBUTE)
	CreateTable($TABLE_LOOKUP_RARITY, $SCHEMA_LOOKUP_RARITY)
	CreateTable($TABLE_LOOKUP_TYPE, $SCHEMA_LOOKUP_TYPE)

	CreateTable($TABLE_LOOKUP_MODEL, $SCHEMA_LOOKUP_MODEL)
	CreateTable($TABLE_LOOKUP_UPGRADES, $SCHEMA_LOOKUP_UPGRADES)

	CreateTable($TABLE_DATA_RAW, $SCHEMA_DATA_RAW)
	CreateTable($TABLE_DATA_USER, $SCHEMA_DATA_USER)

	Local $columnsTypeIsNumber[] = [True, False]
	If TableIsEmpty($TABLE_LOOKUP_TYPE) Then FillTable($TABLE_LOOKUP_TYPE, $columnsTypeIsNumber, $ITEM_TYPES_DOUBLE_ARRAY)
	If TableIsEmpty($TABLE_LOOKUP_ATTRIBUTE) Then FillTable($TABLE_LOOKUP_ATTRIBUTE, $columnsTypeIsNumber, $ATTRIBUTES_DOUBLE_ARRAY)
	If TableIsEmpty($TABLE_LOOKUP_RARITY) Then FillTable($TABLE_LOOKUP_RARITY, $columnsTypeIsNumber, $RARITIES_DOUBLE_ARRAY)
EndFunc


;~ Create a table
Func CreateTable($tableName, $tableColumns, $ifNotExists = True)
	Local $query = 'CREATE TABLE '
	If $ifNotExists Then $query &= 'IF NOT EXISTS '
	$query &= $tableName & ' ('
	For $column in $tableColumns
		$query &= $column & ', '
	Next
	$query = StringLeft($query, StringLen($query) - 2)
	$query &= ');'
	SQLExecute($query)
EndFunc


;~ Drop a table
Func DropTable($tableName)
	Local $query = 'DROP TABLE IF EXISTS ' & $tableName & ';'
	SQLExecute($query)
EndFunc


;~ Fill a table with the given values (bidimensional array)
Func FillTable($table, Const ByRef $isNumber, Const ByRef $values)
	Local $query = 'INSERT INTO ' & $table & ' VALUES '
	For $i = 0 To UBound($values) - 1
		$query &= '('
		For $j = 0 To UBound($values, 2) - 1
			If $isNumber[$j] Then
				$query &= $values[$i][$j] & ', '
			Else
				$query &= "'" & $values[$i][$j] & "', "
			EndIf
		Next
		$query = StringLeft($query, StringLen($query) - 2)
		$query &= '), '
	Next

	$query = StringLeft($query, StringLen($query) - 2)
	$query &= ';'
	SQLExecute($query)
EndFunc


#Region Database Utils
;~ Returns true if a table exists
Func TableExists($table)
	Local $queryResult, $row, $tableName = ''
	SQLQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='" & $table & "';", $queryResult)
	While _SQLite_FetchData($queryResult, $row) = $SQLITE_OK
		$tableName = $row[0]
	WEnd
	Return $tableName <> ''
EndFunc


;~ Returns true if a table is empty
Func TableIsEmpty($table)
	Local $query, $queryResult, $row, $rowCount
	SQLQuery('SELECT COUNT(*) FROM ' & $table & ';', $queryResult)
	While _SQLite_FetchData($queryResult, $row) = $SQLITE_OK
		$rowCount = $row[0]
	WEnd
	Return $rowCount == 0
EndFunc


;~ Query database
Func SQLQuery($query, ByRef $queryResult)
	Debug($query)
	Local $result = _SQLite_Query($sqlite_db, $query, $queryResult)
	If $result <> 0 Then Error('Query failed ! Failure on : ' & @CRLF & $query)
EndFunc


;~ Execute a request on the database
Func SQLExecute($query)
	Debug($query)
	Local $result = _SQLite_Exec($sqlite_db, $query)
	If $result <> 0 Then Error('Query failed ! Failure on : ' & @CRLF & $query & @CRLF & @error)
EndFunc
#EndRegion Database Utils


;~ Store in database all data that can be found in items in inventory
Func StoreAllItemsData()
	Local $insertQuery, $item
	Local $batchID = GetPreviousBatchID() + 1

	Info('Scanning and storing all items data')
	SQLExecute('BEGIN;')
	$insertQuery = 'INSERT INTO ' & $TABLE_DATA_RAW & ' VALUES' & @CRLF
	For $bagIndex = 1 To $bags_count
		Local $bag = GetBag($bagIndex)
		For $i = 1 To DllStructGetData($bag, 'slots')
			$item = GetItemBySlot($bagIndex, $i)
			If DllStructGetData($item, 'ID') = 0 Then ContinueLoop
			GetItemReq($item)
			$insertQuery &= '	('
			$insertQuery &= $batchID & ', '
			$insertQuery &= $bagIndex & ', '
			$insertQuery &= $i & ', '
			$insertQuery &= DllStructGetData($item, 'modelID') & ', '
			$insertQuery &= DllStructGetData($item, 'type') & ', '
			$insertQuery &= 'NULL, '
			$insertQuery &= (IsWeapon($item) ? GetItemMaxDmg($item) : 'NULL') & ', '
			$insertQuery &= (IsWeapon($item) ? GetItemReq($item) : 'NULL') & ', '
			$insertQuery &= (IsWeapon($item) ? GetItemAttribute($item) : 'NULL') & ", '"
			$insertQuery &= DllStructGetData($item, 'nameString') & "', '"
			$insertQuery &= (IsInscribable($item) ? 0 : 1) & "', '"
			$insertQuery &= GetModStruct($item) & "', "
			$insertQuery &= DllStructGetData($item, 'quantity') & ', '
			$insertQuery &= GetOrDefault(DllStructGetData($item, 'value'), 0) & ', '
			$insertQuery &= GetRarity($item) & ', '
			$insertQuery &= DllStructGetData($item, 'DyeColor') & ', '
			$insertQuery &= DllStructGetData($item, 'ID')
			$insertQuery &= '),' & @CRLF
			Sleep(50)
		Next
	Next

	$insertQuery = StringLeft($insertQuery, StringLen($insertQuery) - 3) & @CRLF & ';'
	SQLExecute($insertQuery)
	SQLExecute('COMMIT;')

	AddToFilledData($batchID)
	CompleteItemsMods($batchID)
EndFunc


;~ Insert data into the RAW data table
Func AddToFilledData($batchID)
	Local $insertQuery = 'WITH raw AS (' & @CRLF _
		& '	SELECT batch, bag, slot, value, requirement, rarity_ID, type_ID, attribute_ID, model_ID, type_ID, model_ID, name_string, OS, modstruct, dye_color, ID FROM ' & $TABLE_DATA_RAW & ' WHERE batch = ' & $batchID & @CRLF _
		& ')' & @CRLF _
		& 'INSERT INTO ' & $TABLE_DATA_USER & @CRLF _
		& 'SELECT raw.batch, raw.bag, raw.slot, rarities.rarity, types.type, requirement, attributes.attribute, raw.value, names.model_name, raw.OS, NULL, NULL, NULL, raw.type_ID, raw.model_ID, raw.name_string, raw.modstruct, raw.dye_color, raw.ID' & @CRLF _
		& 'FROM raw' & @CRLF _
		& 'LEFT JOIN ' & $TABLE_LOOKUP_RARITY & ' rarities ON raw.rarity_ID = rarities.rarity_ID' & @CRLF _
		& 'LEFT JOIN ' & $TABLE_LOOKUP_TYPE & ' types ON raw.type_ID = types.type_ID' & @CRLF _
		& 'LEFT JOIN ' & $TABLE_LOOKUP_ATTRIBUTE & ' attributes ON raw.attribute_ID = attributes.attribute_ID' & @CRLF _
		& 'LEFT JOIN ' & $TABLE_LOOKUP_MODEL & ' names ON raw.type_ID = names.type_ID AND raw.model_ID = names.model_ID;'
	SQLExecute($insertQuery)
EndFunc


;~ Auto fill the items mods based on the known modstructs
Func CompleteItemsMods($batchID)
	Info('Completing items mods')
	Local $upgradeTypes[] = ['prefix', 'suffix', 'inscription']
	Local $query
	For $upgradeType In $upgradeTypes
		$query = 'UPDATE ' & $TABLE_DATA_USER & @CRLF _
			& 'SET ' & $upgradeType & ' = (' & @CRLF _
			& '	SELECT upgrades.effect' & @CRLF _
			& '	FROM ' & $TABLE_LOOKUP_UPGRADES & ' upgrades' & @CRLF _
			& '	WHERE upgrades.propagate = 1' & @CRLF _
			& '		AND upgrades.weapon = type_ID' & @CRLF _
			& '		AND upgrades.hexa IS NOT NULL' & @CRLF _
			& "		AND upgrades.upgrade_type = '" & $upgradeType & "'" & @CRLF _
			& "		AND modstruct LIKE ('%' || upgrades.hexa || '%')" & @CRLF _
			& ')' & @CRLF _
			& 'WHERE ' & $upgradeType & ' IS NULL' & @CRLF _
			& '	AND batch = ' & $batchID & @CRLF _
			& '	AND EXISTS (' & @CRLF _
			& '		SELECT upgrades.effect' & @CRLF _
			& '		FROM ' & $TABLE_LOOKUP_UPGRADES & ' upgrades' & @CRLF _
			& '		WHERE upgrades.propagate = 1' & @CRLF _
			& '			AND upgrades.weapon = type_ID' & @CRLF _
			& '			AND upgrades.hexa IS NOT NULL' & @CRLF _
			& "			AND upgrades.upgrade_type = '" & $upgradeType & "'" & @CRLF _
			& "			AND modstruct LIKE ('%' || upgrades.hexa || '%')" & @CRLF _
			& ');'
		SQLExecute($query)
	Next
EndFunc


;~ Get the previous batchID or -1 if no batch has been added into database
Func GetPreviousBatchID()
	Local $queryResult, $row, $lastBatchID, $query
	$query = 'SELECT COALESCE(MAX(batch), -1) FROM ' & $TABLE_DATA_RAW & ';'
	SQLQuery($query, $queryResult)
	While _SQLite_FetchData($queryResult, $row) = $SQLITE_OK
		$lastBatchID = $row[0]
	WEnd
	Return $lastBatchID
EndFunc


;~ Complete model name lookup table
Func CompleteModelLookupTable()
	Local $query
	Info('Completing model lookup ')
	$query = 'INSERT INTO ' & $TABLE_LOOKUP_MODEL & @CRLF _
		& 'SELECT DISTINCT type_ID, model_ID, name, OS' & @CRLF _
		& 'FROM ' & $TABLE_DATA_USER & @CRLF _
		& 'WHERE name IS NOT NULL' & @CRLF _
		& '	AND (type_ID, model_ID) NOT IN (SELECT type_ID, model_ID FROM ' & $TABLE_LOOKUP_MODEL & ');'
	SQLExecute($query)
EndFunc


;~ Complete mods data by cross-comparing all modstructs from items that have the same mods and deduce the mod hexa from it
Func CompleteUpgradeLookupTable()
	Info('Completing upgrade lookup')
	Local $modTypes[] = ['prefix', 'suffix', 'inscription']
	For $upgradeType In $modTypes
		InsertNewUpgrades($upgradeType)
		UpdateNewUpgrades($upgradeType)
		ValidateNewUpgrades($upgradeType)
	Next
EndFunc


;~ Insert upgrades not already present in database
Func InsertNewUpgrades($upgradeType)
	Local $query = 'INSERT INTO ' & $TABLE_LOOKUP_UPGRADES & @CRLF _
		& "SELECT DISTINCT OS, '" & $upgradeType & "', type_ID, " & $upgradeType & ', NULL, NULL, 0' & @CRLF _
		& 'FROM ' & $TABLE_DATA_USER & @CRLF _
		& 'WHERE ' & $upgradeType & ' IS NOT NULL' & @CRLF _
		& "AND (OS, '" & $upgradeType & "', type_ID, " & $upgradeType & ') NOT IN (SELECT OS, upgrade_type, weapon, effect FROM ' & $TABLE_LOOKUP_UPGRADES & ');'
	SQLExecute($query)
EndFunc


;~ Update upgrades with their hexa struct if we manage to find enough similarities
Func UpdateNewUpgrades($upgradeType)
	Local $queryResult, $row
	Local $mapItemStruct[]
	Local $query = 'WITH valid_groups AS (' & @CRLF _
		& '	SELECT OS, type_ID AS weapon, ' & $upgradeType & ' FROM ' & $TABLE_DATA_USER & ' WHERE ' & $upgradeType & ' IS NOT NULL GROUP BY OS, weapon, ' & $upgradeType & ' HAVING COUNT(*) > 3' & @CRLF _
		& ')' & @CRLF _
		& 'SELECT valid_groups.OS, weapon, valid_groups.' & $upgradeType & ', data.modstruct' & @CRLF _
		& 'FROM ' & $TABLE_DATA_USER & ' data' & @CRLF _
		& 'INNER JOIN valid_groups' & @CRLF _
		& '	ON valid_groups.OS = data.OS AND valid_groups.weapon = data.type_ID AND valid_groups.' & $upgradeType & ' = data.' & $upgradeType & @CRLF _
		& 'ORDER BY valid_groups.' & $upgradeType & ';'
	SQLQuery($query, $queryResult)
	While _SQLite_FetchData($queryResult, $row) = $SQLITE_OK
		$mapItemStruct = AppendArrayMap($mapItemStruct, $row[0] & '|' & $row[1] & '|' & $row[2], $row[3])
	WEnd

	Local $osWeaponUpgradeTypes = MapKeys($mapItemStruct)
	For $OSWeaponUpgradeType In $osWeaponUpgradeTypes
		Local $modStruct = LongestCommonSubstring($mapItemStruct[$OSWeaponUpgradeType])
		Local $bananaSplit = StringSplit($OSWeaponUpgradeType, '|')

		$query = 'UPDATE ' & $TABLE_LOOKUP_UPGRADES & @CRLF _
			& "	SET hexa = '" & $modStruct & "' WHERE OS = " & $bananaSplit[1] & " AND upgrade_type = '" & $upgradeType & "' AND weapon = " & $bananaSplit[2] & " AND effect = '" & $bananaSplit[3] & "';"
		SQLExecute($query)
	Next
EndFunc


;~ Validate that the upgrades hexa structs we found are correct
Func ValidateNewUpgrades($upgradeType)
	Local $query
	$query = 'UPDATE ' & $TABLE_LOOKUP_UPGRADES & @CRLF _
		& 'SET propagate = 2' & @CRLF _
		& 'WHERE hexa IS NOT NULL' & @CRLF _
		& 'AND EXISTS (' & @CRLF _
		& "	SELECT data.OS, type_ID, '" & $upgradeType & "', " & $upgradeType & @CRLF _
		& '	FROM ' & $TABLE_DATA_USER & ' data' & @CRLF _
		& '	WHERE data.OS = ' & $TABLE_LOOKUP_UPGRADES & '.OS' & @CRLF _
		& "		AND upgrade_type = '" & $upgradeType & "'" & @CRLF _
		& "		AND data.rarity = 'Gold'" & @CRLF _
		& '		AND data.type_ID = weapon' & @CRLF _
		& "		AND data.modstruct LIKE ('%' || hexa || '%')" & @CRLF _
		& '		AND data.' & $upgradeType & ' <> effect' & @CRLF _
		& ');'
	SQLExecute($query)
EndFunc
#EndRegion Database

#Region Extract upgrades (v5 - only the upgrades checked in the 'Extract upgrades only' tree, strictly sequential)
;~ Component index sent with SalvageMod() (CtoS 0x7B SALVAGE_UPGRADE): a FIXED slot of the salvage session, whatever the item carries:
;~   prefix / insignia = 0, suffix / rune = 1, inscription = 2 (materials use the separate SALVAGE_MATERIALS packet)
;~ Sources: GWCA GameEntities/Item.h SalvageSessionInfo {salvagable_1 = Prefix, salvagable_2 = Suffix, salvagable_3 = Inscription,
;~ chosen_salvagable (3 = materials)}, Py4GW MerchantRules salvage-by-slot (prefix/suffix/inscription options), upstream BotsHub
;~ SalvageItem() ('Prefix' 0, 'Suffix' 1, 'Inscription' 2).
;~ v11 (item & mod audit) - ROOT CAUSE of "Wrapping of Enchanting (staff) / Pommel of Fortitude (sword) never extracted":
;~ v5-v10 defaulted to a 'compact' index (position among the upgrades present). An item carrying only a suffix got index 0 = the EMPTY
;~ prefix slot, nothing was salvaged, the 3 s wait timed out and the session was cancelled ('not confirmed - item skipped').
;~ Inscriptions on items with fewer than 2 mods and runes on armor without insignia were hit the same way. 'compact' is removed.
Global Const $EXTRACT_COMPONENT_INDEX_MODE = 'fixed'
; v7: an expert/superior salvage only has a CHANCE to destroy the item - safety cap on extractions from one surviving item
Global Const $EXTRACT_MAX_SUCCESSES_PER_ITEM = 3


;~ Extract upgrades only (Tools tab button).
;~ Reads the checked leaves of the 'Extract Components' tree (legacy 'Extract upgrades only' accepted). Live from the GUI, or the loaded config when headless.
;~ then for ONE item at a time: reads its modstruct, finds a CHECKED upgrade on it, computes that component's index,
;~ starts ONE salvage session with a freshly re-read kit, selects ONLY that component, waits for confirmation.
;~ Items with none of the checked upgrades are skipped WITHOUT starting a salvage session.
;~ v7: if the item survives a successful extraction, it is re-read and its next checked upgrade (by priority)
;~ is extracted (fixed slot by kind), until it is destroyed, has no checked upgrade left, or hits $EXTRACT_MAX_SUCCESSES_PER_ITEM. Failed items stay excluded.
;~ v22: $autoBuyKits (only the 'Extract selected components before selling' town pass): when no Expert/Superior kit is left,
;~ buy an Expert Salvage Kit at the trade town merchant and continue, at most $EXTRACT_MAX_KIT_BUYS_PER_PASS per pass.
;~ The Tools button calls it with no arguments: unchanged behaviour (stops when there is no kit).
Func ExtractUpgradesOnly($autoBuyKits = False, $tradeTown = $ID_EYE_OF_THE_NORTH, $preloadedDefinitions = Null)
	Info('[Extract] Starting upgrade extraction (only checked upgrades, one item at a time)')
	Local $definitions = IsArray($preloadedDefinitions) ? $preloadedDefinitions : LoadExtractUpgradeDefinitions()
	If UBound($definitions) == 0 Then Return False
	If Not ExtractUpgradesPreflight() Then Return False
	Local $storeSource = ''
	Local $storeCache = BuildStoreProtectionCache($storeSource)
	Info('[Extract] Store items protection read from ' & $storeSource & ($storeCache['@store.nothing'] ? ' (nothing checked)' : ''))
	Local $skippedItems[]
	Local $successCounts[]
	Local $extracted = 0, $failed = 0
	Local $continueItemID = 0
	Local $kitBuys = 0
	; v38.9: bags 1-5 are read once here and then tracked (see InvTrackFull/InvTrackBeforeAction/InvTrackAfterAction)
	Local $inventory[]
	InvTrackFull($inventory)
	Local $salvageKits[] = [$ID_EXPERT_SALVAGE_KIT, $ID_SUPERIOR_SALVAGE_KIT]
	Local $staleInARow = 0
	For $iteration = 1 To 500
		; 1 - re-read kit before every single salvage
		Local $kit = InvTrackFindKit($inventory, $salvageKits)
		If $kit == Null Or DllStructGetData($kit, 'ID') == 0 Then
			If Not $autoBuyKits Then
				Warn('[Extract] No Expert or Superior salvage kit in inventory (bags 1-5) - stopping')
				ExitLoop
			EndIf
			; v22: only buy when there is still something to extract
			Local $probeSkipped = $skippedItems
			Local $probeDefinition = Null, $probeLog = ''
			If $continueItemID == 0 And Not IsDllStruct(InvTrackNextCandidate($inventory, $probeSkipped, 0, $definitions, $probeDefinition, $probeLog, $storeCache)) Then ExitLoop
			If Not ExtractBuyExpertSalvageKit($kitBuys, $tradeTown) Then ExitLoop
			InvTrackFull($inventory, 'salvage kit bought')
			$kit = InvTrackFindKit($inventory, $salvageKits)
			If $kit == Null Or DllStructGetData($kit, 'ID') == 0 Then
				Warn('[Extract] The bought Expert Salvage Kit is not in bags 1-5 - stopping')
				ExitLoop
			EndIf
		EndIf
		; 2 - need one free slot for the extracted upgrade
		If CountSlots(1, _Min(4, $bags_count)) < 1 Then
			Warn('[Extract] Inventory full - need 1 free slot for the extracted upgrade - stopping')
			ExitLoop
		EndIf
		; 3 - item that survived the previous extraction first (fresh read), else fresh inventory scan
		Local $matchedDefinition = Null
		Local $priorityLog = ''
		Local $item = Null
		Local $survivorID = $continueItemID
		If $continueItemID <> 0 Then
			Local $survivor = GetItemByItemID($continueItemID)
			If IsDllStruct($survivor) And DllStructGetData($survivor, 'ID') == $continueItemID And DllStructGetData($survivor, 'Bag') <> 0 Then
				Local $survivorReason = ''
				If IsProtectedByStoreItems($survivor, $storeCache, $survivorReason) Then
					Info('[Extract] Item ' & $continueItemID & ' skipped: protected by Store items (' & $survivorReason & ')')
				Else
					$matchedDefinition = FindCheckedUpgradeOnItem($survivor, $definitions, $priorityLog)
					If IsMap($matchedDefinition) Then $item = $survivor
				EndIf
			EndIf
			If Not IsDllStruct($item) Then $skippedItems[$continueItemID] = True
			$continueItemID = 0
		EndIf
		If Not IsDllStruct($item) Then $item = InvTrackNextCandidate($inventory, $skippedItems, DllStructGetData($kit, 'ID'), $definitions, $matchedDefinition, $priorityLog, $storeCache)
		If Not IsDllStruct($item) Then ExitLoop
		Local $itemID = DllStructGetData($item, 'ID')
		; v11: fixed salvage slot by kind; the modstruct is re-read every time only to log the upgrades still on the item
		Local $hex = GetModStructHex($item)
		Local $componentIndex = ComputeSalvageComponentIndex($matchedDefinition['kind'])
		Local $groups = IsArmorSalvageItem($item) ? '' : DescribeModStructUpgradeGroups($hex)
		Info('[Extract] Item ' & $itemID & ' has checked ' & $matchedDefinition['kind'] & ' "' & $matchedDefinition['path'] & '" (' & $matchedDefinition['struct'] & ')' _
			& ($groups == '' ? '' : ' - upgrades on item: ' & $groups) _
			& ' - salvage slot ' & $componentIndex & ' (' & $EXTRACT_COMPONENT_INDEX_MODE & ': prefix/insignia 0, suffix/rune 1, inscription 2)')
		Info('[Extract] Item ' & $itemID & ' ' & $priorityLog)
		Debug('[Extract] Item ' & $itemID & ' modstruct: ' & $hex)
		If $componentIndex < 0 Then
			Warn('[Extract] Item ' & $itemID & ': unknown upgrade kind "' & $matchedDefinition['kind'] & '" - item skipped, no salvage started')
			$skippedItems[$itemID] = True
			ContinueLoop
		EndIf
		; v38.9: never act on the model without checking it: bags unchanged, item and kit read fresh and identical
		Local $trackReason = InvTrackBeforeAction($inventory, $item, $kit)
		If $trackReason <> '' Then
			InvTrackFull($inventory, $trackReason)
			$staleInARow += 1
			If $staleInARow >= 3 Then
				Warn('[Extract] Inventory keeps changing while extracting (' & $trackReason & ') - stopping; nothing is extracted from data that cannot be confirmed')
				ExitLoop
			EndIf
			; decide again on the fresh read (a survivor keeps its turn)
			If $survivorID == $itemID Then $continueItemID = $itemID
			ContinueLoop
		EndIf
		$staleInARow = 0
		Local $result = ExtractOneUpgradeFromItem($item, $kit, $componentIndex, $matchedDefinition)
		$trackReason = InvTrackAfterAction($inventory, $itemID, DllStructGetData($kit, 'ID'), $result)
		If $trackReason <> '' Then InvTrackFull($inventory, $trackReason)
		Switch $result
			Case 'destroyed'
				$extracted += 1
				$skippedItems[$itemID] = True
			Case 'survived'
				$extracted += 1
				$successCounts[$itemID] = Number($successCounts[$itemID]) + 1
				If $successCounts[$itemID] >= $EXTRACT_MAX_SUCCESSES_PER_ITEM Then
					Warn('[Extract] Item ' & $itemID & ' reached ' & $EXTRACT_MAX_SUCCESSES_PER_ITEM & ' extractions - safety stop for this item')
					$skippedItems[$itemID] = True
				Else
					Local $survivorItem = GetItemByItemID($itemID)
					Local $remaining = DescribeCheckedUpgradesOnItem($survivorItem, $definitions)
					If $remaining == '' Then
						Info('[Extract] Item ' & $itemID & ' survived, no checked upgrades left')
						$skippedItems[$itemID] = True
					Else
						Info('[Extract] Item ' & $itemID & ' survived, remaining checked upgrades: ' & $remaining)
						$continueItemID = $itemID
					EndIf
				EndIf
			Case Else
				; failed: session cancelled, never retry this item in this run (no infinite loop)
				$failed += 1
				$skippedItems[$itemID] = True
		EndSwitch
		PingSleep(250)
	Next
	Info('[Extract] Done. Extracted: ' & $extracted & ', failed: ' & $failed)
	Debug('[Extract] Inventory reads: ' & $inventory['full'] & ' full (' & $inventory['fallbacks'] & ' fallback), ' & $inventory['targeted'] & ' targeted')
	Return True
EndFunc


;~ v22: buys ONE Expert Salvage Kit (2991, merchant slot 3, 400 gold) in the trade town for the extraction pass.
;~ Returns False (and logs why) when the per-pass cap is reached or the kit did not arrive (no gold, no merchant, no space).
Func ExtractBuyExpertSalvageKit(ByRef $kitBuys, $tradeTown)
	If $kitBuys >= $EXTRACT_MAX_KIT_BUYS_PER_PASS Then
		Warn('[Extract] Already bought ' & $kitBuys & ' Expert Salvage Kit(s) this pass (cap ' & $EXTRACT_MAX_KIT_BUYS_PER_PASS & ') - stopping; items still holding a checked component are not salvaged or sold')
		Return False
	EndIf
	$kitBuys += 1
	Info('[Extract] No Expert or Superior salvage kit left - buying an Expert Salvage Kit (' & $ID_EXPERT_SALVAGE_KIT & ', 400 gold), ' & $kitBuys & '/' & $EXTRACT_MAX_KIT_BUYS_PER_PASS & ' this pass')
	Local $before = GetInventoryItemCount($ID_EXPERT_SALVAGE_KIT)
	BuyInTown($ID_EXPERT_SALVAGE_KIT, 3, 400, 1, False, $tradeTown)
	If GetInventoryItemCount($ID_EXPERT_SALVAGE_KIT) <= $before Then
		Warn('[Extract] Could not buy an Expert Salvage Kit (not enough gold, no merchant or no free slot) - stopping; items still holding a checked component are not salvaged or sold')
		Return False
	EndIf
	Info('[Extract] Bought an Expert Salvage Kit - continuing')
	Return True
EndFunc


;~ v22: 'Extract selected components before selling' (Options tab, run.extract_upgrades_only) - town pass, called from
;~ InventoryManagementBeforeRun after identification and before material salvage / selling. Same checked list, per-item logic,
;~ slots and Store items protection as the Tools button, plus Expert Salvage Kit buying. Turns on IsHeldForExtraction.
Func ExtractSelectedComponentsBeforeSelling($tradeTown = $ID_EYE_OF_THE_NORTH)
	Info('[Extract] Extract selected components before selling')
	Local $definitions = LoadExtractUpgradeDefinitions()
	If UBound($definitions) == 0 Then Return False
	$extract_guard_definitions = $definitions
	Local $storeSource = ''
	Local $storeCache = BuildStoreProtectionCache($storeSource)
	Local $skipped[]
	Local $definition = Null, $log = ''
	If Not IsDllStruct(FindNextUpgradeExtractionCandidate($skipped, 0, $definitions, $definition, $log, $storeCache)) Then
		Info('[Extract] No identified item in bags 1-4 holds a checked component - nothing to extract')
		Return True
	EndIf
	If GetMapType() <> $ID_OUTPOST Or GetMapID() <> $tradeTown Then TravelToOutpost($tradeTown, $district_name)
	ExtractUpgradesOnly(True, $tradeTown, $definitions)
	Local $held = CountItemsHeldForExtraction()
	If $held > 0 Then Warn('[Extract] ' & $held & ' item(s) still hold a checked component - not salvaged for materials or sold this pass')
	Return True
EndFunc


;~ v22: True when 'Extract selected components before selling' is protecting items and this weapon / armor salvageable still
;~ carries one of the checked components (logged). $what: 'sold' / 'salvaged for materials'
Func IsHeldForExtraction($item, $what = 'salvaged or sold')
	If Not IsArray($extract_guard_definitions) Or UBound($extract_guard_definitions) == 0 Then Return False
	If Not (IsWeapon($item) Or IsArmorSalvageItem($item)) Then Return False
	Local $log = ''
	Local $definition = FindCheckedUpgradeOnItem($item, $extract_guard_definitions, $log)
	If Not IsMap($definition) Then Return False
	Info('[Extract] Item ' & DllStructGetData($item, 'ID') & ' not ' & $what & ': still holds checked ' & $definition['kind'] & ' "' & $definition['path'] & '"')
	Return True
EndFunc


;~ v22: items in bags 1-4 still holding a checked component (Store-items-protected ones excluded: they get stored)
Func CountItemsHeldForExtraction()
	If Not IsArray($extract_guard_definitions) Then Return 0
	Local $count = 0
	For $bagIndex = 1 To _Min(4, $bags_count)
		Local $bagItems = GetBagItems($bagIndex)
		For $slot = 1 To UBound($bagItems)
			Local $item = $bagItems[$slot - 1]
			If DllStructGetData($item, 'ID') == 0 Then ContinueLoop
			If Not (IsWeapon($item) Or IsArmorSalvageItem($item)) Then ContinueLoop
			Local $reason = ''
			If IsProtectedByStoreItems($item, $inventory_management_cache, $reason) Then ContinueLoop
			Local $log = ''
			If IsMap(FindCheckedUpgradeOnItem($item, $extract_guard_definitions, $log)) Then $count += 1
		Next
	Next
	Return $count
EndFunc


;~ v22: checked definitions for the mid-run guard, re-read at most every $EXTRACT_GUARD_REFRESH_MS (reading the treeview is slow)
Func GetExtractGuardDefinitionsCached()
	Local Static $cached = Null, $timer = Null
	If $timer == Null Or TimerDiff($timer) > $EXTRACT_GUARD_REFRESH_MS Then
		$cached = LoadExtractUpgradeDefinitions(True)
		$timer = TimerInit()
	EndIf
	Return $cached
EndFunc


;~ Reads the checked leaves of the Extract tree and resolves each one to an upgrade definition.
;~ Returns an array of definition maps (empty array = nothing to do, already logged). v22: $quiet = no Info/Warn (mid-run guard)
Func LoadExtractUpgradeDefinitions($quiet = False)
	Local $none[0]
	Local $source = ''
	Local $root = $EXTRACT_TREE_ROOT
	Local $branchSize = 0
	Local $checkedLeaves = GetCheckedUpgradeLeaves($root, $source, $branchSize)
	; v37: if the loaded cache still has the pre-v35 name and was not migrated, use those ticks
	If UBound($checkedLeaves) == 0 Then
		Local $legacySize = 0
		Local $legacyLeaves = GetCheckedUpgradeLeaves($EXTRACT_TREE_ROOT_LEGACY, $source, $legacySize)
		If UBound($legacyLeaves) > 0 Then
			$root = $EXTRACT_TREE_ROOT_LEGACY
			$checkedLeaves = $legacyLeaves
			$branchSize = $legacySize
		EndIf
	EndIf
	; v29: no 'Keep components' fallback any more - a configuration without the branch simply has nothing checked
	If UBound($checkedLeaves) == 0 Then
		If Not $quiet Then Warn('[Extract] Nothing is checked under "' & $root & '" (Inventory tab) - check the runes/insignias/mods/inscriptions to extract. Stopping.')
		Return $none
	EndIf
	Local $definitions[UBound($checkedLeaves)]
	Local $count = 0
	For $leaf In $checkedLeaves
		Local $relativePath = StringTrimLeft($leaf, StringLen($root) + 1)
		; v12: only perfect options (max roll / Superior rune) are extracted
		If Not IsPerfectUpgradeOption($relativePath) Then
			If Not $quiet Then Warn('[Extract] Checked option "' & $leaf & '" is not a perfect (max roll / Superior) upgrade - ignored')
			ContinueLoop
		EndIf
		Local $definition = ResolveUpgradeLeafDefinition($relativePath)
		If Not IsMap($definition) Then
			If Not $quiet Then Warn('[Extract] Checked option "' & $leaf & '" has no upgrade definition - ignored')
			ContinueLoop
		EndIf
		$definitions[$count] = $definition
		$count += 1
	Next
	ReDim $definitions[$count]
	If $count == 0 Then
		If Not $quiet Then Warn('[Extract] None of the checked options could be mapped to an upgrade - stopping')
		Return $none
	EndIf
	If Not $quiet Then Info('[Extract] ' & $count & ' checked upgrade(s) read from ' & $source & ' under "' & $root & '"')
	Return $definitions
EndFunc


;~ v37.2 / v38.2: drop the cached GetCheckedUpgradeLeaves walk and the store-protection map
;~ so the next read is live again (Load / Apply / a tree tick change / Start).
;~ Looped town passes no longer call this.
Func InvalidateExtractLeavesCache()
	$extract_states_cache_valid = False
	Local $emptyStates[]
	Local $emptyLeaves[]
	Local $emptySizes[]
	$extract_states_cache = $emptyStates
	$extract_leaves_cache = $emptyLeaves
	$extract_branchsize_cache = $emptySizes
	$extract_states_cache_source = ''
	$store_protection_cache_valid = False
	Local $emptyStore[]
	$store_protection_cache = $emptyStore
	$store_protection_cache_source = ''
EndFunc


;~ Checked leaves under a root, read live from the Inventory treeview when the GUI exists, else from the loaded configuration.
;~ $branchSize = number of leaves (checked or not) found under the root (0 = branch missing)
;~ v37.2 / v38.2: the Inventory tree walk is cached until Load / Apply / a tree checkbox change / Start.
;~ v38.2: leaf detection is one pass over the branch keys (parent-prefix has-child map) instead of O(n^2).
Func GetCheckedUpgradeLeaves($root, ByRef $source, ByRef $branchSize)
	If $extract_states_cache_valid And MapExists($extract_leaves_cache, $root) Then
		$source = $extract_states_cache_source
		$branchSize = $extract_branchsize_cache[$root]
		Return $extract_leaves_cache[$root]
	EndIf
	If Not $extract_states_cache_valid Then
		Local $fresh[]
		If $gui_treeview_lootoptions Then
			IterateOverTreeView($fresh, $gui_treeview_lootoptions, Null, '', AddLeafStateToMap)
			$extract_states_cache_source = 'the Inventory tab (live)'
		Else
			For $key In MapKeys($inventory_management_cache)
				$fresh[$key] = $inventory_management_cache[$key]
			Next
			$extract_states_cache_source = 'the loaded loot configuration'
		EndIf
		$extract_states_cache = $fresh
		$extract_states_cache_valid = True
		Local $emptyLeaves[]
		Local $emptySizes[]
		$extract_leaves_cache = $emptyLeaves
		$extract_branchsize_cache = $emptySizes
	EndIf
	$source = $extract_states_cache_source
	Local $states = $extract_states_cache
	Local $prefix = $root & '.'
	Local $allKeys = MapKeys($states)
	; keep only the keys of this branch (tree order preserved)
	Local $keys[UBound($allKeys)]
	Local $keyCount = 0
	For $key In $allKeys
		If StringLeft($key, StringLen($prefix)) <> $prefix Then ContinueLoop
		$keys[$keyCount] = $key
		$keyCount += 1
	Next
	ReDim $keys[$keyCount]
	; v38.2: one pass - a key is a parent if any other key in this branch uses it as a dotted prefix.
	; Leaves stay in the same $keys iteration order as the previous O(n^2) walk.
	; $branchSize still counts every leaf (checked or not); $leaves stays the checked subset.
	Local $hasChild[]
	For $key In $keys
		Local $dot = StringInStr($key, '.', 0, -1)
		If $dot > 0 Then $hasChild[StringLeft($key, $dot - 1)] = True
	Next
	Local $leaves[$keyCount]
	Local $leafCount = 0
	$branchSize = 0
	For $key In $keys
		If MapExists($hasChild, $key) Then ContinueLoop
		$branchSize += 1
		If $states[$key] == True Then
			$leaves[$leafCount] = $key
			$leafCount += 1
		EndIf
	Next
	ReDim $leaves[$leafCount]
	$extract_leaves_cache[$root] = $leaves
	$extract_branchsize_cache[$root] = $branchSize
	Return $leaves
EndFunc


;~ Treeview iteration callback: stores checked state of every node, keyed by its path (tree order preserved)
Func AddLeafStateToMap(ByRef $context, $treeViewHandle, $treeViewItem, $currentPath)
	$context[$currentPath] = _GUICtrlTreeView_GetChecked($treeViewHandle, $treeViewItem)
EndFunc


;~ Checks that the injected salvage command and the addresses it uses exist, so we never make the client call address 0
Func ExtractUpgradesPreflight()
	Local $labels[] = ['CommandSalvage', 'Salvage', 'SalvageGlobal']
	For $label In $labels
		If Not IsValidLabelAddress($label) Then
			Error('[Extract] Salvage address "' & $label & '" is not initialised (memory scan failed) - aborting to avoid a client crash')
			Return False
		EndIf
		Debug('[Extract] ' & $label & ' = ' & GetLabel($label))
	Next
	If GetSalvageSessionAddress() == 0 Then
		Error('[Extract] Salvage session pointer could not be read - aborting')
		Return False
	EndIf
	Return True
EndFunc


;~ Returns the first item (fresh read) carrying one of the checked upgrades, or Null. Matched definition returned in $matchedDefinition.
;~ Eligible: identified blue/purple/gold weapon/offhand/shield or armor salvageable, not equipped, not customized, not the kit, not already handled.
Func FindNextUpgradeExtractionCandidate(ByRef $skippedItems, $kitID, ByRef $definitions, ByRef $matchedDefinition, ByRef $priorityLog, ByRef $storeCache)
	; v38.9: fresh bulk read of each bag (read-only scan); the per-item checks are in IsUpgradeExtractionCandidate
	For $bagIndex = 1 To _Min(4, $bags_count)
		Local $bagItems = GetBagItems($bagIndex)
		For $slot = 1 To UBound($bagItems)
			Local $item = $bagItems[$slot - 1]
			If IsUpgradeExtractionCandidate($item, $bagIndex, $slot, $skippedItems, $kitID, $definitions, $matchedDefinition, $priorityLog, $storeCache) Then Return $item
		Next
	Next
	Return Null
EndFunc


;~ v38.9: the per-item checks of FindNextUpgradeExtractionCandidate, unchanged (also used on the tracked inventory)
Func IsUpgradeExtractionCandidate($item, $bagIndex, $slot, ByRef $skippedItems, $kitID, ByRef $definitions, ByRef $matchedDefinition, ByRef $priorityLog, ByRef $storeCache)
	Local $itemID = DllStructGetData($item, 'ID')
	If $itemID == 0 Or $itemID == $kitID Then Return False
	If $skippedItems[$itemID] == True Then Return False
	If Not (IsWeapon($item) Or IsArmorSalvageItem($item)) Then Return False
	; v8: Store items protection - checked before anything else, no salvage session ever started
	Local $storeReason = ''
	If IsProtectedByStoreItems($item, $storeCache, $storeReason) Then
		Info('[Extract] Item ' & $itemID & ' skipped: protected by Store items (' & $storeReason & ')')
		$skippedItems[$itemID] = True
		Return False
	EndIf
	If DllStructGetData($item, 'Equipped') <> 0 Then Return False
	If DllStructGetData($item, 'Customized') <> 0 Then Return False
	Local $rarity = GetRarity($item)
	If $rarity <> $RARITY_BLUE And $rarity <> $RARITY_PURPLE And $rarity <> $RARITY_GOLD Then Return False
	If Not IsIdentified($item) Then
		Debug('[Extract] Skipping unidentified item at ' & $bagIndex & ':' & $slot)
		$skippedItems[$itemID] = True
		Return False
	EndIf
	; v37.1: v27 old-school auto-keep (q9 inherent Energy +5; wand/focus q9-q10 HCT+HSR pair) is kept whole - never extracted
	If IsOSAutoKeepWeapon($item) Then
		Info('[Extract] Item ' & $itemID & ' skipped: old-school auto-keep')
		$skippedItems[$itemID] = True
		Return False
	EndIf
	Local $definition = FindCheckedUpgradeOnItem($item, $definitions, $priorityLog)
	If Not IsMap($definition) Then
		Debug('[Extract] Item at ' & $bagIndex & ':' & $slot & ' has none of the checked upgrades - skipped, no salvage started' & DescribeSlayingOnItem(GetModStructHex($item)))
		$skippedItems[$itemID] = True
		Return False
	EndIf
	$matchedDefinition = $definition
	Return True
EndFunc


;~ v38.9: FindNextUpgradeExtractionCandidate on the tracked inventory (same bags, same slot order, same checks)
Func InvTrackNextCandidate(ByRef $inv, ByRef $skippedItems, $kitID, ByRef $definitions, ByRef $matchedDefinition, ByRef $priorityLog, ByRef $storeCache)
	For $bagIndex = 1 To _Min(4, $bags_count)
		For $slot = 1 To $inv['n' & $bagIndex]
			Local $item = $inv['i' & $bagIndex & ':' & $slot]
			If IsUpgradeExtractionCandidate($item, $bagIndex, $slot, $skippedItems, $kitID, $definitions, $matchedDefinition, $priorityLog, $storeCache) Then Return $item
		Next
	Next
	Return Null
EndFunc


;~ Returns the checked upgrade definition to extract from the item, Null if none.
;~ Priority (v6): armor = rune before insignia; weapons/offhands/shields = inscription, then prefix mod, then suffix mod
;~ (tree order within the same kind). $priorityLog describes every checked upgrade found and which one won.
;~ Weapon mods must match the item's weapon type and be preceded by the upgrade marker ('30'), inscriptions by the inscription marker ('32')
Func FindCheckedUpgradeOnItem($item, ByRef $definitions, ByRef $priorityLog)
	$priorityLog = ''
	Local $hex = GetModStructHex($item)
	If $hex == '' Then Return Null
	Local $isArmor = IsArmorSalvageItem($item)
	Local $itemType = DllStructGetData($item, 'type')
	Local $armorPriority[] = ['rune', 'insignia']
	Local $weaponPriority[] = ['inscription', 'prefix', 'suffix']
	Local $kinds = $isArmor ? $armorPriority : $weaponPriority
	Local $chosen = Null
	Local $found = ''
	For $kind In $kinds
		For $definition In $definitions
			If $definition['kind'] <> $kind Then ContinueLoop
			If Not UpgradeDefinitionPresentOnItem($definition, $hex, $isArmor, $itemType) Then ContinueLoop
			$found &= ($found == '' ? '' : ', ') & $kind & ' "' & $definition['path'] & '"'
			If Not IsMap($chosen) Then $chosen = $definition
		Next
	Next
	If IsMap($chosen) Then
		$priorityLog = 'priority ' & ($isArmor ? 'rune > insignia' : 'inscription > prefix > suffix') & ' - checked upgrades found: ' & $found & ' -> chose ' & $chosen['kind']
	EndIf
	Return $chosen
EndFunc


;~ True if ONE upgrade definition is present on the item (type and marker rules included)
Func UpgradeDefinitionPresentOnItem($definition, $hex, $isArmor, $itemType)
	If $isArmor Then
		If Not $definition['armor'] Then Return False
		Return HasUpgradeStructInModStruct($hex, $definition['struct'])
	EndIf
	If $definition['armor'] Then Return False
	Local $types = $definition['types']
	Local $typeMatches = False
	For $type In $types
		If $type == $itemType Then
			$typeMatches = True
			ExitLoop
		EndIf
	Next
	If Not $typeMatches Then Return False
	Local $marker = ($definition['kind'] == 'inscription') ? $STRUCT_INSCRIPTION : $STRUCT_WEAPON_UPGRADE
	; v11: the group's upgrade id must be of the checked kind - a Hale staff head (prefix) no longer passes for a Wrapping of Fortitude (suffix)
	; v12: upgrades whose constant pins only the fixed part must also carry their max-roll effect (GetPerfectRollRequirements)
	Return HasUpgradeStructInModStruct($hex, $definition['struct'], $marker, $definition['kind'], $definition['requirements'])
EndFunc


;~ Salvage session slot for an upgrade kind (fixed, see $EXTRACT_COMPONENT_INDEX_MODE): prefix/insignia 0, suffix/rune 1, inscription 2.
;~ Returns -1 for an unknown kind (caller must not send SalvageMod then).
Func ComputeSalvageComponentIndex($kind)
	Switch $kind
		Case 'insignia', 'prefix'
			Return 0
		Case 'rune', 'suffix'
			Return 1
		Case 'inscription'
			Return 2
	EndSwitch
	Return -1
EndFunc


;~ ONE salvage session on ONE item for ONE component index, confirmed before returning. Cancels the session if nothing happened.
;~ Returns 'destroyed' (upgrade extracted, item gone), 'survived' (upgrade extracted or kit use consumed, item still there) or 'failed'
Func ExtractOneUpgradeFromItem($item, $kit, $componentIndex, $definition)
	Local $label = $definition['path']
	Local $itemID = DllStructGetData($item, 'ID')
	Local $itemModelID = DllStructGetData($item, 'ModelID')
	Local $itemType = DllStructGetData($item, 'type')
	Local $isArmor = IsArmorSalvageItem($item)
	Local $kitID = DllStructGetData($kit, 'ID')
	; Re-read item and kit right before the step - never trust a stale struct
	Local $currentItem = GetItemByItemID($itemID)
	If Not ExtractItemStillPresent($currentItem, $itemID, $itemModelID) Then
		Warn('[Extract] Item ' & $itemID & ' no longer in inventory - skipped')
		Return 'failed'
	EndIf
	Local $currentKit = GetItemByItemID($kitID)
	If DllStructGetData($currentKit, 'ID') <> $kitID Or DllStructGetData($currentKit, 'Bag') == 0 Then
		Warn('[Extract] Kit ' & $kitID & ' not available any more - skipped')
		Return 'failed'
	EndIf
	Local $kitValueBefore = DllStructGetData($currentKit, 'Value')

	Info('[Extract] Item ' & $itemID & ': step 1/3 start salvage with kit ' & $kitID & ' (value ' & $kitValueBefore & ')')
	If Not StartSalvageWithKit($currentItem, $currentKit) Then
		Warn('[Extract] Could not start salvage session - item skipped')
		Return 'failed'
	EndIf
	; wait for the client/server to open the session
	PingSleep(800)

	Info('[Extract] Item ' & $itemID & ': step 2/3 select component index ' & $componentIndex & ' (' & $label & ')')
	SalvageMod($componentIndex)

	Info('[Extract] Item ' & $itemID & ': step 3/3 waiting for confirmation')
	Local $outcome = WaitForUpgradeExtraction($itemID, $itemModelID, $itemType, $isArmor, $definition, $kitID, $kitValueBefore)
	Switch $outcome
		Case 'destroyed'
			Info('[Extract] Item ' & $itemID & ': extracted ' & $label & ' - item destroyed')
			PingSleep(500)
			Return 'destroyed'
		Case 'upgrade_gone'
			Info('[Extract] Item ' & $itemID & ': extracted ' & $label & ' - item kept')
			PingSleep(500)
			Return 'survived'
		Case 'kit_used'
			Warn('[Extract] Item ' & $itemID & ': kit use consumed but "' & $label & '" still on the item - another component may have been taken (salvage slot ' & $componentIndex & ')')
			PingSleep(500)
			Return 'survived'
	EndSwitch
	Warn('[Extract] Item ' & $itemID & ': extraction of ' & $label & ' not confirmed - cancelling session, item skipped')
	CancelSalvage()
	PingSleep(600)
	Return 'failed'
EndFunc


;~ Polls (ping-aware, bounded). Returns 'destroyed' (item gone), 'upgrade_gone' (item still there, chosen upgrade no longer in its modstruct),
;~ 'kit_used' (kit lost a use / was used up, chosen upgrade still detected) or '' (nothing happened before timeout)
Func WaitForUpgradeExtraction($itemID, $itemModelID, $itemType, $isArmor, $definition, $kitID, $kitValueBefore, $timeout = 3000)
	Local $timer = TimerInit()
	Local $limit = $timeout + 2 * GetPing()
	While TimerDiff($timer) < $limit
		Sleep(100)
		Local $currentItem = GetItemByItemID($itemID)
		If Not ExtractItemStillPresent($currentItem, $itemID, $itemModelID) Then Return 'destroyed'
		If Not UpgradeDefinitionPresentOnItem($definition, GetModStructHex($currentItem), $isArmor, $itemType) Then Return 'upgrade_gone'
		Local $currentKit = GetItemByItemID($kitID)
		If DllStructGetData($currentKit, 'ID') <> $kitID Or DllStructGetData($currentKit, 'Value') < $kitValueBefore Then
			; give the item update a moment to arrive before deciding
			PingSleep(300)
			$currentItem = GetItemByItemID($itemID)
			If Not ExtractItemStillPresent($currentItem, $itemID, $itemModelID) Then Return 'destroyed'
			If Not UpgradeDefinitionPresentOnItem($definition, GetModStructHex($currentItem), $isArmor, $itemType) Then Return 'upgrade_gone'
			Return 'kit_used'
		EndIf
	WEnd
	Return ''
EndFunc


;~ Comma-separated list of the checked upgrades still present on an item ('' if none or item missing)
Func DescribeCheckedUpgradesOnItem($item, ByRef $definitions)
	If Not IsDllStruct($item) Or DllStructGetData($item, 'ID') == 0 Then Return ''
	Local $hex = GetModStructHex($item)
	If $hex == '' Then Return ''
	Local $isArmor = IsArmorSalvageItem($item)
	Local $itemType = DllStructGetData($item, 'type')
	Local $list = ''
	For $definition In $definitions
		If UpgradeDefinitionPresentOnItem($definition, $hex, $isArmor, $itemType) Then $list &= ($list == '' ? '' : ', ') & $definition['kind'] & ' "' & $definition['path'] & '"'
	Next
	Return $list
EndFunc


Func ExtractItemStillPresent($item, $itemID, $itemModelID)
	If Not IsDllStruct($item) Then Return False
	If DllStructGetData($item, 'ID') <> $itemID Then Return False
	If DllStructGetData($item, 'ModelID') <> $itemModelID Then Return False
	If DllStructGetData($item, 'Bag') == 0 Then Return False
	Return True
EndFunc

#Region v38.9 tracked inventory for the extraction pass
;~ v38.9: the extraction pass keeps one model of bags 1-5 instead of re-scanning every slot for every item, and never acts
;~ on it without checking it against the game first:
;~  - start of the pass (and every fallback): full read of bags 1-5 (each bag's pointer array + every item struct);
;~  - right before each extraction: every bag's pointer array is read again and must equal the model (nothing moved,
;~    appeared or vanished), and the item's and the kit's slots are read again and must be byte-identical to the model;
;~  - after the game confirmed the extraction (existing WaitForUpgradeExtraction poll, no extra sleep): the pointer arrays
;~    are read again; ONLY the slots whose pointer changed + the item's slot + the kit's slot are re-read, and the change
;~    must add up: kit lost a use (or is gone), item gone (destroyed) or still in its slot (survived), exactly ONE new item
;~    (the upgrade) in a slot that was empty or held the destroyed item/used-up kit, no other slot touched;
;~  - anything else (not confirmed, kit/item not where expected, unknown destination, extra change, a read that fails)
;~    -> the whole model is thrown away and bags 1-5 are read again before the next decision.
;~ Model keys: 'n'&bag slots, 'a'&bag item array, 'p'&bag:slot pointer, 'i'&bag:slot item struct (0 = empty), 'at'&itemID
;~ bag:slot; counters 'full', 'targeted', 'fallbacks', 'reason'.
Global Const $INV_TRACK_LAST_BAG = 5

Func InvTrackLastBag()
	Return _Min($INV_TRACK_LAST_BAG, $bags_count)
EndFunc


;~ Fresh pointer array of one bag: [slots, itemArray, ptr1..ptrN]; [-1] if the bag or its array cannot be read
Func InvTrackReadPointers($bagIndex)
	Local $fail[] = [-1]
	Local $bag = GetBag($bagIndex)
	Local $none[] = [0, 0]
	If Not IsDllStruct($bag) Then Return $none
	Local $slots = DllStructGetData($bag, 'Slots')
	If $slots <= 0 Then Return $none
	If $slots > 1000 Then Return $fail
	Local $out[$slots + 2]
	$out[0] = $slots
	$out[1] = DllStructGetData($bag, 'ItemArray')
	Local $pointers = ReadBagItemPointers($bagIndex, $bag)
	If Not IsDllStruct($pointers) Then Return $fail
	For $slot = 1 To $slots
		$out[$slot + 1] = Number(DllStructGetData($pointers, 1, $slot))
	Next
	Return $out
EndFunc


;~ Fresh item struct at a pointer (0 for a null/unreadable pointer, as GetItemBySlot)
Func InvTrackReadItem($itemPtr)
	Return GetItemAtPtr($itemPtr)
EndFunc


Func InvTrackBytes($item)
	If Not IsDllStruct($item) Then Return ''
	Return DllStructGetData(DllStructCreate('byte[' & DllStructGetSize($item) & ']', DllStructGetPtr($item)), 1)
EndFunc


Func InvTrackSetSlot(ByRef $inv, $bagIndex, $slot, $itemPtr, $item)
	Local $key = $bagIndex & ':' & $slot
	Local $previous = $inv['i' & $key]
	If IsDllStruct($previous) Then
		Local $previousID = DllStructGetData($previous, 'ID')
		If MapExists($inv, 'at' & $previousID) And $inv['at' & $previousID] == $key Then MapRemove($inv, 'at' & $previousID)
	EndIf
	$inv['p' & $key] = $itemPtr
	$inv['i' & $key] = $item
	If IsDllStruct($item) And DllStructGetData($item, 'ID') <> 0 Then $inv['at' & DllStructGetData($item, 'ID')] = $key
EndFunc


;~ Full read of bags 1-5 (start of the pass, and the fallback). $reason is logged when it is a fallback.
Func InvTrackFull(ByRef $inv, $reason = '')
	Local $full = MapExists($inv, 'full') ? $inv['full'] : 0
	Local $targeted = MapExists($inv, 'targeted') ? $inv['targeted'] : 0
	Local $fallbacks = MapExists($inv, 'fallbacks') ? $inv['fallbacks'] : 0
	Local $fresh[]
	$inv = $fresh
	$inv['full'] = $full + 1
	$inv['targeted'] = $targeted
	$inv['fallbacks'] = $fallbacks
	$inv['reason'] = $reason
	If $reason <> '' Then
		$inv['fallbacks'] = $fallbacks + 1
		Info('[Extract] Inventory re-read (bags 1-' & InvTrackLastBag() & '): ' & $reason)
	EndIf
	For $bagIndex = 1 To InvTrackLastBag()
		Local $pointers = InvTrackReadPointers($bagIndex)
		If $pointers[0] < 0 Then
			; unreadable bag: slot by slot, exactly what the old scans read
			Local $bag = GetBag($bagIndex)
			Local $slots = IsDllStruct($bag) ? DllStructGetData($bag, 'Slots') : 0
			$inv['n' & $bagIndex] = $slots > 0 ? $slots : 0
			$inv['a' & $bagIndex] = -1
			For $slot = 1 To $inv['n' & $bagIndex]
				InvTrackSetSlot($inv, $bagIndex, $slot, -1, GetItemBySlot($bagIndex, $slot))
			Next
			ContinueLoop
		EndIf
		$inv['n' & $bagIndex] = $pointers[0]
		$inv['a' & $bagIndex] = $pointers[0] > 0 ? $pointers[1] : 0
		For $slot = 1 To $pointers[0]
			InvTrackSetSlot($inv, $bagIndex, $slot, $pointers[$slot + 1], InvTrackReadItem($pointers[$slot + 1]))
		Next
	Next
EndFunc


;~ '' when every bag's pointer array still equals the model, else the reason
Func InvTrackCheckPointers(ByRef $inv)
	For $bagIndex = 1 To InvTrackLastBag()
		Local $pointers = InvTrackReadPointers($bagIndex)
		If $pointers[0] < 0 Or $inv['a' & $bagIndex] == -1 Then Return 'bag ' & $bagIndex & ' could not be read in one piece'
		If $pointers[0] <> $inv['n' & $bagIndex] Then Return 'bag ' & $bagIndex & ' size changed'
		If $pointers[0] > 0 And $pointers[1] <> $inv['a' & $bagIndex] Then Return 'bag ' & $bagIndex & ' item array moved'
		For $slot = 1 To $pointers[0]
			If $pointers[$slot + 1] <> $inv['p' & $bagIndex & ':' & $slot] Then Return 'slot ' & $bagIndex & ':' & $slot & ' changed outside the pass'
		Next
	Next
	Return ''
EndFunc


;~ Right before an extraction: '' when nothing moved and the item's and kit's slots, read fresh, are identical to the model
Func InvTrackBeforeAction(ByRef $inv, $item, $kit)
	Local $reason = InvTrackCheckPointers($inv)
	If $reason <> '' Then Return $reason
	Local $pair[] = [$item, $kit]
	For $struct In $pair
		Local $id = DllStructGetData($struct, 'ID')
		If Not MapExists($inv, 'at' & $id) Then Return 'item ' & $id & ' is not in bags 1-' & InvTrackLastBag()
		Local $key = $inv['at' & $id]
		Local $fresh = InvTrackReadItem($inv['p' & $key])
		If Not IsDllStruct($fresh) Then Return 'item ' & $id & ' could not be read at ' & $key
		If InvTrackBytes($fresh) <> InvTrackBytes($inv['i' & $key]) Then Return 'item ' & $id & ' at ' & $key & ' changed'
		If InvTrackBytes($fresh) <> InvTrackBytes($struct) Then Return 'item ' & $id & ' differs from the one chosen'
	Next
	Return ''
EndFunc


;~ After an extraction: targeted re-read and the check that the change adds up. '' = model updated, else the reason
;~ (the caller then re-reads everything). $result: ExtractOneUpgradeFromItem's 'destroyed' / 'survived' / anything else.
Func InvTrackAfterAction(ByRef $inv, $itemID, $kitID, $result)
	If $result <> 'destroyed' And $result <> 'survived' Then Return 'extraction not confirmed (' & $result & ')'
	If Not MapExists($inv, 'at' & $itemID) Or Not MapExists($inv, 'at' & $kitID) Then Return 'item or kit missing from the model'
	Local $itemKey = $inv['at' & $itemID], $kitKey = $inv['at' & $kitID]
	Local $kitBefore = $inv['i' & $kitKey]
	Local $known[]
	For $bagIndex = 1 To InvTrackLastBag()
		For $slot = 1 To $inv['n' & $bagIndex]
			Local $was = $inv['i' & $bagIndex & ':' & $slot]
			If IsDllStruct($was) Then $known[DllStructGetData($was, 'ID')] = True
		Next
	Next
	; which slots changed: pointer arrays of every bag, fresh
	Local $touched[]
	For $bagIndex = 1 To InvTrackLastBag()
		Local $pointers = InvTrackReadPointers($bagIndex)
		If $pointers[0] < 0 Or $pointers[0] <> $inv['n' & $bagIndex] Or ($pointers[0] > 0 And $pointers[1] <> $inv['a' & $bagIndex]) Then Return 'bag ' & $bagIndex & ' changed shape'
		For $slot = 1 To $pointers[0]
			If $pointers[$slot + 1] <> $inv['p' & $bagIndex & ':' & $slot] Then $touched[$bagIndex & ':' & $slot] = $pointers[$slot + 1]
		Next
	Next
	; the item's and the kit's slots are always re-read (same pointer, new contents)
	If Not MapExists($touched, $itemKey) Then $touched[$itemKey] = $inv['p' & $itemKey]
	If Not MapExists($touched, $kitKey) Then $touched[$kitKey] = $inv['p' & $kitKey]
	Local $newItems = 0, $itemSeen = False, $kitSeen = False
	For $key In MapKeys($touched)
		Local $fresh = InvTrackReadItem($touched[$key])
		Local $freshID = IsDllStruct($fresh) ? DllStructGetData($fresh, 'ID') : 0
		Local $wasItem = $inv['i' & $key]
		Local $wasID = IsDllStruct($wasItem) ? DllStructGetData($wasItem, 'ID') : 0
		If $freshID == $itemID Then
			If $key <> $itemKey Then Return 'item ' & $itemID & ' moved to ' & $key
			$itemSeen = True
		ElseIf $freshID == $kitID Then
			If $key <> $kitKey Then Return 'kit ' & $kitID & ' moved to ' & $key
			If DllStructGetData($fresh, 'Value') >= DllStructGetData($kitBefore, 'Value') Then Return 'kit ' & $kitID & ' did not lose a use'
			$kitSeen = True
		ElseIf $freshID <> 0 Then
			If $known[$freshID] Then Return 'item ' & $freshID & ' appeared at ' & $key
			$newItems += 1
		EndIf
		; a slot that held something else than the item or the kit must not change
		If $wasID <> 0 And $wasID <> $itemID And $wasID <> $kitID And $wasID <> $freshID Then Return 'slot ' & $key & ' changed unexpectedly'
	Next
	If $result == 'survived' And Not $itemSeen Then Return 'item ' & $itemID & ' should still be at ' & $itemKey
	If $result == 'destroyed' And $itemSeen Then Return 'item ' & $itemID & ' should be gone'
	If $newItems <> 1 Then Return $newItems & ' new item(s) instead of the one extracted upgrade'
	; all checks passed: store the fresh reads of exactly those slots
	For $key In MapKeys($touched)
		Local $parts = StringSplit($key, ':', 2)
		InvTrackSetSlot($inv, Number($parts[0]), Number($parts[1]), $touched[$key], InvTrackReadItem($touched[$key]))
	Next
	$inv['targeted'] = $inv['targeted'] + 1
	Return ''
EndFunc


;~ FindKit on the tracked inventory: same bags (1-5), same order, same fewest-uses rule (shared with FindKit)
Func InvTrackFindKit(ByRef $inv, $enabledModelIDs)
	Local $kit = Null
	Local $uses = 101
	For $bagIndex = 1 To InvTrackLastBag()
		For $slot = 1 To $inv['n' & $bagIndex]
			Local $item = $inv['i' & $bagIndex & ':' & $slot]
			Local $modelID = DllStructGetData($item, 'ModelID')
			If Not FindKitArrayContainsHelper($enabledModelIDs, $modelID) Then ContinueLoop
			Local $kitUses = KitUsesForFindKit($modelID, DllStructGetData($item, 'Value'))
			If $kitUses < $uses Then
				$uses = $kitUses
				$kit = $item
			EndIf
		Next
	Next
	Return $kit
EndFunc
#EndRegion v38.9 tracked inventory for the extraction pass

#EndRegion Extract upgrades


Func IsExtractUpgradesOnly()
	Return MapExists($run_options_cache, 'run.extract_upgrades_only') And $run_options_cache['run.extract_upgrades_only']
EndFunc
