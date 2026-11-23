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

; TODO :
; - after salvage, get material ID and write in file salvaged material
; - add true locking mechanism to prevent trying to run several bots on the same account at the same time

; Night tips and tricks
; - Always refresh agents before getting data from them (agent = snapshot)
;		(so only use $me if you are sure nothing important changes between $me definition and $me usage)
; - AdlibRegister('NotifyHangingBot', 120000) can be used to simulate multithreading
#CE ===========================================================================

#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Icon=assets\icon\BotsHub.ico
#RequireAdmin
#NoTrayIcon

Opt('MustDeclareVars', True)
;Opt('ExpandEnvStrings', 1)

#Region Includes
#include-once
#include <Math.au3>

; v38.9-bridgeA: GWBridge test build (reads only, opt-in; see bridge/TESTING.md)
#include 'bridge/au3/GWBridge_BotsHub.au3'
#include 'lib/BotsHub-GUI.au3'
#include 'lib/GWA2.au3'
#include 'lib/GWA2_Assembly.au3'
#include 'lib/GWA2_Assembly_Chatlog.au3'
#include 'lib/GWA2_ID.au3'
#include 'lib/GWA2_ID_Maps.au3'
#include 'lib/GWA2_ID_Skills.au3'
#include 'lib/JSON.au3'
#include 'lib/BotsHub-Constants.au3'
#include 'lib/Utils.au3'
#include 'src/LoadWaitHelpers.au3'
#include 'lib/Utils-Session.au3'
#include 'lib/Utils-Console.au3'
#include 'lib/Utils-Debugger.au3'
#include 'lib/Utils-Items_Modstructs.au3'
#include 'lib/Utils-Shared_Memory.au3'
#include 'lib/Utils-Storage.au3'
#include 'lib/Utils-StorageSort.au3'
#include 'lib/Utils-StorageSetup-GUI.au3'
#include 'lib/Utils-ItemsPanel.au3'
#include 'lib/Utils-StuckWatchdog.au3'
#include 'lib/Build_PW_Heroic-Refrain.au3'

#include 'src/farms/CoF.au3'
#include 'src/farms/Corsairs.au3'
#include 'src/farms/DragonMoss.au3'
#include 'src/farms/DrakeFlesh.au3'
#include 'src/farms/EdenIris.au3'
#include 'src/farms/Feathers.au3'
#include 'src/farms/FoWTowerOfCourage.au3'
#include 'src/farms/Gemstones.au3'
#include 'src/farms/GemstoneMargonite.au3'
#include 'src/farms/GemstoneStygian.au3'
#include 'src/farms/GemstoneTorment.au3'
#include 'src/farms/JadeBrotherhood.au3'
#include 'src/farms/Lightbringer-Sunspear.au3'
#include 'src/farms/Lightbringer.au3'
#include 'src/farms/Mantids.au3'
#include 'src/farms/Kournans.au3'
#include 'src/farms/Minotaurs.au3'
#include 'src/farms/Raptors.au3'
#include 'src/farms/SkaleFins.au3'
#include 'src/farms/Skrees.au3'
#include 'src/farms/SpiritSlaves.au3'
#include 'src/farms/Vaettirs.au3'
#include 'src/farms/Zodiac.au3'
#include 'src/missions/Deldrimor.au3'
#include 'src/missions/FoW.au3'
#include 'src/missions/Froggy.au3'
#include 'src/missions/GlintChallenge.au3'
#include 'src/missions/Kilroy.au3'
#include 'src/missions/MinisterialCommendations.au3'
#include 'src/missions/NexusChallenge.au3'
#include 'src/missions/SoO.au3'
#include 'src/missions/SunspearArmor.au3'
#include 'src/missions/TunnelsOfTheForsaken.au3'
#include 'src/missions/Underworld.au3'
#include 'src/missions/Voltaic.au3'
#include 'src/missions/WarSupplyKeiran.au3'
#include 'src/runs/Boreal.au3'
#include 'src/runs/Pongmei.au3'
#include 'src/runs/MagmasRun.au3'
#include 'src/runs/Tasca.au3'
#include 'src/titles/LDOA.au3'
#include 'src/utilities/Follower.au3'
#include 'src/utilities/EctoToGold.au3'
#include 'src/utilities/BonderFollower.au3'
#include 'src/utilities/OmniFarmer.au3'
#include 'src/utilities/TestSuite.au3'
#include 'src/vanquishes/Asuran.au3'
#include 'src/vanquishes/KurzickFerndale.au3'
#include 'src/vanquishes/KurzickDrazach.au3'
#include 'src/vanquishes/LuxonMountQinkai.au3'
#include 'src/vanquishes/LuxonSilentSurf.au3'
#include 'src/vanquishes/Norn.au3'
#include 'src/vanquishes/Vanguard.au3'
#EndRegion Includes

#Region Variables
Global Const $GW_BOT_HUB_VERSION = '2.0 v38.12-bridge'

; -1 = did not start, 0 = ran fine, 1 = failed, 2 = pause
Global Const $NOT_STARTED = -1
Global Const $SUCCESS = 0
Global Const $FAIL = 1
Global Const $PAUSE = 2

Global Const $AVAILABLE_DISTRICTS = '|Random|Random EU|Random US|Random Asia|America|China|English|French|German|International|Italian|Japan|Korea|Polish|Russian|Spanish'

Global Const $AVAILABLE_HEROES = '||Acolyte Jin|Acolyte Sousuke|Anton|Devona|Dunkoro|General Morgahn|Ghost of Althea|Goren|Gwen|Hayda|Jora|Kahmu|Keiran Thackeray|Koss|Livia|' & _
	'Margrid the Sly|Master of Whispers|Melonni|Miku|MOX|Norgu|Ogden|Olias|Pyre Fierceshot|Razah|Tahlkora|Vekk|Xandra|ZeiRi|Zenmai|Zhed Shadowhoof|' & _
	'Mercenary Hero 1|Mercenary Hero 2|Mercenary Hero 3|Mercenary Hero 4|Mercenary Hero 5|Mercenary Hero 6|Mercenary Hero 7|Mercenary Hero 8||'

; UNINITIALIZED -> INITIALIZED -> RUNNING -> WILL_PAUSE -> PAUSED -> RUNNING
Global $runtime_status = 'UNINITIALIZED'
Global $run_mode = 'GUI'
Global $slave_index = 0
Global $process_id = ''
Global $attached_for_tools = False
Global $character_name = ''
Global $farm_name = ''
Global $run_configuration = 'Default Farm Configuration'
Global $loot_configuration = 'Default Loot Configuration'
; If set to 0, disables inventory management
Global $inventory_space_needed = 5
Global $run_timer = Null
Global $global_farm_setup = False

Global $slave_heartbeat = 0

; Farm Name;Farm function;Inventory space;Farm duration
Global $farm_map[]
Global $gui_enabled

