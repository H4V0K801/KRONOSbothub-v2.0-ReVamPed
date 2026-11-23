#CS ===========================================================================
; Author: gigi, tjubutsi, Greg-76
; Modified by: MrZambix, Night, Gahais, and more
; This file contains global GWA2 logics and variables
#CE ===========================================================================

#include-once
; v30: reason the last WaitMapReady/IsMapReadyNow sample was not ready (declared before the includes: Utils.au3 reads it)
Global $map_ready_last_reason = ''

#include 'GWA2_Assembly.au3'
#include 'GWA2_Headers.au3'
#include 'GWA2_ID_Items.au3'
#include 'GWA2_ID_Maps.au3'
#include 'GWA2_ID.au3'
#include 'Utils.au3'
#include 'Utils-Console.au3'
#include 'Utils-Debugger.au3'
#include 'Utils-Storage.au3'

; Required for memory access, opening external process handles and injecting code
#RequireAdmin

; Additional directives
#Region		;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile_type=a3x
#AutoIt3Wrapper_Run_AU3Check=n
#AutoIt3Wrapper_Run_Tidy=y
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/pe /sf /tl
#EndRegion	;**** Directives created by AutoIt3Wrapper_GUI ****


#Region Declarations
; Flags
Global $rendering_enabled = True

; Game memory - base address and queue
Global $base_address_ptr, $queue_counter, $queue_size, $queue_base_address

; Global game variables
Global $pre_game_address
Global $disable_rendering_address
Global $ping_address
Global $status_code_address

; Agents
Global $my_ID
Global $current_target_agent_ID
Global $agent_base_address
Global $max_agents, $agent_copy_count, $agent_copy_base

; Skills
Global $attribute_info_ptr
Global $skill_base_address
Global $skill_timer_address

; Map
Global $region_ID, $instance_info_ptr, $area_info_ptr
Global $map_is_loaded_ptr

; Trader system
Global $trader_quote_ID, $trader_cost_ID, $trader_cost_value
Global $trade_partner_ptr
Global $craft_item_ptr
Global $collector_exchange_ptr

Global $scene_context_ptr
Global $time_on_map_ptr

;EncString Decoding
; Pointer to encoded string input buffer in GW memory
Global $decode_input_ptr
; Pointer to decoded string output buffer in GW memory
Global $decode_output_ptr
; Pointer to ready flag in GW memory
Global $decode_ready
; Command struct: ptr to command + encoded string
Global $decode_enc_string = DllStructCreate('ptr;wchar[128]')
Global $decode_enc_string_ptr = DllStructGetPtr($decode_enc_string)

; Other
Global $friend_list_address
#EndRegion Declarations


#CS ==========================================================================
Movement
Combat and interaction
Skills and builds
Travel
Targeting
Agents
Heroes and Mercenaries
Party
Items
Item manipulations
NPC Trade
Player Trade
Quest
Titles
Factions
Display
Windows
Chat
Builds and Templates
Miscellaneous
#CE ==========================================================================


#Region Movement
;~ Move to a random location around the given coordinates. Returns True if successful
Func MoveRadial($x, $y, $distance)
	Local Static $directionIndex = Random(0, 7, 1)
	Local $angle = $directionIndex * $PI / 4
	$directionIndex = Mod($directionIndex + 1, 8)
	Return Move($x + $distance * Cos($angle), $y + $distance * Sin($angle))
EndFunc


;~ Avoid usage, it is a square around the original position, making it awkward, it can also not add any random
;~ Move to a random location around the given coordinates. Returns True if successful
Func RandomMove($X, $Y, $random = 50)
	Return Move($X + Random(-$random, $random), $Y + Random(-$random, $random))
EndFunc


;~ Move to a location. Returns True if successful
Func Move($X, $Y)
	; GWBridge (opt-in, phase B)
	If $g_GWB_HookCommands And Not $g_GWB_Bypass Then Return Bridge_Move($X, $Y)
	If GetAgentExists(GetMyID()) Then
		DllStructSetData($MOVE_STRUCT, 2, $X)
		DllStructSetData($MOVE_STRUCT, 3, $Y)
		Enqueue($MOVE_STRUCT_PTR, 16)
		Return True
	Else
		Return False
	EndIf
EndFunc


;~ Run to or follow a player.
Func GoPlayer($agent)
	Return SendPacket(0x8, $HEADER_INTERACT_PLAYER , DllStructGetData($agent, 'ID'))
EndFunc


;~ Talk to an NPC
Func GoNPC($agent)
	; GWBridge (opt-in, phase B)
	If $g_GWB_HookCommands And Not $g_GWB_Bypass Then Return Bridge_GoNPC($agent)
	Return SendPacket(0xC, $HEADER_INTERACT_NPC, DllStructGetData($agent, 'ID'))
EndFunc


;~ Run to a signpost.
Func GoSignpost($agent)
	Return SendPacket(0xC, $HEADER_SIGNPOST_RUN, DllStructGetData($agent, 'ID'), 0)
EndFunc


;~ Turn character to the left.
Func TurnLeft($turn)
	Return PerformAction(0xA2, $turn ? $CONTROL_TYPE_ACTIVATE : $CONTROL_TYPE_DEACTIVATE)
EndFunc


;~ Turn character to the right.
Func TurnRight($turn)
	Return PerformAction(0xA3, $turn ? $CONTROL_TYPE_ACTIVATE : $CONTROL_TYPE_DEACTIVATE)
EndFunc


;~ Move backwards.
Func MoveBackward($move)
	Return PerformAction(0xAC, $move ? $CONTROL_TYPE_ACTIVATE : $CONTROL_TYPE_DEACTIVATE)
EndFunc


;~ Run forwards.
Func MoveForward($move)
	Return PerformAction(0xAD, $move ? $CONTROL_TYPE_ACTIVATE : $CONTROL_TYPE_DEACTIVATE)
EndFunc


;~ Strafe to the left.
Func StrafeLeft($strafe)
	Return PerformAction(0x91, $strafe ? $CONTROL_TYPE_ACTIVATE : $CONTROL_TYPE_DEACTIVATE)
EndFunc


;~ Strafe to the right.
Func StrafeRight($strafe)
	Return PerformAction(0x92, $strafe ? $CONTROL_TYPE_ACTIVATE : $CONTROL_TYPE_DEACTIVATE)
EndFunc


;~ Auto-run.
Func ToggleAutoRun()
	Return PerformAction(0xB7)
EndFunc


;~ Turn around.
Func ReverseDirection()
	Return PerformAction(0xB1)
EndFunc
#EndRegion Movement


#Region Combat and interaction
;~ Change weapon sets.
Func ChangeWeaponSet($weaponSet)
	Return PerformAction(0x80 + $weaponSet)
EndFunc


;~ Attack an agent.
Func Attack($agent, $callTarget = False)
	; GWBridge (opt-in, phase B)
	If $g_GWB_HookCommands And Not $g_GWB_Bypass Then Return Bridge_Attack($agent, $callTarget)
	Return SendPacket(0xC, $HEADER_ACTION_ATTACK, DllStructGetData($agent, 'ID'), $callTarget)
EndFunc


;~ Use a skill, does not wait for the skill to be done
;~ If no target is provided then skill is used on self
Func UseSkill($skillSlot, $target = Null, $callTarget = False)
	; GWBridge (opt-in, phase B)
	If $g_GWB_HookCommands And Not $g_GWB_Bypass Then Return Bridge_UseSkill($skillSlot, $target, $callTarget)
	Local $myID = GetMyID()
	Local $targetID = ($target == Null) ? $myID : DllStructGetData($target, 'ID')
	DllStructSetData($USE_SKILL_STRUCT, 2, $myID)
	DllStructSetData($USE_SKILL_STRUCT, 3, $skillSlot - 1)
	DllStructSetData($USE_SKILL_STRUCT, 4, $targetID)
	DllStructSetData($USE_SKILL_STRUCT, 5, $callTarget)
	Enqueue($USE_SKILL_STRUCT_PTR, 20)
EndFunc


;~ Order a hero to use a skill, does not wait for the skill to be done
;~ If no target is provided then skill is used on hero who uses the skill
Func UseHeroSkill($heroIndex, $skillSlot, $target = Null)
	Local $targetID = ($target == Null) ? GetHeroID($heroIndex) : DllStructGetData($target, 'ID')
	DllStructSetData($USE_HERO_SKILL_STRUCT, 2, GetHeroID($heroIndex))
	DllStructSetData($USE_HERO_SKILL_STRUCT, 3, $targetID)
	DllStructSetData($USE_HERO_SKILL_STRUCT, 4, $skillSlot - 1)
	Enqueue($USE_HERO_SKILL_STRUCT_PTR, 16)
EndFunc


Func IsCasting($agent)
	Local $modelState = DllStructGetData($agent, 'ModelState')
	Local $cast = DllStructGetData($agent, 'Skill')
	Local $isCasting = ($cast <> 0) Or ($modelState == 0x41) Or ($modelState == 0x245)
	Return $isCasting
EndFunc


;~ Cancel current action.
Func CancelAction()
	Return SendPacket(0x4, $HEADER_ACTION_CANCEL)
EndFunc


;~ Same as hitting spacebar.
Func ActionInteract()
	Return PerformAction(0x80)
EndFunc


;~ Follow a player.
Func ActionFollow()
	Return PerformAction(0xCC)
EndFunc


;~ Drop environment object.
Func DropBundle()
	Return PerformAction(0xCD)
EndFunc


;~ Suppress action.
Func SuppressAction($suppressAction)
	Return PerformAction(0xD0, $suppressAction ? $CONTROL_TYPE_ACTIVATE : $CONTROL_TYPE_DEACTIVATE)
EndFunc


;~ Open a chest.
Func OpenChest()
	Return SendPacket(0x8, $HEADER_OPEN_CHEST, 2)
EndFunc


;~ Opens the Xunlai storage window.
Func OpenXunlaiWindow()
	Enqueue($OPEN_XUNLAI_STRUCT_PTR, DllStructGetSize($OPEN_XUNLAI_STRUCT))
EndFunc


;~ Stop maintaining enchantment on target.
Func DropBuff($skillID, $agent, $heroIndex = 0)
	Local $buffCount = GetBuffCount($heroIndex)
	Local $buffStructAddress
	Local $offset1[] = [0, 0x18, 0x2C, 0x510]
	Local $processHandle = GetProcessHandle()
	Local $count = MemoryReadPtr($processHandle, $base_address_ptr, $offset1)

	Local $buffer
	Local $offset2[] = [0, 0x18, 0x2C, 0x508, 0]
	Local $buffStruct = SafeDllStructCreate($BUFF_STRUCT_TEMPLATE)
	For $i = 0 To $count[1] - 1
		$offset2[4] = 0x24 * $i
		$buffer = MemoryReadPtr($processHandle, $base_address_ptr, $offset2)
		If $buffer[1] == GetHeroID($heroIndex) Then
			Local $offset3[] = [0, 0x18, 0x2C, 0x508, 0x4 + 0x24 * $i, 0]
			For $j = 0 To $buffCount - 1
				$offset3[5] = 0 + 0x10 * $j
				$buffStructAddress = MemoryReadPtr($processHandle, $base_address_ptr, $offset3)
				SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', $processHandle, 'int', $buffStructAddress[0], 'ptr', DllStructGetPtr($buffStruct), 'int', DllStructGetSize($buffStruct), 'int', 0)
				If (DllStructGetData($buffStruct, 'SkillID') == $skillID) And (DllStructGetData($buffStruct, 'TargetID') == DllStructGetData($agent, 'ID')) Then
					Return SendPacket(0x8, $HEADER_BUFF_DROP, DllStructGetData($buffStruct, 'BuffID'))
					ExitLoop 2
				EndIf
			Next
		EndIf
	Next
EndFunc


;~ Open a dialog.
Func Dialog($dialogID)
	; GWBridge (opt-in, phase B)
	If $g_GWB_HookCommands And Not $g_GWB_Bypass Then Return Bridge_Dialog($dialogID)
	Return SendPacket(0x8, $HEADER_DIALOG_SEND, $dialogID)
EndFunc
#EndRegion Combat and interaction


#Region Skills and Builds
;~ Change a skill on the skillbar.
Func SetSkillbarSkill($slot, $skillID, $heroIndex = 0)
	Return SendPacket(0x14, $HEADER_SET_SKILLBAR_SKILL, GetHeroID($heroIndex), $slot - 1, $skillID, 0)
EndFunc


;~ Load all skills onto a skillbar simultaneously.
Func LoadSkillBar($skill1 = 0, $skill2 = 0, $skill3 = 0, $skill4 = 0, $skill5 = 0, $skill6 = 0, $skill7 = 0, $skill8 = 0, $heroIndex = 0)
	SendPacket(0x2C, $HEADER_LOAD_SKILLBAR, GetHeroID($heroIndex), 8, $skill1, $skill2, $skill3, $skill4, $skill5, $skill6, $skill7, $skill8)
EndFunc


;~ Increase attribute by 1
Func IncreaseAttribute($attributeID, $heroIndex = 0)
	DllStructSetData($INCREASE_ATTRIBUTE_STRUCT, 2, $attributeID)
	DllStructSetData($INCREASE_ATTRIBUTE_STRUCT, 3, GetHeroID($heroIndex))
	Enqueue($INCREASE_ATTRIBUTE_STRUCT_PTR, 12)
EndFunc


;~ Decrease attribute by 1
Func DecreaseAttribute($attributeID, $heroIndex = 0)
	DllStructSetData($DECREASE_ATTRIBUTE_STRUCT, 2, $attributeID)
	DllStructSetData($DECREASE_ATTRIBUTE_STRUCT, 3, GetHeroID($heroIndex))
	Enqueue($DECREASE_ATTRIBUTE_STRUCT_PTR, 12)
EndFunc


;~ Change your secondary profession.
Func ChangeSecondProfession($profession, $heroIndex = 0)
	Return SendPacket(0xC, $HEADER_PROFESSION_CHANGE, GetHeroID($heroIndex), $profession)
EndFunc


