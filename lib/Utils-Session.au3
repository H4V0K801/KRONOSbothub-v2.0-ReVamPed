#CS ===========================================================================
; Session statistics for BotsHub (added in v10-improved)
;
; Licensed under the Apache License, Version 2.0 (the 'License');
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
; http://www.apache.org/licenses/LICENSE-2.0
#CE ===========================================================================

;~ Keeps per-session counters independent of the GUI (so headless mode gets them too), appends one CSV line per run
;~ to logs/runs-YYYY-MM-DD.csv and logs a session summary when the script exits.
;~ Never touches game memory except through GetGoldCharacter/GetGoldStorage, and only while attached.

#include-once
#include <FileConstants.au3>
#include 'Utils-Console.au3'

Global $session_started = False
Global $session_start_time = ''
Global $session_timer = 0
Global $session_runs = 0
Global $session_successes = 0
Global $session_failures = 0
Global $session_pauses = 0
Global $session_consecutive_failures = 0
Global $session_run_time = 0
Global $session_longest_run = 0
Global $session_initial_gold = -1
Global $session_last_gold = -1
Global $session_current_farm = ''
Global $session_csv_enabled = True


;~ Start the session (idempotent)
Func SessionStart()
	If $session_started Then Return
	$session_started = True
	$session_start_time = @YEAR & '-' & @MON & '-' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC
	$session_timer = TimerInit()
	OnAutoItExitRegister('SessionEnd')
EndFunc


;~ Total gold (character + storage), or -1 when it cannot be read (not attached)
Func SessionReadGold()
	; Only while a game client is attached: memory reads without a process handle are meaningless
	If Not IsDeclared('attached_for_tools') Then Return -1
	If Not Eval('attached_for_tools') Then Return -1
	Local $gold = GetGoldCharacter() + GetGoldStorage()
	If @error Then Return -1
	Return $gold
EndFunc


;~ Called right before a farm run starts
Func SessionRunStarted($farmName)
	If Not $session_started Then SessionStart()
	$session_current_farm = $farmName
	If $session_initial_gold < 0 Then
		$session_initial_gold = SessionReadGold()
		$session_last_gold = $session_initial_gold
	EndIf
EndFunc


;~ Called right after a farm run returns
Func SessionRunFinished($farmName, $result, $elapsedTime)
	If Not $session_started Then SessionStart()
	Local $resultName
	Switch $result
		Case $SUCCESS
			$resultName = 'SUCCESS'
			$session_successes += 1
			$session_consecutive_failures = 0
		Case $PAUSE
			$resultName = 'PAUSE'
			$session_pauses += 1
		Case Else
			$resultName = 'FAIL'
			$session_failures += 1
			$session_consecutive_failures += 1
	EndSwitch
	If $result <> $PAUSE Then
		$session_runs += 1
		$session_run_time += $elapsedTime
		If $elapsedTime > $session_longest_run Then $session_longest_run = $elapsedTime
	EndIf
	Local $gold = SessionReadGold()
	If $gold >= 0 Then $session_last_gold = $gold
	SessionAppendCsv($farmName, $resultName, $elapsedTime, $gold)
	If $result <> $PAUSE Then
		Info('Session: ' & $session_runs & ' runs, ' & $session_successes & ' ok, ' & $session_failures & ' failed' & _
			($session_runs > 0 ? ' (' & Round($session_successes * 100 / $session_runs, 1) & '%)' : '') & _
			', average ' & SessionFormatDuration($session_runs > 0 ? $session_run_time / $session_runs : 0) & _
			($session_consecutive_failures > 1 ? ', ' & $session_consecutive_failures & ' failures in a row' : ''))
	EndIf
EndFunc


;~ 'Reset session stats' (v15): counters behind the per-run 'Session:' line, the exit summary and the failure streak
;~ start again from zero; the session start time/uptime restart now and the gold baseline is re-read at the next run start.
;~ Kept: the exit hook, CSV on/off, current farm name, and the log warning/error counters (they describe the log file).
Func SessionResetStats()
	$session_start_time = @YEAR & '-' & @MON & '-' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC
	$session_timer = TimerInit()
	$session_runs = 0
	$session_successes = 0
	$session_failures = 0
	$session_pauses = 0
	$session_consecutive_failures = 0
	$session_run_time = 0
	$session_longest_run = 0
	$session_initial_gold = -1
	$session_last_gold = -1
