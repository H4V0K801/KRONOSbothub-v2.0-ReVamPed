#CS ===========================================================================
#include '../LoadWaitHelpers.au3'
; Hell's Precipice chest run — no hop, enter via mouse click at screen 100,570
#CE ===========================================================================

#include-once
#RequireAdmin
#NoTrayIcon

#include '../../lib/GWA2.au3'
#include '../../lib/GWA2_ID.au3'
#include '../../lib/Utils.au3'
#include '../utilities/OmniFarmer.au3'
#include 'ChestFarmCommon.au3'  ; v18: LowHealthMonitor, skill slot detection, shared SF/SoD/IAU upkeep

Opt('MustDeclareVars', True)

Global Const $MAGMAS_DERVISH_CHESTRUNNER_SKILLBAR = 'OgejwyezHT8I6MHQ3l0kNQ4OIQ'
Global Const $MAGMAS_ASSASSIN_CHESTRUNNER_SKILLBAR = 'OwBj4pf8YQ8I6MHQ3lxlpZ4OIQA'
Global Const $MAGMAS_MESMER_CHESTRUNNER_SKILLBAR = 'OQdTAmP7ZiHRn5A6ukmsBC3BBC'
Global Const $MAGMAS_ELEMENTALIST_CHESTRUNNER_SKILLBAR = 'OgdTw4P7HiHRn5A6ukmsBC3BBC'
Global Const $MAGMAS_MONK_CHESTRUNNER_SKILLBAR = 'OwcTAnP7ZiHRn5A6ukmsBC3BBC'
Global Const $MAGMAS_NECROMANCER_CHESTRUNNER_SKILLBAR = 'OAdT8Z/YYiHRn5A6ukmsBC3BBC'
Global Const $MAGMAS_RITUALIST_CHESTRUNNER_SKILLBAR = 'OAej8xeM5Q8I6MHQ3l0kNQ4OIQ'

Global Const $MAGMAS_CHESTRUN_INFORMATIONS = 'For best results, have :' & @CRLF _
	& '- 12 in Shadow Arts' & @CRLF _
	& '- 16 in Mysticism if playing Dervish' & @CRLF _
	& '- 3 in Deadly Arts' & @CRLF _
	& '- A staff +20e and +20% enchantment duration' & @CRLF _
	& '- caster weapons on all heroes' & @CRLF _
	& '- Windwalker insignias on all the armor pieces' & @CRLF _
	& '- A superior vigor rune'
Global Const $MAGMAS_FARM_DURATION = (3 * 60) * 1000

; v18: slots are read from the live skillbar by skill ID (MagmasDetectSkillSlots); the upstream values below assumed
; SF in slot 5 while the Magmas templates above put it in slot 2 (and IAU in slot 5). 0 = skill not on the bar.
Global $MAGMAS_DEADLY_PARADOX		= 1
Global $MAGMAS_DWARVEN_STABILITY	= 2
Global $MAGMAS_SHROUD_OF_DISTRESS	= 3
Global $MAGMAS_FEIGNED_NEUTRALITY	= 4
Global $MAGMAS_SHADOWFORM			= 5
Global $MAGMAS_DARK_ESCAPE			= 6
Global $MAGMAS_DEATHS_CHARGE		= 7
Global $MAGMAS_HEART_OF_SHADOW		= 8

Global Const $MAGMAS_CHEST_RANGE = 2 * $RANGE_SPELLCAST
; v20: Shadow Form timing back to the original: recast when the game's effect list says less than 5 s of SF is left
; (0 = SF gone). The separate 6.5 s "DP prep" is not restored - DP is cast right before SF (v18, kept).
; The 20 s SoD threshold stays replaced by the v18 Shroud logic (AMG: keep Shroud as it is).
Global Const $MAGMAS_SF_RECAST_MS = 5000
Global Const $MAGMAS_ENERGY_WAIT_MS = 3000
Global Const $MAGMAS_HEAL_HP = 0.35
Global Const $MAGMAS_STUCK_DISTANCE = 40
Global Const $MAGMAS_ARRIVAL_DISTANCE = 150
Global Const $MAGMAS_STUCK_ATTEMPTS_BEFORE_ESCAPE = 2
Global Const $MAGMAS_MAX_STUCK_ATTEMPTS = 20
Global Const $MAGMAS_ENTER_CLICK_X = 100
Global Const $MAGMAS_ENTER_CLICK_Y = 570

