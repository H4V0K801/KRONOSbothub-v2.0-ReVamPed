#CS ===========================================================================
; v38: Xunlai storage sort planner and runner (Tools > Sorting Inventory).
; v38.6: sorting runs ONLY from a Sort now button (no town-pass / run-start auto sort). The planner is pure data so tests
; can run it against a mock world with no game client.
#CE ===========================================================================

#include-once
#include <Array.au3>
#include <FileConstants.au3>
#include <Math.au3>

Global Const $STORAGE_SORT_MATERIAL_BAG = 6
Global Const $STORAGE_SORT_PANE_NAMES[] = [ _
	'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', _
	'IX', 'X', 'XI', 'XII', 'XIII', 'Anniversary', 'Material storage']
; Checklist order is the grouping order inside a pane
Global Const $STORAGE_SORT_TYPES[] = [ _
	'Materials', 'Rare materials', 'Runes', 'Insignias', 'Mods', _
	'Inscriptions', 'Trophies', 'Tomes', 'Dyes', 'Festival items', _
	'Golds', 'Purples', 'Keys', 'Consumables', 'Salvage / ID kits', 'Minipets']

; Applied layout used by Sort now (manual only). Defaults: panes unticked, Material storage = Materials + Rare materials.
Global $storage_sort_busy = False
Global Const $STORAGE_MOVE_MIN_MS = 100
Global Const $STORAGE_MOVE_TIMEOUT_MS = 3000
Global $storage_move_last = 0, $storage_move_has_last = False, $storage_move_busy = False

Global $storage_sort_applied
Global $storage_sort_scanned = False
Global $storage_sort_unlocked[]
Global $storage_sort_lastscan = 'Last: not scanned yet'
Global $storage_sort_layout_name = ''

Func StorageSortInit()
	$storage_sort_applied = StorageSortDefaultSettings()
	$storage_sort_scanned = False
	Local $empty[]
	$storage_sort_unlocked = $empty
	$storage_sort_lastscan = 'Last: not scanned yet'
	$storage_sort_layout_name = ''
	Local $i
	For $i = 0 To 14
		$storage_sort_unlocked[$STORAGE_SORT_PANE_NAMES[$i]] = False
	Next
EndFunc

Func StorageSortDefaultSettings()
	Local $s[]
	$s['reserve_slots'] = 0
	Local $bags[0]
	$s['bags'] = $bags
	$s['order'] = 'By type'
	$s['merge_stacks'] = False
	$s['compact_slots'] = False
	$s['if_full'] = 'Next empty pane'
	$s['layout_name'] = ''
	Local $i, $none[0]
	For $i = 0 To 14
		$s['types_' & $STORAGE_SORT_PANE_NAMES[$i]] = $none
	Next
	StorageSortPresetMaterials($s)
	Return $s
EndFunc

; Xunlai material slots are model-specific, not a user-editable normal pane.
Func StorageSortPresetMaterials(ByRef $settings)
	Local $types[2] = ['Materials', 'Rare materials']
	$settings['types_Material storage'] = $types
EndFunc

Func StorageSortTypeIndex($typeName)
	Local $i
	For $i = 0 To UBound($STORAGE_SORT_TYPES) - 1
		If $STORAGE_SORT_TYPES[$i] == $typeName Then Return $i
	Next
	Return 99
EndFunc

Func StorageSortPaneBagIndex($paneName)
	If $paneName == 'Material storage' Then Return $STORAGE_SORT_MATERIAL_BAG
	Return StorageTabBagIndex($paneName)
EndFunc

Func StorageSortPaneNameForBag($bagIndex)
	If $bagIndex == $STORAGE_SORT_MATERIAL_BAG Then Return 'Material storage'
	Local $i
	For $i = 0 To 13
		If $STORAGE_TAB_FIRST_BAG + $i == $bagIndex Then Return $STORAGE_SORT_PANE_NAMES[$i]
	Next
	Return ''
EndFunc

Func StorageSortIsBag($bagIndex)
	Return $bagIndex >= 1 And $bagIndex <= 4
EndFunc

Func StorageSortIsMaterialOnly($typeName)
	Return $typeName == 'Materials' Or $typeName == 'Rare materials'
EndFunc

Func StorageSortIsReserveType($typeName)
	Return $typeName == 'Consumables' Or $typeName == 'Salvage / ID kits'
EndFunc

;~ True if this pane lists $typeName (ticked types are stored in checklist order)
Func StorageSortPaneHasType(ByRef $settings, $paneName, $typeName)
	If $typeName == '' Then Return False
	Local $types = $settings['types_' & $paneName]
	If Not IsArray($types) Then Return False
	Local $i
	For $i = 0 To UBound($types) - 1
		If $types[$i] == $typeName Then Return True
	Next
	Return False
EndFunc

;~ Assigned panes for a type, in list order, skipping locked panes
Func StorageSortPanesForType(ByRef $settings, ByRef $world, $typeName)
	Local $out[0], $i, $name
	For $i = 0 To 14
		$name = $STORAGE_SORT_PANE_NAMES[$i]
		If Not $world['unlocked'][$name] Then ContinueLoop
		If StorageSortPaneHasType($settings, $name, $typeName) Then
			ReDim $out[UBound($out) + 1]
			$out[UBound($out) - 1] = $name
		EndIf
	Next
	Return $out
EndFunc

#Region World helpers (mockable snapshot)
Func StorageSortWorldNew()
	Local $w[]
	Local $slots[]
	Local $unlocked[]
	$w['slots'] = $slots
	$w['unlocked'] = $unlocked
	Local $i, $name
	For $i = 1 To 21
		$w['slots'][$i] = 0
	Next
	For $i = 0 To 14
		$name = $STORAGE_SORT_PANE_NAMES[$i]
		$w['unlocked'][$name] = True
	Next
	Return $w
EndFunc

Func StorageSortKey($bag, $slot)
	Return $bag & ',' & $slot
EndFunc

Func StorageSortGetItem(ByRef $world, $bag, $slot)
	Local $k = StorageSortKey($bag, $slot)
	If MapExists($world, $k) Then Return $world[$k]
	Return 0
EndFunc

Func StorageSortSetItem(ByRef $world, $bag, $slot, $item)
	$world[StorageSortKey($bag, $slot)] = $item
	If IsMap($item) Then
		$item['bag'] = $bag
		$item['slot'] = $slot
		$world[StorageSortKey($bag, $slot)] = $item
	EndIf
EndFunc

Func StorageSortClearSlot(ByRef $world, $bag, $slot)
	Local $k = StorageSortKey($bag, $slot)
	If MapExists($world, $k) Then MapRemove($world, $k)
EndFunc

Func StorageSortItem($id, $typeName, $model = 0, $qty = 1, $stackable = False, $rarity = 0, $name = '', $dye = 0, $maxqty = 250)
	Local $it[]
	$it['id'] = $id
	$it['type'] = $typeName
	$it['model'] = $model
	$it['qty'] = $qty
	$it['maxqty'] = $maxqty
	$it['stackable'] = $stackable
	$it['rarity'] = $rarity
	$it['name'] = $name
	$it['dye'] = $dye
	$it['reserve_ok'] = StorageSortIsReserveType($typeName)
	$it['bag'] = 0
	$it['slot'] = 0
	Return $it
EndFunc

Func StorageSortPut(ByRef $world, $bag, $slot, $item)
	If $world['slots'][$bag] < $slot Then $world['slots'][$bag] = $slot
	$item['bag'] = $bag
	$item['slot'] = $slot
	StorageSortSetItem($world, $bag, $slot, $item)
EndFunc

