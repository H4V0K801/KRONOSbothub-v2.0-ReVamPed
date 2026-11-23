#include <GuiRichEdit.au3>
#CS ===========================================================================
; Author: caustic-kronos (aka Kronos, Night, Svarog)
; Copyright 2026 caustic-kronos
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
#include <ColorConstants.au3>
#include <FileConstants.au3>
#include 'BotsHub-Constants.au3'
#include 'BotsHub-Theme-Colors.au3'

Global Const $LVL_DEBUG = 0
Global Const $LVL_INFO = 1
Global Const $LVL_NOTICE = 2
Global Const $LVL_WARNING = 3
Global Const $LVL_ERROR = 4

Global Const $LOG_LEVEL_NAMES[5] = ['DEBUG', 'INFO', 'NOTICE', 'WARN', 'ERROR']

Global $log_console = 0
Global $log_level = $LVL_INFO
; Every log line is also appended to logs/botshub-<date>[-<tag>].log (crash-safe: file is opened per line)
Global $log_to_file = True
Global $log_file_tag = ''
; Number of messages logged per level since start (used by the session summary)
Global $log_counts[5] = [0, 0, 0, 0, 0]
; v24: 'new log line' signal for the stuck watchdog (Utils-StuckWatchdog.au3): while enabled, Out() remembers every distinct
; text of the run and raises $log_novelty_new when a text never logged before in this run appears (repeats are not progress)
Global $log_novelty_enabled = False
Global $log_novelty_new = False
Global $log_novelty_seen[]
Global $log_novelty_size = 0
Global Const $LOG_NOVELTY_MAX_TEXTS = 2000


;~ Set a suffix for the log file name (character name) so several hubs do not interleave in one file
Func SetLogFileTag($tag)
	$log_file_tag = StringRegExpReplace($tag, '[\\/:*?"<>|]', '_')
EndFunc


;~ Current log file path
Func GetLogFilePath()
	Local $path = @ScriptDir & '\logs\botshub-' & @YEAR & '-' & @MON & '-' & @MDAY
	If $log_file_tag <> '' Then $path &= '-' & $log_file_tag
	Return $path & '.log'
EndFunc

Func SetConsole($consoleHandle)
	$log_console = $consoleHandle
EndFunc


;~ Print debug to console with timestamp
Func Debug($TEXT)
	Out($TEXT, $LVL_DEBUG)
EndFunc


;~ Print info to console with timestamp
Func Info($TEXT)
	Out($TEXT, $LVL_INFO)
EndFunc


;~ Print notice to console with timestamp
Func Notice($TEXT)
	Out($TEXT, $LVL_NOTICE)
EndFunc


;~ Print warning to console with timestamp
Func Warn($TEXT)
	Out($TEXT, $LVL_WARNING)
EndFunc


;~ Print warning to console with timestamp, only once
;~ Do not overuse, warnings are stored in memory
Func WarnOnce($TEXT)
	Static Local $warningMessages[]
	If $warningMessages[$TEXT] <> 1 Then
		Out($TEXT, $LVL_WARNING)
		$warningMessages[$TEXT] = 1
	EndIf
EndFunc


;~ Print error to console with timestamp
Func Error($TEXT)
	Out($TEXT, $LVL_ERROR)
EndFunc


;~ v24: remembers $TEXT for the stuck watchdog; flags it when it was never logged before in this run
Func LogNoveltyNote($TEXT)
	If MapExists($log_novelty_seen, $TEXT) Then Return
	If $log_novelty_size >= $LOG_NOVELTY_MAX_TEXTS Then LogNoveltyReset()
	$log_novelty_seen[$TEXT] = 1
	$log_novelty_size += 1
	$log_novelty_new = True
EndFunc


;~ v24: forget the texts seen (new run)
Func LogNoveltyReset()
	Local $empty[]
	$log_novelty_seen = $empty
	$log_novelty_size = 0
	$log_novelty_new = False
EndFunc


;~ Print to console with timestamp
;~ LOGLEVEL= 0-Debug, 1-Info, 2-Notice, 3-Warning, 4-Error
Func Out($TEXT, $LOGLEVEL = 1)
	If $LOGLEVEL < $LVL_DEBUG Or $LOGLEVEL > $LVL_ERROR Then $LOGLEVEL = $LVL_INFO
	$log_counts[$LOGLEVEL] += 1
	If $log_novelty_enabled Then LogNoveltyNote($TEXT)
	If $LOGLEVEL < $log_level Then Return
	Local $timestamp = @HOUR & ':' & @MIN & ':' & @SEC
	If $log_to_file Then
		Local Static $logDirReady = False
		If Not $logDirReady Then
			DirCreate(@ScriptDir & '\logs')
			$logDirReady = True
		EndIf
		; Full date + level in the file; failures to write are ignored (logging must never break a run)
		FileWriteLine(GetLogFilePath(), @YEAR & '-' & @MON & '-' & @MDAY & ' ' & $timestamp & ' [' & $LOG_LEVEL_NAMES[$LOGLEVEL] & '] ' & $TEXT)
	EndIf
	; No GUI console (headless mode, or before the GUI exists): fall back to stdout instead of writing to handle 0
	If $log_console == 0 Then
		ConsoleWrite($timestamp & ' [' & $LOG_LEVEL_NAMES[$LOGLEVEL] & '] ' & $TEXT & @CRLF)
		Return
	EndIf
	Local $logColor
	Switch $LOGLEVEL
		; v31: dark-theme palette (lib/BotsHub-Theme-Colors.au3); the RichEdit takes BGR
		Case $LVL_DEBUG
			$logColor = ThemeBGR($THEME_LOG_DEBUG)
		Case $LVL_INFO
			$logColor = ThemeBGR($THEME_LOG_INFO)
		Case $LVL_NOTICE
			$logColor = ThemeBGR($THEME_LOG_NOTICE)
		Case $LVL_WARNING
			$logColor = ThemeBGR($THEME_LOG_WARNING)
		Case $LVL_ERROR
			$logColor = ThemeBGR($THEME_LOG_ERROR)
	EndSwitch
	TrimConsoleIfNeeded()
	_GUICtrlRichEdit_SetCharColor($log_console, $logColor)
	_GUICtrlRichEdit_AppendText($log_console, $timestamp & ' - ' & $TEXT & @CRLF)
EndFunc


;~ The rich-edit console used to grow forever: over a multi-day session it got slow and memory hungry.
;~ When it exceeds $LOG_CONSOLE_MAX_CHARS, the oldest $LOG_CONSOLE_TRIM_CHARS characters are dropped
;~ (the full history is in the log file).
Func TrimConsoleIfNeeded()
	If _GUICtrlRichEdit_GetTextLength($log_console) < $LOG_CONSOLE_MAX_CHARS Then Return
	_GUICtrlRichEdit_SetSel($log_console, 0, $LOG_CONSOLE_TRIM_CHARS)
	_GUICtrlRichEdit_ReplaceText($log_console, '')
	_GUICtrlRichEdit_AppendText($log_console, '[... older log lines trimmed, see ' & GetLogFilePath() & ' ...]' & @CRLF)
EndFunc