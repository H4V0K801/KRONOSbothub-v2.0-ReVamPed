#CS ===========================================================================
; Author: caustic-kronos (aka Kronos, Night, Svarog)
; Contributor: Gahais
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

; GUI built with GuiBuilderPlus
#CE ===========================================================================

Opt('GUIOnEventMode', True)
Opt('GUICloseOnESC', False)

#Region Includes
#include-once
#include <GUIConstantsEx.au3>
#include <GuiListBox.au3>
#include <StaticConstants.au3>
#include <ButtonConstants.au3>
#include <WindowsConstants.au3>
#include <ComboConstants.au3>
#include <Array.au3>
#include <GuiTab.au3>
#include <GuiRichEdit.au3>
#include <GuiTreeView.au3>
#include <GuiComboBox.au3>

#include '../lib/JSON.au3'
#include '../lib/GWA2.au3'
#include '../lib/GWA2_Assembly.au3'
#include '../lib/GWA2_ID_Items.au3'
#include '../lib/Utils.au3'
#include '../lib/Utils-Console.au3'
#include '../lib/Utils-Items_Modstructs.au3'
#include '../lib/Utils-Storage.au3'
#include '../lib/Utils-ItemsPanel.au3'
#include '../lib/BotsHub-Theme.au3'
#include '../lib/BotsHub-BuildInfo.au3'

#include '../src/farms/CoF.au3'
#include '../src/farms/Corsairs.au3'
#include '../src/farms/DrakeFlesh.au3'
#include '../src/farms/DragonMoss.au3'
#include '../src/farms/EdenIris.au3'
#include '../src/farms/Feathers.au3'
#include '../src/farms/FoWTowerOfCourage.au3'
#include '../src/farms/Gemstones.au3'
#include '../src/farms/GemstoneMargonite.au3'
#include '../src/farms/GemstoneStygian.au3'
#include '../src/farms/GemstoneTorment.au3'
#include '../src/farms/JadeBrotherhood.au3'
#include '../src/farms/Kournans.au3'
#include '../src/farms/Lightbringer-Sunspear.au3'
#include '../src/farms/Lightbringer.au3'
#include '../src/farms/Mantids.au3'
#include '../src/farms/Minotaurs.au3'
#include '../src/farms/Raptors.au3'
#include '../src/farms/SpiritSlaves.au3'
#include '../src/farms/Vaettirs.au3'
#include '../src/missions/Deldrimor.au3'
#include '../src/missions/FoW.au3'
#include '../src/missions/Froggy.au3'
#include '../src/missions/GlintChallenge.au3'
#include '../src/missions/Kilroy.au3'
#include '../src/missions/MinisterialCommendations.au3'
#include '../src/missions/NexusChallenge.au3'
#include '../src/missions/SoO.au3'
#include '../src/missions/SunspearArmor.au3'
#include '../src/missions/TunnelsOfTheForsaken.au3'
#include '../src/missions/Underworld.au3'
#include '../src/missions/Voltaic.au3'
#include '../src/missions/WarSupplyKeiran.au3'
#include '../src/runs/Boreal.au3'
#include '../src/runs/Pongmei.au3'
#include '../src/runs/Tasca.au3'
#include '../src/runs/MagmasRun.au3'
#include '../src/titles/LDOA.au3'
#include '../src/utilities/Follower.au3'
#include '../src/utilities/BonderFollower.au3'
#include '../src/utilities/OmniFarmer.au3'
#include '../src/utilities/TestSuite.au3'
#include '../src/vanquishes/Asuran.au3'
#include '../src/vanquishes/KurzickDrazach.au3'
#include '../src/vanquishes/KurzickFerndale.au3'
#include '../src/vanquishes/LuxonMountQinkai.au3'
#include '../src/vanquishes/LuxonSilentSurf.au3'
#include '../src/vanquishes/Norn.au3'
#include '../src/vanquishes/Vanguard.au3'
#EndRegion Includes

Global Const $GUI_WA_INACTIVE = 0
Global Const $GUI_WM_ACTIVATE = 0x0006
Global Const $GUI_WM_COMMAND = 0x0111
Global Const $GUI_COMBOBOX_DROPDOWN_OPENED = 7

Global Const $AVAILABLE_BAG_COUNTS = '|1|2|3|4|5'
Global Const $AVAILABLE_WEAPON_SLOTS = '|0|1|2|3|4'
Global Const $KIT_AMOUNT_CHOICE = '|0|1|2|3|4|5|6|7|8|9|10|11|12'
Global Const $AVAILABLE_FARMS = '|Asuran|Boreal|CoF|Corsairs|Deldrimor|Drake Flesh|Dragon Moss|Eden Iris|Feathers|Follower|Monk Bonder|EleMonk UW Bonder|FoW|FoW Tower of Courage|Froggy|Gemstones|Gemstone Margonite|Gemstone Stygian|Gemstone Torment|' & _
	'Glint Challenge|Jade Brotherhood|Kilroy|Kournans|Kurzick Ferndale|Kurzick Drazach|LDOA|Lightbringer & Sunspear|Lightbringer|LuxonMQ|LuxonSS|Mantids|Ministerial Commendations|Minotaurs|Nexus Challenge|Norn|OmniFarm|Pongmei|' & _
	'Raptors|Skale Fins|Skrees|SoO|SpiritSlaves|Sunspear Armor|Tasca|MagmasRun|TunnelsOfTheForsaken|Underworld|Vaettirs|Vanguard|Voltaic|War Supply Keiran|Zodiac|Manual Mode|Storage|Tests|TestSuite'

#Region GUI

Global $gui_botshub, $gui_tabs_parent, $gui_tab_main, $gui_tab_runoptions, $gui_tab_lootoptions, $gui_tab_farminfos, $gui_tab_lootoptions, $gui_tab_teamoptions
Global $gui_tab_tools, $gui_tab_follower, $gui_tab_titles, $gui_tab_about, $gui_label_status, $gui_label_attachstatus, $gui_label_q8count
Global $gui_button_ectotogold, $gui_button_goldtolockpicks, $gui_button_extractupgrades, $gui_button_attach, $gui_button_resetstats, $gui_label_extractupgrades
Global $gui_button_toolsopenstorage
Global $gui_combo_emptytab, $gui_button_emptytab, $gui_label_emptytab, $gui_button_storagesetup, $gui_button_sortnow_tools
Global $gui_checkbox_extractupgrades, $gui_checkbox_logchests, $gui_checkbox_autoattach, $gui_checkbox_returnondeath
Global $gui_checkbox_follower_permasf, $gui_checkbox_follower_openchests, $gui_checkbox_follower_leadertarget
Global $gui_input_follower_name, $gui_input_follower_leash, $gui_combo_bonder_mode
; v38.4: Follower tab Start button (starts the Follower farm through the main Start/Pause machinery)
Global $gui_button_follower_start, $gui_label_follower_start
Global $temporary_gui, $temporary_gui_opened = False
Global $sessionQ8Count = 0
; v15: bumped by ResetSessionStats(); UpdateStats/UpdateItemStats re-initialise their static counters when it changes
Global $stats_reset_generation = 0
Global $gui_console, $gui_combo_characterchoice, $gui_combo_farmchoice, $gui_startbutton, $gui_farmprogress
Global $gui_label_manualmode, $gui_input_manualmode, $gui_button_manualmode, $gui_renderbutton, $gui_renderlabel, _
		$gui_label_bagscount, $gui_combo_bagscount, $gui_label_traveldistrict, $gui_combo_districtchoice, _
		$gui_label_weaponslot, $gui_combo_weaponslot, $gui_icon_saveconfig, $gui_combo_configchoice, $gui_icon_openstorage

; v38.9: About tab (clickable original-repo link and email) and the constants it uses
Global $gui_about_title, $gui_about_github, $gui_about_email
Global Const $ABOUT_GITHUB_URL = 'https://github.com/caustic-kronos/BotsHub'
Global Const $ABOUT_EMAIL = 'alphametagamma420@gmail.com'

Global $gui_group_runinfos, _
		$gui_label_runs_text, $gui_label_runs_value, $gui_label_successes_text, $gui_label_successes_value, $gui_label_failures_text, $gui_label_failures_value, $gui_label_successratio_text, $gui_label_successratio_value, _
		$gui_label_time_text, $gui_label_time_value, $gui_label_timeperrun_text, $gui_label_timeperrun_value, $gui_label_experience_text, $gui_label_experience_value, $gui_label_chests_text, $gui_label_chests_value, _
		$gui_label_gold_text, $gui_label_gold_value, $gui_label_golditems_text, $gui_label_golditems_value, $gui_label_ectos_text, $gui_label_ectos_value, $gui_label_obsidianshards_text, $gui_label_obsidianshards_value
; v23: the 'Items collected' / 'Titles' labels are replaced by one scrollable ListView (lib/Utils-ItemsPanel.au3)
Global $gui_group_itemslooted
Global $gui_group_runoptions, _
		$gui_checkbox_loopruns, $gui_checkbox_hardmode, $gui_checkbox_emergencytravel, $gui_checkbox_sharememory, $gui_checkbox_automaticteamsetup, $gui_checkbox_useconsumables, $gui_checkbox_useconsets, $gui_checkbox_usescrolls
Global $gui_group_itemoptions, $gui_checkbox_sortitems, $gui_checkbox_collectdata, $gui_checkbox_salvageintocomponents, $gui_checkbox_farmmaterialsmidrun, _
		$gui_label_salvagekits, $gui_combo_salvagekits, $gui_label_identificationkits, $gui_combo_identificationkits
Global $gui_group_factionoptions, $gui_label_faction, $gui_radiobutton_donatepoints, $gui_radiobutton_buyfactionresources, $gui_radiobutton_buyfactionscrolls
Global $gui_group_teamoptions, $gui_teamlabel, $gui_teammemberlabel, $gui_teammemberbuildlabel, _
		$gui_label_hero_1, $gui_label_hero_2, $gui_label_hero_3, $gui_label_hero_4, $gui_label_hero_5, $gui_label_hero_6, $gui_label_hero_7, _
		$gui_label_player, $gui_combo_hero_1, $gui_combo_hero_2, $gui_combo_hero_3, $gui_combo_hero_4, $gui_combo_hero_5, $gui_combo_hero_6, $gui_combo_hero_7, _
		$gui_checkbox_load_build_all, $gui_checkbox_load_build_player, $gui_checkbox_load_build_hero_1, $gui_checkbox_load_build_hero_2, $gui_checkbox_load_build_hero_3, _
		$gui_checkbox_load_build_hero_4, $gui_checkbox_load_build_hero_5, $gui_checkbox_load_build_hero_6, $gui_checkbox_load_build_hero_7, _
		$gui_label_build_hero_1, $gui_label_build_hero_2, $gui_label_build_hero_3, $gui_label_build_hero_4, $gui_label_build_hero_5, $gui_label_build_hero_6, $gui_label_build_hero_7, _
		$gui_input_build_player, $gui_input_build_hero_1, $gui_input_build_hero_2, $gui_input_build_hero_3, $gui_input_build_hero_4, $gui_input_build_hero_5, $gui_input_build_hero_6, $gui_input_build_hero_7
Global $gui_group_otheroptions, $gui_group_actions, $gui_button_openstorage, $gui_checkbox_gooffline, $gui_checkbox_flashwhisper
Global $gui_label_characterbuilds, $gui_label_heroesbuilds, $gui_edit_characterbuilds, $gui_edit_heroesbuilds, $gui_label_farminformations
Global $gui_treeview_lootoptions, $gui_label_lootoptionswarning, $gui_expandlootoptionsbutton, $gui_reducelootoptionsbutton, $gui_loadlootoptionsbutton, $gui_savelootoptionsbutton, $gui_applylootoptionsbutton
; v37.2: AutoIt control IDs created by GUICtrlCreateTreeViewItem - freed on each Load so they do not leak
Global $loot_treeview_item_ctrlids[0]
; v38.2: path -> control ID of the current Inventory tree; used to update checkmarks in place when the structure is unchanged
; v38.3: only the nodes created so far are in this map (the tree is filled in lazily)
Global $loot_treeview_path_ids[]
; v38.3: lazy Inventory tree. The full tree shape and the tick of every node not created yet live in this model.
; Startup / Load create only the top-level branches; a branch's children are created the first time it is expanded.
Global $loot_tree_model_hwnd = 0
Global $loot_tree_model_ctrl = 0
Global $loot_tree_preorder[0]
Global $loot_tree_subtree_end[0]
Global $loot_tree_index[]
Global $loot_tree_children[]
Global $loot_tree_states[]
Global $loot_tree_populated[]
Global $loot_tree_id_paths[]


