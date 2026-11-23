#CS ===========================================================================
; v31: dark theme for the BotsHub GUI. Colours: lib/BotsHub-Theme-Colors.au3 (central constants).
;
; ThemeApplyDark() runs once after the GUI is built and walks every control of the window:
;   - labels: light text (values in light blue) on the background they sit on (tab page or window bar)
;   - group boxes / checkboxes / radios: visual styles switched off for that control (uxtheme SetWindowTheme '', ''),
;     otherwise Windows' themed drawing ignores GUICtrlSetColor and paints black text; then gold titles / light text
;   - push buttons: dark buttons with light text (accent buttons registered with ThemeSetButton keep their colour)
;   - edits / inputs / combos / list views / tree view / progress bar: dark background, light text
;   - tab control: subclassed WM_PAINT draws the header strip dark (selected tab lighter, gold text) and a dark frame
; Tree item branch titles (gold) are coloured by ThemeColorTreeBranches after every (re)build of the loot tree.
; Not themeable from AutoIt (documented in ANALYSIS 27): the ListView column header strip and the combo drop-down
; arrows keep the system look on Windows < 10 1809 / Wine; scrollbars stay system-coloured.
#CE ===========================================================================
#include-once
#include <WinAPI.au3>
#include <WinAPISysWin.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <GuiTab.au3>
#include <GuiTreeView.au3>
#include <GuiListView.au3>
#include <WinAPIGdi.au3>
#include <WinAPIGdiDC.au3>
#include <SendMessage.au3>
#include 'BotsHub-Theme-Colors.au3'

Global $theme_dark_enabled = True
; control ID -> True for buttons whose colour is set by ThemeSetButton (state colours); the generic pass leaves them
Global $theme_accent_buttons[]
; control ID -> True for the tab-page background labels (_GUICtrlTab_SetBkColor)
Global $theme_page_labels[]
Global $theme_tab_control = 0
; group boxes seen by the theme pass (their titles become gold labels, see ThemeGroupTitles)
Global $theme_groups[]
Global $theme_tab_brush = 0, $theme_tab_sel_brush = 0, $theme_window_brush = 0
Global $theme_tab_callback = 0, $theme_tab_oldproc = 0


;~ Colours an accent push button (and remembers it so the generic pass keeps it)
Func ThemeSetButton($controlID, $background, $text = $THEME_TEXT)
	$theme_accent_buttons[$controlID] = True
	GUICtrlSetBkColor($controlID, $background)
	GUICtrlSetColor($controlID, $text)
EndFunc


;~ Visual styles off for one window (classic drawing honours WM_CTLCOLOR* colours)
Func ThemeDisableVisualStyle($handle)
	DllCall('uxtheme.dll', 'int', 'SetWindowTheme', 'hwnd', $handle, 'wstr', '', 'wstr', '')
EndFunc


;~ Background a control sits on: the tab page when its top-left corner is inside the tab control's page area, else the
;~ window bar (bottom row, config combo)
Func ThemeBackgroundAt($gui, $controlID)
	If $theme_tab_control == 0 Then Return $THEME_WINDOW_BG
	Local $pos = ControlGetPos($gui, '', GUICtrlGetHandle($controlID))
	If @error Or Not IsArray($pos) Then Return $THEME_WINDOW_BG
	Local $tab = ControlGetPos($gui, '', GUICtrlGetHandle($theme_tab_control))
	If @error Or Not IsArray($tab) Then Return $THEME_WINDOW_BG
	If $pos[0] >= $tab[0] And $pos[0] < $tab[0] + $tab[2] And $pos[1] >= $tab[1] + 24 And $pos[1] < $tab[1] + $tab[3] Then Return $THEME_PANEL_BG
	Return $THEME_WINDOW_BG
EndFunc


