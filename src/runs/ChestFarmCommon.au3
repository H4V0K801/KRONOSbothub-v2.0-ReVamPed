#CS ===========================================================================
#include '../LoadWaitHelpers.au3'
; Shared chest farm movement, defend, stuck, and escape logic
; Used by Tasca.au3 and Pongmei.au3 (and potentially others)
; Author: caustic-kronos / adapted
#CE ===========================================================================

#include-once
#include '../../lib/GWA2.au3'
#include '../../lib/Utils-Agents.au3'
#include '../../lib/Utils.au3'


; Skill slots. v18: no longer constants - ChestDetectSkillSlots() reads them from the live skillbar by skill ID at the start
; of every run (0 = skill not on the bar, it is then skipped). The values below are the upstream layout and are only kept
; when the skillbar cannot be read. Upstream assumed SF in slot 5, but the shipped Pongmei/Tasca/Magmas templates
; (OgejwyezHT8I6MHQ3l0kNQ4OIQ ...) put SF in slot 2, Dwarven Stability in 4 and IAU in 5, so Pongmei (which loads its
; template) cast IAU when it meant Shadow Form.
Global $CHEST_DEADLY_PARADOX		= 1
Global $CHEST_DWARVEN_STABILITY		= 2
Global $CHEST_SHROUD_OF_DISTRESS	= 3
Global $CHEST_FEIGNED_NEUTRALITY	= 4
Global $CHEST_SHADOWFORM			= 5
Global $CHEST_DARK_ESCAPE			= 6
Global $CHEST_DEATHS_CHARGE			= 7
Global $CHEST_HEART_OF_SHADOW		= 8
Global $CHEST_I_AM_UNSTOPPABLE		= 0
Global Const $CHEST_KNOCKDOWN_GUARD_INTERVAL = 200

; Timers and thresholds
; v20: Shadow Form timing back to the pre-v18 values (AMG, after testing v18/v19): recast once 19.5 s have passed since
; our last Shadow Form and SF is recharged; wait up to 3 s for 20 energy with foes near; SF alone needs the old 15.
; Kept from v18: DP first then SF with no gap, DP only with 20 energy, slots read from the bar.
; The 62 s Shroud timer stays replaced by the v18 Shroud logic (AMG: keep Shroud as it is).
Global Const $CHEST_SHADOWFORM_RECAST = 19500
Global Const $CHEST_SHADOWFORM_MIN_ENERGY = 15
Global Const $CHEST_SHADOWFORM_ENERGY_WAIT = 3000
Global Const $CHEST_DWARVEN_STABILITY_COST = 5
Global Const $CHEST_DARK_ESCAPE_COST = 5
Global Const $CHEST_STUCK_DISTANCE = 40
Global Const $LOW_HEALTH_THRESHOLD = 0.45
Global Const $LOW_HEALTH_CHECK_INTERVAL = 75
Global Const $STUCK_REFIRE_INTERVAL = 1500
; v17: the '/stuck' resync itself is unchanged (upstream: at most every 1.5 s while taking damage); only its log line is
; throttled to one Notice per 30 s with a count (each send is still logged at Debug level)
Global Const $STUCK_LOG_INTERVAL = 30000

; Shared run state (set by the calling farm)
Global $chest_timer_shadowform = Null
Global $chest_timer_shroud = Null
Global $chest_goal_x = Null
Global $chest_goal_y = Null
Global $chest_skill_busy = False

Global $g_hStuckDamageTimer = 0
Global $g_fLastHealthPct = 1.0
Global $g_hStuckLogTimer = 0
Global $g_iStuckSentSinceLog = 0

