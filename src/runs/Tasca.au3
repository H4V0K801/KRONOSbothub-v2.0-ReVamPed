#CS ===========================================================================
#include '../LoadWaitHelpers.au3'
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
#CE ===========================================================================

#include-once
#RequireAdmin
#NoTrayIcon

#include '../../lib/GWA2.au3'
#include '../../lib/GWA2_ID.au3'
#include '../../lib/Utils.au3'
#include 'ChestFarmCommon.au3'  ; Shared movement, defend, stuck (with U-path), escape logic

; Possible improvements :

Opt('MustDeclareVars', True)

; ==== Constants ====
Global Const $TASCA_DERVISH_CHESTRUNNER_SKILLBAR = 'OgejwyezHT8I6MHQ3l0kNQ4OIQ'
Global Const $TASCA_ASSASSIN_CHESTRUNNER_SKILLBAR = 'OwBj4pf8YQ8I6MHQ3lxlpZ4OIQA'
Global Const $TASCA_MESMER_CHESTRUNNER_SKILLBAR = 'OQdTAmP7ZiHRn5A6ukmsBC3BBC'
Global Const $TASCA_ELEMENTALIST_CHESTRUNNER_SKILLBAR = 'OgdTw4P7HiHRn5A6ukmsBC3BBC'
Global Const $TASCA_MONK_CHESTRUNNER_SKILLBAR = 'OwcTAnP7ZiHRn5A6ukmsBC3BBC'
Global Const $TASCA_NECROMANCER_CHESTRUNNER_SKILLBAR = 'OAdT8Z/YYiHRn5A6ukmsBC3BBC'
Global Const $TASCA_RITUALIST_CHESTRUNNER_SKILLBAR = 'OAej8xeM5Q8I6MHQ3l0kNQ4OIQ'

Global Const $TASCA_CHESTRUN_INFORMATIONS = 'For best results, have :' & @CRLF _
	& '- 12 in Shadow Arts' & @CRLF _
	& '- 16 in Mysticism if playing Dervish' & @CRLF _
	& '- 3 in Deadly Arts' & @CRLF _
	& '- A staff +20e and +20% enchantment duration' & @CRLF _
	& '- caster weapons on all heroes' & @CRLF _
	& '- Windwalker insignias on all the armor pieces' & @CRLF _
	& '- Vigor'
; Average duration ~ 3m
Global Const $TASCA_FARM_DURATION = (3 * 60) * 1000

Global Const $TASCA_CHEST_RANGE = 2 * $RANGE_SPELLCAST

; ---- Route ----
; Waypoints are visited in this order. Every chest belongs to the waypoint it is closest to, so a chest is only
; opened when the bot is at ITS waypoint - never one that is further along the route, never one that was left behind.
Global Const $TASCA_WAYPOINTS[18][2] = [ _
	[-6100, 21367], _
	[-3900, 18863], _
	[-1742, 17564], _
	[-850, 17150], _
	[-550, 16800], _
	[240, 17500], _
	[2000, 21600], _
	[5150, 21000], _
	[6200, 22200], _
	[5000, 25000], _
	[2424, 26466], _
	[4400, 27000], _
	[5130, 28380], _
	[5800, 28120], _
	[7750, 25850], _
	[9500, 26800], _
	[11000, 26350], _
	[11900, 25850]]
; Where heroes are parked when they are sent away
Global Const $TASCA_HERO_PARK_X = -9994
Global Const $TASCA_HERO_PARK_Y = 18795

Global $tasca_farm_setup = False
Global $tasca_player_profession = $ID_DERVISH
Global $tasca_chest_attempts[]

;~ Main method to chest farm Tasca
Func TascaChestFarm()
	If Not $tasca_farm_setup And SetupTascaChestFarm() == $FAIL Then Return $PAUSE

	; === START Low Health & Position Resync Monitors (from shared) ===
	AdlibRegister("LowHealthMonitor", $LOW_HEALTH_CHECK_INTERVAL)
	AdlibRegister("CombatStuckResync", 100)
	AdlibRegister("ChestKnockdownGuard", $CHEST_KNOCKDOWN_GUARD_INTERVAL)

	If GoToTascasDemise() == $FAIL Then
		AdlibUnRegister("LowHealthMonitor")
		AdlibUnRegister("CombatStuckResync")
		AdlibUnRegister("ChestKnockdownGuard")
		Return $FAIL
	EndIf
	Local $result = TascaChestFarmLoop()

	; === STOP Monitors ===
	AdlibUnRegister("LowHealthMonitor")
	AdlibUnRegister("CombatStuckResync")
	AdlibUnRegister("UseDeadlyParadox")
	AdlibUnRegister("ChestKnockdownGuard")

	RobustResignAndReturnToOutpost($ID_THE_GRANITE_CITADEL)
	Return $result
