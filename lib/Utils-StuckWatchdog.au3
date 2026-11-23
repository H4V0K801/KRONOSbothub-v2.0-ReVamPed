#CS ===========================================================================
; v24: stuck watchdog (AMG: "if you get stuck on the same action for 5 minutes, you map back and start the farm setup
; over as if the bot hasn't been ran yet except it has and still keeps all of the data").
;
; Replaces the old 'pause after 10 failed runs in a row' rule (removed).
;
; v30 (AMG: "change it to 2 minute watchdog for in town and in explorable zones"): the timeout is 2 minutes, and it watches
; the whole run - the town phases RunFarmLoop does before the farm (mid-run kit purchase, the inventory town pass: identify,
; extract, store, salvage, sell, buy; global setup) as well as the farm function (farm setup, outposts, explorables).
; Long town steps keep it fed through the inventory signal below, so a long salvage/extract/store/sell pass is progress.
;
; Sampled every $STUCK_WATCHDOG_SAMPLE_MS by an Adlib. "Same action" = none of these progress signals for $STUCK_WATCHDOG_TIMEOUT_MS:
;   - the map or the map type changed (zoning, loading screens, entering/leaving an explorable)
;   - the player moved at least $STUCK_WATCHDOG_MOVE_RANGE from where the last progress was seen
;   - experience went up (every foe killed by the party gives XP, also at level 20: long legit fights in one spot count)
;   - a log line was written whose text was never logged before in this run (salvaging, merchants, chests, waypoints,
;     quest steps all log; the SAME line repeated over and over - a loop - is not progress)
;   - v30: the inventory changed: character/storage gold, item counts in the bags and in every Xunlai tab, or the bags'
;     item IDs/slots, quantities, values (kit uses) and identified flags (salvage, extract, identify, sell, buy, store,
;     sort, pick-ups all change it; a step retrying the same item without effect does not)
; While a map is loading the clock is held (a load is a transition, never 'stuck').
;
; When it trips: logs why, sets $stuck_watchdog_tripped (IsRunFailed / CheckStuck then fail the run for farms that poll
; them) and maps back at once from inside the Adlib - travel to the last outpost seen (the farm's town; Eye of the North if
; none was seen yet), or a district change when already there - so loops that never poll anything end too. When the farm
; function returns, StuckWatchdogAfterRun() counts the run as FAILED (never PAUSE), makes sure the character is in an
; outpost and resets EVERY farm setup flag (ResetAllFarmSetupsAfterStuck) so the next run sets up from scratch like a first
; run. Stats, session counters, CSV, configs and the Items panel are kept. If the farm still does not return, it trips again
; after another timeout.
;
; Not watched (they legitimately idle): Follower, Monk Bonder, EleMonk UW Bonder, OmniFarm, Manual Mode, Tests, TestSuite.
; v30: the Storage utility (a town pass on its own) is watched now, like the town pass of every farm.
#CE ===========================================================================

#include-once
#include 'Utils-Console.au3'

Global Const $STUCK_WATCHDOG_TIMEOUT_MS = 2 * 60 * 1000
Global Const $STUCK_WATCHDOG_SAMPLE_MS = 5000
Global Const $STUCK_WATCHDOG_MOVE_RANGE = 300
Global Const $STUCK_WATCHDOG_EXCLUDED_FARMS[] = ['Follower', 'Monk Bonder', 'EleMonk UW Bonder', 'OmniFarm', 'Manual Mode', 'Tests', 'TestSuite', '']

Global $stuck_wd_active = False
Global $stuck_wd_farm = ''
Global $stuck_wd_clock = 0
Global $stuck_wd_last_progress = 0
Global $stuck_wd_map_id = -1
Global $stuck_wd_map_type = -1
Global $stuck_wd_anchor_x = 0
Global $stuck_wd_anchor_y = 0
Global $stuck_wd_anchor_set = False
Global $stuck_wd_xp = -1
; v30: last inventory signature ('' = none yet / unreadable)
Global $stuck_wd_inv_sig = ''
Global $stuck_wd_trips_this_run = 0
Global $stuck_wd_recoveries = 0
; last outpost seen (kept across runs): where 'map back' goes
Global $stuck_wd_last_outpost = 0


;~ True if the farm is watched
Func StuckWatchdogWatches($farmName)
	For $excluded In $STUCK_WATCHDOG_EXCLUDED_FARMS
		If $farmName == $excluded Then Return False
	Next
	Return True
EndFunc


;~ Called by RunFarmLoop at the start of the run (v30: before the town phases, not only before the farm function).
;~ Returns True if the farm is watched.
Func StuckWatchdogStart($farmName)
	$stuck_watchdog_tripped = False
	$stuck_wd_trips_this_run = 0
	$stuck_wd_farm = $farmName
	$stuck_wd_active = False
	If Not StuckWatchdogWatches($farmName) Then Return False
	StuckWatchdogResetWindow(0)
	$stuck_wd_clock = TimerInit()
	LogNoveltyReset()
	$log_novelty_enabled = True
	$stuck_wd_active = True
	; first sample now (records the outpost the run starts from)
	StuckWatchdogSampleNow()
	AdlibRegister('StuckWatchdogTick', $STUCK_WATCHDOG_SAMPLE_MS)
	Return True
EndFunc


;~ Called by RunFarmLoop right after the farm function returned
Func StuckWatchdogStop()
	AdlibUnRegister('StuckWatchdogTick')
	$stuck_wd_active = False
	$log_novelty_enabled = False
EndFunc


;~ Forget the last observation (progress clock restarts at $now)
Func StuckWatchdogResetWindow($now)
	$stuck_wd_last_progress = $now
	$stuck_wd_map_id = -1
	$stuck_wd_map_type = -1
	$stuck_wd_anchor_set = False
	$stuck_wd_xp = -1
	$stuck_wd_inv_sig = ''
	$log_novelty_new = False
EndFunc


;~ Adlib: one sample; trips and maps back when there was no progress for the timeout
Func StuckWatchdogTick()
	If Not $stuck_wd_active Then Return
	If StuckWatchdogSampleNow() Then StuckWatchdogTrip()
EndFunc


;~ Reads the game state once and feeds StuckWatchdogObserve. Returns True when the watchdog trips.
Func StuckWatchdogSampleNow()
	Local $mapType = GetMapType()
	Local $mapID = GetMapID()
	Local $x = 0, $y = 0, $xp = -1, $invSig = ''
	If $mapType <> $ID_LOADING And GetMyID() <> 0 Then
		Local $me = GetMyAgent()
		$x = DllStructGetData($me, 'X')
		$y = DllStructGetData($me, 'Y')
		$xp = GetExperience()
		$invSig = StuckWatchdogInventorySignature()
	Else
		$mapType = $ID_LOADING
	EndIf
	If $mapType == $ID_OUTPOST And $mapID > 0 Then $stuck_wd_last_outpost = $mapID
	Local $newLog = $log_novelty_new
	$log_novelty_new = False
	Return StuckWatchdogObserve($mapID, $mapType, $x, $y, $xp, $newLog, TimerDiff($stuck_wd_clock), $invSig)
EndFunc


;~ v30: one string that changes whenever the inventory/storage changes (gold, item counts per bag and Xunlai tab, and for
;~ the bags the sums of item ID x slot, quantity, value - kit uses - and interaction flags - identified). Read-only.
Func StuckWatchdogInventorySignature()
	Local $sig = GetGoldCharacter() & '/' & GetGoldStorage()
	Local $idSlots = 0, $quantity = 0, $value = 0, $interaction = 0
	For $bagIndex = 1 To $bags_count
		Local $bag = GetBag($bagIndex)
		$sig &= '/' & DllStructGetData($bag, 'ItemsCount')
		Local $bagItems = GetBagItemsOf($bagIndex, $bag)
		For $slot = 1 To UBound($bagItems)
			Local $item = $bagItems[$slot - 1]
			If Not IsDllStruct($item) Or DllStructGetData($item, 'ID') == 0 Then ContinueLoop
			$idSlots += DllStructGetData($item, 'ID') * ($bagIndex * 100 + $slot)
			$quantity += DllStructGetData($item, 'Quantity')
			$value += DllStructGetData($item, 'Value')
			$interaction += BitAND(DllStructGetData($item, 'Interaction'), 0x1)
		Next
	Next
	For $bagIndex = 8 To 21
		$sig &= '/' & DllStructGetData(GetBag($bagIndex), 'ItemsCount')
	Next
	Return $sig & '|' & $idSlots & '|' & $quantity & '|' & $value & '|' & $interaction
EndFunc


;~ Pure progress check (no game reads, unit-tested). Returns True when there was no progress for the timeout.
;~ After a trip the window restarts, so a farm that still does not return trips again one timeout later.
;~ v30: $invSig = inventory signature ('' = not read, e.g. loading): any change from the previous one is progress.
Func StuckWatchdogObserve($mapID, $mapType, $x, $y, $xp, $newLog, $now, $invSig = '')
	Local $progress = False
	If $mapType == $ID_LOADING Then
		; loading screen: a transition, hold the clock and re-anchor after the load
		$progress = True
		$stuck_wd_anchor_set = False
	ElseIf $mapID <> $stuck_wd_map_id Or $mapType <> $stuck_wd_map_type Then
		$progress = True
		$stuck_wd_anchor_set = False
	EndIf
	$stuck_wd_map_id = $mapID
	$stuck_wd_map_type = $mapType
	If $mapType <> $ID_LOADING Then
		If Not $stuck_wd_anchor_set Then
			$stuck_wd_anchor_x = $x
			$stuck_wd_anchor_y = $y
			$stuck_wd_anchor_set = True
		ElseIf ($x - $stuck_wd_anchor_x) ^ 2 + ($y - $stuck_wd_anchor_y) ^ 2 >= $STUCK_WATCHDOG_MOVE_RANGE ^ 2 Then
			$progress = True
			$stuck_wd_anchor_x = $x
			$stuck_wd_anchor_y = $y
		EndIf
		If $xp >= 0 Then
			If $stuck_wd_xp >= 0 And $xp > $stuck_wd_xp Then $progress = True
			$stuck_wd_xp = $xp
		EndIf
		If $invSig <> '' Then
			If $stuck_wd_inv_sig <> '' And $invSig <> $stuck_wd_inv_sig Then $progress = True
			$stuck_wd_inv_sig = $invSig
		EndIf
	EndIf
	If $newLog Then $progress = True
	If $progress Then
		$stuck_wd_last_progress = $now
		Return False
	EndIf
	If $now - $stuck_wd_last_progress < $STUCK_WATCHDOG_TIMEOUT_MS Then Return False
	; tripped: restart the window so the next trip needs another full timeout
	$stuck_wd_last_progress = $now
	Return True
EndFunc


;~ Where 'map back' travels: the last outpost seen (normally the farm's own town), else Eye of the North
Func StuckWatchdogTarget()
	Return $stuck_wd_last_outpost > 0 ? $stuck_wd_last_outpost : $ID_EYE_OF_THE_NORTH
EndFunc


;~ Trip: log, flag the run, map back now
Func StuckWatchdogTrip()
	$stuck_watchdog_tripped = True
	$stuck_wd_trips_this_run += 1
	Local $minutes = Round($STUCK_WATCHDOG_TIMEOUT_MS / 60000)
	Local $target = StuckWatchdogTarget()
	Local $targetName = $MAP_NAMES_FROM_IDS[$target]
	Error('[Stuck] No progress for ' & $minutes & ' min (same map, moved less than ' & $STUCK_WATCHDOG_MOVE_RANGE _
		& ', no XP gained, no inventory change, no new log line) in ' & $stuck_wd_farm & ' - mapping back to ' & $targetName _
		& ' and restarting the farm setup (stats kept)' & ($stuck_wd_trips_this_run > 1 ? ', attempt ' & $stuck_wd_trips_this_run : ''))
	StuckWatchdogMapBack($target)
	StuckWatchdogResetWindow(TimerDiff($stuck_wd_clock))
EndFunc


;~ Travel to the outpost; when already there, change district so the stuck dialog/NPC/state is dropped by a map load
Func StuckWatchdogMapBack($target)
	If GetMapID() == $target And GetMapType() == $ID_OUTPOST Then
		Info('[Stuck] Already in ' & $MAP_NAMES_FROM_IDS[$target] & ' - changing district to reload the map')
		RandomDistrictTravel($target, 0, 6)
		Return
	EndIf
	; v38.1: Tasca only - resign back to the Citadel when stuck in an explorable; other farms still map-travel
	If $stuck_wd_farm == 'Tasca' And GetMapType() <> $ID_OUTPOST Then
		TascaWatchdogRecover($target)
		Return
	EndIf
	TravelToOutpost($target, $district_name)
EndFunc


;~ Called by RunFarmLoop after StuckWatchdogStop(): returns the run result to record ($FAIL after a trip, never $PAUSE)
Func StuckWatchdogAfterRun($result)
	If Not $stuck_watchdog_tripped Then Return $result
	$stuck_watchdog_tripped = False
	$stuck_wd_recoveries += 1
	If GetMapType() <> $ID_OUTPOST Then
		If $stuck_wd_farm == 'Tasca' Then
			TascaWatchdogRecover(StuckWatchdogTarget())
		Else
			TravelToOutpost(StuckWatchdogTarget(), $district_name)
		EndIf
	EndIf
	ResetAllFarmSetupsAfterStuck()
	Notice('[Stuck] Recovered (' & $stuck_wd_recoveries & ' this session): run counted as failed, farm setup will run again from the start, statistics kept')
	Return $FAIL
EndFunc


;~ Stuck recoveries this session
Func StuckWatchdogRecoveries()
	Return $stuck_wd_recoveries
EndFunc