;~ Returns skillbar struct.
Func GetSkillbar($heroIndex = 0)
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetSkillbar($heroIndex)
	; v38.9: the skillbar array is resolved once per call (it was re-resolved for every entry), and the hero count is only
	; read when entry 0 is not the wanted bar (the player's bar is entry 0). Same structs, same order, same result.
	Local $processHandle = GetProcessHandle()
	Local $offset[] = [0, 0x18, 0x2C, 0x6F0, 0]
	Local $skillbarArray = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
	Local $wantedID = GetHeroID($heroIndex)
	Local $skillbarStruct, $i = 0, $heroCount = 0
	While $i <= $heroCount
		$skillbarStruct = DllStructCreate($SKILLBAR_STRUCT_TEMPLATE)
		; [0] = 0 when the chain could not be resolved: nothing is read (all-zero struct), exactly as before
		If $skillbarArray[0] <> 0 Then DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', $processHandle, 'ptr', $skillbarArray[0] + $i * 0xBC, 'struct*', $skillbarStruct, 'ulong_ptr', DllStructGetSize($skillbarStruct), 'ptr', 0)
		If DllStructGetData($skillbarStruct, 'AgentID') == $wantedID Then Return $skillbarStruct
		If $i == 0 Then $heroCount = GetHeroCount()
		$i += 1
	WEnd
EndFunc


;~ Returns skillbar struct with built-in address caching.
;Func GetSkillbar($heroIndex = 0, $cacheLifetimeMs = 10000)
;	Local Static $cachedHero = -1
;	Local Static $cachedSkillbarAddress = -1
;	Local Static $cacheTimestamp = 0
;
;	Local $skillbarStruct = SafeDllStructCreate($SKILLBAR_STRUCT_TEMPLATE)
;	Local $processHandle = GetProcessHandle()
;	; Check if we can use cached address
;	If $heroIndex <> $cachedHero Or TimerDiff($cacheTimestamp) > $cacheLifetimeMs Then
;		; Follow the pointer chain to find the address
;		Local $offset[] = [0, 0x18, 0x2C, 0x6F0, 0]
;		For $i = 0 To GetHeroCount()
;			$offset[4] = $i * 0xBC
;			Local $skillBarStructAddress = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
;			SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', $processHandle, 'int', $skillBarStructAddress[0], 'ptr', DllStructGetPtr($skillbarStruct), 'int', DllStructGetSize($skillbarStruct), 'int', 0)
;
;			If DllStructGetData($skillbarStruct, 'AgentID') == GetHeroID($heroIndex) Then
;				$cachedSkillbarAddress = $skillBarStructAddress[0]
;				$cachedHero = $heroIndex
;				$cacheTimestamp = TimerInit()
;				Return $skillbarStruct
;			EndIf
;		Next
;		If $cachedSkillbarAddress == 0 Then Return SetError(1, 0, 0)
;	EndIf
;	; Read the actual skillbar data
;	SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', $processHandle, 'int', $cachedSkillbarAddress, 'ptr', DllStructGetPtr($skillbarStruct), 'int', DllStructGetSize($skillbarStruct), 'int', 0)
;	Return $skillbarStruct
;EndFunc


;~ Returns the skill ID of an equipped skill.
Func GetSkillbarSkillID($skillSlot, $heroIndex = 0)
	Return DllStructGetData(GetSkillbar($heroIndex), 'SkillID' & $skillSlot)
EndFunc


;~ Returns the adrenaline charge of an equipped skill.
Func GetSkillbarSkillAdrenaline($skillSlot, $heroIndex = 0)
	Return DllStructGetData(GetSkillbar($heroIndex), 'AdrenalineA' & $skillSlot)
EndFunc


;~ Returns True if the skill at the given skillslot is recharged
Func IsRecharged($skillSlot, $heroIndex = 0)
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_IsRecharged($skillSlot, $heroIndex)
	Return IsSkillRecharged(GetSkillbar($heroIndex), $skillSlot)
EndFunc


;~ Return True if the skill from given skillbar at the given skillslot is recharged
Func IsSkillRecharged($skillbar, $skillSlot, $skillTimer = Null)
	Local $recharge = DllStructGetData($skillbar, 'Recharge' & $skillSlot)
	If $recharge == 0 Then Return True
	If $skillTimer == Null Then $skillTimer = GetSkillTimer()
	Return ($recharge - $skillTimer) == 0
EndFunc


;~ Returns skill struct.
Func GetSkillByID($skillID)
	Local $skillstructAddress = $skill_base_address + (0xA4 * $skillID)
	Local $skillStruct = SafeDllStructCreate($SKILL_STRUCT_TEMPLATE)
	SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', GetProcessHandle(), 'int', $skillstructAddress, 'ptr', DllStructGetPtr($skillStruct), 'int', DllStructGetSize($skillStruct), 'int', 0)
	Return $skillStruct
EndFunc


;~ Returns current number of buffs being maintained.
Func GetBuffCount($heroIndex = 0)
	Local $offset1[] = [0, 0x18, 0x2C, 0x510]
	Local $processHandle = GetProcessHandle()
	Local $count = MemoryReadPtr($processHandle, $base_address_ptr, $offset1)
	Local $buffer
	Local $offset2[] = [0, 0x18, 0x2C, 0x508, 0]
	For $i = 0 To $count[1] - 1
		$offset2[4] = 0x24 * $i
		$buffer = MemoryReadPtr($processHandle, $base_address_ptr, $offset2)
		If $buffer[1] == GetHeroID($heroIndex) Then
			Return MemoryRead($processHandle, $buffer[0] + 0xC)
		EndIf
	Next
	Return 0
EndFunc


;~ Tests if you are currently maintaining buff on target.
Func GetIsTargetBuffed($skillID, $agent, $heroIndex = 0)
	Local $buffCount = GetBuffCount($heroIndex)
	Local $buffStructAddress
	Local $offset1[] = [0, 0x18, 0x2C, 0x510]
	Local $processHandle = GetProcessHandle()
	Local $count = MemoryReadPtr($processHandle, $base_address_ptr, $offset1)
	Local $buffer
	Local $offset2[] = [0, 0x18, 0x2C, 0x508, 0]
	For $i = 0 To $count[1] - 1
		$offset2[4] = 0x24 * $i
		$buffer = MemoryReadPtr($processHandle, $base_address_ptr, $offset2)
		If $buffer[1] == GetHeroID($heroIndex) Then
			Local $offset3[] = [0, 0x18, 0x2C, 0x508, 0x4 + 0x24 * $i, 0]
			For $j = 0 To $buffCount - 1
				$offset3[5] = 0 + 0x10 * $j
				$buffStructAddress = MemoryReadPtr($processHandle, $base_address_ptr, $offset3)
				Local $buffStruct = SafeDllStructCreate($BUFF_STRUCT_TEMPLATE)
				SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', $processHandle, 'int', $buffStructAddress[0], 'ptr', DllStructGetPtr($buffStruct), 'int', DllStructGetSize($buffStruct), 'int', 0)
				If (DllStructGetData($buffStruct, 'SkillID') == $skillID) And DllStructGetData($buffStruct, 'TargetID') == DllStructGetData($agent, 'ID') Then Return $j + 1
			Next
		EndIf
	Next
	Return 0
EndFunc


;~ Returns buff struct.
Func GetBuffByIndex($buffIndex, $heroIndex = 0)
	Local $offset1[] = [0, 0x18, 0x2C, 0x510]
	Local $processHandle = GetProcessHandle()
	Local $count = MemoryReadPtr($processHandle, $base_address_ptr, $offset1)
	Local $offset2[] = [0, 0x18, 0x2C, 0x508, 0]
	Local $buffer
	For $i = 0 To $count[1] - 1
		$offset2[4] = 0x24 * $i
		$buffer = MemoryReadPtr($processHandle, $base_address_ptr, $offset2)
		If $buffer[1] == GetHeroID($heroIndex) Then
			Local $offset3[] = [0, 0x18, 0x2C, 0x508, 0x4 + 0x24 * $i, 0x10 * ($buffIndex - 1)]
			Local $buffStructAddress = MemoryReadPtr($processHandle, $base_address_ptr, $offset3)
			Local $buffStruct = SafeDllStructCreate($BUFF_STRUCT_TEMPLATE)
			SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', $processHandle, 'int', $buffStructAddress[0], 'ptr', DllStructGetPtr($buffStruct), 'int', DllStructGetSize($buffStruct), 'int', 0)
			Return $buffStruct
		EndIf
	Next
	Return 0
EndFunc


;~ Returns attribute struct.
Func GetAttributeInfoByID($attributeID)
	Local $attributeStructAddress = $attribute_info_ptr + (0x14 * $attributeID)
	Local $attributeStruct = SafeDllStructCreate($ATTRIBUTE_STRUCT_TEMPLATE)
	SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', GetProcessHandle(), 'int', $attributeStructAddress, 'ptr', DllStructGetPtr($attributeStruct), 'int', DllStructGetSize($attributeStruct), 'int', 0)
	Return $attributeStruct
EndFunc


;~ Returns profession associated with an attribute
Func GetAttributeProfession($attributeID)
	Local $attributeInfo = GetAttributeInfoByID($attributeID)
	Return DllStructGetData($attributeInfo, 'profession_ID')
EndFunc


;~ TODO: try this
Func GetAttributeNameID($attributeID)
	Local $attributeInfo = GetAttributeInfoByID($attributeID)
	Return DllStructGetData($attributeInfo, 'name_ID')
EndFunc


;~ TODO: try this
Func GetAttributeIsPvE($attributeID)
	Local $attributeInfo = GetAttributeInfoByID($attributeID)
	Return DllStructGetData($attributeInfo, 'is_pve')
EndFunc


;~ Returns effect struct or array of effects.
Func GetEffect($skillID = 0, $agentID = GetMyID())
	; v38.9: the agent-effects array is read in ONE read and the matching agent's effect list in ONE read (they were read
	; one dword / one effect at a time, re-resolving a 5-level chain for each). Same structs, same order, same result.
	; Anything unusual (unreadable array, implausible counts, agent ID 0, a failed bulk read) takes the old path unchanged.
	Local $processHandle = GetProcessHandle()
	Local $offset1[] = [0, 0x18, 0x2C, 0x510]
	Local $count = MemoryReadPtr($processHandle, $base_address_ptr, $offset1)
	If $count[1] <= 0 Then Return Null
	Local $offset2[] = [0, 0x18, 0x2C, 0x508]
	Local $array = MemoryReadPtr($processHandle, $base_address_ptr, $offset2)
	If $array[1] == 0 Or $count[1] > 4096 Or $agentID == 0 Then Return GetEffectEntryByEntry($skillID, $agentID)
	Local $entries = DllStructCreate('dword[' & (9 * $count[1]) & ']')
	Local $result = DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', $processHandle, 'ptr', $array[1], 'struct*', $entries, 'ulong_ptr', 0x24 * $count[1], 'ptr', 0)
	If @error Or Not $result[0] Then Return GetEffectEntryByEntry($skillID, $agentID)
	For $i = 0 To $count[1] - 1
		If DllStructGetData($entries, 1, 9 * $i + 1) <> $agentID Then ContinueLoop
		Local $effectCount = DllStructGetData($entries, 1, 9 * $i + 8)
		Local $effectsPtr = DllStructGetData($entries, 1, 9 * $i + 6)
		If $effectCount > 4096 Then Return GetEffectEntryByEntry($skillID, $agentID)
		Local $effects = Null
		If $effectsPtr <> 0 And $effectCount > 0 Then
			$effects = DllStructCreate('byte[' & (24 * $effectCount) & ']')
			$result = DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', $processHandle, 'ptr', $effectsPtr, 'struct*', $effects, 'ulong_ptr', 24 * $effectCount, 'ptr', 0)
			If @error Or Not $result[0] Then Return GetEffectEntryByEntry($skillID, $agentID)
		EndIf
		If $skillID = 0 Then
			Local $resultArray[$effectCount]
			For $j = 0 To $effectCount - 1
				$resultArray[$j] = EffectStructFromBuffer($effects, $j)
			Next
			Return $resultArray
		EndIf
		If $effects == Null Then ContinueLoop
		For $j = 0 To $effectCount - 1
			If DllStructGetData(DllStructCreate('long', DllStructGetPtr($effects) + 24 * $j), 1) == $skillID Then Return EffectStructFromBuffer($effects, $j)
		Next
	Next
	Return Null
EndFunc


;~ v38.9: a fresh effect struct holding effect $index of a bulk-read effect list (all zero when the list is Null)
Func EffectStructFromBuffer($effects, $index)
	Local $effectStruct = DllStructCreate($EFFECT_STRUCT_TEMPLATE)
	If $effects == Null Then Return $effectStruct
	Local $view = DllStructCreate('byte[24]', DllStructGetPtr($effects) + 24 * $index)
	DllStructSetData(DllStructCreate('byte[24]', DllStructGetPtr($effectStruct)), 1, DllStructGetData($view, 1))
	Return $effectStruct
EndFunc


;~ v38.9: the pre-v38.9 GetEffect, unchanged: entry by entry, effect by effect. Used only by GetEffect for unusual cases.
Func GetEffectEntryByEntry($skillID, $agentID)
	Local $effectCount, $effectStructAddress
	; Offsets have to be kept separate - else we risk cross-call contamination - Avoid ReDim !
	Local $offset1[] = [0, 0x18, 0x2C, 0x510]
	Local $processHandle = GetProcessHandle()
	Local $count = MemoryReadPtr($processHandle, $base_address_ptr, $offset1)
	Local $buffer
	For $i = 0 To $count[1] - 1
		Local $offset2[] = [0, 0x18, 0x2C, 0x508, 0x24 * $i]
		$buffer = MemoryReadPtr($processHandle, $base_address_ptr, $offset2)
		If $buffer[1] == $agentID Then
			Local $offset3[] = [0, 0x18, 0x2C, 0x508, 0x1C + 0x24 * $i]
			$effectCount = MemoryReadPtr($processHandle, $base_address_ptr, $offset3)

			Local $offset4[] = [0, 0x18, 0x2C, 0x508, 0x14 + 0x24 * $i, 0]
			$effectStructAddress = MemoryReadPtr($processHandle, $base_address_ptr, $offset4)

			If $skillID = 0 Then
				Local $resultArray[$effectCount[1]]
				For $j = 0 To $effectCount[1] - 1
					$resultArray[$j] = SafeDllStructCreate($EFFECT_STRUCT_TEMPLATE)
					$effectStructAddress[1] = $effectStructAddress[0] + 24 * $j
					SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', $processHandle, 'int', $effectStructAddress[1], 'ptr', DllStructGetPtr($resultArray[$j]), 'int', 24, 'int', 0)
				Next
				Return $resultArray
			Else
				For $j = 0 To $effectCount[1] - 1
					Local $effectStruct = SafeDllStructCreate($EFFECT_STRUCT_TEMPLATE)
					SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', $processHandle, 'int', $effectStructAddress[0] + 24 * $j, 'ptr', DllStructGetPtr($effectStruct), 'int', 24, 'int', 0)
					If DllStructGetData($effectStruct, 'SkillID') == $skillID Then Return $effectStruct
				Next
			EndIf
		EndIf
	Next
	Return Null
EndFunc


;~ Returns time remaining before an effect expires, in milliseconds.
Func GetEffectTimeRemaining($effect, $agentID = GetMyID())
	If Not IsDllStruct($effect) Then $effect = GetEffect($effect, $agentID)
	; if hero or player (0) is not under specified effect then 0 will be returned here
	If $effect == Null Then Return 0
	If IsArray($effect) Then Return 0

	Local $effectSkill = GetSkillByID(DllStructGetData($effect, 'SkillID'))
	Local $castTime = DllStructGetData($effectSkill, 'Activation') * 1000
	Local $aftercast = DllStructGetData($effectSkill, 'Aftercast') * 1000
	; full duration of effect in seconds, not remaining time
	Local $duration = DllStructGetData($effect, 'Duration') * 1000
	; timestamp when the effect was started
	Local $castTimeStamp = DllStructGetData($effect, 'TimeStamp')

	; Caution, noticed some	discrepancy between GetInstanceUpTime() and cast timestamps, difference can be negative surprisingly
	; Furthermore, other problem is that reapplying the effect does not always refresh its start timestamp until previous effect elapses
	; Therefore capping remaining effect time to be always bigger or equal to 1 with _Max() if there is still effect on hero/player
	Return _Max(1, $duration - (GetInstanceUpTime() - ($castTimeStamp + $castTime + $aftercast + GetPing())))
EndFunc


;~ Return the skill timer - shared timer for all skills
Func GetSkillTimer()
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetSkillTimer()
	Local Static $skillTimer = MemoryRead(GetProcessHandle(), $skill_timer_address, 'dword')
	Local $tickCount = DllCall($kernel_handle, 'dword', 'GetTickCount')[0]
	Return BitAND($tickCount + $skillTimer, 0xFFFFFFFF)
EndFunc


;~ Returns level of an attribute - takes runes into account | Thanks DukeFredek for fix !
Func GetAttributeByID($attributeID, $withRunes = False, $heroIndex = 0)
	Local $agentID = GetHeroID($heroIndex)
	Local $buffer
	Local $offset[] = [0, 0x18, 0x2C, 0xAC, 0]
	Local $processHandle = GetProcessHandle()
	For $i = 0 To GetHeroCount()
		$offset[4] = 0x43C * $i
		$buffer = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
		If $buffer[1] == $agentID Then
			$offset[4] = 0x43C * $i + 0x14 * $attributeID + ($withRunes ? 0xC : 0x8)
			$buffer = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
			Return $buffer[1]
		EndIf
	Next
EndFunc
#EndRegion Skills and Builds


#Region Travel
;~ Returns number of foes that have been killed so far.
Func GetFoesKilled()
	Local $offset[] = [0, 0x18, 0x2C, 0x84C]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc


;~ Returns number of enemies left to kill for vanquish.
Func GetFoesToKill()
	Local $offset[] = [0, 0x18, 0x2C, 0x850]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc


;~ Tests if an area has been vanquished.
Func GetAreaVanquished()
	Return GetFoesToKill() = 0
EndFunc


;~ Returns the instance type (city, explorable, mission, etc ...)
Func GetMapType()
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetMapType()
	Local $offset[] = [0x4]
	Local $result = MemoryReadPtr(GetProcessHandle(), $instance_info_ptr, $offset, 'dword')
	Return $result[1]
EndFunc


;~ Returns current map ID
Func GetMapID()
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetMapID()
	Local $offset[] = [0, 0x18, 0x44]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset, 'ptr')
	$result = MemoryRead(GetProcessHandle(), $result[1] + 0x198, 'long')
	Return $result
EndFunc