EndFunc

;~ Tasca chest farm setup
Func SetupTascaChestFarm()
	Info('Setting up farm')
	If RobustTravelToOutpost($ID_THE_GRANITE_CITADEL, $district_name) == $FAIL Then Return $FAIL
	;UseCitySpeedBoost()
	If SetupPlayerTascaChestFarm() == $FAIL Then Return $FAIL
	If SetupTeamTascaChestFarm() == $FAIL Then Return $FAIL
	SwitchToHardModeIfEnabled()

	If GoToTascasDemise() == $FAIL Then Return $FAIL
	MoveTo(-9250, 19850)
	Move(-10000, 18875)
	RandomSleep(1000)
	RobustWaitMapLoading($ID_THE_GRANITE_CITADEL, 8000, 1000)
	; v38.1: mark setup complete only once the Citadel is confirmed loaded after the walk-out
	If Not ConfirmMapReady($ID_THE_GRANITE_CITADEL, 'The Granite Citadel') Then
		Warn('Tasca setup: Citadel did not finish loading after the walk-out')
		TascaResignOrTravelToCitadel()
		Return $FAIL
	EndIf
	$tasca_farm_setup = True
	Info('Preparations complete')
	Return $SUCCESS
EndFunc

Func SetupPlayerTascaChestFarm()
;	Info('Setting up player build skill bar')
;	Switch DllStructGetData(GetMyAgent(), 'Primary')
;		Case $ID_DERVISH
;			$tasca_player_profession = $ID_DERVISH
;			LoadSkillTemplate($TASCA_DERVISH_CHESTRUNNER_SKILLBAR)
;		Case $ID_ASSASSIN
;			$tasca_player_profession = $ID_ASSASSIN
;			LoadSkillTemplate($TASCA_ASSASSIN_CHESTRUNNER_SKILLBAR)
;		Case $ID_MESMER
;			$tasca_player_profession = $ID_MESMER
;			LoadSkillTemplate($TASCA_MESMER_CHESTRUNNER_SKILLBAR)
;		Case $ID_MONK
;			$tasca_player_profession = $ID_MONK
;			LoadSkillTemplate($TASCA_MONK_CHESTRUNNER_SKILLBAR)
;		Case $ID_ELEMENTALIST
;			$tasca_player_profession = $ID_ELEMENTALIST
;			LoadSkillTemplate($TASCA_ELEMENTALIST_CHESTRUNNER_SKILLBAR)
;		Case $ID_NECROMANCER
;			$tasca_player_profession = $ID_NECROMANCER
;			LoadSkillTemplate($TASCA_NECROMANCER_CHESTRUNNER_SKILLBAR)
;		Case $ID_RITUALIST
;			$tasca_player_profession = $ID_RITUALIST
;			LoadSkillTemplate($TASCA_RITUALIST_CHESTRUNNER_SKILLBAR)
;		Case Else
;			; other characters have too few energy
;			Warn('Should run this farm as Dervish, Assassin, Mesmer, Monk, Elementalist, Necromancer or Ritualist')
;			Return $FAIL
;	EndSwitch
	RandomSleep(250)
	Return $SUCCESS
EndFunc

Func SetupTeamTascaChestFarm()
	If IsTeamAutoSetup() Then Return True

	Info('Setting up team according to default settings')
	RandomSleep(500)
	If GetPartySize() <> 8 Then
		Warn('Could not set up party correctly. Team size different than 8')
		Return $FAIL
	EndIf
	Return $SUCCESS
EndFunc

;~ True when the character is in the Granite Citadel outpost and the map is fully loaded
Func TascaCitadelIsReady()
	If GetMapID() <> $ID_THE_GRANITE_CITADEL Then Return False
	If GetMapType() <> $ID_OUTPOST Then Return False
	Return ConfirmMapReady($ID_THE_GRANITE_CITADEL, 'The Granite Citadel')