;~ Low Health Monitor
Func LowHealthMonitor()
	If $chest_skill_busy Then Return
	If Not IsLowHealth() Then Return
	If Not IsPlayerAlive() Then Return

	Local $myEnergy = GetEnergy()
	If $myEnergy < 5 Then Return

	If $chest_goal_x <> Null Then
		If ChestSkillReady($CHEST_DEATHS_CHARGE) Then
			Local $chargeTarget = GetTargetToEscapeWithDeathsCharge($chest_goal_x, $chest_goal_y)
			If IsDllStruct($chargeTarget) Then
				Notice('Low health - Death''s Charge')
				ChestUseEscapeSkill($CHEST_DEATHS_CHARGE, $chargeTarget)
				Return
			EndIf
		EndIf
		If ChestSkillReady($CHEST_HEART_OF_SHADOW) Then
			Local $shadowTarget = GetHeartOfShadowTarget($chest_goal_x, $chest_goal_y)
			If IsDllStruct($shadowTarget) Then
				Notice('Low health - Heart of Shadow')
				ChestUseEscapeSkill($CHEST_HEART_OF_SHADOW, $shadowTarget)
				Return
			EndIf
		EndIf
	EndIf

	If ChestSkillReady($CHEST_FEIGNED_NEUTRALITY) Then
		Notice('Low health - Feigned Neutrality')
		ChestUseEscapeSkill($CHEST_FEIGNED_NEUTRALITY)
		Return
	EndIf
EndFunc

Local $stuckCounter = 0
Func CombatStuckResync()
	If Not IsPlayerAlive() Then Return

	Local $currentHealth = GetHealth()

	If $currentHealth < $g_fLastHealthPct Then
		If $g_hStuckDamageTimer == 0 Or TimerDiff($g_hStuckDamageTimer) >= $STUCK_REFIRE_INTERVAL Then
			SendChat('/stuck')
			$g_hStuckDamageTimer = TimerInit()
			LogStuckResync()
		EndIf
	Else
		If $g_hStuckDamageTimer <> 0 And TimerDiff($g_hStuckDamageTimer) >= $STUCK_REFIRE_INTERVAL Then
			$g_hStuckDamageTimer = 0
		EndIf
	EndIf

	$g_fLastHealthPct = $currentHealth
EndFunc

;~ Log the damage '/stuck' resync: first one at Notice, then at most one Notice per $STUCK_LOG_INTERVAL with the count
Func LogStuckResync()
	$g_iStuckSentSinceLog += 1
	Debug('Taking damage - /stuck sent')
	If $g_hStuckLogTimer <> 0 And TimerDiff($g_hStuckLogTimer) < $STUCK_LOG_INTERVAL Then Return
	If $g_hStuckLogTimer == 0 Then
		Notice('Taking damage - resynching position with /stuck')
	Else
		Notice('Taking damage - resynching position with /stuck (' & $g_iStuckSentSinceLog & 'x in the last ' & Round(TimerDiff($g_hStuckLogTimer) / 1000) & 's)')
	EndIf
	$g_iStuckSentSinceLog = 0
	$g_hStuckLogTimer = TimerInit()
EndFunc

Func IsLowHealth()
	Local $me = GetMyAgent()
	Local $healthRatio = DllStructGetData($me, 'HealthPercent')
	If $healthRatio > 0 And $healthRatio < $LOW_HEALTH_THRESHOLD Then Return True
	Return False
EndFunc

;~ Generic chest run movement with stuck detection, skill unblock, and U-path fallback
Func ChestRunToward($X, $Y)
	; v17: the upstream low-lockpicks warning was removed (user request). It was also wrong: FindInInventory()
	; returns [bag, slot] of a lockpick stack, so N was the bag number (< 5 = almost always), not the lockpick count.
	; Chests are still skipped at 0 lockpicks by FindAndOpenChests / TascaOpenChestsAtWaypoint (upstream logic).
	If IsPlayerDead() Then Return $FAIL
	$chest_goal_x = $X
	$chest_goal_y = $Y
	Move($X, $Y)
	Local $blockedCounter = 0
	Local $me = GetMyAgent()
	Local $lastX = DllStructGetData($me, 'X')
	Local $lastY = DllStructGetData($me, 'Y')
	While GetDistanceToPoint($me, $X, $Y) > 150 And $blockedCounter < 20
		If $blockedCounter > 12 Then
			Notice('Blocked too long - skipping waypoint')
			Return $FAIL
		EndIf
		If ChestDefendFunction($X, $Y) Then
			Move($X, $Y)
			$me = GetMyAgent()
			$lastX = DllStructGetData($me, 'X')
			$lastY = DllStructGetData($me, 'Y')
			$blockedCounter = 0
		EndIf
		$me = GetMyAgent()

		If GetDistanceToPoint($me, $lastX, $lastY) < $CHEST_STUCK_DISTANCE Then
			$blockedCounter += 1
			Move($X, $Y)
		Else
			$blockedCounter = 0
			$lastX = DllStructGetData($me, 'X')
			$lastY = DllStructGetData($me, 'Y')
		EndIf

		If $blockedCounter > 2 And ChestUnblockTowards($X, $Y) Then
			$blockedCounter = 0
			Move($X, $Y)
			$me = GetMyAgent()
			$lastX = DllStructGetData($me, 'X')
			$lastY = DllStructGetData($me, 'Y')
		EndIf

		; U-path fallback when skills can't unstuck
		If $blockedCounter > 6 And Not ChestUnblockTowards($X, $Y) Then
			Notice('Skills failed to unstuck - attempting small U-path')
			ChestUPathAround($X, $Y)
			$blockedCounter = 0
			Move($X, $Y)
			$me = GetMyAgent()
			$lastX = DllStructGetData($me, 'X')
			$lastY = DllStructGetData($me, 'Y')
		EndIf

		RandomSleep(200)
		$me = GetMyAgent()
		If IsPlayerDead() Then Return $FAIL
	WEnd
	Return $SUCCESS