;~ Returns the area infos corresponding to the given map
Func GetAreaInfoByID($mapID = 0)
	If $mapID = 0 Then $mapID = GetMapID()

	Local $areaInfoAddress = $area_info_ptr + (0x7C * $mapID)
	Local $areaInfoStruct = SafeDllStructCreate($AREA_INFO_STRUCT_TEMPLATE)
	SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', GetProcessHandle(), 'int', $areaInfoAddress, 'ptr', DllStructGetPtr($areaInfoStruct), 'int', DllStructGetSize($areaInfoStruct), 'int', 0)
	Return $areaInfoStruct
EndFunc


;~ Returns the campaign of a given map
Func GetMapCampaign($mapID = 0)
	Local $mapStruct = GetAreaInfoByID($mapID)
	Return DllStructGetData($mapStruct, 'campaign')
EndFunc


;~ Returns the region of a given map
Func GetMapRegion($mapID = 0)
	Local $mapStruct = GetAreaInfoByID($mapID)
	Return DllStructGetData($mapStruct, 'region')
EndFunc


;~ TODO: what does this do ?
Func GetMapRegionType($mapID = 0)
	Local $mapStruct = GetAreaInfoByID($mapID)
	Return DllStructGetData($mapStruct, 'regiontype')
EndFunc


;~ Returns if map has been loaded.
Func GetMapIsLoaded()
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetMapIsLoaded()
	Return GetAgentExists(GetMyID())
EndFunc


;~ Returns current district
Func GetDistrict()
	Local $offset[] = [0, 0x18, 0x44, 0x220]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc


;~ Internal use for travel functions.
Func GetRegion()
	Return MemoryRead(GetProcessHandle(), $region_ID)
EndFunc


;~ Internal use for map travel.
Func MoveMap($mapID, $region, $district, $language)
	Return SendPacket(0x18, $HEADER_MAP_TRAVEL, $mapID, $region, $district, $language, False)
EndFunc


;~ Returns to outpost after resigning/failure.
Func ReturnToOutpost()
	Return SendPacket(0x4, $HEADER_PARTY_RETURN_TO_OUTPOST)
EndFunc


;~ Enter a challenge mission/pvp.
Func EnterChallenge()
	Return SendPacket(0x8, $HEADER_PARTY_ENTER_CHALLENGE, 0)
EndFunc


;~ Enter a foreign challenge mission/pvp.
Func EnterChallengeForeign()
	Return SendPacket(0x8, $HEADER_PARTY_ENTER_FOREIGN_MISSION, 0)
EndFunc


;~ Travel to your guild hall.
Func TravelGuildHall()
	Local $offset[] = [0, 0x18, 0x3C]
	Local $processHandle = GetProcessHandle()
	Local $guildHall = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
	SendPacket(0x18, $HEADER_GUILDHALL_TRAVEL, MemoryRead($processHandle, $guildHall[1] + 0x64), MemoryRead($processHandle, $guildHall[1] + 0x68), MemoryRead($processHandle, $guildHall[1] + 0x6C), MemoryRead($processHandle, $guildHall[1] + 0x70), 1)
	Return WaitMapLoading()
EndFunc


;~ Leave your guild hall.
Func LeaveGuildHall()
	SendPacket(0x8, $HEADER_GUILDHALL_LEAVE, 1)
	Return WaitMapLoading()
EndFunc


;~ Wait for map to be loaded, True if map loaded correctly, False otherwise
;Func WaitMapLoading($mapID = -1, $deadlockTime = 10000, $waitingTime = 2500)
;	Local $offset[] = [0, 0x18, 0x2C, 0x6F0, 0xBC]
;	Local $deadlock = TimerInit()
;	Local $processHandle = GetProcessHandle()
;	Local $skillbarStruct = MemoryReadPtr($processHandle, $base_address_ptr, $offset, 'ptr')
;	While GetMyID() == 0 Or $skillbarStruct[0] == 0 Or ($mapID <> -1 And GetMapID() <> $mapID)
;		Sleep(200)
;		$skillbarStruct = MemoryReadPtr($processHandle, $base_address_ptr, $offset, 'ptr')
;		If $skillbarStruct[0] = 0 Then $deadlock = TimerInit()
;		If TimerDiff($deadlock) > $deadlockTime And $deadlockTime > 0 Then Return False
;	WEnd
;	PingSleep($waitingTime)
;	Return True
;EndFunc


;~ Wait for map to be loaded, True if map loaded correctly, False otherwise.
;~ v30: delegates to WaitMapReady (full load guard: not loading, map ID, player agent with a real position, agent array and
;~ party populated, stable over consecutive samples, then the settle delay). Same signature/return contract as before.
Func WaitMapLoading($mapID = -1, $deadlockTime = 10000, $waitingTime = 2500)
	Return WaitMapReady($mapID, -1, $deadlockTime, $waitingTime)
EndFunc


; v30: map load guard. A map counts as ready only when $MAP_READY_STABLE_SAMPLES consecutive samples ($MAP_READY_POLL_MS
; apart) all pass MapReadyReason(). The position/party checks are the only ones that can depend on less-proven memory
; offsets: if everything else has been ready for $MAP_READY_SOFT_GRACE_MS they are waived (logged once), so a bad offset
; can never turn every travel into a timeout - it degrades to the pre-v30 checks, never to a hang.
Global Const $MAP_READY_POLL_MS = 250
Global Const $MAP_READY_STABLE_SAMPLES = 3
Global Const $MAP_READY_SOFT_GRACE_MS = 4000


;~ v30: pure readiness check (no game reads, unit-tested). Returns '' when ready, else the first reason it is not.
;~ $wantedMapID / $wantedMapType = -1: any. $softOnly = True skips the position and party checks (grace fallback).
Func MapReadyReason($mapType, $myID, $maxAgents, $agentExists, $x, $y, $partySize, $mapID, $wantedMapID = -1, $wantedMapType = -1, $softOnly = False)
	If $mapType == $ID_LOADING Then Return 'loading screen'
	If $mapType <> $ID_OUTPOST And $mapType <> $ID_EXPLORABLE Then Return 'unknown instance type ' & $mapType
	If $myID == 0 Then Return 'no player agent id'
	If $maxAgents == 0 Then Return 'agent array empty'
	If Not $agentExists Then Return 'player agent not created'
	If $wantedMapID <> -1 And $mapID <> $wantedMapID Then Return 'map ' & $mapID & ' instead of ' & $wantedMapID
	If $wantedMapType <> -1 And $mapType <> $wantedMapType Then Return 'instance type ' & $mapType & ' instead of ' & $wantedMapType
	If $softOnly Then Return ''
	If Not IsNumber($x) Or Not IsNumber($y) Or $x <> $x Or $y <> $y Then Return 'player position unreadable'
	If $x == 0 And $y == 0 Then Return 'player position not set'
	If $partySize < 1 Then Return 'party not populated'
	Return ''
EndFunc


;~ v30: one game sample for MapReadyReason
Func MapReadySample($wantedMapID = -1, $wantedMapType = -1, $softOnly = False)
	Local $mapType = GetMapType()
	Local $myID = GetMyID()
	Local $maxAgents = GetMaxAgents()
	Local $exists = $myID <> 0 And GetAgentExists($myID)
	Local $x = 0, $y = 0, $partySize = 0
	If $exists And Not $softOnly Then
		Local $me = GetAgentByID($myID)
		$x = DllStructGetData($me, 'X')
		$y = DllStructGetData($me, 'Y')
		$partySize = GetPartySize()
	EndIf
	Return MapReadyReason($mapType, $myID, $maxAgents, $exists, $x, $y, $partySize, GetMapID(), $wantedMapID, $wantedMapType, $softOnly)
EndFunc


;~ v30: True if the map is ready right now (single sample, no settle) - cheap check for 'already there' shortcuts
Func IsMapReadyNow($wantedMapID = -1, $wantedMapType = -1)
	$map_ready_last_reason = MapReadySample($wantedMapID, $wantedMapType)
	Return $map_ready_last_reason == ''
EndFunc


;~ v30: central load guard. Waits until the map is fully loaded (see MapReadyReason) for $MAP_READY_STABLE_SAMPLES samples
;~ in a row, then sleeps $settleTime + 250 ms (+ ping) like WaitMapLoading did ($settleTime < 0: no settle). Returns False (with the reason in $map_ready_last_reason) after $timeout ms
;~ ($timeout <= 0: no limit, like WaitMapLoading's $deadlockTime). Never sends anything to the game.
Func WaitMapReady($wantedMapID = -1, $wantedMapType = -1, $timeout = 20000, $settleTime = 2500)
	Local $deadlock = TimerInit()
	Local $stable = 0
	Local $softTimer = 0
	Local $softWaived = False
	While True
		Local $reason = MapReadySample($wantedMapID, $wantedMapType)
		If $reason <> '' And MapReadySample($wantedMapID, $wantedMapType, True) == '' Then
			; hard checks pass, only position/party missing: waive them after the grace period
			If $softTimer == 0 Then $softTimer = TimerInit()
			If TimerDiff($softTimer) >= $MAP_READY_SOFT_GRACE_MS Then
				If Not $softWaived Then Debug('Map ready check: ' & $reason & ' for ' & Round($MAP_READY_SOFT_GRACE_MS / 1000) & 's - accepting (agent and map are loaded)')
				$softWaived = True
				$reason = ''
			EndIf
		Else
			$softTimer = 0
		EndIf
		$map_ready_last_reason = $reason
		If $reason == '' Then
			$stable += 1
			If $stable >= $MAP_READY_STABLE_SAMPLES Then ExitLoop
		Else
			$stable = 0
		EndIf
		If $timeout > 0 And TimerDiff($deadlock) > $timeout Then
			Debug('Map not ready after ' & Round($timeout / 1000) & 's: ' & $map_ready_last_reason)
			Return False
		EndIf
		Sleep($MAP_READY_POLL_MS)
	WEnd
	If $settleTime >= 0 Then PingSleep($settleTime + 250)
	Return True
EndFunc
#EndRegion Travel


#Region Targeting
;~ Returns current target.
Func GetCurrentTarget()
	Local $currentTargetID = GetCurrentTargetID()
	Return $currentTargetID == 0 ? Null : GetAgentByID($currentTargetID)
EndFunc


;~ Returns current target ID.
Func GetCurrentTargetID()
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetCurrentTargetID()
	Return MemoryRead(GetProcessHandle(), $current_target_agent_ID)
EndFunc


;~ Target an agent.
Func ChangeTarget($agent)
	; GWBridge (opt-in, phase B)
	If $g_GWB_HookCommands And Not $g_GWB_Bypass Then Return Bridge_ChangeTarget($agent)
	DllStructSetData($CHANGE_TARGET_STRUCT, 2, DllStructGetData($agent, 'ID'))
	Enqueue($CHANGE_TARGET_STRUCT_PTR, 8)
EndFunc


;~ Call target.
Func CallTarget($target)
	Return SendPacket(0xC, $HEADER_CALL_TARGET, 0xA, DllStructGetData($target, 'ID'))
EndFunc


;~ Call target.
Func CallTargetOnce($target)
	Local Static $previousTargetID = Null
	Local $targetID = DllStructGetData($target, 'ID')
	If $previousTargetID == $targetID Then Return
	$previousTargetID = $targetID
	Return SendPacket(0xC, $HEADER_CALL_TARGET, 0xA, $targetID)
EndFunc


;~ Clear current target.
Func ClearTarget()
	Return PerformAction(0xE3)
EndFunc


;~ Target the nearest enemy.
Func TargetNearestEnemy()
	Return PerformAction(0x93)
EndFunc


;~ Target the next enemy.
Func TargetNextEnemy()
	Return PerformAction(0x95)
EndFunc


;~ Target the next party member.
Func TargetPartyMember($partyMemberIndex)
	If $partyMemberIndex > 0 And $partyMemberIndex < 13 Then Return PerformAction(0x95 + $partyMemberIndex)
EndFunc


;~ Target the previous enemy.
Func TargetPreviousEnemy()
	Return PerformAction(0x9E)
EndFunc


;~ Target the called target.
Func TargetCalledTarget()
	Return PerformAction(0x9F)
EndFunc


;~ Target yourself.
Func TargetSelf()
	Return PerformAction(0xA0)
EndFunc


;~ Target the nearest ally.
Func TargetNearestAlly()
	Return PerformAction(0xBC)
EndFunc


;~ Target the nearest item.
Func TargetNearestItem()
	Return PerformAction(0xC3)
EndFunc


;~ Target the next item.
Func TargetNextItem()
	Return PerformAction(0xC4)
EndFunc


;~ Target the previous item.
Func TargetPreviousItem()
	Return PerformAction(0xC5)
EndFunc


;~ Target the next party member.
Func TargetNextPartyMember()
	Return PerformAction(0xCA)
EndFunc


;~ Target the previous party member.
Func TargetPreviousPartyMember()
	Return PerformAction(0xCB)
EndFunc
#EndRegion Targeting


#Region Agent
;~ Returns your agent ID.
Func GetMyID()
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetMyID()
	Return MemoryRead(GetProcessHandle(), $my_ID)
EndFunc


;~ Return agent of the player
Func GetMyAgent()
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetMyAgent()
	Return GetAgentByID(GetMyID())
EndFunc


;~ Returns number of agents currently loaded.
Func GetMaxAgents()
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetMaxAgents()
	Return MemoryRead(GetProcessHandle(), $max_agents)
EndFunc


;~ Returns an agent struct.
Func GetAgentByID($agentID)
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetAgentByID($agentID)
	If $agentID = -2 Then $agentID = GetMyID()
	; v38.9: agent array -> agent pointer -> one struct read (no VirtualQueryEx, no wrappers). A null/unreadable pointer
	; gives the same all-zero struct as before.
	Local $processHandle = GetProcessHandle()
	Local $agentStruct = DllStructCreate($AGENT_STRUCT_TEMPLATE)
	Local $agentArray = ReadDword($processHandle, $agent_base_address)
	If $agentArray == 0 Then Return $agentStruct
	Local $agentPtr = ReadDword($processHandle, $agentArray + 4 * $agentID)
	If $agentPtr == 0 Then Return $agentStruct
	DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', $processHandle, 'ptr', $agentPtr, 'struct*', $agentStruct, 'ulong_ptr', DllStructGetSize($agentStruct), 'ptr', 0)
	Return $agentStruct
EndFunc


;~ Internal use for GetAgentByID()
Func GetAgentPtr($agentID)
	Local $offset[] = [0, 4 * $agentID, 0]
	Local $agentStructAddress = MemoryReadPtr(GetProcessHandle(), $agent_base_address, $offset)
	Return $agentStructAddress[0]
EndFunc


;~ Test if an agent exists.
Func GetAgentExists($agentID)
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetAgentExists($agentID)
	Return GetAgentPtr($agentID) <> 0
EndFunc


;~ Returns agent by player name or Null if player with provided name not found.
Func GetAgentByPlayerName($playerName)
	For $agent In GetAgentArray($ID_AGENT_TYPE_NPC)
		If GetPlayerName($agent) == $playerName Then Return $agent
	Next
	Return Null
EndFunc


;~ Quickly creates an array of agents of a given type
Func GetAgentArrayIssueOnDecommitedBlocks($type = 0)
	Local $processHandle = GetProcessHandle()
	DllStructSetData($MAKE_AGENT_ARRAY_STRUCT, 2, $type)
	MemoryWrite($processHandle, $agent_copy_count, -1, 'long')
	Enqueue($MAKE_AGENT_ARRAY_STRUCT_PTR, 8)

	Local $count = -1
	Local $deadlock = TimerInit()
	; fast spin (~5 ms tight spin)
	While TimerDiff($deadlock) < 5
		$count = MemoryRead($processHandle, $agent_copy_count, 'long')
		If $count >= 0 Then ExitLoop
	WEnd
	; Slow spin, if needed
	If $count < 0 Then
		While TimerDiff($deadlock) < 5000
			; Actually sleeps 5-15ms
			Sleep(1)
			$count = MemoryRead($processHandle, $agent_copy_count, 'long')
			If $count >= 0 Then ExitLoop
		WEnd
	EndIf
	If $count <= 0 Then
		Local $empty[0]
		Return $empty
	EndIf

	; 448 = size of $AGENT_STRUCT_TEMPLATE in bytes
	Local Static $AGENT_SIZE = 448
	Local $buffer = SafeDllStructCreate('byte[' & ($count * $AGENT_SIZE) & ']')
	SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', $processHandle, 'int', $agent_copy_base, 'ptr', DllStructGetPtr($buffer), 'int', DllStructGetSize($buffer), 'int', 0)

	Local $returnArray[$count]
	Local $ptrBase = DllStructGetPtr($buffer)
	For $i = 0 To $count - 1
		$returnArray[$i] = SafeDllStructCreate($AGENT_STRUCT_TEMPLATE)
		_WinAPI_MoveMemory(DllStructGetPtr($returnArray[$i]), $ptrBase + ($i * $AGENT_SIZE), $AGENT_SIZE)
	Next
	Return $returnArray
EndFunc


;~ Alternative method to create an array of agents of a given type, without using the agent copy buffer - much slower but more reliable
Func GetAgentArray($type = 0)
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetAgentArray($type)
	Local $processHandle = GetProcessHandle()
	Local $maxAgents = GetMaxAgents()
	Local $agentArray[$maxAgents]
	If $maxAgents <= 0 Then Return $agentArray

	Local $pointer, $agentType, $count = 0
	Local $agentBase = MemoryRead($processHandle, $agent_base_address, 'ptr')
	Local $agentPtrBuffer = DllStructCreate('ptr[' & $maxAgents & ']')

	DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', $processHandle, 'ptr', $agentBase, 'struct*', $agentPtrBuffer, 'ulong_ptr', 4 * $maxAgents, 'ptr', 0)

	; v38.9: plain DllCall/DllStructCreate (no wrappers), and an agent of another type is read into the same struct as the
	; next one instead of a new struct each time - a fresh struct is created only after one is kept. Same agents, same order.
	Local $struct = DllStructCreate($AGENT_STRUCT_TEMPLATE)
	Local $structSize = DllStructGetSize($struct)
	For $i = 1 To $maxAgents
		$pointer = DllStructGetData($agentPtrBuffer, 1, $i)
		If $pointer == 0 Then ContinueLoop

		Local $read = DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', $processHandle, 'ptr', $pointer, 'struct*', $struct, 'ulong_ptr', $structSize, 'ptr', 0)
		If @error Or Not $read[0] Then
			; failed/partial read: redo it into a fresh (zeroed) struct so no byte of the previous agent can remain
			$struct = DllStructCreate($AGENT_STRUCT_TEMPLATE)
			DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', $processHandle, 'ptr', $pointer, 'struct*', $struct, 'ulong_ptr', $structSize, 'ptr', 0)
		EndIf

		$agentType = DllStructGetData($struct, 'Type')
		If $agentType <> 0 And $agentType <> $type Then ContinueLoop
		$agentArray[$count] = $struct
		$count += 1
		$struct = DllStructCreate($AGENT_STRUCT_TEMPLATE)
	Next

	Local $resultArray[$count]
	For $i = 0 To $count - 1
		$resultArray[$i] = $agentArray[$i]
	Next
	Return $resultArray
EndFunc


;~ Returns the name of a player.
;~ v38.7: player records (WorldContext+0x80C) are 80 bytes (0x50) since the Reforged client, as GetAgentIDByLoginNumber
;~ already assumes; the old 76-byte stride read the wrong field for every login number above 0, so no other player's name
;~ could be read (login 1 hit the encoded name, higher numbers hit non-pointer fields). Name pointer is at +0x28.
Func GetPlayerName($agent)
	Local $loginNumber = DllStructGetData($agent, 'LoginNumber')
	Local $offset[] = [0, 0x18, 0x2C, 0x80C, 80 * $loginNumber + 0x28, 0]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset, 'wchar[30]')
	Return $result[1]