EndFunc

;~ Resign back to the Citadel up to 3 times; map-travel only as a last resort.
;~ Map travel resets $tasca_farm_setup so the next run redoes the setup walk, and the caller should end the run as $FAIL.
;~ Returns $SUCCESS if resign (or already being there) put us in a loaded Citadel; $FAIL after last-resort travel.
Func TascaResignOrTravelToCitadel()
	Local $try
	For $try = 1 To 3
		If TascaCitadelIsReady() Then Return $SUCCESS
		; Resign only from an explorable; an outpost needs map travel (wrong town, or Citadel not loaded)
		If GetMapType() == $ID_OUTPOST Then ExitLoop
		Info('Tasca: resigning to the Granite Citadel (attempt ' & $try & '/3)')
		If RobustResignAndReturnToOutpost($ID_THE_GRANITE_CITADEL) == $SUCCESS And TascaCitadelIsReady() Then Return $SUCCESS
	Next
	If TascaCitadelIsReady() Then Return $SUCCESS
	Return TascaLastResortTravelToCitadel()
EndFunc

;~ Map travel to the Citadel, forgetting the quick-exit setup so the next run walks out and back in again
Func TascaLastResortTravelToCitadel()
	Warn('Tasca: resign failed - map traveling to the Granite Citadel and resetting farm setup')
	$tasca_farm_setup = False
	RobustTravelToOutpost($ID_THE_GRANITE_CITADEL, $district_name)
	Return $FAIL
EndFunc

