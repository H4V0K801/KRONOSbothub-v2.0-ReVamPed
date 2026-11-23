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
#include '../../lib/GWA2_ID_Items.au3'
#include '../../lib/GWA2_ID_Maps.au3'
#include '../../lib/GWA2_ID.au3'
#include '../../lib/GWA2.au3'
#include '../../lib/Utils-Agents.au3'
#include '../../lib/Utils-Console.au3'
#include '../../lib/Utils-Storage.au3'
#include '../../lib/Utils.au3'
#include 'ChestFarmCommon.au3'  ; Shared movement, defend, stuck, escape logic (derived from Tasca)

; Possible improvements :
; Replacing shadow form by something to tank assassins and warriors instead might be better

; ==== Constants ====
; Using the same build as Tasca's Demise (Dervish)
Global Const $PONGMEI_CHESTRUNNER_SKILLBAR = 'OgejwyezHT8I6MHQ3l0kNQ4OIQ'
Global Const $PONGMEI_CHESTRUN_INFORMATIONS = 'For best results, have :' & @CRLF _
	& '- 12 in Shadow Arts' & @CRLF _
	& '- 16 in Mysticism if playing Dervish' & @CRLF _
	& '- 3 in Deadly Arts' & @CRLF _
	& '- A staff +20e and +20% enchantment duration' & @CRLF _
	& '- caster weapons on all heroes' & @CRLF _
	& '- Windwalker insignias on all the armor pieces' & @CRLF _
	& '- Vigor' & @CRLF _
	& 'Note: in HM, very frequent failures on Am Fah - I suggest cutting that part of the farm if you wish to run in HM'
; Average duration ~ 4m20s
Global Const $PONGMEI_FARM_DURATION = (4 * 60 + 20) * 1000

Global Const $ID_PARAGON_MERCENARY_HERO = $ID_MERCENARY_HERO_5

Global $pongmei_farm_setup = False

;~ Main method to chest farm Pongmei
Func PongmeiChestFarm()
	If Not $pongmei_farm_setup Then SetupPongmeiChestFarm()

	; === START Low Health & Position Resync Monitors (from shared) ===
	AdlibRegister("LowHealthMonitor", $LOW_HEALTH_CHECK_INTERVAL)
	AdlibRegister("CombatStuckResync", 100)
	AdlibRegister("ChestKnockdownGuard", $CHEST_KNOCKDOWN_GUARD_INTERVAL)

	If GoToPongmeiValley() == $FAIL Then
		AdlibUnRegister("LowHealthMonitor")
		AdlibUnRegister("CombatStuckResync")
		AdlibUnRegister("ChestKnockdownGuard")
		Return $FAIL
	EndIf
	Local $result = PongmeiChestFarmLoop()

	; === STOP Monitors ===
	AdlibUnRegister("LowHealthMonitor")
	AdlibUnRegister("CombatStuckResync")
	AdlibUnRegister("UseDeadlyParadox")
	AdlibUnRegister("ChestKnockdownGuard")

	RobustResignAndReturnToOutpost($ID_BOREAS_SEABED)
	Return $result
EndFunc

;~ Pongmei chest farm setup
Func SetupPongmeiChestFarm()
	Info('Setting up farm')
	RobustTravelToOutpost($ID_BOREAS_SEABED, $district_name)

	SetupPlayerPongmeiChestFarm()
	SetupTeamPongmeiChestFarm()

	SwitchToHardModeIfEnabled()
	$pongmei_farm_setup = True
	Info('Preparations complete')
	Return $SUCCESS
EndFunc

Func SetupPlayerPongmeiChestFarm()
	Info('Setting up player build skill bar')
	If DllStructGetData(GetMyAgent(), 'Primary') == $ID_DERVISH Then
		LoadSkillTemplate($PONGMEI_CHESTRUNNER_SKILLBAR)
		RandomSleep(250)
	Else
		Warn('Should run this farm as dervish')
	EndIf
EndFunc

Func SetupTeamPongmeiChestFarm()
	If IsTeamAutoSetup() Then Return $SUCCESS

	Info('Setting up team according to default settings')
	If GetPartySize() <> 8 Then
		Warn('Party not set up correctly. Team size different than 8')
	EndIf
EndFunc

;~ Move out of outpost into Pongmei Valley
Func GoToPongmeiValley()
	RobustTravelToOutpost($ID_BOREAS_SEABED, $district_name)
	Local $attempts = 0
	While GetMapID() <> $ID_PONGMEI_VALLEY
		If Not MapEntryAttemptAllowed($attempts, 'Pongmei Valley') Then Return $FAIL
		Info('Moving to Pongmei Valley')
		MoveTo(-25366, 1524)
		MoveTo(-26000, 2400)
		Move(-26200, 2800)
		RandomSleep(1000)
		RobustWaitMapLoading($ID_PONGMEI_VALLEY, 10000, 2000)
	WEnd
	; v30: the map ID switches before the load completes - act only once it is fully loaded
	If Not ConfirmMapReady($ID_PONGMEI_VALLEY) Then Return $FAIL
	Return $SUCCESS
EndFunc