EndFunc
#EndRegion Agent


#Region Heroes and Mercenaries
;~ Adds a hero to the party.
Func AddHero($heroID)
	SendPacket(0x8, $HEADER_HERO_ADD, $heroID)
	PingSleep(100)
EndFunc


;~ Kicks a hero from the party.
Func KickHero($heroID)
	Return SendPacket(0x8, $HEADER_HERO_KICK, $heroID)
EndFunc


;~ Kicks all heroes from the party.
Func KickAllHeroes()
	Return SendPacket(0x8, $HEADER_HERO_KICK, 0x28)
EndFunc


;~ Leave your party.
Func LeaveParty($kickHeroes = True)
	If $kickHeroes Then KickAllHeroes()
	SendPacket(0x4, $HEADER_PARTY_LEAVE)
	Sleep(350)
EndFunc


;~ Add a henchman to the party.
Func AddNpc($npcID)
	Return SendPacket(0x8, $HEADER_PARTY_INVITE_NPC, $npcID)
EndFunc


;~ Kick a henchman from the party.
Func KickNpc($npcID)
	Return SendPacket(0x8, $HEADER_PARTY_KICK_NPC, $npcID)
EndFunc


;~ Clear the position flag from a hero.
Func CancelHero($heroIndex)
	Local $agentID = GetHeroID($heroIndex)
	Return SendPacket(0x14, $HEADER_HERO_FLAG_SINGLE, $agentID, 0x7F800000, 0x7F800000, 0)
EndFunc


;~ Clear the full-party position flag.
Func CancelAll()
	Return SendPacket(0x10, $HEADER_HERO_FLAG_ALL, 0x7F800000, 0x7F800000, 0)
EndFunc


;~ Clear all hero flags.
Func ClearPartyCommands()
	Return PerformAction(0xDB)
EndFunc


;~ Clear the position flag from all heroes.
Func CancelAllHeroes()
	For $heroIndex = 1 To GetHeroCount()
		CancelHero($heroIndex)
	Next
EndFunc


;~ Place the position flag of a hero.
Func CommandHero($heroIndex, $X, $Y)
	Return SendPacket(0x14, $HEADER_HERO_FLAG_SINGLE, GetHeroID($heroIndex), FloatToInt($X), FloatToInt($Y), 0)
EndFunc


;~ Place the full-party position flag.
Func CommandAll($X, $Y)
	Return SendPacket(0x10, $HEADER_HERO_FLAG_ALL, FloatToInt($X), FloatToInt($Y), 0)
EndFunc


;~ Lock a hero onto a target.
Func LockHeroTarget($heroIndex, $agentID = 0)
	Local $heroID = GetHeroID($heroIndex)
	Return SendPacket(0xC, $HEADER_HERO_LOCK_TARGET, $heroID, $agentID)
EndFunc


;~ Change aggression level of a hero.
;~ 0=Fight, 1=Guard, 2=Avoid
Func SetHeroBehaviour($heroIndex, $aggressionLevel)
	Local $heroID = GetHeroID($heroIndex)
	Return SendPacket(0xC, $HEADER_HERO_BEHAVIOR, $heroID, $aggressionLevel)
EndFunc


;~ Internal use for enabling or disabling hero skills
Func ToggleHeroSkillSlot($heroIndex, $skillSlot)
	Return SendPacket(0xC, $HEADER_HERO_SKILL_TOGGLE, GetHeroID($heroIndex), $skillSlot - 1)
EndFunc


;~ Returns number of heroes from both you and other players
Func GetHeroCount()
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetHeroCount()
	Local $offset[] = [0, 0x18, 0x4C, 0x54, 0x2C]
	Local $heroCount = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $heroCount[1]
EndFunc


;~ Returns agent ID of a hero - this is only valid in a group with a single player, for more, it can fail
Func GetHeroID($heroIndex)
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetHeroID($heroIndex)
	If $heroIndex == 0 Then Return GetMyID()
	Local $offset[] = [0, 0x18, 0x4C, 0x54, 0x24, 0x18 * ($heroIndex - 1)]
	Local $agentID = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $agentID[1]
EndFunc


;~ Returns hero number by agent ID. If no heroes found with provided agent ID then function returns Null
Func GetHeroNumberByAgentID($agentID)
	Local $heroID
	Local $processHandle = GetProcessHandle()
	Local $offset[] = [0, 0x18, 0x4C, 0x54, 0x24, 0]
	For $i = 1 To GetHeroCount()
		$offset[5] = 0x18 * ($i - 1)
		$heroID = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
		If $heroID[1] == $agentID Then Return $i
	Next
	Return Null
EndFunc


;~ Returns hero number by hero ID.
Func GetHeroNumberByHeroID($heroID)
	Local $agentID
	Local $processHandle = GetProcessHandle()
	Local $offset[] = [0, 0x18, 0x4C, 0x54, 0x24, 0]
	For $i = 1 To GetHeroCount()
		$offset[5] = 8 + 0x18 * ($i - 1)
		$agentID = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
		If $agentID[1] == $heroID Then Return $i
	Next
	Return Null
EndFunc


;~ Returns profession ID of a hero (when it cannot be found by other means)
Func GetHeroProfession($heroIndex, $secondary = False)
	Local $processHandle = GetProcessHandle()
	Local $offset[] = [0, 0x18, 0x2C, 0x6BC, 0]
	Local $buffer
	$heroIndex = GetHeroID($heroIndex)
	For $i = 0 To GetHeroCount()
		$buffer = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
		If $buffer[1] = $heroIndex Then
			$offset[4] += 4
			If $secondary Then $offset[4] += 4
			$buffer = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
			Return $buffer[1]
		EndIf
		$offset[4] += 0x14
	Next
EndFunc


;~ Tests if the skill slot of a hero is disabled.
Func GetIsHeroSkillSlotDisabled($heroIndex, $skillSlot)
	Return BitAND(BitShift(1, -($skillSlot - 1)), DllStructGetData(GetSkillbar($heroIndex), 'Disabled')) > 0
EndFunc
#EndRegion Heroes and Mercenaries


#Region Party
;~ Shared pointer chains into party/player structures. Tails are appended to reach sub-fields.
Global Const $PARTY_CONTEXT_OFFSET[] = [0, 0x18, 0x4C, 0x54]
Global Const $PLAYER_AGENT_ARRAY_OFFSET[] = [0, 0x18, 0x2C, 0x80C]

;~	Description: Returns different States about Party. Check with BitAND.
;~	0x8 = Leader starts Mission / Leader is travelling with Party
;~	0x10 = Hardmode enabled
;~	0x20 = Party defeated
;~	0x40 = Guild Battle
;~	0x80 = Party Leader
;~	0x100 = Observe-Mode
Func GetPartyState($flag)
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetPartyState($flag)
	Local $offset[] = [0, 0x18, 0x4C, 0x14]
	Local $bitMask = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return BitAND($bitMask[1], $flag) > 0
EndFunc


;~ Return True if hard mode is on
Func GetIsHardMode()
	Return GetPartyState(0x10)
EndFunc


Func GetPartySize()
	; v38.9: the party-info chain is resolved once (it was resolved three times, once per counter). Same three reads.
	Local $processHandle = GetProcessHandle()
	Local $offset[] = [0, 0x18, 0x4C, 0x54, 0xC]
	Local $playersPtr = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
	; [0] = 0 when the chain could not be resolved: the three counters read as 0, as before
	Local $partyInfo = $playersPtr[0] == 0 ? 0 : $playersPtr[0] - 0xC
	Local $players = MemoryRead($processHandle, $playersPtr[0], 'long')
	Local $henchmen = MemoryRead($processHandle, $partyInfo == 0 ? 0 : $partyInfo + 0x1C, 'long')
	Local $heroes = MemoryRead($processHandle, $partyInfo == 0 ? 0 : $partyInfo + 0x2C, 'long')
	Return $players + $henchmen + $heroes
EndFunc


Func GetPartyAlliesSize()
	Local $processHandle = GetProcessHandle()
	Local $offset[] = [0, 0x18, 0x4C, 0x54, 0x3C]
	Local $alliesPtr = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
	Return MemoryRead($processHandle, $alliesPtr[0], 'long')
EndFunc


Func GetPartyWaitingForMission()
	Return GetPartyState(0x8)
EndFunc


;~ Returns the number of player slots in the party player array (includes empty slots).
Func GetPlayerCount()
	Local $offset[] = [$PARTY_CONTEXT_OFFSET[0], $PARTY_CONTEXT_OFFSET[1], $PARTY_CONTEXT_OFFSET[2], $PARTY_CONTEXT_OFFSET[3], 0xC]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc


;~ Returns the login number of the player at the given party slot index. Empty slots return 0.
Func GetPartyPlayerLoginNumber($index)
	Local $offset[] = [$PARTY_CONTEXT_OFFSET[0], $PARTY_CONTEXT_OFFSET[1], $PARTY_CONTEXT_OFFSET[2], $PARTY_CONTEXT_OFFSET[3], 0x4, 4 * $index]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc


;~ Returns the agent ID for a given login number by walking the player record array (80-byte records).
Func GetAgentIDByLoginNumber($loginNumber)
	Local $offset[] = [$PLAYER_AGENT_ARRAY_OFFSET[0], $PLAYER_AGENT_ARRAY_OFFSET[1], $PLAYER_AGENT_ARRAY_OFFSET[2], $PLAYER_AGENT_ARRAY_OFFSET[3], 80 * $loginNumber]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc
#EndRegion Party


#Region Item
;~ Returns rarity (name color) of an item.
Func GetRarity($item)
	Local $ptr = DllStructGetData($item, 'NameString')
	If $ptr == 0 Then Return
	Return MemoryRead(GetProcessHandle(), $ptr, 'ushort')
EndFunc


;~ Tests if an item is identified.
Func IsIdentified($item)
	Return BitAND(DllStructGetData($item, 'Interaction'), 0x1) > 0
EndFunc


;~ Tests if an item is unidentified
Func IsUnidentified($item)
	Return Not IsIdentified($item)
EndFunc


;~ Tests if an item is unidentified and gold rarity
Func IsUnidentifiedGoldItem($item)
	Return GetRarity($item) == $RARITY_GOLD And Not IsIdentified($item)
EndFunc


;~ Returns a weapon or shield minimum required attribute.
Func GetItemReq($item)
	Local $mod = GetModByIdentifier($item, '9827')
	Return $mod[0]
EndFunc


;~ Returns a weapon or shield required attribute.
Func GetItemAttribute($item)
	Local $mod = GetModByIdentifier($item, '9827')
	Return $mod[1]
EndFunc


;~ Returns an array of a the requested mod.
Func GetModByIdentifier($item, $identifier)
	Local $result[2]
	Local $string = StringTrimLeft(GetModStruct($item), 2)
	For $i = 0 To StringLen($string) / 8 - 2
		If StringMid($string, 8 * $i + 5, 4) == $identifier Then
			$result[0] = Int('0x' & StringMid($string, 8 * $i + 1, 2))
			$result[1] = Int('0x' & StringMid($string, 8 * $i + 3, 2))
			ExitLoop
		EndIf
	Next
	Return $result
EndFunc


;~ Returns modstruct of an item.
Func GetModStruct($item)
	Local $modstruct = DllStructGetData($item, 'modstruct')
	If $modstruct == 0 Then Return
	Return MemoryRead(GetProcessHandle(), $modstruct, 'Byte[' & DllStructGetData($item, 'modstructsize') * 4 & ']')
EndFunc


;~ Returns struct of an inventory bag. Indexes: 1-5: inventory, 6: xunlai materials, 7: , 8-21: xunlai
Func GetBag($bagIndex)
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetBag($bagIndex)
	Local $bagPtr = GetBagPtr($bagIndex)
	If $bagPtr = 0 Then Return Null
	Local $bag = DllStructCreate($BAG_STRUCT_TEMPLATE)
	DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', GetProcessHandle(), 'ptr', $bagPtr, 'struct*', $bag, 'ulong_ptr', DllStructGetSize($bag), 'ptr', 0)
	Return $bag
EndFunc


;~ Returns pointer to the bag at the bag index provided
Func GetBagPtr($bagIndex)
	Local $offset[] = [0, 0x18, 0x40, 0xF8, 0x4 * $bagIndex]
	Local $itemStructAddress = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset, 'ptr')
	Return $itemStructAddress[1]
EndFunc


;~ Returns item by slot.
Func GetItemBySlot($bagIndex, $slot)
	; GWBridge (opt-in, phase A)
	If $g_GWB_Hook And Not $g_GWB_Bypass Then Return Bridge_GetItemBySlot($bagIndex, $slot)
	; v38.9: still a fresh read of the bag and of the slot on every call; the VirtualQueryEx is replaced by the read result
	; (nothing readable = 0, as before)
	Local $bag = GetBag($bagIndex)
	If Not IsDllStruct($bag) Then Return 0
	Local $processHandle = GetProcessHandle()
	Local $itemPtr = ReadDword($processHandle, DllStructGetData($bag, 'ItemArray') + 4 * ($slot - 1))
	If $itemPtr == 0 Then Return 0
	Local $itemStruct = DllStructCreate($ITEM_STRUCT_TEMPLATE)
	Local $result = DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', $processHandle, 'ptr', $itemPtr, 'struct*', $itemStruct, 'ulong_ptr', DllStructGetSize($itemStruct), 'ulong_ptr*', 0)
	If @error Or (Not $result[0] And $result[5] == 0) Then Return 0
	Return $itemStruct