;~ Applies the dark theme to every control of $gui. $tabControl = the GUICtrlCreateTab ID (dark-painted headers),
;~ $tabItems = array of its GUICtrlCreateTabItem IDs in creation order (group titles are re-created inside their tab).
Func ThemeApplyDark($gui, $tabControl = 0, $tabItems = Null)
	If Not $theme_dark_enabled Then Return
	$theme_tab_control = $tabControl
	GUISetBkColor($THEME_WINDOW_BG, $gui)
	Local $lastID = GUICtrlCreateDummy()
	For $id = 1 To $lastID - 1
		Local $handle = GUICtrlGetHandle($id)
		If $handle == 0 Or Not IsHWnd($handle) Or Not _WinAPI_IsWindow($handle) Then ContinueLoop
		ThemeControl($gui, $id, $handle)
	Next
	ThemeGroupTitles($gui, $tabItems)
	If $tabControl <> 0 Then ThemeOwnerDrawTabs($tabControl)
EndFunc


;~ Group box titles in gold. Classic group boxes ignore GUICtrlSetColor on some systems (Wine draws them black even with
;~ visual styles off), so the title is moved to a gold label drawn over the frame, created in the group's own tab item
;~ (so it shows / hides with its page). The group keeps an empty caption; its frame stays.
Func ThemeGroupTitles($gui, $tabItems)
	For $groupID In MapKeys($theme_groups)
		Local $handle = GUICtrlGetHandle($groupID)
		Local $title = _WinAPI_GetWindowText($handle)
		If $title == '' Then ContinueLoop
		Local $pos = ControlGetPos($gui, '', $handle)
		If @error Or Not IsArray($pos) Or $pos[0] < 0 Then ContinueLoop
		; owning tab item = the last tab item created before the group
		Local $owner = 0
		If IsArray($tabItems) Then
			For $tabItem In $tabItems
				If $tabItem < $groupID And $tabItem > $owner Then $owner = $tabItem
			Next
			If $owner == 0 Then ContinueLoop
		EndIf
		Local $size = ThemeTextSize($handle, $title)
		GUICtrlSetData($groupID, '')
		If $owner <> 0 Then GUISwitch($gui, $owner)
		Local $label = GUICtrlCreateLabel($title, $pos[0] + 7, $pos[1], $size[0] + 4, $size[1])
		GUICtrlSetColor($label, $THEME_ACCENT_GOLD)
		GUICtrlSetBkColor($label, ThemeBackgroundAt($gui, $groupID))
		If $owner <> 0 Then GUICtrlCreateTabItem('')
	Next
	GUISwitch($gui)
EndFunc


;~ Pixel size [width, height] of $text in the font of window $handle
Func ThemeTextSize($handle, $text)
	Local $size[2] = [StringLen($text) * 7, 14]
	Local $hDC = _WinAPI_GetDC($handle)
	If $hDC == 0 Then Return $size
	Local $font = _SendMessage($handle, $WM_GETFONT)
	Local $oldFont = 0
	If $font <> 0 Then $oldFont = _WinAPI_SelectObject($hDC, $font)
	Local $extent = _WinAPI_GetTextExtentPoint32($hDC, $text)
	If IsDllStruct($extent) Then
		$size[0] = DllStructGetData($extent, 1)
		$size[1] = DllStructGetData($extent, 2)
	EndIf
	If $oldFont <> 0 Then _WinAPI_SelectObject($hDC, $oldFont)
	_WinAPI_ReleaseDC($handle, $hDC)
	Return $size
EndFunc