Global $MAGMAS_farm_setup = False
Global $MAGMAS_player_profession = $ID_DERVISH


;~ Ordered chest-run waypoints.
;~ $flagX/$flagY: hero-flag point sent ahead of the player via CommandAll(). Pass Null to skip flagging heroes for this leg.
;~ $runX/$runY: point the player walks to and monitors via MagmasChestRun(). Pass Null to skip walking (e.g. heroes are flagged but player stays put).
;~ NOTE: the '-709,-22056' leg below only flags heroes and never walks the player there (no $runX/$runY) - this matches
;~ the original behaviour but looks like it may be a leftover bug. Fill in $runX/$runY here if the player should actually go there.
Func GetMagmasWaypoints()
	Local $waypoints[24]
	$waypoints[0]	= _MagmasLeg('Running',							4901, 658,			5181, 938)
	$waypoints[1]	= _MagmasLeg('1st Bridge',							2561, -343,			2841, -63)
	$waypoints[2]	= _MagmasLeg('Running',							2446, -2454,		2726, -2174)
	$waypoints[3]	= _MagmasLeg('2nd Bridge',							3920, -5904,		4200, -5624)
	$waypoints[4]	= _MagmasLeg('Looking for 1st Chest',				5376, -8155,		5656, -7875)
	$waypoints[5]	= _MagmasLeg('Running',							7445, -8768,		7445, -8768)
	$waypoints[6]	= _MagmasLeg('3rd Bridge/Looking for 2nd Chest',	8954, -9364,		8954, -9364)
	$waypoints[7]	= _MagmasLeg('Running',							Null, Null,			9299, -10219)
	$waypoints[8]	= _MagmasLeg('Running',							Null, Null,			9000, -12166)
	$waypoints[9]	= _MagmasLeg('Looking for 3rd Chest',				Null, Null,			10334, -12661)
	$waypoints[10]	= _MagmasLeg('Running',							Null, Null,			9691, -18281)
	$waypoints[11]	= _MagmasLeg('Looking for 4th Chest',				Null, Null,			8198, -22389)
	$waypoints[12]	= _MagmasLeg('Running',							Null, Null,			7010, -20345)
	$waypoints[13]	= _MagmasLeg('Running',							Null, Null,			4982, -21057)
	$waypoints[14]	= _MagmasLeg('Looking for 5th Chest',				Null, Null,			4876, -19325)
	$waypoints[15]	= _MagmasLeg('Running',							Null, Null,			1040, -18222)
	$waypoints[16]	= _MagmasLeg('Running',							Null, Null,			-373, -18587)
	$waypoints[17]	= _MagmasLeg('4th Bridge',							Null, Null,			-767, -20580)
	$waypoints[18]	= _MagmasLeg('Running',							-709, -22056,		Null, Null)		; see NOTE above
	$waypoints[19]	= _MagmasLeg('Running',							Null, Null,			-3863, -22145)
	$waypoints[20]	= _MagmasLeg('Looking for 6th Chest',				Null, Null,			-4300, -17750)
	$waypoints[21]	= _MagmasLeg('Looking for 7th Chest',				Null, Null,			-5400, -17000)
	$waypoints[22]	= _MagmasLeg('Looking for 8th Chest',				Null, Null,			-9050, -16850)
	$waypoints[23]	= _MagmasLeg('Looking for 9th Chest',				Null, Null,			-8553, -19607)
	Return $waypoints
EndFunc

;~ Build one waypoint entry. Pass Null for $flagX/$flagY or $runX/$runY to skip that step.
Func _MagmasLeg($label, $flagX, $flagY, $runX, $runY)
	Local $leg[]
	$leg['label'] = $label
	$leg['flagX'] = $flagX
	$leg['flagY'] = $flagY
	$leg['runX'] = $runX
	$leg['runY'] = $runY
	Return $leg
EndFunc


Func MagmasChestFarm()
	If Not $MAGMAS_farm_setup And SetupMagmasChestFarm() == $FAIL Then Return $PAUSE

	MagmasDetectSkillSlots()
	AdlibRegister("LowHealthMonitor", $LOW_HEALTH_CHECK_INTERVAL)
	AdlibRegister("ChestKnockdownGuard", $CHEST_KNOCKDOWN_GUARD_INTERVAL)

	Local $result = MagmasChestFarmLoop()

	AdlibUnRegister("LowHealthMonitor")
	AdlibUnRegister("ChestKnockdownGuard")
	AdlibUnRegister("UsingDeadlyParadox")

	MagmasReturnToOutpost()
	Return $result