EndFunc


;~ v38.9: every slot of one bag in one pass: the bag's item pointer array in ONE read, then one read per item. Element
;~ [slot - 1] = item struct, or 0 for an empty/unreadable slot (exactly what GetItemBySlot returns for that slot).
;~ $bag is the bag struct the caller already read (Null/0 = no bag -> empty array). This is a fresh read every call:
;~ nothing is kept between calls, so it is only used by scans that read the bags and then act on nothing they read
;~ (or re-read the item by ID before acting).
Func GetBagItemsOf($bagIndex, $bag)
	Local $none[0]
	If Not IsDllStruct($bag) Then Return $none
	Local $slots = DllStructGetData($bag, 'Slots')
	If $slots <= 0 Then Return $none
	Local $items[$slots]
	Local $processHandle = GetProcessHandle()
	Local $pointers = DllStructCreate('ptr[' & $slots & ']')
	Local $result = DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', $processHandle, 'ptr', DllStructGetData($bag, 'ItemArray'), 'struct*', $pointers, 'ulong_ptr', 4 * $slots, 'ptr', 0)
	If @error Or Not $result[0] Or $slots > 1000 Then
		; unusual: slot by slot, exactly as before
		For $slot = 1 To $slots
			$items[$slot - 1] = GetItemBySlot($bagIndex, $slot)
		Next
		Return $items
	EndIf
	Local $itemPtr, $itemStruct
	For $slot = 1 To $slots
		$items[$slot - 1] = 0
		$itemPtr = DllStructGetData($pointers, 1, $slot)
		If $itemPtr == 0 Then ContinueLoop
		$itemStruct = DllStructCreate($ITEM_STRUCT_TEMPLATE)
		$result = DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', $processHandle, 'ptr', $itemPtr, 'struct*', $itemStruct, 'ulong_ptr', DllStructGetSize($itemStruct), 'ulong_ptr*', 0)
		If @error Or (Not $result[0] And $result[5] == 0) Then ContinueLoop
		$items[$slot - 1] = $itemStruct
	Next
	Return $items
EndFunc


;~ v38.9: the bag's item pointer array in one read (ptr[Slots] struct), 0 if it cannot be read
Func ReadBagItemPointers($bagIndex, $bag)
	If Not IsDllStruct($bag) Then Return 0
	Local $slots = DllStructGetData($bag, 'Slots')
	If $slots <= 0 Or $slots > 1000 Then Return 0
	Local $pointers = DllStructCreate('ptr[' & $slots & ']')
	Local $result = DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', GetProcessHandle(), 'ptr', DllStructGetData($bag, 'ItemArray'), 'struct*', $pointers, 'ulong_ptr', 4 * $slots, 'ptr', 0)
	If @error Or Not $result[0] Then Return 0
	Return $pointers
EndFunc


;~ v38.9: fresh item struct at an item pointer, 0 for a null or unreadable pointer (as GetItemBySlot)
Func GetItemAtPtr($itemPtr)
	If $itemPtr == 0 Then Return 0
	Local $itemStruct = DllStructCreate($ITEM_STRUCT_TEMPLATE)
	Local $result = DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', GetProcessHandle(), 'ptr', $itemPtr, 'struct*', $itemStruct, 'ulong_ptr', DllStructGetSize($itemStruct), 'ulong_ptr*', 0)
	If @error Or (Not $result[0] And $result[5] == 0) Then Return 0
	Return $itemStruct
EndFunc


;~ v38.9: GetBagItemsOf for a bag index (reads the bag struct first)
Func GetBagItems($bagIndex)
	Return GetBagItemsOf($bagIndex, GetBag($bagIndex))
EndFunc


;~ Returns pointer to the item at the slot provided
Func GetItemPtrBySlot($bagIndex, $slot)
	Local $bagPtr = Null
	If $bagIndex < 1 Or $bagIndex > 17 Then Return 0
	Local $bag = GetBag($bagIndex)
	If $slot < 1 Or $slot > DllStructGetData($bag, 'Slots') Then Return 0
	$bagPtr = GetBagPtr($bagIndex)
	Local $processHandle = GetProcessHandle()
	Local $itemArrayPtr = MemoryRead($processHandle, $bagPtr + 24, 'ptr')
	Return MemoryRead($processHandle, $itemArrayPtr + 4 * ($slot - 1), 'ptr')
EndFunc


;~ Returns item struct.
Func GetItemByItemID($itemID)
	Local $processHandle = GetProcessHandle()
	Local $offset[] = [0, 0x18, 0x40, 0xB8, 0x4 * $itemID]
	Local $itemPtr = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
	Local $itemStruct = DllStructCreate($ITEM_STRUCT_TEMPLATE)
	If $itemPtr[1] == 0 Then Return $itemStruct
	DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', $processHandle, 'ptr', $itemPtr[1], 'struct*', $itemStruct, 'ulong_ptr', DllStructGetSize($itemStruct), 'ptr', 0)
	Return $itemStruct
EndFunc


;~ Returns item by agent ID
Func GetItemByAgentID($agentID)
	; v38.9: an item agent carries its item ID: read that item directly and check it really belongs to this agent
	; (one agent read + one item read instead of walking the whole item array). Anything else -> the old full scan.
	Local $itemID = DllStructGetData(GetAgentByID($agentID), 'ItemID')
	If $itemID > 0 Then
		Local $item = GetItemByItemID($itemID)
		If DllStructGetData($item, 'ID') == $itemID And DllStructGetData($item, 'AgentID') == $agentID Then Return $item
	EndIf
	Return GetItemByFilter(ItemAgentIDFilter, $agentID)
EndFunc


;~ Item agent ID corresponds to the provided agent ID
Func ItemAgentIDFilter($itemStruct, $agentID)
	Return DllStructGetData($itemStruct, 'AgentID') == $agentID
EndFunc


;~ Returns item by model ID
Func GetItemByModelID($modelID)
	Return GetItemByFilter(ItemModelIDFilter, $modelID)
EndFunc


;~ Item model ID corresponds to the provided model ID
Func ItemModelIDFilter($itemStruct, $modelID)
	Return DllStructGetData($itemStruct, 'ModelID') == $modelID
EndFunc


;~ Returns item corresponding to the filter function provided with the parameter given
Func GetItemByFilter($filterFunction, $filterParameter = Null)
	; v38.9: the item pointer array is read in ONE read (it was re-resolved through a 5-level chain for every entry); then
	; each non-null item is read and filtered in the same order. Same first match. Unusual cases take the old path.
	Local $processHandle = GetProcessHandle()
	Local $offset[] = [0, 0x18, 0x40, 0xC0]
	Local $itemArraySize = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
	If $itemArraySize[1] < 1 Then Return Null
	Local $offset2[] = [0, 0x18, 0x40, 0xB8]
	Local $itemArray = MemoryReadPtr($processHandle, $base_address_ptr, $offset2)
	If $itemArray[1] == 0 Or $itemArraySize[1] > 0x40000 Then Return GetItemByFilterEntryByEntry($filterFunction, $filterParameter)
	; entries 1..size are scanned, exactly like before (entry 0 is never used)
	Local $pointers = DllStructCreate('ptr[' & ($itemArraySize[1] + 1) & ']')
	Local $result = DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', $processHandle, 'ptr', $itemArray[1], 'struct*', $pointers, 'ulong_ptr', 4 * ($itemArraySize[1] + 1), 'ptr', 0)
	If @error Or Not $result[0] Then Return GetItemByFilterEntryByEntry($filterFunction, $filterParameter)
	Local $itemPtr, $itemStruct
	For $itemID = 1 To $itemArraySize[1]
		$itemPtr = DllStructGetData($pointers, 1, $itemID + 1)
		If $itemPtr = 0 Then ContinueLoop
		$itemStruct = DllStructCreate($ITEM_STRUCT_TEMPLATE)
		DllCall($kernel_handle, 'bool', 'ReadProcessMemory', 'handle', $processHandle, 'ptr', $itemPtr, 'struct*', $itemStruct, 'ulong_ptr', DllStructGetSize($itemStruct), 'ptr', 0)
		If $filterFunction($itemStruct, $filterParameter) Then Return $itemStruct
	Next
	Return Null
EndFunc


;~ v38.9: the pre-v38.9 GetItemByFilter, unchanged (entry by entry). Used only by GetItemByFilter for unusual cases.
Func GetItemByFilterEntryByEntry($filterFunction, $filterParameter = Null)
	Local $processHandle = GetProcessHandle()
	Local $offset[] = [0, 0x18, 0x40, 0xC0]
	Local $itemArraySize = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
	Local $offset[] = [0, 0x18, 0x40, 0xB8, 0]
	Local $itemPtr, $itemID
	For $itemID = 1 To $itemArraySize[1]
		$offset[4] = 0x4 * $itemID
		$itemPtr = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
		If $itemPtr[1] = 0 Then ContinueLoop
		Local $itemStruct = SafeDllStructCreate($ITEM_STRUCT_TEMPLATE)
		SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', $processHandle, 'int', $itemPtr[1], 'ptr', DllStructGetPtr($itemStruct), 'int', DllStructGetSize($itemStruct), 'int', 0)
		If $filterFunction($itemStruct, $filterParameter) Then Return $itemStruct
	Next
	Return Null
EndFunc


;~ Returns amount of gold in storage.
Func GetGoldStorage()
	Local $offset[] = [0, 0x18, 0x40, 0xF8, 0x94]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc


;~ Returns amount of gold being carried.
Func GetGoldCharacter()
	Local $offset[] = [0, 0x18, 0x40, 0xF8, 0x90]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc
#EndRegion Item


#Region Item manipulations
;~ Starts a salvaging session of an item.
Func StartSalvageWithKit($item, $salvageKit)
	Local $offset[] = [0, 0x18, 0x2C, 0x690]
	Local $salvageSessionID = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	If $salvageSessionID[0] == 0 Then Return False
	PingSleep(50)
	Local $itemID = DllStructGetData($item, 'ID')
	DllStructSetData($SALVAGE_STRUCT, 2, $itemID)
	DllStructSetData($SALVAGE_STRUCT, 3, DllStructGetData($salvageKit, 'ID'))
	DllStructSetData($SALVAGE_STRUCT, 4, $salvageSessionID[1])
	;Enqueue($SALVAGE_STRUCT_PTR, 16)
	; v4: bounded retries (was an unbounded loop that could freeze the script forever)
	Local $enqueueTries = 0
	While Not SafeEnqueue($SALVAGE_STRUCT_PTR, 16)
		$enqueueTries += 1
		If $enqueueTries >= 20 Then Return False
		PingSleep(250)
	WEnd
	Return True
EndFunc


;~ v4: address of the salvage session ID (0 if it cannot be resolved) - used as a pre-flight guard
Func GetSalvageSessionAddress()
	Local $offset[] = [0, 0x18, 0x2C, 0x690]
	Local $salvageSessionID = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $salvageSessionID[0]
EndFunc


;~ Does not work - Should validate salvage
Func ValidateSalvage()
	ControlSend(GetWindowHandle(), '', '', '{Enter}')
	PingSleep(1000)
EndFunc


;~ Salvage the materials out of an item.
Func SalvageMaterials()
	Return SendPacket(0x4, $HEADER_SALVAGE_MATERIALS)
EndFunc


;~ Salvages a mod out of an item. Index = FIXED salvage session slot: 0 prefix/insignia, 1 suffix/rune, 2 inscription
;~ (GWCA SalvageSessionInfo salvagable_1/2/3 = Prefix/Suffix/Inscription) - the slot does not shift when a component is missing
Func SalvageMod($modIndex)
	Return SendPacket(0x8, $HEADER_SALVAGE_UPGRADE, $modIndex)
EndFunc


;~ Salvage the materials out of an item.
Func EndSalvage()
	Return SendPacket(0x4, $HEADER_SALVAGE_SESSION_DONE)
EndFunc


;~ Cancel the salvaging session
Func CancelSalvage()
	Return SendPacket(0x4, $HEADER_SALVAGE_SESSION_CANCEL)
EndFunc


;~ Identifies an item.
Func IdentifyItem($item)
	If IsIdentified($item) Then Return

	Local $itemID = DllStructGetData($item, 'ID')
	Local $identificationKit = FindIdentificationKit()
	If $identificationKit == Null Then Return False

	SendPacket(0xC, $HEADER_ITEM_IDENTIFY, DllStructGetData($identificationKit, 'ID'), $itemID)
	Local $deadlock = TimerInit()
	While TimerDiff($deadlock) < 5000
		Sleep(50)
		; Refetch item by ID to get updated identified status
		If IsIdentified(GetItemByItemID($itemID)) Then Return True
	WEnd
	Return False
EndFunc


;~ Equips an item.
Func EquipItem($item)
	Local $itemID = DllStructGetData($item, 'ID')
	Return SendPacket(0x8, $HEADER_ITEM_EQUIP, $itemID)
EndFunc


;~ Equips an item specified by item model ID. No impact if item is already equipped
Func EquipItemByModelID($itemModelID)
	Local $item = GetItemByModelID($itemModelID)
	If $item == Null Then Return False
	Return SendPacket(0x8, $HEADER_ITEM_EQUIP, DllStructGetData($item, 'ID'))
EndFunc


;~ Checks if item specified by item model ID is equipped in any weapon slot
Func IsItemEquipped($itemModelID)
	Local $item = GetItemByModelID($itemModelID)
	If $item == Null Then Return False
	; Equipped value is 0 if not equipped in any slot
	Return DllStructGetData($item, 'Equipped') > 0
EndFunc


;~ Checks if item specified by item model ID is equipped in specified weapon slot (from 1 to 4)
Func IsItemEquippedInWeaponSlot($itemModelID, $weaponSlot)
	If $weaponSlot <> 1 And $weaponSlot <> 2 And $weaponSlot <> 3 And $weaponSlot <> 4 Then Return False
	Local $item = GetItemByModelID($itemModelID)
	If $item == Null Then Return False

	Local $equipValue = DllStructGetData($item, 'Equipped')
	; Equipped value in item struct is a bitmask of size 1 byte (from 0 to 255). Only first 4 bits are used so values are from 0 to 15
	; Bits from 1 to 4 say if item is equipped in weapon slot 1 to 4 respectively. If item is unequipped then value is 0. If the same item is equipped in all 4 slots then value is 15 = 1+2+4+8 = 2^0+2^1+2^2+2^3
	Return BitAND($equipValue, 2 ^ ($weaponSlot - 1)) > 0
EndFunc


; FIXME: does not work
;~ Checks if item specified by item model ID is located in any bag or backpack or is equipped in any weapon slot
Func ItemExistsInInventory($itemModelID)
	Local $item = GetItemByModelID($itemModelID)
	If $item == Null Then Return False
	; Slots are numbered from 1, if item is not in any bag then Slot is 0
	Return DllStructGetData($item, 'Equipped') > 0 Or DllStructGetData($item, 'Slot') > 0
EndFunc


;~ Uses an item.
Func UseItem($item)
	; GWBridge (opt-in, phase B)
	If $g_GWB_HookCommands And Not $g_GWB_Bypass Then Return Bridge_UseItem($item)
	Local $itemID = DllStructGetData($item, 'ID')
	Return SendPacket(0x8, $HEADER_ITEM_USE, $itemID)
EndFunc


;~ Picks up an item.
Func PickUpItem($item)
	; GWBridge (opt-in, phase B)
	If $g_GWB_HookCommands And Not $g_GWB_Bypass Then Return Bridge_PickUpItem($item)
	Local $agentID = DllStructGetData($item, 'AgentID')
	Return SendPacket(0xC, $HEADER_ITEM_INTERACT, $agentID, 0)
EndFunc


;~ Drops an item.
Func DropItem($item, $amount = 0)
	Local $itemID = DllStructGetData($item, 'ID')
	If $amount < 0 Then $amount = DllStructGetData($item, 'Quantity')
	Return SendPacket(0xC, $HEADER_DROP_ITEM, $itemID, $amount)
EndFunc


;~ Destroy an item
Func DestroyItem($item)
	Return SendPacket(0x8, $HEADER_ITEM_DESTROY, DllStructGetData($item, 'ID'))
