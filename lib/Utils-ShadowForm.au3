#CS ===========================================================================
; v18/v20: shared Shadow Form / Deadly Paradox / Shroud of Distress / "I Am Unstoppable!" helpers.
; Skill data (GW1 wiki, Skill infobox, checked 2026-11-09):
;   Deadly Paradox (572)       Stance, 15e, no activation, 10s recharge, 5..15s (Deadly Arts): Assassin skills activate
;                              and recharge 33% faster. A stance: NOT extended by +% enchantment mods.
;   Shadow Form (826)          Elite Enchantment Spell, 5e, 1s activation, 30s recharge, 5..21s (Shadow Arts).
;                              With DP: 0.67s activation, 20s recharge.
;   Shroud of Distress (1031)  Enchantment Spell, 10e, 1s activation, 45s recharge, 30..60s (Shadow Arts).
;   "I Am Unstoppable!" (2356) Shout (PvE, Norn rank), 5e, no activation, 30s recharge, 16..20s: cannot be knocked down.
;                              A shout: NOT extended by +% enchantment mods.
;   Giant Stomp (530)          Monster attack skill, 4s activation, takes effect halfway (2s): knocks down everything in earshot.
;                              Used by all Giants, Jotun Skullsmasher, Summit Beastmaster, Summit Giant Herder.
;   Agnar's Rage (531)         Monster attack skill, 6s activation: knocks down all foes in earshot (same detection).
;   Tremor (2176)              Monster Shout, no activation: cannot be seen coming, so it is NOT in the list.
;   v20 (AMG: "because of the titans"), IDs cross-checked in GWA2_ID_Skills, GWCA Constants/Skills.h (SkillID enum),
;   Py4GW skill_descriptions.json and the wiki Skill infobox:
;   Wild Blow (321)            Warrior Melee Attack: always a critical hit, unblockable, ENDS THE TARGET'S STANCE. It does
;                              NOT knock down - IAU only adds +24 armor against it, it cannot keep DP / Dwarven Stability up.
;                              Used by Burning Titans (Hell's Precipice = the Magmas run) and Icy Brutes.
;   Bull's Strike (332)        Warrior Melee Attack: knocks the target down if it is MOVING. Used by Titan Abominations /
;                              Flesh Gluttons (Realm of Torment) and Icy Brutes.
;   v21 Irresistible Blow (356) Warrior Hammer Attack: "If Irresistible Blow is blocked, your target is knocked down"
;                              (wiki; ID also in GWCA SkillID enum and Py4GW). Burning Titan bar (wiki): Irresistible Blow,
;                              Thrill of Victory, Wild Blow. Wild Blow strips the stance, Irresistible Blow follows - and
;                              Shroud of Distress (75% block under 50% HP) makes the block, hence the knockdown, likely.
;                              Titan Abominations / Flesh Gluttons also carry it (plus Bull's Strike, Counter Blow).
;   IAU is a Shout effect, not a stance: Wild Blow ("any stance being used by your target ends") does not remove it.
;   Counter Blow (357) only knocks down a foe that is ATTACKING - chest runners do not attack, so it is not in the list.
;   All are single-target attacks: the foe's 'Skill' field shows them for the attack's swing only (about 1 s, not
;   Giant Stomp's 2 s) and does not say who is being attacked.
; Build (AMG): 14 Shadow Arts and a +20% enchantment duration mod on every Shadow Form character.
#CE ===========================================================================
#include-once

; ---- build assumptions (change here if the build changes) ----
Global Const $SF_BUILD_SHADOW_ARTS			= 14
Global Const $SF_BUILD_ENCHANT_BONUS		= 0.20
; ---- skill costs (wiki) ----
Global Const $SF_ENERGY_COST				= 5
Global Const $DP_ENERGY_COST				= 15
Global Const $SOD_ENERGY_COST				= 10
Global Const $IAU_ENERGY_COST				= 5
; AMG: DP + Shadow Form needs 20 energy. = 15 (DP) + 5 (SF) exactly, no margin.
Global Const $SF_COMBO_MIN_ENERGY			= $DP_ENERGY_COST + $SF_ENERGY_COST
; Durations used when the effect cannot be read from the game (14 SA, +20%): SF 20s * 1.2 = 24s, SoD 58s * 1.2 = 69.6s
Global Const $SF_DURATION_FALLBACK_MS		= ComputeEnchantDurationMs(5, 21, $SF_BUILD_SHADOW_ARTS, $SF_BUILD_ENCHANT_BONUS)
Global Const $SOD_DURATION_FALLBACK_MS		= ComputeEnchantDurationMs(30, 60, $SF_BUILD_SHADOW_ARTS, $SF_BUILD_ENCHANT_BONUS)
; Shroud of Distress refresh window (v18, unchanged): recast only when recharged AND at most this much of it is left.
Global Const $SOD_REFRESH_WINDOW_MS			= 2500
; v20: Shadow Form / Deadly Paradox no longer use a refresh window - each farm's pre-v18 timing decides WHEN (see the
; farm files). This value is only kept for the Shroud energy priority below (unchanged from v18).
Global Const $SF_REFRESH_WINDOW_MS			= 2500
; Shroud is not cast if that would leave less than the combo energy while SF needs a refresh within this time
Global Const $SOD_SF_PRIORITY_MS			= $SF_REFRESH_WINDOW_MS + 1500
; Knockdown threats seen as a foe's casting skill: Giant Stomp and Agnar's Rage (IDs verified on the wiki), v20: + Wild Blow
; and Bull's Strike (Titans). Range: the stomp hits everything within earshot of the giant; + margin because we keep moving
; during its 2 s. Same range and readiness rules for all (AMG's request). v21: + Irresistible Blow, the Burning Titans'
; follow-up knockdown after Wild Blow - it also re-triggers IAU if IAU has expired by then (no extra rule needed).
Global Const $KD_THREAT_SKILL_IDS[]		= [$ID_GIANT_STOMP, $ID_AGNARS_RAGE, $ID_WILD_BLOW, $ID_BULLS_STRIKE, $ID_IRRESISTIBLE_BLOW]
Global Const $KD_THREAT_RANGE			= 1000 + 250

Global $sf_last_cast_timer = Null
Global $sod_last_cast_timer = Null


;~ Duration in ms of an attribute-scaled enchantment: value at 0 and at 15 (wiki progression), rounded like the game,
;~ times (1 + enchantment duration bonus)
Func ComputeEnchantDurationMs($at0, $at15, $attribute, $bonus)
	Return Round($at0 + ($at15 - $at0) * $attribute / 15) * (1 + $bonus) * 1000
EndFunc


;~ v20: pure decision for ONE Shadow Form cast once the farm's own (pre-v18) timing says it is due and SF is recharged:
;~  'combo'        Deadly Paradox then Shadow Form (DP on the bar and recharged, 20+ energy - AMG's v18 rule)
;~  'sf'           Shadow Form alone: no DP / DP not ready, or under 20 energy but at least the farm's old SF minimum
;~                 (DP is never started below 20 energy)
;~  'wait-energy'  not even the farm's old minimum
Func ShadowFormPairAction($dpSlotted, $dpRecharged, $energy, $soloMinEnergy)
	If $dpSlotted And $dpRecharged And $energy >= $SF_COMBO_MIN_ENERGY Then Return 'combo'
	If $soloMinEnergy < $SF_ENERGY_COST Then $soloMinEnergy = $SF_ENERGY_COST
	If $energy >= $soloMinEnergy Then Return 'sf'
	Return 'wait-energy'
EndFunc


;~ Pure decision for Shroud of Distress: recharged, inside its window, and enough energy without starving a due SF refresh
Func ShroudShouldRecast($sodRemainingMs, $sodRecharged, $energy, $sfRemainingMs, $sfSlotted)
	If Not $sodRecharged Then Return False
	If $sodRemainingMs > $SOD_REFRESH_WINDOW_MS Then Return False
	Local $reserve = 0
	If $sfSlotted And $sfRemainingMs <= $SOD_SF_PRIORITY_MS Then $reserve = $SF_COMBO_MIN_ENERGY
	Return $energy >= $SOD_ENERGY_COST + $reserve
EndFunc


;~ Pure decision for the pre-emptive "I Am Unstoppable!"
Func IAUShouldFire($threatDetected, $iauRecharged, $energy, $iauActive, $knockedDown, $casting = False)
	Return $threatDetected And $iauRecharged And $energy >= $IAU_ENERGY_COST And Not $iauActive And Not $knockedDown And Not $casting
EndFunc


;~ Slot (1-8) holding the skill, 0 if it is not on the bar
Func FindSkillSlot($skillID)
	For $slot = 1 To 8
		If GetSkillbarSkillID($slot) == $skillID Then Return $slot
	Next
	Return 0
EndFunc


;~ Remaining time of one of our enchantments: read from the game's effect list; while the effect is on us, never less than
;~ what our own cast timer says (the game may keep the old timestamp until the previous cast elapses). 0 if not on us.
Func GetOwnEnchantRemainingMs($skillID, $lastCastTimer, $fallbackDurationMs)
	Local $effect = GetEffect($skillID)
	If $effect == Null Then Return 0
	Local $remaining = GetEffectTimeRemaining($effect)
	If $lastCastTimer <> Null Then
		Local $byTimer = $fallbackDurationMs - TimerDiff($lastCastTimer)
		If $byTimer > $remaining Then $remaining = $byTimer
	EndIf
	Return $remaining
EndFunc


;~ True if the player can start a skill right now (alive, not knocked down, not already casting)
Func CanUseSkillNow()
	; v38.9: one agent read for all three checks (same Effects bit 0x10 test as IsPlayerDead)
	Local $me = GetMyAgent()
	If BitAND(DllStructGetData($me, 'Effects'), 0x0010) > 0 Then Return False
	If GetIsKnocked($me) Then Return False
	If IsCasting($me) Then Return False
	Return True
EndFunc


;~ Deadly Paradox (stance, instant) then Shadow Form right after: no sleep in between - UseSkillEx returns as soon as DP's
;~ recharge starts (~1 ping). $action: 'combo' or 'sf' (from ShadowFormPairAction). Returns True if Shadow Form went off.
Func CastShadowFormWithParadox($dpSlot, $sfSlot, $action = 'combo')
	If $sfSlot < 1 Or Not CanUseSkillNow() Then Return False
	If $action == 'combo' And $dpSlot > 0 Then UseSkillEx($dpSlot)
	UseSkillEx($sfSlot)
	Local $cast = Not IsRecharged($sfSlot)
	If $cast Then $sf_last_cast_timer = TimerInit()
	Return $cast
EndFunc


;~ v20: cast Shadow Form now (the caller has already decided it is due by the farm's old timing): DP first when
;~ ShadowFormPairAction says 'combo'. $dpSlot 0 = no DP this time. Returns 'combo'/'sf' when cast, 'wait-energy' or 'failed'.
Func CastShadowFormPair($dpSlot, $sfSlot, $soloMinEnergy)
	If $sfSlot < 1 Then Return 'none'
	Local $action = ShadowFormPairAction($dpSlot > 0, $dpSlot > 0 And IsRecharged($dpSlot), GetEnergy(), $soloMinEnergy)
	If $action == 'wait-energy' Then Return $action
	If Not CastShadowFormWithParadox($dpSlot, $sfSlot, $action) Then Return 'failed'
	Return $action
EndFunc


;~ Shroud of Distress upkeep with the refresh window and SF energy priority. Returns True if cast.
Func MaintainShroudOfDistress($sodSlot, $sfSlot)
	If $sodSlot < 1 Or Not CanUseSkillNow() Then Return False
	Local $sodRemaining = GetOwnEnchantRemainingMs($ID_SHROUD_OF_DISTRESS, $sod_last_cast_timer, $SOD_DURATION_FALLBACK_MS)
	Local $sfRemaining = $sfSlot > 0 ? GetOwnEnchantRemainingMs($ID_SHADOW_FORM, $sf_last_cast_timer, $SF_DURATION_FALLBACK_MS) : 0
	If Not ShroudShouldRecast($sodRemaining, IsRecharged($sodSlot), GetEnergy(), $sfRemaining, $sfSlot > 0) Then Return False
	UseSkillEx($sodSlot)
	If IsRecharged($sodSlot) Then Return False
	$sod_last_cast_timer = TimerInit()
	Return True
EndFunc


;~ A foe within $range that is casting a knockdown skill from $KD_THREAT_SKILL_IDS, Null if none
Func FindKnockdownThreat($range = $KD_THREAT_RANGE)
	Local $foes = GetFoesInRangeOfAgent(GetMyAgent(), $range)
	If Not IsArray($foes) Then Return Null
	For $foe In $foes
		Local $casting = DllStructGetData($foe, 'Skill')
		If $casting == 0 Then ContinueLoop
		For $threatID In $KD_THREAT_SKILL_IDS
			If $casting == $threatID Then Return $foe
		Next
	Next
	Return Null
EndFunc


;~ Pre-emptive "I Am Unstoppable!" when a foe nearby is using Giant Stomp, Agnar's Rage, Wild Blow, Bull's Strike or
;~ Irresistible Blow. Returns True if IAU was used.
Func TryPreemptiveIAU($iauSlot)
	If $iauSlot < 1 Or IsPlayerDead() Then Return False
	If Not IsRecharged($iauSlot) Then Return False
	Local $threat = FindKnockdownThreat()
	Local $me = GetMyAgent()
	; Casting (e.g. Shadow Form's 0.67 s): skip, the next poll 200 ms later still lands well inside Giant Stomp's 2 s
	; v38.9: energy from the same agent read as the knocked-down / casting state
	If Not IAUShouldFire($threat <> Null, True, GetEnergy($me), GetEffect($ID_I_AM_UNSTOPPABLE) <> Null, GetIsKnocked($me), IsCasting($me)) Then Return False
	Notice('Knockdown threat (skill ' & DllStructGetData($threat, 'Skill') & ' ' & KnockdownThreatName(DllStructGetData($threat, 'Skill')) & ') - "I Am Unstoppable!"')
	UseSkillEx($iauSlot)
	Return Not IsRecharged($iauSlot)
EndFunc


;~ Name for the log line
Func KnockdownThreatName($skillID)
	Switch $skillID
		Case $ID_GIANT_STOMP
			Return 'Giant Stomp'
		Case $ID_AGNARS_RAGE
			Return 'Agnar''s Rage'
		Case $ID_WILD_BLOW
			Return 'Wild Blow'
		Case $ID_BULLS_STRIKE
			Return 'Bull''s Strike'
		Case $ID_IRRESISTIBLE_BLOW
			Return 'Irresistible Blow'
	EndSwitch
	Return '?'
EndFunc


;~ Reset per-run timers
Func ResetShadowFormState()
	$sf_last_cast_timer = Null
	$sod_last_cast_timer = Null
EndFunc
