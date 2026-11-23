#include '../LoadWaitHelpers.au3'
#include-once
#include '../../lib/GWA2_ID_Items.au3'
#include '../../lib/GWA2.au3'
#include '../../lib/Utils-Storage.au3'
#include '../../lib/Utils-Console.au3'
#include '../../lib/Utils.au3'

; v4 rewrite - Tools tab: Ecto -> Gold and Gold -> Lockpicks
; Both tools are strictly sequential: ONE request, wait for the game, confirm, then the next one.
; They no longer depend on $runtime_status (that was 'UNINITIALIZED'/'INITIALIZED' when used from the Tools tab,
; so the old loops never executed a single iteration).

Global Const $TOOLS_CHARACTER_GOLD_MAX = 100000
Global Const $TOOLS_STORAGE_GOLD_MAX = 1000000
Global Const $TOOLS_LOCKPICK_PRICE = 1500
Global Const $TOOLS_LOCKPICK_MERCHANT_POSITION_EOTN = 11
Global Const $TOOLS_MAX_STACK = 250
; v9: lockpicks bought per merchant buy call (one BuyItem of up to this many per step)
Global Const $LOCKPICK_BUY_BATCH = 80
; v38.5: Factions alliance-owned town merchants sell lockpicks at 1200g (20% off the normal 1500g)
Global Const $TOOLS_LOCKPICK_PRICE_FACTION = 1200
; Tests may set this to 0 so an unconfirmed buy does not wait 4s
Global $tools_lockpick_confirm_ms = 4000
; Tests may set this to 0 so a missing lockpick does not wait 3s
Global $tools_merchant_wait_ms = 3000
; Last NPC Talked to by ToolsOpenNPC (agent ID and agent ModelID)
Global $tools_last_npc_id = 0
Global $tools_last_npc_model = 0
; Set by ToolsScanMerchantForLockpick: the list position's model and item Value (0 if unknown)
Global $tools_lockpick_found_model = $ID_LOCKPICK
Global $tools_lockpick_found_value = 0


#Region Shared helpers
;~ Walks to and talks to an NPC of the given type ('Merchant' / 'Rare material trader').
;~ In Eye of the North / Embark Beach the known coordinates are used, elsewhere the nearest NPC.
Func ToolsOpenNPC($npcType, $travelToEotN = False)
	If $travelToEotN Then
		Info('[Tools] Travelling to Eye of the North to find the ' & $npcType)
		TravelToOutpost($ID_EYE_OF_THE_NORTH, $district_name)
		PingSleep(1000)
	EndIf
	Local $mapID = GetMapID()
	Local $npc = Null
	If $mapID == $ID_EYE_OF_THE_NORTH Or $mapID == $ID_EMBARK_BEACH Then
		If $mapID == $ID_EMBARK_BEACH Then MoveTo(1950, 0)
		Local $npcCoordinates = NPCCoordinatesInTown($mapID, $npcType)
		MoveTo($npcCoordinates[0], $npcCoordinates[1])
		$npc = GetNearestNPCToCoords($npcCoordinates[0], $npcCoordinates[1])
	Else
		$npc = GetNearestNPCToAgent(GetMyAgent())
	EndIf
	If Not IsDllStruct($npc) Or DllStructGetData($npc, 'ID') == 0 Then
		Warn('[Tools] No NPC found nearby - stand next to a ' & $npcType)
		Return False
	EndIf
	$tools_last_npc_id = DllStructGetData($npc, 'ID')
	$tools_last_npc_model = DllStructGetData($npc, 'ModelID')
	Info('[Tools] Talking to NPC ' & $tools_last_npc_id & ' (model ' & $tools_last_npc_model & ', expected: ' & $npcType & ')')
	GoToNPC($npc)
	PingSleep(750)
	Return True
EndFunc