EndFunc


;~ Moves an item.
Func MoveItem($item, $bagIndex, $slotIndex)
	Local $itemID = DllStructGetData($item, 'ID')

	Local $bagID = DllStructGetData(GetBag($bagIndex), 'ID')
	Return SendPacket(0x10, $HEADER_ITEM_MOVE, $itemID, $bagID, $slotIndex - 1)
EndFunc


;~ Accepts unclaimed items after a mission.
Func AcceptAllItems()
	Return SendPacket(0x8, $HEADER_ITEMS_ACCEPT_UNCLAIMED, DllStructGetData(GetBag(7), 'ID'))
EndFunc


;~ Drop gold on the ground.
Func DropGold($amount = 0)
	If $amount <= 0 Then
		$amount = GetGoldCharacter()
	EndIf
	Return SendPacket(0x8, $HEADER_DROP_GOLD, $amount)
EndFunc


;~ Internal use for moving gold.
Func ChangeGold($character, $storage)
	Return SendPacket(0xC, $HEADER_CHANGE_GOLD, $character, $storage)
EndFunc
#EndRegion Item manipulations


#Region Trade
#Region NPC Trade
;~ Sells an item.
Func SellItem($item, $amount = 0)
	If $amount = 0 Or $amount > DllStructGetData($item, 'Quantity') Then $amount = DllStructGetData($item, 'Quantity')
	DllStructSetData($SELL_ITEM_STRUCT, 2, $amount)
	DllStructSetData($SELL_ITEM_STRUCT, 3, DllStructGetData($item, 'ID'))
	DllStructSetData($SELL_ITEM_STRUCT, 4, $amount * DllStructGetData($item, 'Value'))
	Enqueue($SELL_ITEM_STRUCT_PTR, 16)
EndFunc


;~ Buys an item. ItemPosition is the position of the item in the list of items offered by merchant
Func BuyItem($itemPosition, $amount, $value)
	Local $merchantItemsBase = GetMerchantItemsBase()
	If Not $merchantItemsBase Or $itemPosition < 1 Or GetMerchantItemsSize() < $itemPosition Then Return

	Local $processHandle = GetProcessHandle()
	DllStructSetData($BUY_ITEM_STRUCT, 2, $amount)
	DllStructSetData($BUY_ITEM_STRUCT, 3, MemoryRead($processHandle, $merchantItemsBase + 4 * ($itemPosition - 1)))
	DllStructSetData($BUY_ITEM_STRUCT, 4, $amount * $value)
	DllStructSetData($BUY_ITEM_STRUCT, 5, MemoryRead($processHandle, GetLabel('BuyItemBase'), 15))
	Enqueue($BUY_ITEM_STRUCT_PTR, 20)
EndFunc


;~ Returns the item ID of the quoted item.
Func GetTraderCostID()
	Return MemoryRead(GetProcessHandle(), $trader_cost_ID)
EndFunc


;~ Returns the cost of the requested item.
Func GetTraderCostValue()
	Return MemoryRead(GetProcessHandle(), $trader_cost_value)
EndFunc


;~ Internal use for BuyItem()
Func GetMerchantItemsBase()
	Local $offset[] = [0, 0x18, 0x2C, 0x24]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc


;~ Internal use for BuyItem()
Func GetMerchantItemsSize()
	Local $offset[] = [0, 0x18, 0x2C, 0x28]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc


;~ Get item from merchant corresponding to given modelID
Func GetMerchantItemPtrByModelID($modelID)
	Local $offsets[] = [0, 0x18, 0x40, 0xB8]
	Local $merchantBaseAddress = GetMerchantItemsBase()
	Local $itemID = 0
	Local $itemPtr = 0
	Local $processHandle = GetProcessHandle()
	For $i = 0 To GetMerchantItemsSize() -1
		$itemID = MemoryRead($processHandle, $merchantBaseAddress + 4 * $i)
		If ($itemID) Then
			$offsets[4] = 4 * $itemID
			$itemPtr = MemoryReadPtr($processHandle, $base_address_ptr, $offsets)[1]
			If (MemoryRead($processHandle, $itemPtr + 0x2C) = $modelID) Then
				Return Ptr($itemPtr)
			EndIf
		EndIf
	Next
EndFunc


;~ Request a quote to buy an item from a trader. Returns True if successful.
Func TraderRequest($modelID, $dyeColor = -1)
	Local $processHandle = GetProcessHandle()
	Local $offset[] = [0, 0x18, 0x40, 0xC0]
	Local $itemArraySize = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
	Local $offset[] = [0, 0x18, 0x40, 0xB8, 0]
	Local $itemPtr, $itemID
	Local $found = False
	Local $quoteID = MemoryRead($processHandle, $trader_quote_ID)
	Local $itemStruct = SafeDllStructCreate($ITEM_STRUCT_TEMPLATE)
	For $itemID = 1 To $itemArraySize[1]
		$offset[4] = 0x4 * $itemID
		$itemPtr = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
		If $itemPtr[1] = 0 Then ContinueLoop

		SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', $processHandle, 'int', $itemPtr[1], 'ptr', DllStructGetPtr($itemStruct), 'int', DllStructGetSize($itemStruct), 'int', 0)
		If DllStructGetData($itemStruct, 'ModelID') = $modelID And DllStructGetData($itemStruct, 'bag') = 0 And DllStructGetData($itemStruct, 'AgentID') == 0 Then
			If $dyeColor = -1 Or DllStructGetData($itemStruct, 'DyeColor') = $dyeColor Then
				$found = True
				ExitLoop
			EndIf
		EndIf
	Next
	If Not $found Then Return False

	DllStructSetData($REQUEST_QUOTE_STRUCT, 2, DllStructGetData($itemStruct, 'ID'))
	Enqueue($REQUEST_QUOTE_STRUCT_PTR, 8)

	Local $deadlock = TimerInit()
	$found = False
	While Not $found And TimerDiff($deadlock) < 5000
		Sleep(50)
		$found = MemoryRead($processHandle, $trader_quote_ID) <> $quoteID
	WEnd
	Return $found
EndFunc


;~ Buy the requested item.
Func TraderBuy()
	If Not GetTraderCostID() Or Not GetTraderCostValue() Then Return False
	Enqueue($TRADER_BUY_STRUCT_PTR, 4)
	Return True
EndFunc


;~ Sell items to traders
Func SellItemToTrader($item, $quantity = 0)
	Local $itemID = DllStructGetData($item, 'ID')
	Local $itemQuantity = DllStructGetData($item, 'Quantity')
	Local $itemType	= DllStructGetData($item, 'type')
	Local $processHandle = GetProcessHandle()
	Local $batchSize = 1

	If $itemQuantity < 0 Then Return False
	; Sell all
	If $quantity == 0 Or $quantity > $itemQuantity Then $quantity = $itemQuantity

	If IsBasicMaterial($item) Then $batchSize = 10
	For $i = 0 To $itemQuantity - $batchSize Step $batchSize
		; Request quote
		DllStructSetData($REQUEST_QUOTE_STRUCT_SELL, 2, $itemID)
		Enqueue($REQUEST_QUOTE_STRUCT_SELL_PTR, 8)
		; Wait for quote response
		Local $costID = -1
		Local $timer = TimerInit()
		While $costID <> $itemID
			$costID = MemoryRead($processHandle, $trader_cost_ID)
			PingSleep(50)
			If TimerDiff($timer) > 2000 Then
				Warn('Trader quote timeout for item ' & DllStructGetData($item, 'ModelID'))
				Return False
			EndIf
		WEnd
		; Execute trader sell
		Local $costValue = MemoryRead($processHandle, $trader_cost_value)
		Enqueue($TRADER_SELL_STRUCT_PTR, 4)
		; Wait a bit for transaction to complete
		PingSleep(50)
	Next
	Return True
EndFunc

;~ v4: Request a SELL quote from the currently opened trader for ONE item (item struct).
;~ Waits (ping-aware, bounded) for the trader hook to report a quote for exactly this item.
;~ Returns the quoted gold value (> 0), or 0 on failure / timeout.
Func TraderRequestSell($item, $timeout = 3000)
	Local $itemID = DllStructGetData($item, 'ID')
	If $itemID == 0 Then Return 0
	If Not IsValidLabelAddress('CommandRequestQuoteSell') Then
		Error('TraderRequestSell: CommandRequestQuoteSell is not initialised (scan failed?)')
		Return 0
	EndIf
	Local $processHandle = GetProcessHandle()
	; clear any stale quote so we only accept the answer to THIS request
	MemoryWrite($processHandle, $trader_cost_ID, 0)
	MemoryWrite($processHandle, $trader_cost_value, 0)
	DllStructSetData($REQUEST_QUOTE_STRUCT_SELL, 2, $itemID)
	Enqueue($REQUEST_QUOTE_STRUCT_SELL_PTR, 8)
	Local $timer = TimerInit()
	Local $limit = $timeout + GetPing()
	While TimerDiff($timer) < $limit
		Sleep(50)
		If MemoryRead($processHandle, $trader_cost_ID) == $itemID Then
			Local $value = MemoryRead($processHandle, $trader_cost_value)
			If $value > 0 Then Return $value
		EndIf
	WEnd
	Return 0
EndFunc


;~ v4: Accept the current SELL quote (call only after TraderRequestSell returned > 0). Sells exactly what was quoted.
Func TraderSell()
	If Not GetTraderCostID() Or GetTraderCostValue() <= 0 Then Return False
	If Not IsValidLabelAddress('CommandTraderSell') Then
		Error('TraderSell: CommandTraderSell is not initialised (scan failed?)')
		Return False
	EndIf
	Enqueue($TRADER_SELL_STRUCT_PTR, 4)
	Return True
EndFunc


;~ v4: True if an assembler label / scanned address exists and is non-zero (guards against calls into address 0)
Func IsValidLabelAddress($labelName)
	Local $value = GetLabel($labelName)
	If $value == Null Then Return False
	If IsPtr($value) Then Return $value <> Ptr(0) And $value <> Ptr(-1)
	If IsString($value) And $value == '' Then Return False
	Local $number = Number($value)
	Return $number <> 0 And $number <> -1
EndFunc


;~ v4: 1-based position of an item (by model ID) in the currently opened merchant's list, 0 if not sold here / no merchant open
Func GetMerchantItemPositionByModelID($modelID)
	Local $merchantBaseAddress = GetMerchantItemsBase()
	Local $merchantSize = GetMerchantItemsSize()
	If Not $merchantBaseAddress Or $merchantSize < 1 Or $merchantSize > 512 Then Return 0
	Local $offsets[] = [0, 0x18, 0x40, 0xB8, 0]
	Local $processHandle = GetProcessHandle()
	Local $itemID, $itemPtr
	For $i = 0 To $merchantSize - 1
		$itemID = MemoryRead($processHandle, $merchantBaseAddress + 4 * $i)
		If Not $itemID Then ContinueLoop
		$offsets[4] = 4 * $itemID
		$itemPtr = MemoryReadPtr($processHandle, $base_address_ptr, $offsets)[1]
		If Not $itemPtr Then ContinueLoop
		If MemoryRead($processHandle, $itemPtr + 0x2C) = $modelID Then Return $i + 1
	Next
	Return 0
EndFunc

#EndRegion NPC Trade


#Region Player Trade
;~ Initiate a trade with the given player agent
Func TradePlayer($agent)
	SendPacket(0x08, $HEADER_TRADE_PLAYER, DllStructGetData($agent, 'ID'))
EndFunc


;~ Like pressing the 'Accept' button in a trade.
Func AcceptTrade()
	Return SendPacket(0x4, $HEADER_TRADE_ACCEPT)
EndFunc


;~ Like pressing the 'Accept' button in a trade. Can only be used after both players have submitted their offer.
Func SubmitOffer($gold = 0)
	Return SendPacket(0x8, $HEADER_TRADE_SUBMIT_OFFER, $gold)
EndFunc


;~ Like pressing the 'Cancel' button in a trade.
Func CancelTrade()
	Return SendPacket(0x4, $HEADER_TRADE_CANCEL)
EndFunc


;~ Like pressing the 'Change Offer' button.
Func ChangeOffer()
	Return SendPacket(0x4, $HEADER_TRADE_CHANGE_OFFER)
EndFunc


;~ $itemID = ID of the item or item agent, $amount = Quantity
Func OfferItem($itemID, $amount = 1)
	Return SendPacket(0xC, $HEADER_TRADE_OFFER_ITEM, $itemID, $amount)
EndFunc


;~ Returns: 1 - Trade windows exist 3 - Offer 7 - Accepted Trade
Func TradeWinExist()
	Local $offset = [0, 0x18, 0x58, 0]
	Return MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)[1]
EndFunc


Func TradeOfferItemExist()
	Local $offset = [0, 0x18, 0x58, 0x28, 0]
	Return MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)[1]
EndFunc


Func TradeOfferMoneyExist()
	Local $offset = [0, 0x18, 0x58, 0x24]
	Return MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)[1]
EndFunc


Func ToggleTradePatch($enableTradePatch = True)
	MemoryWrite(GetProcessHandle(), $trade_hack_address, $enableTradePatch ? 0xC3 : 0x55, 'BYTE')
EndFunc
#EndRegion Player Trade
#EndRegion Trade


#Region Quest
;~ Accept a quest from an NPC.
Func AcceptQuest($questID)
	Return SendPacket(0x8, $HEADER_DIALOG_SEND, '0x008' & Hex($questID, 3) & '01')
EndFunc


;~ Accept the reward for a quest.
Func QuestReward($questID)
	Return SendPacket(0x8, $HEADER_DIALOG_SEND, '0x008' & Hex($questID, 3) & '07')
EndFunc


;~ Abandon a quest.
Func AbandonQuest($questID)
	Return SendPacket(0x8, $HEADER_QUEST_ABANDON, $questID)
EndFunc


;~ Returns quest
;~ LogState = 0(no such quest) - 1(quest in progress) - 2(quest over and out) - 3(quest over, still in map)
Func GetQuestByID($questID = 0)
	Local $questPtr, $questLogSize, $quest
	Local $processHandle = GetProcessHandle()
	Local $offset[] = [0, 0x18, 0x2C, 0x534]

	$questLogSize = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
	If $questLogSize[1] = 0 Then Return Null

	If $questID = 0 Then
		$offset[1] = 0x18
		$offset[2] = 0x2C
		$offset[3] = 0x528
		$quest = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
		$questID = $quest[1]
	EndIf

	Local $offset[] = [0, 0x18, 0x2C, 0x52C, 0]
	For $i = 0 To $questLogSize[1] - 1
		$offset[4] = 0x34 * $i
		$questPtr = MemoryReadPtr($processHandle, $base_address_ptr, $offset)
		$quest = SafeDllStructCreate($QUEST_STRUCT_TEMPLATE)
		SafeDllCall13($kernel_handle, 'int', 'ReadProcessMemory', 'int', $processHandle, 'int', $questPtr[0], 'ptr', DllStructGetPtr($quest), 'int', DllStructGetSize($quest), 'int', 0)
		If DllStructGetData($quest, 'ID') = $questID Then Return $quest
	Next
	Return Null
EndFunc
#EndRegion Quest


#Region Titles
;~ Set a title on
Func SetDisplayedTitle($title = 0)
	If $title Then
		Return SendPacket(0x8, $HEADER_TITLE_DISPLAY, $title)
	Else
		Return SendPacket(0x4, $HEADER_TITLE_HIDE)
	EndIf
EndFunc


;~ Set the title to Spearmarshall
Func SetTitleSpearmarshall()
	SendPacket(0x8, $HEADER_TITLE_DISPLAY, $ID_SUNSPEAR_TITLE)
EndFunc


;~ Set the title to Lightbringer
Func SetTitleLightbringer()
	SendPacket(0x8, $HEADER_TITLE_DISPLAY, $ID_LIGHTBRINGER_TITLE)
EndFunc


;~ Set the title to Asuran
Func SetTitleAsuran()
	SendPacket(0x8, $HEADER_TITLE_DISPLAY, $ID_ASURA_TITLE)
EndFunc


;~ Set the title to Dwarven
Func SetTitleDwarven()
	SendPacket(0x8, $HEADER_TITLE_DISPLAY, $ID_DWARF_TITLE)
EndFunc


;~ Set the title to Ebon Vanguard
Func SetTitleEbonVanguard()
	SendPacket(0x8, $HEADER_TITLE_DISPLAY, $ID_EBON_VANGUARD_TITLE)
