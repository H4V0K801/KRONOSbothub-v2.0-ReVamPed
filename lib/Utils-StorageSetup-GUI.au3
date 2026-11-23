#CS ===========================================================================
; v38: Tools > Sorting Inventory section and the hidden Storage Setup page.
; The page is not a tab in the row; Setup shows it, Back returns to Tools.
#CE ===========================================================================

#include-once
#include <Array.au3>
#include <GuiEdit.au3>
#include <EditConstants.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <GUIConstantsEx.au3>
#include <WinAPI.au3>
#include <WinAPISysWin.au3>

Global $gui_group_sortinv, $gui_button_storagesetup, $gui_button_sortnow_tools, $gui_label_storagesetup
Global $gui_ss_back, $gui_ss_load, $gui_ss_save, $gui_ss_apply, $gui_ss_sortnow
Global $gui_ss_bag1, $gui_ss_bag2, $gui_ss_bag3, $gui_ss_bag4, $gui_ss_reserve
Global $gui_ss_order, $gui_ss_merge, $gui_ss_compact, $gui_ss_overflow
Global $gui_ss_paneTitle, $gui_ss_paneHint, $gui_ss_paneNote
Global $gui_ss_fill1, $gui_ss_fill2, $gui_ss_selbar, $gui_ss_layout, $gui_ss_scan, $gui_ss_lastscan
Global $gui_ss_paneBg[15], $gui_ss_paneName[15], $gui_ss_paneSum[15]
Global $gui_ss_type[UBound($STORAGE_SORT_TYPES)]
Global $ss_setup_ids[1]
Global $ss_tools_ids[1]
Global $ss_page_open = False
Global $ss_updating = False
Global $ss_sel = 0
; Working copy edited on the page; Apply / Load copies it to $storage_sort_applied
Global $storage_sort_draft

Func _SSAddId(ByRef $arr, $id)
	If $id == 0 Then Return
	Local $n = UBound($arr)
	ReDim $arr[$n + 1]
	$arr[$n] = $id
EndFunc

Func _SSSetIds($arr, $state)
	Local $i
	For $i = 1 To UBound($arr) - 1
		If $arr[$i] Then GUICtrlSetState($arr[$i], $state)
	Next
EndFunc

Func StorageSetupAddToolsSection()
	$gui_group_sortinv = GUICtrlCreateGroup('Sorting Inventory', 21, 379, 604, 64)
	$gui_button_storagesetup = GUICtrlCreateButton('Setup', 31, 399, 120, 28)
	ThemeSetButton($gui_button_storagesetup, $THEME_BTN_PRIMARY)
	GUICtrlSetOnEvent($gui_button_storagesetup, 'GuiToolsTabButtonHandler')
	$gui_button_sortnow_tools = GUICtrlCreateButton('Sort now', 159, 399, 120, 28)
	ThemeSetButton($gui_button_sortnow_tools, $THEME_BTN_PRIMARY)
	GUICtrlSetOnEvent($gui_button_sortnow_tools, 'GuiToolsTabButtonHandler')
	$gui_label_storagesetup = GUICtrlCreateLabel('Setup: choose items per Xunlai pane. Sort now: sorts one pane at a time using the saved layout.', 287, 397, 328, 36)
	GUICtrlCreateGroup('', -99, -99, 1, 1)
	StorageSetupCreateControls()
EndFunc