;~ One control (by window class and style)
Func ThemeControl($gui, $id, $handle)
	Local $class = _WinAPI_GetClassName($handle)
	Local $style = _WinAPI_GetWindowLong($handle, $GWL_STYLE)
	Switch $class
		Case 'Static'
			If MapExists($theme_page_labels, $id) Then
				GUICtrlSetBkColor($id, $THEME_PANEL_BG)
				Return
			EndIf
			Local $type = BitAND($style, 0x1F)
			; pictures / icons / frames (SS_ICON 3, SS_BITMAP 0x0E, SS_ENHMETAFILE 0x0F, SS_ETCHED*) keep their look
			If $type == 0x03 Or $type == 0x0E Or $type == 0x0F Or $type >= 0x10 Then Return
			GUICtrlSetBkColor($id, ThemeBackgroundAt($gui, $id))
			; right-aligned labels are the Informations values
			GUICtrlSetColor($id, $type == 0x02 ? $THEME_VALUE : $THEME_TEXT)
		Case 'Button'
			Local $kind = BitAND($style, 0x0F)
			Switch $kind
				Case 7 ; group box: gold title (ThemeGroupTitles)
					$theme_groups[$id] = True
					ThemeDisableVisualStyle($handle)
					GUICtrlSetColor($id, $THEME_ACCENT_GOLD)
					GUICtrlSetBkColor($id, ThemeBackgroundAt($gui, $id))
				Case 2, 3, 4, 5, 6, 9 ; checkbox, auto checkbox, radio, 3-state, auto 3-state, auto radio
					ThemeDisableVisualStyle($handle)
					GUICtrlSetColor($id, $THEME_TEXT)
					GUICtrlSetBkColor($id, ThemeBackgroundAt($gui, $id))
				Case Else ; push buttons
					If MapExists($theme_accent_buttons, $id) Then Return
					GUICtrlSetBkColor($id, $THEME_BUTTON_BG)
					GUICtrlSetColor($id, $THEME_TEXT)
			EndSwitch
		Case 'Edit'
			GUICtrlSetBkColor($id, $THEME_INPUT_BG)
			GUICtrlSetColor($id, $THEME_TEXT)
		Case 'ComboBox'
			ThemeDisableVisualStyle($handle)
			GUICtrlSetBkColor($id, $THEME_INPUT_BG)
			GUICtrlSetColor($id, $THEME_TEXT)
		Case 'SysListView32'
			GUICtrlSetBkColor($id, $THEME_INPUT_BG)
			GUICtrlSetColor($id, $THEME_TEXT)
			_GUICtrlListView_SetBkColor($handle, ThemeBGR($THEME_INPUT_BG))
			_GUICtrlListView_SetTextBkColor($handle, ThemeBGR($THEME_INPUT_BG))
			_GUICtrlListView_SetTextColor($handle, ThemeBGR($THEME_TEXT))
			; Windows 10 1809+ draws a dark header with this theme class; elsewhere (Wine, older Windows) it is ignored
			Local $header = _GUICtrlListView_GetHeader($handle)
			If $header <> 0 Then DllCall('uxtheme.dll', 'int', 'SetWindowTheme', 'hwnd', $header, 'wstr', 'DarkMode_ItemsView', 'ptr', 0)
		Case 'SysTreeView32'
			GUICtrlSetBkColor($id, $THEME_INPUT_BG)
			GUICtrlSetColor($id, $THEME_TEXT)
			_GUICtrlTreeView_SetLineColor($handle, ThemeBGR($THEME_TEXT_DIM))
		Case 'msctls_progress32'
			ThemeDisableVisualStyle($handle)
			GUICtrlSetBkColor($id, $THEME_INPUT_BG)
			GUICtrlSetColor($id, $THEME_BTN_PRIMARY)
			_SendMessage($handle, 0x2001, 0, ThemeBGR($THEME_INPUT_BG))		; PBM_SETBKCOLOR
			_SendMessage($handle, 0x0409, 0, ThemeBGR($THEME_BTN_PRIMARY))	; PBM_SETBARCOLOR
	EndSwitch
EndFunc


;~ Gold text for tree items that have children (section / branch titles), light text for leaves
Func ThemeColorTreeBranches($treeViewID)
	If Not $theme_dark_enabled Then Return
	Local $handle = GUICtrlGetHandle($treeViewID)
	Local $item = _GUICtrlTreeView_GetFirstItem($handle)
	While $item <> 0
		Local $itemID = _GUICtrlTreeView_GetItemParam($handle, $item)
		If $itemID > 0 Then GUICtrlSetColor($itemID, _GUICtrlTreeView_GetChildren($handle, $item) ? $THEME_ACCENT_GOLD : $THEME_TEXT)
		$item = _GUICtrlTreeView_GetNext($handle, $item)
	WEnd
EndFunc