Func StorageSortCountItems(ByRef $world)
	Local $n = 0, $bag, $slot, $it
	For $bag = 1 To 21
		For $slot = 1 To $world['slots'][$bag]
			$it = StorageSortGetItem($world, $bag, $slot)
			If IsMap($it) Then $n += 1
		Next
	Next
	Return $n
EndFunc

Func StorageSortFreeSlots(ByRef $world, $bag)
	Local $n = 0, $slot
	For $slot = 1 To $world['slots'][$bag]
		If Not IsMap(StorageSortGetItem($world, $bag, $slot)) Then $n += 1
	Next
	Return $n
EndFunc
#EndRegion

#Region Compare / grouping
;~ Sort key within a type group, according to the Order rule
Func StorageSortWithinTypeCmp($a, $b, $order)
	If $order == 'By rarity' Then
		; Higher rarity first (Gold before Purple, and so on)
		If $a['rarity'] <> $b['rarity'] Then Return $a['rarity'] > $b['rarity'] ? -1 : 1
	ElseIf $order == 'By name' Then
		Local $na = StringLower($a['name']), $nb = StringLower($b['name'])
		If $na <> $nb Then Return $na > $nb ? 1 : -1
	EndIf
	; By type, By model ID, and as a stable tie-breaker
	If $a['model'] <> $b['model'] Then Return $a['model'] > $b['model'] ? 1 : -1
	If $a['dye'] <> $b['dye'] Then Return $a['dye'] > $b['dye'] ? 1 : -1
	If $a['id'] <> $b['id'] Then Return $a['id'] > $b['id'] ? 1 : -1
	Return 0
EndFunc