Global $inventory_management_cache[]
Global $run_options_cache[]
$run_options_cache['run.district'] = 'Random EU'
$run_options_cache['run.loop_mode'] = True
$run_options_cache['run.hard_mode'] = False
$run_options_cache['run.consume_consumables'] = True
$run_options_cache['run.use_consets'] = False
$run_options_cache['run.use_scrolls'] = False
$run_options_cache['run.sort_items'] = False
$run_options_cache['run.salvage_into_materials'] = False
$run_options_cache['run.farm_materials_mid_run'] = False
$run_options_cache['run.bags_count'] = 5
$run_options_cache['run.weapon_slot'] = '1'
$run_options_cache['run.donate_faction_points'] = True
$run_options_cache['run.buy_faction_scrolls'] = False
$run_options_cache['run.buy_faction_resources'] = False
$run_options_cache['run.collect_data'] = False
$run_options_cache['run.go_offline'] = False
$run_options_cache['run.flash_whisper'] = False
$run_options_cache['team.automatic_team_setup'] = False
; Team tab defaults (same values as the Team tab controls are created with)
$run_options_cache['team.hero_1'] = 'Master of Whispers'
$run_options_cache['team.hero_2'] = 'Livia'
$run_options_cache['team.hero_3'] = 'Gwen'
$run_options_cache['team.hero_4'] = 'Olias'
$run_options_cache['team.hero_5'] = 'Norgu'
$run_options_cache['team.hero_6'] = 'Xandra'
$run_options_cache['team.hero_7'] = 'Razah'
$run_options_cache['team.load_all_builds'] = False
$run_options_cache['team.load_player_build'] = False
$run_options_cache['team.load_hero_1_build'] = False
$run_options_cache['team.load_hero_2_build'] = False
$run_options_cache['team.load_hero_3_build'] = False
$run_options_cache['team.load_hero_4_build'] = False
$run_options_cache['team.load_hero_5_build'] = False
$run_options_cache['team.load_hero_6_build'] = False
$run_options_cache['team.load_hero_7_build'] = False
$run_options_cache['team.player_build'] = ''
$run_options_cache['team.hero_1_build'] = ''
$run_options_cache['team.hero_2_build'] = ''
$run_options_cache['team.hero_3_build'] = ''
$run_options_cache['team.hero_4_build'] = ''
$run_options_cache['team.hero_5_build'] = ''
$run_options_cache['team.hero_6_build'] = ''
$run_options_cache['team.hero_7_build'] = ''
$run_options_cache['follower.perma_sf'] = False
$run_options_cache['follower.open_chests'] = True
$run_options_cache['follower.leader_target'] = True
$run_options_cache['follower.name'] = ''
$run_options_cache['follower.leash'] = 1500
$run_options_cache['follower.bonder_mode'] = 'None'
$run_options_cache['run.return_on_death'] = False
$run_options_cache['run.log_chests'] = False
$run_options_cache['run.auto_attach'] = False
$run_options_cache['run.extract_upgrades_only'] = False
$run_options_cache['run.skip_am_fah'] = False
$run_options_cache['run.debug_logging'] = False

; Simple options persisted 1:1 between $run_options_cache and the farm configuration JSON.
; Special cases (character, farm, loot config, weapon slot, bags, district, rendering) are handled explicitly.
; Adding an option = add its key here + a default above; load/save/validation pick it up automatically.
Global Const $PERSISTED_OPTION_KEYS[] = [ _
	'run.loop_mode', 'run.hard_mode', 'run.salvage_into_materials', 'run.consume_consumables', 'run.use_consets', _
	'run.use_scrolls', 'run.sort_items', 'run.collect_data', 'run.go_offline', 'run.flash_whisper', _
	'run.donate_faction_points', 'run.buy_faction_resources', 'run.buy_faction_scrolls', _
	'run.return_on_death', 'run.log_chests', 'run.extract_upgrades_only', 'run.skip_am_fah', 'run.debug_logging', _
	'follower.name', 'follower.leash', 'follower.perma_sf', 'follower.open_chests', 'follower.leader_target', 'follower.bonder_mode', _
	'team.automatic_team_setup', _
	'team.hero_1', 'team.hero_2', 'team.hero_3', 'team.hero_4', 'team.hero_5', 'team.hero_6', 'team.hero_7', _
	'team.load_all_builds', 'team.load_player_build', _
	'team.load_hero_1_build', 'team.load_hero_2_build', 'team.load_hero_3_build', 'team.load_hero_4_build', _
	'team.load_hero_5_build', 'team.load_hero_6_build', 'team.load_hero_7_build', _
	'team.player_build', _
	'team.hero_1_build', 'team.hero_2_build', 'team.hero_3_build', 'team.hero_4_build', _
	'team.hero_5_build', 'team.hero_6_build', 'team.hero_7_build']

; Overrides on $run_options_cache for frequent usage
Global $district_name = 'Random EU'
Global $bags_count = 5
#EndRegion Variables


#Region Main loops
BotsHubMain()

;------------------------------------------------------
; Title...........:	Main
; Description.....:	run the main program
;------------------------------------------------------
Func BotsHubMain()
	; Verify validity
	If @AutoItVersion < '3.3.16.1' Then
		MsgBox(16, 'Error', 'This bot requires AutoIt version 3.3.16.1 or higher. You are using ' & @AutoItVersion & '.')
		Exit 1
	EndIf
	If @AutoItX64 Then
		MsgBox(16, 'Error!', 'Please run all bots in 32-bit (x86) mode.')
		Exit 1
	EndIf

	If $cmdLine[0] <> 0 Then $run_mode = 'HEADLESS'

	; GUI free steps
	SessionStart()
	LogStartupDiagnostics($GW_BOT_HUB_VERSION, $run_mode)
	Info('GWBridge test build ' & $GWB_BOTSHUB_BUILD & ': the bridge starts when the bot attaches to a game client (reads only, commands stay classic GWA2)')
	FillFarmMap()
	LoadDefaultRunConfiguration()
	LoadDefaultLootConfiguration()

	If $run_mode == 'GUI' Then
		$gui_enabled = True
		CreateBotsHubGUI()
		RenameGUI('GW Bot Hub [' & $GWB_BOTSHUB_BUILD & ']')
		ApplyConfigToGUI()
		FillConfigurationCombo()
		GUISetState(@SW_SHOWNORMAL)
		Info('GW Bot Hub ' & $GW_BOT_HUB_VERSION)
		; Authentication
		ScanAndUpdateGameClients()
		RefreshCharactersComboBox()
	ElseIf $run_mode == 'HEADLESS' Then
		$gui_enabled = False
		; Need minimum 4 things to run a bot: slave index, process ID, character name and farm name
		If $cmdLine[0] < 4 Then
			; Headless errors: shown for 30s at most so a slave started by a master never hangs on a dialog
			Error('The Hub needs 0 or at least 4 arguments.')
			MsgBox(0, 'Error', 'The Hub needs 0 or at least 4 arguments.', 30)
			Exit 1
		EndIf
		$slave_index = $cmdLine[1]
		$process_id = $cmdLine[2]
		$character_name = $cmdLine[3]
		$farm_name = $cmdLine[4]

		Info('Running in CMD mode with process ID: ' & $process_id & ' character name: ' & $character_name & ' farm name: ' & $farm_name)
		If Not IsKnownFarm($farm_name) Then
			Error('Farm "' & $farm_name & '" does not exist, pick one from the list')
			MsgBox(16, 'Error', 'Farm "' & $farm_name & '" does not exist, pick one from the list', 30)
			Exit 1
		EndIf

		If $character_name <> '' Then
			Local $openProcess = SafeDllCall9($kernel_handle, 'int', 'OpenProcess', 'int', 0x1F0FFF, 'int', 1, 'int', $process_id)
			Local $processHandle = IsArray($openProcess) ? $openProcess[0] : 0
			If $processHandle <> 0 Then
				Local $windowHandle = GetWindowHandleForProcess($process_id)
				AddClient($process_id, $processHandle, $windowHandle, $character_name)
				SelectClient(1)
			Else
				Error('GW process ' & $process_id & ' could not be opened (wrong PID or not running as administrator)')
				MsgBox(0, 'Error', 'GW Process with incorrect handle.', 30)
				Exit 1
			EndIf
		EndIf
		; Authentication - a failed attach used to be ignored and the farm then ran against an unattached client
		If Authentification($character_name) <> $SUCCESS Then
			Error('Could not attach to Guild Wars for character "' & $character_name & '" - exiting')
			Exit 1
		EndIf
		$runtime_status = 'RUNNING'


		If $slave_index >= 0 Then
			If OpenMasterSlaveSharedMemory($slave_index) Then
				AdlibRegister('UpdateHeartbeat', 5000)
			Else
				Error('Unable to open shared memory blocks.')
			EndIf
		EndIf
	Else
		MsgBox(0, 'Error', 'Unknown run mode: ' & $run_mode)
		Exit
	EndIf

	; Infinite loop
	BotHubLoop()
EndFunc



;~ True when $name is a real key in $farm_map (excludes placeholder / typos / free-typed combo text)
Func IsKnownFarm($name)
	If $name == Null Or $name == '' Then Return False
	If $name == 'Choose a farm' Then Return False
	Return MapExists($farm_map, $name)
