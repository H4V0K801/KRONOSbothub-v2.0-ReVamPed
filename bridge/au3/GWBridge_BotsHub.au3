#include-once
#include 'GWBridge.au3'
; ==============================================================================================
; GWBridge_BotsHub.au3 - BotsHub glue for the reads-only bridge test build (v38.9-bridgeA).
;   * BotsHubBridgeStart($pid): called right after InitializeGameClientForGWA2 succeeded.
;       - GWToolbox++ / Py4GW found in or around the client -> bridge not loaded, logged, bot runs classic.
;       - bridge up   -> $g_GWB_Hook = True  (GWA2 READS go through the bridge)
;       - $g_GWB_HookCommands stays False   (every COMMAND stays classic GWA2 in this build)
;   * one clear log line either way: "GWBridge: ACTIVE ..." or "GWBridge: OFF ...".
;   * a light 5 s check that logs (once per change) if the DLL stops (error / foreign tool / no frames).
;     Fixed texts only, so it never looks like "progress" to the stuck watchdog.
;   * on exit: the DLL is asked to unload from the game.
; Uses BotsHub's Info / Notice / Warn (lib/Utils-Console.au3).
; ==============================================================================================

Global Const $GWB_BOTSHUB_BUILD = 'v38.12-bridge'
Global $g_GWB_BotsHubExitHooked = False
Global $g_GWB_WatchState = ''

Func BotsHubBridgeStart($pid, $dllDir = Default, $dllName = Default)   ; dir/name only for the offline tests
	$g_GWB_Hook = False
	$g_GWB_HookCommands = False
	If $g_GWB_Attached And $g_GWB_PID <> $pid Then GWBridge_Unload(2000)   ; other client before: let that one go
	If $dllDir = Default Then $dllDir = @ScriptDir & '\bridge\bin'
	If $dllName = Default Then $dllName = 'GWBridge.dll'
	If GWBridge_Start($pid, $dllDir, $dllName) Then
		$g_GWB_Hook = True
		$g_GWB_WatchState = 'ok'
		Notice('GWBridge: ACTIVE - game reads through the bridge, commands classic GWA2 (pid ' & $pid & ', ' & _
				DllStructGetData($g_GWB_tHdr, 'build') & ', GW build ' & DllStructGetData($g_GWB_tHdr, 'gw_version') & ')')
		AdlibRegister('__BotsHubBridgeWatch', 5000)
		If Not $g_GWB_BotsHubExitHooked Then
			OnAutoItExitRegister('BotsHubBridgeStop')
			$g_GWB_BotsHubExitHooked = True
		EndIf
		Return True
	EndIf
	Local $why = $g_GWB_LastError
	$g_GWB_WatchState = ''
	AdlibUnRegister('__BotsHubBridgeWatch')
	If $g_GWB_Attached Then GWBridge_Unload(2000)   ; loaded but not usable (error): take it out of the game again
	Warn('GWBridge: OFF - classic GWA2 for everything. Reason: ' & $why)
	Return False
EndFunc

Func BotsHubBridgeStop()
	AdlibUnRegister('__BotsHubBridgeWatch')
	$g_GWB_Hook = False
	If $g_GWB_Attached Then GWBridge_Unload(1500)
EndFunc

;~ Every 5 s: header reads only (no game memory access). Logs once per state change.
Func __BotsHubBridgeWatch()
	If Not $g_GWB_Attached Then Return
	Local $st = DllStructGetData($g_GWB_tHdr, 'status'), $state = 'ok'
	If BitAND($st, $GWB_ST_ERROR) Then
		$state = 'error'
	ElseIf BitAND($st, $GWB_ST_STALLED) Then
		$state = 'stalled'
	EndIf
	If $state = $g_GWB_WatchState Then Return
	$g_GWB_WatchState = $state
	Switch $state
		Case 'error'
			$g_GWB_Hook = False
			Warn('GWBridge: STOPPED (' & DllStructGetData($g_GWB_tHdr, 'diag') & ') - classic GWA2 from now on')
		Case 'stalled'
			Warn('GWBridge: no frames from the game for 2 s - classic GWA2 until frames come back')
		Case 'ok'
			Info('GWBridge: frames again - reads through the bridge')
	EndSwitch
EndFunc