EndFunc

;~ Small U-pathing
Func ChestUPathAround($goalX, $goalY)
	Local $me = GetMyAgent()
	Local $myX = DllStructGetData($me, 'X')
	Local $myY = DllStructGetData($me, 'Y')
	Local $dx = $goalX - $myX
	Local $dy = $goalY - $myY
	Local $dist = Sqrt($dx * $dx + $dy * $dy)
	If $dist < 100 Then Return

	$dx /= $dist
	$dy /= $dist

	; Step back ~200 units
	Local $backDist = 200
	Local $backX = $myX - $dx * $backDist
	Local $backY = $myY - $dy * $backDist
	Move($backX, $backY)
	Sleep(600)

	; Perpendicular offset (alternate sides)
	Static $side = 1
	$side = -$side
	Local $perpDist = 160
	Local $perpX = -$dy * $perpDist * $side
	Local $perpY = $dx * $perpDist * $side
	Local $sideX = $backX + $perpX
	Local $sideY = $backY + $perpY
	Move($sideX, $sideY)
	Sleep(500)

	Move($goalX, $goalY)
EndFunc

Func GetTargetToEscapeWithDeathsCharge($X, $Y)
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

Func GetHeartOfShadowTarget($X, $Y)
	Local $me = GetMyAgent()
	Local $playerDistToGoal = GetDistanceToPoint($me, $X, $Y)
	Local $best = Null
	Local $bestDistance = 999999
	Local $foes = GetFoesInRangeOfAgent($me, $RANGE_SPELLCAST)
	If IsArray($foes) And UBound($foes) > 0 Then
		For $foe In $foes
			If GetDistanceToPoint($foe, $X, $Y) > $playerDistToGoal + 100 Then
				Local $distance = GetDistance($me, $foe)
				If $distance < $bestDistance Then
					$best = $foe
					$bestDistance = $distance
				EndIf
			EndIf
		Next
	EndIf
	If IsDllStruct($best) Then Return $best
	Local $npc = GetNPCInTheBack($X, $Y)
	If IsDllStruct($npc) Then Return $npc
	Return Null
EndFunc

Func ChestUnblockTowards($X, $Y)
	If $X == Null Or $Y == Null Then Return False
	If GetEnergy() < 5 Then Return False
	If ChestSkillReady($CHEST_DEATHS_CHARGE) Then
		Local $chargeTarget = GetTargetToEscapeWithDeathsCharge($X, $Y)
		If IsDllStruct($chargeTarget) Then
			ChestUseEscapeSkill($CHEST_DEATHS_CHARGE, $chargeTarget)
			Return True
		EndIf
	EndIf
	If ChestSkillReady($CHEST_HEART_OF_SHADOW) Then
		Local $shadowTarget = GetHeartOfShadowTarget($X, $Y)
		If IsDllStruct($shadowTarget) Then
			ChestUseEscapeSkill($CHEST_HEART_OF_SHADOW, $shadowTarget)
			Return True
		EndIf
	EndIf
	Return False
EndFunc