EndFunc


Func SessionConsecutiveFailures()
	Return $session_consecutive_failures
EndFunc


;~ One line per run: date,time,farm,result,duration_s,total_gold
Func SessionAppendCsv($farmName, $resultName, $elapsedTime, $gold)
	If Not $session_csv_enabled Then Return
	Local $path = @ScriptDir & '\logs\runs-' & @YEAR & '-' & @MON & '-' & @MDAY & '.csv'
	Local $isNew = Not FileExists($path)
	Local $file = FileOpen($path, $FO_APPEND + $FO_CREATEPATH)
	If $file == -1 Then Return
	If $isNew Then FileWriteLine($file, 'date,time,character,farm,result,duration_s,total_gold')
	Local $character = IsDeclared('character_name') ? Eval('character_name') : ''
	FileWriteLine($file, @YEAR & '-' & @MON & '-' & @MDAY & ',' & @HOUR & ':' & @MIN & ':' & @SEC & ',' & _
		SessionCsvField($character) & ',' & SessionCsvField($farmName) & ',' & $resultName & ',' & _
		Round($elapsedTime / 1000, 1) & ',' & ($gold >= 0 ? $gold : ''))
	FileClose($file)
EndFunc


Func SessionCsvField($value)
	$value = String($value)
	If StringRegExp($value, '[",\r\n]') Then Return '"' & StringReplace($value, '"', '""') & '"'
	Return $value
EndFunc


;~ 'h:mm:ss' style duration
Func SessionFormatDuration($milliseconds)
	Local $totalSeconds = Int($milliseconds / 1000)
	Local $hours = Int($totalSeconds / 3600)
	Local $minutes = Int(Mod($totalSeconds, 3600) / 60)
	Local $seconds = Mod($totalSeconds, 60)
	Return ($hours > 0 ? $hours & 'h' : '') & StringFormat('%02dm%02ds', $minutes, $seconds)
EndFunc


;~ Summary text of the current session
Func SessionSummary()
	Local $text = 'Session summary (started ' & $session_start_time & ', uptime ' & SessionFormatDuration(TimerDiff($session_timer)) & '): '
	$text &= $session_runs & ' runs, ' & $session_successes & ' successful, ' & $session_failures & ' failed, ' & $session_pauses & ' paused'
	If $session_runs > 0 Then
		$text &= ', success rate ' & Round($session_successes * 100 / $session_runs, 1) & '%'
		$text &= ', average run ' & SessionFormatDuration($session_run_time / $session_runs)
		$text &= ', longest run ' & SessionFormatDuration($session_longest_run)
	EndIf
	If $session_initial_gold >= 0 And $session_last_gold >= 0 Then
		$text &= ', gold change ' & ($session_last_gold - $session_initial_gold)
	EndIf
	; v24: stuck watchdog recoveries (only shown when there were any)
	If IsDeclared('stuck_wd_recoveries') And Eval('stuck_wd_recoveries') > 0 Then $text &= ', stuck recoveries ' & Eval('stuck_wd_recoveries')
	$text &= ', log: ' & $log_counts[$LVL_WARNING] & ' warnings, ' & $log_counts[$LVL_ERROR] & ' errors'
	Return $text
EndFunc


;~ Registered with OnAutoItExitRegister: logs the summary on any normal exit (window close, Exit, end of script)
Func SessionEnd()
	If Not $session_started Then Return
	$session_started = False
	; GUI may already be destroyed here: log to file/stdout only
	$log_console = 0
	Notice(SessionSummary())
EndFunc


;~ One-time environment line at start-up: makes user-submitted logs self-describing
Func LogStartupDiagnostics($hubVersion, $runMode)
	Info('BotsHub ' & $hubVersion & ' (v10-improved) | AutoIt ' & @AutoItVersion & ($runMode == '' ? '' : ' | mode ' & $runMode) & _
		' | ' & @OSVersion & ' ' & @OSArch & ' | admin ' & (IsAdmin() ? 'yes' : 'NO') & ' | ' & @ScriptDir)
	If Not IsAdmin() Then Warn('Not running as administrator: attaching to Guild Wars will fail')
	Debug('Log file: ' & GetLogFilePath())
EndFunc