;~ Moves character gold to storage, waits for confirmation. Returns False if storage is full or nothing moved.
Func ToolsDepositGold()
	Local $characterGold = GetGoldCharacter()
	Local $room = $TOOLS_STORAGE_GOLD_MAX - GetGoldStorage()
	If $room <= 0 Or $characterGold <= 0 Then Return False
	Local $amount = _Min($characterGold, $room)
	Info('[Tools] Depositing ' & $amount & ' gold to storage')
	DepositGold($amount)
	Local $timer = TimerInit()
	While TimerDiff($timer) < 3000 + GetPing()
		Sleep(100)
		If GetGoldCharacter() < $characterGold Then
			PingSleep(200)
			Return True
		EndIf
	WEnd
	Warn('[Tools] Gold deposit was not confirmed')
	Return False
EndFunc


;~ Moves storage gold to character (up to the 100k cap), waits for confirmation.
Func ToolsWithdrawGold()
	Local $characterGold = GetGoldCharacter()
	Local $storageGold = GetGoldStorage()
	Local $amount = _Min($storageGold, $TOOLS_CHARACTER_GOLD_MAX - $characterGold)
	If $amount <= 0 Then Return False
	Info('[Tools] Withdrawing ' & $amount & ' gold from storage')
	WithdrawGold($amount)
	Local $timer = TimerInit()
	While TimerDiff($timer) < 3000 + GetPing()
		Sleep(100)
		If GetGoldCharacter() > $characterGold Then
			PingSleep(200)
			Return True
		EndIf
	WEnd
	Warn('[Tools] Gold withdrawal was not confirmed')
	Return False
EndFunc


;~ Polls until the inventory count of a model changes in the expected direction
Func ToolsWaitForItemCountChange($modelID, $countBefore, $expectIncrease, $timeout = 3000)
	Local $timer = TimerInit()
	Local $limit = $timeout + 2 * GetPing()
	While TimerDiff($timer) < $limit
		Sleep(100)
		Local $count = GetInventoryItemCount($modelID)
		If $expectIncrease And $count > $countBefore Then Return True
		If Not $expectIncrease And $count < $countBefore Then Return True
	WEnd
	Return False
EndFunc


Func GetInventoryGold()
	; Character-carried gold (GWA2 API)
	Return GetGoldCharacter()
EndFunc


Func GetStorageGold()
	Return GetGoldStorage()
EndFunc
#EndRegion Shared helpers


#Region Ecto to gold
;~ Ecto to Gold: sells Globs of Ectoplasm ONE at a time to the rare material trader.
;~ quote -> wait -> sell -> confirm (ecto count dropped / gold rose) -> next. Deposits gold before the 100k cap.
Func ConvertEctosToGold()
	Info('[Ecto] Starting ecto to gold conversion (one ecto at a time)')
	If Not IsValidLabelAddress('CommandRequestQuoteSell') Or Not IsValidLabelAddress('CommandTraderSell') Then
		Error('[Ecto] Trader commands are not initialised (memory scan failed) - aborting')
		Return $FAIL
	EndIf
	If GetInventoryItemCount($ID_GLOB_OF_ECTOPLASM) < 1 Then
		Info('[Ecto] No Glob of Ectoplasm in inventory')
		Return $SUCCESS
	EndIf
	ToolsOpenNPC('Rare material trader')
	Local $sold = 0, $deposits = 0, $failures = 0, $goldEarned = 0
	Local $travelled = False
	For $iteration = 1 To 5000
		Local $ectoSlot = FindInInventory($ID_GLOB_OF_ECTOPLASM)
		If $ectoSlot[0] == 0 Then
			Info('[Ecto] No more ectos in inventory')
			ExitLoop
		EndIf
		Local $item = GetItemBySlot($ectoSlot[0], $ectoSlot[1])
		If Not IsDllStruct($item) Or DllStructGetData($item, 'ID') == 0 Then ExitLoop
		Local $ectoCountBefore = GetInventoryItemCount($ID_GLOB_OF_ECTOPLASM)
		Local $goldBefore = GetGoldCharacter()

		; 1 - ONE quote for ONE ecto
		Local $quote = TraderRequestSell($item)
		If $quote <= 0 Then
			$failures += 1
			Warn('[Ecto] No sell quote from trader (attempt ' & $failures & '/3)')
			If $failures >= 3 Then
				If Not $travelled Then
					$travelled = True
					$failures = 0
					ToolsOpenNPC('Rare material trader', True)
					ContinueLoop
				EndIf
				Error('[Ecto] Trader does not answer - stand next to a Rare Material Trader and try again')
				ExitLoop
			EndIf
			ToolsOpenNPC('Rare material trader')
			ContinueLoop
		EndIf

		; 2 - respect 100k carried gold cap: deposit first, then re-quote
		If $goldBefore + $quote > $TOOLS_CHARACTER_GOLD_MAX Then
			If Not ToolsDepositGold() Then
				Warn('[Ecto] Character gold near 100k and storage is full (1,000,000) - stopping')
				ExitLoop
			EndIf
			$deposits += 1
			ContinueLoop
		EndIf

		; 3 - ONE sell
		Debug('[Ecto] Quote ' & $quote & ' gold, selling 1 ecto')
		If Not TraderSell() Then
			$failures += 1
			Warn('[Ecto] Sell command refused (attempt ' & $failures & '/3)')
			If $failures >= 3 Then ExitLoop
			ContinueLoop
		EndIf

		; 4 - confirm before the next one
		If Not ToolsWaitForItemCountChange($ID_GLOB_OF_ECTOPLASM, $ectoCountBefore, False) And GetGoldCharacter() <= $goldBefore Then
			$failures += 1
			Warn('[Ecto] Sale not confirmed (attempt ' & $failures & '/3)')
			If $failures >= 3 Then ExitLoop
			ToolsOpenNPC('Rare material trader')
			ContinueLoop
		EndIf
		$failures = 0
		$sold += 1
		$goldEarned += GetGoldCharacter() - $goldBefore
		Info('[Ecto] Sold ecto #' & $sold & ' for ' & $quote & ' gold')
		PingSleep(300)
	Next
	Info('[Ecto] Done. Sold ' & $sold & ' ectos (~' & $goldEarned & ' gold), deposited ' & $deposits & ' times.')
	Return $SUCCESS
