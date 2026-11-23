#include-once
#include 'GWBridge_Layout.au3'
; ==============================================================================================
; GWBridge.au3 - BotsHub side of the GWBridge DLL bridge (Guild Wars 1).          PROTOTYPE v0.1
;
; What it does
;   * GWBridge_Start($pid)   inject GWBridge.dll into Gw.exe (LoadLibraryW via CreateRemoteThread),
;                            then map the named shared block "Local\GWBridge_<pid>".
;   * Bridge_*() readers     GWA2-compatible drop-ins (same arguments, same return types: the agent /
;                            skillbar / item / bag structs are the SAME GWA2 templates filled with the
;                            same raw bytes), served from the per-frame snapshot. No ReadProcessMemory.
;   * Bridge_*() commands    write to the command ring; the DLL runs them on the game thread via GWCA.
;   * Fallback               whenever the bridge is not attached, not live (no fresh frame), loading,
;                            or the requested data is not in the snapshot, every Bridge_* function calls
;                            the classic GWA2 function of the same name, so behaviour degrades to today's.
;
; Nothing here is used by BotsHub until it is wired in (see BRIDGE.md, "Integration plan").
; Requires: 32-bit AutoIt (same as GWA2). GWA2 struct templates are used if declared.
; ==============================================================================================

Global $g_GWB_k32 = DllOpen('kernel32.dll')
Global $g_GWB_Attached = False          ; shared block mapped and validated
Global $g_GWB_Hook = False              ; integration switch, phase A: GWA2 READ guards route to Bridge_* when True
Global $g_GWB_HookCommands = False      ; integration switch, phase B: GWA2 COMMAND guards (Move, UseSkill, ...) route to Bridge_*
Global $g_GWB_Bypass = False            ; set while a Bridge_* function is calling the classic GWA2 version
Global $g_GWB_CmdBusy = False           ; re-entrancy guard (Adlib can interrupt the main loop mid-write)
Global $g_GWB_hMap = 0, $g_GWB_pBase = 0, $g_GWB_PID = 0
Global $g_GWB_tHdr = 0, $g_GWB_tRing = 0
Global $g_GWB_pSlot[2], $g_GWB_tSeq[2], $g_GWB_tHash[2], $g_GWB_tAgentIds[2]
Global $g_GWB_pBag[2], $g_GWB_tBagHead[2]
Global $g_GWB_tCmd[64], $g_GWB_tCmdF[64]
Global $g_GWB_tCore = DllStructCreate($GWB_CORE_TEMPLATE)   ; local, consistent copy of the current frame's core
Global $g_GWB_tCoreSkill = DllStructCreate('dword[376]', DllStructGetPtr($g_GWB_tCore, 'skillbars'))   ; dword view of the 8 raw skillbars
Global $g_GWB_CoreFrame = -1, $g_GWB_CoreSlot = 0, $g_GWB_CoreSeq = 0
Global $g_GWB_LastLiveFrame = -1, $g_GWB_LastLiveOk = False, $g_GWB_LiveTimer = 0
Global $g_GWB_CoreFlags = 0, $g_GWB_CoreMyID = 0
Global $g_GWB_tBagLocal = DllStructCreate('byte[16496]'), $g_GWB_BagCounter = -1
Global $g_GWB_NextCmdId = 1
Global $g_GWB_LastError = ''
Global $g_GWB_Stats[6] = [0, 0, 0, 0, 0, 0]     ; bridge hits, classic fallbacks, seq retries, cmds sent, cmd fallbacks, snapshot copies
Global $g_GWB_tplAgent = 'byte[452]', $g_GWB_tplSkillbar = 'byte[188]', $g_GWB_tplItem = 'byte[84]', $g_GWB_tplBag = 'byte[40]'

; ----------------------------------------------------------------------------------------------
#Region Injection / attach
; ----------------------------------------------------------------------------------------------

;~ Injects (if needed) and attaches. $dllDir must contain GWBridge.dll and gwca.dll.
;~ Returns True when attached and the DLL reports RUNNING. On False, $g_GWB_LastError says why and every
;~ Bridge_* function keeps using classic GWA2.
Func GWBridge_Start($pid, $dllDir = @ScriptDir & '\bridge\bin', $dllName = 'GWBridge.dll', $timeoutMs = 8000)
	__GWB_PickTemplates()
	; GWToolbox++ / Py4GW carry their own GWCA and hooks: never load the bridge next to them (the DLL checks again
	; itself, at load and every second while it runs)
	Local $foreign = GWBridge_ForeignTools($pid, $dllName)
	If $foreign <> '' Then
		If GWBridge_Attach($pid, 300) Then GWBridge_Unload(2000)   ; a bridge left over from before: ask it to leave
		GWBridge_Detach()
		Return __GWB_Fail('not loaded: ' & $foreign & ' - the bridge never runs next to GWToolbox or Py4GW')
	EndIf
	If GWBridge_Attach($pid, 300) Then Return __GWB_WaitRunning($timeoutMs)
	Local $path = $dllDir & '\' & $dllName
	If Not FileExists($path) Then Return __GWB_Fail('DLL not found: ' & $path)
	If Not GWBridge_Inject($pid, $path) Then Return False
	If Not GWBridge_Attach($pid, $timeoutMs) Then Return False
	Return __GWB_WaitRunning($timeoutMs)
EndFunc

Func __GWB_WaitRunning($timeoutMs)
	Local $t = TimerInit()
	While TimerDiff($t) < $timeoutMs
		Local $st = DllStructGetData($g_GWB_tHdr, 'status')
		If BitAND($st, $GWB_ST_ERROR) Then Return __GWB_Fail('DLL error ' & DllStructGetData($g_GWB_tHdr, 'last_error') & ': ' & DllStructGetData($g_GWB_tHdr, 'diag'))
		If BitAND($st, $GWB_ST_RUNNING) Then
			$g_GWB_LastError = ''
			Return True
		EndIf
		Sleep(20)
	WEnd
	Return __GWB_Fail('DLL loaded but no frame published within ' & $timeoutMs & ' ms (status 0x' & Hex(DllStructGetData($g_GWB_tHdr, 'status'), 4) & ')')
EndFunc

