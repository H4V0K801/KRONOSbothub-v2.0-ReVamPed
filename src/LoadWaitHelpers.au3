#include-once
#include '../lib/BotsHub-Constants.au3'
#include '../lib/GWA2.au3'
#include '../lib/Utils.au3'

; Robust wrappers that only add retry and timing safety.
; They do not alter how GWA2 issues packets or reads memory.


;~ Wait for a map load with retries. If the load never completes while in an explorable area, resign so the
;~ next run restarts from a clean state.
;~ $mapID = -1 means "the map ID does not change" (e.g. Slaver's Exile -> Justicar, Urgoz outpost -> explorable):
;~ plain WaitMapLoading(-1) returns immediately while the OLD instance is still loaded, so for -1 we first wait
;~ for a new instance to start (see WaitForNewInstance).
Func RobustWaitMapLoading($mapID = -1, $deadlockTime = 20000, $waitingTime = 2000, $retries = 3)
	Local $result = False
	For $i = 1 To $retries
		If $mapID == -1 And Not WaitForNewInstance() Then
			Sleep(Random(600, 1000, 1))
			ContinueLoop
		EndIf
		If WaitMapLoading($mapID, $deadlockTime, $waitingTime) Then
			$result = True
			ExitLoop
		EndIf
		Sleep(Random(600, 1000, 1))
	Next
	If Not $result Then
		Warn('Map load wait failed' & ($mapID == -1 ? '' : ' (expected map ' & $mapID & ', current ' & GetMapID() & ')'))
		If GetMapType() <> $ID_OUTPOST Then
			Notice('Map load timeout - forcing resign')
			Resign()
			Sleep(2000)
		EndIf
	EndIf
	Return $result
EndFunc


;~ Wait until a NEW instance has started loading (or has just loaded), bounded by $timeout.
;~ Detection: player agent disappears (loading screen) or the instance up-time counter restarts.
;~ An instance younger than $NEW_INSTANCE_FRESH_MS at call time counts as already new, so callers that sleep
;~ before waiting cannot miss a fast load. If the up-time offset ever stops working (reads 0) this degrades to
;~ the previous behaviour (immediate return), never to a hang.
Func WaitForNewInstance($timeout = $NEW_INSTANCE_START_TIMEOUT)
	Local $startUpTime = GetInstanceUpTime()
	If $startUpTime < $NEW_INSTANCE_FRESH_MS Then Return True
	Local $timer = TimerInit()
	While TimerDiff($timer) < $timeout
		If GetMyID() == 0 Or GetInstanceUpTime() < $startUpTime Then Return True
		Sleep(100)
	WEnd
	Debug('No new instance detected within ' & Round($timeout / 1000) & 's')
	Return False
EndFunc


;~ Travel to an outpost. TravelToOutpost already waits for the load and verifies the map ID, so no second wait
;~ is needed (the previous extra WaitMapLoading only added ~2.5s of dead time per travel).
Func RobustTravelToOutpost($outpostID, $district = 'Random')
	Local $result = TravelToOutpost($outpostID, $district)
	If $result <> $SUCCESS Then
		; One retry: map travel occasionally fails on district/instance hiccups
		Warn('Travel failed, retrying once')
		RandomSleep(2000)
		$result = TravelToOutpost($outpostID, $district)
	EndIf
	Return $result
EndFunc


Func RobustResignAndReturnToOutpost($outpostID, $ignoreMapID = False)
	Local $result = ResignAndReturnToOutpost($outpostID, $ignoreMapID)
	If $result == $SUCCESS Then RobustWaitMapLoading($outpostID)
	Return $result
EndFunc


;~ Bounded retry helper for "walk into the portal until the map changes" loops.
;~ Usage:  Local $attempts = 0
;~         While GetMapID() <> $ID_X
;~             If Not MapEntryAttemptAllowed($attempts, 'X') Then Return $FAIL
;~             ...
Func MapEntryAttemptAllowed(ByRef $attempts, $mapName = 'the next map')
	$attempts += 1
	If $attempts > $MAP_ENTRY_MAX_ATTEMPTS Then
		Error('Could not enter ' & $mapName & ' after ' & $MAP_ENTRY_MAX_ATTEMPTS & ' attempts')
		Return False
	EndIf
	If $attempts > 1 Then Warn('Entering ' & $mapName & ': attempt ' & $attempts & '/' & $MAP_ENTRY_MAX_ATTEMPTS)
	Return True
EndFunc


;~ Bounded retry helper for farm setup loops (run to dungeon / zone) - same contract as MapEntryAttemptAllowed
Func SetupAttemptAllowed(ByRef $attempts, $setupName = 'farm setup')
	$attempts += 1
	If $attempts > $SETUP_MAX_ATTEMPTS Then
		Error($setupName & ' failed ' & $SETUP_MAX_ATTEMPTS & ' times in a row')
		Return False
	EndIf
	If $attempts > 1 Then Warn($setupName & ': attempt ' & $attempts & '/' & $SETUP_MAX_ATTEMPTS)
	Return True
EndFunc


;~ Keep casting a skill until it goes on recharge, the player dies or $timeout elapses.
;~ Replaces the farms' unbounded "While IsRecharged(x) And IsPlayerAlive()" loops (e.g. Death's Charge on a dead
;~ target or a skill without enough energy used to spin forever). Returns True if the skill went on recharge.
Func CastUntilRecharging($skillSlot, $target = Null, $sleepBetween = 200, $timeout = $SKILL_SPAM_TIMEOUT)
	Local $timer = TimerInit()
	While IsRecharged($skillSlot) And IsPlayerAlive()
		If TimerDiff($timer) > $timeout Then
			Debug('Skill ' & $skillSlot & ' could not be cast within ' & Round($timeout / 1000) & 's')
			Return False
		EndIf
		If $target == Null Then
			UseSkillEx($skillSlot)
		Else
			UseSkillEx($skillSlot, $target)
		EndIf
		RandomSleep($sleepBetween)
	WEnd
	Return Not IsRecharged($skillSlot)