;------------------------------------------------------
; Title...........:	_guiCreate
; Description.....:	Create the main GUI
;------------------------------------------------------
Func CreateBotsHubGUI()
	; -1, -1 automatically positions GUI in the middle of the screen, alternatively can do calculations with inbuilt @DesktopWidth and @DesktopHeight
	$gui_botshub = GUICreate('GW Bot Hub', 650, 500, -1, -1)
	GUISetBkColor($THEME_WINDOW_BG, $gui_botshub)
	; v28: window / taskbar icon (inverted helmet); skipped if the file is missing (compiled exe keeps its embedded icon)
	If FileExists(@ScriptDir & '\assets\icon\BotsHub.ico') Then GUISetIcon(@ScriptDir & '\assets\icon\BotsHub.ico', -1, $gui_botshub)

	; === Buttons common to all tabs ===
	$gui_combo_characterchoice = GUICtrlCreateCombo('No character selected', 10, 470, 150, 20)
	$gui_combo_farmchoice = GUICtrlCreateCombo('Choose a farm', 170, 470, 150, 20, BitOR($CBS_DROPDOWN, $WS_VSCROLL))
	$gui_startbutton = GUICtrlCreateButton('Start', 330, 470, 150, 21)
	$gui_label_status = GUICtrlCreateLabel('Ready', 490, 448, 150, 16)
	$gui_farmprogress = GUICtrlCreateProgress(490, 470, 150, 21)
	; v38.12: top-right cluster on the tab-strip row. Chest (20x20), template combo and save icon (20x20) all start at y=10
	; and are spaced 7 px apart; the save icon ends at x=638, 2 px inside the tab panel's right edge (640).
	; These are the positions for a 407 px tab strip (About ends at x=407); TopRightClusterLayout() re-measures the
	; real end of the About header once the tabs exist and moves the chest/combo so the 7 px gaps hold on any font.
	; The combo's drop-down list is 220 px wide so long template names are readable in full.
	; About is a real tab after Tools; AutoIt cannot place a tab header to the right of a floating button.
	$gui_icon_openstorage = 0
	If FileExists(@ScriptDir & '/assets/icon/xunlai_chest.bmp') Then
		$gui_icon_openstorage = GUICtrlCreatePic(@ScriptDir & '/assets/icon/xunlai_chest.bmp', 414, 10, 20, 20)
	Else
		$gui_icon_openstorage = GUICtrlCreateButton('', 414, 10, 20, 20)
	EndIf
	GUICtrlSetTip($gui_icon_openstorage, 'Open Xunlai storage')
	GUICtrlSetOnEvent($gui_icon_openstorage, 'GuiMainButtonHandler')
	$gui_combo_configchoice = GUICtrlCreateCombo('Default Farm Configuration', 441, 10, 170, 22, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	GUICtrlSendMsg($gui_combo_configchoice, $CB_SETDROPPEDWIDTH, 220, 0)
	$gui_icon_saveconfig = GUICtrlCreatePic(@ScriptDir & '/doc/save.jpg', 618, 10, 20, 20)
	GUICtrlSetData($gui_combo_farmchoice, $AVAILABLE_FARMS, 'Choose a farm')
	ThemeSetButton($gui_startbutton, $THEME_BTN_PRIMARY)

	GUISetOnEvent($GUI_EVENT_CLOSE, 'GuiMainButtonHandler')
	GUICtrlSetOnEvent($gui_startbutton, 'GuiStartButtonHandler')
	GUICtrlSetOnEvent($gui_combo_farmchoice, 'GuiMainButtonHandler')
	GUICtrlSetOnEvent($gui_combo_configchoice, 'GuiMainButtonHandler')
	GUICtrlSetOnEvent($gui_icon_saveconfig, 'GuiMainButtonHandler')

	; === Main tab ===
	$gui_tabs_parent = GUICtrlCreateTab(10, 10, 630, 435)
	; v38.12: slightly tighter tab-header padding (text unchanged) so the top-right cluster has room for full template names
	_GUICtrlTab_SetPadding(GUICtrlGetHandle($gui_tabs_parent), 4, 3)
	$gui_tab_main = GUICtrlCreateTabItem('Main')
	_GUICtrlTab_SetBkColor($gui_botshub, $gui_tabs_parent, $THEME_PANEL_BG)
	GUICtrlSetOnEvent($gui_tabs_parent, 'GuiTabHandler')

	$gui_console = _GUICtrlRichEdit_Create($gui_botshub, '', 20, 190, 300, 240, BitOR($ES_MULTILINE, $ES_READONLY, $WS_VSCROLL))
	_GUICtrlRichEdit_SetCharColor($gui_console, ThemeBGR($THEME_LOG_INFO))
	_GUICtrlRichEdit_SetBkColor($gui_console, ThemeBGR($THEME_CONSOLE_BG))
	SetConsole($gui_console)

	; === Run Infos ===
	; v32: same labels and order as v10; label/value widths fitted to the text (v10's 65/85 px wrapped 'Time per run:' and
	; 'Obsidian Shards:' onto a hidden second line); values right-aligned in wider cells
	$gui_group_runinfos = GUICtrlCreateGroup('Informations', 21, 39, 300, 145)
	$gui_label_runs_text = GUICtrlCreateLabel('Runs:', 31, 64, 78, 16)
	$gui_label_runs_value = GUICtrlCreateLabel('0', 109, 64, 53, 16, $SS_RIGHT)
	$gui_label_successes_text = GUICtrlCreateLabel('Successes:', 31, 84, 78, 16)
	$gui_label_successes_value = GUICtrlCreateLabel('0', 109, 84, 53, 16, $SS_RIGHT)
	$gui_label_failures_text = GUICtrlCreateLabel('Failures:', 31, 104, 78, 16)
	$gui_label_failures_value = GUICtrlCreateLabel('0', 109, 104, 53, 16, $SS_RIGHT)
	$gui_label_successratio_text = GUICtrlCreateLabel('Success Ratio:', 31, 124, 78, 16)
	$gui_label_successratio_value = GUICtrlCreateLabel('0', 109, 124, 53, 16, $SS_RIGHT)
	$gui_label_time_text = GUICtrlCreateLabel('Time:', 31, 144, 50, 16)
	$gui_label_time_value = GUICtrlCreateLabel('0', 81, 144, 81, 16, $SS_RIGHT)
	$gui_label_timeperrun_text = GUICtrlCreateLabel('Time per run:', 31, 164, 78, 16)
	$gui_label_timeperrun_value = GUICtrlCreateLabel('0', 109, 164, 53, 16, $SS_RIGHT)

	$gui_label_experience_text = GUICtrlCreateLabel('Experience:', 170, 64, 90, 16)
	$gui_label_experience_value = GUICtrlCreateLabel('0', 260, 64, 58, 16, $SS_RIGHT)
	$gui_label_chests_text = GUICtrlCreateLabel('Chests:', 170, 84, 90, 16)
	$gui_label_chests_value = GUICtrlCreateLabel('0', 260, 84, 58, 16, $SS_RIGHT)
	$gui_label_gold_text = GUICtrlCreateLabel('Gold:', 170, 104, 90, 16)
	$gui_label_gold_value = GUICtrlCreateLabel('0', 260, 104, 58, 16, $SS_RIGHT)
	$gui_label_golditems_text = GUICtrlCreateLabel('Gold Items:', 170, 124, 90, 16)
	$gui_label_golditems_value = GUICtrlCreateLabel('0', 260, 124, 58, 16, $SS_RIGHT)
	$gui_label_ectos_text = GUICtrlCreateLabel('Ectos:', 170, 144, 90, 16)
	$gui_label_ectos_value = GUICtrlCreateLabel('0', 260, 144, 58, 16, $SS_RIGHT)
	$gui_label_obsidianshards_text = GUICtrlCreateLabel('Obsidian Shards:', 170, 164, 90, 16)
	$gui_label_obsidianshards_value = GUICtrlCreateLabel('0', 260, 164, 58, 16, $SS_RIGHT)
	GUICtrlCreateGroup('', -99, -99, 1, 1)

	; === Items (v23): inventory + Xunlai storage totals by category (v33: titles moved to the Titles tab) - one scrollable ListView ===
	$gui_group_itemslooted = GUICtrlCreateGroup('Items (inventory + storage)', 330, 39, 295, 396)
	GUICtrlCreateGroup('', -99, -99, 1, 1)
	ItemsPanelCreate(337, 56, 281, 375)
	GUICtrlCreateTabItem('')

	; === Setup tab (v35: redesigned, approved mockup tools/out/v35_setup_mockup.png) ===
	$gui_tab_runoptions = GUICtrlCreateTabItem('Setup')
	_GUICtrlTab_SetBkColor($gui_botshub, $gui_tabs_parent, $THEME_PANEL_BG)

	$gui_group_runoptions = GUICtrlCreateGroup('Run options', 21, 39, 295, 150)
	$gui_checkbox_loopruns = GUICtrlCreateCheckbox('Loop Runs', 31, 62)
	$gui_checkbox_hardmode = GUICtrlCreateCheckbox('Hard Mode', 31, 88)
	$gui_label_weaponslot = GUICtrlCreateLabel('Use weapon slot for farm:', 31, 118)
	$gui_combo_weaponslot = GUICtrlCreateCombo('0', 180, 114, 30, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	GUICtrlSetData($gui_combo_weaponslot, $AVAILABLE_WEAPON_SLOTS, '0')
	$gui_label_bagscount = GUICtrlCreateLabel('Use bags:', 31, 144)
	$gui_combo_bagscount = GUICtrlCreateCombo('5', 180, 140, 30, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	GUICtrlSetData($gui_combo_bagscount, $AVAILABLE_BAG_COUNTS, '5')
	$gui_label_traveldistrict = GUICtrlCreateLabel('Travel district:', 31, 170)
	$gui_combo_districtchoice = GUICtrlCreateCombo('Random EU', 180, 166, 95, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	GUICtrlSetData($gui_combo_districtchoice, $AVAILABLE_DISTRICTS, 'Random EU')
	GUICtrlCreateGroup('', -99, -99, 1, 1)

	$gui_group_factionoptions = GUICtrlCreateGroup('Faction options', 330, 39, 295, 150)
	$gui_radiobutton_donatepoints = GUICtrlCreateRadio('Donate Kurzick/Luxon points to alliance', 350, 68, 265, 20)
	$gui_radiobutton_buyfactionresources = GUICtrlCreateRadio('Buy Amber Chunks/Jadeite Shards', 350, 108, 265, 20)
	$gui_radiobutton_buyfactionscrolls = GUICtrlCreateRadio('Buy Urgoz''s Warren/The Deep Passage scrolls', 350, 148, 265, 20)
	GUICtrlSetState($gui_radiobutton_donatepoints, $GUI_CHECKED)
	GUICtrlCreateGroup('', -99, -99, 1, 1)

	$gui_group_itemoptions = GUICtrlCreateGroup('Inventory management', 21, 204, 295, 155)
	$gui_checkbox_sortitems = GUICtrlCreateCheckbox('Sort items', 31, 226)
	$gui_checkbox_salvageintocomponents = GUICtrlCreateCheckbox('Salvage into materials', 31, 252, 265, 20)
	$gui_checkbox_extractupgrades = GUICtrlCreateCheckbox('Extract selected components before selling', 31, 278, 275, 20)
	$gui_checkbox_usescrolls = GUICtrlCreateCheckbox('Use scrolls to enter elite zones', 31, 304, 265, 20)
	GUICtrlCreateGroup('', -99, -99, 1, 1)

	$gui_group_otheroptions = GUICtrlCreateGroup('Other options', 330, 204, 295, 170)
	$gui_checkbox_useconsumables = GUICtrlCreateCheckbox('Use optional consumables', 350, 226)
	$gui_checkbox_useconsets = GUICtrlCreateCheckbox('Use consets', 350, 250)
	$gui_checkbox_logchests = GUICtrlCreateCheckbox('Log chest spawns', 350, 274)
	$gui_checkbox_returnondeath = GUICtrlCreateCheckbox('Return to outpost on death', 350, 298)
	$gui_checkbox_gooffline = GUICtrlCreateCheckbox('Go offline when bot starts', 350, 322)
	$gui_checkbox_flashwhisper = GUICtrlCreateCheckbox('Flash taskbar on whisper', 350, 346)
	GUICtrlCreateGroup('', -99, -99, 1, 1)

	$gui_group_actions = GUICtrlCreateGroup('Actions', 21, 386, 604, 50)
	$gui_button_openstorage = GUICtrlCreateButton('Open Storage', 31, 404, 120, 22)
	ThemeSetButton($gui_button_openstorage, $THEME_BTN_PRIMARY)
	; v24: the button names the action (AMG): 'Disable Graphics' while the game renders, 'Enable Graphics' while it does not
	; v35: control itself is unchanged (label, size 122x22, colours, tip, handler) - only moved into the Actions row
	$gui_renderbutton = GUICtrlCreateButton('Disable Graphics', 161, 404, 122, 22)
	ThemeSetButton($gui_renderbutton, $THEME_BTN_WARNING, $THEME_BTN_WARNING_TEXT)
	Local $manualModeTooltip = 'Manual Mode. Allows running a command with' & @CRLF _
							& 'any arguments on the fly by writing it in below field.' & @CRLF _
							& 'Syntax: fun(arg1, arg2, arg3, [...])'
	$gui_label_manualmode = GUICtrlCreateLabel('Manual:', 310, 407, 50, 16)
	$gui_input_manualmode = GUICtrlCreateInput('', 360, 404, 145, 20)
	$gui_button_manualmode = GUICtrlCreateButton('Run', 515, 404, 90, 22)
	ThemeSetButton($gui_button_manualmode, $THEME_BTN_PRIMARY)
	GUICtrlCreateGroup('', -99, -99, 1, 1)

	GUICtrlSetTip($gui_checkbox_salvageintocomponents, 'Master switch for the Inventory tab''s Salvage items branch. When unticked, nothing is salvaged into materials, even if that branch has ticks.')
	GUICtrlSetTip($gui_checkbox_useconsumables, 'If bot uses consumables (cake, pie, speed boosts, etc), it will do it automatically.')
	GUICtrlSetTip($gui_checkbox_useconsets, 'If bot can use consets, it will do it automatically.')
	GUICtrlSetTip($gui_button_openstorage, 'Open Xunlai storage window. Works remotely - view only from explorable areas. Also works while a farm is running. Same as Tools > Open Storage.')
	GUICtrlSetTip($gui_checkbox_gooffline, 'Set your status to offline in the friends list when the bot starts.')
	GUICtrlSetTip($gui_checkbox_flashwhisper, 'Flash the GW taskbar button when an incoming whisper is received while the window is not focused.')
	GUICtrlSetTip($gui_checkbox_usescrolls, 'Automatically uses scrolls required to enter elite zones (UW, FoW, Urgoz, Deep)')
	GUICtrlSetTip($gui_checkbox_sortitems, 'Sorts items in inventory to optimize space before loot management.')
	GUICtrlSetTip($gui_checkbox_extractupgrades, 'In town, before salvaging for materials and selling: extract the components checked under Inventory > "Extract Components"' & @CRLF _
		& 'from items in your bags (Superior/Expert salvage kit; buys an Expert Salvage Kit if you have none).' & @CRLF _
		& 'Items still holding a checked component are not salvaged for materials or sold. Store items protection wins.')
	GUICtrlSetTip($gui_checkbox_logchests, 'Log chest spawn positions to the console/database when chests are found.')
	GUICtrlSetTip($gui_checkbox_returnondeath, 'Travel back to the outpost automatically if the character dies during a run.')
	Local $factionPointsUsageTooltip = 'Option on how to spend faction points earned in Kurzick/Luxon farms'
	GUICtrlSetTip($gui_radiobutton_donatepoints, $factionPointsUsageTooltip)
	GUICtrlSetTip($gui_radiobutton_buyfactionresources, $factionPointsUsageTooltip)
	GUICtrlSetTip($gui_radiobutton_buyfactionscrolls, $factionPointsUsageTooltip)
	Local $weaponSlotTooltip = 'Choose a weapon slot to use - 0 means it will use the current weapon slot'
	GUICtrlSetTip($gui_label_weaponslot, $weaponSlotTooltip)
	GUICtrlSetTip($gui_combo_weaponslot, $weaponSlotTooltip)
	GUICtrlSetTip($gui_renderbutton, 'Disabling rendering can reduce power consumption')
	GUICtrlSetTip($gui_label_manualmode, $manualModeTooltip)
	GUICtrlSetTip($gui_input_manualmode, $manualModeTooltip)
	GUICtrlSetTip($gui_button_manualmode, $manualModeTooltip)

	GUICtrlSetOnEvent($gui_checkbox_loopruns, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_checkbox_hardmode, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_checkbox_salvageintocomponents, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_checkbox_extractupgrades, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_checkbox_useconsumables, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_checkbox_useconsets, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_checkbox_usescrolls, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_checkbox_gooffline, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_checkbox_flashwhisper, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_checkbox_sortitems, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_radiobutton_donatepoints, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_radiobutton_buyfactionresources, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_radiobutton_buyfactionscrolls, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_combo_weaponslot, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_combo_bagscount, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_combo_districtchoice, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_renderbutton, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_button_openstorage, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_button_manualmode, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_checkbox_logchests, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_checkbox_returnondeath, 'GuiOptionsHandler')
	GUICtrlCreateTabItem('')

	; === Build Info tab (v34) ===
	$gui_tab_farminfos = GUICtrlCreateTabItem('Build Info')
	_GUICtrlTab_SetBkColor($gui_botshub, $gui_tabs_parent, $THEME_PANEL_BG)
	BuildInfoCreate()
	GUICtrlCreateTabItem('')

	; === Team tab ===
	$gui_tab_teamoptions = GUICtrlCreateTabItem('Team')
	_GUICtrlTab_SetBkColor($gui_botshub, $gui_tabs_parent, $THEME_PANEL_BG)
	$gui_group_teamoptions = GUICtrlCreateGroup('Team options', 21, 39, 604, 385)
	$gui_teamlabel = GUICtrlCreateLabel( _
		'Warning: enabling team setup overrides all bots team setup. Make sure your heroes have:' & @CRLF & _
		'- correct build' & @CRLF & _
		'- correct order' & @CRLF & _
		'- correct behaviour (passive/aggressive)' & @CRLF & _
		'If party size is 4 or 6, last heroes just will not be added to party.', 40, 70)
	$gui_checkbox_automaticteamsetup = GUICtrlCreateCheckbox('Setup team automatically using team options section', 31, 140)
	$gui_teammemberlabel = GUICtrlCreateLabel('Team member', 147, 170, 100, 20)
	$gui_teammemberbuildlabel = GUICtrlCreateLabel('Team member build', 438, 170, 120, 20)
	$gui_checkbox_load_build_all = GUICtrlCreateCheckbox('Load all builds:', 254, 167)

	; Player build setup
	$gui_label_player = GUICtrlCreateLabel('Player', 125, 197, 114, 20, BitOR($SS_CENTER, $SS_CENTERIMAGE))
	$gui_checkbox_load_build_player = GUICtrlCreateCheckbox('Load Player Build:', 254, 197)
	$gui_input_build_player = GUICtrlCreateInput('', 375, 197, 236, 20)
	GUICtrlSetBkColor($gui_label_player, $THEME_INPUT_BG)
	; Hero 1 setup
	$gui_label_hero_1 = GUICtrlCreateLabel('Selected Hero 1:', 31, 230, 100, 20)
	$gui_combo_hero_1 = GUICtrlCreateCombo('Master of Whispers', 125, 227, 114, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	$gui_checkbox_load_build_hero_1 = GUICtrlCreateCheckbox('Load Hero 1 Build:', 254, 227)
	$gui_input_build_hero_1 = GUICtrlCreateInput('OAljUwGopSUBHVyBoBVVbh4B1YA', 375, 227, 236, 20)
	; Hero 2 setup
	$gui_label_hero_2 = GUICtrlCreateLabel('Selected Hero 2:', 31, 260, 100, 20)
	$gui_combo_hero_2 = GUICtrlCreateCombo('Livia', 125, 257, 114, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	$gui_checkbox_load_build_hero_2 = GUICtrlCreateCheckbox('Load Hero 2 Build:', 254, 257)
	$gui_input_build_hero_2 = GUICtrlCreateInput('OAhjQoGYIP3hhWVVaO5EeDzxJ', 375, 257, 236, 20)
	; Hero 3 setup
	$gui_label_hero_3 = GUICtrlCreateLabel('Selected Hero 3:', 31, 290, 100, 20)
	$gui_combo_hero_3 = GUICtrlCreateCombo('Gwen', 125, 287, 114, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	$gui_checkbox_load_build_hero_3 = GUICtrlCreateCheckbox('Load Hero 3 Build:', 254, 287)
	$gui_input_build_hero_3 = GUICtrlCreateInput('OQNEAqwD2ycC0AmupXOIDQEQj', 375, 287, 236, 20)
	; Hero 4 setup
	$gui_label_hero_4 = GUICtrlCreateLabel('Selected Hero 4:', 31, 320, 100, 20)
	$gui_combo_hero_4 = GUICtrlCreateCombo('Olias', 125, 317, 114, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	$gui_checkbox_load_build_hero_4 = GUICtrlCreateCheckbox('Load Hero 4 Build:', 254, 317)
	$gui_input_build_hero_4 = GUICtrlCreateInput('OAhjUwGYoSUBHVoBbhVVWbTODTA', 375, 317, 236, 20)
	; Hero 5 setup
	$gui_label_hero_5 = GUICtrlCreateLabel('Selected Hero 5:', 31, 350, 100, 20)
	$gui_combo_hero_5 = GUICtrlCreateCombo('Norgu', 125, 347, 114, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	$gui_checkbox_load_build_hero_5 = GUICtrlCreateCheckbox('Load Hero 5 Build:', 254, 347)
	$gui_input_build_hero_5 = GUICtrlCreateInput('OQNEAqwD2ycCwpmupXOIDcBQj', 375, 347, 236, 20)
	; Hero 6 setup
	$gui_label_hero_6 = GUICtrlCreateLabel('Selected Hero 6:', 31, 380, 100, 20)
	$gui_combo_hero_6 = GUICtrlCreateCombo('Xandra', 125, 377, 114, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	$gui_checkbox_load_build_hero_6 = GUICtrlCreateCheckbox('Load Hero 6 Build:', 254, 377)
	$gui_input_build_hero_6 = GUICtrlCreateInput('OACiAyk8gNtePuwJ00ZOPLYA', 375, 377, 236, 20)
	; Hero 7 setup
	$gui_label_hero_7 = GUICtrlCreateLabel('Selected Hero 7:', 31, 410, 100, 20)
	$gui_combo_hero_7 = GUICtrlCreateCombo('Razah', 125, 407, 114, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	$gui_checkbox_load_build_hero_7 = GUICtrlCreateCheckbox('Load Hero 7 Build:', 254, 407)
	$gui_input_build_hero_7 = GUICtrlCreateInput('OQNEAqwD2ycCaCmupXOIDMEQj', 375, 407, 236, 20)

	GUICtrlSetData($gui_combo_hero_1, $AVAILABLE_HEROES, 'Master of Whispers')
	GUICtrlSetData($gui_combo_hero_2, $AVAILABLE_HEROES, 'Livia')
	GUICtrlSetData($gui_combo_hero_3, $AVAILABLE_HEROES, 'Gwen')
	GUICtrlSetData($gui_combo_hero_4, $AVAILABLE_HEROES, 'Olias')
	GUICtrlSetData($gui_combo_hero_5, $AVAILABLE_HEROES, 'Norgu')
	GUICtrlSetData($gui_combo_hero_6, $AVAILABLE_HEROES, 'Xandra')
	GUICtrlSetData($gui_combo_hero_7, $AVAILABLE_HEROES, 'Razah')

	GUICtrlSetOnEvent($gui_checkbox_automaticteamsetup, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_combo_hero_1, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_combo_hero_2, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_combo_hero_3, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_combo_hero_4, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_combo_hero_5, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_combo_hero_6, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_combo_hero_7, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_checkbox_load_build_all, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_checkbox_load_build_player, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_checkbox_load_build_hero_1, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_checkbox_load_build_hero_2, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_checkbox_load_build_hero_3, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_checkbox_load_build_hero_4, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_checkbox_load_build_hero_5, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_checkbox_load_build_hero_6, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_checkbox_load_build_hero_7, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_input_build_player, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_input_build_hero_1, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_input_build_hero_2, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_input_build_hero_3, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_input_build_hero_4, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_input_build_hero_5, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_input_build_hero_6, 'GuiTeamTabButtonHandler')
	GUICtrlSetOnEvent($gui_input_build_hero_7, 'GuiTeamTabButtonHandler')
	GUICtrlCreateGroup('', -99, -99, 1, 1)
	GUICtrlCreateTabItem('')

	; === Inventory tab ===
	$gui_tab_lootoptions = GUICtrlCreateTabItem('Inventory')
	$gui_treeview_lootoptions = GUICtrlCreateTreeView(80, 45, 545, 380, BitOR($TVS_HASLINES, $TVS_LINESATROOT, $TVS_HASBUTTONS, $TVS_CHECKBOXES, $TVS_FULLROWSELECT))
	BuildTreeViewFromCache($gui_treeview_lootoptions)

	; v32: button column 63 px wide (55 px cut 'Expand all' / 'Reduce all' at the real font)
	$gui_expandlootoptionsbutton = GUICtrlCreateButton('Expand all', 14, 124, 63, 21)
	$gui_reducelootoptionsbutton = GUICtrlCreateButton('Reduce all', 14, 154, 63, 21)
	$gui_loadlootoptionsbutton = GUICtrlCreateButton('Load', 14, 184, 63, 21)
	$gui_savelootoptionsbutton = GUICtrlCreateButton('Save', 14, 214, 63, 21)
	$gui_label_lootoptionswarning = GUICtrlCreateLabel('Click apply to confirm your changes', 14, 244, 63, 56, $SS_CENTER)
	$gui_applylootoptionsbutton = GUICtrlCreateButton(@LF & 'Apply' & @LF & 'changes', 14, 304, 63, 63, $BS_MULTILINE)
	ThemeSetButton($gui_applylootoptionsbutton, $THEME_BTN_WARNING, $THEME_BTN_WARNING_TEXT)

	GUICtrlSetOnEvent($gui_expandlootoptionsbutton, 'GuiLootTabButtonHandler')
	GUICtrlSetOnEvent($gui_reducelootoptionsbutton, 'GuiLootTabButtonHandler')
	GUICtrlSetOnEvent($gui_loadlootoptionsbutton, 'GuiLootTabButtonHandler')
	GUICtrlSetOnEvent($gui_savelootoptionsbutton, 'GuiLootTabButtonHandler')
	GUICtrlSetOnEvent($gui_applylootoptionsbutton, 'GuiLootTabButtonHandler')
	GUICtrlCreateTabItem('')

	$gui_tab_follower = GUICtrlCreateTabItem('Follower')
	GUICtrlCreateGroup('Follower options', 21, 39, 604, 220)
	GUICtrlCreateLabel('Follower Assassin: Perma SF + open chests', 31, 59, 400, 16)
	$gui_checkbox_follower_permasf = GUICtrlCreateCheckbox('Perma Shadow Form', 31, 84)
	$gui_checkbox_follower_openchests = GUICtrlCreateCheckbox('Open locked chests', 220, 84)
	$gui_checkbox_follower_leadertarget = GUICtrlCreateCheckbox('Follow leader target calls', 400, 84)
	GUICtrlCreateLabel('Follow party member name (blank = party leader):', 31, 118, 280, 16)
	$gui_input_follower_name = GUICtrlCreateInput('', 320, 115, 200, 20)
	GUICtrlCreateLabel('Leash range:', 31, 150, 80, 16)
	$gui_input_follower_leash = GUICtrlCreateInput('1500', 120, 147, 70, 20)
	GUICtrlSetOnEvent($gui_input_follower_leash, 'GuiOptionsHandler')
	; The name input had no event handler, so 'follower.name' was never stored/saved
	GUICtrlSetOnEvent($gui_input_follower_name, 'GuiOptionsHandler')
	GUICtrlCreateLabel('Bonder Mode:', 220, 150, 80, 16)
	$gui_combo_bonder_mode = GUICtrlCreateCombo('None', 310, 147, 160, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	GUICtrlSetData($gui_combo_bonder_mode, 'None|Monk Bonder|EleMonk UW Bonder', 'None')
	GUICtrlSetState($gui_checkbox_follower_leadertarget, $GUI_CHECKED)
	GUICtrlSetOnEvent($gui_checkbox_follower_permasf, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_checkbox_follower_openchests, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_checkbox_follower_leadertarget, 'GuiOptionsHandler')
	GUICtrlSetOnEvent($gui_combo_bonder_mode, 'GuiOptionsHandler')
	; v38.4: start this follow bot straight from the tab; it shares the main Start button's state (Start / Pause / Will pause)
	$gui_button_follower_start = GUICtrlCreateButton('Start Follower', 31, 190, 150, 24)
	$gui_label_follower_start = GUICtrlCreateLabel('Runs the Follower farm. Pause here or with the main button.', 195, 194, 410, 16)
	ThemeSetButton($gui_button_follower_start, $THEME_BTN_PRIMARY)
	GUICtrlSetOnEvent($gui_button_follower_start, 'GuiFollowerStartButtonHandler')
	GUICtrlCreateGroup('', -99, -99, 1, 1)
	GUICtrlCreateTabItem('')
	; v33: Titles tab (approved mockup tools/out/v33_titles_mockup.png), placed after Follower (v34: Tools is last)
	$gui_tab_titles = GUICtrlCreateTabItem('Titles')
	_GUICtrlTab_SetBkColor($gui_botshub, $gui_tabs_parent, $THEME_PANEL_BG)
	TitlesTabCreate('GuiTitlesButtonHandler')
	GUICtrlCreateTabItem('')
	; === Tools tab ===
	$gui_tab_tools = GUICtrlCreateTabItem('Tools')
	GUICtrlCreateGroup('Ecto to Gold', 21, 39, 604, 100)
	$gui_button_ectotogold = GUICtrlCreateButton('Convert Ectos to Gold', 31, 64, 180, 30)
	GUICtrlSetOnEvent($gui_button_ectotogold, 'GuiToolsTabButtonHandler')
	$gui_button_goldtolockpicks = GUICtrlCreateButton('Convert Gold to Lockpicks', 220, 64, 180, 30)
	GUICtrlSetOnEvent($gui_button_goldtolockpicks, 'GuiToolsTabButtonHandler')
	GUICtrlCreateLabel('Stand by rare material trader with ectos in inventory.', 31, 104, 500, 20)
	GUICtrlCreateGroup('', -99, -99, 1, 1)
	; v37: Tools button renamed 'Manually extract selected components' (wider so the caption is not clipped)
	GUICtrlCreateGroup('Other tools', 21, 149, 604, 135)
	$gui_button_attach = GUICtrlCreateButton('Attach to Guild Wars', 31, 174, 150, 30)
	GUICtrlSetOnEvent($gui_button_attach, 'GuiToolsTabButtonHandler')
	$gui_button_resetstats = GUICtrlCreateButton('Reset session stats', 191, 174, 150, 30)
	GUICtrlSetOnEvent($gui_button_resetstats, 'GuiToolsTabButtonHandler')
	$gui_button_toolsopenstorage = GUICtrlCreateButton('Open Storage', 351, 174, 120, 30)
	GUICtrlSetOnEvent($gui_button_toolsopenstorage, 'GuiToolsTabButtonHandler')
	GUICtrlSetTip($gui_button_toolsopenstorage, 'Open Xunlai storage window. Works remotely - view only from explorable areas. Also works while a farm is running.')
	$gui_button_extractupgrades = GUICtrlCreateButton('Manually extract selected components', 31, 212, 280, 30)
	GUICtrlSetOnEvent($gui_button_extractupgrades, 'GuiToolsTabButtonHandler')
	$gui_label_extractupgrades = GUICtrlCreateLabel('Specified items must be in your inventory (bags 1-4), with an Expert or Superior salvage kit.', 321, 214, 295, 30)
	Local $manualExtractTip = 'Extracts the components checked under Inventory > "Extract Components" from the items in your inventory now.' & @CRLF _
		& 'Does not use the Setup "Extract selected components before selling" checkbox - that only gates automatic extraction in the town pass.' & @CRLF _
		& 'The specified items must be in your inventory (bags 1-4, not equipped, identified) and you need an Expert or Superior salvage kit.' & @CRLF _
		& 'Store items protection wins. No kit is bought here (the town pass buys one when automatic extraction is on).'
	GUICtrlSetTip($gui_button_extractupgrades, $manualExtractTip)
	GUICtrlSetTip($gui_label_extractupgrades, $manualExtractTip)
	$gui_label_attachstatus = GUICtrlCreateLabel('Not attached', 31, 254, 500, 20)
	GUICtrlCreateGroup('', -99, -99, 1, 1)
	; v24: empty one Xunlai storage tab into the inventory
	GUICtrlCreateGroup('Empty storage tab', 21, 294, 604, 75)
	GUICtrlCreateLabel('Storage tab:', 31, 323, 65, 20)
	$gui_combo_emptytab = GUICtrlCreateCombo('', 101, 319, 110, 22, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	GUICtrlSetData($gui_combo_emptytab, StorageTabComboList(), 'I')
	$gui_button_emptytab = GUICtrlCreateButton('Empty Tab', 221, 316, 120, 28)
	GUICtrlSetOnEvent($gui_button_emptytab, 'GuiToolsTabButtonHandler')
	$gui_label_emptytab = GUICtrlCreateLabel('Moves the tab into your inventory one item at a time, from slot 1. In an outpost or town; stops when the inventory is full.', 351, 314, 265, 45)
	Local $emptyTabTip = 'Takes every item of the selected Xunlai storage tab (I to XIII, or the Anniversary tab) and moves it into your' & @CRLF _
		& 'inventory (bags 1-4), one by one starting with slot 1. Stacks top up the same item already in your bags first.' & @CRLF _
		& 'Only in an outpost or town, not while a farm runs. Stops and logs when your inventory is full.'
	GUICtrlSetTip($gui_combo_emptytab, $emptyTabTip)
	GUICtrlSetTip($gui_button_emptytab, $emptyTabTip)
	GUICtrlSetTip($gui_label_emptytab, $emptyTabTip)
	GUICtrlCreateGroup('', -99, -99, 1, 1)
	; v38: Sorting Inventory (Setup + Sort now) and the hidden Storage Setup page
	StorageSetupAddToolsSection()
	GUICtrlCreateTabItem('')
	; v38.9: About tab (after Tools). Tab index 7 remains Tools, so StorageSetupOnTabChange is unchanged.
	$gui_tab_about = GUICtrlCreateTabItem('About')
	_GUICtrlTab_SetBkColor($gui_botshub, $gui_tabs_parent, $THEME_PANEL_BG)
	$gui_about_title = GUICtrlCreateLabel('BotsHub 2.0', 31, 50, 580, 24)
	GUICtrlSetFont($gui_about_title, 12, 800)
	GUICtrlCreateLabel('BotsHub 2.0 is AMG''s enhanced edition of BotsHub, the AutoIt automation hub for Guild Wars 1. It keeps the original framework and adds the inventory, farming, and quality-of-life work developed for this edition.', 31, 84, 580, 48)
	GUICtrlCreateLabel('Original BotsHub', 31, 144, 580, 18)
	GUICtrlSetFont(-1, 9, 800)
	GUICtrlCreateLabel('The original project was created by caustic-kronos (also known as Kronos, Night, Svarog).', 31, 166, 580, 18)
	$gui_about_github = GUICtrlCreateLabel($ABOUT_GITHUB_URL, 31, 188, 580, 18, $SS_NOTIFY)
	GUICtrlSetFont($gui_about_github, 9, 400, 4)
	GUICtrlSetCursor($gui_about_github, 12)
	GUICtrlSetTip($gui_about_github, 'Open the original BotsHub repository')
	GUICtrlSetOnEvent($gui_about_github, 'AboutOpenGithub')
	GUICtrlCreateLabel('Feedback', 31, 226, 580, 18)
	GUICtrlSetFont(-1, 9, 800)
	GUICtrlCreateLabel('Have an addition, an optimization, or a bug-fix request? Email AMG at:', 31, 248, 580, 18)
	$gui_about_email = GUICtrlCreateLabel($ABOUT_EMAIL, 31, 270, 580, 18, $SS_NOTIFY)
	GUICtrlSetFont($gui_about_email, 9, 400, 4)
	GUICtrlSetCursor($gui_about_email, 12)
	GUICtrlSetTip($gui_about_email, 'Write to AMG')
	GUICtrlSetOnEvent($gui_about_email, 'AboutOpenEmail')
	GUICtrlCreateTabItem('')
	; v31: dark theme (lib/BotsHub-Theme.au3, colours in lib/BotsHub-Theme-Colors.au3)
	Local $themeTabItems[] = [$gui_tab_main, $gui_tab_runoptions, $gui_tab_farminfos, $gui_tab_teamoptions, $gui_tab_lootoptions, $gui_tab_follower, $gui_tab_titles, $gui_tab_tools, $gui_tab_about]
	ThemeApplyDark($gui_botshub, $gui_tabs_parent, $themeTabItems)
	TitlesTabApplyColors()
	AboutApplyColors()
	TopRightClusterLayout()
	StorageSetupFinishPage()

	GUIRegisterMsg($WM_COMMAND, 'WM_COMMAND_Handler')
	GUIRegisterMsg($WM_NOTIFY, 'WM_NOTIFY_Handler')
EndFunc


;~ v38.12: place the Xunlai chest and the template combo 7 px after the last tab header (About), keeping the save icon
;~ fixed at 618. Only moves those two controls; if the measured room is unusable the creation positions stay.
Func TopRightClusterLayout()
	Local Const $gap = 7, $iconSize = 20, $saveX = 618, $minComboWidth = 125, $maxComboWidth = 200
	Local $tabHandle = GUICtrlGetHandle($gui_tabs_parent)
	Local $count = _GUICtrlTab_GetItemCount($tabHandle)
	If $count < 1 Then Return False
	Local $rect = _GUICtrlTab_GetItemRect($tabHandle, $count - 1)
	If Not IsArray($rect) Then Return False
	Local $tabPos = ControlGetPos($gui_botshub, '', $tabHandle)
	Local $tabX = IsArray($tabPos) ? $tabPos[0] : 10
	Local $chestX = $tabX + $rect[2] + $gap
	Local $comboX = $chestX + $iconSize + $gap
	Local $comboWidth = $saveX - $gap - $comboX
	If $comboWidth > $maxComboWidth Then
		; a very narrow tab strip: keep the combo at its maximum width, right-justified against the save icon
		$comboWidth = $maxComboWidth
		$comboX = $saveX - $gap - $comboWidth
		$chestX = $comboX - $gap - $iconSize
	EndIf
	If $comboWidth < $minComboWidth Then Return False
	GUICtrlSetPos($gui_icon_openstorage, $chestX, 10, $iconSize, $iconSize)
	GUICtrlSetPos($gui_combo_configchoice, $comboX, 10, $comboWidth)
	Return True
EndFunc

;~ v38.9: gold title and clickable link colours, re-applied after ThemeApplyDark (which would otherwise paint them as body text)
Func AboutApplyColors()
	GUICtrlSetColor($gui_about_title, $THEME_ACCENT_GOLD)
	GUICtrlSetBkColor($gui_about_title, $THEME_PANEL_BG)
	GUICtrlSetColor($gui_about_github, $THEME_VALUE)
	GUICtrlSetBkColor($gui_about_github, $THEME_PANEL_BG)
	GUICtrlSetColor($gui_about_email, $THEME_VALUE)
	GUICtrlSetBkColor($gui_about_email, $THEME_PANEL_BG)
EndFunc


;~ v38.9: open the original BotsHub repository in the default browser
Func AboutOpenGithub()
	ShellExecute($ABOUT_GITHUB_URL)
EndFunc


;~ v38.9: open a mail compose window to AMG
Func AboutOpenEmail()
	ShellExecute('mailto:' & $ABOUT_EMAIL)
EndFunc


;~ Change the color of a tab
Func _GUICtrlTab_SetBkColor($gui, $parentTab, $color)
	Local $tabPosition = ControlGetPos($gui, '', $parentTab)
	Local $tabRectangle = _GUICtrlTab_GetItemRect($parentTab, -1)
	Local $pageLabel = GUICtrlCreateLabel('', $tabPosition[0]+2, $tabPosition[1]+$tabRectangle[3]+4, $tabPosition[2]-6, $tabPosition[3]-$tabRectangle[3]-7)
	GUICtrlSetBkColor($pageLabel, $color)
	GUICtrlSetState($pageLabel, $GUI_DISABLE)
	; v31: the theme pass keeps these page backgrounds (they are labels too)
	$theme_page_labels[$pageLabel] = True
EndFunc


#Region Handlers
;~ Handles WM_COMMAND elements, like combobox arrow clicks
Func WM_COMMAND_Handler($windowHandle, $messageCode, $packedParameters, $controlHandle)
	Local $notificationCode = BitShift($packedParameters, 16)
	Local $controlID = BitAND($packedParameters, 0xFFFF)

	Switch $controlID
		Case $gui_combo_characterchoice
			; Auto-attach is handled by the OnEvent handler (GuiMainButtonHandler) on selection. Doing it here fired on every
			; combo notification (focus, dropdown, close...) and showed blocking MsgBoxes inside a window-message handler.
			If $notificationCode = $gui_combobox_dropdown_opened Then
				ScanAndUpdateGameClients()
				RefreshCharactersComboBox()
			EndIf
		Case $gui_combo_farmchoice
			Switch $notificationCode
				Case $CBN_EDITCHANGE
					_GUICtrlComboBox_AutoComplete($gui_combo_farmchoice)
					$farm_name = GUICtrlRead($gui_combo_farmchoice)
					UpdateFarmDescription(GUICtrlRead($gui_combo_farmchoice))
			EndSwitch
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc


;~ Handles WM_NOTIFY elements, like treeview clicks
Func WM_NOTIFY_Handler($windowHandle, $messageCode, $unusedParam, $paramNotifyStruct)
	Local $notificationHeader = DllStructCreate('hwnd sourceHandle;int controlID;int notificationCode', $paramNotifyStruct)
	Local $sourceHandle = DllStructGetData($notificationHeader, 'sourceHandle')
	Local $notificationCode = DllStructGetData($notificationHeader, 'notificationCode')

	; v23: Items panel header rows
	If $items_panel_listview <> 0 And $notificationCode = $NM_CUSTOMDRAW And $sourceHandle = GUICtrlGetHandle($items_panel_listview) Then Return ItemsPanelCustomDraw($paramNotifyStruct)
	If $sourceHandle = GUICtrlGetHandle($gui_treeview_lootoptions) Then
		Switch $notificationCode
			Case $NM_CLICK
				Local $mousePos = _WinAPI_GetMousePos(True, $sourceHandle)
				Local $hitTestResult = _GUICtrlTreeView_HitTestEx($sourceHandle, DllStructGetData($mousePos, 1), DllStructGetData($mousePos, 2))
				Local $clickedItem = DllStructGetData($hitTestResult, 'Item')
				Local $hitFlags = DllStructGetData($hitTestResult, 'Flags')

				If $clickedItem <> 0 And BitAND($hitFlags, $TVHT_ONITEMSTATEICON) Then
					ToggleCheckboxCascade($sourceHandle, $clickedItem, True)
					ToggleCheckboxCascadeUpwards($sourceHandle, $clickedItem, True)
					InvalidateExtractLeavesCache()
				EndIf

			Case $TVN_KEYDOWN
				Local $keyInfo = DllStructCreate('hwnd;int;int;short key;uint', $paramNotifyStruct)
				Local $selectedItem = _GUICtrlTreeView_GetSelection($sourceHandle)
				; Spacebar pressed
				If DllStructGetData($keyInfo, 'key') = 0x20 And $selectedItem Then
					ToggleCheckboxCascade($sourceHandle, $selectedItem, True)
					ToggleCheckboxCascadeUpwards($sourceHandle, $selectedItem, True)
					InvalidateExtractLeavesCache()
				EndIf

			; v38.3: create a branch's children the first time it is expanded
			Case $TVN_ITEMEXPANDINGW, $TVN_ITEMEXPANDINGA
				Local $expandInfo = DllStructCreate($tagNMTREEVIEW, $paramNotifyStruct)
				If BitAND(DllStructGetData($expandInfo, 'Action'), $TVE_EXPAND) Then LootTreeOnExpanding($sourceHandle, DllStructGetData($expandInfo, 'NewParam'))
		EndSwitch
	EndIf
	Return $GUI_RUNDEFMSG
EndFunc


;~ Toggles checkbox state on a TreeView item and cascades it to children
Func ToggleCheckboxCascade($treeViewHandle, $itemHandle, $toggleFromRoot = False)
	Local $isChecked = _GUICtrlTreeView_GetChecked($treeViewHandle, $itemHandle)
	; Clicked item check status is only changed after WM_NOTIFY is handled, so it needs to be inverted
	If $toggleFromRoot Then $isChecked = Not $isChecked
	; v38.3: lazy Inventory tree - every descendant takes the new tick, created yet or not
	If LootTreeCascadeDown($treeViewHandle, $itemHandle, $isChecked) Then Return

	If _GUICtrlTreeView_GetChildren($treeViewHandle, $itemHandle) Then
		Local $childHandle = _GUICtrlTreeView_GetFirstChild($treeViewHandle, $itemHandle)
		While $childHandle <> 0
			_GUICtrlTreeView_SetChecked($treeViewHandle, $childHandle, $isChecked)
			ToggleCheckboxCascade($treeViewHandle, $childHandle)
			$childHandle = _GUICtrlTreeView_GetNextChild($treeViewHandle, $childHandle)
		WEnd
	EndIf
EndFunc


;~ Toggles checkbox state on a TreeView item and cascades it to its parents
Func ToggleCheckboxCascadeUpwards($treeViewHandle, $itemHandle, $toggleFromRoot = False)
	Local $parentHandle = _GUICtrlTreeView_GetParentHandle($treeViewHandle, $itemHandle)
	If $parentHandle == 0 Or $parentHandle == $itemHandle Then Return

	Local $allChildrenChecked = True
	Local $childHandle = _GUICtrlTreeView_GetFirstChild($treeViewHandle, $parentHandle)
	While $childHandle <> 0
		Local $childChecked = _GUICtrlTreeView_GetChecked($treeViewHandle, $childHandle)
		; Clicked item check status is only changed after WM_NOTIFY is handled, so it needs to be inverted
		If $toggleFromRoot And $childHandle == $itemHandle Then $childChecked = Not $childChecked
		If Not $childChecked Then
			$allChildrenChecked = False
			ExitLoop
		EndIf
		$childHandle = _GUICtrlTreeView_GetNextChild($treeViewHandle, $childHandle)
	WEnd
	_GUICtrlTreeView_SetChecked($treeViewHandle, $parentHandle, $allChildrenChecked)
	ToggleCheckboxCascadeUpwards($treeViewHandle, $parentHandle)
EndFunc


;~ Function handling tab changes
Func GuiTabHandler()
	Switch @GUI_CtrlId
		Case $gui_tabs_parent
			Switch GUICtrlRead($gui_tabs_parent)
				Case 0
					ControlEnable($gui_botshub, '', $gui_console)
					ControlShow($gui_botshub, '', $gui_console)
				Case Else
					ControlDisable($gui_botshub, '', $gui_console)
					ControlHide($gui_botshub, '', $gui_console)
			EndSwitch
			StorageSetupOnTabChange(GUICtrlRead($gui_tabs_parent))
		Case Else
			MsgBox(0, 'Error', 'This button is not coded yet.')
	EndSwitch
EndFunc


;~ Handle main GUI buttons usage
Func GuiMainButtonHandler()
	Switch @GUI_CtrlId
		Case $gui_combo_characterchoice
			$character_name = GUICtrlRead($gui_combo_characterchoice)
		Case $gui_combo_farmchoice
			$farm_name = GUICtrlRead($gui_combo_farmchoice)
			UpdateFarmDescription($farm_name)
		Case $gui_combo_configchoice
			Local $filePath = @ScriptDir & '/conf/farm/' & GUICtrlRead($gui_combo_configchoice) & '.json'
			LoadRunConfiguration($filePath)
			ApplyConfigToGUI()
			; If run config contains a link to loot config, we need to reload loot as well
			; We could compare old/new value or loot_configuration to see if this is worth it
			LoadDefaultLootConfiguration()
			BuildTreeViewFromCache($gui_treeview_lootoptions)
		Case $gui_icon_openstorage
			; v38.9: same Open Storage behaviour as the Setup and Tools buttons (v17)
			OpenStorageForTools()
		Case $gui_icon_saveconfig
			GUICtrlSetState($gui_icon_saveconfig, $GUI_DISABLE)
			Local $filePath = FileSaveDialog('', @ScriptDir & '\conf\farm', '(*.json)')
			If @error <> 0 Then
				Warn('Failed to write JSON configuration.')
			Else
				Local $configurationName = SaveRunConfiguration($filePath)
				FillConfigurationCombo($configurationName)
			EndIf
			GUICtrlSetState($gui_icon_saveconfig, $GUI_ENABLE)
		Case $GUI_EVENT_CLOSE
			; restore rendering in case it was disabled
			EnableRendering()
			Exit
		Case Else
			MsgBox(0, 'Error', 'This button is not coded yet.')
	EndSwitch
EndFunc


;~ Function handling start button
Func GuiStartButtonHandler()
	Switch $runtime_status
		Case 'UNINITIALIZED'
			Local $selectedCharacter = GUICtrlRead($gui_combo_characterchoice)
			$farm_name = GUICtrlRead($gui_combo_farmchoice)
			; Already attached to this character through Tools: no need to scan/inject a second time
			If Not ($attached_for_tools And $selectedCharacter == $character_name And $character_name <> '') Then
				$character_name = $selectedCharacter
				If (Authentification($character_name) <> $SUCCESS) Then Return
			EndIf
			$runtime_status = 'INITIALIZED'
			GUICtrlSetData($gui_startbutton, 'Pause')
			ThemeSetButton($gui_startbutton, $THEME_BTN_DANGER)
			$runtime_status = 'RUNNING'
			InvalidateExtractLeavesCache()
		Case 'INITIALIZED'
			$farm_name = GUICtrlRead($gui_combo_farmchoice)
			$runtime_status = 'RUNNING'
			InvalidateExtractLeavesCache()
		Case 'RUNNING'
			GUICtrlSetData($gui_startbutton, 'Will pause after this run')
			GUICtrlSetState($gui_startbutton, $GUI_DISABLE)
			ThemeSetButton($gui_startbutton, $THEME_BTN_WAITING)
			$runtime_status = 'WILL_PAUSE'
		Case 'WILL_PAUSE'
			MsgBox(0, 'Error', 'You should not be able to press Pause when bot is already pausing.')
		Case 'PAUSED'
			$farm_name = GUICtrlRead($gui_combo_farmchoice)
			GUICtrlSetData($gui_startbutton, 'Pause')
			ThemeSetButton($gui_startbutton, $THEME_BTN_DANGER)
			$runtime_status = 'RUNNING'
			InvalidateExtractLeavesCache()
		Case Else
			MsgBox(0, 'Error', 'Unknown status <' & $runtime_status & '>')
	EndSwitch
	FollowerStartButtonSync()
EndFunc


;~ v38.4: Follower tab Start button. Selects the Follower farm and presses the main Start button, so state, attach,
;~ caches and Pause / Will pause all go through GuiStartButtonHandler exactly as from the Main tab.
Func GuiFollowerStartButtonHandler()
	Switch $runtime_status
		Case 'UNINITIALIZED', 'INITIALIZED', 'PAUSED'
			Local $index = _GUICtrlComboBox_FindStringExact($gui_combo_farmchoice, 'Follower')
			If $index < 0 Then Return
			_GUICtrlComboBox_SetCurSel($gui_combo_farmchoice, $index)
			$farm_name = 'Follower'
			UpdateFarmDescription($farm_name)
			GuiStartButtonHandler()
		Case 'RUNNING'
			; Pause only the Follower farm from this tab (the button is disabled while another farm runs)
			If $farm_name == 'Follower' Then GuiStartButtonHandler()
	EndSwitch
	FollowerStartButtonSync()
EndFunc


;~ v38.4: mirror the main Start button on the Follower tab button: 'Start Follower' when idle, 'Pause' / 'Will pause after
;~ this run' while the Follower farm runs, disabled while another farm runs
Func FollowerStartButtonSync()
	If Not $gui_button_follower_start Then Return
	Local $followerActive = $farm_name == 'Follower'
	Switch $runtime_status
		Case 'RUNNING'
			If $followerActive Then
				GUICtrlSetData($gui_button_follower_start, 'Pause')
				GUICtrlSetState($gui_button_follower_start, $GUI_ENABLE)
				ThemeSetButton($gui_button_follower_start, $THEME_BTN_DANGER)
			Else
				GUICtrlSetData($gui_button_follower_start, 'Start Follower')
				GUICtrlSetState($gui_button_follower_start, $GUI_DISABLE)
				ThemeSetButton($gui_button_follower_start, $THEME_BTN_WAITING)
			EndIf
		Case 'WILL_PAUSE'
			GUICtrlSetData($gui_button_follower_start, $followerActive ? 'Will pause after this run' : 'Start Follower')
			GUICtrlSetState($gui_button_follower_start, $GUI_DISABLE)
			ThemeSetButton($gui_button_follower_start, $THEME_BTN_WAITING)
		Case Else
			GUICtrlSetData($gui_button_follower_start, 'Start Follower')
			GUICtrlSetState($gui_button_follower_start, $GUI_ENABLE)
			ThemeSetButton($gui_button_follower_start, $THEME_BTN_PRIMARY)
	EndSwitch
EndFunc


;~ Handle main GUI buttons usage
Func GuiOptionsHandler()
	Switch @GUI_CtrlId
		Case $gui_checkbox_loopruns
			$run_options_cache['run.loop_mode'] = GUICtrlRead($gui_checkbox_loopruns) == $GUI_CHECKED
		Case $gui_checkbox_hardmode
			$run_options_cache['run.hard_mode'] = GUICtrlRead($gui_checkbox_hardmode) == $GUI_CHECKED
		Case $gui_checkbox_salvageintocomponents
			$run_options_cache['run.salvage_into_materials'] = GUICtrlRead($gui_checkbox_salvageintocomponents) == $GUI_CHECKED
		Case $gui_checkbox_useconsumables
			$run_options_cache['run.consume_consumables'] = GUICtrlRead($gui_checkbox_useconsumables) == $GUI_CHECKED
		Case $gui_checkbox_useconsets
			$run_options_cache['run.use_consets'] = GUICtrlRead($gui_checkbox_useconsets) == $GUI_CHECKED
		Case $gui_checkbox_usescrolls
			$run_options_cache['run.use_scrolls'] = GUICtrlRead($gui_checkbox_usescrolls) == $GUI_CHECKED
		Case $gui_checkbox_gooffline
			$run_options_cache['run.go_offline'] = GUICtrlRead($gui_checkbox_gooffline) == $GUI_CHECKED
		Case $gui_checkbox_flashwhisper
			$run_options_cache['run.flash_whisper'] = GUICtrlRead($gui_checkbox_flashwhisper) == $GUI_CHECKED
		Case $gui_checkbox_sortitems
			$run_options_cache['run.sort_items'] = GUICtrlRead($gui_checkbox_sortitems) == $GUI_CHECKED
		Case $gui_radiobutton_donatepoints
			$run_options_cache['run.donate_faction_points'] = True
			$run_options_cache['run.buy_faction_resources'] = False
			$run_options_cache['run.buy_faction_scrolls'] = False
		Case $gui_radiobutton_buyfactionresources
			$run_options_cache['run.donate_faction_points'] = False
			$run_options_cache['run.buy_faction_resources'] = True
			$run_options_cache['run.buy_faction_scrolls'] = False
		Case $gui_radiobutton_buyfactionscrolls
			$run_options_cache['run.donate_faction_points'] = False
			$run_options_cache['run.buy_faction_resources'] = False
			$run_options_cache['run.buy_faction_scrolls'] = True
		Case $gui_combo_weaponslot
			Local $weaponSlot = Number(GUICtrlRead($gui_combo_weaponslot))
			$weaponSlot = _Max($weaponSlot, 0)
			$weaponSlot = _Min($weaponSlot, 4)
			$run_options_cache['run.weapon_slot'] = $weaponSlot
		Case $gui_combo_bagscount
			$bags_count = Number(GUICtrlRead($gui_combo_bagscount))
			$bags_count = _Max($bags_count, 1)
			$bags_count = _Min($bags_count, 5)
			$run_options_cache['run.bags_count'] = $bags_count
		Case $gui_combo_districtchoice
			$district_name = GUICtrlRead($gui_combo_districtchoice)
			$run_options_cache['run.district'] = $district_name
		Case $gui_renderbutton
			$rendering_enabled = Not $rendering_enabled
			$run_options_cache['run.disable_rendering'] = Not $rendering_enabled
			RefreshRenderingButton()
			ToggleRendering()
		Case $gui_button_openstorage
			; v17: like the original v10 button (town, explorable, while running); logs instead if not attached / client closed
			OpenStorageForTools()
		Case $gui_button_manualmode
			DynamicExecution(GUICtrlRead($gui_input_manualmode))
		Case $gui_checkbox_extractupgrades
			$run_options_cache['run.extract_upgrades_only'] = GUICtrlRead($gui_checkbox_extractupgrades) == $GUI_CHECKED
		Case $gui_checkbox_logchests
			$run_options_cache['run.log_chests'] = GUICtrlRead($gui_checkbox_logchests) == $GUI_CHECKED
		Case $gui_checkbox_returnondeath
			$run_options_cache['run.return_on_death'] = GUICtrlRead($gui_checkbox_returnondeath) == $GUI_CHECKED
			ApplyDeathReturnOption()
		Case $gui_checkbox_follower_permasf
			$run_options_cache['follower.perma_sf'] = GUICtrlRead($gui_checkbox_follower_permasf) == $GUI_CHECKED
		Case $gui_checkbox_follower_openchests
			$run_options_cache['follower.open_chests'] = GUICtrlRead($gui_checkbox_follower_openchests) == $GUI_CHECKED
		Case $gui_checkbox_follower_leadertarget
			$run_options_cache['follower.leader_target'] = GUICtrlRead($gui_checkbox_follower_leadertarget) == $GUI_CHECKED
		Case $gui_input_follower_name
			$run_options_cache['follower.name'] = GUICtrlRead($gui_input_follower_name)
		Case $gui_input_follower_leash
			$run_options_cache['follower.leash'] = Number(GUICtrlRead($gui_input_follower_leash))
		Case $gui_combo_bonder_mode
			$run_options_cache['follower.bonder_mode'] = GUICtrlRead($gui_combo_bonder_mode)
		Case Else
			Return
	EndSwitch
EndFunc


;~ Handle buttons in team tab
Func GuiTeamTabButtonHandler()
	Local $checked
	Switch @GUI_CtrlId
		Case $gui_checkbox_automaticteamsetup
			Local $autoTeamSetup = GUICtrlRead($gui_checkbox_automaticteamsetup) == $GUI_CHECKED
			$run_options_cache['team.automatic_team_setup'] = $autoTeamSetup
			UpdateTeamComboboxes($autoTeamSetup)
		; Saving the chosen heroes, in cache
		Case $gui_combo_hero_1
			$run_options_cache['team.hero_1'] = GUICtrlRead($gui_combo_hero_1)
		Case $gui_combo_hero_2
			$run_options_cache['team.hero_2'] = GUICtrlRead($gui_combo_hero_2)
		Case $gui_combo_hero_3
			$run_options_cache['team.hero_3'] = GUICtrlRead($gui_combo_hero_3)
		Case $gui_combo_hero_4
			$run_options_cache['team.hero_4'] = GUICtrlRead($gui_combo_hero_4)
		Case $gui_combo_hero_5
			$run_options_cache['team.hero_5'] = GUICtrlRead($gui_combo_hero_5)
		Case $gui_combo_hero_6
			$run_options_cache['team.hero_6'] = GUICtrlRead($gui_combo_hero_6)
		Case $gui_combo_hero_7
			$run_options_cache['team.hero_7'] = GUICtrlRead($gui_combo_hero_7)
		; Saving whether the player and hero builds are loaded, in cache
		Case $gui_checkbox_load_build_all
			Local $checked = GUICtrlRead($gui_checkbox_load_build_all) == $GUI_CHECKED
			$run_options_cache['team.load_all_builds'] = $checked
			; Setting all the run options to checked
			$run_options_cache['team.load_player_build'] = $checked
			$run_options_cache['team.load_hero_1_build'] = $checked
			$run_options_cache['team.load_hero_2_build'] = $checked
			$run_options_cache['team.load_hero_3_build'] = $checked
			$run_options_cache['team.load_hero_4_build'] = $checked
			$run_options_cache['team.load_hero_5_build'] = $checked
			$run_options_cache['team.load_hero_6_build'] = $checked
			$run_options_cache['team.load_hero_7_build'] = $checked
			; Setting all checkboxes checked/unchecked
			GUICtrlSetState($gui_checkbox_load_build_player, $checked ? $GUI_CHECKED : $GUI_UNCHECKED)
			GUICtrlSetState($gui_checkbox_load_build_hero_1, $checked ? $GUI_CHECKED : $GUI_UNCHECKED)
			GUICtrlSetState($gui_checkbox_load_build_hero_2, $checked ? $GUI_CHECKED : $GUI_UNCHECKED)
			GUICtrlSetState($gui_checkbox_load_build_hero_3, $checked ? $GUI_CHECKED : $GUI_UNCHECKED)
			GUICtrlSetState($gui_checkbox_load_build_hero_4, $checked ? $GUI_CHECKED : $GUI_UNCHECKED)
			GUICtrlSetState($gui_checkbox_load_build_hero_5, $checked ? $GUI_CHECKED : $GUI_UNCHECKED)
			GUICtrlSetState($gui_checkbox_load_build_hero_6, $checked ? $GUI_CHECKED : $GUI_UNCHECKED)
			GUICtrlSetState($gui_checkbox_load_build_hero_7, $checked ? $GUI_CHECKED : $GUI_UNCHECKED)
			; Setting all inputs enabled/disabled
			GUICtrlSetState($gui_input_build_player, $checked ? $GUI_ENABLE : $GUI_DISABLE)
			GUICtrlSetState($gui_input_build_hero_1, $checked ? $GUI_ENABLE : $GUI_DISABLE)
			GUICtrlSetState($gui_input_build_hero_2, $checked ? $GUI_ENABLE : $GUI_DISABLE)
			GUICtrlSetState($gui_input_build_hero_3, $checked ? $GUI_ENABLE : $GUI_DISABLE)
			GUICtrlSetState($gui_input_build_hero_4, $checked ? $GUI_ENABLE : $GUI_DISABLE)
			GUICtrlSetState($gui_input_build_hero_5, $checked ? $GUI_ENABLE : $GUI_DISABLE)
			GUICtrlSetState($gui_input_build_hero_6, $checked ? $GUI_ENABLE : $GUI_DISABLE)
			GUICtrlSetState($gui_input_build_hero_7, $checked ? $GUI_ENABLE : $GUI_DISABLE)
		Case $gui_checkbox_load_build_player
			$checked = GUICtrlRead($gui_checkbox_load_build_player) == $GUI_CHECKED
			$run_options_cache['team.load_player_build'] = $checked
			GUICtrlSetState($gui_input_build_player, $checked ? $GUI_ENABLE : $GUI_DISABLE)
		Case $gui_checkbox_load_build_hero_1
			$checked = GUICtrlRead($gui_checkbox_load_build_hero_1) == $GUI_CHECKED
			$run_options_cache['team.load_hero_1_build'] = $checked
			GUICtrlSetState($gui_input_build_hero_1, $checked ? $GUI_ENABLE : $GUI_DISABLE)
		Case $gui_checkbox_load_build_hero_2
			$checked = GUICtrlRead($gui_checkbox_load_build_hero_2) == $GUI_CHECKED
			$run_options_cache['team.load_hero_2_build'] = $checked
			GUICtrlSetState($gui_input_build_hero_2, $checked ? $GUI_ENABLE : $GUI_DISABLE)
		Case $gui_checkbox_load_build_hero_3
			$checked = GUICtrlRead($gui_checkbox_load_build_hero_3) == $GUI_CHECKED
			$run_options_cache['team.load_hero_3_build'] = $checked
			GUICtrlSetState($gui_input_build_hero_3, $checked ? $GUI_ENABLE : $GUI_DISABLE)
		Case $gui_checkbox_load_build_hero_4
			$checked = GUICtrlRead($gui_checkbox_load_build_hero_4) == $GUI_CHECKED
			$run_options_cache['team.load_hero_4_build'] = $checked
			GUICtrlSetState($gui_input_build_hero_4, $checked ? $GUI_ENABLE : $GUI_DISABLE)
		Case $gui_checkbox_load_build_hero_5
			$checked = GUICtrlRead($gui_checkbox_load_build_hero_5) == $GUI_CHECKED
			$run_options_cache['team.load_hero_5_build'] = $checked
			GUICtrlSetState($gui_input_build_hero_5, $checked ? $GUI_ENABLE : $GUI_DISABLE)
		Case $gui_checkbox_load_build_hero_6
			$checked = GUICtrlRead($gui_checkbox_load_build_hero_6) == $GUI_CHECKED
			$run_options_cache['team.load_hero_6_build'] = $checked
			GUICtrlSetState($gui_input_build_hero_6, $checked ? $GUI_ENABLE : $GUI_DISABLE)
		Case $gui_checkbox_load_build_hero_7
			$checked = GUICtrlRead($gui_checkbox_load_build_hero_7) == $GUI_CHECKED
			$run_options_cache['team.load_hero_7_build'] = $checked
			GUICtrlSetState($gui_input_build_hero_7, $checked ? $GUI_ENABLE : $GUI_DISABLE)
		; Saving the player and hero builds in cache
		Case $gui_input_build_player
			$run_options_cache['team.player_build'] = GUICtrlRead($gui_input_build_player)
		Case $gui_input_build_hero_1
			$run_options_cache['team.hero_1_build'] = GUICtrlRead($gui_input_build_hero_1)
		Case $gui_input_build_hero_2
			$run_options_cache['team.hero_2_build'] = GUICtrlRead($gui_input_build_hero_2)
		Case $gui_input_build_hero_3
			$run_options_cache['team.hero_3_build'] = GUICtrlRead($gui_input_build_hero_3)
		Case $gui_input_build_hero_4
			$run_options_cache['team.hero_4_build'] = GUICtrlRead($gui_input_build_hero_4)
		Case $gui_input_build_hero_5
			$run_options_cache['team.hero_5_build'] = GUICtrlRead($gui_input_build_hero_5)
		Case $gui_input_build_hero_6
			$run_options_cache['team.hero_6_build'] = GUICtrlRead($gui_input_build_hero_6)
		Case $gui_input_build_hero_7
			$run_options_cache['team.hero_7_build'] = GUICtrlRead($gui_input_build_hero_7)
		Case Else
			MsgBox(0, 'Error', 'This button is not coded yet.')
	EndSwitch
EndFunc


;~ Handle loot tab buttons
Func GuiLootTabButtonHandler()
	Switch @GUI_CtrlId
		Case $gui_expandlootoptionsbutton
			; v38.3: Expand all needs every branch, so the not-yet-created ones are created first
			LootTreeRealizeAll($gui_treeview_lootoptions)
			_GUICtrlTreeView_Expand(GUICtrlGetHandle($gui_treeview_lootoptions), 0, True)
		Case $gui_reducelootoptionsbutton
			_GUICtrlTreeView_Expand(GUICtrlGetHandle($gui_treeview_lootoptions), 0, False)
		Case $gui_loadlootoptionsbutton
			Local $filePath = FileOpenDialog('Please select a valid loot options file', @ScriptDir & '\conf\loot', '(*.json)')
			If @error <> 0 Then
				Warn('Failed to read JSON loot options configuration.')
			Else
				LoadLootConfiguration($filePath)
				BuildTreeViewFromCache($gui_treeview_lootoptions)
			EndIf
		Case $gui_savelootoptionsbutton
			Local $jsonObject = BuildJSONFromTreeView($gui_treeview_lootoptions)
			Local $jsonString = _JSON_Generate($jsonObject)
			Local $filePath = FileSaveDialog('', @ScriptDir & '\conf\loot', '(*.json)')
			If @error <> 0 Then
				Warn('Failed to write JSON loot options configuration.')
			Else
				Local $configFile = FileOpen($filePath, $FO_OVERWRITE + $FO_CREATEPATH + $FO_UTF8)
				FileWrite($configFile, $jsonString)
				FileClose($configFile)
				Info('Saved loot options configuration ' & $filePath)
			EndIf
		Case $gui_applylootoptionsbutton
			FillInventoryCacheFromTreeView($gui_treeview_lootoptions)
			BuildInventoryDerivedFlags()
			InvalidateExtractLeavesCache()
			Info('Refreshed inventory management options')
		Case Else
			MsgBox(0, 'Error', 'This button is not coded yet.')
	EndSwitch
EndFunc


;~ Update the farm description written on the rightmost tab
Func UpdateFarmDescription($farm)
	; v34: Build Info fills as soon as a farm is selected (no Load Script); display only
	BuildInfoShow($farm)
EndFunc


#Region Statistics management
;~ Fill statistics
Func UpdateStats($result, $elapsedTime = 0)
	; All static variables are initialized only once when UpdateStats() function is called first time
	Local Static $runs = 0
	Local Static $successes = 0
	Local Static $failures = 0
	Local Static $successRatio = 0
	Local Static $totalTime = 0
	Local Static $totalChests = 0
	Local Static $initialExperience = GetExperience()

	; v33: title points are on the Titles tab (lib/Utils-TitlesTab.au3, own per-character baseline)

	; v15: 'Reset session stats' -> start counting again from zero, with fresh baselines (same as the very first call)
	Local Static $generation = $stats_reset_generation
	If $generation <> $stats_reset_generation Then
		$generation = $stats_reset_generation
		$runs = 0
		$successes = 0
		$failures = 0
		$successRatio = 0
		$totalTime = 0
		$totalChests = 0
		$initialExperience = GetExperience()
	EndIf

	; $NOT_STARTED = -1 : Before every farm loop
	If $result == $NOT_STARTED Then
		Info('Starting run ' & ($runs + 1))
	; $SUCCESS = 0 : Successful farm run
	ElseIf $result == $SUCCESS Then
		$successes += 1
		$runs += 1
		$successRatio = Round(($successes / $runs) * 100, 2)
		$totalTime += $elapsedTime
	; $FAIL = 1 : Failed farm run
	ElseIf $result == $FAIL Then
		$failures += 1
		$runs += 1
		$successRatio = Round(($successes / $runs) * 100, 2)
		$totalTime += $elapsedTime
	EndIf
	; $PAUSE = 2 : Paused run or will pause

	; Global stats
	GUICtrlSetData($gui_label_runs_value, $runs)
	GUICtrlSetData($gui_label_successes_value, $successes)
	GUICtrlSetData($gui_label_failures_value, $failures)
	GUICtrlSetData($gui_label_successratio_value, $successRatio & ' %')
	GUICtrlSetData($gui_label_time_value, ConvertTimeToHourString($totalTime))
	Local $timePerRun = $runs == 0 ? 0 : $totalTime / $runs
	GUICtrlSetData($gui_label_timeperrun_value, ConvertTimeToMinutesString($timePerRun))
	$totalChests += CountOpenedChests()
	ClearChestsMap()
	GUICtrlSetData($gui_label_chests_value, $totalChests)
	GUICtrlSetData($gui_label_experience_value, (GetExperience() - $initialExperience))


	UpdateItemStats()
	Return $timePerRun
EndFunc


Func UpdateItemStats()
	; All static variables are initialized only once when UpdateItemStats() function is called first time
	; v23: only the 'Informations' items (gold, gold items, ectos, obsidian shards) are session gains; the Items panel shows
	; inventory + storage totals (ItemsPanelRefresh), so the per-item session counters for the old 'Items collected' labels are gone
	Local Static $itemsToCount[] = [$ID_GLOB_OF_ECTOPLASM, $ID_OBSIDIAN_SHARD]
	Local $itemCounts = CountTheseItems($itemsToCount)
	Local $goldItemsCount = CountGoldItems()

	Local Static $preRunGold = GetGoldCharacter()
	Local Static $preRunGoldItems = $goldItemsCount
	Local Static $totalGold = 0
	Local Static $totalGoldItems = 0

	Local Static $preRunEctos = $itemCounts[0]
	Local Static $preRunObsidianShards = $itemCounts[1]

	Local Static $totalEctos = 0
	Local Static $totalObsidianShards = 0

	; v15: 'Reset session stats' -> totals back to zero and fresh pre-run baselines (same as the very first call)
	Local Static $generation = $stats_reset_generation
	If $generation <> $stats_reset_generation Then
		$generation = $stats_reset_generation
		$preRunGold = GetGoldCharacter()
		$preRunGoldItems = $goldItemsCount
		$totalGold = 0
		$totalGoldItems = 0
		$preRunEctos = $itemCounts[0]
		$preRunObsidianShards = $itemCounts[1]
		$totalEctos = 0
		$totalObsidianShards = 0
	EndIf

	; Items stats, including inventory management situations when some items got sold or stored in chest, to update counters accordingly
	; Counting income surplus of every item group after each finished run
	Local $runIncomeGold = GetGoldCharacter() - $preRunGold
	Local $runIncomeGoldItems = $goldItemsCount - $preRunGoldItems
	Local $runIncomeEctos = $itemCounts[0] - $preRunEctos
	Local $runIncomeObsidianShards = $itemCounts[1] - $preRunObsidianShards

	; If income is positive then updating cumulative item stats. Income is negative when selling or storing items in chest
	If $runIncomeGold > 0 Then $totalGold += $runIncomeGold
	If $runIncomeGoldItems > 0 Then $totalGoldItems += $runIncomeGoldItems
	If $runIncomeEctos > 0 Then $totalEctos += $runIncomeEctos
	If $runIncomeObsidianShards > 0 Then $totalObsidianShards += $runIncomeObsidianShards

	; updating GUI labels with cumulative items counters
	GUICtrlSetData($gui_label_gold_value, Floor($totalGold/1000) & 'k' & Mod($totalGold, 1000) & 'g')
	GUICtrlSetData($gui_label_golditems_value, $totalGoldItems)
	GUICtrlSetData($gui_label_ectos_value, $totalEctos)
	GUICtrlSetData($gui_label_obsidianshards_value, $totalObsidianShards)

	; resetting items counters to count income surplus for the next run
	$preRunGold = GetGoldCharacter()
	$preRunGoldItems = $goldItemsCount
	$preRunEctos = $itemCounts[0]
	$preRunObsidianShards = $itemCounts[1]

	; v23: Items panel totals (inventory + storage) - run start/end is a safe point (no farm code running)
	ItemsPanelRefresh(True)
EndFunc
#EndRegion Statistics management


;~ Refresh rendering button according to current rendering status - should be split from real rendering logic
;~ v24: the text is the action a click does (it used to show the current state)
Func RefreshRenderingButton()
	If $rendering_enabled Then
		ThemeSetButton($gui_renderbutton, $THEME_BTN_WARNING, $THEME_BTN_WARNING_TEXT)
		GUICtrlSetData($gui_renderbutton, 'Disable Graphics')
	Else
		ThemeSetButton($gui_renderbutton, $THEME_BTN_SUCCESS)
		GUICtrlSetData($gui_renderbutton, 'Enable Graphics')
	EndIf
EndFunc


;~ Fill characters combobox
Func RefreshCharactersComboBox()
	Local $comboList = ''
	For $i = 1 To $game_clients[0][0]
		If $game_clients[$i][0] <> -1 Then $comboList &= '|' & $game_clients[$i][3]
	Next
	GUICtrlSetData($gui_combo_characterchoice, $comboList, '')
	If ($game_clients[0][0] > 0) Then
		SelectClient(1)
		GUICtrlSetData($gui_combo_characterchoice, $comboList, $game_clients[1][3])
		$character_name = $game_clients[1][3]
	EndIf
EndFunc


;~ Update team comboboxes
Func UpdateTeamComboboxes($autoTeamSetup)
	If $autoTeamSetup Then
		EnableTeamComboboxes()
	Else
		DisableTeamComboboxes()
	EndIf
EndFunc


;~ Enable team comboboxes
Func EnableTeamComboboxes()
	GUICtrlSetState($gui_checkbox_load_build_all, $GUI_ENABLE)
	GUICtrlSetState($gui_label_player, $GUI_ENABLE)
	GUICtrlSetState($gui_combo_hero_1, $GUI_ENABLE)
	GUICtrlSetState($gui_combo_hero_2, $GUI_ENABLE)
	GUICtrlSetState($gui_combo_hero_3, $GUI_ENABLE)
	GUICtrlSetState($gui_combo_hero_4, $GUI_ENABLE)
	GUICtrlSetState($gui_combo_hero_5, $GUI_ENABLE)
	GUICtrlSetState($gui_combo_hero_6, $GUI_ENABLE)
	GUICtrlSetState($gui_combo_hero_7, $GUI_ENABLE)

	GUICtrlSetState($gui_checkbox_load_build_all, $GUI_ENABLE)
	GUICtrlSetState($gui_checkbox_load_build_player, $GUI_ENABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_1, $GUI_ENABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_2, $GUI_ENABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_3, $GUI_ENABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_4, $GUI_ENABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_5, $GUI_ENABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_6, $GUI_ENABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_7, $GUI_ENABLE)

	GUICtrlSetState($gui_input_build_player, GUICtrlRead($gui_checkbox_load_build_player) == $GUI_CHECKED ? $GUI_ENABLE : $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_1, GUICtrlRead($gui_checkbox_load_build_hero_1) == $GUI_CHECKED ? $GUI_ENABLE : $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_2, GUICtrlRead($gui_checkbox_load_build_hero_2) == $GUI_CHECKED ? $GUI_ENABLE : $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_3, GUICtrlRead($gui_checkbox_load_build_hero_3) == $GUI_CHECKED ? $GUI_ENABLE : $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_4, GUICtrlRead($gui_checkbox_load_build_hero_4) == $GUI_CHECKED ? $GUI_ENABLE : $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_5, GUICtrlRead($gui_checkbox_load_build_hero_5) == $GUI_CHECKED ? $GUI_ENABLE : $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_6, GUICtrlRead($gui_checkbox_load_build_hero_6) == $GUI_CHECKED ? $GUI_ENABLE : $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_7, GUICtrlRead($gui_checkbox_load_build_hero_7) == $GUI_CHECKED ? $GUI_ENABLE : $GUI_DISABLE)
EndFunc


;~ Disable team comboboxes
Func DisableTeamComboboxes()
	GUICtrlSetState($gui_label_player, $GUI_DISABLE)
	GUICtrlSetState($gui_combo_hero_1, $GUI_DISABLE)
	GUICtrlSetState($gui_combo_hero_2, $GUI_DISABLE)
	GUICtrlSetState($gui_combo_hero_3, $GUI_DISABLE)
	GUICtrlSetState($gui_combo_hero_4, $GUI_DISABLE)
	GUICtrlSetState($gui_combo_hero_5, $GUI_DISABLE)
	GUICtrlSetState($gui_combo_hero_6, $GUI_DISABLE)
	GUICtrlSetState($gui_combo_hero_7, $GUI_DISABLE)

	GUICtrlSetState($gui_checkbox_load_build_all, $GUI_DISABLE)
	GUICtrlSetState($gui_checkbox_load_build_player, $GUI_DISABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_1, $GUI_DISABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_2, $GUI_DISABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_3, $GUI_DISABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_4, $GUI_DISABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_5, $GUI_DISABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_6, $GUI_DISABLE)
	GUICtrlSetState($gui_checkbox_load_build_hero_7, $GUI_DISABLE)

	GUICtrlSetState($gui_checkbox_load_build_all, $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_player, $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_1, $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_2, $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_3, $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_4, $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_5, $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_6, $GUI_DISABLE)
	GUICtrlSetState($gui_input_build_hero_7, $GUI_DISABLE)
EndFunc


;~ Enable most comboboxes
Func EnableGUIComboboxes()
	; Enabling changing account is non trivial
	;GUICtrlSetState($gui_combo_characterchoice, $GUI_ENABLE)
	GUICtrlSetState($gui_combo_farmchoice, $GUI_ENABLE)
	GUICtrlSetState($gui_combo_configchoice, $GUI_ENABLE)
	EnableTeamComboboxes()
EndFunc


;~ Disable most comboboxes
Func DisableGUIComboboxes()
	GUICtrlSetState($gui_combo_characterchoice, $GUI_DISABLE)
	GUICtrlSetState($gui_combo_farmchoice, $GUI_DISABLE)
	GUICtrlSetState($gui_combo_configchoice, $GUI_DISABLE)
	DisableTeamComboboxes()
EndFunc


;~ Update the progress bar
Func UpdateProgressBar($totalDuration = 0)
	Local Static $duration
	If IsDeclared('totalDuration') And $totalDuration <> 0 Then
		$duration = $totalDuration
	EndIf
	Local $progress = Floor((TimerDiff($run_timer) / $duration) * 100)
	; capping run progress at 98%
	If $progress > 98 Then $progress = 98
	GUICtrlSetData($gui_farmprogress, $progress)
EndFunc


;~ Update the progress bar to 100%
Func CompleteGUIFarmProgress()
	GUICtrlSetData($gui_farmprogress, 100)
EndFunc
#EndRegion Handlers
#EndRegion GUI


#Region Configuration
;~ Fill the choice of configuration
Func FillConfigurationCombo($configuration = 'Default Farm Configuration')
	Local $files = _FileListToArray(@ScriptDir & '/conf/farm/', '*.json', $FLTA_FILES)
	Local $comboList = ''
	If @error == 0 Then
		For $file In $files
			Local $fileNameTrimmed = StringTrimRight($file, 5)
			If $fileNameTrimmed <> '' Then
				$comboList &= '|'
				$comboList &= $fileNameTrimmed
			EndIf
		Next
	EndIf
	GUICtrlSetData($gui_combo_configchoice, $comboList, $configuration)
EndFunc


;~ Read given config from JSON
Func ApplyConfigToGUI()
	GUICtrlSetData($gui_combo_characterchoice, $character_name)
	GUICtrlSetData($gui_combo_farmchoice, $AVAILABLE_FARMS, $farm_name)
	UpdateFarmDescription($farm_name)

	GUICtrlSetData($gui_combo_weaponslot, $run_options_cache['run.weapon_slot'])
	GUICtrlSetData($gui_combo_bagscount, $bags_count)
	GUICtrlSetData($gui_combo_districtchoice, $district_name)
	RefreshRenderingButton()
	GUICtrlSetState($gui_checkbox_loopruns, $run_options_cache['run.loop_mode'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_hardmode, $run_options_cache['run.hard_mode'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_salvageintocomponents, $run_options_cache['run.salvage_into_materials'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_useconsumables, $run_options_cache['run.consume_consumables'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_useconsets, $run_options_cache['run.use_consets'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_usescrolls, $run_options_cache['run.use_scrolls'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_gooffline, $run_options_cache['run.go_offline'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_flashwhisper, $run_options_cache['run.flash_whisper'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_sortitems, $run_options_cache['run.sort_items'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_radiobutton_donatepoints, $run_options_cache['run.donate_faction_points'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_radiobutton_buyfactionresources, $run_options_cache['run.buy_faction_resources'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_radiobutton_buyfactionscrolls, $run_options_cache['run.buy_faction_scrolls'] ? $GUI_CHECKED : $GUI_UNCHECKED)

	GUICtrlSetState($gui_checkbox_automaticteamsetup, $run_options_cache['team.automatic_team_setup'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetData($gui_combo_hero_1, $run_options_cache['team.hero_1'])
	GUICtrlSetData($gui_combo_hero_2, $run_options_cache['team.hero_2'])
	GUICtrlSetData($gui_combo_hero_3, $run_options_cache['team.hero_3'])
	GUICtrlSetData($gui_combo_hero_4, $run_options_cache['team.hero_4'])
	GUICtrlSetData($gui_combo_hero_5, $run_options_cache['team.hero_5'])
	GUICtrlSetData($gui_combo_hero_6, $run_options_cache['team.hero_6'])
	GUICtrlSetData($gui_combo_hero_7, $run_options_cache['team.hero_7'])
	GUICtrlSetState($gui_checkbox_load_build_all, $run_options_cache['team.load_all_builds'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_load_build_player, $run_options_cache['team.load_player_build'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_load_build_hero_1, $run_options_cache['team.load_hero_1_build'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_load_build_hero_2, $run_options_cache['team.load_hero_2_build'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_load_build_hero_3, $run_options_cache['team.load_hero_3_build'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_load_build_hero_4, $run_options_cache['team.load_hero_4_build'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_load_build_hero_5, $run_options_cache['team.load_hero_5_build'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_load_build_hero_6, $run_options_cache['team.load_hero_6_build'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_load_build_hero_7, $run_options_cache['team.load_hero_7_build'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetData($gui_input_build_player, $run_options_cache['team.player_build'])
	GUICtrlSetData($gui_input_build_hero_1, $run_options_cache['team.hero_1_build'])
	GUICtrlSetData($gui_input_build_hero_2, $run_options_cache['team.hero_2_build'])
	GUICtrlSetData($gui_input_build_hero_3, $run_options_cache['team.hero_3_build'])
	GUICtrlSetData($gui_input_build_hero_4, $run_options_cache['team.hero_4_build'])
	GUICtrlSetData($gui_input_build_hero_5, $run_options_cache['team.hero_5_build'])
	GUICtrlSetData($gui_input_build_hero_6, $run_options_cache['team.hero_6_build'])
	GUICtrlSetData($gui_input_build_hero_7, $run_options_cache['team.hero_7_build'])
	UpdateTeamComboboxes($run_options_cache['team.automatic_team_setup'])

	; Options added after the original GUI: they were never pushed back to the controls on config load
	GUICtrlSetState($gui_checkbox_extractupgrades, $run_options_cache['run.extract_upgrades_only'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_logchests, $run_options_cache['run.log_chests'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_returnondeath, $run_options_cache['run.return_on_death'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_follower_permasf, $run_options_cache['follower.perma_sf'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_follower_openchests, $run_options_cache['follower.open_chests'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetState($gui_checkbox_follower_leadertarget, $run_options_cache['follower.leader_target'] ? $GUI_CHECKED : $GUI_UNCHECKED)
	GUICtrlSetData($gui_input_follower_name, $run_options_cache['follower.name'])
	GUICtrlSetData($gui_input_follower_leash, $run_options_cache['follower.leash'])
	GUICtrlSetData($gui_combo_bonder_mode, $run_options_cache['follower.bonder_mode'])
EndFunc
#EndRegion Configuration


#Region Loot Tree View Management
;~ Fill inventory cache from JSON
Func FillInventoryCacheFromJSON($jsonNode, $currentPath)
	If IsMap($jsonNode) Then
		Local $checked = True
		For $key In MapKeys($jsonNode)
			If Not FillInventoryCacheFromJSON($jsonNode[$key], ($currentPath == '') ? $key : ($currentPath & '.' & $key)) Then $checked = False
		Next
		$inventory_management_cache[$currentPath] = $checked
		Return $checked
	Else
		$inventory_management_cache[$currentPath] = $jsonNode
		Return $jsonNode
	EndIf
EndFunc


Func FreeLootTreeViewItemControls()
	Local $i
	For $i = 0 To UBound($loot_treeview_item_ctrlids) - 1
		If $loot_treeview_item_ctrlids[$i] Then GUICtrlDelete($loot_treeview_item_ctrlids[$i])
	Next
	Local $empty[0]
	$loot_treeview_item_ctrlids = $empty
	Local $emptyPaths[]
	$loot_treeview_path_ids = $emptyPaths
	; v38.3: no node exists any more, so no branch is filled in
	Local $emptyPopulated[]
	$loot_tree_populated = $emptyPopulated
	Local $emptyIdPaths[]
	$loot_tree_id_paths = $emptyIdPaths
EndFunc


;~ Expected Inventory-tree paths: every dotted prefix of every non-@ cache key.
Func LootTreeExpectedPaths()
	Local $paths[]
	Local $key, $i, $parts, $currentPath
	For $key In MapKeys($inventory_management_cache)
		If $key == '' Or StringLeft($key, 1) == '@' Then ContinueLoop
		$parts = StringSplit($key, '.')
		$currentPath = ''
		For $i = 1 To $parts[0]
			$currentPath &= ($currentPath == '') ? $parts[$i] : ('.' & $parts[$i])
			$paths[$currentPath] = True
		Next
	Next
	Return $paths
EndFunc

;~ True when the tree model already has exactly the expected set of path nodes (same structure)
;~ and its top-level branches exist in the control.
;~ v38.3: compares the lazy-tree model (every node, created or not) instead of the created controls only.
Func LootTreeStructureMatches(ByRef $expected)
	If Not IsMap($loot_treeview_path_ids) Then Return False
	Local $nExp = 0, $nHave = UBound($loot_tree_preorder), $p
	For $p In MapKeys($expected)
		$nExp += 1
		If Not MapExists($loot_tree_index, $p) Then Return False
	Next
	If Not MapExists($loot_tree_children, '') Then Return False
	Local $roots = StringSplit($loot_tree_children[''], @LF, 2)
	For $p In $roots
		If Not MapExists($loot_treeview_path_ids, $p) Then Return False
		If Not $loot_treeview_path_ids[$p] Then Return False
	Next
	Return $nExp > 0 And $nExp == $nHave
EndFunc

;~ v38.2: same ticks, no node create/destroy. Also leaves the tree collapsed (v37.3 Load behaviour).
;~ v38.3: nodes not created yet get the tick in the model; created nodes get it in the control.
Func LootTreeApplyChecksFromCache($guiTreeviewHandle)
	Local $hWnd = $guiTreeviewHandle
	If Not IsHWnd($hWnd) Then $hWnd = GUICtrlGetHandle($guiTreeviewHandle)
	If $hWnd = 0 Then $hWnd = $guiTreeviewHandle
	_GUICtrlTreeView_BeginUpdate($hWnd)
	InvalidateExtractLeavesCache()
	Local $key
	For $key In MapKeys($inventory_management_cache)
		If $key == '' Or StringLeft($key, 1) == '@' Then ContinueLoop
		If Not MapExists($loot_tree_index, $key) Then ContinueLoop
		$loot_tree_states[$key] = $inventory_management_cache[$key] ? True : False
		If MapExists($loot_treeview_path_ids, $key) Then _GUICtrlTreeView_SetChecked($hWnd, GUICtrlGetHandle($loot_treeview_path_ids[$key]), $inventory_management_cache[$key])
	Next
	; v37.3: leave the tree fully collapsed (top-level branches only) at startup and after Load.
	_GUICtrlTreeView_Expand($hWnd, 0, False)
	_GUICtrlTreeView_EndUpdate($hWnd)
EndFunc

;~ Build TreeView from flat map
;~ v37.2: BeginUpdate/EndUpdate so the tree is not redrawn per item; GUICtrlCreateTreeViewItem IDs are kept
;~ (ThemeColorTreeBranches and GUICtrlSetState need them) and freed before a rebuild so Load does not leak IDs.
;~ v38.2: when the tree structure already matches the cache, only checkmarks are updated (no ID leak, no recreate).
;~ v38.3: lazy - the model holds every node and tick; only the top-level branches are created here, the rest
;~ of a branch the first time it is expanded (LootTreeOnExpanding). Same nodes, order and ticks as a full build.
Func BuildTreeViewFromCache($guiTreeviewHandle)
	; v38.3: the structure check only applies to the tree the model was built for (skipped at startup)
	If LootTreeIsModelTree($guiTreeviewHandle) Then
		Local $expected = LootTreeExpectedPaths()
		If LootTreeStructureMatches($expected) Then
			LootTreeApplyChecksFromCache($guiTreeviewHandle)
			Return
		EndIf
	EndIf
	Local $hWnd = $guiTreeviewHandle
	If Not IsHWnd($hWnd) Then $hWnd = GUICtrlGetHandle($guiTreeviewHandle)
	If $hWnd = 0 Then $hWnd = $guiTreeviewHandle
	_GUICtrlTreeView_BeginUpdate($hWnd)
	FreeLootTreeViewItemControls()
	_GUICtrlTreeView_DeleteAll($guiTreeviewHandle)
	InvalidateExtractLeavesCache()
	LootTreeBuildModel($guiTreeviewHandle)
	LootTreePopulate($guiTreeviewHandle, '')
	; v37.3: leave the tree fully collapsed (top-level branches only) at startup and after Load.
	; Expand all / Reduce all still work as before.
	; v31: dark theme - branch / section titles in gold
	ThemeColorTreeBranches($guiTreeviewHandle)
	_GUICtrlTreeView_EndUpdate($hWnd)
EndFunc


;~ v38.3: the full Inventory tree shape, in the exact node order and with the exact ticks the v38.2 full build created.
Func LootTreeBuildModel($guiTreeviewHandle)
	; v36.1: display-only root order matches town-pass execution (Store items after Extract, before Salvage).
	; 'Extract upgrades only' is the pre-migration alias and is kept so any leftover key still sorts with Extract.
	Local $rootOrder[] = ['Pick up items', 'Identify items', 'Extract Components', 'Extract upgrades only', 'Store items', 'Salvage items', 'Sell items', 'Buy items']
	Local $nRoots = UBound($rootOrder)
	Local $rootRank[]
	Local $i, $j, $dot, $key, $first, $rank
	For $i = 0 To $nRoots - 1
		$rootRank[$rootOrder[$i]] = $i
	Next
	Local $allKeys = MapKeys($inventory_management_cache)
	Local $nKeys = UBound($allKeys)
	; key order of the v38.2 build: keys of each root in $rootOrder (cache order), then every other drawable key.
	; One pass: a key belongs to root R when it is R or starts with 'R.' (= its first dotted part is R).
	Local $rankOf[$nKeys], $rankCount[$nRoots + 1]
	For $i = 0 To $nRoots
		$rankCount[$i] = 0
	Next
	For $i = 0 To $nKeys - 1
		$key = $allKeys[$i]
		$dot = StringInStr($key, '.')
		$first = $dot > 0 ? StringLeft($key, $dot - 1) : $key
		If MapExists($rootRank, $first) Then
			$rank = $rootRank[$first]
		ElseIf $key == '' Or StringLeft($key, 1) == '@' Then
			$rank = -1
		Else
			$rank = $nRoots
		EndIf
		$rankOf[$i] = $rank
		If $rank >= 0 Then $rankCount[$rank] += 1
	Next
	Local $rankStart[$nRoots + 1], $nOrdered = 0
	For $i = 0 To $nRoots
		$rankStart[$i] = $nOrdered
		$nOrdered += $rankCount[$i]
	Next
	Local $orderedKeys[$nOrdered]
	For $i = 0 To $nKeys - 1
		$rank = $rankOf[$i]
		If $rank < 0 Then ContinueLoop
		$orderedKeys[$rankStart[$rank]] = $allKeys[$i]
		$rankStart[$rank] += 1
	Next
	; nodes in creation order: parent -> children (@LF joined), tick per node
	Local $children[], $states[]
	Local $nNodes = 0
	For $j = 0 To $nOrdered - 1
		$key = $orderedKeys[$j]
		LootTreeModelAddNode($key, $children, $states, $nNodes)
		$states[$key] = $inventory_management_cache[$key] ? True : False
	Next
	; depth-first order = the order a walk of the full control visits the nodes
	Local $order[$nNodes], $ends[$nNodes], $index[]
	Local $n = 0
	LootTreePreorderFill('', $children, $order, $ends, $index, $n)
	$loot_tree_preorder = $order
	$loot_tree_subtree_end = $ends
	$loot_tree_index = $index
	$loot_tree_children = $children
	$loot_tree_states = $states
	Local $emptyPopulated[]
	$loot_tree_populated = $emptyPopulated
	Local $emptyIdPaths[]
	$loot_tree_id_paths = $emptyIdPaths
	$loot_tree_model_hwnd = IsHWnd($guiTreeviewHandle) ? $guiTreeviewHandle : GUICtrlGetHandle($guiTreeviewHandle)
	$loot_tree_model_ctrl = IsHWnd($guiTreeviewHandle) ? _WinAPI_GetDlgCtrlID($guiTreeviewHandle) : $guiTreeviewHandle
EndFunc


;~ Adds $path and its missing ancestors to the model, ancestors first (the order the v38.2 build created tree items).
;~ A new node starts unticked, like a freshly created tree item.
Func LootTreeModelAddNode($path, ByRef $children, ByRef $states, ByRef $nNodes)
	If MapExists($states, $path) Then Return
	Local $dot = StringInStr($path, '.', 0, -1)
	Local $parentPath = ''
	If $dot > 0 Then
		$parentPath = StringLeft($path, $dot - 1)
		LootTreeModelAddNode($parentPath, $children, $states, $nNodes)
	EndIf
	$states[$path] = False
	$nNodes += 1
	If MapExists($children, $parentPath) Then
		$children[$parentPath] &= @LF & $path
	Else
		$children[$parentPath] = $path
	EndIf
EndFunc


Func LootTreePreorderFill($parentPath, ByRef $children, ByRef $order, ByRef $ends, ByRef $index, ByRef $n)
	If Not MapExists($children, $parentPath) Then Return
	Local $kid, $at
	Local $kids = StringSplit($children[$parentPath], @LF, 2)
	For $kid In $kids
		$at = $n
		$order[$at] = $kid
		$index[$kid] = $at
		$n += 1
		LootTreePreorderFill($kid, $children, $order, $ends, $index, $n)
		$ends[$at] = $n - 1
	Next
EndFunc


;~ True when $treeViewHandle (control ID or handle) is the tree the lazy model belongs to
Func LootTreeIsModelTree($treeViewHandle)
	If $loot_tree_model_hwnd = 0 Then Return False
	Local $hWnd = IsHWnd($treeViewHandle) ? $treeViewHandle : GUICtrlGetHandle($treeViewHandle)
	If $hWnd = 0 Then Return False
	Return $hWnd = $loot_tree_model_hwnd
EndFunc


;~ Last part of a dotted path (the label of its tree item)
Func LootTreeNodeLabel($path)
	Local $dot = StringInStr($path, '.', 0, -1)
	Return $dot > 0 ? StringMid($path, $dot + 1) : $path
EndFunc


;~ Gold for branch titles, light text for leaves (same colours as ThemeColorTreeBranches)
Func LootTreeColorNode($itemID, $isBranch)
	If Not $theme_dark_enabled Then Return
	GUICtrlSetColor($itemID, $isBranch ? $THEME_ACCENT_GOLD : $THEME_TEXT)
EndFunc


;~ Create the children of $parentPath ('' = top-level branches) once, with their ticks from the model.
;~ A child that has children of its own gets an expand button; its children are created when it is expanded.
Func LootTreePopulate($guiTreeviewHandle, $parentPath)
	If Not LootTreeIsModelTree($guiTreeviewHandle) Then Return 0
	If MapExists($loot_tree_populated, $parentPath) Then Return 0
	If $parentPath <> '' And Not MapExists($loot_treeview_path_ids, $parentPath) Then Return 0
	$loot_tree_populated[$parentPath] = True
	If Not MapExists($loot_tree_children, $parentPath) Then Return 0
	; tree items are created under the tree's control ID (top level) or the parent item's control ID;
	; check / expand-button calls take the tree and item handles (a control ID with a tree handle is not converted)
	Local $parentID = ($parentPath == '') ? $loot_tree_model_ctrl : $loot_treeview_path_ids[$parentPath]
	Local $hWnd = $loot_tree_model_hwnd, $hItem
	Local $kids = StringSplit($loot_tree_children[$parentPath], @LF, 2)
	Local $base = UBound($loot_treeview_item_ctrlids)
	ReDim $loot_treeview_item_ctrlids[$base + UBound($kids)]
	Local $k = 0, $kid, $itemID, $isBranch
	For $kid In $kids
		$itemID = GUICtrlCreateTreeViewItem(LootTreeNodeLabel($kid), $parentID)
		$loot_treeview_item_ctrlids[$base + $k] = $itemID
		$k += 1
		$loot_treeview_path_ids[$kid] = $itemID
		$loot_tree_id_paths[String($itemID)] = $kid
		$hItem = GUICtrlGetHandle($itemID)
		_GUICtrlTreeView_SetChecked($hWnd, $hItem, $loot_tree_states[$kid])
		$isBranch = MapExists($loot_tree_children, $kid)
		If $isBranch Then _GUICtrlTreeView_SetChildren($hWnd, $hItem, True)
		LootTreeColorNode($itemID, $isBranch)
	Next
	Return $k
EndFunc


;~ TVN_ITEMEXPANDING on the lazy tree: $itemParam is the item's control ID
Func LootTreeOnExpanding($treeViewHandle, $itemParam)
	If Not LootTreeIsModelTree($treeViewHandle) Then Return
	Local $idKey = String($itemParam)
	If Not MapExists($loot_tree_id_paths, $idKey) Then Return
	Local $path = $loot_tree_id_paths[$idKey]
	If MapExists($loot_tree_populated, $path) Then Return
	LootTreePopulate($treeViewHandle, $path)
EndFunc


;~ Create every node of the lazy tree that does not exist yet (Expand all, and any walk of the control itself)
Func LootTreeRealizeAll($guiTreeviewHandle)
	If Not LootTreeIsModelTree($guiTreeviewHandle) Then Return
	Local $hWnd = IsHWnd($guiTreeviewHandle) ? $guiTreeviewHandle : GUICtrlGetHandle($guiTreeviewHandle)
	Local $i, $path
	_GUICtrlTreeView_BeginUpdate($hWnd)
	If Not MapExists($loot_tree_populated, '') Then LootTreePopulate($guiTreeviewHandle, '')
	For $i = 0 To UBound($loot_tree_preorder) - 1
		If $loot_tree_subtree_end[$i] == $i Then ContinueLoop
		$path = $loot_tree_preorder[$i]
		If MapExists($loot_tree_populated, $path) Then ContinueLoop
		LootTreePopulate($guiTreeviewHandle, $path)
	Next
	_GUICtrlTreeView_EndUpdate($hWnd)
EndFunc


;~ Tick of one node: the control for a created node, the model for one not created yet
Func LootTreeNodeState($treeViewHandle, $path)
	If MapExists($loot_treeview_path_ids, $path) Then Return _GUICtrlTreeView_GetChecked($loot_tree_model_hwnd, GUICtrlGetHandle($loot_treeview_path_ids[$path]))
	Return $loot_tree_states[$path]
EndFunc


;~ Clicked / space-toggled node of the lazy tree: every descendant (created or not) takes $isChecked.
;~ False when $itemHandle is not a node of the lazy tree (the caller then cascades over the control as before).
Func LootTreeCascadeDown($treeViewHandle, $itemHandle, $isChecked)
	If Not LootTreeIsModelTree($treeViewHandle) Then Return False
	Local $idKey = String(_GUICtrlTreeView_GetItemParam($treeViewHandle, $itemHandle))
	If Not MapExists($loot_tree_id_paths, $idKey) Then Return False
	Local $path = $loot_tree_id_paths[$idKey]
	Local $at = $loot_tree_index[$path]
	Local $j, $p
	For $j = $at + 1 To $loot_tree_subtree_end[$at]
		$p = $loot_tree_preorder[$j]
		$loot_tree_states[$p] = $isChecked
		If MapExists($loot_treeview_path_ids, $p) Then _GUICtrlTreeView_SetChecked($loot_tree_model_hwnd, GUICtrlGetHandle($loot_treeview_path_ids[$p]), $isChecked)
	Next
	Return True
EndFunc


;~ Walk of the whole lazy tree from its model, for the walks the hub does: Apply (AddToInventoryCache),
;~ Save (AddLeavesToJSONObject), live extract / store ticks (AddLeafStateToMap) and AddLeafToArray.
;~ Same nodes, same order, same values as those callbacks on the fully built control. False = not handled here.
Func LootTreeModelWalk(ByRef $context, $treeViewHandle, $currentPath, $functionToApply, $maxDepth)
	If $currentPath <> '' Or $maxDepth <> -1 Then Return False
	If $functionToApply == Null Then Return True
	Local $mode = 0
	Switch FuncName($functionToApply)
		Case 'AddLeafStateToMap'
			$mode = 1
		Case 'AddToInventoryCache'
			$mode = 2
		Case 'AddLeavesToJSONObject'
			$mode = 3
		Case 'AddLeafToArray'
			$mode = 4
		Case Else
			Return False
	EndSwitch
	Local $i, $path, $state
	For $i = 0 To UBound($loot_tree_preorder) - 1
		$path = $loot_tree_preorder[$i]
		$state = LootTreeNodeState($treeViewHandle, $path)
		Switch $mode
			Case 1
				$context[$path] = $state
			Case 2
				$inventory_management_cache[$path] = $state
			Case 3
				If $loot_tree_subtree_end[$i] == $i Then _JSON_addChangeDelete($context, $path, $state)
			Case 4
				If $loot_tree_subtree_end[$i] == $i And $state Then _ArrayAdd($context, $path)
		EndSwitch
	Next
	Return True
EndFunc


;~ Fill the inventory cache with the treeview data
Func FillInventoryCacheFromTreeView($treeViewHandle)
	IterateOverTreeView(Null, $treeViewHandle, Null, '', AddToInventoryCache)
EndFunc


;~ Utility function to add treeview elements to the inventory cache
Func AddToInventoryCache(ByRef $context, $treeViewHandle, $treeViewItem, $currentPath)
	$inventory_management_cache[$currentPath] = _GUICtrlTreeView_GetChecked($treeViewHandle, $treeViewItem)
EndFunc


;~ Creating a JSON node from a treeview
Func BuildJSONFromTreeView($treeViewHandle, $treeViewItem = Null, $currentPath = '')
	Local $jsonObject
	IterateOverTreeView($jsonObject, $treeViewHandle, $treeViewItem, $currentPath, AddLeavesToJSONObject)
	Return $jsonObject
EndFunc


;~ Utility function to add treeview elements to a JSON object
Func AddLeavesToJSONObject(ByRef $context, $treeViewHandle, $treeViewItem, $currentPath)
	; We are on a leaf
	If _GUICtrlTreeView_GetChildCount($treeViewHandle, $treeViewItem) <= 0 Then
		_JSON_addChangeDelete($context, $currentPath, _GUICtrlTreeView_GetChecked($treeViewHandle, $treeViewItem))
	EndIf
EndFunc


;~ Creating an array from a treeview
Func BuildArrayFromTreeView($treeViewHandle, $treeViewItem = Null, $currentPath = '', $recursive = True)
	Local $array[0]
	IterateOverTreeView($array, $treeViewHandle, $treeViewItem, $currentPath, AddLeafToArray, $recursive ? -1 : 2)
	Return $array
EndFunc


;~ Utility function to add treeview elements to an array
Func AddLeafToArray(ByRef $context, $treeViewHandle, $treeViewItem, $currentPath)
	; We are on a leaf
	If _GUICtrlTreeView_GetChildCount($treeViewHandle, $treeViewItem) <= 0 Then
		If _GUICtrlTreeView_GetChecked($treeViewHandle, $treeViewItem) Then _ArrayAdd($context, $currentPath)
	EndIf
EndFunc


;~ Iterate over a treeview and make an operation on every node - can be called on root node (Null) or any other node
Func IterateOverTreeView(ByRef $context, $treeViewHandle, $treeViewItem = Null, $currentPath = '', $functionToApply = Null, $maxDepth = -1)
	; v38.3: the lazy Inventory tree is walked from its model (same nodes, same order, same ticks as a full tree);
	; any other walk of it first creates every node, then walks the control as before
	If LootTreeIsModelTree($treeViewHandle) Then
		If $treeViewItem == Null And LootTreeModelWalk($context, $treeViewHandle, $currentPath, $functionToApply, $maxDepth) Then Return
		LootTreeRealizeAll($treeViewHandle)
	EndIf
	If $treeViewItem == Null Then
		$treeViewItem = _GUICtrlTreeView_GetFirstItem($treeViewHandle)
		While $treeViewItem <> 0
			IterateOverTreeItem($context, $treeViewHandle, $treeViewItem, $currentPath, $functionToApply, 1, $maxDepth)
			$treeViewItem = _GUICtrlTreeView_GetNextSibling($treeViewHandle, $treeViewItem)
		WEnd
		Return
	EndIf
	IterateOverTreeItem($context, $treeViewHandle, $treeViewItem, $currentPath, $functionToApply, 1, $maxDepth)
EndFunc


;~ Iterate over a treeview item and make an operation on every node - cannot be called on root node (Null)
Func IterateOverTreeItem(ByRef $context, $treeViewHandle, $treeViewItem, $currentPath, $functionToApply, $currentDepth, $maxDepth)
	If $maxDepth <> -1 And $currentDepth > $maxDepth Then Return
	Local $treeViewItemName = _GUICtrlTreeView_GetText($treeViewHandle, $treeViewItem)
	Local $newPath = ($currentPath == '') ? $treeViewItemName : $currentPath & '.' & $treeViewItemName
	If $functionToApply <> Null Then $functionToApply($context, $treeViewHandle, $treeViewItem, $newPath)

	Local $child = _GUICtrlTreeView_GetFirstChild($treeViewHandle, $treeViewItem)
	While $child <> 0
		IterateOverTreeItem($context, $treeViewHandle, $child, $newPath, $functionToApply, $currentDepth + 1, $maxDepth)
		$child = _GUICtrlTreeView_GetNextSibling($treeViewHandle, $child)
	WEnd
EndFunc
#EndRegion Loot Tree View Management


Func RenameGUI($gui_title)
	WinSetTitle($gui_botshub, '', $gui_title)
EndFunc


Func EnableStartButton()
	GUICtrlSetData($gui_startbutton, 'Start')
	GUICtrlSetState($gui_startbutton, $GUI_ENABLE)
	ThemeSetButton($gui_startbutton, $THEME_BTN_PRIMARY)
	FollowerStartButtonSync()
EndFunc


#Region Dead GUI code but keep because it could come handy
;~ Create and destroy a temporary GUI hosting a list of things to pick from
; Stub: OpenPickWindow is unused; empty list keeps Au3Check quiet
Global Const $ARRAY_STUFF = []

Func OpenPickWindow()
	Local $windowWidth = 200
	Local $windowHeight = 500
	Local $mainPos = WinGetPos($gui_botshub)
	Local $windowXPos = $mainPos[0] + $mainPos[2] - $windowWidth - 75
	Local $windowYPos = $mainPos[1] + 25

	; need to be global
	$temporary_gui = GUICreate('List of stuff', $windowWidth, $windowHeight, $windowXPos, $windowYPos, BitOR($WS_POPUP, $WS_BORDER), $WS_EX_TOOLWINDOW)
	Local $list = GUICtrlCreateList('', 8, 8, $windowWidth - 16, $windowHeight - 16, BitOR($LBS_EXTENDEDSEL, $WS_VSCROLL, $LBS_NOINTEGRALHEIGHT))

	; Fill list
	Local $alreadyPickedStuff = $map['pickedStuff']
	If $alreadyPickedStuff == Null Then
		Local $alreadyPickedStuff[]
		$map['pickedStuff'] = $alreadyPickedStuff
	EndIf
	For $i = 0 To UBound($ARRAY_STUFF) - 1
		GUICtrlSetData($list, $ARRAY_STUFF[$i])
		If $alreadyPickedStuff[$ARRAY_STUFF[$i]] <> Null Then _GUICtrlListBox_SetSel($list, $i, 1)
	Next

	; need to be global
	$temporary_gui_opened = True
	GUIRegisterMsg($GUI_WM_ACTIVATE, 'TemporaryGUIWMActivateHandler')
	GUISetState(@SW_SHOW, $temporary_gui)

	While $temporary_gui_opened
		Switch GUIGetMsg()
			Case $GUI_EVENT_CLOSE
				$temporary_gui_opened = False
		EndSwitch
		; GUIGetMsg returns immediately in OnEvent mode: avoid a 100% CPU spin
		Sleep(20)
	WEnd

	; harvest while GUI still exists
	Local $selectedStuff[]
	Local $selectedIndices = _GUICtrlListBox_GetSelItems($list)
	For $i = 1 To $selectedIndices[0]
		$selectedStuff[_GUICtrlListBox_GetText($list, $selectedIndices[$i])] = 1
	Next
	$map['pickedStuff'] = $selectedStuff
	GUIDelete($temporary_gui)
EndFunc


;~ Handler to catch clicks outside of temporary GUI
Func TemporaryGUIWMActivateHandler($handle, $message, $param)
	If $handle = $temporary_gui Then
		If BitAND($param, 0xFFFF) = $GUI_WA_INACTIVE Then
			$temporary_gui_opened = False
		EndIf
	EndIf
	Return $GUI_RUNDEFMSG
EndFunc


;~ Getting ticked loot options from checkboxes as array
Func GetLootOptionsTickedCheckboxes($startingPoint, $treeViewHandle = $gui_treeview_lootoptions, $pathDelimiter = '.', $recursive = True)
	Local $treeViewItem = FindNodeInTreeView($treeViewHandle, Null, $startingPoint, $pathDelimiter)
	Return $treeViewItem == Null ? Null : BuildArrayFromTreeView($treeViewHandle, $treeViewItem, '', $recursive)
EndFunc


;~ Find a node in a treeview by its path as string
Func FindNodeInTreeView($treeViewHandle, $treeViewItem = Null, $path = '', $pathDelimiter = '.')
	Local $pathArray = StringSplit($path, $pathDelimiter)
	; Caution in AutoIT, StringSplit function returns array in which first element is count of items
	Local $pathArraySize = $pathArray[0]
	If $pathArraySize == 0 Or $path == '' Then Return Null
	; v38.3: lazy Inventory tree - create every node before searching the control
	If LootTreeIsModelTree($treeViewHandle) Then LootTreeRealizeAll($treeViewHandle)
	If $treeViewItem == Null Then $treeViewItem = _GUICtrlTreeView_GetFirstItem($treeViewHandle)
	Return FindNodeInTreeViewHelper($treeViewHandle, $treeViewItem, $pathArray, 1)
EndFunc


;~ Find a node in a treeview by its path as string
Func FindNodeInTreeViewHelper($treeViewHandle, $treeViewItem, $pathArray, $pathArrayIndex)
	Local $treeViewItemName, $treeViewItemChildCount, $treeViewItemFirstChild
	While $treeViewItem <> 0
		$treeViewItemName = _GUICtrlTreeView_GetText($treeViewHandle, $treeViewItem)
		$treeViewItemChildCount = _GUICtrlTreeView_GetChildCount($treeViewHandle, $treeViewItem)
		If $treeViewItemName == $pathArray[$pathArrayIndex] Then
			If $pathArrayIndex == UBound($pathArray) - 1 Then
				Return $treeViewItem
			Else
				Return FindNodeInTreeViewHelper($treeViewHandle, _GUICtrlTreeView_GetFirstChild($treeViewHandle, $treeViewItem), $pathArray, $pathArrayIndex + 1)
			EndIf
		EndIf
		$treeViewItem = _GUICtrlTreeView_GetNextSibling($treeViewHandle, $treeViewItem)
	WEnd
	Return Null
EndFunc


;~ Find the child from the given treeview by its name
Func FindDirectChildTreeViewItem($treeViewHandle, $treeViewItem, $name)
	If $treeViewItem == Null Then
		$treeViewItem = _GUICtrlTreeView_GetFirstItem($treeViewHandle)
	EndIf
	Return FindDirectChildTreeViewItemHelper($treeViewHandle, $treeViewItem, $name)
EndFunc


;~ Find a node in a treeview by its path as string
Func FindDirectChildTreeViewItemHelper($treeViewHandle, $treeViewItem, $name)
	Local $treeViewItemName
	While $treeViewItem <> 0
		$treeViewItemName = _GUICtrlTreeView_GetText($treeViewHandle, $treeViewItem)
		If $treeViewItemName == $name Then
			Return $treeViewItem
		EndIf
		$treeViewItem = _GUICtrlTreeView_GetNextSibling($treeViewHandle, $treeViewItem)
	WEnd
	Return Null
EndFunc


;~ Creating a treeview from a JSON node
Func BuildTreeViewFromJSON($parentItem, $jsonNode)
	If IsMap($jsonNode) Then
		Local $isChecked = True
		For $key In MapKeys($jsonNode)
			Local $keyHandle = GUICtrlCreateTreeViewItem($key, $parentItem)
			If Not BuildTreeViewFromJSON($keyHandle, $jsonNode[$key]) Then $isChecked = False
		Next
		_GUICtrlTreeView_SetChecked($gui_treeview_lootoptions, $parentItem, $isChecked)
		Return $isChecked
	EndIf
	; Leaf node: this node is true or false
	_GUICtrlTreeView_SetChecked($gui_treeview_lootoptions, $parentItem, $jsonNode)
	Return $jsonNode == True
EndFunc


;~ Function to recursively traverse a branch in a tree view to check if any child in that branch is checked
Func IsAnyChildInBranchChecked($treeViewHandle, $treeViewItem)
	; Check if current tree node item is checked
	If _GUICtrlTreeView_GetChecked($treeViewHandle, $treeViewItem) Then Return True

	; Recursively check all child items of provided $treeViewItem
	If _GUICtrlTreeView_GetChildren($treeViewHandle, $treeViewItem) Then
		Local $childHandle = _GUICtrlTreeView_GetFirstChild($treeViewHandle, $treeViewItem)
		While $childHandle <> 0
			If IsAnyChildInBranchChecked($treeViewHandle, $childHandle) Then Return True
			$childHandle = _GUICtrlTreeView_GetNextChild($treeViewHandle, $childHandle)
		WEnd
	EndIf

	Return False
EndFunc


;~ Function to check if any checkbox is checked in a branch starting in node provided as path string
Func IsAnyLootOptionInBranchChecked($startNodePath, $treeViewHandle = $gui_treeview_lootoptions, $pathDelimiter = '.')
	Local $treeViewItem = FindNodeInTreeView($treeViewHandle, Null, $startNodePath, $pathDelimiter)
	Return $treeViewItem == Null ? False : IsAnyChildInBranchChecked($treeViewHandle, $treeViewItem)
EndFunc
#EndRegion Dead GUI code but keep because it could come handy
;~ Final confirmation of tools and follower linkage
Func ConfirmAllLinkages()
	Notice('Tools and Follower linkages confirmed active')
	Return True
EndFunc

; Handle Tools tab buttons
Func GuiToolsTabButtonHandler()
	Switch @GUI_CtrlId
		Case $gui_button_attach
			AttachForTools()
		Case $gui_button_resetstats
			ResetSessionStats()
		Case $gui_button_ectotogold
			If Not IsAttachedForTools() Then Return
			Info('Converting ectos to gold...')
			ConvertEctosToGold()
		Case $gui_button_goldtolockpicks
			If Not IsAttachedForTools() Then Return
			Info('Converting gold to lockpicks...')
			ConvertGoldToLockpicks()
		Case $gui_button_extractupgrades
			If Not IsAttachedForTools() Then Return
			Info('Manually extracting selected components...')
			ExtractUpgradesOnly()
		Case $gui_button_toolsopenstorage
			OpenStorageForTools()
		Case $gui_button_emptytab
			EmptyStorageTabForTools(GUICtrlRead($gui_combo_emptytab))
		Case $gui_button_storagesetup
			StorageSetupShow()
		Case $gui_button_sortnow_tools
			StorageSortNow('Sort now')
		Case Else
			MsgBox(0, 'Error', 'This button is not coded yet.')
	EndSwitch
EndFunc

;~ v33: Titles tab buttons (Eat all sweets / Drink all alcohol / Use all party items) - refused during a farm run
;~ (IsAttachedForTools), inventory only, see TitlesConsumeRun in lib/Utils-TitlesTab.au3
Func GuiTitlesButtonHandler()
	Local $titleKey = TitlesButtonKey(@GUI_CtrlId)
	If $titleKey == '' Then Return
	If Not IsAttachedForTools() Then Return
	TitlesConsumeRun($titleKey)
	ItemsPanelRefresh(True)
EndFunc

;~ Tools > 'Reset session stats' (v15): resets the statistics, not just their labels. Exactly what is reset:
;~ - GUI 'Informations' counters (UpdateStats/UpdateItemStats statics, via $stats_reset_generation):
;~   runs, successes, failures, success ratio, total time, time per run, chests, experience, gold, gold items,
;~   ectos, obsidian shards. v23: the Items panel item rows are inventory + storage totals, so they are not reset.
;~   v33: title points moved to the Titles tab (own Session baseline, not reset).
;~   Their baselines (experience, gold, item counts) are re-read at the next stats update, i.e. the next run start.
;~ - Session counters behind the run log line, the session summary and the watchdog (SessionResetStats): see Utils-Session.au3.
;~ - Q8 counter.
;~ NOT reset: log file and its warning/error counters, the runs-YYYY-MM-DD.csv file (new lines simply continue), configs,
;~ attach state, farm setup flags, per-run timer/deadline and chest map (only used inside a run).
;~ Refused while a farm is running (same convention as the other Tools).
Func ResetSessionStats()
	If $runtime_status == 'RUNNING' Or $runtime_status == 'WILL_PAUSE' Then
		MsgBox(0, 'Tools', 'Pause the farm (and wait for it to stop) before using Tools.')
		Return False
	EndIf
	Notice('Before reset - ' & SessionSummary())
	SessionResetStats()
	$stats_reset_generation += 1
	$sessionQ8Count = 0
	If $gui_label_q8count <> '' Then GUICtrlSetData($gui_label_q8count, 'Q8s: 0')
	ResetStatsLabels()
	Info('Session stats reset (runs, successes, failures, timings, chests, experience, gold/items, failure streak)')
	Return True
EndFunc


;~ Shows the 'just reset' value on every statistics label (what UpdateStats/UpdateItemStats show with zero counters)
Func ResetStatsLabels()
	Local $zeroLabels[] = [$gui_label_runs_value, $gui_label_successes_value, $gui_label_failures_value, $gui_label_chests_value, _
		$gui_label_experience_value, $gui_label_golditems_value, $gui_label_ectos_value, $gui_label_obsidianshards_value]
	For $label In $zeroLabels
		GUICtrlSetData($label, 0)
	Next
	; Items panel rows are inventory + storage totals and the Titles tab has its own baseline (v33) - neither is reset
	GUICtrlSetData($gui_label_successratio_value, 0 & ' %')
	GUICtrlSetData($gui_label_time_value, ConvertTimeToHourString(0))
	GUICtrlSetData($gui_label_timeperrun_value, ConvertTimeToMinutesString(0))
	GUICtrlSetData($gui_label_gold_value, '0k0g')
EndFunc

Func WriteRunSummary($result, $elapsed)
	Local $status = ($result == $SUCCESS) ? 'Success' : 'Failed'
	Info('Run summary: ' & $status & ' | Time: ' & ConvertTimeToMinutesString($elapsed))
EndFunc