EndFunc


;~ Main loop of the program
Func BotHubLoop()
	While True
		If ($runtime_status == 'RUNNING') Then
			If Not IsKnownFarm($farm_name) Then
				Local $displayName = ($farm_name == Null Or $farm_name == '') ? '(blank)' : $farm_name
				Error('Farm "' & $displayName & '" does not exist, pick one from the list')
				$runtime_status = 'INITIALIZED'
				If $run_mode == 'GUI' Then
					EnableStartButton()
					EnableGUIComboboxes()
				Else
					; Headless cannot recover from a bad farm name
					Exit 1
				EndIf
				ContinueLoop
			EndIf
			If $run_mode == 'GUI' Then
				DisableGUIComboboxes()
			EndIf
			Local $result = RunFarmLoop()
			If ($result == $PAUSE Or $run_options_cache['run.loop_mode'] == False) Then $runtime_status = 'WILL_PAUSE'
		EndIf

		If ($runtime_status == 'WILL_PAUSE') Then
			Warn('Paused.')
			$runtime_status = 'PAUSED'
			If $run_mode == 'GUI' Then
				EnableStartButton()
				EnableGUIComboboxes()
			EndIf
		EndIf
		; v23: Items panel totals while idle/paused (rate-limited; never during a run)
		If $run_mode == 'GUI' And $runtime_status <> 'RUNNING' Then ItemsPanelRefresh()
		; Small random gap between consecutive runs (was a fixed 1s) so run starts are not perfectly periodic
		Sleep($runtime_status == 'RUNNING' ? Random(1000, 3000, 1) : 1000)
	WEnd
EndFunc


;~ Main loop to run farms
Func RunFarmLoop()
	; Farm Name;Farm function;Inventory space;Farm duration
	; v38.2: extract-leaf cache is no longer cleared on every run. It is cleared on Load,
	; Apply, a tree tick change, and the Start button (see GuiStartButtonHandler).
	If Not IsKnownFarm($farm_name) Then
		Error('Farm "' & $farm_name & '" does not exist, pick one from the list')
		Return $PAUSE
	EndIf
	Local $farm = $farm_map[$farm_name]
	If Not IsArray($farm) Then
		Error('Farm "' & $farm_name & '" does not exist, pick one from the list')
		Return $PAUSE
	EndIf
	Local $inventorySpaceNeeded = $farm[2]

	; No authentication: skip global farm setup and inventory management
	If $character_name <> '' Then
		; Reconnect if the client was disconnected (pause if that fails)
		If Not EnsureGameConnected() Then
			Error('Game client is disconnected, pausing.')
			Return $PAUSE
		EndIf
		; v30: the stuck watchdog (2 min) also watches the town phases below (mid-run kits, inventory town pass, global setup)
		StuckWatchdogStart($farm_name)
		; Must do mid-run inventory management before normal one else we will go back to town
		If $inventorySpaceNeeded <> 0 And $run_options_cache['run.farm_materials_mid_run'] Then
			Local $resetRequired = InventoryManagementMidRun()
			If $resetRequired Then ResetBotsSetups()
		EndIf

		; During pickup, items will be moved to equipment bag (if used) when first 3 bags are full
		; So bag 5 will always fill before 4 - hence we can count items up to bag 4
		If (CountSlots(1, _Min($bags_count, 4)) < $inventorySpaceNeeded) Then
			InventoryManagementBeforeRun()
		EndIf
		; Inventory management did not clean up inventory - we pause
		If (CountSlots(1, $bags_count) < $inventorySpaceNeeded) Then
			StuckWatchdogStop()
			; v30: a town pass cut short by a stuck trip is a failed run that retries, not a full inventory
			If $stuck_watchdog_tripped Then Return StuckWatchdogAfterRun($PAUSE)
			Notice('Inventory full, pausing.')
			ResetBotsSetups()
			Return $PAUSE
		EndIf

		; Global farm setup
		If Not $global_farm_setup Then GeneralFarmSetup()
	EndIf

	; Running chosen farm
	Local $result = $NOT_STARTED
	$run_timer = TimerInit()
	$run_deadline = _Max(Number($farm[3]) * $RUN_DEADLINE_FACTOR, $RUN_DEADLINE_MIN)
	Local $farmFunction = $farm[1]
	SessionRunStarted($farm_name)
	; v24/v30: stuck watchdog (2 min without progress -> map back, run failed, setup from scratch), started above with the
	; town phases; the farm is skipped when it already tripped there
	If $stuck_watchdog_tripped Then
		Warn('[Stuck] Tripped before the farm started - skipping this run')
		$result = $FAIL
	ElseIf $run_mode == 'HEADLESS' Then
		$result = $farmFunction()
	ElseIf $run_mode == 'GUI' Then
		Local $timePerRun = UpdateStats($NOT_STARTED)
		UpdateProgressBar($timePerRun == 0 ? $farm[3] : $timePerRun)
		AdlibRegister('UpdateProgressBar', 5000)
		$result = $farmFunction()
		AdlibUnRegister('UpdateProgressBar')
		CompleteGUIFarmProgress()
	EndIf
	StuckWatchdogStop()
	$result = StuckWatchdogAfterRun($result)
	Local $elapsedTime = TimerDiff($run_timer)
	If $result == $PAUSE Then
		Info('Run paused after: ' & ConvertTimeToMinutesString($elapsedTime))
	Else
		Info('Run ' & ($result == $SUCCESS ? 'successful' : 'failed') & ' after: ' & ConvertTimeToMinutesString($elapsedTime))
	EndIf
	If $run_mode == 'GUI' Then UpdateStats($result, $elapsedTime)
	SessionRunFinished($farm_name, $result, $elapsedTime)
	; v24: no more 'pause after 10 failed runs in a row' (AMG) - failed runs keep looping; the stuck watchdog handles stuck runs
	If $character_name <> '' Then ClearMemory(GetProcessHandle())
	Return $result
EndFunc
#EndRegion Main loops


#Region Load/Save configuration
;~ Load default farm configuration if it exists
Func LoadDefaultRunConfiguration()
	Local $filePath = @ScriptDir & '/conf/farm/' & $run_configuration & '.json'
	If FileExists($filePath) Then
		LoadRunConfiguration($filePath)
	Else
		Error('No default run configuration at ' & $filePath)
	EndIf
EndFunc


;~ Change to a different configuration. Returns True on success.
;~ A missing/unreadable/invalid file is reported and leaves the current settings untouched.
Func LoadRunConfiguration($filePath)
	Local $configFile = FileOpen($filePath, $FO_READ + $FO_UTF8)
	If $configFile == -1 Then
		Error('Could not open run configuration ' & $filePath)
		Return False
	EndIf
	Local $jsonString = FileRead($configFile)
	FileClose($configFile)
	If Not ReadConfigFromJson($jsonString) Then
		Error('Run configuration ' & $filePath & ' is not valid JSON - settings left unchanged')
		Return False
	EndIf
	Info('Loaded run configuration at ' & $filePath)
	ValidateRunConfiguration()
	Return True
EndFunc