Func ChestUseEscapeSkill($skillSlot, $target = Null)
	Local $wasBusy = $chest_skill_busy
	$chest_skill_busy = True
	UseSkillEx($skillSlot, $target)
	$chest_skill_busy = $wasBusy
EndFunc

Func ChestDefendFunction($X, $Y)
	Local $recast = ChestMaintainShadowForm()
	; Shadow Form first: Shroud is only cast if it leaves the 20 energy a due SF refresh needs
	ChestMaintainShroud()
	Return $recast
EndFunc

;~ True if the skill is on the bar and recharged
Func ChestSkillReady($slot)
	Return $slot > 0 And IsRecharged($slot)
EndFunc

;~ v18: read the chest build's slots from the live skillbar by skill ID (any order, missing skills = 0)
Func ChestDetectSkillSlots()
	Local $ids[9] = [0, $ID_DEADLY_PARADOX, $ID_SHADOW_FORM, $ID_SHROUD_OF_DISTRESS, $ID_DWARVEN_STABILITY, _
		$ID_FEIGNED_NEUTRALITY, $ID_DARK_ESCAPE, $ID_DEATHS_CHARGE, $ID_HEART_OF_SHADOW]
	Local $found[9], $any = False
	For $i = 1 To 8
		$found[$i] = FindSkillSlot($ids[$i])
		If $found[$i] > 0 Then $any = True
	Next
	Local $iau = FindSkillSlot($ID_I_AM_UNSTOPPABLE)
	If Not $any And $iau == 0 Then
		Warn('Could not read the skillbar - keeping the default chest skill slots')
		Return False
	EndIf
	$CHEST_DEADLY_PARADOX = $found[1]
	$CHEST_SHADOWFORM = $found[2]
	$CHEST_SHROUD_OF_DISTRESS = $found[3]
	$CHEST_DWARVEN_STABILITY = $found[4]
	$CHEST_FEIGNED_NEUTRALITY = $found[5]
	$CHEST_DARK_ESCAPE = $found[6]
	$CHEST_DEATHS_CHARGE = $found[7]
	$CHEST_HEART_OF_SHADOW = $found[8]
	$CHEST_I_AM_UNSTOPPABLE = $iau
	Info('Skill slots: DP ' & $CHEST_DEADLY_PARADOX & ', SF ' & $CHEST_SHADOWFORM & ', SoD ' & $CHEST_SHROUD_OF_DISTRESS & _
		', DwSt ' & $CHEST_DWARVEN_STABILITY & ', IAU ' & $CHEST_I_AM_UNSTOPPABLE & ', FN ' & $CHEST_FEIGNED_NEUTRALITY & _
		', DE ' & $CHEST_DARK_ESCAPE & ', DC ' & $CHEST_DEATHS_CHARGE & ', HoS ' & $CHEST_HEART_OF_SHADOW & ' (0 = not on bar)')
	If $CHEST_SHADOWFORM == 0 Then Warn('Shadow Form is not on the skillbar')
	Return True
EndFunc

;~ Shadow Form upkeep. v20: WHEN = pre-v18 timing (19.5 s after our last SF, SF recharged, bounded 3 s wait for 20 energy
;~ with foes near, nothing under 15). HOW = v18: Deadly Paradox first, Shadow Form right after it, DP only with 20 energy.
;~ Returns True if Shadow Form was cast.
Func ChestMaintainShadowForm()
	If $chest_timer_shadowform <> Null And TimerDiff($chest_timer_shadowform) < $CHEST_SHADOWFORM_RECAST Then Return False
	If $CHEST_SHADOWFORM < 1 Or Not IsPlayerAlive() Then Return False
	If Not IsRecharged($CHEST_SHADOWFORM) Then Return False

	Local $me = GetMyAgent()
	If GetEnergy() < $SF_COMBO_MIN_ENERGY Then
		Local $nearest = GetNearestEnemyToAgent($me)
		If $nearest <> Null And GetDistance($me, $nearest) < $RANGE_SPELLCAST Then
			Local $waitTimer = TimerInit()
			While IsPlayerAlive() And GetEnergy() < $SF_COMBO_MIN_ENERGY And TimerDiff($waitTimer) < $CHEST_SHADOWFORM_ENERGY_WAIT
				Sleep(250)
			WEnd
		EndIf
		If GetEnergy() < $CHEST_SHADOWFORM_MIN_ENERGY Then Return False
	EndIf

	$chest_skill_busy = True
	Local $action = CastShadowFormPair($CHEST_DEADLY_PARADOX, $CHEST_SHADOWFORM, $CHEST_SHADOWFORM_MIN_ENERGY)
	Local $cast = ($action == 'combo' Or $action == 'sf')
	If $cast Then
		$chest_timer_shadowform = TimerInit()
		; No sleep: UseSkillEx already waited for SF's activation
		If GetEnergy() >= $CHEST_DWARVEN_STABILITY_COST And ChestSkillReady($CHEST_DWARVEN_STABILITY) Then UseSkillEx($CHEST_DWARVEN_STABILITY)
		If GetEnergy() >= $CHEST_DARK_ESCAPE_COST And ChestSkillReady($CHEST_DARK_ESCAPE) Then UseSkillEx($CHEST_DARK_ESCAPE)
	EndIf
	$chest_skill_busy = False
	Return $cast