EndFunc

Func SetupMagmasChestFarm()
	Info('Setting up farm')

	If SetupTeamMagmasChestFarm() == $FAIL Then Return $FAIL

	SwitchToHardModeIfEnabled()
	RandomSleep(1500)

	$MAGMAS_farm_setup = True
	Info('Preparations complete')
	Return $SUCCESS
EndFunc


Func SetupTeamMagmasChestFarm()
	If IsTeamAutoSetup() Then Return True

	Info('Setting up team according to default settings')
	RandomSleep(500)
	If GetPartySize() <> 8 Then
		Warn('Could not set up party correctly. Team size different than 8')
		Return $FAIL
	EndIf
	Return $SUCCESS
EndFunc

Func MagmasChestFarmLoop()

	Info('Starting chest run')
	ResetShadowFormState()
	PrepareZephyrSpirit()
	RegisterBurstHealingUnit()

	RobustTravelToOutpost($ID_ABADDONS_MOUTH, $district_name)
	Sleep(3000)
	RobustTravelToOutpost($ID_HELLS_PRECIPICE, $district_name)
	Sleep(3000)
	EnterChallenge()
	Sleep(3000)
	; v30: do not drink/cast/flag before the explorable has fully loaded
	If MagmasWaitForMapType($ID_EXPLORABLE, 30000, 1000) == $FAIL Then
		UnregisterBurstHealingUnit()
		Return $FAIL
	EndIf

	Local $openedChests = 0

	UseConsumable($ID_BIRTHDAY_CUPCAKE, True)
	RandomAlcohol()
	UseConsumable($ID_CANDY_APPLE, True)

	MagmasDefendFunction(0, 0, True)

	For $leg In GetMagmasWaypoints()
		If $leg['flagX'] <> Null Then CommandAll($leg['flagX'], $leg['flagY'])
		If $leg['runX'] <> Null Then
			If MagmasChestRun($leg['runX'], $leg['runY']) == $FAIL Then Return $FAIL
		EndIf
		Info($leg['label'])
		$openedChests += FindAndOpenChests($MAGMAS_CHEST_RANGE, MagmasDefendFunctionForChests, UnblockToOpenChest) ? 1 : 0
	Next

	UnregisterBurstHealingUnit()
	Info('Opened ' & $openedChests & ' chests.')
	Return ($openedChests > 0) Or IsPlayerAlive() ? $SUCCESS : $FAIL
EndFunc

; v30: central load guard (WaitMapReady: instance type, player agent/position, agents, party, stable samples) + settle
Func MagmasWaitForMapType($wantedType, $deadlockTime = 20000, $settleTime = 2500)
	If Not WaitMapReady(-1, $wantedType, $deadlockTime, -1) Then
		Warn('Timed out waiting for map type ' & $wantedType & ' (current ' & GetMapType() & ', id ' & GetMapID() & ': ' & $map_ready_last_reason & ')')
		Return $FAIL
	EndIf
	RandomSleep($settleTime)
	If GetMapType() <> $wantedType Then Return $FAIL
	Return $SUCCESS
EndFunc

Func MagmasResetSetup()
	$MAGMAS_farm_setup = False
EndFunc

Func MagmasReturnToOutpost()
	If GetMapID() == $ID_HELLS_PRECIPICE And GetMapType() == $ID_OUTPOST Then Return $SUCCESS

	Info('Returning to Hell''s Precipice outpost')
	If GetMapType() == $ID_EXPLORABLE Then
		Resign()
		Sleep(3500)
		ReturnToOutpost()
	Else
		If RobustTravelToOutpost($ID_HELLS_PRECIPICE, $district_name) == $FAIL Then Return $FAIL
	EndIf

	If MagmasWaitForMapType($ID_OUTPOST, 25000, 2000) == $FAIL Then Return $FAIL
	If GetMapID() <> $ID_HELLS_PRECIPICE Then Return $FAIL
	Return $SUCCESS
EndFunc