EndFunc


;~ Wait (bounded) for a skill to come off recharge while the player is alive. Returns True when ready.
Func WaitForSkillRecharge($skillSlot, $timeout = 60000, $poll = 250)
	Local $timer = TimerInit()
	While IsPlayerAlive() And Not IsRecharged($skillSlot)
		If TimerDiff($timer) > $timeout Then Return False
		RandomSleep($poll)
	WEnd
	Return IsRecharged($skillSlot)
EndFunc


;~ Heuristic disconnection detection, cheap when connected (~1.5s):
;~ connected = not on a loading screen, player agent exists and the instance clock is advancing.
;~ Anything else must persist for $confirmMs before the client is declared disconnected, so ordinary
;~ loading screens are never mistaken for a disconnection.
Func IsGameDisconnected($confirmMs = 30000)
	If IsGameConnectedSample() Then Return False
	Local $timer = TimerInit()
	While TimerDiff($timer) < $confirmMs
		If IsGameConnectedSample() Then Return False
		Sleep(500)
	WEnd
	Return True
EndFunc


; Set once the instance clock has been seen advancing: only then is a frozen clock evidence of a disconnection
Global $instance_clock_verified = False

Func IsGameConnectedSample()
	If GetMapType() == $ID_LOADING Then Return False
	Local $myID = GetMyID()
	If $myID == 0 Or Not GetAgentExists($myID) Then Return False
	Local $upTime = GetInstanceUpTime()
	; Up-time offset unavailable (reads 0): cannot use the clock, trust the agent check
	If $upTime <= 0 Then Return True
	Sleep(1500)
	If GetInstanceUpTime() <> $upTime Then
		$instance_clock_verified = True
		Return True
	EndIf
	; Clock never seen moving in this session: do not trust it (an unexpected offset must not cause false alarms)
	Return Not $instance_clock_verified
EndFunc


;~ Called before every run: detect a dropped connection and try to reconnect.
;~ Returns False when the client stays disconnected (the hub then pauses instead of failing runs in a loop).
Func EnsureGameConnected()
	If Not IsGameDisconnected() Then Return True
	If Not Disconnected() Then Return False
	; Back in game, but every farm's cached state (setup done, current map...) is stale
	ResetBotsSetups()
	Return True
EndFunc


Func SafeRandomSleep($min, $max)
	Sleep(Random($min, $max, 1))
EndFunc
