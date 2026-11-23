#CS ===========================================================================
; v31: BotsHub dark theme - the ONE place where GUI colours are defined (AMG: "invert the way the gui color is, so its
; with white text" + "you can use other than white text for different things").
; AutoIt GUI functions take 0xRRGGBB; RichEdit char colours and ListView custom draw take COLORREF 0xBBGGRR - use ThemeBGR().
; No dependencies: included by Utils-Console (log colours), Utils-ItemsPanel (panel colours) and BotsHub-Theme (the rest).
#CE ===========================================================================
#include-once

; surfaces
Global Const $THEME_WINDOW_BG		= 0x1B1D21	; window around the tabs, bottom bar
Global Const $THEME_PANEL_BG		= 0x25282D	; tab pages, group boxes, labels on them
Global Const $THEME_INPUT_BG		= 0x30343A	; edits, inputs, combos, lists, tree, Items panel
Global Const $THEME_CONSOLE_BG		= 0x121417	; log console
Global Const $THEME_BUTTON_BG		= 0x3A3F47	; normal push buttons
; text
Global Const $THEME_TEXT			= 0xF2F3F5	; normal text (near white)
Global Const $THEME_TEXT_DIM		= 0xB9BEC6	; secondary text / tree lines
Global Const $THEME_TEXT_DISABLED	= 0x7D828A	; disabled-looking / zero / placeholder
Global Const $THEME_ACCENT_GOLD		= 0xE8B54D	; group titles, section headers, tree branch titles
Global Const $THEME_VALUE			= 0x7FD3FF	; values / totals (light blue)
Global Const $THEME_POSITIVE		= 0x5FD98F	; Session +N
Global Const $THEME_NEGATIVE		= 0xFF7B72	; Session -N
Global Const $THEME_HEADER_ROW_BG	= 0x3B3324	; Items panel category rows (dark gold tint)
; accent buttons (background; text is $THEME_TEXT unless noted)
Global Const $THEME_BTN_PRIMARY		= 0x2F6FD0	; Start, Open Storage, Manual mode
Global Const $THEME_BTN_DANGER		= 0xA4413F	; Pause
Global Const $THEME_BTN_WAITING		= 0x8C7426	; 'Will pause after this run'
Global Const $THEME_BTN_WARNING		= 0xC9962B	; Apply changes, Disable Graphics (text $THEME_BTN_WARNING_TEXT)
Global Const $THEME_BTN_WARNING_TEXT	= 0x1B1D21
Global Const $THEME_BTN_SUCCESS		= 0x2F8F57	; Enable Graphics
; log console levels (0xRRGGBB, converted with ThemeBGR for the RichEdit)
Global Const $THEME_LOG_DEBUG		= 0x8FD694	; soft green
Global Const $THEME_LOG_INFO		= 0xE6E8EB	; light grey/white
Global Const $THEME_LOG_NOTICE		= 0x5CD6E0	; cyan
Global Const $THEME_LOG_WARNING		= 0xF2C14E	; amber
Global Const $THEME_LOG_ERROR		= 0xFF6B6B	; soft red


;~ 0xRRGGBB -> COLORREF 0xBBGGRR (RichEdit, ListView custom draw, Win32 messages)
Func ThemeBGR($rgb)
	Return BitOR(BitShift(BitAND($rgb, 0xFF), -16), BitAND($rgb, 0xFF00), BitShift(BitAND($rgb, 0xFF0000), 16))
EndFunc