;~ Pongmei Chest farm loop
Func PongmeiChestFarmLoop()
	If GetMapID() <> $ID_PONGMEI_VALLEY Then Return $FAIL
	Info('Starting chest farm run')
	ChestResetRunState()  ; from shared

	Local $openedChests = 0

	Info('Running to Spot #1/13')
	ChestRunToward(22399, 1144)
	ChestRunToward(20126, 1983)
	ChestRunToward(17760, 266)
	ChestRunToward(15405, -2025)
	ChestRunToward(13314, -1374)
	$openedChests += FindAndOpenChests($RANGE_COMPASS, SurviveWhileOpeningChests) ? 1 : 0
	Info('Running to Spot #2/13')
	ChestRunToward(12947, 2289)
	$openedChests += FindAndOpenChests($RANGE_COMPASS, SurviveWhileOpeningChests) ? 1 : 0
	Info('Running to Spot #3/13')
	ChestRunToward(11499, 4242)
	; Am Fah Bridge
	ChestRunToward(11839, 5966)
	$openedChests += FindAndOpenChests($RANGE_COMPASS, SurviveWhileOpeningChests) ? 1 : 0
	Info('Running to Spot #4/13')
	; Am Fah shits
	ChestRunToward(11703, 8854)
	ChestRunToward(8529, 10036)
	$openedChests += FindAndOpenChests($RANGE_COMPASS, SurviveWhileOpeningChests) ? 1 : 0
	Info('Running to Spot #5/13')
	ChestRunToward(5485, 11048)
	ChestRunToward(1597, 7802)
	$openedChests += FindAndOpenChests($RANGE_COMPASS, SurviveWhileOpeningChests) ? 1 : 0
	Info('Running to Spot #6/13')
	ChestRunToward(0, 5850)
	ChestRunToward(-2223, 5916)
	$openedChests += FindAndOpenChests($RANGE_COMPASS, SurviveWhileOpeningChests) ? 1 : 0
	Info('Running to Spot #7/13')
	ChestRunToward(-7113, 4543)
	$openedChests += FindAndOpenChests($RANGE_COMPASS, SurviveWhileOpeningChests) ? 1 : 0
	Info('Running to Spot #8/13')
	ChestRunToward(-9318, 1204)
	$openedChests += FindAndOpenChests($RANGE_COMPASS, SurviveWhileOpeningChests) ? 1 : 0
	Info('Running to Spot #9/13')
	; Echovald side
	ChestRunToward(-12821, 2172)
	$openedChests += FindAndOpenChests($RANGE_COMPASS, SurviveWhileOpeningChests) ? 1 : 0
	Info('Running to Spot #10/13')
	ChestRunToward(-16938, 5153)
	$openedChests += FindAndOpenChests($RANGE_COMPASS, SurviveWhileOpeningChests) ? 1 : 0
	Info('Running to Spot #11/13')
	ChestRunToward(-17706, -1383)
	$openedChests += FindAndOpenChests($RANGE_COMPASS, SurviveWhileOpeningChests) ? 1 : 0
	Info('Running to Spot #12/13')
	ChestRunToward(-16347, -5139)
	$openedChests += FindAndOpenChests($RANGE_COMPASS, SurviveWhileOpeningChests) ? 1 : 0
	Info('Running to Spot #13/13')
	ChestRunToward(-13876, -5626)
	$openedChests += FindAndOpenChests($RANGE_COMPASS, SurviveWhileOpeningChests) ? 1 : 0
	Info('Opened ' & $openedChests & ' chests.')
	Return IsPlayerAlive() ? $SUCCESS : $FAIL
EndFunc

;~ Use defensive skills while opening chests (adapted to shared skills)
Func SurviveWhileOpeningChests()
	; v20: original timing back - Shadow Form whenever it is recharged and a foe is within spellcast + 200, 15 energy
	; minimum (v18 had moved this to the refresh window). Kept from v18: Deadly Paradox first and only with 20 energy;
	; Feigned Neutrality ends when you use a skill, so it is not cast right before DP/SF (that wasted it).
	Local $nearestFoe = GetNearestEnemyToAgent(GetMyAgent())
	If $nearestFoe == Null Then Return
	Local $distance = GetDistance(GetMyAgent(), $nearestFoe)
	Local $sfCast = False
	If $distance < ($RANGE_SPELLCAST + 200) And ChestSkillReady($CHEST_SHADOWFORM) Then
		Local $action = CastShadowFormPair($CHEST_DEADLY_PARADOX, $CHEST_SHADOWFORM, $CHEST_SHADOWFORM_MIN_ENERGY)
		$sfCast = ($action == 'combo' Or $action == 'sf')
	EndIf
	If Not $sfCast And GetEnergy() >= 5 And ChestSkillReady($CHEST_FEIGNED_NEUTRALITY) And $distance < $RANGE_AREA Then
		ChestUseEscapeSkill($CHEST_FEIGNED_NEUTRALITY)
	EndIf
EndFunc

;~ Optional skip Am Fah section
Func ShouldSkipAmFah()
	If MapExists($run_options_cache, 'run.skip_am_fah') And $run_options_cache['run.skip_am_fah'] Then
		Notice('Skipping Am Fah section')
		Return True
	EndIf
	Return False
EndFunc