EndFunc
#EndRegion Ecto to gold


#Region Gold to lockpicks
;~ v38.5: 1500g is the normal merchant price; 1200g is the Factions alliance-discount price.
;~ GWA2 has no merchant-buy-price API. Item Value is trusted only when it is exactly 1200 or 1500.
Func ToolsTrustedMerchantValue($value)
	If $value == $TOOLS_LOCKPICK_PRICE Then Return $TOOLS_LOCKPICK_PRICE
	If $value == $TOOLS_LOCKPICK_PRICE_FACTION Then Return $TOOLS_LOCKPICK_PRICE_FACTION
	Return 0
EndFunc


;~ The only lockpick model in this repo / GWA2 is $ID_LOCKPICK (22751)
Func ToolsIsLockpickModel($modelID)
	Return $modelID == $ID_LOCKPICK
EndFunc


;~ Exact name "Lockpick" (trimmed, case-insensitive). Used only when model 22751 is not in the list.
Func ToolsIsLockpickName($name)
	If Not IsString($name) Then Return False
	Return StringLower(StringStripWS($name, 3)) == 'lockpick'
EndFunc


;~ How many lockpicks to buy in one transaction: never more than the batch, the request, or what carried gold covers.
Func ToolsLockpickBuyQuantity($wanted, $gold, $price)
	If $wanted < 1 Or $gold < 1 Or $price < 1 Then Return 0
	Local $quantity = _Min($wanted, Floor($gold / $price))
	If $quantity < 1 Then Return 0
	If $quantity * $price > $gold Then Return 0
	Return $quantity
EndFunc


;~ Price to attempt: a remembered price if we have one; otherwise 1500 when gold covers it, else 1200.
;~ $alreadyTried1500 is True after a 1500g buy on this merchant was not confirmed.
Func ToolsLockpickPriceToTry($knownPrice, $alreadyTried1500, $gold)
	If $knownPrice > 0 Then
		If $gold >= $knownPrice Then Return $knownPrice
		Return 0
	EndIf
	If Not $alreadyTried1500 And $gold >= $TOOLS_LOCKPICK_PRICE Then Return $TOOLS_LOCKPICK_PRICE
	If $gold >= $TOOLS_LOCKPICK_PRICE_FACTION Then Return $TOOLS_LOCKPICK_PRICE_FACTION
	Return 0