Func MagmasChestRun($X, $Y)
	If IsPlayerDead() Then Return $FAIL
	Move($X, $Y)
	Local $blockedCounter = 0
	Local $me = GetMyAgent()
	Local $lastX = DllStructGetData($me, 'X')
	Local $lastY = DllStructGetData($me, 'Y')
	While GetDistanceToPoint($me, $X, $Y) > $MAGMAS_ARRIVAL_DISTANCE And $blockedCounter < $MAGMAS_MAX_STUCK_ATTEMPTS
		MagmasDefendFunction($X, $Y)
		$me = GetMyAgent()

		If GetDistanceToPoint($me, $lastX, $lastY) < $MAGMAS_STUCK_DISTANCE Then
			$blockedCounter += 1
			Move($X, $Y)
		Else
			$blockedCounter = 0
			$lastX = DllStructGetData($me, 'X')
			$lastY = DllStructGetData($me, 'Y')
		EndIf

		If $blockedCounter > $MAGMAS_STUCK_ATTEMPTS_BEFORE_ESCAPE And GetEnergy() >= 5 Then
			Local $target = EscapeWithDeathsCharge($X, $Y)
			If $target <> Null And _MagmasTryUseSkill($MAGMAS_DEATHS_CHARGE, 5, $target) Then
				$blockedCounter = 0
				$me = GetMyAgent()
				$lastX = DllStructGetData($me, 'X')
				$lastY = DllStructGetData($me, 'Y')
			ElseIf ChestSkillReady($MAGMAS_HEART_OF_SHADOW) Then
				Local $npc = GetNPCInTheBack($X, $Y)
				If $npc == Null Then $npc = $me
				UseSkillEx($MAGMAS_HEART_OF_SHADOW, $npc)
				$blockedCounter = 0
				$me = GetMyAgent()
				$lastX = DllStructGetData($me, 'X')
				$lastY = DllStructGetData($me, 'Y')
			EndIf
		EndIf

		RandomSleep(150)
		$me = GetMyAgent()
		If IsPlayerDead() Then Return $FAIL
	WEnd
	Return $SUCCESS
EndFunc

Func EscapeWithDeathsCharge($X, $Y)
	Local $me = GetMyAgent()
	Local $playerDistToGoal = GetDistanceToPoint($me, $X, $Y)
	Local $targetDistance = 999999
	Local $target = Null
	Local $foes = GetFoesInRangeOfAgent($me, $RANGE_SPELLCAST)
	If Not IsArray($foes) Or UBound($foes) <= 0 Then Return Null
	For $foe In $foes
		Local $distToGoal = GetDistanceToPoint($foe, $X, $Y)
		If $distToGoal < $playerDistToGoal - 100 And $distToGoal < $targetDistance Then
			$target = $foe
			$targetDistance = $distToGoal
		EndIf
	Next
	Return $target
EndFunc

Func UnblockToOpenChest()
	Local $me = GetMyAgent()
	If ChestSkillReady($MAGMAS_HEART_OF_SHADOW) Then
		Local $target = GetNearestEnemyToAgent($me)
		If $target == Null Then $target = $me
		UseSkillEx($MAGMAS_HEART_OF_SHADOW, $target)
	ElseIf ChestSkillReady($MAGMAS_DEATHS_CHARGE) Then
		Local $target = GetFurthestNPCInRangeOfCoords($ID_ALLEGIANCE_FOE, Null, Null, $RANGE_SPELLCAST)
		If $target <> Null Then UseSkillEx($MAGMAS_DEATHS_CHARGE, $target)
	EndIf
EndFunc

Func MagmasDefendFunctionForChests()
	Return MagmasDefendFunction(0, 0)
EndFunc

;~ Attempt to use a skill if it's recharged and there's enough energy for it. Returns True if the skill was used.
Func _MagmasTryUseSkill($skillID, $energyCost, $target = Null)
	If $skillID > 0 And GetEnergy() >= $energyCost And IsRecharged($skillID) Then
		UseSkillEx($skillID, $target)
		Return True
	EndIf
	Return False
EndFunc