;~ Before the portal walk: be in a fully loaded Granite Citadel. Resign from an explorable (including Tasca's Demise)
;~ rather than map-traveling; travel only if resign fails 3 times or we are in the wrong outpost.
Func TascaEnsureCitadelOutpost()
	If TascaCitadelIsReady() Then Return $SUCCESS
	If GetMapType() <> $ID_OUTPOST Then Return TascaResignOrTravelToCitadel()
	; Wrong outpost, or the Citadel did not finish loading: map travel is the last resort
	Return TascaLastResortTravelToCitadel()
EndFunc

;~ v38.1: Tasca-scoped watchdog recovery - resign from an explorable rather than map-traveling
Func TascaWatchdogRecover($target)
	#forceref $target
	Return TascaResignOrTravelToCitadel()
EndFunc

;~ Move out of outpost into Tasca's Demise
Func GoToTascasDemise()
	If TascaEnsureCitadelOutpost() == $FAIL Then Return $FAIL
	Local $attempts = 0
	While GetMapID() <> $ID_TASCAS_DEMISE
		If Not MapEntryAttemptAllowed($attempts, 'Tascas Demise') Then Return $FAIL
		Info('Moving to Tasca''s Demise')
		MoveTo(-10000, 18875)
		Move(-9250, 19850)
		RandomSleep(5000)
		RobustWaitMapLoading($ID_TASCAS_DEMISE, 8000, 1000)
	WEnd
	; v30: the map ID switches before the load completes - act only once it is fully loaded
	If Not ConfirmMapReady($ID_TASCAS_DEMISE) Then TascaResignOrTravelToCitadel()
	If Not ConfirmMapReady($ID_TASCAS_DEMISE) Then Return $FAIL
	Return $SUCCESS
EndFunc

;~ Forget everything that belongs to the previous run
Func TascaResetRunState()
	ChestResetRunState()  ; shared state
	; Chest IDs may be reused between runs, a stale "opened" flag would make the bot skip a chest
	ClearChestsMap()
	Local $newAttempts[]
	$tasca_chest_attempts = $newAttempts
EndFunc

;~ Tasca Chest farm loop
Func TascaChestFarmLoop()
	If GetMapID() <> $ID_TASCAS_DEMISE Then Return $FAIL

	Info('Starting chest run')
	TascaResetRunState()
	UseConsumable($ID_BIRTHDAY_CUPCAKE, True)
	UseConsumable($ID_CANDY_APPLE, True)
	RandomAlcohol()
	; Calling it here to already use shadow form, shroud of distress and dwarven stability and have enough mana later on
	ChestDefendFunction(0, 0)
	CommandAll(-9645, 19194)
	Sleep(1000)
;	PrepareZephyrSpirit()
;	RegisterBurstHealingUnit()

	Local $openedChests = 0
	;ToggleMapping(2)

	For $i = 0 To UBound($TASCA_WAYPOINTS) - 1
		If ChestRunToward($TASCA_WAYPOINTS[$i][0], $TASCA_WAYPOINTS[$i][1]) == $FAIL Then Return $FAIL
		Info('Finding Chest')
		$openedChests += TascaOpenChestsAtWaypoint($i)
		TascaSendHeroesAway($i)
	Next

	;ToggleMapping()
;	UnregisterBurstHealingUnit()
	Info('Opened ' & $openedChests & ' chests.')
	If IsPlayerAlive() Then
		Return $SUCCESS
	Else
		Return $FAIL
	EndIf
EndFunc

;~ Heroes are parked at the start once the route has moved away from them
Func TascaSendHeroesAway($waypointIndex)
	Switch $waypointIndex
		Case 2
			CommandHero(5, $TASCA_HERO_PARK_X, $TASCA_HERO_PARK_Y)
		Case 3
			CommandHero(1, $TASCA_HERO_PARK_X, $TASCA_HERO_PARK_Y)
		Case 7
			CommandHero(2, $TASCA_HERO_PARK_X, $TASCA_HERO_PARK_Y)
			CommandHero(3, $TASCA_HERO_PARK_X, $TASCA_HERO_PARK_Y)
		Case 11
			CommandHero(4, $TASCA_HERO_PARK_X, $TASCA_HERO_PARK_Y)
			CommandHero(6, $TASCA_HERO_PARK_X, $TASCA_HERO_PARK_Y)
			CommandHero(7, $TASCA_HERO_PARK_X, $TASCA_HERO_PARK_Y)
	EndSwitch
EndFunc

;~ Function to unblock when opening chests - jumps towards the chest currently being approached
Func UnblockWhenOpeningChests()
	ChestUnblockTowards($chest_goal_x, $chest_goal_y)
EndFunc

;~ Index of the waypoint that is closest to the given coordinates
Func TascaNearestWaypointIndex($X, $Y)
	Local $bestIndex = 0
	Local $bestDistance = 999999999
	For $i = 0 To UBound($TASCA_WAYPOINTS) - 1
		Local $distance = ComputeDistance($X, $Y, $TASCA_WAYPOINTS[$i][0], $TASCA_WAYPOINTS[$i][1])
		If $distance < $bestDistance Then
			$bestDistance = $distance
			$bestIndex = $i
		EndIf
	Next
	Return $bestIndex
EndFunc

;~ Nearest not-yet-handled chest that belongs to the given waypoint, or Null
Func TascaFindChestForWaypoint($waypointIndex)
	Local $me = GetMyAgent()
	Local $best = Null
	Local $bestDistance = 999999999
	Local $agents = GetAgentArray($ID_AGENT_TYPE_STATIC)
	For $agent In $agents
		If $MAP_CHESTS_IDS[DllStructGetData($agent, 'GadgetID')] == Null Then ContinueLoop
		Local $chestID = DllStructGetData($agent, 'ID')
		If $chests_map[$chestID] == 2 Then ContinueLoop
		If $tasca_chest_attempts[$chestID] <> Null Then ContinueLoop
		Local $distance = GetDistance($me, $agent)
		If $distance > $TASCA_CHEST_RANGE Then ContinueLoop
		If TascaNearestWaypointIndex(DllStructGetData($agent, 'X'), DllStructGetData($agent, 'Y')) <> $waypointIndex Then ContinueLoop
		If $distance < $bestDistance Then
			$best = $agent
			$bestDistance = $distance
		EndIf
	Next
	Return $best
EndFunc

;~ Open every chest that belongs to this waypoint, nearest first. Each chest is tried once.
;~ Returns the number of chests opened.
Func TascaOpenChestsAtWaypoint($waypointIndex)
	If FindInInventory($ID_LOCKPICK)[0] == 0 Then
		WarnOnce('No lockpicks available to open chests')
		Return 0
	EndIf

	Local $opened = 0
	Local $chest = TascaFindChestForWaypoint($waypointIndex)
	While IsDllStruct($chest) And IsPlayerAlive()
		Local $chestID = DllStructGetData($chest, 'ID')
		$tasca_chest_attempts[$chestID] = 1
		$chest_goal_x = DllStructGetData($chest, 'X')
		$chest_goal_y = DllStructGetData($chest, 'Y')

		; Chest is considered as a signpost by the game client
		GoToSignpostSafely($chest, TascaDefendFunctionForChests, UnblockWhenOpeningChests)
		If IsPlayerDead() Then Return $opened
		RandomSleep(200)
		ChestDefendFunction(0, 0)
		OpenChest()
		RandomSleep(1000)
		If IsPlayerDead() Then Return $opened
		ChestDefendFunction(0, 0)
		$chests_map[$chestID] = 2
		PickUpItems()
		$opened += 1

		$chest = TascaFindChestForWaypoint($waypointIndex)
	WEnd
	Return $opened
EndFunc

;~ Wrapper for DefendFunction to be used as survival function when going to chests
Func TascaDefendFunctionForChests()
	Return ChestDefendFunction(0, 0)
EndFunc

Func RandomAlcohol()
	If GetInventoryItemCount($ID_HUNTERS_ALE) > 0 Then
		UseConsumable($ID_HUNTERS_ALE, True)
	ElseIf GetInventoryItemCount($ID_FLASK_OF_FIREWATER) > 0 Then
		UseConsumable($ID_FLASK_OF_FIREWATER, True)
	ElseIf GetInventoryItemCount($ID_DWARVEN_ALE) > 0 Then
		UseConsumable($ID_DWARVEN_ALE, True)
	ElseIf GetInventoryItemCount($ID_WITCHS_BREW) > 0 Then
		UseConsumable($ID_WITCHS_BREW, True)
	ElseIf GetInventoryItemCount($ID_SPIKED_EGGNOG) > 0 Then
		UseConsumable($ID_SPIKED_EGGNOG, True)
	ElseIf GetInventoryItemCount($ID_VIAL_OF_ABSINTHE) > 0 Then
		UseConsumable($ID_VIAL_OF_ABSINTHE, True)
	ElseIf GetInventoryItemCount($ID_EGGNOG) > 0 Then
		UseConsumable($ID_EGGNOG, True)
	ElseIf GetInventoryItemCount($ID_BOTTLE_OF_RICE_WINE) > 0 Then
		UseConsumable($ID_BOTTLE_OF_RICE_WINE, True)
	ElseIf GetInventoryItemCount($ID_ZEHTUKAS_JUG) > 0 Then
		UseConsumable($ID_ZEHTUKAS_JUG, True)
	ElseIf GetInventoryItemCount($ID_BOTTLE_OF_JUNIBERRY_GIN) > 0 Then
		UseConsumable($ID_BOTTLE_OF_JUNIBERRY_GIN, True)
	ElseIf GetInventoryItemCount($ID_BOTTLE_OF_VABBIAN_WINE) > 0 Then
		UseConsumable($ID_BOTTLE_OF_VABBIAN_WINE, True)
	ElseIf GetInventoryItemCount($ID_SHAMROCK_ALE) > 0 Then
		UseConsumable($ID_SHAMROCK_ALE, True)
	ElseIf GetInventoryItemCount($ID_AGED_DWARVEN_ALE) > 0 Then
		UseConsumable($ID_AGED_DWARVEN_ALE, True)
	ElseIf GetInventoryItemCount($ID_HARD_APPLE_CIDER) > 0 Then
		UseConsumable($ID_HARD_APPLE_CIDER, True)
	ElseIf GetInventoryItemCount($ID_BOTTLE_OF_GROG) > 0 Then
		UseConsumable($ID_BOTTLE_OF_GROG, True)
	ElseIf GetInventoryItemCount($ID_AGED_HUNTERS_ALE) > 0 Then
		UseConsumable($ID_AGED_HUNTERS_ALE, True)
	ElseIf GetInventoryItemCount($ID_KEG_OF_AGED_HUNTERS_ALE) > 0 Then
		UseConsumable($ID_KEG_OF_AGED_HUNTERS_ALE, True)
	ElseIf GetInventoryItemCount($ID_KRYTAN_BRANDY) > 0 Then
		UseConsumable($ID_KRYTAN_BRANDY, True)
	ElseIf GetInventoryItemCount($ID_BATTLE_ISLE_ICED_TEA) > 0 Then
		UseConsumable($ID_BATTLE_ISLE_ICED_TEA, True)
	EndIf
EndFunc