;~ Save a new configuration
Func SaveRunConfiguration($filePath)
	; FileSaveDialog does not force the extension; files without .json were invisible to the config combo
	If StringLower(StringRight($filePath, 5)) <> '.json' Then $filePath &= '.json'
	Local $configFile = FileOpen($filePath, $FO_OVERWRITE + $FO_CREATEPATH + $FO_UTF8)
	If $configFile == -1 Then
		Error('Could not write run configuration ' & $filePath)
		Return ''
	EndIf
	Local $jsonString = WriteConfigToJson()
	FileWrite($configFile, $jsonString)
	FileClose($configFile)
	Local $configurationName = StringTrimRight(StringMid($filePath, StringInStr($filePath, '\', 0, -1) + 1), 5)
	Info('Saved run configuration at ' & $filePath)
	Return $configurationName
EndFunc


;~ Load default loot configuration if it exists
Func LoadDefaultLootConfiguration()
	Local $filePath = @ScriptDir & '/conf/loot/' & $loot_configuration & '.json'
	If FileExists($filePath) Then
		LoadLootConfiguration($filePath)
	Else
		Error('No default loot configuration at ' & $filePath)
	EndIf
EndFunc


;~ Load loot configuration file if it exists
Func LoadLootConfiguration($filePath)
	$loot_configuration = $filePath
	$loot_configuration = StringTrimLeft($loot_configuration, StringLen(@ScriptDir & '/conf/loot/'))
	; Removing .json
	$loot_configuration = StringTrimRight($loot_configuration, 5)
	Local $jsonLootOptions = LoadLootOptions($filePath)
	; v29: the 'Keep components' tree was removed (AMG) - silently dropped from older loot files (not shown, not saved back)
	If IsMap($jsonLootOptions) And MapExists($jsonLootOptions, 'Keep components') Then MapRemove($jsonLootOptions, 'Keep components')
	; v35: 'Extract upgrades only' -> 'Extract Components' (ticks preserved); must run before prune/store migration
	$jsonLootOptions = MigrateExtractTreeRoot($jsonLootOptions)
	; v36: add missing Minor/Major rune leaves (unticked) so older loot files show them; existing ticks kept
	$jsonLootOptions = EnsureRuneLeaves($jsonLootOptions)
	; v12/v13: drop non-perfect Extract Components options saved by older versions (one warning, other settings untouched)
	; v36: Minor/Major runes are allowed again and are no longer pruned
	$jsonLootOptions = PruneNonPerfectUpgradeOptions($jsonLootOptions)
	; v25: Store items > Components (Mods / Inscriptions / Insignias / Runes) always present; v24 Store items.Mods and v19
	; Store items.Runes.Major Vigor migrated into it
	$jsonLootOptions = MigrateStoreComponentOptions($jsonLootOptions)
	FillInventoryCacheFromJSON($jsonLootOptions, '')
	BuildInventoryDerivedFlags()
	InvalidateExtractLeavesCache()
	Info('Loaded loot configuration at ' & $filePath)
EndFunc


;~ Load loot configuration file if it exists
Func LoadLootOptions($filePath)
	If FileExists($filePath) Then
		Local $lootOptionsFile = FileOpen($filePath, $FO_READ + $FO_UTF8)
		Local $jsonString = FileRead($lootOptionsFile)
		FileClose($lootOptionsFile)
		Return _JSON_Parse($jsonString)
	EndIf
	Return Null
EndFunc


;~ Read a JSON value; returns $default (and leaves the current setting alone) when the key is absent.
;~ Older or hand-written configs that lack a key used to overwrite the default with an empty string
;~ (e.g. a missing 'run.loop_mode' silently turned loop mode off).
Func ConfigGet(ByRef $jsonObject, $key, $default)
	Local $value = _JSON_Get($jsonObject, $key)
	If @error Then Return $default
	Return $value
EndFunc


;~ Read given config from JSON. Returns False if the string is not a JSON object.
Func ReadConfigFromJson($jsonString)
	Local $jsonObject = _JSON_Parse($jsonString)
	If @error Or Not IsMap($jsonObject) Then Return False

	$character_name = ConfigGet($jsonObject, 'main.character', $character_name)
	$farm_name = ConfigGet($jsonObject, 'main.farm', $farm_name)
	Local $lootConfig = ConfigGet($jsonObject, 'main.loot_configuration', '')
	If $lootConfig <> Null And $lootConfig <> '' Then $loot_configuration = $lootConfig

	Local $weaponSlot = Int(ConfigGet($jsonObject, 'run.weapon_slot', $run_options_cache['run.weapon_slot']))
	$weaponSlot = _Max($weaponSlot, 0)
	$weaponSlot = _Min($weaponSlot, 4)
	$run_options_cache['run.weapon_slot'] = $weaponSlot

	$bags_count = Int(ConfigGet($jsonObject, 'run.bags_count', $bags_count))
	$bags_count = _Max($bags_count, 1)
	$bags_count = _Min($bags_count, 5)
	$run_options_cache['run.bags_count'] = $bags_count

	$district_name = ConfigGet($jsonObject, 'run.district', $district_name)
	$run_options_cache['run.district'] = $district_name

	Local $renderingDisabled = ConfigGet($jsonObject, 'run.disable_rendering', Not $rendering_enabled)
	$rendering_enabled = Not $renderingDisabled

	For $key In $PERSISTED_OPTION_KEYS
		Local $default = MapExists($run_options_cache, $key) ? $run_options_cache[$key] : ''
		$run_options_cache[$key] = ConfigGet($jsonObject, $key, $default)
	Next
	; v35: mid-run salvage is no longer a GUI option; accept leftover keys and ignore them
	$run_options_cache['run.farm_materials_mid_run'] = False
	ApplyLogLevelFromOptions()
	Return True
EndFunc


;~ Writes current config to a json string
Func WriteConfigToJson()
	Local $jsonObject
	_JSON_addChangeDelete($jsonObject, 'main.character', $character_name)
	_JSON_addChangeDelete($jsonObject, 'main.farm', $farm_name)
	_JSON_addChangeDelete($jsonObject, 'main.loot_configuration', $loot_configuration)
	_JSON_addChangeDelete($jsonObject, 'run.weapon_slot', $run_options_cache['run.weapon_slot'])
	_JSON_addChangeDelete($jsonObject, 'run.bags_count', $run_options_cache['run.bags_count'])
	_JSON_addChangeDelete($jsonObject, 'run.district', $run_options_cache['run.district'])
	_JSON_addChangeDelete($jsonObject, 'run.disable_rendering', Not $rendering_enabled)
	For $key In $PERSISTED_OPTION_KEYS
		If MapExists($run_options_cache, $key) Then _JSON_addChangeDelete($jsonObject, $key, $run_options_cache[$key])
	Next
	Return _JSON_Generate($jsonObject)
EndFunc


;~ Optional verbose logging, controlled by the 'run.debug_logging' configuration flag
Func ApplyLogLevelFromOptions()
	$log_level = $run_options_cache['run.debug_logging'] ? $LVL_DEBUG : $LVL_INFO
EndFunc


;~ Sanity-check the loaded settings and report problems up front instead of failing mid-run.
;~ Only warns (never changes behaviour), except for values that would crash: those are already clamped on load.
;~ Returns the number of problems found.
Func ValidateRunConfiguration()
	Local $problems = 0
	If $farm_name <> '' And $farm_name <> 'Choose a farm' And Not IsKnownFarm($farm_name) Then
		Warn('Config check: farm "' & $farm_name & '" does not exist')
		$problems += 1
	EndIf
	If Not StringInStr($AVAILABLE_DISTRICTS & '|', '|' & $district_name & '|') Then
		Warn('Config check: unknown district "' & $district_name & '" (Random EU will be used)')
		$problems += 1
	EndIf
	If Not FileExists(@ScriptDir & '/conf/loot/' & $loot_configuration & '.json') Then
		Warn('Config check: loot configuration "' & $loot_configuration & '" not found in conf/loot')
		$problems += 1
	EndIf
	If $run_options_cache['team.automatic_team_setup'] Then
		For $i = 1 To 7
			Local $hero = $run_options_cache['team.hero_' & $i]
			If $hero <> '' And Not MapExists($HERO_IDS_FROM_NAMES, $hero) Then
				Warn('Config check: hero ' & $i & ' "' & $hero & '" is not a known hero name')
				$problems += 1
			EndIf
			If $run_options_cache['team.load_hero_' & $i & '_build'] And $run_options_cache['team.hero_' & $i & '_build'] == '' Then
				Warn('Config check: hero ' & $i & ' build loading is enabled but the template is empty')
				$problems += 1
			EndIf
		Next
		If $run_options_cache['team.load_player_build'] And $run_options_cache['team.player_build'] == '' Then
			Warn('Config check: player build loading is enabled but the template is empty')
			$problems += 1
		EndIf
	EndIf
	Local $exclusiveFactionChoices = ($run_options_cache['run.donate_faction_points'] ? 1 : 0) + ($run_options_cache['run.buy_faction_resources'] ? 1 : 0) + ($run_options_cache['run.buy_faction_scrolls'] ? 1 : 0)
	If $exclusiveFactionChoices > 1 Then
		Warn('Config check: several faction point options are enabled, the first one (donate > resources > scrolls) wins')
		$problems += 1
	EndIf
	If $problems > 0 Then Notice('Config check: ' & $problems & ' problem(s) found')
	Return $problems
EndFunc
#EndRegion Load/Save configuration


#Region Setup
;~ Fill the map of farms with the farms and their details
Func FillFarmMap()
	;					Farm Name						Farm function					Inventory space		Farm duration
	AddFarmToFarmMap(	'Asuran',						AsuranTitleFarm,				5,					$ASURAN_FARM_DURATION)
	AddFarmToFarmMap(	'Boreal',						BorealChestFarm,				5,					$BOREAL_FARM_DURATION)
	AddFarmToFarmMap(	'CoF',							CoFFarm,						5,					$COF_FARM_DURATION)
	AddFarmToFarmMap(	'Corsairs',						CorsairsFarm,					5,					$CORSAIRS_FARM_DURATION)
	AddFarmToFarmMap(	'Deldrimor',					DeldrimorFarm,					10,					$DELDRIMOR_FARM_DURATION)
	AddFarmToFarmMap(	'Drake Flesh',					DrakeFleshFarm,					5,					$DRAKE_FLESH_FARM_DURATION)
	AddFarmToFarmMap(	'Dragon Moss',					DragonMossFarm,					5,					$DRAGONMOSS_FARM_DURATION)
	AddFarmToFarmMap(	'Eden Iris',					EdenIrisFarm,					2,					$IRIS_FARM_DURATION)
	AddFarmToFarmMap(	'Feathers',						FeathersFarm,					10,					$FEATHERS_FARM_DURATION)
	AddFarmToFarmMap(	'Follower',						FollowerFarm,					5,					30 * 60 * 1000)
	AddFarmToFarmMap(	'Monk Bonder',					MonkBonderFarm,				5,					30 * 60 * 1000)
	AddFarmToFarmMap(	'EleMonk UW Bonder',			EleMonkUWBonderFarm,				5,					30 * 60 * 1000)
	AddFarmToFarmMap(	'FoW',							FoWFarm,						15,					$FOW_FARM_DURATION)
	AddFarmToFarmMap(	'FoW Tower of Courage',			FoWToCFarm,						10,					$FOW_TOC_FARM_DURATION)
	AddFarmToFarmMap(	'Froggy',						FroggyFarm,						10,					$FROGGY_FARM_DURATION)
	AddFarmToFarmMap(	'Gemstones',					GemstonesFarm,					10,					$GEMSTONES_FARM_DURATION)
	AddFarmToFarmMap(	'Gemstone Margonite',			GemstoneMargoniteFarm,			10,					$GEMSTONE_MARGONITE_FARM_DURATION)
	AddFarmToFarmMap(	'Gemstone Stygian',				GemstoneStygianFarm,			10,					$GEMSTONE_STYGIAN_FARM_DURATION)
	AddFarmToFarmMap(	'Gemstone Torment',				GemstoneTormentFarm,			10,					$GEMSTONE_TORMENT_FARM_DURATION)
	AddFarmToFarmMap(	'Glint Challenge',				GlintChallengeFarm,				5,					$GLINT_CHALLENGE_DURATION)
	AddFarmToFarmMap(	'Jade Brotherhood',				JadeBrotherhoodFarm,			5,					$JADEBROTHERHOOD_FARM_DURATION)
	AddFarmToFarmMap(	'Kilroy',						KilroyFarm,						10,					$KILROY_FARM_DURATION)
	AddFarmToFarmMap(	'Kournans',						KournansFarm,					5,					$KOURNANS_FARM_DURATION)
	AddFarmToFarmMap(	'Kurzick Ferndale',				KurzickFerndaleFarm,			15,					$KURZICKS_FERNDALE_DURATION)
	AddFarmToFarmMap(	'Kurzick Drazach',				KurzickDrazachFarm,				10,					$KURZICKS_DRAZACH_DURATION)
	AddFarmToFarmMap(	'LDOA',							LDOATitleFarm,					0,					$LDOA_FARM_DURATION)
	AddFarmToFarmMap(	'Lightbringer',					LightbringerFarm,				5,					$LIGHTBRINGER_FARM_DURATION)
	AddFarmToFarmMap(	'Lightbringer & Sunspear',		LightbringerSunspearFarm,		10,					$LIGHTBRINGER_SUNSPEAR_FARM_DURATION)
	AddFarmToFarmMap(	'LuxonMQ',						LuxonMountQinkaiFarm,			10,					$LUXONS_MOUNT_QINKAI_DURATION)
	AddFarmToFarmMap(	'LuxonSS',						LuxonSilentSurfFarm,			10,					$LUXONS_SILENT_SURF_DURATION)
	AddFarmToFarmMap(	'Mantids',						MantidsFarm,					5,					$MANTIDS_FARM_DURATION)
	AddFarmToFarmMap(	'Ministerial Commendations',	MinisterialCommendationsFarm,	5,					$COMMENDATIONS_FARM_DURATION)
	AddFarmToFarmMap(	'Minotaurs',					MinotaursFarm,					5,					$MINOTAURS_FARM_DURATION)
	AddFarmToFarmMap(	'Nexus Challenge',				NexusChallengeFarm,				5,					$NEXUS_CHALLENGE_FARM_DURATION)
	AddFarmToFarmMap(	'Norn',							NornTitleFarm,					5,					$NORN_FARM_DURATION)
	AddFarmToFarmMap(	'OmniFarm',						OmniFarm,						5,					5 * 60 * 1000)
	AddFarmToFarmMap(	'Pongmei',						PongmeiChestFarm,				5,					$PONGMEI_FARM_DURATION)
	AddFarmToFarmMap(	'Raptors',						RaptorsFarm,					5,					$RAPTORS_FARM_DURATION)
	AddFarmToFarmMap(	'Skale Fins',					SkaleFinsFarm,					5,					$SKALE_FINS_FARM_DURATION)
	AddFarmToFarmMap(	'Skrees',						SkreesFarm,						10,					$SKREES_FARM_DURATION)
	AddFarmToFarmMap(	'SoO',							SoOFarm,						15,					$SOO_FARM_DURATION)
	AddFarmToFarmMap(	'SpiritSlaves',					SpiritSlavesFarm,				5,					$SPIRIT_SLAVES_FARM_DURATION)
	AddFarmToFarmMap(	'Sunspear Armor',				SunspearArmorFarm,				5,					$SUNSPEAR_ARMOR_FARM_DURATION)
	AddFarmToFarmMap(	'Tasca',						TascaChestFarm,					5,					$TASCA_FARM_DURATION)
	AddFarmToFarmMap(	'MagmasRun',						MagmasChestFarm,				5,					$MAGMAS_FARM_DURATION)
	AddFarmToFarmMap(	'TunnelsOfTheForsaken',			TunnelsOfTheForsakenFarm,		5,					$TUNNELS_OF_THE_FORSAKEN_FARM_DURATION)
	AddFarmToFarmMap(	'Underworld',					UnderworldFarm,					5,					$UW_FARM_DURATION)
	AddFarmToFarmMap(	'Vaettirs',						VaettirsFarm,					5,					$VAETTIRS_FARM_DURATION)
	AddFarmToFarmMap(	'Vanguard',						VanguardTitleFarm,				5,					$VANGUARD_TITLE_FARM_DURATION)
	AddFarmToFarmMap(	'Voltaic',						VoltaicFarm,					10,					$VOLTAIC_FARM_DURATION)
	AddFarmToFarmMap(	'War Supply Keiran',			WarSupplyKeiranFarm,			10,					$WAR_SUPPLY_FARM_DURATION)
	AddFarmToFarmMap(	'Zodiac',						ZodiacFarm,						10,					$ZODIAC_FARM_DURATION)
	AddFarmToFarmMap(	'Manual Mode',					ManualMode,						0,					2 * 60 * 1000)
	AddFarmToFarmMap(	'Storage',						InventoryManagementBeforeRun,	5,					2 * 60 * 1000)
	AddFarmToFarmMap(	'Tests',						RunTests,						0,					2 * 60 * 1000)
	AddFarmToFarmMap(	'TestSuite',					RunTestSuite,					0,					5 * 60 * 1000)
	AddFarmToFarmMap(	'',								RunTests,						0,					2 * 60 * 1000)
EndFunc


;~ Reset the setups of the bots when porting to a city for instance
Func ResetBotsSetups()
	$global_farm_setup						= False
	$boreal_farm_setup						= False
	$drake_flesh_farm_setup					= False
	$dm_farm_setup							= False
	$feathers_farm_setup					= False
	$froggy_farm_setup						= False
	$iris_farm_setup						= False
	$jade_brotherhood_farm_setup			= False
	$kournans_farm_setup					= False
	$ldoa_farm_setup						= False
	$lightbringer_farm_setup				= False
	$mantids_farm_setup						= False
	$pongmei_farm_setup						= False
	$raptors_farm_setup						= False
	$skrees_farm_setup						= False
	$soo_farm_setup							= False
	$spirit_slaves_farm_setup				= False
	$tasca_farm_setup						= False
	$Magmas_farm_setup						= False
	$tunnels_of_the_forsaken_farm_setup		= False
	$vaettirs_farm_setup					= False
	$zodiac_farm_setup						= False
	; Those do not need to be reset - party did not change, build did not change, and there is no need to refresh portal
	; BUT those bots MUST tp to the correct map on every loop
	;$cof_farm_setup						= False
	;$corsairs_farm_setup					= False
	;$follower_setup						= False
	;$fow_farm_setup						= False
	;$gemstones_farm_setup					= False
	;$gemstone_margonite_farm_setup			= False
	;$gemstone_stygian_farm_setup			= False
	;$gemstone_torment_farm_setup			= False
	;$glint_challenge_setup					= False
	;$lightbringer_farm_setup				= False
	;$ministerial_commendations_farm_setup	= False
	;$uw_farm_setup							= False
	;$voltaic_farm_setup					= False
	;$warsupply_farm_setup					= False
EndFunc


;~ v24: stuck watchdog recovery - EVERY farm setup flag back to False, as on a fresh start (the per-loop flags that
;~ ResetBotsSetups keeps are reset too), plus the party wipe counter. Statistics, session counters, configs are not touched.
Func ResetAllFarmSetupsAfterStuck()
	ResetBotsSetups()
	$asuran_farm_setup	= False
	$cof_farm_setup	= False
	$corsairs_farm_setup	= False
	$fow_farm_setup	= False
	$fow_toc_farm_setup	= False
	$gemstone_margonite_farm_setup	= False
	$gemstone_stygian_farm_setup	= False
	$gemstone_torment_farm_setup	= False
	$gemstones_farm_setup	= False
	$glint_challenge_setup	= False
	$kurzick_drazach_setup	= False
	$kurzick_ferndale_setup	= False
	$lightbringer_sunspear_farm_setup	= False
	$luxon_mount_qinkai_setup	= False
	$luxon_silent_surf_setup	= False
	$ministerial_commendations_farm_setup	= False
	$minotaurs_farm_setup	= False
	$nexus_challenge_setup	= False
	$norn_farm_setup	= False
	$skale_fins_farm_setup	= False
	$snowman_farm_setup	= False
	$sunspear_armor_farm_setup	= False
	$uw_farm_setup	= False
	$vanguard_farm_setup	= False
	$voltaic_farm_setup	= False
	$warsupply_farm_setup	= False
	ResetFailuresCounter()
EndFunc


;~ Setup executed for all farms - setup weapon slots, player and team builds if provided
Func GeneralFarmSetup()
	Local $weaponSlot = $run_options_cache['run.weapon_slot']
	If $weaponSlot <> 0 Then
		Info('Setting player weapon slot to ' & $weaponSlot & ' according to GUI settings')
		ChangeWeaponSet($weaponSlot)
		Sleep(500)
	EndIf
	If $run_options_cache['team.automatic_team_setup'] Then
		; Need to be in an outpost to change team and builds
		If GetMapType() <> $ID_OUTPOST Then TravelToOutpost($ID_EYE_OF_THE_NORTH)
		SetupPlayerUsingGlobalSettings()
		SetupTeamUsingGlobalSettings()
	EndIf
	If $character_name <> '' Then
		If $run_options_cache['run.go_offline'] Then SetPlayerStatus(0)
		If $run_options_cache['run.flash_whisper'] Then EnableWhisperFlash()
	EndIf

	SetupPlayerBuildOverrides()

	$global_farm_setup = True
EndFunc


;~ Helper to add farms into map in a one-liner
Func AddFarmToFarmMap($farmName, $farmFunction, $farmInventorySpace, $farmDuration)
	Local $farmArray[] = [$farmName, $farmFunction, $farmInventorySpace, $farmDuration]
	$farm_map[$farmName] = $farmArray
EndFunc


;~ Return if team automatic setup is enabled
Func IsTeamAutoSetup()
	Return $run_options_cache['team.automatic_team_setup']
EndFunc


;~ Setup player build from global settings (from GUI or JSON)
Func SetupPlayerUsingGlobalSettings()
	If $run_options_cache['team.load_player_build'] Then
		Info('Loading player build from GUI')
		LoadSkillTemplate($run_options_cache['team.player_build'])
		RandomSleep(500)
	EndIf
EndFunc


;~ Auto-detect player build and wire up specialized combat/maintenance routines
Func SetupPlayerBuildOverrides()
	; For build detection, we iterate over skills and key skills + profession will give use which build must be used
	Local $profession = GetHeroProfession(0)
	Local $skillbar = GetSkillbar(0)
	For $i = 1 To 8
		Local $skillID = DllStructGetData($skillbar, 'SkillID' & $i)
		If $profession == $ID_PARAGON Then
			If $skillID == $ID_HEROIC_REFRAIN Then Return SetupHRBuild()
			;If $skillID == ... Then Return ...
		EndIf
		;If $profession == $ID_NECROMANCER Then
			;If $skillID == ... Then Return ...
		;EndIf
	Next
EndFunc


;~ Setup team build from global settings (from GUI or JSON)
Func SetupTeamUsingGlobalSettings($teamSize = $ID_TEAM_SIZE_LARGE)
	Info('Setting up team according to GUI settings')
	LeaveParty()
	; Could use Eval(), it is shorter but also kind of dirty
	For $i = 1 To $ID_TEAM_SIZE_LARGE - 1
		Local $hero = $run_options_cache['team.hero_' & $i]
		If $hero <> '' Then
			AddHero($HERO_IDS_FROM_NAMES[$hero])
			If $run_options_cache['team.load_hero_' & $i & '_build'] Then
				RandomSleep(500)
				Info('Loading hero ' & $i & ' build from GUI')
				LoadSkillTemplate($run_options_cache['team.hero_' & $i & '_build'], $i)
			EndIf
		EndIf
	Next
EndFunc


Func IsHardmodeEnabled()
	Return $run_options_cache['run.hard_mode']
EndFunc


Func SwitchToHardModeIfEnabled()
	If IsHardmodeEnabled() Then
		SwitchMode($ID_HARD_MODE)
	Else
		SwitchMode($ID_NORMAL_MODE)
	EndIf
EndFunc


;~ Fill the inventory cache with additional derived data
Func BuildInventoryDerivedFlags()
	; -------- Pickup --------
	Local $pickupSomething = IsAnyChecked('Pick up items')
	$inventory_management_cache['@pickup.something'] = $pickupSomething
	$inventory_management_cache['@pickup.nothing'] = Not $pickupSomething
	Local $pickupSomeWeapons = IsAnyChecked('Pick up items.Weapons and offhands')
	$inventory_management_cache['@pickup.weapons.something'] = $pickupSomeWeapons
	$inventory_management_cache['@pickup.weapons.nothing'] = Not $pickupSomeWeapons

	; -------- Identify --------
	Local $identifySomething = IsAnyChecked('Identify items')
	$inventory_management_cache['@identify.something'] = $identifySomething
	$inventory_management_cache['@identify.nothing'] = Not $identifySomething

	; -------- Salvage --------
	Local $salvageSomething = IsAnyChecked('Salvage items')
	$inventory_management_cache['@salvage.something'] = $salvageSomething
	$inventory_management_cache['@salvage.nothing'] = Not $salvageSomething
	Local $salvageSomeWeapons = IsAnyChecked('Salvage items.Weapons and offhands')
	$inventory_management_cache['@salvage.weapons.something'] = $salvageSomeWeapons
	$inventory_management_cache['@salvage.weapons.nothing'] = Not $salvageSomeWeapons
	Local $salvageSomeSalvageables = IsAnyChecked('Salvage items.Armor salvageables')
	$inventory_management_cache['@salvage.salvageables.something'] = $salvageSomeSalvageables
	$inventory_management_cache['@salvage.salvageables.nothing'] = Not $salvageSomeSalvageables
	Local $salvageSomeTrophies = IsAnyChecked('Salvage items.Trophies')
	$inventory_management_cache['@salvage.trophies.something'] = $salvageSomeTrophies
	$inventory_management_cache['@salvage.trophies.nothing'] = Not $salvageSomeTrophies
	Local $salvageSomeMaterials = IsAnyChecked('Salvage items.Rare Materials')
	$inventory_management_cache['@salvage.materials.something'] = $salvageSomeMaterials
	$inventory_management_cache['@salvage.materials.nothing'] = Not $salvageSomeMaterials

	; -------- Sell --------
	Local $sellSomething = IsAnyChecked('Sell items')
	$inventory_management_cache['@sell.something'] = $sellSomething
	$inventory_management_cache['@sell.nothing'] = Not $sellSomething
	Local $sellSomeWeapons = IsAnyChecked('Sell items.Weapons and offhands')
	$inventory_management_cache['@sell.weapons.something'] = $sellSomeWeapons
	$inventory_management_cache['@sell.weapons.nothing'] = Not $sellSomeWeapons
	Local $sellSomeSalvageables = IsAnyChecked('Sell items.Armor salvageables')
	$inventory_management_cache['@sell.salvageables.something'] = $sellSomeSalvageables
	$inventory_management_cache['@sell.salvageables.nothing'] = Not $sellSomeSalvageables

	Local $sellSomeBasicMaterials = IsAnyChecked('Sell items.Basic Materials')
	$inventory_management_cache['@sell.materials.basic.something'] = $sellSomeBasicMaterials
	$inventory_management_cache['@sell.materials.basic.nothing'] = Not $sellSomeBasicMaterials
	Local $sellSomeRareMaterials = IsAnyChecked('Sell items.Rare Materials')
	$inventory_management_cache['@sell.materials.rare.something'] = $sellSomeRareMaterials
	$inventory_management_cache['@sell.materials.rare.nothing'] = Not $sellSomeRareMaterials
	Local $sellSomeMaterials = $sellSomeBasicMaterials Or $sellSomeRareMaterials
	$inventory_management_cache['@sell.materials.something'] = $sellSomeMaterials
	$inventory_management_cache['@sell.materials.nothing'] = Not $sellSomeMaterials

	; -------- Buy --------
	Local $buySomething = IsAnyChecked('Buy items')
	$inventory_management_cache['@buy.something'] = $buySomething
	$inventory_management_cache['@buy.nothing'] = Not $buySomething

	Local $buySomeBasicMaterials = IsAnyChecked('Buy items.Basic Materials')
	$inventory_management_cache['@buy.materials.basic.something'] = $buySomeBasicMaterials
	$inventory_management_cache['@buy.materials.basic.nothing'] = Not $buySomeBasicMaterials
	Local $buySomeRareMaterials = IsAnyChecked('Buy items.Rare Materials')
	$inventory_management_cache['@buy.materials.rare.something'] = $buySomeRareMaterials
	$inventory_management_cache['@buy.materials.rare.nothing'] = Not $buySomeRareMaterials
	Local $buySomeMaterials = $buySomeBasicMaterials Or $buySomeRareMaterials
	$inventory_management_cache['@buy.materials.something'] = $buySomeMaterials
	$inventory_management_cache['@buy.materials.nothing'] = Not $buySomeMaterials

	; -------- Store --------
	Local $storeSomething = IsAnyChecked('Store items')
	$inventory_management_cache['@store.something'] = $storeSomething
	$inventory_management_cache['@store.nothing'] = Not $storeSomething
	Local $storeSomeWeapons = IsAnyChecked('Store items.Weapons and offhands')
	$inventory_management_cache['@store.weapons.something'] = $storeSomeWeapons
	$inventory_management_cache['@store.weapons.nothing'] = Not $storeSomeWeapons
	; v25: Store items > Components (step 4c of InventoryManagementBeforeRun); checked definitions re-resolved after every apply/load
	$inventory_management_cache['@store.components.something'] = IsAnyStoreComponentChecked($inventory_management_cache)
	If MapExists($inventory_management_cache, '@store.components.definitions') Then MapRemove($inventory_management_cache, '@store.components.definitions')
EndFunc


;~ Return if any option at provided path or lower in the tree is checked
Func IsAnyChecked($path)
	Local $pathLength = StringLen($path) + 1
	For $key In MapKeys($inventory_management_cache)
		If Not $inventory_management_cache[$key] Then ContinueLoop
		If $key == $path Then Return True
		If StringLen($key) <= $pathLength Then ContinueLoop
		If StringLeft($key, $pathLength) == ($path & '.') Then Return True
	Next
	Return False
EndFunc


;~ Return checked leaf options under provided path
Func GetAllChecked($map, $path, $minDepth = -1, $maxDepth = -1)
	Local $checkedElements[0]
	Local $pathLength = StringLen($path) + 1

	; Step 1: collect all checked descendants
	For $key In MapKeys($map)
		If Not $map[$key] Then ContinueLoop
		If $key == $path Then ContinueLoop
		If StringLen($key) <= $pathLength Then ContinueLoop
		If StringLeft($key, $pathLength) == ($path & '.') Then
			_ArrayAdd($checkedElements, $key)
		EndIf
	Next

	; Step 2: remove checked parents (keep leaves only)
	Local $size = UBound($checkedElements)
	Local $remove[$size]

	For $i = 0 To $size - 1
		For $j = 0 To $size - 1
			If $i = $j Then ContinueLoop
			If StringLeft($checkedElements[$j], StringLen($checkedElements[$i]) + 1) == $checkedElements[$i] & '.' Then
				$remove[$i] = True
				ExitLoop
			EndIf
		Next
	Next

	Local $leaves[0]
	For $i = 0 To $size - 1
		If Not $remove[$i] Then _ArrayAdd($leaves, $checkedElements[$i])
	Next

	; Step 3: depth filtering
	If $minDepth > 0 Or $maxDepth > 0 Then
		Local $filtered[0]

		For $element In $leaves
			Local $relative = StringTrimLeft($element, $pathLength)
			; Careful - this is AutoIt, size is present in first slot
			Local $depth = UBound(StringSplit($relative, '.')) - 1
			If $minDepth > 0 And $depth < $minDepth Then ContinueLoop
			If $maxDepth > 0 And $depth > $maxDepth Then ContinueLoop

			_ArrayAdd($filtered, $element)
		Next

		Return $filtered
	EndIf

	Return $leaves
EndFunc
#EndRegion Setup


#Region Authentification and Login
;~ Initialize connection to GW with the character name or process ID given
Func Authentification($characterName)
	If ($characterName == '') Then
		Warn('Running without authentification.')
	ElseIf $run_mode == 'HEADLESS' Then
		SetLogFileTag($characterName)
		Info('Running via PID ' & $process_id)
		If InitializeGameClientForGWA2(True) = 0 Then
			; Headless: no MsgBox (nobody would see it and it would block the slave forever)
			Error('Could not find a ProcessID or somewhat <<' & $process_id & '>> ' & VarGetType($process_id) & '')
			Return $FAIL
		EndIf
		; v38.9-bridgeA: reads through GWBridge when it can load, classic GWA2 otherwise (logged either way)
		BotsHubBridgeStart(GetPID() <> '' ? GetPID() : Number($process_id))
		$attached_for_tools = True
	Else
		SetLogFileTag($characterName)
		Local $clientIndex = FindClientIndexByCharacterName($characterName)
		If $clientIndex == -1 Then
			MsgBox(0, 'Error', 'Could not find a GW client with a character named <<' & $characterName & '>>')
			Return $FAIL
		Else
			SelectClient($clientIndex)
			OpenDebugLogFile()
			If InitializeGameClientForGWA2(True) = 0 Then
				MsgBox(0, 'Error', 'Failed game initialisation')
				Return $FAIL
			EndIf
			; v38.9-bridgeA: reads through GWBridge when it can load, classic GWA2 otherwise (logged either way)
			BotsHubBridgeStart(GetPID())
		EndIf
		RenameGUI('GW Bot Hub - ' & $characterName & ' [' & $GWB_BOTSHUB_BUILD & ']')
		$attached_for_tools = True
	EndIf
	Return $SUCCESS
EndFunc
#EndRegion Authentification and Login


Func UpdateHeartbeat()
	WriteSlaveToMaster($slave_index, 'heartbeat', $slave_heartbeat)
	$slave_heartbeat += 1

	; Debug level: at Info these two lines were logged every 5s (~35k lines a day)
	Debug('Master heartbeat: ' & ReadMasterBroadcast('heartbeat'))
	Local $enableGUICommand = ReadMasterToSlave($slave_index, 'enableGUI')
	Debug('Enable GUI order: ' & $enableGUICommand)
	; The GUI is created once: hiding then showing it again used to call CreateBotsHubGUI() a second time
	; (duplicate window, all control IDs re-assigned)
	Local Static $guiCreated = False
	If Not $gui_enabled And $enableGUICommand Then
		If Not $guiCreated Then
			CreateBotsHubGUI()
			ApplyConfigToGUI()
			FillConfigurationCombo()
			$guiCreated = True
		EndIf
		GUISetState(@SW_SHOWNORMAL)
		Info('GW Bot Hub ' & $GW_BOT_HUB_VERSION)
		$gui_enabled = True
	EndIf
	If $gui_enabled And Not $enableGUICommand Then
		GUISetState(@SW_HIDE)
		$gui_enabled = False
	EndIf
EndFunc





;~ Lightweight attach so Tools and utilities can run without a full farm
Func AttachForTools()
	Local $char = GUICtrlRead($gui_combo_characterchoice)
	If $char == '' Then
		MsgBox(0, 'Attach', 'Select a character first.')
		Return
	EndIf
	; Re-attaching re-runs the whole GWA2 pattern scan + injection: never do it in the middle of a run
	If $runtime_status == 'RUNNING' Or $runtime_status == 'WILL_PAUSE' Then
		Warn('Cannot attach while a farm is running')
		Return
	EndIf
	If $attached_for_tools And $char == $character_name Then
		Info('Already attached to ' & $char)
		Return
	EndIf
	$character_name = $char
	Local $result = Authentification($character_name)
	If $result == $SUCCESS Then
		Info('Attached to Guild Wars for Tools use')
		GUICtrlSetData($gui_label_attachstatus, 'Attached')
		$attached_for_tools = True
		MsgBox(0, 'Attach', 'Attached successfully. Tools are ready.')
	Else
		MsgBox(0, 'Attach', 'Failed to attach. Make sure Guild Wars is running with that character.')
	EndIf
EndFunc

Func IsAttachedForTools()
	; Tools issue game commands from a GUI event: running them while a farm is executing interleaves two bots
	If $runtime_status == 'RUNNING' Or $runtime_status == 'WILL_PAUSE' Then
		MsgBox(0, 'Tools', 'Pause the farm (and wait for it to stop) before using Tools.')
		Return False
	EndIf
	If Not $attached_for_tools Then
		MsgBox(0, 'Tools', 'Attach to Guild Wars first.')
		Return False
	EndIf
	Return True
EndFunc


;~ 'Open Storage' buttons (Tools tab and Options tab), v17: same behaviour as the original v10 Options button -
;~ OpenXunlaiWindow() (kShowXunlaiChest UI message, no NPC, no packet) in town, in explorables (the game shows storage
;~ view-only there) and while a farm is running. Only guards that cannot block a legit use: not attached / client closed
;~ (logged, no memory read, nothing sent). Loading or explorable only add a log note; the window is still requested.
Func OpenStorageForTools()
	If Not $attached_for_tools Then
		Warn('[Storage] Not attached to Guild Wars - use Tools > Attach or start a farm first. Storage not opened.')
		Return False
	EndIf
	Local $pid = GetPID()
	If $pid == '' Or $pid == 0 Or ProcessExists($pid) == 0 Then
		Warn('[Storage] Guild Wars client not found (closed?) - restart it and attach again. Storage not opened.')
		Return False
	EndIf
	Local $note = GetOpenStorageNote(GetMapType(), GetMyID())
	If $note <> '' Then Info('[Storage] ' & $note)
	OpenXunlaiWindow()
	Info('[Storage] Xunlai storage window requested')
	; v23: re-read the Items panel totals (storage is read in outposts); not while a farm run is executing
	If $runtime_status <> 'RUNNING' Then ItemsPanelRefresh(True)
	Return True
EndFunc


;~ v24: Tools > 'Empty Tab': moves the selected Xunlai storage tab into the inventory, slot 1 first (Utils-Storage EmptyStorageBag).
;~ Needs what moving items out of storage needs in the game: attached, not during a farm run, in an outpost/town (in
;~ explorables the storage is view-only). Opens the storage window like Open Storage so the moves can be watched.
Func EmptyStorageTabForTools($tabName)
	Local $bagIndex = StorageTabBagIndex($tabName)
	If $bagIndex == 0 Then
		Warn('[Empty Tab] Pick a storage tab (I to XIII or Anniversary) first')
		Return False
	EndIf
	If Not IsAttachedForTools() Then Return False
	Local $pid = GetPID()
	If $pid == '' Or $pid == 0 Or ProcessExists($pid) == 0 Then
		Warn('[Empty Tab] Guild Wars client not found (closed?) - restart it and attach again. Nothing moved.')
		Return False
	EndIf
	If GetMapType() <> $ID_OUTPOST Or GetMyID() == 0 Then
		Warn('[Empty Tab] Items can only be taken out of storage in an outpost or town (view-only in explorable areas) - nothing moved')
		Return False
	EndIf
	OpenXunlaiWindow()
	Sleep(500 + GetPing())
	EmptyStorageBag($bagIndex, $tabName)
	ItemsPanelRefresh(True)
	Return True
EndFunc


;~ Informational note only (never blocks): '' in an outpost/town
Func GetOpenStorageNote($mapType, $myID)
	If $mapType == $ID_LOADING Or $myID == 0 Then Return 'Character is loading or not in game - requesting the storage window anyway (it may not appear).'
	If $mapType == $ID_EXPLORABLE Then Return 'Explorable area: the game shows the storage window view-only (no deposit/withdraw).'
	Return ''
EndFunc


;~ 'Return on death' option: when enabled, IsRunFailed() reports the run as failed at the first party wipe so the
;~ farm stops and returns to its outpost instead of fighting on. (The option used to be stored but never read.)
Func ApplyDeathReturnOption()
	Info('Return on death: ' & ($run_options_cache['run.return_on_death'] ? 'Yes' : 'No'))
EndFunc