;~ True if any foe in spellcast range is closer to ($X,$Y) than the player (i.e. ahead on the path)
Func AreFoesInFront($X, $Y)
	Local $me = GetMyAgent()
	Local $playerDist = GetDistanceToPoint($me, $X, $Y)
	Local $foes = GetFoesInRangeOfAgent($me, $RANGE_SPELLCAST)
	If Not IsArray($foes) Or UBound($foes) < 1 Then Return False
	For $foe In $foes
		If GetDistanceToPoint($foe, $X, $Y) < $playerDist Then Return True
	Next
	Return False
EndFunc

Func MagmasDefendFunction($X, $Y, $force = False)
	Local $me = GetMyAgent()
	Local $target = GetNearestEnemyToAgent($me)
	Local $enemiesAreNear = ($target <> Null And GetDistance($me, $target) < $RANGE_SPELLCAST)
	Local $needSf = ($force Or $enemiesAreNear Or ($X <> 0 And AreFoesInFront($X, $Y)))
	Local $hp = DllStructGetData($me, 'HealthPercent')
	Local $sfCast = False

	If $hp > 0 And $hp <= $MAGMAS_HEAL_HP Then
		_MagmasTryUseSkill($MAGMAS_FEIGNED_NEUTRALITY, 5)
	EndIf

	; v20: original WHEN restored - SF effect (game timer) under 5 s or gone, foes near / in front, SF recharged; the old
	; "wait for 20 energy while foes are near" loop, bounded to 3 s (v18: it had no time limit). Kept from v18: Deadly
	; Paradox right before SF and only with 20 energy (and only if DP is not still active, as originally).
	Local $sfRemaining = GetEffectTimeRemaining($ID_SHADOW_FORM)
	If $needSf And $sfRemaining < $MAGMAS_SF_RECAST_MS Then
		If GetEnergy() < $SF_COMBO_MIN_ENERGY And ($force Or $enemiesAreNear) Then
			Local $waitTimer = TimerInit()
			While IsPlayerAlive() And GetEnergy() < $SF_COMBO_MIN_ENERGY And ($force Or $enemiesAreNear) And TimerDiff($waitTimer) < $MAGMAS_ENERGY_WAIT_MS
				Sleep(100)
				$target = GetNearestEnemyToAgent($me)
				$enemiesAreNear = ($target <> Null And GetDistance($me, $target) < $RANGE_SPELLCAST)
			WEnd
		EndIf
		If IsPlayerAlive() And ChestSkillReady($MAGMAS_SHADOWFORM) Then
			Local $dpSlot = (GetEffectTimeRemaining($ID_DEADLY_PARADOX) < 1000) ? $MAGMAS_DEADLY_PARADOX : 0
			Local $action = CastShadowFormPair($dpSlot, $MAGMAS_SHADOWFORM, $SF_ENERGY_COST)
			$sfCast = ($action == 'combo' Or $action == 'sf')
		EndIf
		If $sfCast Then
			_MagmasTryUseSkill($MAGMAS_DWARVEN_STABILITY, 5)
			_MagmasTryUseSkill($MAGMAS_DARK_ESCAPE, 5)
		EndIf
	EndIf

	MaintainShroudOfDistress($MAGMAS_SHROUD_OF_DISTRESS, $MAGMAS_SHADOWFORM)
	Return $sfCast
EndFunc

;~ v18: read the slots from the live skillbar (shared detection), also used by LowHealthMonitor's $CHEST_* slots
Func MagmasDetectSkillSlots()
	If Not ChestDetectSkillSlots() Then Return False
	$MAGMAS_DEADLY_PARADOX = $CHEST_DEADLY_PARADOX
	$MAGMAS_DWARVEN_STABILITY = $CHEST_DWARVEN_STABILITY
	$MAGMAS_SHROUD_OF_DISTRESS = $CHEST_SHROUD_OF_DISTRESS
	$MAGMAS_FEIGNED_NEUTRALITY = $CHEST_FEIGNED_NEUTRALITY
	$MAGMAS_SHADOWFORM = $CHEST_SHADOWFORM
	$MAGMAS_DARK_ESCAPE = $CHEST_DARK_ESCAPE
	$MAGMAS_DEATHS_CHARGE = $CHEST_DEATHS_CHARGE
	$MAGMAS_HEART_OF_SHADOW = $CHEST_HEART_OF_SHADOW
	Return True
EndFunc

;~ Kept for compatibility; v18 casts DP directly before SF
Func UsingDeadlyParadox()
	AdlibUnRegister('UsingDeadlyParadox')
EndFunc