;~ Tab control: visual styles off and the window procedure subclassed so the header strip (tabs, the gaps between
;~ them, the empty area right of the last tab) and the page are painted dark by ThemePaintTabStrip (pages without a
;~ _GUICtrlTab_SetBkColor label show the tab control itself).
Func ThemeOwnerDrawTabs($tabControl)
	Local $handle = GUICtrlGetHandle($tabControl)
	ThemeDisableVisualStyle($handle)
	If $theme_tab_brush == 0 Then $theme_tab_brush = _WinAPI_CreateSolidBrush(ThemeBGR($THEME_WINDOW_BG))
	If $theme_tab_sel_brush == 0 Then $theme_tab_sel_brush = _WinAPI_CreateSolidBrush(ThemeBGR($THEME_PANEL_BG))
	If $theme_window_brush == 0 Then $theme_window_brush = _WinAPI_CreateSolidBrush(ThemeBGR($THEME_BUTTON_BG))
	If $theme_tab_callback == 0 Then
		$theme_tab_callback = DllCallbackRegister('ThemeTabWndProc', 'lresult', 'hwnd;uint;wparam;lparam')
		$theme_tab_oldproc = _WinAPI_SetWindowLong($handle, $GWL_WNDPROC, DllCallbackGetPtr($theme_tab_callback))
	EndIf
	_WinAPI_InvalidateRect($handle)
EndFunc


;~ Subclassed tab control window procedure
Func ThemeTabWndProc($hWnd, $message, $wParam, $lParam)
	Switch $message
		Case $WM_ERASEBKGND
			Return 1
		Case $WM_PAINT
			Local $paintStruct = DllStructCreate($tagPAINTSTRUCT)
			Local $hDC = _WinAPI_BeginPaint($hWnd, $paintStruct)
			ThemePaintTabStrip($hWnd, $hDC)
			_WinAPI_EndPaint($hWnd, $paintStruct)
			Return 0
	EndSwitch
	Return _WinAPI_CallWindowProc($theme_tab_oldproc, $hWnd, $message, $wParam, $lParam)
EndFunc


;~ Paints the tab headers, the page and its frame
Func ThemePaintTabStrip($hWnd, $hDC)
	Local $client = _WinAPI_GetClientRect($hWnd)
	Local $width = DllStructGetData($client, 3), $height = DllStructGetData($client, 4)
	Local $count = _GUICtrlTab_GetItemCount($hWnd)
	Local $selected = _GUICtrlTab_GetCurSel($hWnd)
	Local $stripBottom = 22
	If $count > 0 Then
		Local $first = _GUICtrlTab_GetItemRect($hWnd, 0)
		$stripBottom = $first[3]
	EndIf
	Local $rect = DllStructCreate($tagRECT)
	DllStructSetData($rect, 1, 0)
	DllStructSetData($rect, 2, 0)
	DllStructSetData($rect, 3, $width)
	DllStructSetData($rect, 4, $height)
	_WinAPI_FillRect($hDC, $rect, $theme_tab_brush)
	; page frame: panel colour with a thin lighter outline
	DllStructSetData($rect, 2, $stripBottom)
	_WinAPI_FillRect($hDC, $rect, $theme_tab_sel_brush)
	_WinAPI_FrameRect($hDC, $rect, $theme_window_brush)
	Local $font = _SendMessage($hWnd, $WM_GETFONT)
	Local $oldFont = 0
	If $font <> 0 Then $oldFont = _WinAPI_SelectObject($hDC, $font)
	_WinAPI_SetBkMode($hDC, $TRANSPARENT)
	For $i = 0 To $count - 1
		Local $item = _GUICtrlTab_GetItemRect($hWnd, $i)
		DllStructSetData($rect, 1, $item[0])
		DllStructSetData($rect, 2, $item[1] + ($i == $selected ? 0 : 2))
		DllStructSetData($rect, 3, $item[2])
		DllStructSetData($rect, 4, $item[3] + ($i == $selected ? 1 : 0))
		_WinAPI_FillRect($hDC, $rect, $i == $selected ? $theme_tab_sel_brush : $theme_window_brush)
		_WinAPI_SetTextColor($hDC, ThemeBGR($i == $selected ? $THEME_ACCENT_GOLD : $THEME_TEXT))
		_WinAPI_DrawText($hDC, _GUICtrlTab_GetItemText($hWnd, $i), $rect, BitOR($DT_CENTER, $DT_VCENTER, $DT_SINGLELINE))
	Next
	If $oldFont <> 0 Then _WinAPI_SelectObject($hDC, $oldFont)
EndFunc
