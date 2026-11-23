#include '../LoadWaitHelpers.au3'
#include-once
#include '../../lib/GWA2.au3'
#include '../../lib/Utils.au3'

;~ Monk Bonder Mode (Mo/any or any/Mo)
; Slots 1-4: maintained enchantments
; Slots 5-7: spammable energy recovery
; Slot 8: Blessed Signet
Func MonkBonderMode()
	Info('Starting Monk Bonder Mode')
	While $runtime_status == 'RUNNING'
		MaintainEnchantments(1, 4)
		SpamEnergySkills(5, 7)
		UseSkill(8, -2) ; Blessed Signet
		Sleep(300)
	WEnd
	Return $SUCCESS
EndFunc

;~ Ele/Monk Ether Prodigy UW Bonder
; Typical bar: Protective Bond, Life Bond, Ether Prodigy, Burning Speed, Infuse Health, etc.
Func EtherProdigyBonderMode()
	Info('Starting Ether Prodigy Bonder Mode')
	While $runtime_status == 'RUNNING'
		If GetEffect($ID_ETHER_PRODIGY) == Null Then
			UseSkill(3, -2) ; Ether Prodigy slot (adjust as needed)
		EndIf
		MaintainEnchantments(1, 2) ; Protective Bond + Life Bond
		SpamEnergySkills(4, 7) ; Burning Speed / Infuse Health etc.
		Sleep(250)
	WEnd
	Return $SUCCESS
EndFunc

Func MaintainEnchantments($startSlot, $endSlot)
	For $i = $startSlot To $endSlot
		If GetEffect(GetSkillbarSkillID($i)) == Null Then
			UseSkill($i, -2)
			Sleep(200)
		EndIf
	Next
EndFunc

Func SpamEnergySkills($startSlot, $endSlot)
	For $i = $startSlot To $endSlot
		If IsRecharged($i) Then
			UseSkill($i, -2)
			Sleep(150)
		EndIf
	Next
EndFunc
