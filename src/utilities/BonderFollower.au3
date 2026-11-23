#include '../LoadWaitHelpers.au3'
#include-once
#include '../../lib/GWA2_ID_Skills.au3'
#include '../../lib/GWA2.au3'
#include '../../lib/Utils-Agents.au3'
#include '../../lib/Utils-Console.au3'
#include '../../lib/Utils.au3'

; === Monk Bonder (Mo/any or any/Mo) ===
; Slots 1-4: maintained enchantments
; Slots 5-7: spammable energy recovery
; Slot 8: Blessed Signet
Global Const $MONK_BONDER_SKILLS = 'OwpiMypMBg1cxcBAMBdmtIKAA'

; === Ele/Monk UW Ether Prodigy Bonder ===
; Based on standard UW bonder usage with Ether Prodigy
; Ether Prodigy, Protective Bond, Life Bond, Balthazar's Spirit, Infuse Health, Burning Speed, Aura of Restoration, Optional
Global Const $ELE_MONK_UW_BONDER_SKILLS = 'OgNiw8h8eT6M4OIQ0k3lA'

Func BonderFollowerFarm($mode = 'monk')
	Info('Starting Bonder Follower mode: ' & $mode)
	While $runtime_status == 'RUNNING'
		BonderFollowerLoop($mode)
	WEnd
	Return $runtime_status <> 'RUNNING' ? $PAUSE : $SUCCESS
EndFunc

Func BonderFollowerLoop($mode)
	; v38.4: forget the leader on map change, the same way FollowerLoop does (its agent ID is not valid on the new map)
	Local Static $currentMap = Null
	Local $mapID = GetMapID()
	If $mapID <> $currentMap Then
		$currentMap = $mapID
		$leaderID = Null
	EndIf
	; Follow logic (reuse existing follower leader resolution)
	If $leaderID == Null Then $leaderID = FollowerResolveLeaderID()
	If $leaderID == Null Then
		Sleep(1000)
		Return
	EndIf

	Local $leader = GetAgentByID($leaderID)
	Local $me = GetMyAgent()
	If GetDistance($me, $leader) > $RANGE_SPELLCAST Then
		MoveTo(DllStructGetData($leader, 'X'), DllStructGetData($leader, 'Y'))
	EndIf

	If $mode == 'monk' Then
		MaintainMonkBonds()
	ElseIf $mode == 'elemonk' Then
		MaintainEleMonkUWBonds()
	EndIf
	Sleep(200)
EndFunc

Func MaintainMonkBonds()
	; Maintain slots 1-4 (enchantments)
	For $slot = 1 To 4
		If IsRecharged($slot) And GetEnergy() >= 5 Then
			UseSkillEx($slot, GetAgentByID($leaderID))
			Sleep(Random(80, 150, 1))
		EndIf
	Next
	; Spam slots 5-7 for energy recovery if low
	If GetEnergy() < 25 Then
		For $slot = 5 To 7
			If IsRecharged($slot) Then
				UseSkillEx($slot)
				Sleep(50)
			EndIf
		Next
	EndIf
	; Blessed Signet on slot 8 when available
	If IsRecharged(8) And GetEnergy() < 35 Then
		UseSkillEx(8)
	EndIf
EndFunc

Func MaintainEleMonkUWBonds()
	; Maintain Ether Prodigy and key bonds
	; Slot order expected: Ether Prodigy, Protective Bond, Life Bond, Balthazar's Spirit, Infuse Health, Burning Speed, Aura of Restoration, Optional
	If IsRecharged(1) And GetEffect($ID_ETHER_PRODIGY) == Null Then UseSkillEx(1)
	If IsRecharged(7) And GetEffect($ID_AURA_OF_RESTORATION) == Null Then UseSkillEx(7)
	; Maintain bonds on leader
	If IsRecharged(2) Then UseSkillEx(2, GetAgentByID($leaderID))
	If IsRecharged(3) Then UseSkillEx(3, GetAgentByID($leaderID))
	If IsRecharged(4) Then UseSkillEx(4)
	; Spam Burning Speed for energy if needed
	If GetEnergy() < 15 And IsRecharged(6) Then UseSkillEx(6)
	; Infuse Health if leader is low
	Local $leader = GetAgentByID($leaderID)
	If DllStructGetData($leader, 'HP') < 0.5 And IsRecharged(5) Then UseSkillEx(5, $leader)
EndFunc

;~ Farm-map entry points (RunFarmLoop calls with no args)
Func MonkBonderFarm()
	Return BonderFollowerFarm('monk')
EndFunc

Func EleMonkUWBonderFarm()
	Return BonderFollowerFarm('elemonk')
EndFunc