Func StorageSetupCreateControls()
	Local $id, $p, $t, $col, $row, $x, $y, $notify
	$notify = $SS_NOTIFY
	Local $empty[1]
	$ss_setup_ids = $empty
	If Not IsMap($storage_sort_applied) Then StorageSortInit()
	$storage_sort_draft = StorageSortCopySettings($storage_sort_applied)
	$ss_sel = 0

	$id = GUICtrlCreateLabel('Storage Setup', 80, 43, 110, 16)
	GUICtrlSetColor($id, $THEME_ACCENT_GOLD)
	_SSAddId($ss_setup_ids, $id)
	$gui_ss_layout = GUICtrlCreateLabel(StorageSetupLayoutCaption(), 196, 43, 230, 16)
	GUICtrlSetColor($gui_ss_layout, $THEME_VALUE)
	_SSAddId($ss_setup_ids, $gui_ss_layout)
	$id = GUICtrlCreateLabel('Saved in conf/storage', 430, 43, 124, 16)
	GUICtrlSetColor($id, $THEME_TEXT_DIM)
	_SSAddId($ss_setup_ids, $id)
	$gui_ss_back = GUICtrlCreateButton('Back', 560, 39, 70, 22)
	GUICtrlSetOnEvent($gui_ss_back, 'StorageSetupHide')
	_SSAddId($ss_setup_ids, $gui_ss_back)

	$gui_ss_load = GUICtrlCreateButton('Load', 14, 84, 63, 21)
	GUICtrlSetOnEvent($gui_ss_load, 'StorageSetupLoad')
	_SSAddId($ss_setup_ids, $gui_ss_load)
	$gui_ss_save = GUICtrlCreateButton('Save', 14, 114, 63, 21)
	GUICtrlSetOnEvent($gui_ss_save, 'StorageSetupSave')
	_SSAddId($ss_setup_ids, $gui_ss_save)
	$id = GUICtrlCreateLabel('Click apply to confirm your changes', 14, 144, 63, 56, $SS_CENTER)
	_SSAddId($ss_setup_ids, $id)
	$gui_ss_apply = GUICtrlCreateButton(@LF & 'Apply' & @LF & 'changes', 14, 204, 63, 63, $BS_MULTILINE)
	ThemeSetButton($gui_ss_apply, $THEME_BTN_WARNING, $THEME_BTN_WARNING_TEXT)
	GUICtrlSetOnEvent($gui_ss_apply, 'StorageSetupApply')
	_SSAddId($ss_setup_ids, $gui_ss_apply)
	$id = GUICtrlCreateLabel('Opened from Tools', 14, 274, 63, 32, $SS_CENTER)
	GUICtrlSetColor($id, $THEME_TEXT_DIM)
	_SSAddId($ss_setup_ids, $id)

	_SSAddId($ss_setup_ids, GUICtrlCreateGroup('Storage panes', 80, 66, 248, 264))
	$gui_ss_scan = GUICtrlCreateButton('Scan storage', 86, 82, 92, 18)
	GUICtrlSetOnEvent($gui_ss_scan, 'StorageSetupScan')
	_SSAddId($ss_setup_ids, $gui_ss_scan)
	$gui_ss_lastscan = GUICtrlCreateLabel($storage_sort_lastscan, 182, 84, 140, 14)
	GUICtrlSetColor($gui_ss_lastscan, $THEME_TEXT_DIM)
	_SSAddId($ss_setup_ids, $gui_ss_lastscan)
	For $p = 0 To 14
		$y = 102 + $p * 15
		$gui_ss_paneBg[$p] = GUICtrlCreateLabel('', 86, $y, 234, 15, $notify)
		GUICtrlSetOnEvent($gui_ss_paneBg[$p], 'StorageSetupSelectPane')
		_SSAddId($ss_setup_ids, $gui_ss_paneBg[$p])
		$gui_ss_paneName[$p] = GUICtrlCreateLabel($STORAGE_SORT_PANE_NAMES[$p], 96, $y, 104, 15, $notify)
		GUICtrlSetOnEvent($gui_ss_paneName[$p], 'StorageSetupSelectPane')
		_SSAddId($ss_setup_ids, $gui_ss_paneName[$p])
		$gui_ss_paneSum[$p] = GUICtrlCreateLabel('', 202, $y, 114, 15, $notify)
		GUICtrlSetOnEvent($gui_ss_paneSum[$p], 'StorageSetupSelectPane')
		_SSAddId($ss_setup_ids, $gui_ss_paneSum[$p])
	Next
	$gui_ss_selbar = GUICtrlCreateLabel('', 86, 102, 3, 15)
	GUICtrlSetBkColor($gui_ss_selbar, $THEME_ACCENT_GOLD)
	_SSAddId($ss_setup_ids, $gui_ss_selbar)
	GUICtrlCreateGroup('', -99, -99, 1, 1)

	_SSAddId($ss_setup_ids, GUICtrlCreateGroup('Items in this pane', 334, 66, 296, 264))
	$gui_ss_paneTitle = GUICtrlCreateLabel('Pane I', 344, 84, 276, 16)
	GUICtrlSetColor($gui_ss_paneTitle, $THEME_ACCENT_GOLD)
	_SSAddId($ss_setup_ids, $gui_ss_paneTitle)
	$gui_ss_paneHint = GUICtrlCreateLabel('Mix types here. Shared types fill panes in list order.', 344, 102, 276, 16)
	GUICtrlSetColor($gui_ss_paneHint, $THEME_TEXT_DIM)
	_SSAddId($ss_setup_ids, $gui_ss_paneHint)
	For $t = 0 To UBound($STORAGE_SORT_TYPES) - 1
		$col = Int($t / 8)
		$row = Mod($t, 8)
		$x = 344 + $col * 142
		$y = 122 + $row * 22
		$gui_ss_type[$t] = GUICtrlCreateCheckbox($STORAGE_SORT_TYPES[$t], $x, $y, 138, 20)
		GUICtrlSetOnEvent($gui_ss_type[$t], 'StorageSetupTypeToggled')
		_SSAddId($ss_setup_ids, $gui_ss_type[$t])
	Next
	$gui_ss_paneNote = GUICtrlCreateLabel('Unassigned types stay in bags.', 344, 300, 276, 26)
	GUICtrlSetColor($gui_ss_paneNote, $THEME_TEXT_DIM)
	_SSAddId($ss_setup_ids, $gui_ss_paneNote)
	GUICtrlCreateGroup('', -99, -99, 1, 1)

	$id = GUICtrlCreateLabel('Fill order', 20, 338, 60, 16)
	GUICtrlSetColor($id, $THEME_ACCENT_GOLD)
	_SSAddId($ss_setup_ids, $id)
	$gui_ss_fill1 = GUICtrlCreateLabel('', 82, 338, 350, 16)
	_SSAddId($ss_setup_ids, $gui_ss_fill1)
	$id = GUICtrlCreateLabel('If full', 436, 338, 40, 16)
	_SSAddId($ss_setup_ids, $id)
	$gui_ss_overflow = GUICtrlCreateCombo('', 476, 336, 154, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	GUICtrlSetData($gui_ss_overflow, 'Next empty pane|Leave in bags', 'Next empty pane')
	GUICtrlSetOnEvent($gui_ss_overflow, 'StorageSetupDraftChanged')
	_SSAddId($ss_setup_ids, $gui_ss_overflow)
	$gui_ss_fill2 = GUICtrlCreateLabel('', 20, 354, 610, 16)
	GUICtrlSetColor($gui_ss_fill2, $THEME_TEXT_DIM)
	_SSAddId($ss_setup_ids, $gui_ss_fill2)

	_SSAddId($ss_setup_ids, GUICtrlCreateGroup('Bags to sort', 16, 374, 200, 68))
	$gui_ss_bag1 = GUICtrlCreateCheckbox('Bag 1', 24, 392, 46, 18)
	$gui_ss_bag2 = GUICtrlCreateCheckbox('Bag 2', 72, 392, 46, 18)
	$gui_ss_bag3 = GUICtrlCreateCheckbox('Bag 3', 120, 392, 46, 18)
	$gui_ss_bag4 = GUICtrlCreateCheckbox('Bag 4', 168, 392, 46, 18)
	_SSAddId($ss_setup_ids, $gui_ss_bag1)
	_SSAddId($ss_setup_ids, $gui_ss_bag2)
	_SSAddId($ss_setup_ids, $gui_ss_bag3)
	_SSAddId($ss_setup_ids, $gui_ss_bag4)
	GUICtrlSetOnEvent($gui_ss_bag1, 'StorageSetupDraftChanged')
	GUICtrlSetOnEvent($gui_ss_bag2, 'StorageSetupDraftChanged')
	GUICtrlSetOnEvent($gui_ss_bag3, 'StorageSetupDraftChanged')
	GUICtrlSetOnEvent($gui_ss_bag4, 'StorageSetupDraftChanged')
	$id = GUICtrlCreateLabel('Reserve first', 24, 414, 72, 16)
	_SSAddId($ss_setup_ids, $id)
	$gui_ss_reserve = GUICtrlCreateInput('0', 96, 412, 28, 20)
	GUICtrlSetOnEvent($gui_ss_reserve, 'StorageSetupDraftChanged')
	_SSAddId($ss_setup_ids, $gui_ss_reserve)
	$id = GUICtrlCreateLabel('slots for kits / consumables', 128, 414, 84, 26)
	_SSAddId($ss_setup_ids, $id)
	GUICtrlCreateGroup('', -99, -99, 1, 1)

	_SSAddId($ss_setup_ids, GUICtrlCreateGroup('Sort', 222, 374, 204, 68))
	$id = GUICtrlCreateLabel('Manual only. One pane at a time, 0.10 s per move.', 230, 390, 94, 48)
	GUICtrlSetColor($id, $THEME_TEXT_DIM)
	_SSAddId($ss_setup_ids, $id)
	$gui_ss_sortnow = GUICtrlCreateButton('Sort now', 328, 410, 88, 24)
	ThemeSetButton($gui_ss_sortnow, $THEME_BTN_PRIMARY)
	GUICtrlSetOnEvent($gui_ss_sortnow, 'StorageSetupSortNow')
	_SSAddId($ss_setup_ids, $gui_ss_sortnow)
	GUICtrlCreateGroup('', -99, -99, 1, 1)

	_SSAddId($ss_setup_ids, GUICtrlCreateGroup('Sort rules', 432, 374, 198, 68))
	$id = GUICtrlCreateLabel('Order', 440, 392, 36, 16)
	_SSAddId($ss_setup_ids, $id)
	$gui_ss_order = GUICtrlCreateCombo('', 478, 390, 142, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	GUICtrlSetData($gui_ss_order, 'By type|By rarity|By model ID|By name', 'By type')
	GUICtrlSetOnEvent($gui_ss_order, 'StorageSetupDraftChanged')
	_SSAddId($ss_setup_ids, $gui_ss_order)
	$gui_ss_merge = GUICtrlCreateCheckbox('Merge stacks', 440, 414, 96, 18)
	_SSAddId($ss_setup_ids, $gui_ss_merge)
	GUICtrlSetOnEvent($gui_ss_merge, 'StorageSetupDraftChanged')
	$gui_ss_compact = GUICtrlCreateCheckbox('Compact slots', 536, 414, 90, 18)
	_SSAddId($ss_setup_ids, $gui_ss_compact)
	GUICtrlSetOnEvent($gui_ss_compact, 'StorageSetupDraftChanged')
	GUICtrlCreateGroup('', -99, -99, 1, 1)

	_SSSetIds($ss_setup_ids, $GUI_HIDE)
EndFunc

Func StorageSetupLayoutCaption()
	If $storage_sort_layout_name == '' Then Return 'Storage layout: (none)'
	Return 'Storage layout: ' & $storage_sort_layout_name
EndFunc

Func StorageSortCopySettings($src)
	; Re-parse through a map so arrays are duplicated
	Return StorageSortSettingsFromMap(StorageSortSettingsToMap($src))
EndFunc

Func StorageSetupFinishPage()
	; Called after ThemeApplyDark so gold group titles are classified.
	; Only hide setup controls here; leave Tools-tab children to the tab control
	; so they do not appear on Main at startup.
	Local $empty[1]
	$ss_tools_ids = $empty
	Local $lastID = GUICtrlCreateDummy()
	Local $id, $handle, $pos, $isSetup, $i, $gpos, $style, $class
	For $i = 1 To UBound($ss_setup_ids) - 1
		$handle = GUICtrlGetHandle($ss_setup_ids[$i])
		If $handle == 0 Then ContinueLoop
		$class = _WinAPI_GetClassName($handle)
		If $class <> 'Button' Then ContinueLoop
		$style = _WinAPI_GetWindowLong($handle, $GWL_STYLE)
		If BitAND($style, 0x0F) <> 7 Then ContinueLoop
		$gpos = ControlGetPos($gui_botshub, '', $handle)
		If @error Or Not IsArray($gpos) Then ContinueLoop
		For $id = 1 To $lastID - 1
			$pos = ControlGetPos($gui_botshub, '', GUICtrlGetHandle($id))
			If @error Or Not IsArray($pos) Then ContinueLoop
			If Abs($pos[0] - ($gpos[0] + 7)) <= 2 And Abs($pos[1] - $gpos[1]) <= 2 Then
				_SSAddId($ss_setup_ids, $id)
			EndIf
		Next
	Next
	For $id = 1 To $lastID - 1
		$handle = GUICtrlGetHandle($id)
		If $handle == 0 Or Not IsHWnd($handle) Then ContinueLoop
		$pos = ControlGetPos($gui_botshub, '', $handle)
		If @error Or Not IsArray($pos) Then ContinueLoop
		If $pos[1] < 34 Or $pos[1] > 444 Then ContinueLoop
		If $pos[0] < 8 Or $pos[0] > 640 Then ContinueLoop
		$isSetup = False
		For $i = 1 To UBound($ss_setup_ids) - 1
			If $ss_setup_ids[$i] == $id Then
				$isSetup = True
				ExitLoop
			EndIf
		Next
		If $isSetup Then ContinueLoop
		_SSAddId($ss_tools_ids, $id)
	Next
	For $id = 1 To $lastID - 1
		$handle = GUICtrlGetHandle($id)
		If $handle == 0 Or Not IsHWnd($handle) Then ContinueLoop
		$pos = ControlGetPos($gui_botshub, '', $handle)
		If @error Or Not IsArray($pos) Then ContinueLoop
		If $pos[1] < 34 Or $pos[1] > 444 Or $pos[0] < 8 Or $pos[0] > 640 Then ContinueLoop
		$isSetup = False
		For $i = 1 To UBound($ss_setup_ids) - 1
			If $ss_setup_ids[$i] == $id Then
				$isSetup = True
				ExitLoop
			EndIf
		Next
		If $isSetup Then ContinueLoop
		Local $isTools = False
		For $i = 1 To UBound($ss_tools_ids) - 1
			If $ss_tools_ids[$i] == $id Then
				$isTools = True
				ExitLoop
			EndIf
		Next
		If $isTools Then ContinueLoop
		_SSAddId($ss_setup_ids, $id)
	Next
	_SSSetIds($ss_setup_ids, $GUI_HIDE)
	$ss_page_open = False
	StorageSetupRefreshPage()
EndFunc

Func StorageSetupShow()
	If $gui_console Then
		ControlDisable($gui_botshub, '', $gui_console)
		ControlHide($gui_botshub, '', $gui_console)
	EndIf
	$storage_sort_draft = StorageSortCopySettings($storage_sort_applied)
	_SSSetIds($ss_tools_ids, $GUI_HIDE)
	_SSSetIds($ss_setup_ids, $GUI_SHOW)
	$ss_page_open = True
	StorageSetupSettingsToControls()
	StorageSetupRefreshPage()
EndFunc

Func StorageSetupHide()
	_SSSetIds($ss_setup_ids, $GUI_HIDE)
	_SSSetIds($ss_tools_ids, $GUI_SHOW)
	$ss_page_open = False
EndFunc

Func StorageSetupOnTabChange($tabIndex)
	; Tools is the 8th tab (1-based CurrentTab) / Case 7 (0-based GUICtrlRead of the tab control)
	If $ss_page_open And $tabIndex <> 7 Then StorageSetupHide()
EndFunc

Func StorageSetupSelectPane()
	Local $id = @GUI_CtrlId
	Local $p
	For $p = 0 To 14
		If $id = $gui_ss_paneBg[$p] Or $id = $gui_ss_paneName[$p] Or $id = $gui_ss_paneSum[$p] Then
			If $storage_sort_scanned And Not $storage_sort_unlocked[$STORAGE_SORT_PANE_NAMES[$p]] Then Return
			$ss_sel = $p
			StorageSetupRefreshPage()
			Return
		EndIf
	Next
EndFunc

Func StorageSetupTypeToggled()
	If $ss_updating Then Return
	StorageSetupControlsToDraft()
	StorageSetupRefreshPage()
EndFunc

Func StorageSetupDraftChanged()
	If $ss_updating Then Return
	StorageSetupControlsToDraft()
	StorageSetupRefreshPage()
EndFunc

Func StorageSetupControlsToDraft()
	If Not IsMap($storage_sort_draft) Then $storage_sort_draft = StorageSortDefaultSettings()
	$storage_sort_draft['reserve_slots'] = Number(GUICtrlRead($gui_ss_reserve))
	If $storage_sort_draft['reserve_slots'] < 0 Then $storage_sort_draft['reserve_slots'] = 0
	Local $bags[0]
	If GUICtrlRead($gui_ss_bag1) = $GUI_CHECKED Then _ArrayAdd($bags, 1)
	If GUICtrlRead($gui_ss_bag2) = $GUI_CHECKED Then _ArrayAdd($bags, 2)
	If GUICtrlRead($gui_ss_bag3) = $GUI_CHECKED Then _ArrayAdd($bags, 3)
	If GUICtrlRead($gui_ss_bag4) = $GUI_CHECKED Then _ArrayAdd($bags, 4)
	$storage_sort_draft['bags'] = $bags
	$storage_sort_draft['order'] = GUICtrlRead($gui_ss_order)
	$storage_sort_draft['merge_stacks'] = (GUICtrlRead($gui_ss_merge) = $GUI_CHECKED)
	$storage_sort_draft['compact_slots'] = (GUICtrlRead($gui_ss_compact) = $GUI_CHECKED)
	$storage_sort_draft['if_full'] = GUICtrlRead($gui_ss_overflow)
	Local $types[0], $t
	For $t = 0 To UBound($STORAGE_SORT_TYPES) - 1
		If GUICtrlRead($gui_ss_type[$t]) = $GUI_CHECKED Then _ArrayAdd($types, $STORAGE_SORT_TYPES[$t])
	Next
	$storage_sort_draft['types_' & $STORAGE_SORT_PANE_NAMES[$ss_sel]] = StorageSortSanitizeTypes($types)
	StorageSortPresetMaterials($storage_sort_draft)
EndFunc

Func StorageSetupSettingsToControls()
	$ss_updating = True
	Local $s = $storage_sort_draft
	If GUICtrlRead($gui_ss_reserve) <> -1 Then
		GUICtrlSetData($gui_ss_reserve, $s['reserve_slots'])
		Local $bags = $s['bags']
		GUICtrlSetState($gui_ss_bag1, StorageSetupBagChecked($bags, 1))
		GUICtrlSetState($gui_ss_bag2, StorageSetupBagChecked($bags, 2))
		GUICtrlSetState($gui_ss_bag3, StorageSetupBagChecked($bags, 3))
		GUICtrlSetState($gui_ss_bag4, StorageSetupBagChecked($bags, 4))
		GUICtrlSetData($gui_ss_order, $s['order'])
		If $s['merge_stacks'] Then
			GUICtrlSetState($gui_ss_merge, $GUI_CHECKED)
		Else
			GUICtrlSetState($gui_ss_merge, $GUI_UNCHECKED)
		EndIf
		If $s['compact_slots'] Then
			GUICtrlSetState($gui_ss_compact, $GUI_CHECKED)
		Else
			GUICtrlSetState($gui_ss_compact, $GUI_UNCHECKED)
		EndIf
		GUICtrlSetData($gui_ss_overflow, $s['if_full'])
	EndIf
	StorageSetupLoadChecks()
	$ss_updating = False
EndFunc

Func StorageSetupBagChecked($bags, $n)
	If Not IsArray($bags) Then Return $GUI_UNCHECKED
	Local $i
	For $i = 0 To UBound($bags) - 1
		If Number($bags[$i]) == $n Then Return $GUI_CHECKED
	Next
	Return $GUI_UNCHECKED
EndFunc

Func StorageSetupLoadChecks()
	$ss_updating = True
	StorageSortPresetMaterials($storage_sort_draft)
	Local $types = $storage_sort_draft['types_' & $STORAGE_SORT_PANE_NAMES[$ss_sel]]
	Local $t
	For $t = 0 To UBound($STORAGE_SORT_TYPES) - 1
		If $ss_sel == 14 Or ($storage_sort_scanned And Not $storage_sort_unlocked[$STORAGE_SORT_PANE_NAMES[$ss_sel]]) Then
			GUICtrlSetState($gui_ss_type[$t], $GUI_DISABLE)
		Else
			GUICtrlSetState($gui_ss_type[$t], $GUI_ENABLE)
		EndIf
		If StorageSortArrayHasStr($types, $STORAGE_SORT_TYPES[$t]) Then
			GUICtrlSetState($gui_ss_type[$t], $GUI_CHECKED)
		Else
			GUICtrlSetState($gui_ss_type[$t], $GUI_UNCHECKED)
		EndIf
	Next
	$ss_updating = False
EndFunc

Func StorageSetupPaneSummary($p)
	Local $name = $STORAGE_SORT_PANE_NAMES[$p]
	If Not $storage_sort_scanned Then Return 'not scanned yet'
	If Not $storage_sort_unlocked[$name] Then Return 'N/A (locked)'
	If $name == 'Material storage' Then Return 'Mats + rare (auto)'
	Local $types = $storage_sort_draft['types_' & $name]
	If Not IsArray($types) Or UBound($types) == 0 Then Return '(empty)'
	Local $parts = '', $i, $short, $ord, $total, $idx, $t
	For $i = 0 To UBound($types) - 1
		$t = $types[$i]
		$short = $t
		If $t == 'Rare materials' Then $short = 'rare mats'
		If $t == 'Festival items' Then $short = 'festival'
		If $t == 'Salvage / ID kits' Then $short = 'kits'
		$total = 0
		$ord = 0
		For $idx = 0 To 14
			If StorageSortPaneHasType($storage_sort_draft, $STORAGE_SORT_PANE_NAMES[$idx], $t) Then
				$total += 1
				If $idx == $p Then $ord = $total
			EndIf
		Next
		If $total > 1 Then $short &= ' ' & $ord & '/' & $total
		If $parts <> '' Then $parts &= ', '
		$parts &= $short
	Next
	Return $parts
EndFunc

Func StorageSetupRefreshPage()
	If $gui_ss_paneTitle == 0 Then Return
	Local $p, $sum, $bk, $nc, $sc, $locked, $pending, $name
	For $p = 0 To 14
		$name = $STORAGE_SORT_PANE_NAMES[$p]
		$sum = StorageSetupPaneSummary($p)
		GUICtrlSetData($gui_ss_paneSum[$p], $sum)
		$locked = $storage_sort_scanned And Not $storage_sort_unlocked[$name]
		$pending = Not $storage_sort_scanned
		If $locked Then
			$bk = $THEME_PANEL_BG
			$nc = $THEME_TEXT_DISABLED
			$sc = $THEME_TEXT_DISABLED
		ElseIf $pending Then
			If $p = $ss_sel Then
				$bk = $THEME_INPUT_BG
			Else
				$bk = $THEME_PANEL_BG
			EndIf
			$nc = $THEME_TEXT_DIM
			$sc = $THEME_TEXT_DIM
		ElseIf $p = $ss_sel Then
			$bk = $THEME_INPUT_BG
			$nc = $THEME_TEXT
			$sc = $THEME_TEXT
		Else
			$bk = $THEME_PANEL_BG
			$nc = $THEME_TEXT
			If $sum == '(empty)' Then
				$sc = $THEME_TEXT_DIM
			Else
				$sc = $THEME_TEXT
			EndIf
		EndIf
		GUICtrlSetBkColor($gui_ss_paneBg[$p], $bk)
		GUICtrlSetBkColor($gui_ss_paneName[$p], $bk)
		GUICtrlSetBkColor($gui_ss_paneSum[$p], $bk)
		GUICtrlSetColor($gui_ss_paneName[$p], $nc)
		GUICtrlSetColor($gui_ss_paneSum[$p], $sc)
	Next
	If $storage_sort_scanned And Not $storage_sort_unlocked[$STORAGE_SORT_PANE_NAMES[$ss_sel]] Then
		GUICtrlSetState($gui_ss_selbar, $GUI_HIDE)
	Else
		GUICtrlSetPos($gui_ss_selbar, 86, 102 + $ss_sel * 15, 3, 15)
		GUICtrlSetBkColor($gui_ss_selbar, $THEME_ACCENT_GOLD)
		GUICtrlSetState($gui_ss_selbar, $GUI_SHOW)
	EndIf
	GUICtrlSetData($gui_ss_lastscan, $storage_sort_lastscan)
	GUICtrlSetData($gui_ss_layout, StorageSetupLayoutCaption())
	GUICtrlSetData($gui_ss_paneTitle, 'Pane ' & $STORAGE_SORT_PANE_NAMES[$ss_sel])
	GUICtrlSetData($gui_ss_paneHint, $ss_sel == 14 ? 'Automatic: Materials + Rare materials (locked).' : 'Mix types here. Shared types fill panes in list order.')
	StorageSetupLoadChecks()
	StorageSetupRefreshFill()
	StorageSetupRefreshNote()
EndFunc

Func StorageSetupRefreshNote()
	Local $pane = $STORAGE_SORT_PANE_NAMES[$ss_sel]
	Local $types = $storage_sort_draft['types_' & $pane]
	Local $note = 'Unassigned types stay in bags.'
	If IsArray($types) And UBound($types) > 0 Then
		Local $t, $i, $n, $ord, $chain, $p, $lines = ''
		For $t = 0 To UBound($types) - 1
			$chain = ''
			$n = 0
			$ord = 0
			For $p = 0 To 14
				If Not StorageSortPaneHasType($storage_sort_draft, $STORAGE_SORT_PANE_NAMES[$p], $types[$t]) Then ContinueLoop
				$n += 1
				If $p == $ss_sel Then $ord = $n
				If $chain <> '' Then $chain &= ' -> '
				$chain &= $STORAGE_SORT_PANE_NAMES[$p]
			Next
			If $n > 1 Then
				If $lines <> '' Then $lines &= @CRLF
				$lines &= $types[$t] & ': ' & $chain & ' (' & $ord & ' of ' & $n & ')'
			EndIf
		Next
		If $lines <> '' Then $note = $lines
	EndIf
	If $ss_sel == 14 Then $note = 'Fixed material slots; paced per-item deposit.'
	GUICtrlSetData($gui_ss_paneNote, $note)
EndFunc

Func StorageSetupRefreshFill()
	Local $t, $p, $chain, $n, $shared, $singleByPane[15], $i
	$shared = ''
	For $i = 0 To 14
		$singleByPane[$i] = ''
	Next
	For $t = 0 To UBound($STORAGE_SORT_TYPES) - 1
		$chain = ''
		$n = 0
		Local $lastP = -1
		For $p = 0 To 14
			If Not StorageSortPaneHasType($storage_sort_draft, $STORAGE_SORT_PANE_NAMES[$p], $STORAGE_SORT_TYPES[$t]) Then ContinueLoop
			If $chain <> '' Then $chain &= ' -> '
			$chain &= $STORAGE_SORT_PANE_NAMES[$p]
			$n += 1
			$lastP = $p
		Next
		If $n = 0 Then ContinueLoop
		If $n > 1 Then
			If $shared <> '' Then $shared &= '    '
			$shared &= $STORAGE_SORT_TYPES[$t] & ': ' & $chain
		Else
			If $singleByPane[$lastP] <> '' Then $singleByPane[$lastP] &= ', '
			Local $short = $STORAGE_SORT_TYPES[$t]
			If $short == 'Rare materials' Then $short = 'rare mats'
			If $short == 'Festival items' Then $short = 'festival'
			If $short == 'Salvage / ID kits' Then $short = 'kits'
			$singleByPane[$lastP] &= $short
		EndIf
	Next
	If $shared == '' Then $shared = 'No type uses more than one pane yet.'
	GUICtrlSetData($gui_ss_fill1, $shared)
	Local $singles = ''
	For $p = 0 To 14
		If $singleByPane[$p] == '' Then ContinueLoop
		If $singles <> '' Then $singles &= '  ·  '
		$singles &= $singleByPane[$p] & ': ' & $STORAGE_SORT_PANE_NAMES[$p]
	Next
	GUICtrlSetData($gui_ss_fill2, $singles)
EndFunc

Func StorageSetupApply()
	StorageSetupControlsToDraft()
	$storage_sort_applied = StorageSortCopySettings($storage_sort_draft)
	$storage_sort_applied['layout_name'] = $storage_sort_layout_name
	Info('Applied storage layout' & ($storage_sort_layout_name == '' ? '' : ' ' & $storage_sort_layout_name))
EndFunc

Func StorageSetupLoad()
	Local $filePath = FileOpenDialog('Please select a storage layout', @ScriptDir & '\conf\storage', '(*.json)')
	If @error <> 0 Then
		Warn('Failed to read storage layout.')
		Return
	EndIf
	DirCreate(@ScriptDir & '\conf\storage')
	$storage_sort_draft = StorageSortLoadFromFile($filePath)
	$storage_sort_applied = StorageSortCopySettings($storage_sort_draft)
	$storage_sort_layout_name = StringTrimLeft($filePath, StringInStr($filePath, '\', 0, -1))
	If $storage_sort_layout_name == $filePath Then $storage_sort_layout_name = StringTrimLeft($filePath, StringInStr($filePath, '/', 0, -1))
	$storage_sort_applied['layout_name'] = $storage_sort_layout_name
	StorageSetupSettingsToControls()
	StorageSetupRefreshPage()
	Info('Loaded storage layout ' & $filePath)
EndFunc

Func StorageSetupSave()
	StorageSetupControlsToDraft()
	DirCreate(@ScriptDir & '\conf\storage')
	Local $filePath = FileSaveDialog('', @ScriptDir & '\conf\storage', '(*.json)')
	If @error <> 0 Then
		Warn('Failed to write storage layout.')
		Return
	EndIf
	If StringRight($filePath, 5) <> '.json' Then $filePath &= '.json'
	If Not StorageSortSaveToFile($storage_sort_draft, $filePath) Then
		Warn('Failed to write storage layout.')
		Return
	EndIf
	$storage_sort_layout_name = StringTrimLeft($filePath, StringInStr($filePath, '\', 0, -1))
	If $storage_sort_layout_name == $filePath Then $storage_sort_layout_name = StringTrimLeft($filePath, StringInStr($filePath, '/', 0, -1))
	GUICtrlSetData($gui_ss_layout, StorageSetupLayoutCaption())
	Info('Saved storage layout ' & $filePath)
EndFunc

Func StorageSetupScan()
	If Not IsAttachedForTools() Then Return
	If GetMapType() <> $ID_OUTPOST Or GetMyID() == 0 Then
		Warn('[Storage Sort] Scan storage in an outpost or town so the Xunlai panes can be read.')
		Return
	EndIf
	OpenXunlaiWindow()
	Sleep(300 + GetPing())
	StorageSortScanPanes()
	StorageSetupRefreshPage()
	Info('[Storage Sort] Scanned Xunlai panes')
EndFunc

Func StorageSetupSortNow()
	; Sort now uses the last applied layout, like Inventory Apply
	StorageSortNow('Sort now')
EndFunc