EndFunc


;~ The other candidate unit price (1500 <-> 1200), or 0
Func ToolsOtherLockpickPrice($price)
	If $price == $TOOLS_LOCKPICK_PRICE Then Return $TOOLS_LOCKPICK_PRICE_FACTION
	If $price == $TOOLS_LOCKPICK_PRICE_FACTION Then Return $TOOLS_LOCKPICK_PRICE
	Return 0
EndFunc


;~ One merchant-list slot: [modelID, value, name]. $decodeName is False on the cheap first pass.
Func ToolsMerchantItemAt($position, $decodeName = False)
	Local $result[3]
	$result[0] = 0
	$result[1] = 0
	$result[2] = ''
	Local $merchantBaseAddress = GetMerchantItemsBase()
	Local $merchantSize = GetMerchantItemsSize()
	If Not $merchantBaseAddress Or $position < 1 Or $position > $merchantSize Then Return $result
	Local $processHandle = GetProcessHandle()
	Local $itemID = MemoryRead($processHandle, $merchantBaseAddress + 4 * ($position - 1))
	If Not $itemID Then Return $result
	Local $offsets[5] = [0, 0x18, 0x40, 0xB8, 0]
	$offsets[4] = 4 * $itemID
	Local $itemPtr = MemoryReadPtr($processHandle, $base_address_ptr, $offsets)[1]
	If Not $itemPtr Then Return $result
	$result[0] = MemoryRead($processHandle, $itemPtr + 0x2C)
	$result[1] = MemoryRead($processHandle, $itemPtr + 0x24, 'short')
	If $decodeName Then
		Local $nameEnc = MemoryRead($processHandle, $itemPtr + 0x34)
		If $nameEnc Then $result[2] = DecodeEncStringAsync($nameEnc)
	EndIf
	Return $result
EndFunc


;~ Walk the open merchant list. Prefer model 22751; if it is absent, log every model ID and
;~ fall back to an item whose decoded name is exactly "Lockpick". Returns the 1-based position, or 0.
Func ToolsScanMerchantForLockpick()
	$tools_lockpick_found_model = $ID_LOCKPICK
	$tools_lockpick_found_value = 0
	Local $merchantSize = GetMerchantItemsSize()
	If $merchantSize < 1 Then Return 0
	Local $list = ''
	Local $modelPos = 0
	Local $i, $item
	For $i = 1 To $merchantSize
		$item = ToolsMerchantItemAt($i, False)
		If $list <> '' Then $list &= ', '
		$list &= $i & ':' & $item[0]
		If $item[1] > 0 Then $list &= '@' & $item[1]
		If ToolsIsLockpickModel($item[0]) And $modelPos == 0 Then
			$modelPos = $i
			$tools_lockpick_found_model = $item[0]
			$tools_lockpick_found_value = $item[1]
		EndIf
	Next
	Info('[Lockpicks] Merchant list (' & $merchantSize & ' items, NPC ' & $tools_last_npc_id & ' model ' & $tools_last_npc_model & '): ' & $list)
	If $modelPos > 0 Then
		Info('[Lockpicks] Lockpick model ' & $tools_lockpick_found_model & ' at position ' & $modelPos & ', item value ' & $tools_lockpick_found_value)
		Return $modelPos
	EndIf
	Info('[Lockpicks] Model ' & $ID_LOCKPICK & ' is not in this merchant list - scanning item names')
	Local $namePos = 0
	For $i = 1 To $merchantSize
		$item = ToolsMerchantItemAt($i, True)
		If $item[2] <> '' Then Info('[Lockpicks]   pos ' & $i & ' model ' & $item[0] & ' name "' & $item[2] & '" value ' & $item[1])
		If ToolsIsLockpickName($item[2]) And $namePos == 0 Then
			$namePos = $i
			$tools_lockpick_found_model = $item[0]
			$tools_lockpick_found_value = $item[1]
		EndIf
	Next
	If $namePos > 0 Then
		Warn('[Lockpicks] An item named Lockpick is at position ' & $namePos & ' with model ' & $tools_lockpick_found_model & ' (not ' & $ID_LOCKPICK & ') - buying that slot. Send this log if the model is wrong.')
		Return $namePos
	EndIf
	Return 0