EndFunc


;~ Set the title to Norn
Func SetTitleNorn()
	SendPacket(0x8, $HEADER_TITLE_DISPLAY, $ID_NORN_TITLE)
EndFunc


;~ Returns title progress by title index.
Func GetTitleByIndex($titleIndex)
	Local Static $TITLE_BASE_OFFSET = 0x04
	Local Static $TITLE_STRUCT_SIZE = 0x2C
	Return GetTitleProgress($TITLE_BASE_OFFSET + ($titleIndex * $TITLE_STRUCT_SIZE))
EndFunc


;~ Return title progression - common part for most titles
Func GetTitleProgress($finalOffset)
	Local $offset[] = [0, 0x18, 0x2C, 0x81C, $finalOffset]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc


;~ Returns Hero title progress.
Func GetHeroTitle()
	Return GetTitleByIndex(0)
EndFunc


;~ Returns Gladiator title progress.
Func GetGladiatorTitle()
	Return GetTitleByIndex(3)
EndFunc


;~ Returns Kurzick title progress.
Func GetKurzickTitle()
	Return GetTitleByIndex(5)
EndFunc


;~ Returns Luxon title progress.
Func GetLuxonTitle()
	Return GetTitleByIndex(6)
EndFunc


;~ Returns drunkard title progress.
Func GetDrunkardTitle()
	Return GetTitleByIndex(7)
EndFunc


;~ Returns survivor title progress.
Func GetSurvivorTitle()
	Return GetTitleByIndex(9)
EndFunc


;~ Returns max titles
Func GetMaxTitles()
	Return GetTitleByIndex(10)
EndFunc


;~ Returns lucky title progress.
Func GetLuckyTitle()
	Return GetTitleByIndex(15)
EndFunc


;~ Returns unlucky title progress.
Func GetUnluckyTitle()
	Return GetTitleByIndex(16)
EndFunc


;~ Returns Sunspear title progress.
Func GetSunspearTitle()
	Return GetTitleByIndex(17)
EndFunc


;~ Returns Lightbringer title progress.
Func GetLightbringerTitle()
	Return GetTitleByIndex(20)
EndFunc


;~ Returns Commander title progress.
Func GetCommanderTitle()
	Return GetTitleByIndex(22)
EndFunc


;~ Returns Gamer title progress.
Func GetGamerTitle()
	Return GetTitleByIndex(23)
EndFunc


;~ Returns Legendary Guardian title progress.
Func GetLegendaryGuardianTitle()
	Return GetTitleByIndex(31)
EndFunc


;~ Returns sweets title progress.
Func GetSweetTitle()
	Return GetTitleByIndex(34)
EndFunc


;~ Returns Asura title progress.
Func GetAsuraTitle()
	Return GetTitleByIndex(38)
EndFunc


;~ Returns Deldrimor title progress.
Func GetDeldrimorTitle()
	Return GetTitleByIndex(39)
EndFunc


;~ Returns Vanguard title progress.
Func GetVanguardTitle()
	Return GetTitleByIndex(40)
EndFunc


;~ Returns Norn title progress.
Func GetNornTitle()
	Return GetTitleByIndex(41)
EndFunc


;~ Returns mastery of the north title progress.
Func GetNorthMasteryTitle()
	Return GetTitleByIndex(42)
EndFunc


;~ Returns party title progress.
Func GetPartyTitle()
	Return GetTitleByIndex(43)
EndFunc


;~ Returns Zaishen title progress.
Func GetZaishenTitle()
	Return GetTitleByIndex(44)
EndFunc


;~ Returns treasure hunter title progress.
Func GetTreasureTitle()
	Return GetTitleByIndex(45)
EndFunc


;~ Returns wisdom title progress.
Func GetWisdomTitle()
	Return GetTitleByIndex(46)
EndFunc


;~ Returns Codex title progress.
Func GetCodexTitle()
	Return GetTitleByIndex(47)
EndFunc


;~ Returns current Tournament points.
Func GetTournamentPoints()
	Local $offset[] = [0, 0x18, 0x2C, 0, 0x18]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc
#EndRegion Titles


#Region Faction
;~ Returns current Kurzick faction.
Func GetKurzickFaction()
	Return GetFaction(0x748)
EndFunc


;~ Returns max Kurzick faction.
Func GetMaxKurzickFaction()
	Return GetFaction(0x7B8)
EndFunc


;~ Returns current Luxon faction.
Func GetLuxonFaction()
	Return GetFaction(0x758)
EndFunc


;~ Returns max Luxon faction.
Func GetMaxLuxonFaction()
	Return GetFaction(0x7BC)
EndFunc


;~ Returns current Balthazar faction.
Func GetBalthazarFaction()
	Return GetFaction(0x798)
EndFunc


;~ Returns max Balthazar faction.
Func GetMaxBalthazarFaction()
	Return GetFaction(0x7C0)
EndFunc


;~ Returns current Imperial faction.
Func GetImperialFaction()
	Return GetFaction(0x76C)
EndFunc


;~ Returns max Imperial faction.
Func GetMaxImperialFaction()
	Return GetFaction(0x7C4)
EndFunc


;~ Returns the faction points depending on the offset provided
Func GetFaction($finalOffset)
	Local $offset[] = [0, 0x18, 0x2C, $finalOffset]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc


;~ Donate Kurzick or Luxon faction.
Func DonateFaction($faction)
	Return SendPacket(0x10, $HEADER_FACTION_DEPOSIT, 0, StringLeft($faction, 1) = 'k' ? 0 : 1, 5000)
EndFunc
#EndRegion Faction


#Region Display
;~ Take a screenshot.
Func MakeScreenshot()
	Return PerformAction(0xAE)
EndFunc


;~ Enable graphics rendering.
Func EnableRendering($showWindow = True)
	Local $windowHandle = GetWindowHandle()
	Local $prevGwState = WinGetState($windowHandle)
	Local $previousWindow = WinGetHandle('[ACTIVE]', '')
	Local $previousWindowState = WinGetState($previousWindow)
	If $showWindow And $prevGwState Then
		If BitAND($prevGwState, 0x10) Then
			WinSetState($windowHandle, '', @SW_RESTORE)
		ElseIf Not BitAND($prevGwState, 0x02) Then
			WinSetState($windowHandle, '', @SW_SHOW)
		EndIf
		If $windowHandle <> $previousWindow And $previousWindow Then RestoreWindowState($previousWindow, $previousWindowState)
	EndIf
	If Not GetIsRendering() Then
		If Not MemoryWrite(GetProcessHandle(), $disable_rendering_address, 0) Then Return SetError(@error, False)
		Sleep(250)
	EndIf
	Return 1
EndFunc


;~ Disable graphics rendering.
Func DisableRendering($hideWindow = True)
	Local $windowHandle = GetWindowHandle()
	If $hideWindow And WinGetState($windowHandle) Then WinSetState($windowHandle, '', @SW_HIDE)
	If GetIsRendering() Then
		If Not MemoryWrite(GetProcessHandle(), $disable_rendering_address, 1) Then Return SetError(@error, False)
		Sleep(250)
	EndIf
	Return 1
EndFunc


;~ Toggles graphics rendering
Func ToggleRendering()
	Return $rendering_enabled ? EnableRendering() : DisableRendering()
EndFunc


;~ Returns True if the game is being rendered
Func GetIsRendering()
	Return MemoryRead(GetProcessHandle(), $disable_rendering_address) <> 1
EndFunc


;~ Internally used - restores a window to previous state.
Func RestoreWindowState($windowHandle, $previousWindowState)
	If Not $windowHandle Or Not $previousWindowState Then Return 0

	Local $currentWindowState = WinGetState($windowHandle)
	; SW_HIDE, SW_SHOWNORMAL, SW_SHOWMINIMIZED, SW_SHOWMAXIMIZED, SW_MINIMIZE, SW_RESTORE
	Local $states = [1, 2, 4, 8, 16, 32]
	For $state In $states
		If BitAND($previousWindowState, $state) And Not BitAND($currentWindowState, $state) Then WinSetState($windowHandle, '', $state)
	Next
EndFunc


;~ Display all names.
Func DisplayAll($display)
	DisplayAllies($display)
	DisplayEnemies($display)
EndFunc


;~ Display the names of allies.
Func DisplayAllies($display)
	Return PerformAction(0x89, $display ? $CONTROL_TYPE_ACTIVATE : $CONTROL_TYPE_DEACTIVATE)
EndFunc


;~ Display the names of enemies.
Func DisplayEnemies($display)
	Return PerformAction(0x94, $display ? $CONTROL_TYPE_ACTIVATE : $CONTROL_TYPE_DEACTIVATE)
EndFunc
#EndRegion Display


#Region Windows
;~ Close all in-game windows.
Func CloseAllPanels()
	Return PerformAction(0x85)
EndFunc


;~ Toggle hero window.
Func ToggleHeroWindow()
	Return PerformAction(0x8A)
EndFunc


;~ Toggle inventory window.
Func ToggleInventory()
	Return PerformAction(0x8B)
EndFunc


;~ Toggle all bags window.
Func ToggleAllBags()
	Return PerformAction(0xB8)
EndFunc


;~ Toggle world map.
Func ToggleWorldMap()
	Return PerformAction(0x8C)
EndFunc


;~ Toggle options window.
Func ToggleOptions()
	Return PerformAction(0x8D)
EndFunc


;~ Toggle quest window.
Func ToggleQuestWindow()
	Return PerformAction(0x8E)
EndFunc


;~ Toggle skills window.
Func ToggleSkillWindow()
	Return PerformAction(0x8F)
EndFunc


;~ Toggle mission map.
Func ToggleMissionMap()
	Return PerformAction(0xB6)
EndFunc


;~ Toggle friends list window.
Func ToggleFriendList()
	Return PerformAction(0xB9)
EndFunc


;~ Toggle guild window.
Func ToggleGuildWindow()
	Return PerformAction(0xBA)
EndFunc


;~ Toggle party window.
Func TogglePartyWindow()
	Return PerformAction(0xBF)
EndFunc


;~ Toggle score chart.
Func ToggleScoreChart()
	Return PerformAction(0xBD)
EndFunc


;~ Toggle layout window.
Func ToggleLayoutWindow()
	Return PerformAction(0xC1)
EndFunc


;~ Toggle minions window.
Func ToggleMinionList()
	Return PerformAction(0xC2)
EndFunc


;~ Toggle a hero panel.
Func ToggleHeroPanel($hero)
	Return PerformAction(($hero < 4 ? 0xDB : 0xFE) + $hero)
EndFunc


;~ Toggle pet panel of a hero.
Func ToggleHeroPetPanel($hero)
	Return PerformAction(($hero < 4 ? 0xDF : 0xFA) + $hero)
EndFunc


;~ Toggle pet panel.
Func TogglePetPanel()
	Return PerformAction(0xDF)
EndFunc


;~ Toggle help window.
Func ToggleHelpWindow()
	Return PerformAction(0xE4)
EndFunc
#EndRegion Windows


#Region Chat
;~ Write a message in the local chat log (client-only, never sent to server).
;~ Uses kWriteToChatLog (0x1000007F) via CommandUIMsg.
;~ channel: 2=GWCA1, 3=All, 6=Emote, 7=Warning, 9=Guild, 11=Group
Func WriteChat($message, $sender = '[Bhub]', $channel = 3)
	Local $processHandle = GetProcessHandle()
	Local $address = 256 * $queue_counter + $queue_base_address
	$queue_counter = Mod($queue_counter + 1, $queue_size)

	If StringLen($message) > 100 Then $message = StringLeft($message, 100)
	; Slot: 256 bytes, struct: 20 bytes → 118 wchars available (incl null).
	; Sender-path fixed overhead: 11 chars + message, so sender max = 106 - msgLen.
	If $sender <> '' Then
		Local $maxSenderLen = 106 - StringLen($message)
		If StringLen($sender) > $maxSenderLen Then $sender = StringLeft($sender, $maxSenderLen)
	EndIf

	; GW1 encoded string: \x108\x107{text}\x1 (must use ChrW for codepoints > 255)
	Local $ESC = ChrW(0x108) & ChrW(0x107)
	Local $END = ChrW(0x1)
	Local $displayStr
	If $sender <> '' Then
		; WriteChatEnc format: \x76b\x10a{senderEnc}\x1\x10b{msgEnc}\x1
		Local $senderEnc = $ESC & $sender & $END
		Local $msgEnc = $ESC & $message & $END
		$displayStr = ChrW(0x76b) & ChrW(0x10a) & $senderEnc & $END & ChrW(0x10b) & $msgEnc & $END
	Else
		$displayStr = $ESC & $message & $END
	EndIf

	; Write encoded string into the queue slot after the 20-byte struct
	Local $msgGWAddr = $address + 20
	MemoryWrite($processHandle, $msgGWAddr, $displayStr, 'wchar[' & (StringLen($displayStr) + 1) & ']')

	; CommandUIMsg struct: [fn ptr][kWriteToChatLog][channel][msg ptr][channel]
	Local $s = DllStructCreate('dword;dword;dword;dword;dword')
	DllStructSetData($s, 1, GetLabel('CommandUIMsg'))
	DllStructSetData($s, 2, 0x1000007F)		; kWriteToChatLog
	DllStructSetData($s, 3, $channel)
	DllStructSetData($s, 4, $msgGWAddr)		; GW1-side pointer to encoded message
	DllStructSetData($s, 5, $channel)
	SafeDllCall13($kernel_handle, 'int', 'WriteProcessMemory', 'int', $processHandle, 'int', $address, 'ptr', DllStructGetPtr($s), 'int', DllStructGetSize($s), 'int', 0)
EndFunc


;~ Send a whisper to another player.
Func SendWhisper($receiver, $message)
	Local $total = 'whisper ' & $receiver & ',' & $message
	If StringLen($total) > 120 Then
		$message = StringLeft($total, 120)
	Else
		$message = $total
	EndIf
	SendChat($message, '/')
	If StringLen($total) > 120 Then SendWhisper($receiver, StringTrimLeft($total, 120))
EndFunc


;~ Send a message to chat.
Func SendChat($message, $channel = '/')
	Local $processHandle = GetProcessHandle()
	Local $address = 256 * $queue_counter + $queue_base_address
	$queue_counter = Mod($queue_counter + 1, $queue_size)
	If StringLen($message) > 120 Then $message = StringLeft($message, 120)

	MemoryWrite($processHandle, $address + 12, $channel & $message, 'wchar[122]')
	SafeDllCall13($kernel_handle, 'int', 'WriteProcessMemory', 'int', $processHandle, 'int', $address, 'ptr', $SEND_CHAT_STRUCT_PTR, 'int', 8, 'int', 0)

	If StringLen($message) > 120 Then SendChat(StringTrimLeft($message, 120), $channel)
EndFunc


;~ Internal use only.
Func ProcessChatMessage($chatLogStruct)
	Local $messageType = DllStructGetData($chatLogStruct, 1)
	Local $message = DllStructGetData($chatLogStruct, 'message[512]')
	Local $channel = 'Unknown'
	Local $sender = 'Unknown'

	Switch $messageType
		Case 0
			$channel = 'Alliance'
		Case 3
			$channel = 'All'
		Case 9
			$channel = 'Guild'
		Case 11
			$channel = 'Team'
		Case 12
			$channel = 'Trade'
		Case 10
			If StringLeft($message, 3) == '-> ' Then
				$channel = 'Sent'
			Else
				$channel = 'Global'
				$sender = 'Guild Wars'
			EndIf
		Case 13
			$channel = 'Advisory'
			$sender = 'Guild Wars'
		Case 14
			$channel = 'Whisper'
		Case Else
			$channel = 'Other'
			$sender = 'Other'
	EndSwitch

	If $channel <> 'Global' And $channel <> 'Advisory' And $channel <> 'Other' Then
		$sender = StringMid($message, 6, StringInStr($message, '</a>') - 6)
		$message = StringTrimLeft($message, StringInStr($message, '<quote>') + 6)
	EndIf

	If $channel == 'Sent' Then
		$sender = StringMid($message, 10, StringInStr($message, '</a>') - 10)
		$message = StringTrimLeft($message, StringInStr($message, '<quote>') + 6)
	EndIf
EndFunc
#EndRegion Chat