EndFunc

;~ v18: Shroud of Distress upkeep (refresh window), never starving a due Shadow Form refresh - unchanged in v20
Func ChestMaintainShroud()
	If $CHEST_SHROUD_OF_DISTRESS < 1 Then Return False
	Local $wasBusy = $chest_skill_busy
	$chest_skill_busy = True
	Local $cast = MaintainShroudOfDistress($CHEST_SHROUD_OF_DISTRESS, $CHEST_SHADOWFORM)
	$chest_skill_busy = $wasBusy
	Return $cast
EndFunc

;~ v18: Adlib - pre-emptive "I Am Unstoppable!" when a foe in range starts Giant Stomp (2 s before it lands),
;~ Agnar's Rage, or (v20) Wild Blow / Bull's Strike, (v21) Irresistible Blow
Func ChestKnockdownGuard()
	If $CHEST_I_AM_UNSTOPPABLE < 1 Then Return
	TryPreemptiveIAU($CHEST_I_AM_UNSTOPPABLE)
EndFunc

;~ Kept for compatibility (farms still unregister it); v18 casts DP directly before SF instead of 750 ms after it
Func UseDeadlyParadox()
	AdlibUnRegister('UseDeadlyParadox')
EndFunc

Func GetNPCInTheBack($X, $Y)
	Local $me = GetMyAgent()
	Local $myX = DllStructGetData($me, 'X')
	Local $myY = DllStructGetData($me, 'Y')
	Local $npcs = GetNPCsInRangeOfAgent($me, Null, $RANGE_SPELLCAST)
	Local $bestNpc = Null
	Local $minDot = 1

	Local $moveX = $X - $myX
	Local $moveY = $Y - $myY
	Local $myMovementVector = Sqrt($moveX ^ 2 + $moveY ^ 2)
	If $myMovementVector = 0 Then Return Null
	$moveX /= $myMovementVector
	$moveY /= $myMovementVector

	For $npc In $npcs
		Local $npcMoveX = DllStructGetData($npc, 'X') - $myX
		Local $npcMoveY = DllStructGetData($npc, 'Y') - $myY
		Local $npcMovementVector = Sqrt($npcMoveX ^ 2 + $npcMoveY ^ 2)
		If $npcMovementVector = 0 Then ContinueLoop
		$npcMoveX /= $npcMovementVector
		$npcMoveY /= $npcMovementVector

		Local $dot = $npcMoveX * $moveX + $npcMoveY * $moveY
		If $dot < $minDot Then
			$minDot = $dot
			$bestNpc = $npc
		EndIf
	Next
	Return $bestNpc
EndFunc

; Reset shared state between runs
Func ChestResetRunState()
	$chest_timer_shadowform = Null
	$chest_timer_shroud = Null
	ResetShadowFormState()
	ChestDetectSkillSlots()
	$chest_goal_x = Null
	$chest_goal_y = Null
	$chest_skill_busy = False
EndFunc

;~ Combined recovery sequence for stubborn blocks
Func ChestRecoverySequence($goalX, $goalY)
	Notice('Running recovery sequence')
	SendChat('/stuck')
	Sleep(300)
	Move($goalX, $goalY)
EndFunc