;~ LoadLibraryW in the target via CreateRemoteThread. Same Windows calls GWA2 already makes
;~ (OpenProcess / VirtualAllocEx / WriteProcessMemory) plus CreateRemoteThread.
Func GWBridge_Inject($pid, $dllPath)
	Local $k = $g_GWB_k32
	; PROCESS_CREATE_THREAD | QUERY_INFORMATION | VM_OPERATION | VM_WRITE | VM_READ
	Local $hProc = DllCall($k, 'handle', 'OpenProcess', 'dword', 0x043A, 'bool', False, 'dword', $pid)[0]
	If $hProc = 0 Then Return __GWB_Fail('OpenProcess failed for pid ' & $pid)
	If __GWB_RemoteModuleBase($pid, StringRegExpReplace($dllPath, '^.*\\', '')) <> 0 Then
		DllCall($k, 'bool', 'CloseHandle', 'handle', $hProc)
		Return True   ; already loaded
	EndIf
	Local $tPath = DllStructCreate('wchar[' & (StringLen($dllPath) + 1) & ']')
	DllStructSetData($tPath, 1, $dllPath)
	Local $size = DllStructGetSize($tPath)
	Local $remote = DllCall($k, 'ptr', 'VirtualAllocEx', 'handle', $hProc, 'ptr', 0, 'ulong_ptr', $size, 'dword', 0x3000, 'dword', 0x04)[0]
	If $remote = 0 Then Return __GWB_CloseFail($hProc, 'VirtualAllocEx failed')
	Local $ok = DllCall($k, 'bool', 'WriteProcessMemory', 'handle', $hProc, 'ptr', $remote, 'struct*', $tPath, 'ulong_ptr', $size, 'ulong_ptr*', 0)[0]
	If Not $ok Then Return __GWB_CloseFail($hProc, 'WriteProcessMemory failed', $remote)
	; LoadLibraryW address in the target: same as ours unless kernel32 is based differently there
	Local $hK32 = DllCall($k, 'handle', 'GetModuleHandleW', 'wstr', 'kernel32.dll')[0]
	Local $pLoad = DllCall($k, 'ptr', 'GetProcAddress', 'handle', $hK32, 'str', 'LoadLibraryW')[0]
	Local $remoteK32 = __GWB_RemoteModuleBase($pid, 'kernel32.dll')
	If $remoteK32 <> 0 And $remoteK32 <> $hK32 Then $pLoad = Ptr(Number($remoteK32) + (Number($pLoad) - Number($hK32)))
	Local $hThread = DllCall($k, 'handle', 'CreateRemoteThread', 'handle', $hProc, 'ptr', 0, 'ulong_ptr', 0, 'ptr', $pLoad, 'ptr', $remote, 'dword', 0, 'ptr', 0)[0]
	If $hThread = 0 Then Return __GWB_CloseFail($hProc, 'CreateRemoteThread failed', $remote)
	DllCall($k, 'dword', 'WaitForSingleObject', 'handle', $hThread, 'dword', 10000)
	Local $exit = DllCall($k, 'bool', 'GetExitCodeThread', 'handle', $hThread, 'dword*', 0)[2]
	DllCall($k, 'bool', 'CloseHandle', 'handle', $hThread)
	DllCall($k, 'bool', 'VirtualFreeEx', 'handle', $hProc, 'ptr', $remote, 'ulong_ptr', 0, 'dword', 0x8000)
	DllCall($k, 'bool', 'CloseHandle', 'handle', $hProc)
	If $exit = 0 Then Return __GWB_Fail('LoadLibraryW returned NULL in the game (missing file, or blocked)')
	Return True
EndFunc

;~ '' when neither GWToolbox++ nor Py4GW is around, otherwise what was found. Looks at the client's modules
;~ (GWToolbox*, Py4GW*, python*, a gwca.dll that is not the one next to our GWBridge.dll) and at running processes
;~ (GWToolbox*, Py4GW*: their launchers inject later).
Func GWBridge_ForeignTools($pid, $ourDll = 'GWBridge.dll')
	Local $mods = __GWB_RemoteModules($pid), $ourDir = '?'
	For $i = 0 To UBound($mods) - 1
		If StringLower($mods[$i][0]) = StringLower($ourDll) Then $ourDir = __GWB_DirOf($mods[$i][1])
	Next
	For $i = 0 To UBound($mods) - 1
		Local $m = StringLower($mods[$i][0])
		If StringLeft($m, 9) = 'gwtoolbox' Or StringLeft($m, 5) = 'py4gw' Or StringLeft($m, 6) = 'python' Then Return $mods[$i][0] & ' is loaded in the client'
		If $m = 'gwca.dll' And __GWB_DirOf($mods[$i][1]) <> $ourDir Then Return 'another gwca.dll is loaded in the client (' & $mods[$i][1] & ')'
	Next
	Local $procs = ProcessList()
	For $i = 1 To $procs[0][0]
		Local $p = StringLower($procs[$i][0])
		If StringLeft($p, 9) = 'gwtoolbox' Or StringLeft($p, 5) = 'py4gw' Then Return $procs[$i][0] & ' is running'
	Next
	Return ''
EndFunc