EndFunc


;~ Waits for the merchant window/list to be loaded and returns the lockpick position (0 if absent)
Func ToolsWaitForLockpickInMerchant()
	Local $position = 0
	If GetMerchantItemsSize() > 0 Then
		$position = ToolsScanMerchantForLockpick()
		If $position > 0 Then Return $position
	EndIf
	Local $timer = TimerInit()
	Local $limit = $tools_merchant_wait_ms + GetPing()
	While TimerDiff($timer) < $limit
		Sleep(150)
		If GetMerchantItemsSize() > 0 Then
			$position = ToolsScanMerchantForLockpick()
			If $position > 0 Then Return $position
		EndIf
	WEnd
	Return $position
EndFunc


;~ Opens a merchant that sells lockpicks and returns the lockpick position in its list (0 if none)
Func ToolsOpenLockpickMerchant()
	$tools_lockpick_found_model = $ID_LOCKPICK
	$tools_lockpick_found_value = 0
	Local $position = 0
	If ToolsOpenNPC('Merchant') Then $position = ToolsWaitForLockpickInMerchant()
	If $position > 0 Then Return $position
	Info('[Lockpicks] Nearby NPC does not sell lockpicks - going to the Eye of the North merchant')
	If Not ToolsOpenNPC('Merchant', True) Then Return 0
	$position = ToolsWaitForLockpickInMerchant()
	If $position > 0 Then Return $position
	If GetMapID() == $ID_EYE_OF_THE_NORTH And GetMerchantItemsSize() >= $TOOLS_LOCKPICK_MERCHANT_POSITION_EOTN Then
		Warn('[Lockpicks] Lockpick not found by model or name in merchant list - using known EotN position ' & $TOOLS_LOCKPICK_MERCHANT_POSITION_EOTN)
		$tools_lockpick_found_model = $ID_LOCKPICK
		Return -$TOOLS_LOCKPICK_MERCHANT_POSITION_EOTN
	EndIf
	Return 0
EndFunc


;~ Waits for the merchant window/list to be loaded and returns position of the model in it (0 if absent)
Func ToolsWaitForMerchantItem($modelID)
	Local $timer = TimerInit()
	While TimerDiff($timer) < 3000 + GetPing()
		If GetMerchantItemsSize() > 0 Then
			Local $position = GetMerchantItemPositionByModelID($modelID)
			If $position > 0 Then Return $position
		EndIf
		Sleep(150)
	WEnd
	Return 0
EndFunc


;~ v9: how many lockpicks still fit in bags 1-4: 250 per free slot + the room left on existing lockpick stacks
Func ToolsLockpickRoom($modelID = $ID_LOCKPICK)
	Local $room = 0
	For $bagIndex = 1 To _Min(4, $bags_count)
		For $slot = 1 To DllStructGetData(GetBag($bagIndex), 'Slots')
			Local $item = GetItemBySlot($bagIndex, $slot)
			Local $slotModel = DllStructGetData($item, 'ModelID')
			If $slotModel == 0 Then
				$room += $TOOLS_MAX_STACK
			ElseIf $slotModel == $modelID And DllStructGetData($item, 'Quantity') < $TOOLS_MAX_STACK Then
				$room += $TOOLS_MAX_STACK - DllStructGetData($item, 'Quantity')
			EndIf
		Next
	Next
	Return $room
EndFunc


;~ True if a lockpick can be added: free slot, or an existing lockpick stack below 250
Func ToolsHasRoomForLockpick()
	Return ToolsLockpickRoom($tools_lockpick_found_model) > 0
EndFunc