#Region Builds and Templates
;~ Loads skill template code.
Func LoadSkillTemplate($buildTemplate, $heroIndex = 0)
	Local $heroID = GetHeroID($heroIndex)
	Local $buildTemplateChars = StringSplit($buildTemplate, '')
	; deleting first element of string array (which has the count of characters in AutoIT) to have string array indexed from 0
	_ArrayDelete($buildTemplateChars, 0)

	Local $tempValuelateType	; 4 Bits
	Local $versionNumber		; 4 Bits
	Local $professionBits		; 2 Bits -> P
	Local $primaryProfession	; P Bits
	Local $secondaryProfession	; P Bits
	Local $attributesCount		; 4 Bits
	Local $attributesBits		; 4 Bits -> A
	Local $attributes[10][2]	; A Bits + 4 Bits (for each Attribute)
	Local $skillsBits			; 4 Bits -> S
	Local $skills[8]			; S Bits * 8
	Local $opTail				; 1 Bit

	$buildTemplate = ''
	For $character in $buildTemplateChars
		$buildTemplate &= Base64ToBin64($character)
	Next

	$tempValuelateType = Bin64ToDec(StringLeft($buildTemplate, 4))
	$buildTemplate = StringTrimLeft($buildTemplate, 4)
	If $tempValuelateType <> 14 Then Return False

	$versionNumber = Bin64ToDec(StringLeft($buildTemplate, 4))
	$buildTemplate = StringTrimLeft($buildTemplate, 4)

	$professionBits = Bin64ToDec(StringLeft($buildTemplate, 2)) * 2 + 4
	$buildTemplate = StringTrimLeft($buildTemplate, 2)

	$primaryProfession = Bin64ToDec(StringLeft($buildTemplate, $professionBits))
	$buildTemplate = StringTrimLeft($buildTemplate, $professionBits)
	If $primaryProfession <> GetHeroProfession($heroIndex) Then
		Error('Build profession does not correspond to hero profession')
		Return False
	EndIf

	$secondaryProfession = Bin64ToDec(StringLeft($buildTemplate, $professionBits))
	$buildTemplate = StringTrimLeft($buildTemplate, $professionBits)

	$attributesCount = Bin64ToDec(StringLeft($buildTemplate, 4))
	$buildTemplate = StringTrimLeft($buildTemplate, 4)

	$attributesBits = Bin64ToDec(StringLeft($buildTemplate, 4)) + 4
	$buildTemplate = StringTrimLeft($buildTemplate, 4)

	$attributes[0][0] = $secondaryProfession
	$attributes[0][1] = $attributesCount
	For $i = 1 To $attributesCount
		$attributes[$i][0] = Bin64ToDec(StringLeft($buildTemplate, $attributesBits))
		$buildTemplate = StringTrimLeft($buildTemplate, $attributesBits)
		$attributes[$i][1] = Bin64ToDec(StringLeft($buildTemplate, 4))
		$buildTemplate = StringTrimLeft($buildTemplate, 4)
	Next

	$skillsBits = Bin64ToDec(StringLeft($buildTemplate, 4)) + 8
	$buildTemplate = StringTrimLeft($buildTemplate, 4)

	For $i = 0 To 7
		$skills[$i] = Bin64ToDec(StringLeft($buildTemplate, $skillsBits))
		$buildTemplate = StringTrimLeft($buildTemplate, $skillsBits)
	Next

	$opTail = Bin64ToDec($buildTemplate)


	LoadAttributes($attributes, $secondaryProfession, $heroIndex)

	LoadSkillBar($skills[0], $skills[1], $skills[2], $skills[3], $skills[4], $skills[5], $skills[6], $skills[7], $heroIndex)
EndFunc


;~ Load attributes from a two dimensional array.
Func LoadAttributes($attributesArray, $secondaryProfession, $heroIndex = 0)
	Local $heroID = GetHeroID($heroIndex)
	Local $primaryAttribute
	Local $deadlock
	Local $level

	$primaryAttribute = GetProfPrimaryAttribute(GetHeroProfession($heroIndex))

	; fix for problem when build template does not have second profession, but attribute points of current player/hero profession still need to be cleared
	; in case of player it is possible to extract secondary profession property from agent struct because player exists in outposts contrary to heroes
	; in case of heroes it is not possible to extract secondary profession from agent struct of hero in outpost because hero agents do not exist in outposts, only in explorables
	; therefore doing a workaround for heroes that when build template does not have second profession then hero second profession is changed to Monk, which clears attribute points of second profession, regardless if it was Monk or not
	If $secondaryProfession == 0 Or $secondaryProfession == Null Then
		If $heroIndex == 0 Then
			$secondaryProfession = DllStructGetData(GetMyAgent(), 'Secondary')
		Else
			ChangeSecondProfession($ID_MONK, $heroIndex)
			$secondaryProfession = $ID_MONK
		EndIf
	EndIf

	$deadlock = TimerInit()
	; Setting up secondary profession
	If GetHeroProfession($heroIndex) <> $secondaryProfession Then
		While GetHeroProfession($heroIndex, True) <> $secondaryProfession And TimerDiff($deadlock) < 8000
			ChangeSecondProfession($attributesArray[0][0], $heroIndex)
			PingSleep(50)
		WEnd
	EndIf

	; Cleaning the attributes array to have only values between 0 and 12
	For $i = 1 To $attributesArray[0][1]
		If $attributesArray[$i][1] > 12 Then $attributesArray[$i][1] = 12
		If $attributesArray[$i][1] < 0 Then $attributesArray[$i][1] = 0
	Next

	; Only way to do this is to set all attributes to 0 and then increasing them as many times as needed
	EmptyAttributes($secondaryProfession, $heroIndex)

	; Now that all attributes are at 0, we increase them by the times needed
	; Using GetAttributeByID during the increase is a bad idea because it counts points from runes too
	For $i = 1 To $attributesArray[0][1]
		For $j = 1 To $attributesArray[$i][1]
			IncreaseAttribute($attributesArray[$i][0], $heroIndex)
			PingSleep(50)
		Next
	Next
	PingSleep(50)

	; If there are any points left, we put them in the primary attribute
	For $i = 0 To 11
		IncreaseAttribute($primaryAttribute, $heroIndex)
		PingSleep(50)
	Next
EndFunc


;~ Returns primary attribute from the provided profession
Func GetProfPrimaryAttribute($profession)
	Switch $profession
		Case $ID_WARRIOR
			Return $ID_STRENGTH
		Case $ID_RANGER
			Return $ID_EXPERTISE
		Case $ID_MONK
			Return $ID_DIVINE_FAVOR
		Case $ID_NECROMANCER
			Return $ID_SOUL_REAPING
		Case $ID_MESMER
			Return $ID_FAST_CASTING
		Case $ID_ELEMENTALIST
			Return $ID_ENERGY_STORAGE
		Case $ID_ASSASSIN
			Return $ID_CRITICAL_STRIKES
		Case $ID_RITUALIST
			Return $ID_SPAWNING_POWER
		Case $ID_PARAGON
			Return $ID_LEADERSHIP
		Case $ID_DERVISH
			Return $ID_MYSTICISM
	EndSwitch
EndFunc


;~ Set all attributes of the character/hero to 0
Func EmptyAttributes($secondaryProfession, $heroIndex = 0)
	For $attribute In $ATTRIBUTES_BY_PROFESSION_MAP[GetHeroProfession($heroIndex)]
		For $i = 0 To 11
			DecreaseAttribute($attribute, $heroIndex)
			PingSleep(50)
		Next
	Next

	For $attribute In $ATTRIBUTES_BY_PROFESSION_MAP[$secondaryProfession]
		For $i = 0 To 11
			DecreaseAttribute($attribute, $heroIndex)
			PingSleep(50)
		Next
	Next
EndFunc


;~ Set all attributes to 0
Func ClearAttributes($heroIndex = 0)
	Local $level
	For $i = 0 To UBound($ATTRIBUTES_ARRAY) - 1
		Local $attributeID = $ATTRIBUTES_ARRAY[$i]
		Local $attribute = GetAttributeByID($attributeID, False, $heroIndex)
		If $attribute > 0 Then
			Local $deadlock = TimerInit()
			While $attribute <> 0 And TimerDiff($deadlock) < 5000
				$deadlock = TimerInit()
				DecreaseAttribute($attributeID, $heroIndex)
				Sleep(250)
				$attribute = GetAttributeByID($attributeID, False, $heroIndex)
			WEnd
		EndIf
	Next
	Return True
EndFunc
#EndRegion Builds and Templates


#Region Miscellaneous
; Decodes a Guild Wars Encoded String to extract the string ID
; EncStrings use variable-length encoding with continuation bits
Func DecodeEncString($ptr)
	If $ptr = 0 Then Return 0

	Local $value = 0
	Local $offset = 0
	; Safety limit
	Local $maxIterations = 10
	Local $processHandle = GetProcessHandle()

	For $i = 1 To $maxIterations
		Local $char = MemoryRead($processHandle, $ptr + $offset, 'word')

		; Check if this is a valid encoded word (>= 0x100)
		If $char < $ENCSTR_WORD_VALUE_BASE Then ExitLoop

		$value *= $ENCSTR_WORD_VALUE_RANGE
		$value += BitAND($char, BitNOT($ENCSTR_WORD_BIT_MORE)) - $ENCSTR_WORD_VALUE_BASE
		$offset += 2

		; If continuation bit is not set, we're done
		If BitAND($char, $ENCSTR_WORD_BIT_MORE) = 0 Then ExitLoop
	Next

	Return $value
EndFunc

; Decodes an encoded string to readable text using GW internal decoder
; This calls ValidateAsyncDecodeStr via injected ASM code
; @param $a_p_Ptr - Pointer to the encoded string in GW memory
; @param $a_i_Timeout - Maximum time to wait for decode (ms), default 1000
; @return Decoded string or empty string on failure
Func DecodeEncStringAsync($ptr, $timeout = 1000)
	If $ptr = 0 Then Return ''

	Local $processHandle = GetProcessHandle()
	; Read the encoded string from GW memory (max 128 wchars)
	Local $encString = MemoryRead($processHandle, $ptr, 'wchar[128]')
	If $encString = '' Then Return ''

	; Write encoded string to command struct
	DllStructSetData($decode_enc_string, 2, $encString)

	; Reset ready flag before sending command
	MemoryWrite($processHandle, $decode_ready, 0, 'dword')

	; Enqueue the decode command
	Enqueue($decode_enc_string_ptr, DllStructGetSize($decode_enc_string))

	; Wait for decode to complete
	Local $startTime = TimerInit()
	While TimerDiff($startTime) < $timeout
		If MemoryRead($processHandle, $decode_ready, 'dword') = 1 Then
			; Read the decoded string
			Local $decoded = MemoryRead($processHandle, $decode_output_ptr, 'wchar[1024]')
			Return $decoded
		EndIf
		Sleep(50)
	WEnd

	; Timeout
	Return ''
EndFunc


;~ Returns current morale.
Func GetMorale($heroIndex = 0)
	Local $processHandle = GetProcessHandle()
	Local $agentID = GetHeroID($heroIndex)
	Local $offset1[] = [0, 0x18, 0x2C, 0x638]
	Local $index = MemoryReadPtr($processHandle, $base_address_ptr, $offset1)
	Local $offset2[] = [0, 0x18, 0x2C, 0x62C, 8 + 0xC * BitAND($agentID, $index[1]), 0x18]
	Local $result = MemoryReadPtr($processHandle, $base_address_ptr, $offset2)
	Return $result[1] - 100
EndFunc


;~ Returns amount of experience.
Func GetExperience()
	Local $offset[] = [0, 0x18, 0x2C, 0x740]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc


;~ Returns current ping. Do not overruse, is valuable for sensitive things (salvage for instance) and small sleeps
Func GetPing()
	Local $ping = MemoryRead(GetProcessHandle(), $ping_address)
	Return $ping < 10 ? 10 : $ping
EndFunc


;~ Returns language currently being used.
Func GetDisplayLanguage()
	Local $offset[] = [0, 0x18, 0x18, 0x194, 0x4C, 0x40]
	Local $result = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $result[1]
EndFunc


;~ Returns how long the current instance has been active, in milliseconds.
Func GetInstanceUpTime()
	Local $offset[] = [0, 0x18, 0x8, 0x1AC]
	Local $timer = MemoryReadPtr(GetProcessHandle(), $base_address_ptr, $offset)
	Return $timer[1]
EndFunc


;~ Switches to/from Hard Mode.
Func SwitchMode($mode)
	Return SendPacket(0x8, $HEADER_SET_DIFFICULTY, $mode)
EndFunc


;~ Skip a cinematic.
Func SkipCinematic()
	Return SendPacket(0x4, $HEADER_CINEMATIC_SKIP)
EndFunc


;~ Change game language.
Func ToggleLanguage()
	DllStructSetData($TOGGLE_LANGUAGE_STRUCT, 2, 0x18)
	Enqueue($TOGGLE_LANGUAGE_STRUCT_PTR, 8)
EndFunc


;~ Change online status. 0 = Offline, 1 = Online, 2 = Do not disturb, 3 = Away
Func SetPlayerStatus($status)
	If $status < 0 Or $status > 3 Then
		Warn('Provided an incorrect status - or the player is already in the provided status.')
		Return False
	EndIf
	DllStructSetData($CHANGE_STATUS_STRUCT, 2, $status)
	Enqueue($CHANGE_STATUS_STRUCT_PTR, 8)
	Return True
EndFunc


;~ Invites a player into the guild using his character name
Func InviteGuild($characterName)
	If GetAgentExists(GetMyID()) Then
		DllStructSetData($INVITE_GUILD_STRUCT, 1, GetLabel('CommandPacketSend'))
		DllStructSetData($INVITE_GUILD_STRUCT, 2, 0x4C)
		DllStructSetData($INVITE_GUILD_STRUCT, 3, 0xB5)
		DllStructSetData($INVITE_GUILD_STRUCT, 4, 0x01)
		DllStructSetData($INVITE_GUILD_STRUCT, 5, $characterName)
		DllStructSetData($INVITE_GUILD_STRUCT, 6, 0x02)
		Enqueue(DllStructGetPtr($INVITE_GUILD_STRUCT), DllStructGetSize($INVITE_GUILD_STRUCT))
		Return True
	EndIf
	Return False
EndFunc


;~ Invites a player as a guest into the guild using his character name
Func InviteGuest($characterName)
	If GetAgentExists(GetMyID()) Then
		DllStructSetData($INVITE_GUILD_STRUCT, 1, GetLabel('CommandPacketSend'))
		DllStructSetData($INVITE_GUILD_STRUCT, 2, 0x4C)
		DllStructSetData($INVITE_GUILD_STRUCT, 3, 0xB5)
		DllStructSetData($INVITE_GUILD_STRUCT, 4, 0x01)
		DllStructSetData($INVITE_GUILD_STRUCT, 5, $characterName)
		DllStructSetData($INVITE_GUILD_STRUCT, 6, 0x01)
		Enqueue(DllStructGetPtr($INVITE_GUILD_STRUCT), DllStructGetSize($INVITE_GUILD_STRUCT))
		Return True
	EndIf
	Return False
EndFunc


;~ Handles disconnection and attempts to reconnect. Returns True once the character is back in game.
;~ The original version was never called and could not terminate: its 'give up' branch was unreachable
;~ (the retry branch above it always matched first), and the first attempt waited a full minute before acting.
;~ Pressing Enter on the client accepts the 'Reconnect' button of the disconnection dialog.
Func Disconnected($maxRetries = 3, $retryDelay = 60000)
	Local $windowHandle = GetWindowHandle()
	If Not IsHWnd($windowHandle) Then $windowHandle = GetWindowHandleForProcess(GetPID())
	If Not IsHWnd($windowHandle) Then
		; Never send keys without a known target: ControlSend with an empty handle types into the active window
		Error('Disconnected, but the game window could not be found - cannot reconnect')
		Return False
	EndIf
	Error('Disconnected. Attempting to reconnect.')
	For $retry = 1 To $maxRetries
		ControlSend($windowHandle, '', '', '{Enter}')
		Local $deadlock = TimerInit()
		While TimerDiff($deadlock) < $retryDelay
			Sleep(250)
			If GetMapType() <> $ID_LOADING And GetMyID() <> 0 And GetAgentExists(GetMyID()) Then
				Notice('Reconnected!')
				Sleep(5000)
				Return True
			EndIf
		WEnd
		Error('Failed to reconnect (attempt ' & $retry & '/' & $maxRetries & ')')
	Next
	Error('Could not reconnect.')
	Return False
EndFunc
#EndRegion Miscellaneous