Func __GWB_DirOf($path)
	Local $i = StringInStr($path, '\', 0, -1)
	Return StringLower($i ? StringLeft($path, $i - 1) : '')
EndFunc

;~ [n][2] = module name, full path, of every module in another process (Toolhelp snapshot).
Func __GWB_RemoteModules($pid)
	Local $k = $g_GWB_k32, $out[64][2], $n = 0
	Local $hSnap = DllCall($k, 'handle', 'CreateToolhelp32Snapshot', 'dword', 0x18, 'dword', $pid)[0]
	If $hSnap = 0 Or $hSnap = Ptr(-1) Then
		ReDim $out[1][2]
		Return $out
	EndIf
	Local $me = DllStructCreate('dword dwSize;dword th32ModuleID;dword th32ProcessID;dword GlblcntUsage;dword ProccntUsage;' & _
			'ptr modBaseAddr;dword modBaseSize;handle hModule;wchar szModule[256];wchar szExePath[260]')
	DllStructSetData($me, 'dwSize', DllStructGetSize($me))
	Local $r = DllCall($k, 'bool', 'Module32FirstW', 'handle', $hSnap, 'struct*', $me)[0]
	While $r
		If $n >= UBound($out) Then ReDim $out[$n * 2][2]
		$out[$n][0] = DllStructGetData($me, 'szModule')
		$out[$n][1] = DllStructGetData($me, 'szExePath')
		$n += 1
		$r = DllCall($k, 'bool', 'Module32NextW', 'handle', $hSnap, 'struct*', $me)[0]
	WEnd
	DllCall($k, 'bool', 'CloseHandle', 'handle', $hSnap)
	ReDim $out[($n > 0 ? $n : 1)][2]
	Return $out
EndFunc

;~ Base address of a module in another process (0 if not loaded), via a Toolhelp snapshot.
Func __GWB_RemoteModuleBase($pid, $moduleName)
	Local $k = $g_GWB_k32
	Local $hSnap = DllCall($k, 'handle', 'CreateToolhelp32Snapshot', 'dword', 0x18, 'dword', $pid)[0]
	If $hSnap = 0 Or $hSnap = Ptr(-1) Then Return 0
	Local $me = DllStructCreate('dword dwSize;dword th32ModuleID;dword th32ProcessID;dword GlblcntUsage;dword ProccntUsage;' & _
			'ptr modBaseAddr;dword modBaseSize;handle hModule;wchar szModule[256];wchar szExePath[260]')
	DllStructSetData($me, 'dwSize', DllStructGetSize($me))
	Local $base = 0
	Local $r = DllCall($k, 'bool', 'Module32FirstW', 'handle', $hSnap, 'struct*', $me)[0]
	While $r
		If StringLower(DllStructGetData($me, 'szModule')) = StringLower($moduleName) Then
			$base = DllStructGetData($me, 'modBaseAddr')
			ExitLoop
		EndIf
		$r = DllCall($k, 'bool', 'Module32NextW', 'handle', $hSnap, 'struct*', $me)[0]
	WEnd
	DllCall($k, 'bool', 'CloseHandle', 'handle', $hSnap)
	Return $base
EndFunc

;~ Maps "Local\GWBridge_<pid>" and validates the layout. Waits up to $timeoutMs for the DLL to create it.
Func GWBridge_Attach($pid, $timeoutMs = 3000)
	__GWB_PickTemplates()
	GWBridge_Detach()
	Local $k = $g_GWB_k32, $t = TimerInit(), $h = 0
	Do
		$h = DllCall($k, 'handle', 'OpenFileMappingW', 'dword', 0xF001F, 'bool', False, 'wstr', 'Local\GWBridge_' & $pid)[0]
		If $h <> 0 Then ExitLoop
		Sleep(20)
	Until TimerDiff($t) > $timeoutMs
	If $h = 0 Then Return __GWB_Fail('no shared block for pid ' & $pid & ' (bridge not loaded)')
	Local $p = DllCall($k, 'ptr', 'MapViewOfFile', 'handle', $h, 'dword', 0xF001F, 'dword', 0, 'dword', 0, 'ulong_ptr', 0)[0]
	If $p = 0 Then
		DllCall($k, 'bool', 'CloseHandle', 'handle', $h)
		Return __GWB_Fail('MapViewOfFile failed')
	EndIf
	$g_GWB_hMap = $h
	$g_GWB_pBase = $p
	$g_GWB_tHdr = DllStructCreate($GWB_HEADER_TEMPLATE, $p)
	While DllStructGetData($g_GWB_tHdr, 'magic') <> $GWB_MAGIC And TimerDiff($t) < $timeoutMs
		Sleep(10)
	WEnd
	Local $why = __GWB_ValidateHeader()
	If $why <> '' Then
		GWBridge_Detach()
		Return __GWB_Fail('layout mismatch: ' & $why & ' - BotsHub and GWBridge.dll are from different versions')
	EndIf
	For $i = 0 To 1
		$g_GWB_pSlot[$i] = $p + DllStructGetData($g_GWB_tHdr, 'slot_offset' & $i)
		$g_GWB_tSeq[$i] = DllStructCreate('dword', $g_GWB_pSlot[$i])
		$g_GWB_tHash[$i] = DllStructCreate('ushort[' & $GWB_HASH_SIZE & ']', $g_GWB_pSlot[$i] + $GWB_SLOT_OFF_HASH)
		$g_GWB_tAgentIds[$i] = DllStructCreate('dword[' & ($GWB_MAX_AGENTS * $GWB_AGENT_STRIDE / 4) & ']', $g_GWB_pSlot[$i] + $GWB_SLOT_OFF_AGENTS)
		$g_GWB_pBag[$i] = $p + DllStructGetData($g_GWB_tHdr, 'bag_offset' & $i)
		$g_GWB_tBagHead[$i] = DllStructCreate($GWB_BAGSLOT_HEAD_TEMPLATE, $g_GWB_pBag[$i])
	Next
	Local $pCmd = $p + $GWB_CMD_OFFSET
	$g_GWB_tRing = DllStructCreate($GWB_CMD_RING_TEMPLATE, $pCmd)
	For $i = 0 To $GWB_CMD_CAPACITY - 1
		$g_GWB_tCmd[$i] = DllStructCreate($GWB_CMD_TEMPLATE, $pCmd + 64 + $i * $GWB_CMD_ENTRY_SIZE)
		$g_GWB_tCmdF[$i] = DllStructCreate($GWB_CMD_TEMPLATE_F, $pCmd + 64 + $i * $GWB_CMD_ENTRY_SIZE)
	Next
	DllStructSetData($g_GWB_tHdr, 'client_pid', @AutoItPID)
	$g_GWB_PID = $pid
	$g_GWB_Attached = True
	$g_GWB_CoreFrame = -1
	$g_GWB_BagCounter = -1
	$g_GWB_LastLiveFrame = -1
	Return True
EndFunc

Func __GWB_ValidateHeader()
	Local $h = $g_GWB_tHdr
	If DllStructGetData($h, 'magic') <> $GWB_MAGIC Then Return 'magic'
	If DllStructGetData($h, 'layout_version') <> $GWB_LAYOUT_VERSION Then Return 'layout_version ' & DllStructGetData($h, 'layout_version') & ' <> ' & $GWB_LAYOUT_VERSION
	If DllStructGetData($h, 'header_size') <> $GWB_HEADER_SIZE Then Return 'header_size'
	If DllStructGetData($h, 'total_size') <> $GWB_TOTAL_SIZE Then Return 'total_size ' & DllStructGetData($h, 'total_size')
	If DllStructGetData($h, 'slot_offset0') <> $GWB_SLOT_OFFSET0 Or DllStructGetData($h, 'slot_offset1') <> $GWB_SLOT_OFFSET1 Then Return 'slot_offset'
	If DllStructGetData($h, 'slot_size') <> $GWB_SLOT_SIZE Then Return 'slot_size'
	If DllStructGetData($h, 'bag_offset0') <> $GWB_BAG_OFFSET0 Or DllStructGetData($h, 'bag_offset1') <> $GWB_BAG_OFFSET1 Then Return 'bag_offset'
	If DllStructGetData($h, 'cmd_offset') <> $GWB_CMD_OFFSET Or DllStructGetData($h, 'cmd_capacity') <> $GWB_CMD_CAPACITY Or DllStructGetData($h, 'cmd_entry_size') <> $GWB_CMD_ENTRY_SIZE Then Return 'cmd ring'
	Return ''
EndFunc

Func GWBridge_Detach()
	If $g_GWB_pBase <> 0 Then DllCall($g_GWB_k32, 'bool', 'UnmapViewOfFile', 'ptr', $g_GWB_pBase)
	If $g_GWB_hMap <> 0 Then DllCall($g_GWB_k32, 'bool', 'CloseHandle', 'handle', $g_GWB_hMap)
	$g_GWB_pBase = 0
	$g_GWB_hMap = 0
	$g_GWB_tHdr = 0
	$g_GWB_Attached = False
EndFunc

;~ Asks the DLL to unhook and free itself (GWCA DisableHooks/Terminate, FreeLibrary), then detaches.
Func GWBridge_Unload($timeoutMs = 3000)
	If Not $g_GWB_Attached Then Return False
	Local $idx = __GWB_Enqueue($GWB_OP_UNLOAD, 0, 0, 0, 0, True)
	Local $st = ($idx < 0) ? -1 : GWBridge_WaitCommand($idx, $timeoutMs)
	GWBridge_Detach()
	Return $st = $GWB_CS_DONE
EndFunc

Func __GWB_PickTemplates()
	If IsDeclared('AGENT_STRUCT_TEMPLATE') Then $g_GWB_tplAgent = Eval('AGENT_STRUCT_TEMPLATE')
	If IsDeclared('SKILLBAR_STRUCT_TEMPLATE') Then $g_GWB_tplSkillbar = Eval('SKILLBAR_STRUCT_TEMPLATE')
	If IsDeclared('ITEM_STRUCT_TEMPLATE') Then $g_GWB_tplItem = Eval('ITEM_STRUCT_TEMPLATE')
	If IsDeclared('BAG_STRUCT_TEMPLATE') Then $g_GWB_tplBag = Eval('BAG_STRUCT_TEMPLATE')
EndFunc

Func __GWB_Fail($msg)
	$g_GWB_LastError = $msg
	Return SetError(1, 0, False)
EndFunc

Func __GWB_CloseFail($hProc, $msg, $remote = 0)
	If $remote <> 0 Then DllCall($g_GWB_k32, 'bool', 'VirtualFreeEx', 'handle', $hProc, 'ptr', $remote, 'ulong_ptr', 0, 'dword', 0x8000)
	DllCall($g_GWB_k32, 'bool', 'CloseHandle', 'handle', $hProc)
	Return __GWB_Fail($msg)
EndFunc
#EndRegion Injection / attach

; ----------------------------------------------------------------------------------------------
#Region Liveness + snapshot
; ----------------------------------------------------------------------------------------------

;~ True when the DLL is attached, running and published a frame within the last second.
;~ Cost while frames flow: one field read + one TimerDiff (no syscall, no DllCall).
Func GWBridge_IsLive()
	If Not $g_GWB_Attached Then Return False
	Local $f = DllStructGetData($g_GWB_tHdr, 'frame_counter')
	If $f <> $g_GWB_LastLiveFrame Then
		$g_GWB_LastLiveFrame = $f
		$g_GWB_LiveTimer = TimerInit()
		Local $st = DllStructGetData($g_GWB_tHdr, 'status')
		$g_GWB_LastLiveOk = BitAND($st, $GWB_ST_RUNNING) <> 0 And BitAND($st, BitOR($GWB_ST_ERROR, $GWB_ST_STALLED, $GWB_ST_UNLOADING)) = 0 _
				And DllStructGetData($g_GWB_tHdr, 'magic') = $GWB_MAGIC
		Return $g_GWB_LastLiveOk
	EndIf
	Return $g_GWB_LastLiveOk And TimerDiff($g_GWB_LiveTimer) < 1000
EndFunc

;~ Makes $g_GWB_tCore a consistent copy of the latest frame. One RtlMoveMemory per new frame;
;~ repeated calls within the same frame cost a field read and a TimerDiff. Returns False if not live / no consistent copy.
Func GWBridge_Snapshot()
	If Not GWBridge_IsLive() Then Return False
	If $g_GWB_LastLiveFrame = $g_GWB_CoreFrame Then Return True
	For $try = 1 To 4
		Local $cur = BitAND(DllStructGetData($g_GWB_tHdr, 'current_slot'), 1)
		Local $frame = DllStructGetData($g_GWB_tHdr, 'frame_counter')
		Local $s1 = DllStructGetData($g_GWB_tSeq[$cur], 1)
		If BitAND($s1, 1) = 0 Then
			DllCall($g_GWB_k32, 'none', 'RtlMoveMemory', 'struct*', $g_GWB_tCore, 'ptr', $g_GWB_pSlot[$cur], 'ulong_ptr', $GWB_SLOT_CORE_COPY)
			If DllStructGetData($g_GWB_tSeq[$cur], 1) = $s1 Then
				$g_GWB_CoreFrame = $frame
				$g_GWB_LastLiveFrame = $frame
				$g_GWB_CoreSlot = $cur
				$g_GWB_CoreSeq = $s1
				$g_GWB_CoreFlags = DllStructGetData($g_GWB_tCore, 'flags')
				$g_GWB_CoreMyID = DllStructGetData($g_GWB_tCore, 'my_id')
				$g_GWB_Stats[5] += 1
				Return True
			EndIf
		EndIf
		$g_GWB_Stats[2] += 1
	Next
	Return False
EndFunc

;~ Snapshot taken and the frame has a valid player (not loading). The condition for serving reads.
Func __GWB_Usable()
	If $g_GWB_Bypass Then Return False
	If Not GWBridge_Snapshot() Then Return False
	Return BitAND($g_GWB_CoreFlags, $GWB_SF_PLAYER_VALID) <> 0
EndFunc

;~ Calls the classic GWA2 function with the integration guard bypassed. Returns SetError(3) if it does not exist.
Func __GWB_Classic($fn, $n = 0, $a1 = 0, $a2 = 0, $a3 = 0)
	$g_GWB_Stats[1] += 1
	$g_GWB_Bypass = True
	Local $r
	Switch $n
		Case 0
			$r = Call($fn)
		Case 1
			$r = Call($fn, $a1)
		Case 2
			$r = Call($fn, $a1, $a2)
		Case Else
			$r = Call($fn, $a1, $a2, $a3)
	EndSwitch
	Local $err = @error, $ext = @extended
	$g_GWB_Bypass = False
	If $err = 0xDEAD And $ext = 0xBEEF Then Return SetError(3, 0, 0)
	Return SetError($err, $ext, $r)
EndFunc

Func GWBridge_Core($field, $index = Default)
	If $index = Default Then Return DllStructGetData($g_GWB_tCore, $field)
	Return DllStructGetData($g_GWB_tCore, $field, $index)
EndFunc

Func GWBridge_Header($field)
	If Not $g_GWB_Attached Then Return 0
	Return DllStructGetData($g_GWB_tHdr, $field)
EndFunc

;~ Controls (written into the shared header, read by the DLL every frame)
Func GWBridge_SetAgentRange($range)
	If $g_GWB_Attached Then DllStructSetData($g_GWB_tHdr, 'agent_range', $range)
EndFunc

Func GWBridge_SetCommandsPerFrame($n)
	If $g_GWB_Attached Then DllStructSetData($g_GWB_tHdr, 'cmds_per_frame', $n)
EndFunc
#EndRegion Liveness + snapshot

; ----------------------------------------------------------------------------------------------
#Region Readers - GWA2 drop-ins (same signature and return type as the GWA2 function named after Bridge_)
; ----------------------------------------------------------------------------------------------

Func Bridge_GetMyID()
	If Not __GWB_Usable() Then Return __GWB_Classic('GetMyID')
	$g_GWB_Stats[0] += 1
	Return $g_GWB_CoreMyID
EndFunc

Func Bridge_GetMyAgent()
	If Not __GWB_Usable() Then Return __GWB_Classic('GetMyAgent')
	$g_GWB_Stats[0] += 1
	Local $agent = DllStructCreate($g_GWB_tplAgent)
	DllCall($g_GWB_k32, 'none', 'RtlMoveMemory', 'struct*', $agent, 'ptr', DllStructGetPtr($g_GWB_tCore, 'me'), 'ulong_ptr', DllStructGetSize($agent))
	Return $agent
EndFunc

;~ Full record if the agent is in the snapshot (player, party, target, anything within agent_range);
;~ otherwise the classic GWA2 read (far agents, or agents that do not exist: GWA2 then returns a zeroed struct).
Func Bridge_GetAgentByID($agentID)
	If Not __GWB_Usable() Then Return __GWB_Classic('GetAgentByID', 1, $agentID)
	If $agentID = -2 Or $agentID = $g_GWB_CoreMyID Then Return Bridge_GetMyAgent()
	For $try = 1 To 3
		Local $cur = $g_GWB_CoreSlot
		Local $rec = __GWB_FindRecord($cur, $agentID)
		If $rec < 0 Then ExitLoop
		Local $agent = DllStructCreate($g_GWB_tplAgent)
		DllCall($g_GWB_k32, 'none', 'RtlMoveMemory', 'struct*', $agent, 'ptr', $g_GWB_pSlot[$cur] + $GWB_SLOT_OFF_AGENTS + $rec * $GWB_AGENT_STRIDE, 'ulong_ptr', DllStructGetSize($agent))
		; the slot may have been recycled by the writer while we copied (only after 2 newer frames): re-check
		If DllStructGetData($g_GWB_tSeq[$cur], 1) = $g_GWB_CoreSeq Then
			$g_GWB_Stats[0] += 1
			Return $agent
		EndIf
		$g_GWB_Stats[2] += 1
		$g_GWB_CoreFrame = -1
		If Not __GWB_Usable() Then ExitLoop
	Next
	Return __GWB_Classic('GetAgentByID', 1, $agentID)
EndFunc

;~ Record index in slot $cur, or -1. Probes the open-addressing table the DLL built.
Func __GWB_FindRecord($cur, $agentID)
	Local $h = BitAND($agentID, $GWB_HASH_SIZE - 1)
	For $probe = 0 To $GWB_HASH_SIZE - 1
		Local $v = DllStructGetData($g_GWB_tHash[$cur], 1, BitAND($h + $probe, $GWB_HASH_SIZE - 1) + 1)
		If $v = 0 Then Return -1
		If DllStructGetData($g_GWB_tAgentIds[$cur], 1, ($v - 1) * 114 + 12) = $agentID Then Return $v - 1
	Next
	Return -1
EndFunc

Func Bridge_GetAgentExists($agentID)
	If Not __GWB_Usable() Then Return __GWB_Classic('GetAgentExists', 1, $agentID)
	If $agentID = DllStructGetData($g_GWB_tCore, 'my_id') Then Return True
	If __GWB_FindRecord($g_GWB_CoreSlot, $agentID) >= 0 Then Return True
	Return __GWB_Classic('GetAgentExists', 1, $agentID)   ; far agent: ask the game
EndFunc

;~ GWA2 semantics kept exactly, including its type filter. Served from the snapshot only when the snapshot
;~ holds every agent the classic call would return (not truncated, and agent_range = 0 meaning "whole map");
;~ otherwise classic. With the default range (5000) this therefore stays classic - see BRIDGE.md decision D2.
Func Bridge_GetAgentArray($type = 0)
	If Not __GWB_Usable() Then Return __GWB_Classic('GetAgentArray', 1, $type)
	If DllStructGetData($g_GWB_tCore, 'range') <> 0 Or BitAND(DllStructGetData($g_GWB_tCore, 'flags'), $GWB_SF_TRUNCATED) Then Return __GWB_Classic('GetAgentArray', 1, $type)
	Return Bridge_GetNearbyAgentArray($type)
EndFunc

;~ Bridge-only: agents with a full record in the current frame (within agent_range + party + target).
;~ Same type filter as GWA2 GetAgentArray. One copy of all records, then one struct per agent.
Func Bridge_GetNearbyAgentArray($type = 0)
	Local $empty[0]
	If Not __GWB_Usable() Then Return $empty
	Local $cur = $g_GWB_CoreSlot
	Local $n = DllStructGetData($g_GWB_tCore, 'agent_count')
	If $n <= 0 Then Return $empty
	Local $buf = DllStructCreate('byte[' & ($n * $GWB_AGENT_STRIDE) & ']')
	DllCall($g_GWB_k32, 'none', 'RtlMoveMemory', 'struct*', $buf, 'ptr', $g_GWB_pSlot[$cur] + $GWB_SLOT_OFF_AGENTS, 'ulong_ptr', $n * $GWB_AGENT_STRIDE)
	If DllStructGetData($g_GWB_tSeq[$cur], 1) <> $g_GWB_CoreSeq Then
		$g_GWB_Stats[2] += 1
		$g_GWB_CoreFrame = -1
		If Not __GWB_Usable() Then Return $empty
		Return Bridge_GetNearbyAgentArray($type)
	EndIf
	Local $out[$n], $count = 0, $base = DllStructGetPtr($buf)
	For $i = 0 To $n - 1
		Local $s = DllStructCreate($g_GWB_tplAgent)
		DllCall($g_GWB_k32, 'none', 'RtlMoveMemory', 'struct*', $s, 'ptr', $base + $i * $GWB_AGENT_STRIDE, 'ulong_ptr', DllStructGetSize($s))
		Local $t = DllStructGetData($s, 'Type')
		If $t <> 0 And $t <> $type Then ContinueLoop
		$out[$count] = $s
		$count += 1
	Next
	ReDim $out[$count]
	$g_GWB_Stats[0] += 1
	Return $out
EndFunc

Func Bridge_GetMaxAgents()
	If Not __GWB_Usable() Then Return __GWB_Classic('GetMaxAgents')
	Return DllStructGetData($g_GWB_tCore, 'max_agents')
EndFunc

Func Bridge_GetMapID()
	If Not __GWB_Usable() Then Return __GWB_Classic('GetMapID')
	$g_GWB_Stats[0] += 1
	Return DllStructGetData($g_GWB_tCore, 'map_id')
EndFunc

Func Bridge_GetMapType()
	If Not __GWB_Usable() Then Return __GWB_Classic('GetMapType')
	$g_GWB_Stats[0] += 1
	Return DllStructGetData($g_GWB_tCore, 'instance_type')
EndFunc

;~ GWA2: GetAgentExists(GetMyID()). Bridge: player valid in the latest frame. During loading -> classic.
Func Bridge_GetMapIsLoaded()
	If Not __GWB_Usable() Then Return __GWB_Classic('GetMapIsLoaded')
	Return True
EndFunc

;~ Bridge-only: True while the latest frame says the game is on a loading screen (no syscall).
Func Bridge_IsLoading()
	If $g_GWB_Bypass Or Not GWBridge_Snapshot() Then Return SetError(1, 0, False)
	Return BitAND(DllStructGetData($g_GWB_tCore, 'flags'), $GWB_SF_LOADING) <> 0
EndFunc

Func Bridge_GetCurrentTargetID()
	If Not __GWB_Usable() Then Return __GWB_Classic('GetCurrentTargetID')
	$g_GWB_Stats[0] += 1
	Return DllStructGetData($g_GWB_tCore, 'target_id')
EndFunc

Func Bridge_GetCurrentTarget()
	Local $id = Bridge_GetCurrentTargetID()
	Return $id == 0 ? Null : Bridge_GetAgentByID($id)
EndFunc

Func Bridge_GetHeroCount()
	If Not __GWB_Usable() Or BitAND(DllStructGetData($g_GWB_tCore, 'flags'), $GWB_SF_PARTY_VALID) = 0 Then Return __GWB_Classic('GetHeroCount')
	$g_GWB_Stats[0] += 1
	Return DllStructGetData($g_GWB_tCore, 'hero_count')
EndFunc

Func Bridge_GetHeroID($heroIndex)
	If Not __GWB_Usable() Or BitAND(DllStructGetData($g_GWB_tCore, 'flags'), $GWB_SF_PARTY_VALID) = 0 Then Return __GWB_Classic('GetHeroID', 1, $heroIndex)
	$g_GWB_Stats[0] += 1
	If $heroIndex == 0 Then Return DllStructGetData($g_GWB_tCore, 'my_id')
	If $heroIndex < 1 Or $heroIndex > DllStructGetData($g_GWB_tCore, 'hero_count') Then Return 0
	Return DllStructGetData($g_GWB_tCore, 'heroes', ($heroIndex - 1) * 4 + 1)
EndFunc

Func Bridge_GetPartyState($flag)
	If Not __GWB_Usable() Then Return __GWB_Classic('GetPartyState', 1, $flag)
	Return BitAND(DllStructGetData($g_GWB_tCore, 'party_flags'), $flag) > 0
EndFunc

;~ Skillbar struct ($SKILLBAR_STRUCT_TEMPLATE) of the player (0) or hero index, bytes identical to GWA2's read.
Func Bridge_GetSkillbar($heroIndex = 0)
	If Not __GWB_Usable() Or $heroIndex < 0 Or $heroIndex >= DllStructGetData($g_GWB_tCore, 'skillbar_count') Then Return __GWB_Classic('GetSkillbar', 1, $heroIndex)
	$g_GWB_Stats[0] += 1
	Local $sb = DllStructCreate($g_GWB_tplSkillbar)
	DllCall($g_GWB_k32, 'none', 'RtlMoveMemory', 'struct*', $sb, 'ptr', DllStructGetPtr($g_GWB_tCore, 'skillbars') + $heroIndex * $GWB_SKILLBAR_RAW, 'ulong_ptr', DllStructGetSize($sb))
	Return $sb
EndFunc

;~ True if recharged. Exactly GWA2's IsSkillRecharged() rule on the same raw 'Recharge' value:
;~ recharge = 0 -> True, else (recharge - GetSkillTimer()) = 0. Only the source of the bytes changes.
Func Bridge_IsRecharged($skillSlot, $heroIndex = 0)
	If Not __GWB_Usable() Or $heroIndex < 0 Or $heroIndex >= DllStructGetData($g_GWB_tCore, 'skillbar_count') Or $skillSlot < 1 Or $skillSlot > 8 Then _
			Return __GWB_Classic('IsRecharged', 2, $skillSlot, $heroIndex)
	$g_GWB_Stats[0] += 1
	Local $recharge = DllStructGetData($g_GWB_tCoreSkill, 1, $heroIndex * 47 + 4 + ($skillSlot - 1) * 5)
	If $recharge == 0 Then Return True
	Return BitAND($recharge - Bridge_GetSkillTimer(), 0xFFFFFFFF) == 0
EndFunc

;~ Bridge-only: milliseconds until the skill is ready (0 = ready), as of the latest frame.
Func Bridge_GetRechargeRemaining($skillSlot, $heroIndex = 0)
	If Not __GWB_Usable() Then Return SetError(1, 0, -1)
	Return DllStructGetData($g_GWB_tCore, 'recharge_ms', $heroIndex * 8 + $skillSlot)
EndFunc

Func Bridge_GetSkillbarSkillID($skillSlot, $heroIndex = 0)
	Return DllStructGetData(Bridge_GetSkillbar($heroIndex), 'SkillID' & $skillSlot)
EndFunc

Func Bridge_GetSkillbarSkillAdrenaline($skillSlot, $heroIndex = 0)
	Return DllStructGetData(Bridge_GetSkillbar($heroIndex), 'AdrenalineA' & $skillSlot)
EndFunc

;~ GWA2 GetSkillTimer() = GetTickCount + game offset. Bridge: value at capture + elapsed ticks.
Func Bridge_GetSkillTimer()
	If Not __GWB_Usable() Then Return __GWB_Classic('GetSkillTimer')
	Local $now = DllCall($g_GWB_k32, 'dword', 'GetTickCount')[0]
	Return BitAND(DllStructGetData($g_GWB_tCore, 'skill_timer') + ($now - DllStructGetData($g_GWB_tCore, 'tick')), 0xFFFFFFFF)
EndFunc

; ---- compact player fields (bridge-only, no struct creation at all) ----
Func Bridge_GetMyXY()
	Local $xy[2] = [0, 0]
	If Not __GWB_Usable() Then
		Local $me = __GWB_Classic('GetMyAgent')
		$xy[0] = DllStructGetData($me, 'X')
		$xy[1] = DllStructGetData($me, 'Y')
		Return $xy
	EndIf
	$xy[0] = DllStructGetData($g_GWB_tCore, 'my_x')
	$xy[1] = DllStructGetData($g_GWB_tCore, 'my_y')
	Return $xy
EndFunc

;~ Same formula as GWA2 GetEnergy()/GetHealth() with no argument (percent * max).
Func Bridge_GetMyEnergy()
	If Not __GWB_Usable() Then Return __GWB_Classic('GetEnergy')
	Return DllStructGetData($g_GWB_tCore, 'my_energy') * DllStructGetData($g_GWB_tCore, 'my_max_energy')
EndFunc

Func Bridge_GetMyHealth()
	If Not __GWB_Usable() Then Return __GWB_Classic('GetHealth')
	Return DllStructGetData($g_GWB_tCore, 'my_hp') * DllStructGetData($g_GWB_tCore, 'my_max_hp')
EndFunc

Func Bridge_GetMyIsDead()
	If Not __GWB_Usable() Then Return BitAND(DllStructGetData(__GWB_Classic('GetMyAgent'), 'Effects'), 0x0010) > 0
	Return BitAND(DllStructGetData($g_GWB_tCore, 'my_effects'), 0x0010) > 0
EndFunc
#EndRegion Readers

; ----------------------------------------------------------------------------------------------
#Region Bags (refreshed by the DLL only when the inventory changes)
; ----------------------------------------------------------------------------------------------

;~ Copies the current bag snapshot locally if a newer one was published. Returns the bag-slot index used, or -1.
Func __GWB_BagSnapshot()
	If Not __GWB_Usable() Then Return -1
	Local $counter = DllStructGetData($g_GWB_tHdr, 'bag_counter')
	If $counter = 0 Then Return -1
	If $counter = $g_GWB_BagCounter Then Return 1
	For $try = 1 To 4
		Local $cur = BitAND(DllStructGetData($g_GWB_tHdr, 'current_bag_slot'), 1)
		$counter = DllStructGetData($g_GWB_tHdr, 'bag_counter')
		Local $s1 = DllStructGetData($g_GWB_tBagHead[$cur], 'seq')
		If BitAND($s1, 1) = 0 Then
			DllCall($g_GWB_k32, 'none', 'RtlMoveMemory', 'struct*', $g_GWB_tBagLocal, 'ptr', $g_GWB_pBag[$cur], 'ulong_ptr', $GWB_BAG_SLOT_SIZE)
			If DllStructGetData($g_GWB_tBagHead[$cur], 'seq') = $s1 Then
				$g_GWB_BagCounter = $counter
				Return 1
			EndIf
		EndIf
		$g_GWB_Stats[2] += 1
	Next
	Return -1
EndFunc

Func __GWB_BagPos($bagIndex)
	For $i = 0 To 5
		If $GWB_BAG_IDS[$i] = $bagIndex Then Return $i
	Next
	Return -1
EndFunc

;~ GWA2 GetBag($bagIndex): bag struct, or Null if the bag does not exist. Bags 1-5 and 22 from the bridge, others classic.
Func Bridge_GetBag($bagIndex)
	Local $pos = __GWB_BagPos($bagIndex)
	If $pos < 0 Or __GWB_BagSnapshot() < 0 Then Return __GWB_Classic('GetBag', 1, $bagIndex)
	Local $pInfo = DllStructGetPtr($g_GWB_tBagLocal) + $GWB_BAG_OFF_INFO + $pos * $GWB_BAG_INFO_SIZE
	Local $info = DllStructCreate('dword bag_id;dword present;dword slots;dword items_count', $pInfo)
	If DllStructGetData($info, 'present') = 0 Then Return Null
	Local $bag = DllStructCreate($g_GWB_tplBag)
	DllCall($g_GWB_k32, 'none', 'RtlMoveMemory', 'struct*', $bag, 'ptr', $pInfo + 16, 'ulong_ptr', DllStructGetSize($bag))
	$g_GWB_Stats[0] += 1
	Return $bag
EndFunc

;~ GWA2 GetItemBySlot($bagIndex, $slot): item struct, or 0 for an empty slot (same as GWA2).
Func Bridge_GetItemBySlot($bagIndex, $slot)
	Local $pos = __GWB_BagPos($bagIndex)
	If $pos < 0 Or $slot < 1 Or $slot > $GWB_BAG_SLOTS Or __GWB_BagSnapshot() < 0 Then Return __GWB_Classic('GetItemBySlot', 2, $bagIndex, $slot)
	Local $info = DllStructCreate('dword bag_id;dword present;dword slots', DllStructGetPtr($g_GWB_tBagLocal) + $GWB_BAG_OFF_INFO + $pos * $GWB_BAG_INFO_SIZE)
	If DllStructGetData($info, 'present') = 0 Or $slot > DllStructGetData($info, 'slots') Then Return 0
	Local $p = DllStructGetPtr($g_GWB_tBagLocal) + $GWB_BAG_OFF_ITEMS + ($pos * $GWB_BAG_SLOTS + $slot - 1) * $GWB_ITEM_RAW
	If DllStructGetData(DllStructCreate('dword', $p), 1) = 0 Then Return 0
	Local $item = DllStructCreate($g_GWB_tplItem)
	DllCall($g_GWB_k32, 'none', 'RtlMoveMemory', 'struct*', $item, 'ptr', $p, 'ulong_ptr', DllStructGetSize($item))
	$g_GWB_Stats[0] += 1
	Return $item
EndFunc

;~ Bridge-only: number of bag snapshots the DLL has published (changes exactly when the inventory changed).
Func Bridge_GetBagCounter()
	If Not $g_GWB_Attached Then Return -1
	Return DllStructGetData($g_GWB_tHdr, 'bag_counter')
EndFunc
#EndRegion Bags

; ----------------------------------------------------------------------------------------------
#Region Commands
; ----------------------------------------------------------------------------------------------

;~ Low level: returns the ring index of the queued command, or -1 (not live, ring full, re-entered from an Adlib).
Func __GWB_Enqueue($op, $a0 = 0, $a1 = 0, $a2 = 0, $a3 = 0, $force = False, $floats = False)
	If Not $g_GWB_Attached Then Return -1
	If Not $force And Not GWBridge_IsLive() Then Return -1
	If $g_GWB_CmdBusy Then Return -1                ; an Adlib interrupted a write in progress: caller falls back
	$g_GWB_CmdBusy = True
	Local $w = DllStructGetData($g_GWB_tRing, 'write_idx')
	If BitAND($w - DllStructGetData($g_GWB_tRing, 'read_idx'), 0xFFFFFFFF) >= $GWB_CMD_CAPACITY Then
		$g_GWB_CmdBusy = False
		Return -1
	EndIf
	Local $i = BitAND($w, $GWB_CMD_CAPACITY - 1)
	Local $c = $g_GWB_tCmd[$i]
	DllStructSetData($c, 'state', $GWB_CS_FREE)
	DllStructSetData($c, 'id', $g_GWB_NextCmdId)
	DllStructSetData($c, 'op', $op)
	If $floats Then
		DllStructSetData($g_GWB_tCmdF[$i], 'argf', $a0, 1)
		DllStructSetData($g_GWB_tCmdF[$i], 'argf', $a1, 2)
	Else
		DllStructSetData($c, 'arg', $a0, 1)
		DllStructSetData($c, 'arg', $a1, 2)
	EndIf
	DllStructSetData($c, 'arg', $a2, 3)
	DllStructSetData($c, 'arg', $a3, 4)
	DllStructSetData($c, 'result', 0)
	DllStructSetData($c, 'state', $GWB_CS_QUEUED)      ; x86 keeps these stores in order
	DllStructSetData($g_GWB_tRing, 'write_idx', BitAND($w + 1, 0xFFFFFFFF))
	$g_GWB_NextCmdId = ($g_GWB_NextCmdId >= 0x7FFFFFFF) ? 1 : $g_GWB_NextCmdId + 1
	$g_GWB_Stats[3] += 1
	$g_GWB_CmdBusy = False
	Return $w
EndFunc

;~ Waits for a queued command. Returns the final state ($GWB_CS_*), or 0 on timeout. @extended = result value.
Func GWBridge_WaitCommand($idx, $timeoutMs = 1000)
	Local $c = $g_GWB_tCmd[BitAND($idx, $GWB_CMD_CAPACITY - 1)]
	Local $t = TimerInit()
	While TimerDiff($t) < $timeoutMs
		Local $st = DllStructGetData($c, 'state')
		If $st >= $GWB_CS_DONE Then Return SetExtended(DllStructGetData($c, 'result'), $st)
		Sleep(1)
	WEnd
	Return 0
EndFunc

Func Bridge_Ping($value = 1, $timeoutMs = 1000)
	Local $idx = __GWB_Enqueue($GWB_OP_PING, $value)
	If $idx < 0 Then Return SetError(1, 0, False)
	Local $st = GWBridge_WaitCommand($idx, $timeoutMs)
	Return $st = $GWB_CS_DONE And @extended = $value
EndFunc

; ---- GWA2 drop-ins: same arguments/returns, fire-and-forget like GWA2's Enqueue/SendPacket ----

;~ GWA2 Move($X, $Y): True if the player exists and the move was queued.
Func Bridge_Move($X, $Y)
	If Not __GWB_Usable() Then Return __GWB_Classic('Move', 2, $X, $Y)
	If __GWB_Enqueue($GWB_OP_MOVE, $X, $Y, 0, 0, False, True) < 0 Then Return __GWB_CmdFallback('Move', 2, $X, $Y)
	Return True
EndFunc

;~ GWA2 UseSkill($skillSlot, $target = Null, $callTarget = False). Null target = self, like GWA2.
Func Bridge_UseSkill($skillSlot, $target = Null, $callTarget = False)
	If Not __GWB_Usable() Then Return __GWB_Classic('UseSkill', 3, $skillSlot, $target, $callTarget)
	Local $targetID = ($target == Null) ? DllStructGetData($g_GWB_tCore, 'my_id') : DllStructGetData($target, 'ID')
	If __GWB_Enqueue($GWB_OP_USE_SKILL, $skillSlot, $targetID) < 0 Then Return __GWB_CmdFallback('UseSkill', 3, $skillSlot, $target, $callTarget)
EndFunc

;~ GWA2 ChangeTarget($agent)
Func Bridge_ChangeTarget($agent)
	If Not __GWB_Usable() Then Return __GWB_Classic('ChangeTarget', 1, $agent)
	If __GWB_Enqueue($GWB_OP_CHANGE_TARGET, DllStructGetData($agent, 'ID')) < 0 Then Return __GWB_CmdFallback('ChangeTarget', 1, $agent)
EndFunc

;~ GWA2 Attack($agent, $callTarget = False) -> GWCA InteractAgent (attack for foes)
Func Bridge_Attack($agent, $callTarget = False)
	If Not __GWB_Usable() Then Return __GWB_Classic('Attack', 2, $agent, $callTarget)
	If __GWB_Enqueue($GWB_OP_INTERACT, DllStructGetData($agent, 'ID'), $callTarget ? 1 : 0) < 0 Then Return __GWB_CmdFallback('Attack', 2, $agent, $callTarget)
	Return True
EndFunc

;~ GWA2 GoNPC($agent) / GoPlayer($agent) -> GWCA InteractAgent
Func Bridge_GoNPC($agent)
	If Not __GWB_Usable() Then Return __GWB_Classic('GoNPC', 1, $agent)
	If __GWB_Enqueue($GWB_OP_INTERACT, DllStructGetData($agent, 'ID'), 0) < 0 Then Return __GWB_CmdFallback('GoNPC', 1, $agent)
	Return True
EndFunc

;~ GWA2 PickUpItem($item): item struct, uses its AgentID (the item lying on the ground)
Func Bridge_PickUpItem($item)
	If Not __GWB_Usable() Then Return __GWB_Classic('PickUpItem', 1, $item)
	If __GWB_Enqueue($GWB_OP_PICK_UP, DllStructGetData($item, 'AgentID'), 0) < 0 Then Return __GWB_CmdFallback('PickUpItem', 1, $item)
	Return True
EndFunc

;~ GWA2 UseItem($item)
Func Bridge_UseItem($item)
	If Not __GWB_Usable() Then Return __GWB_Classic('UseItem', 1, $item)
	If __GWB_Enqueue($GWB_OP_USE_ITEM, DllStructGetData($item, 'ID')) < 0 Then Return __GWB_CmdFallback('UseItem', 1, $item)
	Return True
EndFunc

;~ GWA2 Dialog($dialogID)
Func Bridge_Dialog($dialogID)
	If Not __GWB_Usable() Then Return __GWB_Classic('Dialog', 1, $dialogID)
	If __GWB_Enqueue($GWB_OP_DIALOG, $dialogID) < 0 Then Return __GWB_CmdFallback('Dialog', 1, $dialogID)
	Return True
EndFunc

Func __GWB_CmdFallback($fn, $n, $a1 = 0, $a2 = 0, $a3 = 0)
	$g_GWB_Stats[4] += 1
	Return __GWB_Classic($fn, $n, $a1, $a2, $a3)
EndFunc
#EndRegion Commands

;~ Human-readable state for logs / the BotsHub console.
Func GWBridge_Describe()
	If Not $g_GWB_Attached Then Return 'GWBridge: not attached' & ($g_GWB_LastError <> '' ? ' (' & $g_GWB_LastError & ')' : '')
	Local $h = $g_GWB_tHdr
	Return StringFormat('GWBridge: %s status=0x%X err=%d %s frames=%d skipped=%d cost=%dus(max %d) bags=%d live=%s hits=%d classic=%d retries=%d cmds=%d', _
			DllStructGetData($h, 'build'), DllStructGetData($h, 'status'), DllStructGetData($h, 'last_error'), DllStructGetData($h, 'diag'), _
			DllStructGetData($h, 'frame_counter'), DllStructGetData($h, 'skipped_frames'), DllStructGetData($h, 'frame_cost_us_avg'), _
			DllStructGetData($h, 'frame_cost_us_max'), DllStructGetData($h, 'bag_counter'), GWBridge_IsLive(), _
			$g_GWB_Stats[0], $g_GWB_Stats[1], $g_GWB_Stats[2], $g_GWB_Stats[3])
EndFunc