;~ v9 / v38.5: waits until the lockpick count reaches $countBefore + $quantity (or timeout); returns how many actually arrived
Func ToolsWaitForLockpicksBought($countBefore, $quantity, $modelID = $ID_LOCKPICK)
	Local $count = GetInventoryItemCount($modelID)
	If $count >= $countBefore + $quantity Then Return $quantity
	Local $timer = TimerInit()
	Local $limit = $tools_lockpick_confirm_ms + 2 * GetPing()
	While TimerDiff($timer) < $limit
		Sleep(100)
		$count = GetInventoryItemCount($modelID)
		If $count >= $countBefore + $quantity Then ExitLoop
	WEnd
	; partial arrival: give the remaining stack update one more ping to land
	If $count > $countBefore And $count < $countBefore + $quantity Then
		If $tools_lockpick_confirm_ms > 0 Then PingSleep(300)
		$count = GetInventoryItemCount($modelID)
	EndIf
	Return _Max(0, $count - $countBefore)
EndFunc


;~ Gold to Lockpicks: buys lockpicks in multi-quantity transactions of up to $LOCKPICK_BUY_BATCH.
;~ v38.5: pays the price this merchant actually charges (1500 normal, 1200 Factions discount).
;~ If the first price is not confirmed, the same merchant is retried at the other price and that price is remembered.
;~ $requestedTotal = 0 means 'as many as funds/space allow'.
Func ConvertGoldToLockpicks($requestedTotal = 0)
	Info('[Lockpicks] Starting gold to lockpicks conversion (up to ' & $LOCKPICK_BUY_BATCH & ' lockpicks per purchase)')
	If Not IsValidLabelAddress('CommandBuyItem') Then
		Error('[Lockpicks] Buy command is not initialised (memory scan failed) - aborting')
		Return $FAIL
	EndIf
	Local $position = ToolsOpenLockpickMerchant()
	If $position == 0 Then
		Error('[Lockpicks] Could not open a merchant selling lockpicks - stand next to a merchant that sells them')
		Return $FAIL
	EndIf
	; negative position = unverified fallback position: stop at the first unconfirmed purchase
	Local $unverifiedPosition = $position < 0
	$position = Abs($position)
	Local $modelID = $tools_lockpick_found_model
	If $modelID == 0 Then $modelID = $ID_LOCKPICK
	Local $knownPrice = ToolsTrustedMerchantValue($tools_lockpick_found_value)
	If $knownPrice > 0 Then
		Info('[Lockpicks] Lockpick at merchant position ' & $position & ', model ' & $modelID & ', using item value ' & $knownPrice & 'g as the unit price (NPC ' & $tools_last_npc_id & ' model ' & $tools_last_npc_model & ')')
	Else
		Info('[Lockpicks] Lockpick at merchant position ' & $position & ', model ' & $modelID & ', price unknown (item value ' & $tools_lockpick_found_value & ') - will try ' & $TOOLS_LOCKPICK_PRICE & 'g then ' & $TOOLS_LOCKPICK_PRICE_FACTION & 'g if needed (NPC ' & $tools_last_npc_id & ' model ' & $tools_last_npc_model & ')')
	EndIf

	Local $bought = 0, $withdrawals = 0, $failures = 0, $purchases = 0, $batchNumber = 0
	For $iteration = 1 To 1000
		; ---- wanted quantity: batch, remaining requested total, inventory room ----
		Local $wanted = $LOCKPICK_BUY_BATCH
		If $requestedTotal > 0 Then $wanted = _Min($wanted, $requestedTotal - $bought)
		If $wanted <= 0 Then
			Info('[Lockpicks] Requested total of ' & $requestedTotal & ' reached')
			ExitLoop
		EndIf
		Local $room = ToolsLockpickRoom($modelID)
		If $room <= 0 Then
			Warn('[Lockpicks] Inventory full - stopping')
			ExitLoop
		EndIf
		$wanted = _Min($wanted, $room)

		; ---- gold: withdraw from storage if the batch is not covered at the price we expect to try ----
		Local $gold = GetGoldCharacter()
		Local $withdrawPrice = $knownPrice
		If $withdrawPrice < 1 Then $withdrawPrice = $TOOLS_LOCKPICK_PRICE
		If $gold < $wanted * $withdrawPrice And GetGoldStorage() > 0 And $gold < $TOOLS_CHARACTER_GOLD_MAX Then
			If ToolsWithdrawGold() Then
				$withdrawals += 1
			Else
				Warn('[Lockpicks] Could not withdraw gold from storage')
			EndIf
			$gold = GetGoldCharacter()
		EndIf

		; If we still cannot cover 1500 but can cover the discount price, try 1200
		Local $price = ToolsLockpickPriceToTry($knownPrice, False, $gold)
		If $price < 1 Then
			Info('[Lockpicks] No more funds in inventory or storage')
			ExitLoop
		EndIf
		Local $quantity = ToolsLockpickBuyQuantity($wanted, $gold, $price)
		If $quantity < 1 Then
			Info('[Lockpicks] No more funds in inventory or storage')
			ExitLoop
		EndIf
		Local $totalCost = $quantity * $price
		If $totalCost > $gold Then ExitLoop

		; ---- ONE multi-quantity transaction, then confirm. If the price is rejected, retry the other price. ----
		Local $countBefore = GetInventoryItemCount($modelID)
		Local $goldBefore = $gold
		$batchNumber += 1
		Info('[Lockpick] batch ' & $batchNumber & ': buying ' & $quantity & ' at ' & $price & 'g each (total ' & $totalCost & 'g, carried ' & $gold & 'g, position ' & $position & ', model ' & $modelID & ', NPC ' & $tools_last_npc_id & ')')
		BuyItem($position, $quantity, $price)
		Local $received = ToolsWaitForLockpicksBought($countBefore, $quantity, $modelID)
		Info('[Lockpick] batch ' & $batchNumber & ': ' & $price & 'g result bought ' & $received & '/' & $quantity)
		If $received <= 0 Then
			Local $otherPrice = ToolsOtherLockpickPrice($price)
			Local $otherQuantity = ToolsLockpickBuyQuantity($wanted, $gold, $otherPrice)
			If $otherPrice > 0 And $otherQuantity >= 1 Then
				Warn('[Lockpicks] ' & $price & 'g not confirmed - retrying the same merchant at ' & $otherPrice & 'g')
				$quantity = $otherQuantity
				$totalCost = $quantity * $otherPrice
				$price = $otherPrice
				Info('[Lockpick] batch ' & $batchNumber & ': buying ' & $quantity & ' at ' & $price & 'g each (total ' & $totalCost & 'g, carried ' & $gold & 'g, position ' & $position & ', model ' & $modelID & ', NPC ' & $tools_last_npc_id & ')')
				BuyItem($position, $quantity, $price)
				$received = ToolsWaitForLockpicksBought($countBefore, $quantity, $modelID)
				Info('[Lockpick] batch ' & $batchNumber & ': ' & $price & 'g result bought ' & $received & '/' & $quantity)
			EndIf
		EndIf
		If $received <= 0 Then
			$failures += 1
			Warn('[Lockpicks] Purchase of ' & $quantity & ' not confirmed at 1500g or 1200g (attempt ' & $failures & '/3)')
			If $unverifiedPosition Or $failures >= 3 Then ExitLoop
			$position = ToolsOpenLockpickMerchant()
			If $position == 0 Then ExitLoop
			$unverifiedPosition = $position < 0
			$position = Abs($position)
			$modelID = $tools_lockpick_found_model
			If $modelID == 0 Then $modelID = $ID_LOCKPICK
			$knownPrice = ToolsTrustedMerchantValue($tools_lockpick_found_value)
			ContinueLoop
		EndIf
		$unverifiedPosition = False
		$failures = 0
		$purchases += 1
		$bought += $received
		$knownPrice = $price
		If $received < $quantity Then
			Warn('[Lockpicks] Partial purchase: requested ' & $quantity & ' at ' & $price & 'g, received ' & $received & ' (gold ' & $goldBefore & ' -> ' & GetGoldCharacter() & ')')
		Else
			Info('[Lockpicks] Bought ' & $received & ' lockpicks at ' & $price & 'g each (total ' & $bought & ')')
		EndIf
		PingSleep(500)
	Next
	Info('[Lockpicks] Done. Bought ' & $bought & ' lockpicks in ' & $purchases & ' purchases, withdrew gold ' & $withdrawals & ' times.')
	Return $SUCCESS
EndFunc
#EndRegion Gold to lockpicks