;~ Desired item sequence for a pane: ticked types in checklist order, Order rule within each type
Func StorageSortDesiredPaneSequence(ByRef $items, ByRef $tickedTypes, $order)
	Local $out[0]
	If Not IsArray($items) Then Return $out
	Local $t, $i, $typeName, $group[0]
	For $t = 0 To UBound($tickedTypes) - 1
		$typeName = $tickedTypes[$t]
		Local $g[0]
		For $i = 0 To UBound($items) - 1
			Local $it = $items[$i]
			If $it['type'] == $typeName Then
				ReDim $g[UBound($g) + 1]
				$g[UBound($g) - 1] = $it
			EndIf
		Next
		StorageSortSortGroup($g, $order)
		For $i = 0 To UBound($g) - 1
			ReDim $out[UBound($out) + 1]
			$out[UBound($out) - 1] = $g[$i]
		Next
	Next
	; anything left (shouldn't happen after a correct evict) stays at the end, stable
	For $i = 0 To UBound($items) - 1
		Local $left = $items[$i]
		If StorageSortArrayHasId($out, $left['id']) Then ContinueLoop
		ReDim $out[UBound($out) + 1]
		$out[UBound($out) - 1] = $left
	Next
	Return $out
EndFunc

Func StorageSortArrayHasId(ByRef $arr, $id)
	Local $i
	For $i = 0 To UBound($arr) - 1
		Local $it = $arr[$i]
		If $it['id'] == $id Then Return True
	Next
	Return False
EndFunc

;~ Insertion sort so we don't depend on _ArraySort with a custom comparer
Func StorageSortSortGroup(ByRef $group, $order)
	Local $n = UBound($group), $i, $j, $tmp
	If $n < 2 Then Return
	For $i = 1 To $n - 1
		$tmp = $group[$i]
		$j = $i - 1
		While $j >= 0 And StorageSortWithinTypeCmp($group[$j], $tmp, $order) > 0
			$group[$j + 1] = $group[$j]
			$j -= 1
		WEnd
		$group[$j + 1] = $tmp
	Next
EndFunc

Func StorageSortPaneItems(ByRef $world, $bag)
	Local $items[0], $slot, $it
	For $slot = 1 To $world['slots'][$bag]
		$it = StorageSortGetItem($world, $bag, $slot)
		If IsMap($it) Then
			ReDim $items[UBound($items) + 1]
			$items[UBound($items) - 1] = $it
		EndIf
	Next
	Return $items
EndFunc

;~ True if the pane's occupied slots already match the desired grouped sequence (trailing empties ignored)
Func StorageSortPaneAlreadyInOrder(ByRef $world, $bag, ByRef $tickedTypes, $order)
	Local $items = StorageSortPaneItems($world, $bag)
	Local $desired = StorageSortDesiredPaneSequence($items, $tickedTypes, $order)
	If UBound($items) <> UBound($desired) Then Return False
	Local $i, $slot, $it
	$slot = 1
	For $i = 0 To UBound($desired) - 1
		$it = StorageSortGetItem($world, $bag, $slot)
		If Not IsMap($it) Then Return False
		Local $want = $desired[$i]
		If $it['id'] <> $want['id'] Then Return False
		$slot += 1
	Next
	; remaining slots must be empty (already packed)
	For $i = $slot To $world['slots'][$bag]
		If IsMap(StorageSortGetItem($world, $bag, $i)) Then Return False
	Next
	Return True
EndFunc
#EndRegion

#Region Planner
Func StorageSortPlanNew()
	Local $p[]
	Local $moves[0], $left[0], $logs[0]
	$p['moves'] = $moves
	$p['leftovers'] = $left
	$p['logs'] = $logs
	$p['stopped'] = False
	$p['stop_reason'] = ''
	$p['changed_panes'] = ''
	Return $p
EndFunc

Func StorageSortPlanAddMove(ByRef $plan, $fromBag, $fromSlot, $toBag, $toSlot, $id, $reason)
	Local $m[]
	$m['fromBag'] = $fromBag
	$m['fromSlot'] = $fromSlot
	$m['toBag'] = $toBag
	$m['toSlot'] = $toSlot
	$m['id'] = $id
	$m['reason'] = $reason
	Local $moves = $plan['moves']
	ReDim $moves[UBound($moves) + 1]
	$moves[UBound($moves) - 1] = $m
	$plan['moves'] = $moves
EndFunc

Func StorageSortPlanLog(ByRef $plan, $text)
	Local $logs = $plan['logs']
	ReDim $logs[UBound($logs) + 1]
	$logs[UBound($logs) - 1] = $text
	$plan['logs'] = $logs
EndFunc

Func StorageSortPlanAddLeftover(ByRef $plan, $item, $reason)
	Local $L[]
	$L['id'] = $item['id']
	$L['type'] = $item['type']
	$L['model'] = $item['model']
	$L['bag'] = $item['bag']
	$L['slot'] = $item['slot']
	$L['reason'] = $reason
	Local $arr = $plan['leftovers']
	ReDim $arr[UBound($arr) + 1]
	$arr[UBound($arr) - 1] = $L
	$plan['leftovers'] = $arr
EndFunc

;~ Simulate a move on $world and append it to $plan. Returns False if the destination is invalid.
Func StorageSortSimMove(ByRef $world, ByRef $plan, $fromBag, $fromSlot, $toBag, $toSlot, $reason, ByRef $moveCount, $maxMoves)
	Local $item = StorageSortGetItem($world, $fromBag, $fromSlot)
	If Not IsMap($item) Then Return False
	If $fromBag == $toBag And $fromSlot == $toSlot Then Return True
	If $moveCount >= $maxMoves Then
		$plan['stopped'] = True
		$plan['stop_reason'] = 'move limit reached (refusing to loop forever)'
		StorageSortPlanLog($plan, $plan['stop_reason'])
		Return False
	EndIf
	Local $dest = StorageSortGetItem($world, $toBag, $toSlot)
	Local $before = $item, $beforeDest = $dest
	If IsMap($dest) Then
		If ($toBag == $STORAGE_SORT_MATERIAL_BAG Or ($item['stackable'] And $dest['stackable'])) And $dest['model'] == $item['model'] And $dest['dye'] == $item['dye'] And $dest['qty'] < $dest['maxqty'] Then
			Local $room = $dest['maxqty'] - $dest['qty']
			Local $give = $item['qty']
			If $give > $room Then $give = $room
			$dest['qty'] += $give
			$item['qty'] -= $give
			StorageSortSetItem($world, $toBag, $toSlot, $dest)
			StorageSortPlanAddMove($plan, $fromBag, $fromSlot, $toBag, $toSlot, $item['id'], $reason)
			StorageSortMovePreconditions($plan, $before, $beforeDest, $give)
			$moveCount += 1
			If $item['qty'] <= 0 Then
				StorageSortClearSlot($world, $fromBag, $fromSlot)
			Else
				StorageSortSetItem($world, $fromBag, $fromSlot, $item)
			EndIf
			Return True
		EndIf
		Return False
	EndIf
	StorageSortClearSlot($world, $fromBag, $fromSlot)
	StorageSortSetItem($world, $toBag, $toSlot, $item)
	StorageSortPlanAddMove($plan, $fromBag, $fromSlot, $toBag, $toSlot, $item['id'], $reason)
	StorageSortMovePreconditions($plan, $before, $beforeDest, $before['qty'])
	$moveCount += 1
	Return True
EndFunc

Func StorageSortMovePreconditions(ByRef $plan, $item, $dest, $amount)
	Local $moves = $plan['moves'], $m = $moves[UBound($moves) - 1]
	$m['source_qty'] = $item['qty']
	$m['dest_id'] = IsMap($dest) ? $dest['id'] : 0
	$m['dest_qty'] = IsMap($dest) ? $dest['qty'] : 0
	$m['amount'] = $amount
	$moves[UBound($moves) - 1] = $m
	$plan['moves'] = $moves
EndFunc

;~ Find a stack of the same model+dye with room, else an empty slot, in $bag. $skipReserve applies reserved slots.
Func StorageSortFindPlaceInBag(ByRef $world, ByRef $settings, $bag, ByRef $item, $allowReserve)
	If $world['slots'][$bag] <= 0 Then Return 0
	Local $reserve = Number($settings['reserve_slots'])
	Local $slot, $dest, $start = 1
	If Not $allowReserve And $reserve > 0 Then $start = $reserve + 1
	If $settings['merge_stacks'] And $item['stackable'] Then
		For $slot = $start To $world['slots'][$bag]
			If (Not $allowReserve) And $slot <= $reserve Then ContinueLoop
			$dest = StorageSortGetItem($world, $bag, $slot)
			If IsMap($dest) And $dest['stackable'] And $dest['model'] == $item['model'] And $dest['dye'] == $item['dye'] And $dest['qty'] < $dest['maxqty'] Then Return $slot
		Next
	EndIf
	For $slot = 1 To $world['slots'][$bag]
		If (Not $allowReserve) And $slot <= $reserve Then ContinueLoop
		If Not IsMap(StorageSortGetItem($world, $bag, $slot)) Then Return $slot
	Next
	; reserve-ok items may also use reserved slots (kits / consumables)
	If $allowReserve Then
		For $slot = 1 To $world['slots'][$bag]
			If Not IsMap(StorageSortGetItem($world, $bag, $slot)) Then Return $slot
		Next
	EndIf
	Return 0
EndFunc

Func StorageSortBagsToSort(ByRef $settings)
	Local $bags = $settings['bags']
	If Not IsArray($bags) Then
		Local $empty[0]
		Return $empty
	EndIf
	Return $bags
EndFunc

;~ First bag destination for evict / leftover, respecting reserved slots and merge
Func StorageSortFindBagPlace(ByRef $world, ByRef $settings, ByRef $item)
	Local $bags = StorageSortBagsToSort($settings)
	Local $i, $bag, $slot
	Local $allow = $item['reserve_ok'] == True
	If $settings['merge_stacks'] And $item['stackable'] Then
		For $i = 0 To UBound($bags) - 1
			$bag = $bags[$i]
			$slot = StorageSortFindPlaceInBag($world, $settings, $bag, $item, $allow)
			If $slot > 0 Then
				Local $d = StorageSortGetItem($world, $bag, $slot)
				If IsMap($d) Then
					Local $p[2] = [$bag, $slot]
					Return $p
				EndIf
			EndIf
		Next
	EndIf
	For $i = 0 To UBound($bags) - 1
		$bag = $bags[$i]
		$slot = StorageSortFindPlaceInBag($world, $settings, $bag, $item, $allow)
		If $slot > 0 Then
			Local $p2[2] = [$bag, $slot]
			Return $p2
		EndIf
	Next
	Local $none[2] = [0, 0]
	Return $none
EndFunc

; Fixed Xunlai material slot from $MAP_MATERIAL_LOCATION (GWA2_ID_Items); -1 if that map is not loaded (unit tests)
Func StorageSortMaterialSlot($model)
	If Not IsDeclared('MAP_MATERIAL_LOCATION') Then Return -1
	Local $m = Eval('MAP_MATERIAL_LOCATION')
	If Not IsMap($m) Or Not MapExists($m, $model) Then Return 0
	Return Number($m[$model])
EndFunc

Func StorageSortFirstFree(ByRef $world, $bag)
	Local $slot
	For $slot = 1 To $world['slots'][$bag]
		If Not IsMap(StorageSortGetItem($world, $bag, $slot)) Then Return $slot
	Next
	Return 0
EndFunc

Func StorageSortFindSlotInPane(ByRef $world, $bag, ByRef $item, $merge)
	Local $slot, $dest
	If $bag == $STORAGE_SORT_MATERIAL_BAG Then
		If Not StorageSortIsMaterialOnly($item['type']) Then Return 0
		$slot = StorageSortMaterialSlot($item['model'])
		If $slot == -1 Then Return StorageSortFirstFree($world, $bag)
		If $slot < 1 Or $slot > $world['slots'][$bag] Then Return 0
		$dest = StorageSortGetItem($world, $bag, $slot)
		If Not IsMap($dest) Then Return $slot
		If $dest['model'] == $item['model'] And $dest['qty'] < $dest['maxqty'] Then Return $slot
		Return 0
	EndIf
	If $merge And $item['stackable'] Then
		For $slot = 1 To $world['slots'][$bag]
			$dest = StorageSortGetItem($world, $bag, $slot)
			If IsMap($dest) And $dest['stackable'] And $dest['model'] == $item['model'] And $dest['dye'] == $item['dye'] And $dest['qty'] < $dest['maxqty'] Then Return $slot
		Next
	EndIf
	For $slot = 1 To $world['slots'][$bag]
		If Not IsMap(StorageSortGetItem($world, $bag, $slot)) Then Return $slot
	Next
	Return 0
EndFunc

;~ Next unlocked pane after $fromIndex with at least one empty slot (Material storage only for materials)
Func StorageSortNextEmptyPane(ByRef $world, $fromIndex, $typeName)
	Local $i, $name, $bag
	For $i = $fromIndex + 1 To 14
		$name = $STORAGE_SORT_PANE_NAMES[$i]
		If Not $world['unlocked'][$name] Then ContinueLoop
		If $name == 'Material storage' And Not StorageSortIsMaterialOnly($typeName) Then ContinueLoop
		If $name <> 'Material storage' And StorageSortIsMaterialOnly($typeName) Then
			; materials may overflow into a regular pane if the user asked for next pane
		EndIf
		$bag = StorageSortPaneBagIndex($name)
		If $bag <= 0 Then ContinueLoop
		If StorageSortFreeSlots($world, $bag) > 0 Then Return $name
	Next
	Return ''
EndFunc

;~ A destination pane+slot for an item that belongs somewhere. $preferBags: evict path tries bags first.
Func StorageSortFindDest(ByRef $world, ByRef $settings, ByRef $item, $preferBags, $fromPaneIndex)
	If $preferBags Then
		Local $bp = StorageSortFindBagPlace($world, $settings, $item)
		If $bp[0] > 0 Then Return $bp
	EndIf
	Local $panes = StorageSortPanesForType($settings, $world, $item['type'])
	Local $i, $name, $bag, $slot, $merge
	$merge = $settings['merge_stacks'] == True
	For $i = 0 To UBound($panes) - 1
		$name = $panes[$i]
		If $name == 'Material storage' And Not StorageSortIsMaterialOnly($item['type']) Then ContinueLoop
		$bag = StorageSortPaneBagIndex($name)
		$slot = StorageSortFindSlotInPane($world, $bag, $item, $merge)
		If $slot > 0 Then
			Local $p[2] = [$bag, $slot]
			Return $p
		EndIf
	Next
	If $settings['if_full'] == 'Next empty pane' Then
		$name = StorageSortNextEmptyPane($world, $fromPaneIndex, $item['type'])
		If $name <> '' Then
			$bag = StorageSortPaneBagIndex($name)
			$slot = StorageSortFindSlotInPane($world, $bag, $item, $merge)
			If $slot > 0 Then
				Local $p2[2] = [$bag, $slot]
				Return $p2
			EndIf
		EndIf
	EndIf
	If Not $preferBags Then
		Local $bp2 = StorageSortFindBagPlace($world, $settings, $item)
		If $bp2[0] > 0 Then Return $bp2
	EndIf
	Local $none[2] = [0, 0]
	Return $none
EndFunc

;~ Re-group a pane in checklist order (Order rule within each type). No-op if already in order or empty.
;~ Always packs from slot 1 (groups are contiguous). Returns True if any move was made.
Func StorageSortRegroupPane(ByRef $world, ByRef $plan, ByRef $settings, $paneName, ByRef $moveCount, $maxMoves)
	Local $bag = StorageSortPaneBagIndex($paneName)
	If $bag <= 0 Or $bag == $STORAGE_SORT_MATERIAL_BAG Then Return False
	Local $ticked = $settings['types_' & $paneName]
	If Not IsArray($ticked) Then Return False
	If StorageSortPaneAlreadyInOrder($world, $bag, $ticked, $settings['order']) Then Return False
	Local $items = StorageSortPaneItems($world, $bag)
	If UBound($items) == 0 Then Return False
	Local $desired = StorageSortDesiredPaneSequence($items, $ticked, $settings['order'])
	; Safe executable moves: never drop an item onto an occupied slot.
	; If the target is occupied, first park that occupant in a free slot (pane, then bags).
	Local $n = UBound($desired), $i, $want, $cur, $target, $free, $guard = 0
	Local $changed = False
	While Not StorageSortPaneAlreadyInOrder($world, $bag, $ticked, $settings['order']) And $guard < $n * 4 + 8
		$guard += 1
		Local $progress = False
		For $i = 0 To $n - 1
			$target = $i + 1
			$want = $desired[$i]
			Local $fromBag = 0, $fromSlot = 0
			If Not StorageSortLocateId($world, $want['id'], $fromBag, $fromSlot) Then ContinueLoop
			$cur = StorageSortGetItem($world, $bag, $target)
			If IsMap($cur) And $cur['id'] == $want['id'] Then ContinueLoop
			If IsMap($cur) Then
				$free = StorageSortFindFreeSlot($world, $bag, $target)
				If $free <= 0 Then
					Local $park = StorageSortFindBagPlace($world, $settings, $cur)
					If $park[0] <= 0 Then ContinueLoop
					If Not StorageSortSimMove($world, $plan, $bag, $target, $park[0], $park[1], 'regroup park ' & $paneName, $moveCount, $maxMoves) Then ContinueLoop
					$changed = True
					$progress = True
					If $plan['stopped'] Then Return $changed
					If $fromBag == $bag And $fromSlot == $target Then StorageSortLocateId($world, $want['id'], $fromBag, $fromSlot)
				Else
					If Not StorageSortSimMove($world, $plan, $bag, $target, $bag, $free, 'regroup park ' & $paneName, $moveCount, $maxMoves) Then ContinueLoop
					$changed = True
					$progress = True
					If $plan['stopped'] Then Return $changed
					If $fromBag == $bag And $fromSlot == $target Then StorageSortLocateId($world, $want['id'], $fromBag, $fromSlot)
				EndIf
			EndIf
			If $fromBag == $bag And $fromSlot == $target Then ContinueLoop
			If StorageSortSimMove($world, $plan, $fromBag, $fromSlot, $bag, $target, 'regroup ' & $paneName, $moveCount, $maxMoves) Then
				$changed = True
				$progress = True
			EndIf
			If $plan['stopped'] Then Return $changed
		Next
		If Not $progress Then ExitLoop
	WEnd
	Return $changed
EndFunc

Func StorageSortLocateId(ByRef $world, $id, ByRef $bag, ByRef $slot)
	Local $b, $s, $it
	For $b = 1 To 21
		For $s = 1 To $world['slots'][$b]
			$it = StorageSortGetItem($world, $b, $s)
			If IsMap($it) And $it['id'] == $id Then
				$bag = $b
				$slot = $s
				Return True
			EndIf
		Next
	Next
	Return False
EndFunc

Func StorageSortFindFreeSlot(ByRef $world, $bag, $avoidSlot = 0)
	Local $s
	For $s = 1 To $world['slots'][$bag]
		If $s == $avoidSlot Then ContinueLoop
		If Not IsMap(StorageSortGetItem($world, $bag, $s)) Then Return $s
	Next
	Return 0
EndFunc


;~ Collect fill candidates for pane $paneName: bags and later/other panes that should feed this pane
Func StorageSortFillCandidates(ByRef $world, ByRef $settings, $paneName, $paneIndex)
	Local $list[0], $bag, $slot, $it, $srcPane, $srcIndex, $j
	Local $bags = StorageSortBagsToSort($settings)
	; v38.6: Material storage takes materials from all of bags 1-4, like the in-game Deposit All Materials button
	If $paneName == 'Material storage' Then $bags = StorageSortMaterialSourceBags()
	For $j = 0 To UBound($bags) - 1
		$bag = $bags[$j]
		For $slot = 1 To $world['slots'][$bag]
			$it = StorageSortGetItem($world, $bag, $slot)
			If Not IsMap($it) Then ContinueLoop
			If Not StorageSortPaneAcceptsFill($settings, $world, $paneName, $it) Then ContinueLoop
			ReDim $list[UBound($list) + 1]
			$list[UBound($list) - 1] = $it
		Next
	Next
	For $srcIndex = $paneIndex + 1 To 14
		; Completed panes are immutable. Never withdraw from dedicated Material Storage.
		If $srcIndex == 14 Then ContinueLoop
		$srcPane = $STORAGE_SORT_PANE_NAMES[$srcIndex]
		If Not $world['unlocked'][$srcPane] Then ContinueLoop
		$bag = StorageSortPaneBagIndex($srcPane)
		For $slot = 1 To $world['slots'][$bag]
			$it = StorageSortGetItem($world, $bag, $slot)
			If Not IsMap($it) Then ContinueLoop
			If Not StorageSortPaneAcceptsFill($settings, $world, $paneName, $it) Then ContinueLoop
			ReDim $list[UBound($list) + 1]
			$list[UBound($list) - 1] = $it
		Next
	Next
	; Order: checklist type groups, then the Order rule within a type
	Local $allTypes = $settings['types_' & $paneName]
	Return StorageSortDesiredPaneSequence($list, $allTypes, $settings['order'])
EndFunc

Func StorageSortPaneAcceptsFill(ByRef $settings, ByRef $world, $paneName, ByRef $item)
	If StorageSortPaneHasType($settings, $paneName, $item['type']) Then Return True
	; Overflow is deferred until the receiving pane's turn, never written ahead.
	Return StorageSortIsValidOverflowPane($settings, $world, $paneName, $item['type'])
EndFunc

Func StorageSortMarkChanged(ByRef $plan, $paneName)
	If StringInStr('|' & $plan['changed_panes'] & '|', '|' & $paneName & '|') Then Return
	If $plan['changed_panes'] == '' Then
		$plan['changed_panes'] = $paneName
	Else
		$plan['changed_panes'] &= '|' & $paneName
	EndIf
EndFunc

;~ Main planner. Mutates a working copy of $world. Does not loop panes more than once, plus one leftover pass.
Func StorageSortPaneIndex($paneName)
	Local $i
	For $i = 0 To 14
		If $STORAGE_SORT_PANE_NAMES[$i] == $paneName Then Return $i
	Next
	Return -1
EndFunc

;~ True when every unlocked assigned pane for this type has no free slot
Func StorageSortAssignedPanesFull(ByRef $settings, ByRef $world, $typeName)
	Local $panes = StorageSortPanesForType($settings, $world, $typeName)
	If UBound($panes) == 0 Then Return False
	Local $i, $bag
	For $i = 0 To UBound($panes) - 1
		$bag = StorageSortPaneBagIndex($panes[$i])
		If $bag > 0 And StorageSortFreeSlots($world, $bag) > 0 Then Return False
	Next
	Return True
EndFunc

;~ This pane may keep an item whose assigned panes are full (If full = Next empty pane)
Func StorageSortIsValidOverflowPane(ByRef $settings, ByRef $world, $paneName, $typeName)
	If $settings['if_full'] <> 'Next empty pane' Then Return False
	If Not $world['unlocked'][$paneName] Then Return False
	If $paneName == 'Material storage' And Not StorageSortIsMaterialOnly($typeName) Then Return False
	Local $panes = StorageSortPanesForType($settings, $world, $typeName)
	If UBound($panes) == 0 Then Return False
	If Not StorageSortAssignedPanesFull($settings, $world, $typeName) Then Return False
	Local $last = $panes[UBound($panes) - 1]
	Return StorageSortPaneIndex($paneName) > StorageSortPaneIndex($last)
EndFunc

Func StorageSortPlan(ByRef $srcWorld, ByRef $settings)
	Local $plan = StorageSortPlanNew()
	Local $world = $srcWorld
	StorageSortPresetMaterials($settings)
	Local $itemCount = StorageSortCountItems($world)
	Local $maxMoves = $itemCount * 8 + 64
	If $maxMoves < 64 Then $maxMoves = 64
	Local $moveCount = 0
	Local $pi, $paneName, $bag, $slot, $it, $dest, $types, $changed

	For $pi = 0 To 14
		If $plan['stopped'] Then ExitLoop
		$paneName = $STORAGE_SORT_PANE_NAMES[$pi]
		If Not $world['unlocked'][$paneName] Then ContinueLoop
		$bag = StorageSortPaneBagIndex($paneName)
		If $bag <= 0 Or $world['slots'][$bag] <= 0 Then ContinueLoop
		$types = $settings['types_' & $paneName]
		$changed = False

		; Material slots have fixed identities. Never empty or regroup that bag.
		; 1. Move out anything that does not belong
		For $slot = 1 To $world['slots'][$bag]
			If $bag == $STORAGE_SORT_MATERIAL_BAG Then ExitLoop
			If $plan['stopped'] Then ExitLoop
			$it = StorageSortGetItem($world, $bag, $slot)
			If Not IsMap($it) Then ContinueLoop
			If StorageSortPaneHasType($settings, $paneName, $it['type']) Then ContinueLoop
			; Keep overflow that landed here because assigned panes are full (If full = Next empty pane)
			If StorageSortIsValidOverflowPane($settings, $world, $paneName, $it['type']) Then ContinueLoop
			; Evict to bags first; only when bags are full does it go straight to its own (later) pane
			$dest = StorageSortFindDest($world, $settings, $it, True, $pi)
			If $dest[0] <= 0 Then
				; No scratch room: stop safely instead of interleaving panes.
				StorageSortPlanAddLeftover($plan, $it, 'no space to evict from ' & $paneName)
				StorageSortPlanLog($plan, 'No space for item ' & $it['id'] & ' evicted from ' & $paneName & ' - stopping')
				$plan['stopped'] = True
				$plan['stop_reason'] = 'no space while evicting from ' & $paneName
				ExitLoop
			EndIf
			If StorageSortSimMove($world, $plan, $bag, $slot, $dest[0], $dest[1], 'evict from ' & $paneName, $moveCount, $maxMoves) Then
				$changed = True
			EndIf
		Next
		If $plan['stopped'] Then ExitLoop

		; 2. Fill with this pane's ticked types from bags and other panes, one item at a time
		If IsArray($types) Then
			Local $cands = StorageSortFillCandidates($world, $settings, $paneName, $pi)
			Local $c
			For $c = 0 To UBound($cands) - 1
				If $plan['stopped'] Then ExitLoop
				$it = $cands[$c]
				; Re-read: the item may have been moved by an earlier fill
				Local $cur = StorageSortGetItem($world, $it['bag'], $it['slot'])
				If Not IsMap($cur) Or $cur['id'] <> $it['id'] Then ContinueLoop
				Local $placeBag = $bag
				Local $placeSlot = StorageSortFindSlotInPane($world, $bag, $cur, $settings['merge_stacks'] == True)
				If $placeSlot <= 0 Then
					; leave in bags / current location
					ContinueLoop
				EndIf
				If StorageSortSimMove($world, $plan, $cur['bag'], $cur['slot'], $placeBag, $placeSlot, 'fill ' & $paneName, $moveCount, $maxMoves) Then
					$changed = True
					If $placeBag == $bag Then StorageSortMarkChanged($plan, $paneName)
				EndIf
			Next
		EndIf

		; 3. Complete this pane before proceeding, even if all its items were already here.
		If StorageSortRegroupPane($world, $plan, $settings, $paneName, $moveCount, $maxMoves) Then $changed = True
		If $changed Then StorageSortMarkChanged($plan, $paneName)
		If $bag <> $STORAGE_SORT_MATERIAL_BAG And Not StorageSortPaneAlreadyInOrder($world, $bag, $types, $settings['order']) Then
			$plan['stopped'] = True
			$plan['stop_reason'] = 'no scratch space to finish regrouping ' & $paneName
		EndIf
	Next

	; Compact bags if requested (pack after reserved slots)
	If Not $plan['stopped'] And $settings['compact_slots'] == True Then
		StorageSortCompactBags($world, $plan, $settings, $moveCount, $maxMoves)
	EndIf

	$plan['world'] = $world
	Return $plan
EndFunc

Func StorageSortCompactBags(ByRef $world, ByRef $plan, ByRef $settings, ByRef $moveCount, $maxMoves)
	Local $bags = StorageSortBagsToSort($settings)
	Local $i, $bag, $reserve, $read, $write, $it
	$reserve = Number($settings['reserve_slots'])
	For $i = 0 To UBound($bags) - 1
		$bag = $bags[$i]
		$write = $reserve + 1
		If $write < 1 Then $write = 1
		For $read = $write To $world['slots'][$bag]
			$it = StorageSortGetItem($world, $bag, $read)
			If Not IsMap($it) Then ContinueLoop
			If $read == $write Then
				$write += 1
				ContinueLoop
			EndIf
			If StorageSortSimMove($world, $plan, $bag, $read, $bag, $write, 'compact bags', $moveCount, $maxMoves) Then $write += 1
			If $plan['stopped'] Then Return
		Next
	Next
EndFunc
#EndRegion

#Region Settings JSON
Func StorageSortSettingsToMap(ByRef $settings)
	Local $o[]
	$o['version'] = 1
	$o['reserve_slots'] = Number($settings['reserve_slots'])
	$o['order'] = $settings['order']
	$o['merge_stacks'] = $settings['merge_stacks'] == True
	$o['compact_slots'] = $settings['compact_slots'] == True
	$o['if_full'] = $settings['if_full']
	$o['bags'] = $settings['bags']
	Local $panes[]
	Local $i, $name
	For $i = 0 To 14
		$name = $STORAGE_SORT_PANE_NAMES[$i]
		$panes[$name] = $settings['types_' & $name]
	Next
	$o['panes'] = $panes
	Return $o
EndFunc

Func StorageSortSettingsFromMap($o)
	Local $s = StorageSortDefaultSettings()
	If Not IsMap($o) Then Return $s
	; v38.6: legacy 'after_store' / 'on_run_start' keys are ignored (sorting is manual only)
	If MapExists($o, 'reserve_slots') Then $s['reserve_slots'] = Number($o['reserve_slots'])
	If MapExists($o, 'order') Then $s['order'] = $o['order']
	If MapExists($o, 'merge_stacks') Then $s['merge_stacks'] = $o['merge_stacks'] == True
	If MapExists($o, 'compact_slots') Then $s['compact_slots'] = $o['compact_slots'] == True
	If MapExists($o, 'if_full') Then $s['if_full'] = $o['if_full']
	If MapExists($o, 'bags') And IsArray($o['bags']) Then $s['bags'] = $o['bags']
	If MapExists($o, 'panes') And IsMap($o['panes']) Then
		Local $i, $name, $types
		For $i = 0 To 14
			$name = $STORAGE_SORT_PANE_NAMES[$i]
			If MapExists($o['panes'], $name) Then
				$types = $o['panes'][$name]
				If IsArray($types) Then $s['types_' & $name] = StorageSortSanitizeTypes($types)
			EndIf
		Next
	EndIf
	StorageSortPresetMaterials($s)
	Return $s
EndFunc

Func StorageSortSanitizeTypes($types)
	Local $out[0], $i, $t
	For $i = 0 To UBound($types) - 1
		$t = $types[$i]
		If StorageSortTypeIndex($t) == 99 Then ContinueLoop
		If StorageSortArrayHasStr($out, $t) Then ContinueLoop
		ReDim $out[UBound($out) + 1]
		$out[UBound($out) - 1] = $t
	Next
	; restore checklist order
	Local $ordered[0], $k
	For $k = 0 To UBound($STORAGE_SORT_TYPES) - 1
		If StorageSortArrayHasStr($out, $STORAGE_SORT_TYPES[$k]) Then
			ReDim $ordered[UBound($ordered) + 1]
			$ordered[UBound($ordered) - 1] = $STORAGE_SORT_TYPES[$k]
		EndIf
	Next
	Return $ordered
EndFunc

Func StorageSortArrayHasStr(ByRef $arr, $s)
	Local $i
	For $i = 0 To UBound($arr) - 1
		If $arr[$i] == $s Then Return True
	Next
	Return False
EndFunc

Func StorageSortSaveToFile($settings, $filePath)
	Local $obj = StorageSortSettingsToMap($settings)
	Local $json = _JSON_Generate($obj)
	Local $dir = StringLeft($filePath, StringInStr($filePath, '\', 0, -1) - 1)
	If $dir == '' Then $dir = StringLeft($filePath, StringInStr($filePath, '/', 0, -1) - 1)
	If $dir <> '' Then DirCreate($dir)
	Local $fh = FileOpen($filePath, $FO_OVERWRITE + $FO_CREATEPATH + $FO_UTF8)
	If $fh == -1 Then Return False
	FileWrite($fh, $json)
	FileClose($fh)
	Return True
EndFunc

Func StorageSortLoadFromFile($filePath)
	Local $raw = FileRead($filePath)
	If @error Then Return StorageSortDefaultSettings()
	Local $obj = _JSON_Parse($raw)
	Return StorageSortSettingsFromMap($obj)
EndFunc
#EndRegion

#Region Classify / snapshot / execute (game client)
Func StorageSortIsKitModel($model)
	Return $model == $ID_IDENTIFICATION_KIT Or $model == $ID_SUPERIOR_IDENTIFICATION_KIT Or _
		$model == $ID_SALVAGE_KIT Or $model == $ID_SALVAGE_KIT_2 Or _
		$model == $ID_EXPERT_SALVAGE_KIT Or $model == $ID_SUPERIOR_SALVAGE_KIT
EndFunc

;~ Loose upgrade kind from the item's modstruct: Inscriptions, Mods, Runes, or Insignias
Func StorageSortUpgradeType($item)
	Local $hex = ''
	If IsDeclared('GetModStructHex') Or True Then
		$hex = GetModStructHex($item)
	EndIf
	If $hex <> '' And StringInStr($hex, $STRUCT_INSCRIPTION) Then Return 'Inscriptions'
	; Weapon mods carry a TargetItemType (25B8) or a weapon-upgrade marker
	If $hex <> '' And (StringInStr($hex, 'B825') Or StringInStr($hex, '25B8') Or StringInStr($hex, $STRUCT_WEAPON_UPGRADE)) Then
		; armor runes/insignias also have tooltip 2530, which can look like a '30' marker; prefer armor structs when they match
		If StorageSortHexLooksLikeArmorUpgrade($hex) Then Return StorageSortRuneOrInsignia($hex)
		If StringInStr($hex, 'B825') Or StringInStr($hex, '25B8') Then Return 'Mods'
	EndIf
	If StorageSortHexLooksLikeArmorUpgrade($hex) Then Return StorageSortRuneOrInsignia($hex)
	If IsWeaponMod(DllStructGetData($item, 'ModelID')) Then Return 'Mods'
	Return 'Mods'
EndFunc

Func StorageSortHexLooksLikeArmorUpgrade($hex)
	If $hex == '' Then Return False
	; Identity dwords used by known runes (Vigor family and common all-profession runes)
	If StringInStr($hex, $STRUCT_ALL_RUNES_MINOR_VIGOR) Then Return True
	If StringInStr($hex, $STRUCT_ALL_RUNES_MAJOR_VIGOR) Then Return True
	If StringInStr($hex, $STRUCT_ALL_RUNES_SUPERIOR_VIGOR) Then Return True
	If StringInStr($hex, $STRUCT_ALL_RUNES_VITAE) Then Return True
	If StringInStr($hex, $STRUCT_ALL_RUNES_ATTUNEMENT) Then Return True
	If StringInStr($hex, $STRUCT_ALL_RUNES_RECOVERY) Then Return True
	If StringInStr($hex, $STRUCT_ALL_RUNES_RESTORATION) Then Return True
	If StringInStr($hex, $STRUCT_ALL_RUNES_CLARITY) Then Return True
	If StringInStr($hex, $STRUCT_ALL_RUNES_PURITY) Then Return True
	Return False
EndFunc

Func StorageSortRuneOrInsignia($hex)
	If StorageSortHexLooksLikeArmorUpgrade($hex) Then Return 'Runes'
	Return 'Insignias'
EndFunc

; All twelve zodiac fortunes reuse these existing model IDs in subsequent cycles.
; Explicit constants (no inferred range / name substring). Token is 21833, not cookie 28433.
Func StorageSortLunarModel($model)
	Switch $model
		Case $ID_LUNAR_FORTUNE_PIG, $ID_LUNAR_FORTUNE_RAT, $ID_LUNAR_FORTUNE_OX, $ID_LUNAR_FORTUNE_TIGER, _
			$ID_LUNAR_FORTUNE_RABBIT, $ID_LUNAR_FORTUNE_DRAGON, $ID_LUNAR_FORTUNE_SNAKE, $ID_LUNAR_FORTUNE_HORSE, _
			$ID_LUNAR_FORTUNE_SHEEP, $ID_LUNAR_FORTUNE_MONKEY, $ID_LUNAR_FORTUNE_ROOSTER, $ID_LUNAR_FORTUNE_DOG, $ID_LUNAR_TOKEN
			Return True
	EndSwitch
	Return False
EndFunc

Func StorageSortClassifyItem($item)
	If Not IsMap($item) And Not IsDllStruct($item) Then Return ''
	Local $model = DllStructGetData($item, 'ModelID')
	If DllStructGetData($item, 'Type') == $ID_TYPE_MINIPET Then Return 'Minipets'
	If StorageSortLunarModel($model) Then Return 'Festival items'
	If $model == $ID_BIRDS_EYE_COMPASS Or $model == $ID_STALKERS_RATION Then Return 'Consumables'
	If StorageSortIsKitModel($model) Then Return 'Salvage / ID kits'
	If IsKey($model) Or $model == $ID_LOCKPICK Then Return 'Keys'
	If $model == $ID_DYES Then Return 'Dyes'
	If IsMaterial($item) Then
		If IsRareMaterial($item) Then Return 'Rare materials'
		Return 'Materials'
	EndIf
	If IsLooseUpgradeComponent($item) Then Return StorageSortUpgradeType($item)
	If IsTome($model) Then Return 'Tomes'
	If IsFestive($model) Then Return 'Festival items'
	If IsConsumable($model) Then Return 'Consumables'
	If IsTrophy($model) Then Return 'Trophies'
	If IsWeapon($item) Or IsArmor($item) Or IsArmorSalvageItem($item) Then
		Local $r = GetRarity($item)
		If $r == $RARITY_GOLD Then Return 'Golds'
		If $r == $RARITY_PURPLE Then Return 'Purples'
	EndIf
	Return ''
EndFunc

Func StorageSortTimeNow()
	Local $h = Number(@HOUR), $ampm = 'AM'
	If $h >= 12 Then $ampm = 'PM'
	If $h > 12 Then $h -= 12
	If $h == 0 Then $h = 12
	Local $mons = StringSplit('Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec', ',', 2)
	Return $mons[Number(@MON) - 1] & ' ' & Number(@MDAY) & ', ' & $h & ':' & @MIN & ' ' & $ampm
EndFunc

;~ Scan Xunlai panes: unlocked if GetBag returns a positive slot count. Updates globals.
Func StorageSortScanPanes()
	Local $i, $name, $bag, $g, $slots
	For $i = 0 To 14
		$name = $STORAGE_SORT_PANE_NAMES[$i]
		$bag = StorageSortPaneBagIndex($name)
		$slots = 0
		$g = GetBag($bag)
		If $g <> Null Then $slots = DllStructGetData($g, 'slots')
		$storage_sort_unlocked[$name] = ($slots > 0)
	Next
	$storage_sort_scanned = True
	$storage_sort_lastscan = 'Last: ' & StorageSortTimeNow()
	Return $storage_sort_scanned
EndFunc

Func StorageSortSnapshotFromGame(ByRef $settings)
	Local $world = StorageSortWorldNew()
	Local $i, $name, $bag, $g, $slots, $slot, $raw, $id, $it, $type
	For $i = 0 To 14
		$name = $STORAGE_SORT_PANE_NAMES[$i]
		$bag = StorageSortPaneBagIndex($name)
		$slots = 0
		$g = GetBag($bag)
		If $g <> Null Then $slots = DllStructGetData($g, 'slots')
		$world['slots'][$bag] = $slots
		If $storage_sort_scanned Then
			$world['unlocked'][$name] = $storage_sort_unlocked[$name] And $slots > 0
		Else
			$world['unlocked'][$name] = ($slots > 0)
		EndIf
		If $slots <= 0 Then ContinueLoop
		Local $bagItems = GetBagItemsOf($bag, $g)
		For $slot = 1 To $slots
			$raw = $bagItems[$slot - 1]
			$id = DllStructGetData($raw, 'ID')
			If $id == 0 Then ContinueLoop
			$type = StorageSortClassifyItem($raw)
			$it = StorageSortItem($id, $type, DllStructGetData($raw, 'ModelID'), StorageMoveQuantity($raw, $bag), IsStackable($raw), GetRarity($raw), '', DllStructGetData($raw, 'DyeColor'), StorageSortMaxQty($bag))
			StorageSortPut($world, $bag, $slot, $it)
		Next
	Next
	Local $bags = StorageSortMaterialSourceBags(), $b
	For $b = 0 To UBound($bags) - 1
		$bag = $bags[$b]
		$slots = 0
		$g = GetBag($bag)
		If $g <> Null Then $slots = DllStructGetData($g, 'slots')
		$world['slots'][$bag] = $slots
		Local $bagItems = GetBagItemsOf($bag, $g)
		For $slot = 1 To $slots
			$raw = $bagItems[$slot - 1]
			$id = DllStructGetData($raw, 'ID')
			If $id == 0 Then ContinueLoop
			$type = StorageSortClassifyItem($raw)
			$it = StorageSortItem($id, $type, DllStructGetData($raw, 'ModelID'), StorageMoveQuantity($raw, $bag), IsStackable($raw), GetRarity($raw), '', DllStructGetData($raw, 'DyeColor'), StorageSortMaxQty($bag))
			StorageSortPut($world, $bag, $slot, $it)
		Next
	Next
	Return $world
EndFunc

; Clock / sleep adapters keep the one shared move gate mockable without speeding up production.
Func StorageMoveClock()
	Return TimerInit()
EndFunc

Func StorageMoveElapsed($since)
	Return TimerDiff($since)
EndFunc

Func StorageMoveSleep($ms)
	Sleep($ms)
EndFunc

Func StorageMoveWaitTurn()
	If Not $storage_move_has_last Then Return
	Local $remaining = $STORAGE_MOVE_MIN_MS - StorageMoveElapsed($storage_move_last)
	While $remaining > 0
		StorageMoveSleep(Ceiling($remaining))
		$remaining = $STORAGE_MOVE_MIN_MS - StorageMoveElapsed($storage_move_last)
	WEnd
EndFunc

Func StorageMoveQuantity($item, $bag)
	Local $q = DllStructGetData($item, 'Quantity')
	If $bag == $STORAGE_SORT_MATERIAL_BAG Then $q += DllStructGetData($item, 'Equipped') * 256
	Return $q
EndFunc

; One packet, then confirmation or timeout, never a burst/retry. Shared by Sort and Empty Tab.
Func StorageMoveConfirmed($item, $fromBag, $fromSlot, $toBag, $toSlot, $amount = 0, $allowPartial = False)
	If $storage_move_busy Then Return False
	$storage_move_busy = True
	StorageMoveWaitTurn()
	Local $source = GetItemBySlot($fromBag, $fromSlot), $dest = GetItemBySlot($toBag, $toSlot)
	Local $id = DllStructGetData($item, 'ID'), $qty = StorageMoveQuantity($source, $fromBag)
	If $id == 0 Or DllStructGetData($source, 'ID') <> $id Or GetMapType() <> $ID_OUTPOST Or GetMyID() == 0 Then
		$storage_move_busy = False
		Return False
	EndIf
	Local $destQty = StorageMoveQuantity($dest, $toBag), $model = DllStructGetData($source, 'ModelID')
	If $amount <= 0 Then
		$amount = $qty
		If DllStructGetData($dest, 'ID') <> 0 Then $amount = _Min($amount, 250 - $destQty)
	EndIf
	If $amount <= 0 Then
		$storage_move_busy = False
		Return False
	EndIf
	MoveItem($source, $toBag, $toSlot)
	; Measure from dispatch completion (conservative), across calls/plans/partial merges too.
	$storage_move_last = StorageMoveClock()
	$storage_move_has_last = True
	Local $timer = StorageMoveClock(), $now, $atDest, $remaining, $ok = False
	While StorageMoveElapsed($timer) < $STORAGE_MOVE_TIMEOUT_MS
		StorageMoveSleep(50)
		$now = GetItemBySlot($fromBag, $fromSlot)
		$atDest = GetItemBySlot($toBag, $toSlot)
		$remaining = DllStructGetData($now, 'ID') == $id ? StorageMoveQuantity($now, $fromBag) : 0
		Local $gained = StorageMoveQuantity($atDest, $toBag) - $destQty
		If $allowPartial And $gained > 0 And $remaining == $qty - $gained And DllStructGetData($atDest, 'ModelID') == $model Then
			$ok = True
			ExitLoop
		EndIf
		If $remaining == $qty - $amount And DllStructGetData($atDest, 'ModelID') == $model And $gained == $amount Then
			$ok = True
			ExitLoop
		EndIf
	WEnd
	$storage_move_busy = False
	Return $ok
EndFunc

Func StorageSortExecutePlan(ByRef $plan)
	Local $moves = $plan['moves'], $i, $m, $item, $dest, $done = 0
	For $i = 0 To UBound($moves) - 1
		$m = $moves[$i]
		$item = GetItemBySlot($m['fromBag'], $m['fromSlot'])
		$dest = GetItemBySlot($m['toBag'], $m['toSlot'])
		; Any mismatch invalidates subsequent slot-based moves. Never skip ahead into the next pane.
		Local $toMat = ($m['toBag'] == $STORAGE_SORT_MATERIAL_BAG)
		If DllStructGetData($item, 'ID') <> $m['id'] Or StorageMoveQuantity($item, $m['fromBag']) <> $m['source_qty'] Or _
			((Not $toMat) And (DllStructGetData($dest, 'ID') <> $m['dest_id'] Or StorageMoveQuantity($dest, $m['toBag']) <> $m['dest_qty'])) Then
			Warn('[Storage Sort] Storage changed since planning; stopped. Scan and sort again.')
			Return False
		EndIf
		If $toMat Then
			; Material storage: capacity is not readable, so take what the slot accepts; a full slot is skipped, not fatal
			If Not StorageMoveConfirmed($item, $m['fromBag'], $m['fromSlot'], $m['toBag'], $m['toSlot'], $m['source_qty'], True) Then
				If GetMapType() <> $ID_OUTPOST Or GetMyID() == 0 Then
					Warn('[Storage Sort] Left the outpost or disconnected; stopped after ' & $done & ' move(s).')
					Return False
				EndIf
				Warn('[Storage Sort] Material storage did not accept item ' & $m['id'] & ' (slot full?) - left in bag ' & $m['fromBag'])
				ContinueLoop
			EndIf
			$done += 1
			ContinueLoop
		EndIf
		If Not StorageMoveConfirmed($item, $m['fromBag'], $m['fromSlot'], $m['toBag'], $m['toSlot'], $m['amount']) Then
			Warn('[Storage Sort] Move not confirmed (or disconnected); stopped after ' & $done & ' move(s).')
			Return False
		EndIf
		$done += 1
	Next
	Info('[Storage Sort] Applied ' & $done & ' move(s), minimum 100 ms apart')
	Return True
EndFunc

; Material storage capacity depends on account upgrades and cannot be read; the executor confirms what was accepted
Func StorageSortMaterialSourceBags()
	Local $b[4] = [1, 2, 3, 4]
	Return $b
EndFunc

Func StorageSortMaxQty($bag)
	If $bag == $STORAGE_SORT_MATERIAL_BAG Then Return 1000000
	Return 250
EndFunc

Func StorageSortFindId($id, ByRef $bag, ByRef $slot)
	Local $b, $s, $it
	For $b = 1 To 21
		Local $g = GetBag($b)
		If $g == Null Then ContinueLoop
		Local $n = DllStructGetData($g, 'slots')
		Local $bagItems = GetBagItemsOf($b, $g)
		For $s = 1 To $n
			$it = $bagItems[$s - 1]
			If DllStructGetData($it, 'ID') == $id Then
				$bag = $b
				$slot = $s
				Return True
			EndIf
		Next
	Next
	Return False
EndFunc

;~ Public entry used by Sort now and by the optional town-pass hooks. $reason is a log label.
Func StorageSortNow($reason = 'Sort now')
	If $storage_sort_busy Then Return False
	$storage_sort_busy = True
	Local $result = StorageSortNowInternal($reason)
	$storage_sort_busy = False
	Return $result
EndFunc

Func StorageSortNowInternal($reason)
	If Not IsAttachedForTools() Then Return False
	If $runtime_status == 'RUNNING' Or $runtime_status == 'WILL_PAUSE' Then
		MsgBox(0, 'Storage Sort', 'Pause the farm (and wait for it to stop) before sorting storage.')
		Return False
	EndIf
	Local $pid = GetPID()
	If $pid == '' Or $pid == 0 Or ProcessExists($pid) == 0 Then
		Warn('[Storage Sort] Guild Wars client not found (closed?) - restart it and attach again. Nothing moved.')
		Return False
	EndIf
	If GetMapType() <> $ID_OUTPOST Or GetMyID() == 0 Then
		Warn('[Storage Sort] Storage can only be sorted in an outpost or town - nothing moved')
		Return False
	EndIf
	If Not IsMap($storage_sort_applied) Then $storage_sort_applied = StorageSortDefaultSettings()
	Local $hasType = False, $i, $name, $types
	For $i = 0 To 14
		$types = $storage_sort_applied['types_' & $STORAGE_SORT_PANE_NAMES[$i]]
		If IsArray($types) And UBound($types) > 0 Then $hasType = True
	Next
	If Not $hasType Then
		Info('[Storage Sort] Nothing to sort (no types assigned in the applied layout)')
		Return False
	EndIf
	OpenXunlaiWindow()
	Sleep(500 + GetPing())
	StorageSortScanPanes()
	StorageSortPresetMaterials($storage_sort_applied)
	Info('[Storage Sort] Deposit All Materials is not wired in this GWA2; using confirmed, paced per-item material moves (fixed slots).')
	Local $world = StorageSortSnapshotFromGame($storage_sort_applied)
	Local $plan = StorageSortPlan($world, $storage_sort_applied)
	Local $logs = $plan['logs'], $L
	For $L = 0 To UBound($logs) - 1
		Info('[Storage Sort] ' & $logs[$L])
	Next
	If UBound($plan['moves']) == 0 Then
		If $plan['stopped'] Then
			Warn('[Storage Sort] ' & $reason & ': stopped - ' & $plan['stop_reason'])
		Else
			Info('[Storage Sort] ' & $reason & ': already in order, nothing to move')
		EndIf
		Return True
	EndIf
	Info('[Storage Sort] ' & $reason & ': ' & UBound($plan['moves']) & ' move(s)')
	If Not StorageSortExecutePlan($plan) Then Return False
	Local $left = $plan['leftovers']
	If UBound($left) > 0 Then
		Local $j
		For $j = 0 To UBound($left) - 1
			Local $leftover = $left[$j]
			Warn('[Storage Sort] Could not place item ' & $leftover['id'] & ' (' & $leftover['type'] & ') from bag ' & $leftover['bag'] & ' slot ' & $leftover['slot'] & ': ' & $leftover['reason'])
		Next
	EndIf
	ItemsPanelRefresh(True)
	Return True
EndFunc
#EndRegion

; Initialise defaults when this file is included
StorageSortInit()
