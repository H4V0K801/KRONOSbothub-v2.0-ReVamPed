#CS ===========================================================================
; Author: caustic-kronos (aka Kronos, Night, Svarog)
; Contributor: Underavelvetmoon, Gahais
; Copyright 2025 caustic-kronos
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
#include <Array.au3>
#include 'GWA2.au3'
#include 'GWA2_ID_Items.au3'
#include 'Utils.au3'
#include 'Utils-Console.au3'
#include 'Utils-Storage.au3'

Global Const $STRUCT_WEAPON_UPGRADE		= '30'	;[v11 audit: 2 hex chars (not one dword)]
Global Const $STRUCT_INSCRIPTION		= '32'	;[v11 audit: 2 hex chars (not one dword)]


#Region Weapon mod IDs
Global Const $ID_STAFF_HEAD								= 896
Global Const $ID_STAFF_WRAPPING							= 908
Global Const $ID_SHIELD_HANDLE							= 15554
Global Const $ID_FOCUS_CORE								= 15551
Global Const $ID_WAND									= 15552
Global Const $ID_BOW_STRING								= 894
Global Const $ID_BOW_GRIP								= 906
Global Const $ID_SWORD_HILT								= 897
Global Const $ID_SWORD_POMMEL							= 909
Global Const $ID_AXE_HAFT								= 893
Global Const $ID_AXE_GRIP								= 905
Global Const $ID_DAGGER_TANG							= 6323
Global Const $ID_DAGGER_HANDLE							= 6331
Global Const $ID_HAMMER_HAFT							= 895
Global Const $ID_HAMMER_GRIP							= 907
Global Const $ID_SCYTHE_SNATHE							= 15543
Global Const $ID_SCYTHE_GRIP							= 15553
Global Const $ID_SPEARHEAD								= 15544
Global Const $ID_SPEAR_GRIP								= 15555
Global Const $ID_INSCRIPTIONS_MARTIAL					= 15540
Global Const $ID_INSCRIPTIONS_OFFHAND					= 15541
Global Const $ID_INSCRIPTIONS_ALL						= 15542
Global Const $ID_INSCRIPTIONS_GENERAL					= 17059
Global Const $ID_INSCRIPTIONS_SPELLCASTING				= 19122
Global Const $ID_INSCRIPTIONS_FOCUS						= 19123
Global Const $WEAPON_MODS_ARRAY[]						= [$ID_AXE_HAFT, $ID_BOW_STRING, $ID_HAMMER_HAFT, $ID_STAFF_HEAD, $ID_SWORD_HILT, $ID_AXE_GRIP, $ID_BOW_GRIP, $ID_HAMMER_GRIP, _
															$ID_STAFF_WRAPPING, $ID_SWORD_POMMEL, $ID_DAGGER_TANG, $ID_DAGGER_HANDLE, $ID_INSCRIPTIONS_MARTIAL, _
															$ID_INSCRIPTIONS_OFFHAND, $ID_INSCRIPTIONS_ALL, $ID_SCYTHE_SNATHE, $ID_SPEARHEAD, $ID_FOCUS_CORE, $ID_WAND, _
															$ID_SCYTHE_GRIP, $ID_SHIELD_HANDLE, $ID_SPEAR_GRIP, $ID_INSCRIPTIONS_GENERAL, $ID_INSCRIPTIONS_SPELLCASTING, _
															$ID_INSCRIPTIONS_FOCUS]
Global Const $MAP_WEAPON_MODS							= MapFromArray($WEAPON_MODS_ARRAY)
#EndRegion Weapon mod IDs


Global Const $STRUCT_30_HEALTH								= '001E4823'	;[v11 audit: HealthPlus(0x234) arg1=30 arg2=0]
Global Const $STRUCT_MINUS_5_ENERGY							= '0500B820'	;[v11 audit: EnergyMinus(0x20B) arg1=0 arg2=5]
Global Const $STRUCT_15_ENERGY								= '0F00D822'	;[v11 audit: EnergyPlus(0x22D) arg1=0 arg2=15]
Global Const $STRUCT_ENERGY_REGENERATION					= '0100C820'	;[v11 audit: EnergyRegeneration(0x20C) arg1=0 arg2=1]
Global Const $STRUCT_15_DAMAGE								= '0F003822'	;[v11 audit: DamagePlusPercent(0x223) arg1=0 arg2=15]
Global Const $STRUCT_5_ENERGY								= '0500D822'	;[v11 audit: EnergyPlus(0x22D) arg1=0 arg2=5]
Global Const $STRUCT_5_ARMOR								= '05000821'	;[v11 audit: ArmorPlus(0x210) arg1=0 arg2=5]
Global Const $STRUCT_1_20_ATTRIBUTE							= '00143828'	;[v11 audit: AttributePlusOneItem(0x283) arg1=20 arg2=0]
Global Const $STRUCT_MOD_HCT_20								= '00140828'	;[v11 audit: HalvesCastingTimeItemAttribute(0x280) arg1=20 arg2=0]
Global Const $STRUCT_MOD_HCT_10								= '000A0822'	;[v11 audit: HalvesCastingTimeGeneral(0x220) arg1=10 arg2=0]
Global Const $STRUCT_MOD_HSR_20								= '00142828'	;[v11 audit: HalvesSkillRechargeItemAttribute(0x282) arg1=20 arg2=0]
Global Const $STRUCT_MOD_HSR_10								= '000AA823'	;[v11 audit: HalvesSkillRechargeGeneral(0x23A) arg1=10 arg2=0]


#Region Inscriptions
Global Const $STRUCT_INSCRIPTION_MEASURE_FOR_MEASURE		= '1E000826'	;salvageable [v11 audit: HighlySalvageable(0x260) arg1=0 arg2=30 | Py4GW MeasureForMeasure: Inscription; highly_salvageable =True]
Global Const $STRUCT_INSCRIPTION_SHOW_ME_THE_MONEY			= '3200F825'	;rare/money [v36.1: was typo '3200F805' (effect 0x05F, unknown to Py4GW). Py4GW IncreasedSaleValue = 0x25F = '3200F825'. ShowMeTheMoney inscription, improved_sale_value = True]

#Region Weapon Inscriptions
Global Const $STRUCT_INSCRIPTION_STRENGTH_AND_HONOR			= '0F327822'	;+15% while health > 50% [v11 audit: DamagePlusWhileAbove(0x227) arg1=50 arg2=15 | Py4GW StrengthAndHonor: Inscription; damage_increase 10-15, health_threshold =50]
Global Const $STRUCT_INSCRIPTION_GUIDED_BY_FATE				= '0F006822'	;+15% while enchanted [v11 audit: DamagePlusEnchanted(0x226) arg1=0 arg2=15 | Py4GW GuidedByFate: Inscription; damage_increase 10-15]
Global Const $STRUCT_INSCRIPTION_DANCE_WITH_DEATH			= '0F00A822'	;+15% while in a stance [v11 audit: DamagePlusStance(0x22A) arg1=0 arg2=15 | Py4GW DanceWithDeath: Inscription; damage_increase 10-15]
Global Const $STRUCT_INSCRIPTION_TOO_MUCH_INFORMATION		= '0F005822'	;+15% against hexed foes [v11 audit: DamagePlusVsHexed(0x225) arg1=0 arg2=15 | Py4GW TooMuchInformation: Inscription; damage_increase 10-15]
Global Const $STRUCT_INSCRIPTION_TO_THE_PAIN				= '0A001820'	;+15% damage -10 armor while attacking - -10 armor part [v11 audit: ArmorMinusAttacking(0x201) arg1=0 arg2=10 | Py4GW ToThePain: Inscription; damage_increase 14-15, armor =10]
;Global Const $STRUCT_INSCRIPTION_TO_THE_PAIN_2				= $STRUCT_15_DAMAGE				;+15% damage -10 armor while attacking - +15% damage part
Global Const $STRUCT_INSCRIPTION_BRAWN_OVER_BRAIN			= $STRUCT_MINUS_5_ENERGY	;+15% damage -5 energy - -5 energy part [v11 audit: EnergyMinus(0x20B) arg1=0 arg2=5 | Py4GW BrawnOverBrains: Inscription; damage_increase 14-15, energy =5]
;Global Const $STRUCT_INSCRIPTION_BRAWN_OVER_BRAIN_2		= $STRUCT_15_DAMAGE				;+15% damage -5 energy - +15% damage part
Global Const $STRUCT_INSCRIPTION_VENGEANCE_IS_MINE			= '14328822'	;+20% while health < 50% [v11 audit: DamagePlusWhileBelow(0x228) arg1=50 arg2=20 | Py4GW VengeanceIsMine: Inscription; damage_increase 10-20, health_threshold =50]
Global Const $STRUCT_INSCRIPTION_DONT_FEAR_THE_REAPER		= '14009822'	;+20% while hexed [v11 audit: DamagePlusHexed(0x229) arg1=0 arg2=20 | Py4GW DontFearTheReaper: Inscription; damage_increase 10-20]
Global Const $STRUCT_INSCRIPTION_DONT_THINK_TWICE			= $STRUCT_MOD_HCT_10	;hct 10 [v11 audit: HalvesCastingTimeGeneral(0x220) arg1=10 arg2=0 | Py4GW DontThinkTwice: Inscription; chance 5-10]
#EndRegion Common Inscriptions

#Region Martial Inscriptions
Global Const $STRUCT_INSCRIPTION_I_HAVE_THE_POWER			= $STRUCT_5_ENERGY	;+5e [v11 audit: EnergyPlus(0x22D) arg1=0 arg2=5 | Py4GW IHaveThePower: Inscription; energy =5]
Global Const $STRUCT_INSCRIPTION_LET_THE_MEMORY_LIVE_AGAIN	= $STRUCT_MOD_HSR_10	;hsr 10 [v11 audit: HalvesSkillRechargeGeneral(0x23A) arg1=10 arg2=0 | Py4GW LetTheMemoryLiveAgain: Inscription; chance 5-10]
#EndRegion Martial Inscriptions

#Region Caster Weapon Inscriptions
Global Const $STRUCT_INSCRIPTION_HALE_AND_HEARTY			= '05320823'	;+5e while health > 50% [v11 audit: EnergyPlusWhileAbove(0x230) arg1=50 arg2=5 | Py4GW HaleAndHearty: Inscription; energy 4-5, health_threshold =50]
Global Const $STRUCT_INSCRIPTION_HAVE_FAITH					= '0500F822'	;+5e while enchanted [v11 audit: EnergyPlusEnchanted(0x22F) arg1=0 arg2=5 | Py4GW HaveFaith: Inscription; energy 4-5]
Global Const $STRUCT_INSCRIPTION_DONT_CALL_IT_A_COME_BACK	= '07321823'	;+7e while health < 50% [v11 audit: EnergyPlusWhileBelow(0x231) arg1=50 arg2=7 | Py4GW DontCallItAComeback: Inscription; energy 5-7, health_threshold =50]
Global Const $STRUCT_INSCRIPTION_I_AM_SORROW				= '07002823'	;+7e while hexed [v11 audit: EnergyPlusHexed(0x232) arg1=0 arg2=7 | Py4GW IAmSorrow: Inscription; energy 5-7]
Global Const $STRUCT_INSCRIPTION_SEIZE_THE_DAY				= $STRUCT_15_ENERGY	;+15e energy regeneration -1 - +15e part [v11 audit: EnergyPlus(0x22D) arg1=0 arg2=15 | Py4GW SeizeTheDay: Inscription; energy 10-15, energy_regeneration =-1]
;Global Const $STRUCT_INSCRIPTION_SEIZE_THE_DAY_2			= $STRUCT_ENERGY_REGENERATION	;+15e energy regeneration -1 - energy regeneration -1 part
Global Const $STRUCT_INSCRIPTION_APTITUDE_NOT_ATTITUDE		= $STRUCT_MOD_HCT_20	;hct 20 [v11 audit: HalvesCastingTimeItemAttribute(0x280) arg1=20 arg2=0 | Py4GW AptitudeNotAttitude: Inscription; chance 10-20]
#EndRegion Caster Weapon Inscriptions
#EndRegion Inscriptions

#Region Offhand Inscriptions
#Region Focus Inscriptions
Global Const $STRUCT_INSCRIPTION_FORGET_ME_NOT				= $STRUCT_MOD_HSR_20	;hsr 20 [v11 audit: HalvesSkillRechargeItemAttribute(0x282) arg1=20 arg2=0 | Py4GW ForgetMeNot: Inscription; chance 10-20]
Global Const $STRUCT_INSCRIPTION_SERENITY_NOW				= $STRUCT_MOD_HSR_10	;hsr 10 [v11 audit: HalvesSkillRechargeGeneral(0x23A) arg1=10 arg2=0 | Py4GW SerenityNow: Inscription; chance 7-10]

Global Const $STRUCT_INSCRIPTION_HAIL_TO_THE_KING			= '0532A821'	;+5 armor while health > 50% [v11 audit: ArmorPlusAbove(0x21A) arg1=50 arg2=5 | Py4GW HailToTheKing: Inscription; armor 4-5, health_threshold =50]
Global Const $STRUCT_INSCRIPTION_FAITH_IS_MY_SHIELD			= '05009821'	;+5 armor while enchanted [v11 audit: ArmorPlusEnchanted(0x219) arg1=0 arg2=5 | Py4GW FaithIsMyShield: Inscription; armor 4-5]
Global Const $STRUCT_INSCRIPTION_MIGHT_MAKES_RIGHT			= '05007821'	;+5 armor while attacking [v11 audit: ArmorPlusAttacking(0x217) arg1=0 arg2=5 | Py4GW MightMakesRight: Inscription; armor 4-5]
Global Const $STRUCT_INSCRIPTION_KNOWING_IS_HALF_THE_BATTLE	= '05008821'	;+5 armor while casting [v11 audit: ArmorPlusCasting(0x218) arg1=0 arg2=5 | Py4GW KnowingIsHalfTheBattle: Inscription; armor =5]
Global Const $STRUCT_INSCRIPTION_MAN_FOR_ALL_SEASONS		= '05002821'	;+5 armor vs elemental damage [v11 audit: ArmorPlusVsElemental(0x212) arg1=0 arg2=5 | Py4GW ManForAllSeasons: Inscription; armor 4-5]
Global Const $STRUCT_INSCRIPTION_SURVIVAL_OF_THE_FITTEST	= '05005821'	;+5 armor vs physical damage [v11 audit: ArmorPlusVsPhysical(0x215) arg1=0 arg2=5 | Py4GW SurvivalOfTheFittest: Inscription; armor 4-5]
Global Const $STRUCT_INSCRIPTION_IGNORANCE_IS_BLISS			= $STRUCT_MINUS_5_ENERGY	;+5 armor ^ -5 energy - -5 energy part [v11 audit: EnergyMinus(0x20B) arg1=0 arg2=5 | Py4GW IgnoranceIsBliss: Inscription; armor 4-5, energy =5]
;Global Const $STRUCT_INSCRIPTION_IGNORANCE_IS_BLISS_2		= $STRUCT_5_ARMOR				;+5 armor ^ -5 energy - +5 armor part
Global Const $STRUCT_INSCRIPTION_LIFE_IS_PAIN				= '1400D820'	;+5 armor ^ -20 health - -20 health part [v11 audit: HealthMinus(0x20D) arg1=0 arg2=20 | Py4GW LifeIsPain: Inscription; armor 4-5, health =20]
;Global Const $STRUCT_INSCRIPTION_LIFE_IS_PAIN_2			= $STRUCT_5_ARMOR				;+5 armor ^ -20 health - +5 armor part
Global Const $STRUCT_INSCRIPTION_DOWN_BUT_NOT_OUT			= '0A32B821'	;+10 armor while health < 50% [v11 audit: ArmorPlusWhileBelow(0x21B) arg1=50 arg2=10 | Py4GW DownButNotOut: Inscription; armor 5-10, health_threshold =50]
Global Const $STRUCT_INSCRIPTION_BE_JUST_AND_FEAR_NOT		= '0A00C821'	;+10 armor while hexed [v11 audit: ArmorPlusHexed(0x21C) arg1=0 arg2=10 | Py4GW BeJustAndFearNot: Inscription; armor 5-10]
Global Const $STRUCT_INSCRIPTION_LIVE_FOR_TODAY				= $STRUCT_15_ENERGY	;+15 energy ^ -1 energy regeneration - +15 energy part [v11 audit: EnergyPlus(0x22D) arg1=0 arg2=15 | Py4GW LiveForToday: Inscription; energy 10-15, energy_regeneration =-1]
;Global Const $STRUCT_INSCRIPTION_LIVE_FOR_TODAY_2			= $STRUCT_ENERGY_REGENERATION	;+15 energy ^ -1 energy regeneration - energy regeneration -1 part
#EndRegion Focus Inscriptions

#Region Focus and Shield Inscriptions
Global Const $STRUCT_INSCRIPTION_MASTER_OF_MY_DOMAIN		= $STRUCT_1_20_ATTRIBUTE	;+1^20% item attribute [v11 audit: AttributePlusOneItem(0x283) arg1=20 arg2=0 | Py4GW MasterOfMyDomain: Inscription; chance 11-20, attribute_level =1]

Global Const $STRUCT_INSCRIPTION_NOT_THE_FACE				= '0A0018A1'	;+10 armor vs blunt [v11 audit: ArmorPlusVsDamage(0x211) arg1=0 arg2=10 | Py4GW NotTheFace: Inscription; armor 5-10, damage_type =Blunt]
Global Const $STRUCT_INSCRIPTION_LEAF_ON_THE_WIND			= '0A0318A1'	;+10 armor vs cold [v11 audit: ArmorPlusVsDamage(0x211) arg1=3 arg2=10 | Py4GW LeafOnTheWind: Inscription; armor 5-10, damage_type =Cold]
Global Const $STRUCT_INSCRIPTION_LIKE_A_ROLLING_STONE		= '0A0B18A1'	;+10 armor vs earth [v11 audit: ArmorPlusVsDamage(0x211) arg1=11 arg2=10 | Py4GW LikeARollingStone: Inscription; armor 5-10, damage_type =Earth]
Global Const $STRUCT_INSCRIPTION_SLEEP_NOW_IN_THE_FIRE		= '0A0518A1'	;+10 armor vs fire [v11 audit: ArmorPlusVsDamage(0x211) arg1=5 arg2=10 | Py4GW SleepNowInTheFire: Inscription; armor 5-10, damage_type =Fire]
Global Const $STRUCT_INSCRIPTION_RIDERS_ON_THE_STORM		= '0A0418A1'	;+10 armor vs lightning [v11 audit: ArmorPlusVsDamage(0x211) arg1=4 arg2=10 | Py4GW RidersOnTheStorm: Inscription; armor 5-10, damage_type =Lightning]
Global Const $STRUCT_INSCRIPTION_THROUGH_THICK_AND_THIN		= '0A0118A1'	;+10 armor vs piercing [v11 audit: ArmorPlusVsDamage(0x211) arg1=1 arg2=10 | Py4GW ThroughThickAndThin: Inscription; armor 5-10, damage_type =Piercing]
Global Const $STRUCT_INSCRIPTION_THE_RIDDLE_OF_STEEL		= '0A0218A1'	;+10 armor vs slashing [v11 audit: ArmorPlusVsDamage(0x211) arg1=2 arg2=10 | Py4GW TheRiddleOfSteel: Inscription; armor 5-10, damage_type =Slashing]

Global Const $STRUCT_INSCRIPTION_SHELTERED_BY_FAITH			= '02008820'	;-2 physical damage while enchanted [v11 audit: ReceiveLessPhysDamageEnchanted(0x208) arg1=0 arg2=2 | Py4GW ShelteredByFaith: Inscription; damage_reduction 1-2]
Global Const $STRUCT_INSCRIPTION_RUN_FOR_YOUR_LIFE			= '0200A820'	;-2 physical damage while in a stance [v11 audit: ReceiveLessPhysDamageStance(0x20A) arg1=0 arg2=2 | Py4GW RunForYourLife: Inscription; damage_reduction 1-2]
Global Const $STRUCT_INSCRIPTION_NOTHING_TO_FEAR			= '03009820'	;-3 physical damage while hexed [v11 audit: ReceiveLessPhysDamageHexed(0x209) arg1=0 arg2=3 | Py4GW NothingToFear: Inscription; damage_reduction 1-3]
Global Const $STRUCT_INSCRIPTION_LUCK_OF_THE_DRAW			= '05147820'	;-5 physical damage ^ 20% [v11 audit: ReceiveLessDamage(0x207) arg1=20 arg2=5 | Py4GW LuckOfTheDraw: Inscription; chance 11-20, damage_reduction =5]

Global Const $STRUCT_INSCRIPTION_FEAR_CUTS_DEEPER			= '00005828'	;-20 bleeding duration [v11 audit: ReduceConditionDuration(0x285) arg1=0 arg2=0 | Py4GW FearCutsDeeper: Inscription; condition =Bleeding]
Global Const $STRUCT_INSCRIPTION_I_CAN_SEE_CLEARLY_NOW		= '00015828'	;-20 blind duration [v11 audit: ReduceConditionDuration(0x285) arg1=1 arg2=0 | Py4GW ICanSeeClearlyNow: Inscription; condition =Blind]
Global Const $STRUCT_INSCRIPTION_SWIFT_AS_THE_WIND			= '00035828'	;-20 crippled duration [v11 audit: ReduceConditionDuration(0x285) arg1=3 arg2=0 | Py4GW SwiftAsTheWind: Inscription; condition =Crippled]
Global Const $STRUCT_INSCRIPTION_SOUNDNESS_OF_MIND			= '00075828'	;-20 dazed duration [v11 audit: ReduceConditionDuration(0x285) arg1=7 arg2=0 | Py4GW SoundnessOfMind: Inscription; condition =Dazed]
Global Const $STRUCT_INSCRIPTION_STRENGTH_OF_BODY			= '00045828'	;-20 deep wound duration [v11 audit: ReduceConditionDuration(0x285) arg1=4 arg2=0 | Py4GW StrengthOfBody: Inscription; condition =Deep_Wound]
Global Const $STRUCT_INSCRIPTION_CAST_OUT_THE_UNCLEAN		= '00055828'	;-20 disease duration [v11 audit: ReduceConditionDuration(0x285) arg1=5 arg2=0 | Py4GW CastOutTheUnclean: Inscription; condition =Disease]
Global Const $STRUCT_INSCRIPTION_CAST_OUT_THE_UNCLEAN_OS	= 'E3017824'	;-20 disease duration [v11 audit: ReducesDiseaseDuration(0x247) arg1=1 arg2=227]
Global Const $STRUCT_INSCRIPTION_PURE_OF_HEART				= '00065828'	;-20 poison duration [v11 audit: ReduceConditionDuration(0x285) arg1=6 arg2=0 | Py4GW PureOfHeart: Inscription; condition =Poison]
Global Const $STRUCT_INSCRIPTION_ONLY_THE_STRONG_SURVIVE	= '00085828'	;-20 weakness duration (old 'incorrect' note disproved: arg1 8 = Weakness in Py4GW Reduced_Ailment, same scheme as the other 7 condition inscriptions) [v11 audit: ReduceConditionDuration(0x285) arg1=8 arg2=0 | Py4GW OnlyTheStrongSurvive: Inscription; condition =Weakness]
#EndRegion Focus and Shield Inscriptions
#EndRegion Offhand Inscriptions



#Region Mods
#Region Prefixes
#Region Martial prefix mods
Global Const $STRUCT_MOD_BARBED								= 'DE016824'	;+33% bleeding [v11 audit: IncreaseConditionDuration(0x246) arg1=1 arg2=222 | Py4GW BarbedUpgrade: Prefix on Axe/Bow/Daggers/Scythe/Spear/Sword; condition =Bleeding]
Global Const $STRUCT_MOD_CRUEL								= 'E2016824'	;+33% deep wound [v11 audit: IncreaseConditionDuration(0x246) arg1=1 arg2=226 | Py4GW CruelUpgrade: Prefix on Axe/Daggers/Hammer/Scythe/Spear/Sword; condition =Deep_Wound]
Global Const $STRUCT_MOD_CRIPPLING							= 'E1016824'	;+33% crippled							;Does not match all crippling prefixes [v11 audit: IncreaseConditionDuration(0x246) arg1=1 arg2=225 | Py4GW CripplingUpgrade: Prefix on Axe/Bow/Daggers/Scythe/Spear/Sword; condition =Crippled]
Global Const $STRUCT_MOD_HEAVY								= 'E6016824'	; v5: was 'E601824' (7 chars, typo) - weakness = condition 8 -> E6, same pattern as Barbed/Cruel/Poisonous						;+33% weakness [v11 audit: IncreaseConditionDuration(0x246) arg1=1 arg2=230 | Py4GW HeavyUpgrade: Prefix on Axe/Hammer/Scythe/Spear; condition =Weakness]
Global Const $STRUCT_MOD_POISONOUS							= 'E4016824'	;+33% poison [v11 audit: IncreaseConditionDuration(0x246) arg1=1 arg2=228 | Py4GW PoisonousUpgrade: Prefix on Axe/Bow/Daggers/Scythe/Spear/Sword; condition =Poison]
Global Const $STRUCT_MOD_SILENCING							= 'E5016824'	;+33% dazed [v11 audit: IncreaseConditionDuration(0x246) arg1=1 arg2=229 | Py4GW SilencingUpgrade: Prefix on Bow/Daggers/Spear; condition =Dazed]

Global Const $STRUCT_MOD_EBON								= '000BB824'	;[v11 audit: DamageTypeProperty(0x24B) arg1=11 arg2=0 | Py4GW EbonUpgrade: Prefix on Axe/Bow/Daggers/Hammer/Scythe/Spear/Sword; damage_type =Earth]
Global Const $STRUCT_MOD_FIERY								= '0005B824'	;[v11 audit: DamageTypeProperty(0x24B) arg1=5 arg2=0 | Py4GW FieryUpgrade: Prefix on Axe/Bow/Daggers/Hammer/Scythe/Spear/Sword; damage_type =Fire]
Global Const $STRUCT_MOD_ICY								= '0003B824'	;[v11 audit: DamageTypeProperty(0x24B) arg1=3 arg2=0 | Py4GW IcyUpgrade: Prefix on Axe/Bow/Daggers/Hammer/Scythe/Spear/Sword; damage_type =Cold]
Global Const $STRUCT_MOD_SHOCKING							= '0004B824'	;[v11 audit: DamageTypeProperty(0x24B) arg1=4 arg2=0 | Py4GW ShockingUpgrade: Prefix on Axe/Bow/Daggers/Hammer/Scythe/Spear/Sword; damage_type =Lightning]

Global Const $STRUCT_MOD_FURIOUS							= '0A00B823'	;adrenaline * 2 ^ 20% [v11 audit: Furious(0x23B) arg1=0 arg2=10 | Py4GW FuriousUpgrade: Prefix on Axe/Daggers/Hammer/Scythe/Spear/Sword; chance 2-10]
Global Const $STRUCT_MOD_SUNDERING							= '1414F823'	;armor penetration 20^20 [v11 audit: ArmorPenetration(0x23F) arg1=20 arg2=20 | Py4GW SunderingUpgrade: Prefix on Axe/Bow/Daggers/Hammer/Scythe/Spear/Sword; chance 10-20, armor_penetration =20]

Global Const $STRUCT_MOD_VAMPIRIC_3							= '00032825'	;[v11 audit: HealthStealOnHit(0x252) arg1=3 arg2=0 | Py4GW VampiricMinorUpgrade: Prefix on Axe/Daggers/Spear/Sword; health_regeneration =-1, health_steal =3]
Global Const $STRUCT_MOD_VAMPIRIC_5							= '00052825'	;[v11 audit: HealthStealOnHit(0x252) arg1=5 arg2=0 | Py4GW VampiricMajorUpgrade: Prefix on Bow/Hammer/Scythe; health_regeneration =-1, health_steal =5]
Global Const $STRUCT_MOD_ZEALOUS							= '01001825'	;[v11 audit: EnergyGainOnHit(0x251) arg1=0 arg2=1 | Py4GW ZealousUpgrade: Prefix on Axe/Bow/Daggers/Hammer/Scythe/Spear/Sword; energy_gain =1, energy_regeneration =-1]
#EndRegion Martial prefix mods

#Region Staff prefix mods
Global Const $STRUCT_MOD_HALE								= $STRUCT_30_HEALTH	;+30 health [v11 audit: HealthPlus(0x234) arg1=30 arg2=0 | Py4GW HaleUpgrade: Prefix on Staff; health 10-30]
Global Const $STRUCT_MOD_ADEPT								= $STRUCT_MOD_HCT_20	;hct 20 [v11 audit: HalvesCastingTimeItemAttribute(0x280) arg1=20 arg2=0 | Py4GW AdeptUpgrade: Prefix]
Global Const $STRUCT_MOD_SWIFT								= $STRUCT_MOD_HCT_10	;hct 10 [v11 audit: HalvesCastingTimeGeneral(0x220) arg1=10 arg2=0 | Py4GW SwiftUpgrade: Prefix on Staff; chance 5-10]
Global Const $STRUCT_MOD_INSIGHTFUL							= $STRUCT_5_ENERGY	;+5 energy [v11 audit: EnergyPlus(0x22D) arg1=0 arg2=5 | Py4GW InsightfulUpgrade: Prefix on Staff; energy 1-5]
Global Const $STRUCT_MOD_DEFENSIVE							= $STRUCT_5_ARMOR	;+5 armor [v11 audit: ArmorPlus(0x210) arg1=0 arg2=5 | Py4GW DefensiveUpgrade: Prefix on Staff]
#EndRegion Staff prefix mods
#EndRegion Prefixes

#Region Suffixes
Global Const $STRUCT_MOD_OF_FORTITUDE						= $STRUCT_30_HEALTH	;+30 health [v11 audit: HealthPlus(0x234) arg1=30 arg2=0 | Py4GW OfFortitudeUpgrade: Suffix on Axe/Bow/Daggers/Hammer/Offhand/Scythe/Shield/Spear/Staff/Sword; health 10-30]

#Region Martial and staff suffix mods
Global Const $STRUCT_MOD_OF_DEFENSE							= $STRUCT_5_ARMOR	;+5 armor [v11 audit: ArmorPlus(0x210) arg1=0 arg2=5 | Py4GW OfDefenseUpgrade: Suffix on Axe/Bow/Daggers/Hammer/Scythe/Spear/Staff/Sword; armor 4-5]
Global Const $STRUCT_MOD_OF_SHELTER							= '07005821'	;+7 armor vs physical [v11 audit: ArmorPlusVsPhysical(0x215) arg1=0 arg2=7 | Py4GW OfShelterUpgrade: Suffix on Axe/Bow/Daggers/Hammer/Scythe/Spear/Staff/Sword; armor 4-7]
Global Const $STRUCT_MOD_OF_WARDING							= '07002821'	;+7 armor vs elemental [v11 audit: ArmorPlusVsElemental(0x212) arg1=0 arg2=7 | Py4GW OfWardingUpgrade: Suffix on Axe/Bow/Daggers/Hammer/Scythe/Spear/Staff/Sword; armor 4-7]
Global Const $STRUCT_MOD_OF_ENCHANTING						= '1400B822'	;+20% enchantment duration [v11 audit: IncreaseEnchantmentDuration(0x22B) arg1=0 arg2=20 | Py4GW OfEnchantingUpgrade: Suffix on Axe/Bow/Daggers/Hammer/Scythe/Spear/Staff/Sword; enchantment_duration 10-20]

Global Const $STRUCT_MOD_OF_THE_WARRIOR						= '0511A828'	;[v11 audit: OfTheProfession(0x28A) arg1=17 arg2=5 | Py4GW OfTheWarriorUpgrade: Suffix; attribute =Strength, attribute_level 4-5, profession =Warrior]
Global Const $STRUCT_MOD_OF_THE_RANGER						= '0517A828'	;[v11 audit: OfTheProfession(0x28A) arg1=23 arg2=5 | Py4GW OfTheRangerUpgrade: Suffix; attribute =Expertise, attribute_level 4-5, profession =Ranger]
Global Const $STRUCT_MOD_OF_THE_NECROMANCER					= '0506A828'	;[v11 audit: OfTheProfession(0x28A) arg1=6 arg2=5 | Py4GW OfTheNecromancerUpgrade: Suffix; attribute =SoulReaping, attribute_level 4-5, profession =Necromancer]
Global Const $STRUCT_MOD_OF_THE_MESMER						= '0500A828'	;[v11 audit: OfTheProfession(0x28A) arg1=0 arg2=5 | Py4GW OfTheMesmerUpgrade: Suffix; attribute =FastCasting, attribute_level 4-5, profession =Mesmer]
Global Const $STRUCT_MOD_OF_THE_ELEMENTALIST				= '050CA828'	;[v11 audit: OfTheProfession(0x28A) arg1=12 arg2=5 | Py4GW OfTheElementalistUpgrade: Suffix; attribute =EnergyStorage, attribute_level 4-5, profession =Elementalist]
Global Const $STRUCT_MOD_OF_THE_MONK						= '0510A828'	;[v11 audit: OfTheProfession(0x28A) arg1=16 arg2=5 | Py4GW OfTheMonkUpgrade: Suffix; attribute =DivineFavor, attribute_level 4-5, profession =Monk]
Global Const $STRUCT_MOD_OF_THE_RITUALIST					= '0524A828'	;[v11 audit: OfTheProfession(0x28A) arg1=36 arg2=5 | Py4GW OfTheRitualistUpgrade: Suffix; attribute =SpawningPower, attribute_level 4-5, profession =Ritualist]
Global Const $STRUCT_MOD_OF_THE_ASSASSIN					= '0523A828'	;[v11 audit: OfTheProfession(0x28A) arg1=35 arg2=5 | Py4GW OfTheAssassinUpgrade: Suffix; attribute =CriticalStrikes, attribute_level 4-5, profession =Assassin]
Global Const $STRUCT_MOD_OF_THE_PARAGON						= '0528A828'	;[v11 audit: OfTheProfession(0x28A) arg1=40 arg2=5 | Py4GW OfTheParagonUpgrade: Suffix; attribute =Leadership, attribute_level 4-5, profession =Paragon]
Global Const $STRUCT_MOD_OF_THE_DERVISH						= '052CA828'	;[v11 audit: OfTheProfession(0x28A) arg1=44 arg2=5 | Py4GW OfTheDervishUpgrade: Suffix; attribute =Mysticism, attribute_level 4-5, profession =Dervish]

; This is not available for staff
; +1^20%
Global Const $STRUCT_MOD_OF_AXE_MASTERY						= '14121824'	;[v11 audit: AttributePlusOne(0x241) arg1=18 arg2=20 | Py4GW OfAxeMasteryUpgrade: Suffix on Axe; attribute =AxeMastery, chance 10-20, attribute_level =1]
Global Const $STRUCT_MOD_OF_MARKSMANSHIP					= '14191824'	;[v11 audit: AttributePlusOne(0x241) arg1=25 arg2=20 | Py4GW OfMarksmanshipUpgrade: Suffix on Bow; attribute =Marksmanship, chance 10-20, attribute_level =1]
Global Const $STRUCT_MOD_OF_DAGGER_MASTERY					= '141D1824'	;[v11 audit: AttributePlusOne(0x241) arg1=29 arg2=20 | Py4GW OfDaggerMasteryUpgrade: Suffix on Daggers; attribute =DaggerMastery, chance 10-20, attribute_level =1]
Global Const $STRUCT_MOD_OF_HAMMER_MASTERY					= '14131824'	;[v11 audit: AttributePlusOne(0x241) arg1=19 arg2=20 | Py4GW OfHammerMasteryUpgrade: Suffix on Hammer; attribute =HammerMastery, chance 10-20, attribute_level =1]
Global Const $STRUCT_MOD_OF_SCYTHE_MASTERY					= '14291824'	;[v11 audit: AttributePlusOne(0x241) arg1=41 arg2=20 | Py4GW OfScytheMasteryUpgrade: Suffix on Scythe; attribute =ScytheMastery, chance 10-20, attribute_level =1]
Global Const $STRUCT_MOD_OF_SPEAR_MASTERY					= '14251824'	;[v11 audit: AttributePlusOne(0x241) arg1=37 arg2=20 | Py4GW OfSpearMasteryUpgrade: Suffix on Spear; attribute =SpearMastery, chance 10-20, attribute_level =1]
Global Const $STRUCT_MOD_OF_SWORDMANSHIP					= '14141824'	;[v11 audit: AttributePlusOne(0x241) arg1=20 arg2=20 | Py4GW OfSwordsmanshipUpgrade: Suffix on Sword; attribute =Swordsmanship, chance 10-20, attribute_level =1]

; Those are not available for staves, daggers, spears and scythes
Global Const $STRUCT_MOD_OF_DEATHBANE						= '00008080'	;[v11 audit: BaneSpecies(0x008) arg1=0 arg2=0 | Py4GW OfUndeadSlayingUpgrade: Suffix; species =Undead, damage_increase 15-20]
Global Const $STRUCT_MOD_OF_CHARRSLAYING					= '00018080'	;[v11 audit: BaneSpecies(0x008) arg1=1 arg2=0 | Py4GW OfCharrSlayingUpgrade: Suffix; species =Charr, damage_increase 15-20]
Global Const $STRUCT_MOD_OF_TROLLSLAYING					= '00028080'	;[v11 audit: BaneSpecies(0x008) arg1=2 arg2=0 | Py4GW OfTrollsSlayingUpgrade: Suffix; species =Trolls, damage_increase 15-20]
Global Const $STRUCT_MOD_OF_PRUNING							= '00038080'	;[v11 audit: BaneSpecies(0x008) arg1=3 arg2=0 | Py4GW OfPlantsSlayingUpgrade: Suffix; species =Plants, damage_increase 15-20]
Global Const $STRUCT_MOD_OF_SKELETON_SLAYING				= '00048080'	;[v11 audit: BaneSpecies(0x008) arg1=4 arg2=0 | Py4GW OfSkeletonsSlayingUpgrade: Suffix; species =Skeletons, damage_increase 15-20]
Global Const $STRUCT_MOD_OF_GIANT_SLAYING					= '00058080'	;[v11 audit: BaneSpecies(0x008) arg1=5 arg2=0 | Py4GW OfGiantsSlayingUpgrade: Suffix; species =Giants, damage_increase 15-20]
Global Const $STRUCT_MOD_OF_DWARF_SLAYING					= '00068080'	;[v11 audit: BaneSpecies(0x008) arg1=6 arg2=0 | Py4GW OfDwarvesSlayingUpgrade: Suffix; species =Dwarves, damage_increase 15-20]
Global Const $STRUCT_MOD_OF_TENGU_SLAYING					= '00078080'	;[v11 audit: BaneSpecies(0x008) arg1=7 arg2=0 | Py4GW OfTengusSlayingUpgrade: Suffix; species =Tengus, damage_increase 15-20]
Global Const $STRUCT_MOD_OF_DEMON_SLAYING					= '00088080'	;[v11 audit: BaneSpecies(0x008) arg1=8 arg2=0 | Py4GW OfDemonsSlayingUpgrade: Suffix; species =Demons, damage_increase 15-20]
Global Const $STRUCT_MOD_OF_OGRE_SLAYING					= '000A8080'	;[v11 audit: BaneSpecies(0x008) arg1=10 arg2=0 | Py4GW OfOgresSlayingUpgrade: Suffix; species =Ogres, damage_increase 15-20]
Global Const $STRUCT_MOD_OF_DRAGON_SLAYING					= '00098080'	;[v11 audit: BaneSpecies(0x008) arg1=9 arg2=0 | Py4GW OfDragonsSlayingUpgrade: Suffix; species =Dragons, damage_increase 15-20]
#EndRegion Martial and staff suffix mods


#Region Staff suffix mods
Global Const $STRUCT_MOD_OF_MASTERY							= $STRUCT_1_20_ATTRIBUTE	;+1^20% [v11 audit: AttributePlusOneItem(0x283) arg1=20 arg2=0 | Py4GW OfMasteryUpgrade: Suffix on Staff; chance 10-20, attribute_level =1]
#EndRegion Staff suffix mods


#Region Wand suffix mods
Global Const $STRUCT_MOD_OF_MEMORY							= $STRUCT_MOD_HSR_20	;[v11 audit: HalvesSkillRechargeItemAttribute(0x282) arg1=20 arg2=0 | Py4GW OfMemoryUpgrade: Suffix on Wand; chance 10-20]
Global Const $STRUCT_MOD_OF_QUICKENING						= $STRUCT_MOD_HSR_10	;[v11 audit: HalvesSkillRechargeGeneral(0x23A) arg1=10 arg2=0 | Py4GW OfQuickeningUpgrade: Suffix on Wand; chance 5-10]
#EndRegion Wand suffix mods


#Region Staff, focus and shield suffix mods
Global Const $STRUCT_MOD_OF_DEVOTION						= '002D6823'	;+45 health while enchanted [v11 audit: HealthPlusEnchanted(0x236) arg1=45 arg2=0 | Py4GW OfDevotionUpgrade: Suffix on Offhand/Shield/Staff; health 30-45]
Global Const $STRUCT_MOD_OF_ENDURANCE						= '002D8823'	;+45 health while in a stance [v11 audit: HealthPlusStance(0x238) arg1=45 arg2=0 | Py4GW OfEnduranceUpgrade: Suffix on Offhand/Shield/Staff; health 30-45]
Global Const $STRUCT_MOD_OF_VALOR							= '003C7823'	;+60 health while hexed [v11 audit: HealthPlusHexed(0x237) arg1=60 arg2=0 | Py4GW OfValorUpgrade: Suffix on Offhand/Shield/Staff; health 45-60]
#EndRegion Staff, focus and shield suffix mods


#Region Focus suffix mods
Global Const $STRUCT_MOD_OF_APTITUDE						= $STRUCT_MOD_HCT_20	;[v11 audit: HalvesCastingTimeItemAttribute(0x280) arg1=20 arg2=0 | Py4GW OfAptitudeUpgrade: Suffix on Offhand; chance 10-20]
Global Const $STRUCT_MOD_OF_SWIFTNESS						= $STRUCT_MOD_HCT_10	;[v11 audit: HalvesCastingTimeGeneral(0x220) arg1=10 arg2=0 | Py4GW OfSwiftnessUpgrade: Suffix on Offhand; chance 5-10]
#EndRegion Focus suffix mods
#EndRegion Suffixes
#EndRegion Mods


#Region inherent bonus
#Region martial weapons
Global Const $STRUCT_INHERENT_ZEALOUS_STRENGTH				= $STRUCT_ENERGY_REGENERATION	;+15% damage energy regeneration -1 - energy regeneration -1 part [v11 audit: EnergyRegeneration(0x20C) arg1=0 arg2=1]
;Global Const $STRUCT_INHERENT_ZEALOUS_STRENGTH_2			= $STRUCT_15_DAMAGE				;+15% damage -1 energy regeneration - +15% damage part

Global Const $STRUCT_INHERENT_VAMPIRIC_STRENGTH				= '0100E820'	;+15% damage health regeneration -1 - health regeneration -1 part [v11 audit: HealthRegeneneration(0x20E) arg1=0 arg2=1]
;Global Const $STRUCT_INHERENT_VAMPIRIC_STRENGTH_2			= $STRUCT_15_DAMAGE				;+15% damage -1 health regeneration - +15% damage part
#EndRegion martial weapons


#Region caster weapons and focus
Global Const $STRUCT_INHERENT_FIRE_MAGIC_HCT				= '0A141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=10]
Global Const $STRUCT_INHERENT_FIRE_MAGIC_HSR				= '0A149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=10]
Global Const $STRUCT_INHERENT_WATER_MAGIC_HCT				= '0B141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=11]
Global Const $STRUCT_INHERENT_WATER_MAGIC_HSR				= '0B149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=11]
Global Const $STRUCT_INHERENT_AIR_MAGIC_HCT					= '08141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=8]
Global Const $STRUCT_INHERENT_AIR_MAGIC_HSR					= '08149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=8]
Global Const $STRUCT_INHERENT_EARTH_MAGIC_HCT				= '09141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=9]
Global Const $STRUCT_INHERENT_EARTH_MAGIC_HSR				= '09149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=9]
Global Const $STRUCT_INHERENT_ENERGY_STORAGE_HCT			= '0C141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=12]
Global Const $STRUCT_INHERENT_ENERGY_STORAGE_HSR			= '0C149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=12]
Global Const $STRUCT_INHERENT_SMITING_PRAYERS_HCT			= '0E141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=14]
Global Const $STRUCT_INHERENT_SMITING_PRAYERS_HSR			= '0E149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=14]
Global Const $STRUCT_INHERENT_DIVINE_FAVOR_HCT				= '10141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=16]
Global Const $STRUCT_INHERENT_DIVINE_FAVOR_HSR				= '10149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=16]
Global Const $STRUCT_INHERENT_HEALING_PRAYERS_HCT			= '0D141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=13]
Global Const $STRUCT_INHERENT_HEALING_PRAYERS_HSR			= '0D149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=13]
Global Const $STRUCT_INHERENT_PROTECTION_PRAYERS_HCT		= '0F141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=15]
Global Const $STRUCT_INHERENT_PROTECTION_PRAYERS_HSR		= '0F149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=15]
Global Const $STRUCT_INHERENT_CHANNELING_MAGIC_HCT			= '22141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=34]
Global Const $STRUCT_INHERENT_CHANNELING_MAGIC_HSR			= '22149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=34]
Global Const $STRUCT_INHERENT_RESTORATION_MAGIC_HCT			= '21141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=33]
Global Const $STRUCT_INHERENT_RESTORATION_MAGIC_HSR			= '21149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=33]
Global Const $STRUCT_INHERENT_COMMUNING_HCT					= '20141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=32]
Global Const $STRUCT_INHERENT_COMMUNING_HSR					= '20149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=32]
Global Const $STRUCT_INHERENT_SPAWNING_POWER_HCT			= '24141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=36]
Global Const $STRUCT_INHERENT_SPAWNING_POWER_HSR			= '24149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=36]
Global Const $STRUCT_INHERENT_ILLUSION_MAGIC_HCT			= '01141822'	;[v11 audit: FIXED label - was '01149823' (the HSR value); HalvesCastingTimeAttribute(0x221) arg1=20 (chance %) arg2=0x01 attribute - Py4GW ModifierIdentifier]
Global Const $STRUCT_INHERENT_ILLUSION_MAGIC_HSR			= '01149823'	;[v11 audit: FIXED label - was '01141822' (the HCT value); HalvesSkillRechargeAttribute(0x239) arg1=20 (chance %) arg2=0x01 attribute - Py4GW ModifierIdentifier]
Global Const $STRUCT_INHERENT_DOMINATION_MAGIC_HCT			= '02141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=2]
Global Const $STRUCT_INHERENT_DOMINATION_MAGIC_HSR			= '02149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=2]
Global Const $STRUCT_INHERENT_INSPIRATION_MAGIC_HCT			= '03141822'	;[v11 audit: FIXED label - was '03149823' (the HSR value); HalvesCastingTimeAttribute(0x221) arg1=20 (chance %) arg2=0x03 attribute - Py4GW ModifierIdentifier]
Global Const $STRUCT_INHERENT_INSPIRATION_MAGIC_HSR			= '03149823'	;[v11 audit: FIXED label - was '03141822' (the HCT value); HalvesSkillRechargeAttribute(0x239) arg1=20 (chance %) arg2=0x03 attribute - Py4GW ModifierIdentifier]
Global Const $STRUCT_INHERENT_DEATH_MAGIC_HCT				= '05141822'	;[v11 audit: HalvesCastingTimeAttribute(0x221) arg1=20 arg2=5]
Global Const $STRUCT_INHERENT_DEATH_MAGIC_HSR				= '05149823'	;[v11 audit: HalvesSkillRechargeAttribute(0x239) arg1=20 arg2=5]
Global Const $STRUCT_INHERENT_BLOOD_MAGIC_HCT				= '04141822'	;[v11 audit: FIXED label - was '04149823' (the HSR value); HalvesCastingTimeAttribute(0x221) arg1=20 (chance %) arg2=0x04 attribute - Py4GW ModifierIdentifier]
Global Const $STRUCT_INHERENT_BLOOD_MAGIC_HSR				= '04149823'	;[v11 audit: FIXED label - was '04141822' (the HCT value); HalvesSkillRechargeAttribute(0x239) arg1=20 (chance %) arg2=0x04 attribute - Py4GW ModifierIdentifier]
Global Const $STRUCT_INHERENT_SOUL_REAPING_HCT				= '06141822'	;[v11 audit: FIXED label - was '06149823' (the HSR value); HalvesCastingTimeAttribute(0x221) arg1=20 (chance %) arg2=0x06 attribute - Py4GW ModifierIdentifier]
Global Const $STRUCT_INHERENT_SOUL_REAPING_HSR				= '06149823'	;[v11 audit: FIXED label - was '06141822' (the HCT value); HalvesSkillRechargeAttribute(0x239) arg1=20 (chance %) arg2=0x06 attribute - Py4GW ModifierIdentifier]
Global Const $STRUCT_INHERENT_CURSES_HCT					= '07141822'	;[v11 audit: FIXED label - was '07149823' (the HSR value); HalvesCastingTimeAttribute(0x221) arg1=20 (chance %) arg2=0x07 attribute - Py4GW ModifierIdentifier]
Global Const $STRUCT_INHERENT_CURSES_HSR					= '07149823'	;[v11 audit: FIXED label - was '07141822' (the HCT value); HalvesSkillRechargeAttribute(0x239) arg1=20 (chance %) arg2=0x07 attribute - Py4GW ModifierIdentifier]
#EndRegion caster weapons and focus

#Region focus and shield OS (Old School)
; 10 armor VS ...
Global Const $STRUCT_INHERENT_ARMOR_VS_UNDEAD				= '0A004821'	;'A0048210' [v11 audit: ArmorPlusVsSpecies(0x214) arg1=0 arg2=10]
Global Const $STRUCT_INHERENT_ARMOR_VS_CHARR				= '0A014821'	;[v11 audit: ArmorPlusVsSpecies(0x214) arg1=1 arg2=10]
Global Const $STRUCT_INHERENT_ARMOR_VS_TROLLS				= '0A024821'	;[v11 audit: ArmorPlusVsSpecies(0x214) arg1=2 arg2=10]
Global Const $STRUCT_INHERENT_ARMOR_VS_PLANTS				= '0A034821'	;'A0348210' [v11 audit: ArmorPlusVsSpecies(0x214) arg1=3 arg2=10]
Global Const $STRUCT_INHERENT_ARMOR_VS_SKELETONS			= '0A044821'	;[v11 audit: ArmorPlusVsSpecies(0x214) arg1=4 arg2=10]
Global Const $STRUCT_INHERENT_ARMOR_VS_GIANTS				= '0A054821'	;[v11 audit: ArmorPlusVsSpecies(0x214) arg1=5 arg2=10]
Global Const $STRUCT_INHERENT_ARMOR_VS_DWARVES				= '0A064821'	;[v11 audit: ArmorPlusVsSpecies(0x214) arg1=6 arg2=10]
Global Const $STRUCT_INHERENT_ARMOR_VS_TENGU				= '0A074821'	;'A0748210' [v11 audit: ArmorPlusVsSpecies(0x214) arg1=7 arg2=10]
Global Const $STRUCT_INHERENT_ARMOR_VS_DEMONS				= '0A084821'	;'A0848210' [v11 audit: ArmorPlusVsSpecies(0x214) arg1=8 arg2=10]
Global Const $STRUCT_INHERENT_ARMOR_VS_DRAGONS				= '0A094821'	;'A0948210' [v11 audit: ArmorPlusVsSpecies(0x214) arg1=9 arg2=10]
Global Const $STRUCT_INHERENT_ARMOR_VS_OGRES				= '0A0A4821'	;[v11 audit: ArmorPlusVsSpecies(0x214) arg1=10 arg2=10]

; +1^19% and +1^20%
; Adding 14 to the modstruct as a prefix gives you only +1^20%
Global Const $STRUCT_INHERENT_OF_ILLUSION_MAGIC				= '0118240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_DOMINATION_MAGIC			= '0218240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_INSPIRATION				= '0318240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_BLOOD_MAGIC				= '0418240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_DEATH_MAGIC				= '0518240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_SOUL_REAPING				= '0618240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_CURSE_MAGIC				= '0718240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_AIR_MAGIC					= '0818240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_EARTH_MAGIC				= '0918240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_FIRE_MAGIC					= '0A18240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_WATER_MAGIC				= '0B18240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_HEALING_PRAYERS			= '0D18240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_SMITING_PRAYERS			= '0E18240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_PROTECTION_PRAYERS			= '0F18240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_DIVINE_FAVOR				= '1018240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_COMMUNING_MAGIC			= '2018240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_RESTORATION_MAGIC			= '2118240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_CHANNELING_MAGIC			= '2218240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
Global Const $STRUCT_INHERENT_OF_SPAWNING_MAGIC				= '2418240'	;[v11 audit: UNVERIFIED partial match - arg1 (attribute) + AttributePlusOne(0x241) identifier + 1st char of next dword; chance byte not checked (19/20%)]
#EndRegion focus and shield OS (Old School)
#EndRegion inherent bonus


#Region Runes
Global Const $ID_WARRIOR_INSIGNIAS_KNIGHTS					= '19152'
Global Const $ID_WARRIOR_INSIGNIAS_LIEUTENANTS				= '19153'
Global Const $ID_WARRIOR_INSIGNIAS_STONEFIST				= '19154'
Global Const $ID_WARRIOR_INSIGNIAS_DREADNOUGHT				= '19155'
Global Const $ID_WARRIOR_INSIGNIAS_SENTINELS				= '19156'
Global Const $ID_WARRIOR_RUNES_MINOR_ABSORPTION				= '903'
Global Const $ID_WARRIOR_RUNES_MINOR_AXE_MASTERY			= '903'
Global Const $ID_WARRIOR_RUNES_MINOR_HAMMER_MASTERY			= '903'
Global Const $ID_WARRIOR_RUNES_MINOR_STRENGTH				= '903'
Global Const $ID_WARRIOR_RUNES_MINOR_SWORDSMANSHIP			= '903'
Global Const $ID_WARRIOR_RUNES_MINOR_TACTICS				= '903'
Global Const $ID_WARRIOR_RUNES_MAJOR_ABSORPTION				= '5558'
Global Const $ID_WARRIOR_RUNES_MAJOR_AXE_MASTERY			= '5558'
Global Const $ID_WARRIOR_RUNES_MAJOR_HAMMER_MASTERY			= '5558'
Global Const $ID_WARRIOR_RUNES_MAJOR_STRENGTH				= '5558'
Global Const $ID_WARRIOR_RUNES_MAJOR_SWORDSMANSHIP			= '5558'
Global Const $ID_WARRIOR_RUNES_MAJOR_TACTICS				= '5558'
Global Const $ID_WARRIOR_RUNES_SUPERIOR_AXE_MASTERY			= '5559'
Global Const $ID_WARRIOR_RUNES_SUPERIOR_HAMMER_MASTERY		= '5559'
Global Const $ID_WARRIOR_RUNES_SUPERIOR_STRENGTH			= '5559'
Global Const $ID_WARRIOR_RUNES_SUPERIOR_SWORDSMANSHIP		= '5559'
Global Const $ID_WARRIOR_RUNES_SUPERIOR_TACTICS				= '5559'
Global Const $ID_WARRIOR_RUNES_SUPERIOR_ABSORPTION			= '5559'
Global Const $ID_RANGER_INSIGNIAS_FROSTBOUND				= '19157'
Global Const $ID_RANGER_INSIGNIAS_PYREBOUND					= '19159'
Global Const $ID_RANGER_INSIGNIAS_STORMBOUND				= '19160'
Global Const $ID_RANGER_INSIGNIAS_SCOUTS					= '19162'
Global Const $ID_RANGER_INSIGNIAS_EARTHBOUND				= '19158'
Global Const $ID_RANGER_INSIGNIAS_BEASTMASTERS				= '19161'
Global Const $ID_RANGER_RUNES_MINOR_BEAST_MASTERY			= '904'
Global Const $ID_RANGER_RUNES_MINOR_EXPERTISE				= '904'
Global Const $ID_RANGER_RUNES_MINOR_MARKSMANSHIP			= '904'
Global Const $ID_RANGER_RUNES_MINOR_WILDERNESS_SURVIVAL		= '904'
Global Const $ID_RANGER_RUNES_MAJOR_BEAST_MASTERY			= '5560'
Global Const $ID_RANGER_RUNES_MAJOR_EXPERTISE				= '5560'
Global Const $ID_RANGER_RUNES_MAJOR_MARKSMANSHIP			= '5560'
Global Const $ID_RANGER_RUNES_MAJOR_WILDERNESS_SURVIVAL		= '5560'
Global Const $ID_RANGER_RUNES_SUPERIOR_BEAST_MASTERY		= '5561'
Global Const $ID_RANGER_RUNES_SUPERIOR_EXPERTISE			= '5561'
Global Const $ID_RANGER_RUNES_SUPERIOR_MARKSMANSHIP			= '5561'
Global Const $ID_RANGER_RUNES_SUPERIOR_WILDERNESS_SURVIVAL	= '5561'
Global Const $ID_MONK_INSIGNIAS_WANDERERS					= '19149'
Global Const $ID_MONK_INSIGNIAS_DISCIPLES					= '19150'
Global Const $ID_MONK_INSIGNIAS_ANCHORITES					= '19151'
Global Const $ID_MONK_RUNES_MINOR_DIVINE_FAVOR				= '902'
Global Const $ID_MONK_RUNES_MINOR_HEALING_PRAYERS			= '902'
Global Const $ID_MONK_RUNES_MINOR_PROTECTION_PRAYERS		= '902'
Global Const $ID_MONK_RUNES_MINOR_SMITING_PRAYERS			= '902'
Global Const $ID_MONK_RUNES_MAJOR_HEALING_PRAYERS			= '5556'
Global Const $ID_MONK_RUNES_MAJOR_PROTECTION_PRAYERS		= '5556'
Global Const $ID_MONK_RUNES_MAJOR_SMITING_PRAYERS			= '5556'
Global Const $ID_MONK_RUNES_MAJOR_DIVINE_FAVOR				= '5556'
Global Const $ID_MONK_RUNES_SUPERIOR_DIVINE_FAVOR			= '5557'
Global Const $ID_MONK_RUNES_SUPERIOR_HEALING_PRAYERS		= '5557'
Global Const $ID_MONK_RUNES_SUPERIOR_PROTECTION_PRAYERS		= '5557'
Global Const $ID_MONK_RUNES_SUPERIOR_SMITING_PRAYERS		= '5557'
Global Const $ID_NECROMANCER_INSIGNIAS_BLOODSTAINED			= '19138'
Global Const $ID_NECROMANCER_INSIGNIAS_TORMENTORS			= '19139'
Global Const $ID_NECROMANCER_INSIGNIAS_BONELACE				= '19141'
Global Const $ID_NECROMANCER_INSIGNIAS_MINION_MASTERS		= '19142'
Global Const $ID_NECROMANCER_INSIGNIAS_BLIGHTERS			= '19143'
Global Const $ID_NECROMANCER_INSIGNIAS_UNDERTAKERS			= '19140'
Global Const $ID_NECROMANCER_RUNES_MINOR_BLOOD_MAGIC		= '900'
Global Const $ID_NECROMANCER_RUNES_MINOR_CURSES				= '900'
Global Const $ID_NECROMANCER_RUNES_MINOR_DEATH_MAGIC		= '900'
Global Const $ID_NECROMANCER_RUNES_MINOR_SOUL_REAPING		= '900'
Global Const $ID_NECROMANCER_RUNES_MAJOR_BLOOD_MAGIC		= '5552'
Global Const $ID_NECROMANCER_RUNES_MAJOR_CURSES				= '5552'
Global Const $ID_NECROMANCER_RUNES_MAJOR_DEATH_MAGIC		= '5552'
Global Const $ID_NECROMANCER_RUNES_MAJOR_SOUL_REAPING		= '5552'
Global Const $ID_NECROMANCER_RUNES_SUPERIOR_BLOOD_MAGIC		= '5553'
Global Const $ID_NECROMANCER_RUNES_SUPERIOR_CURSES			= '5553'
Global Const $ID_NECROMANCER_RUNES_SUPERIOR_DEATH_MAGIC		= '5553'
Global Const $ID_NECROMANCER_RUNES_SUPERIOR_SOUL_REAPING	= '5553'
Global Const $ID_MESMER_INSIGNIAS_VIRTUOSOS					= '19130'
Global Const $ID_MESMER_INSIGNIAS_ARTIFICERS				= '19128'
Global Const $ID_MESMER_INSIGNIAS_PRODIGYS					= '19129'
Global Const $ID_MESMER_RUNES_MINOR_DOMINATION_MAGIC		= '899'
Global Const $ID_MESMER_RUNES_MINOR_FAST_CASTING			= '899'
Global Const $ID_MESMER_RUNES_MINOR_ILLUSION_MAGIC			= '899'
Global Const $ID_MESMER_RUNES_MINOR_INSPIRATION_MAGIC		= '899'
Global Const $ID_MESMER_RUNES_MAJOR_DOMINATION_MAGIC		= '3612'
Global Const $ID_MESMER_RUNES_MAJOR_FAST_CASTING			= '3612'
Global Const $ID_MESMER_RUNES_MAJOR_ILLUSION_MAGIC			= '3612'
Global Const $ID_MESMER_RUNES_MAJOR_INSPIRATION_MAGIC		= '3612'
Global Const $ID_MESMER_RUNES_SUPERIOR_DOMINATION_MAGIC		= '5549'
Global Const $ID_MESMER_RUNES_SUPERIOR_FAST_CASTING			= '5549'
Global Const $ID_MESMER_RUNES_SUPERIOR_ILLUSION_MAGIC		= '5549'
Global Const $ID_MESMER_RUNES_SUPERIOR_INSPIRATION_MAGIC	= '5549'
Global Const $ID_ELEMENTALIST_INSIGNIAS_HYDROMANCER			= '19145'
Global Const $ID_ELEMENTALIST_INSIGNIAS_GEOMANCER			= '19146'
Global Const $ID_ELEMENTALIST_INSIGNIAS_PYROMANCER			= '19147'
Global Const $ID_ELEMENTALIST_INSIGNIAS_AEROMANCER			= '19148'
Global Const $ID_ELEMENTALIST_INSIGNIAS_PRISMATIC			= '19144'
Global Const $ID_ELEMENTALIST_RUNES_MINOR_AIR_MAGIC			= '901'
Global Const $ID_ELEMENTALIST_RUNES_MINOR_EARTH_MAGIC		= '901'
Global Const $ID_ELEMENTALIST_RUNES_MINOR_ENERGY_STORAGE	= '901'
Global Const $ID_ELEMENTALIST_RUNES_MINOR_WATER_MAGIC		= '901'
Global Const $ID_ELEMENTALIST_RUNES_MINOR_FIRE_MAGIC		= '901'
Global Const $ID_ELEMENTALIST_RUNES_MAJOR_AIR_MAGIC			= '5554'
Global Const $ID_ELEMENTALIST_RUNES_MAJOR_EARTH_MAGIC		= '5554'
Global Const $ID_ELEMENTALIST_RUNES_MAJOR_ENERGY_STORAGE	= '5554'
Global Const $ID_ELEMENTALIST_RUNES_MAJOR_FIRE_MAGIC		= '5554'
Global Const $ID_ELEMENTALIST_RUNES_MAJOR_WATER_MAGIC		= '5554'
Global Const $ID_ELEMENTALIST_RUNES_SUPERIOR_AIR_MAGIC		= '5555'
Global Const $ID_ELEMENTALIST_RUNES_SUPERIOR_EARTH_MAGIC	= '5555'
Global Const $ID_ELEMENTALIST_RUNES_SUPERIOR_ENERGY_STORAGE	= '5555'
Global Const $ID_ELEMENTALIST_RUNES_SUPERIOR_FIRE_MAGIC		= '5555'
Global Const $ID_ELEMENTALIST_RUNES_SUPERIOR_WATER_MAGIC	= '5555'
Global Const $ID_ASSASSIN_INSIGNIAS_VANGUARDS				= '19124'
Global Const $ID_ASSASSIN_INSIGNIAS_INFILTRATORS			= '19125'
Global Const $ID_ASSASSIN_INSIGNIAS_SABOTEURS				= '19126'
Global Const $ID_ASSASSIN_INSIGNIAS_NIGHTSTALKERS			= '19127'
Global Const $ID_ASSASSIN_RUNES_MINOR_CRITICAL_STRIKES		= '6324'
Global Const $ID_ASSASSIN_RUNES_MINOR_DAGGER_MASTERY		= '6324'
Global Const $ID_ASSASSIN_RUNES_MINOR_DEADLY_ARTS			= '6324'
Global Const $ID_ASSASSIN_RUNES_MINOR_SHADOW_ARTS			= '6324'
Global Const $ID_ASSASSIN_RUNES_MAJOR_CRITICAL_STRIKES		= '6325'
Global Const $ID_ASSASSIN_RUNES_MAJOR_DAGGER_MASTERY		= '6325'
Global Const $ID_ASSASSIN_RUNES_MAJOR_DEADLY_ARTS			= '6325'
Global Const $ID_ASSASSIN_RUNES_MAJOR_SHADOW_ARTS			= '6325'
Global Const $ID_ASSASSIN_RUNES_SUPERIOR_CRITICAL_STRIKES	= '6326'
Global Const $ID_ASSASSIN_RUNES_SUPERIOR_DAGGER_MASTERY		= '6326'
Global Const $ID_ASSASSIN_RUNES_SUPERIOR_DEADLY_ARTS		= '6326'
Global Const $ID_ASSASSIN_RUNES_SUPERIOR_SHADOW_ARTS		= '6326'
Global Const $ID_RITUALIST_INSIGNIAS_SHAMANS				= '19165'
Global Const $ID_RITUALIST_INSIGNIAS_GHOST_FORGE			= '19166'
Global Const $ID_RITUALIST_INSIGNIAS_MYSTICS				= '19167'
Global Const $ID_RITUALIST_RUNES_MINOR_CHANNELING_MAGIC		= '6327'
Global Const $ID_RITUALIST_RUNES_MINOR_COMMUNING			= '6327'
Global Const $ID_RITUALIST_RUNES_MINOR_RESTORATION_MAGIC	= '6327'
Global Const $ID_RITUALIST_RUNES_MINOR_SPAWNING_POWER		= '6327'
Global Const $ID_RITUALIST_RUNES_MAJOR_CHANNELING_MAGIC		= '6328'
Global Const $ID_RITUALIST_RUNES_MAJOR_COMMUNING			= '6328'
Global Const $ID_RITUALIST_RUNES_MAJOR_RESTORATION_MAGIC	= '6328'
Global Const $ID_RITUALIST_RUNES_MAJOR_SPAWNING_POWER		= '6328'
Global Const $ID_RITUALIST_RUNES_SUPERIOR_CHANNELING_MAGIC	= '6329'
Global Const $ID_RITUALIST_RUNES_SUPERIOR_COMMUNING			= '6329'
Global Const $ID_RITUALIST_RUNES_SUPERIOR_RESTORATION_MAGIC	= '6329'
Global Const $ID_RITUALIST_RUNES_SUPERIOR_SPAWNING_POWER	= '6329'
Global Const $ID_DERVISH_INSIGNIAS_WINDWALKER				= '19163'
Global Const $ID_DERVISH_INSIGNIAS_FORSAKEN					= '19164'
Global Const $ID_DERVISH_RUNES_MINOR_EARTH_PRAYERS			= '15545'
Global Const $ID_DERVISH_RUNES_MINOR_MYSTICISM				= '15545'
Global Const $ID_DERVISH_RUNES_MINOR_SCYTHE_MASTERY			= '15545'
Global Const $ID_DERVISH_RUNES_MINOR_WIND_PRAYERS			= '15545'
Global Const $ID_DERVISH_RUNES_MAJOR_EARTH_PRAYERS			= '15546'
Global Const $ID_DERVISH_RUNES_MAJOR_MYSTICISM				= '15546'
Global Const $ID_DERVISH_RUNES_MAJOR_SCYTHE_MASTERY			= '15546'
Global Const $ID_DERVISH_RUNES_MAJOR_WIND_PRAYERS			= '15546'
Global Const $ID_DERVISH_RUNES_SUPERIOR_EARTH_PRAYERS		= '15547'
Global Const $ID_DERVISH_RUNES_SUPERIOR_MYSTICISM			= '15547'
Global Const $ID_DERVISH_RUNES_SUPERIOR_SCYTHE_MASTERY		= '15547'
Global Const $ID_DERVISH_RUNES_SUPERIOR_WIND_PRAYERS		= '15547'
Global Const $ID_PARAGON_INSIGNIAS_CENTURIONS				= '19168'
Global Const $ID_PARAGON_RUNES_MINOR_COMMAND				= '15548'
Global Const $ID_PARAGON_RUNES_MINOR_LEADERSHIP				= '15548'
Global Const $ID_PARAGON_RUNES_MINOR_MOTIVATION				= '15548'
Global Const $ID_PARAGON_RUNES_MINOR_SPEAR_MASTERY			= '15548'
Global Const $ID_PARAGON_RUNES_MAJOR_COMMAND				= '15549'
Global Const $ID_PARAGON_RUNES_MAJOR_LEADERSHIP				= '15549'
Global Const $ID_PARAGON_RUNES_MAJOR_MOTIVATION				= '15549'
Global Const $ID_PARAGON_RUNES_MAJOR_SPEAR_MASTERY			= '15549'
Global Const $ID_PARAGON_RUNES_SUPERIOR_COMMAND				= '15550'
Global Const $ID_PARAGON_RUNES_SUPERIOR_LEADERSHIP			= '15550'
Global Const $ID_PARAGON_RUNES_SUPERIOR_MOTIVATION			= '15550'
Global Const $ID_PARAGON_RUNES_SUPERIOR_SPEAR_MASTERY		= '15550'
Global Const $ID_INSIGNIAS_SURVIVOR							= '19132'
Global Const $ID_INSIGNIAS_RADIANT							= '19131'
Global Const $ID_INSIGNIAS_STALWART							= '19133'
Global Const $ID_INSIGNIAS_BRAWLERS							= '19134'
Global Const $ID_INSIGNIAS_BLESSED							= '19135'
Global Const $ID_INSIGNIAS_HERALDS							= '19136'
Global Const $ID_INSIGNIAS_SENTRYS							= '19137'
Global Const $ID_RUNES_MINOR_VIGOR							= '898'
Global Const $ID_RUNES_VITAE								= '898'
Global Const $ID_RUNES_ATTUNEMENT							= '898'
Global Const $ID_RUNES_MAJOR_VIGOR							= '5550'
Global Const $ID_RUNES_RECOVERY								= '5550'
Global Const $ID_RUNES_RESTORATION							= '5550'
Global Const $ID_RUNES_CLARITY								= '5550'
Global Const $ID_RUNES_PURITY								= '5550'
Global Const $ID_RUNES_SUPERIOR_VIGOR						= '5551'


Global Const $STRUCT_WARRIOR_INSIGNIAS_KNIGHTS					= 'F9010824'	;[v11 audit: Upgrade(0x240) id 0x1F9 = Py4GW ItemUpgradeId.Knights (insignia)]
Global Const $STRUCT_WARRIOR_INSIGNIAS_LIEUTENANTS				= '08020824'	;[v11 audit: Upgrade(0x240) id 0x208 = Py4GW ItemUpgradeId.Lieutenants (insignia)]
Global Const $STRUCT_WARRIOR_INSIGNIAS_STONEFIST				= '09020824'	;[v11 audit: Upgrade(0x240) id 0x209 = Py4GW ItemUpgradeId.Stonefist (insignia)]
Global Const $STRUCT_WARRIOR_INSIGNIAS_DREADNOUGHT				= 'FA010824'	;[v11 audit: Upgrade(0x240) id 0x1FA = Py4GW ItemUpgradeId.Dreadnought (insignia)]
Global Const $STRUCT_WARRIOR_INSIGNIAS_SENTINELS				= 'FB010824'	;[v11 audit: Upgrade(0x240) id 0x1FB = Py4GW ItemUpgradeId.Sentinels (insignia)]
Global Const $STRUCT_WARRIOR_RUNES_MINOR_ABSORPTION				= 'EA02E827'	;[v11 audit: unknown id(0x27E) arg1=2 arg2=234]
Global Const $STRUCT_WARRIOR_RUNES_MINOR_AXE_MASTERY			= '0112E821'	;[v11 audit: AttributeRune(0x21E) AxeMastery +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_WARRIOR_RUNES_MINOR_HAMMER_MASTERY			= '0113E821'	;[v11 audit: AttributeRune(0x21E) HammerMastery +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_WARRIOR_RUNES_MINOR_STRENGTH				= '0111E821'	;[v11 audit: AttributeRune(0x21E) Strength +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_WARRIOR_RUNES_MINOR_SWORDSMANSHIP			= '0114E821'	;[v11 audit: AttributeRune(0x21E) Swordsmanship +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_WARRIOR_RUNES_MINOR_TACTICS				= '0115E821'	;[v11 audit: AttributeRune(0x21E) Tactics +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_WARRIOR_RUNES_MAJOR_ABSORPTION				= 'EA02E927'	;[v11 audit: unknown id(0x27E) arg1=2 arg2=234]
Global Const $STRUCT_WARRIOR_RUNES_MAJOR_AXE_MASTERY			= '0212E8217301'	;[v11 audit: AttributeRune(0x21E) AxeMastery +2, then Upgrade dword id 0x173 AppliesToMajorWarriorRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_WARRIOR_RUNES_MAJOR_HAMMER_MASTERY			= '0213E8217301'	;[v11 audit: AttributeRune(0x21E) HammerMastery +2, then Upgrade dword id 0x173 AppliesToMajorWarriorRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_WARRIOR_RUNES_MAJOR_STRENGTH				= '0211E8217301'	;[v11 audit: AttributeRune(0x21E) Strength +2, then Upgrade dword id 0x173 AppliesToMajorWarriorRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_WARRIOR_RUNES_MAJOR_SWORDSMANSHIP			= '0214E8217301'	;[v11 audit: AttributeRune(0x21E) Swordsmanship +2, then Upgrade dword id 0x173 AppliesToMajorWarriorRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_WARRIOR_RUNES_MAJOR_TACTICS				= '0215E8217301'	;[v11 audit: AttributeRune(0x21E) Tactics +2, then Upgrade dword id 0x173 AppliesToMajorWarriorRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_WARRIOR_RUNES_SUPERIOR_AXE_MASTERY			= '0312E8217F01'	;[v11 audit: AttributeRune(0x21E) AxeMastery +3, then Upgrade dword id 0x17F AppliesToSuperiorWarriorRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_WARRIOR_RUNES_SUPERIOR_HAMMER_MASTERY		= '0313E8217F01'	;[v11 audit: AttributeRune(0x21E) HammerMastery +3, then Upgrade dword id 0x17F AppliesToSuperiorWarriorRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_WARRIOR_RUNES_SUPERIOR_STRENGTH			= '0311E8217F01'	;[v11 audit: AttributeRune(0x21E) Strength +3, then Upgrade dword id 0x17F AppliesToSuperiorWarriorRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_WARRIOR_RUNES_SUPERIOR_SWORDSMANSHIP		= '0314E8217F01'	;[v11 audit: AttributeRune(0x21E) Swordsmanship +3, then Upgrade dword id 0x17F AppliesToSuperiorWarriorRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_WARRIOR_RUNES_SUPERIOR_TACTICS				= '0315E8217F01'	;[v11 audit: AttributeRune(0x21E) Tactics +3, then Upgrade dword id 0x17F AppliesToSuperiorWarriorRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_WARRIOR_RUNES_SUPERIOR_ABSORPTION			= 'EA02EA27'	;[v11 audit: unknown id(0x27E) arg1=2 arg2=234]
Global Const $STRUCT_RANGER_INSIGNIAS_FROSTBOUND				= 'FC010824'	;[v11 audit: Upgrade(0x240) id 0x1FC = Py4GW ItemUpgradeId.Frostbound (insignia)]
Global Const $STRUCT_RANGER_INSIGNIAS_PYREBOUND					= 'FE010824'	;[v11 audit: Upgrade(0x240) id 0x1FE = Py4GW ItemUpgradeId.Pyrebound (insignia)]
Global Const $STRUCT_RANGER_INSIGNIAS_STORMBOUND				= 'FF010824'	;[v11 audit: Upgrade(0x240) id 0x1FF = Py4GW ItemUpgradeId.Stormbound (insignia)]
Global Const $STRUCT_RANGER_INSIGNIAS_SCOUTS					= '01020824'	;[v11 audit: Upgrade(0x240) id 0x201 = Py4GW ItemUpgradeId.Scouts (insignia)]
Global Const $STRUCT_RANGER_INSIGNIAS_EARTHBOUND				= 'FD010824'	;[v11 audit: Upgrade(0x240) id 0x1FD = Py4GW ItemUpgradeId.Earthbound (insignia)]
Global Const $STRUCT_RANGER_INSIGNIAS_BEASTMASTERS				= '00020824'	;[v11 audit: Upgrade(0x240) id 0x200 = Py4GW ItemUpgradeId.Beastmasters (insignia)]
Global Const $STRUCT_RANGER_RUNES_MINOR_BEAST_MASTERY			= '0116E821'	;[v11 audit: AttributeRune(0x21E) BeastMastery +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_RANGER_RUNES_MINOR_EXPERTISE				= '0117E821'	;[v11 audit: AttributeRune(0x21E) Expertise +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_RANGER_RUNES_MINOR_MARKSMANSHIP			= '0119E821'	;[v11 audit: AttributeRune(0x21E) Marksmanship +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_RANGER_RUNES_MINOR_WILDERNESS_SURVIVAL		= '0118E821'	;[v11 audit: AttributeRune(0x21E) WildernessSurvival +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_RANGER_RUNES_MAJOR_BEAST_MASTERY			= '0216E8217501'	;[v11 audit: AttributeRune(0x21E) BeastMastery +2, then Upgrade dword id 0x175 AppliesToMajorRangerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RANGER_RUNES_MAJOR_EXPERTISE				= '0217E8217501'	;[v11 audit: AttributeRune(0x21E) Expertise +2, then Upgrade dword id 0x175 AppliesToMajorRangerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RANGER_RUNES_MAJOR_MARKSMANSHIP			= '0219E8217501'	;[v11 audit: AttributeRune(0x21E) Marksmanship +2, then Upgrade dword id 0x175 AppliesToMajorRangerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RANGER_RUNES_MAJOR_WILDERNESS_SURVIVAL		= '0218E8217501'	;[v11 audit: AttributeRune(0x21E) WildernessSurvival +2, then Upgrade dword id 0x175 AppliesToMajorRangerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RANGER_RUNES_SUPERIOR_BEAST_MASTERY		= '0316E8218101'	;[v11 audit: AttributeRune(0x21E) BeastMastery +3, then Upgrade dword id 0x181 AppliesToSuperiorRangerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RANGER_RUNES_SUPERIOR_EXPERTISE			= '0317E8218101'	;[v11 audit: AttributeRune(0x21E) Expertise +3, then Upgrade dword id 0x181 AppliesToSuperiorRangerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RANGER_RUNES_SUPERIOR_MARKSMANSHIP			= '0319E8218101'	;[v11 audit: AttributeRune(0x21E) Marksmanship +3, then Upgrade dword id 0x181 AppliesToSuperiorRangerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RANGER_RUNES_SUPERIOR_WILDERNESS_SURVIVAL	= '0318E8218101'	;[v11 audit: AttributeRune(0x21E) WildernessSurvival +3, then Upgrade dword id 0x181 AppliesToSuperiorRangerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MONK_INSIGNIAS_WANDERERS					= 'F6010824'	;[v11 audit: Upgrade(0x240) id 0x1F6 = Py4GW ItemUpgradeId.Wanderers (insignia)]
Global Const $STRUCT_MONK_INSIGNIAS_DISCIPLES					= 'F7010824'	;[v11 audit: Upgrade(0x240) id 0x1F7 = Py4GW ItemUpgradeId.Disciples (insignia)]
Global Const $STRUCT_MONK_INSIGNIAS_ANCHORITES					= 'F8010824'	;[v11 audit: Upgrade(0x240) id 0x1F8 = Py4GW ItemUpgradeId.Anchorites (insignia)]
Global Const $STRUCT_MONK_RUNES_MINOR_DIVINE_FAVOR				= '0110E821'	;[v11 audit: AttributeRune(0x21E) DivineFavor +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_MONK_RUNES_MINOR_HEALING_PRAYERS			= '010DE821'	;[v11 audit: AttributeRune(0x21E) HealingPrayers +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_MONK_RUNES_MINOR_PROTECTION_PRAYERS		= '010FE821'	;[v11 audit: AttributeRune(0x21E) ProtectionPrayers +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_MONK_RUNES_MINOR_SMITING_PRAYERS			= '010EE821'	;[v11 audit: AttributeRune(0x21E) SmitingPrayers +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_MONK_RUNES_MAJOR_HEALING_PRAYERS			= '020DE8217101'	;[v11 audit: AttributeRune(0x21E) HealingPrayers +2, then Upgrade dword id 0x171 AppliesToMajorMonkRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MONK_RUNES_MAJOR_PROTECTION_PRAYERS		= '020FE8217101'	;[v11 audit: AttributeRune(0x21E) ProtectionPrayers +2, then Upgrade dword id 0x171 AppliesToMajorMonkRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MONK_RUNES_MAJOR_SMITING_PRAYERS			= '020EE8217101'	;[v11 audit: AttributeRune(0x21E) SmitingPrayers +2, then Upgrade dword id 0x171 AppliesToMajorMonkRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MONK_RUNES_MAJOR_DIVINE_FAVOR				= '0210E8217101'	;[v11 audit: AttributeRune(0x21E) DivineFavor +2, then Upgrade dword id 0x171 AppliesToMajorMonkRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MONK_RUNES_SUPERIOR_DIVINE_FAVOR			= '0310E8217D01'	;[v11 audit: AttributeRune(0x21E) DivineFavor +3, then Upgrade dword id 0x17D AppliesToSuperiorMonkRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MONK_RUNES_SUPERIOR_HEALING_PRAYERS		= '030DE8217D01'	;[v11 audit: AttributeRune(0x21E) HealingPrayers +3, then Upgrade dword id 0x17D AppliesToSuperiorMonkRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MONK_RUNES_SUPERIOR_PROTECTION_PRAYERS		= '030FE8217D01'	;[v11 audit: AttributeRune(0x21E) ProtectionPrayers +3, then Upgrade dword id 0x17D AppliesToSuperiorMonkRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MONK_RUNES_SUPERIOR_SMITING_PRAYERS		= '030EE8217D01'	;[v11 audit: AttributeRune(0x21E) SmitingPrayers +3, then Upgrade dword id 0x17D AppliesToSuperiorMonkRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_NECROMANCER_INSIGNIAS_BLOODSTAINED			= '0A020824'	;[v11 audit: Upgrade(0x240) id 0x20A = Py4GW ItemUpgradeId.Bloodstained (insignia)]
Global Const $STRUCT_NECROMANCER_INSIGNIAS_TORMENTORS			= 'EC010824'	;[v11 audit: Upgrade(0x240) id 0x1EC = Py4GW ItemUpgradeId.Tormentors (insignia)]
Global Const $STRUCT_NECROMANCER_INSIGNIAS_BONELACE				= 'EE010824'	;[v11 audit: Upgrade(0x240) id 0x1EE = Py4GW ItemUpgradeId.Bonelace (insignia)]
Global Const $STRUCT_NECROMANCER_INSIGNIAS_MINION_MASTERS		= 'EF010824'	;[v11 audit: Upgrade(0x240) id 0x1EF = Py4GW ItemUpgradeId.MinionMasters (insignia)]
Global Const $STRUCT_NECROMANCER_INSIGNIAS_BLIGHTERS			= 'F0010824'	;[v11 audit: Upgrade(0x240) id 0x1F0 = Py4GW ItemUpgradeId.Blighters (insignia)]
Global Const $STRUCT_NECROMANCER_INSIGNIAS_UNDERTAKERS			= 'ED010824'	;[v11 audit: Upgrade(0x240) id 0x1ED = Py4GW ItemUpgradeId.Undertakers (insignia)]
Global Const $STRUCT_NECROMANCER_RUNES_MINOR_BLOOD_MAGIC		= '0104E821'	;[v11 audit: AttributeRune(0x21E) BloodMagic +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_NECROMANCER_RUNES_MINOR_CURSES				= '0107E821'	;[v11 audit: AttributeRune(0x21E) Curses +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_NECROMANCER_RUNES_MINOR_DEATH_MAGIC		= '0105E821'	;[v11 audit: AttributeRune(0x21E) DeathMagic +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_NECROMANCER_RUNES_MINOR_SOUL_REAPING		= '0106E821'	;[v11 audit: AttributeRune(0x21E) SoulReaping +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_NECROMANCER_RUNES_MAJOR_BLOOD_MAGIC		= '0204E8216D01'	;[v11 audit: AttributeRune(0x21E) BloodMagic +2, then Upgrade dword id 0x16D AppliesToMajorNecromancerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_NECROMANCER_RUNES_MAJOR_CURSES				= '0207E8216D01'	;[v11 audit: AttributeRune(0x21E) Curses +2, then Upgrade dword id 0x16D AppliesToMajorNecromancerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_NECROMANCER_RUNES_MAJOR_DEATH_MAGIC		= '0205E8216D01'	;[v11 audit: AttributeRune(0x21E) DeathMagic +2, then Upgrade dword id 0x16D AppliesToMajorNecromancerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_NECROMANCER_RUNES_MAJOR_SOUL_REAPING		= '0206E8216D01'	;[v11 audit: AttributeRune(0x21E) SoulReaping +2, then Upgrade dword id 0x16D AppliesToMajorNecromancerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_NECROMANCER_RUNES_SUPERIOR_BLOOD_MAGIC		= '0304E8217901'	;[v11 audit: AttributeRune(0x21E) BloodMagic +3, then Upgrade dword id 0x179 AppliesToSuperiorNecromancerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_NECROMANCER_RUNES_SUPERIOR_CURSES			= '0307E8217901'	;[v11 audit: AttributeRune(0x21E) Curses +3, then Upgrade dword id 0x179 AppliesToSuperiorNecromancerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_NECROMANCER_RUNES_SUPERIOR_DEATH_MAGIC		= '0305E8217901'	;[v11 audit: AttributeRune(0x21E) DeathMagic +3, then Upgrade dword id 0x179 AppliesToSuperiorNecromancerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_NECROMANCER_RUNES_SUPERIOR_SOUL_REAPING	= '0306E8217901'	;[v11 audit: AttributeRune(0x21E) SoulReaping +3, then Upgrade dword id 0x179 AppliesToSuperiorNecromancerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MESMER_INSIGNIAS_VIRTUOSOS					= 'E4010824'	;[v11 audit: Upgrade(0x240) id 0x1E4 = Py4GW ItemUpgradeId.Virtuosos (insignia)]
Global Const $STRUCT_MESMER_INSIGNIAS_ARTIFICERS				= 'E2010824'	;[v11 audit: Upgrade(0x240) id 0x1E2 = Py4GW ItemUpgradeId.Artificers (insignia)]
Global Const $STRUCT_MESMER_INSIGNIAS_PRODIGYS					= 'E3010824'	;[v11 audit: Upgrade(0x240) id 0x1E3 = Py4GW ItemUpgradeId.Prodigys (insignia)]
Global Const $STRUCT_MESMER_RUNES_MINOR_DOMINATION_MAGIC		= '0102E821'	;[v11 audit: AttributeRune(0x21E) DominationMagic +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_MESMER_RUNES_MINOR_FAST_CASTING			= '0100E821'	;[v11 audit: AttributeRune(0x21E) FastCasting +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_MESMER_RUNES_MINOR_ILLUSION_MAGIC			= '0101E821'	;[v11 audit: AttributeRune(0x21E) IllusionMagic +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_MESMER_RUNES_MINOR_INSPIRATION_MAGIC		= '0103E821'	;[v11 audit: AttributeRune(0x21E) InspirationMagic +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_MESMER_RUNES_MAJOR_DOMINATION_MAGIC		= '0202E8216B01'	;[v11 audit: AttributeRune(0x21E) DominationMagic +2, then Upgrade dword id 0x16B AppliesToMajorMesmerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MESMER_RUNES_MAJOR_FAST_CASTING			= '0200E8216B01'	;[v11 audit: AttributeRune(0x21E) FastCasting +2, then Upgrade dword id 0x16B AppliesToMajorMesmerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MESMER_RUNES_MAJOR_ILLUSION_MAGIC			= '0201E8216B01'	;[v11 audit: AttributeRune(0x21E) IllusionMagic +2, then Upgrade dword id 0x16B AppliesToMajorMesmerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MESMER_RUNES_MAJOR_INSPIRATION_MAGIC		= '0203E8216B01'	;[v11 audit: AttributeRune(0x21E) InspirationMagic +2, then Upgrade dword id 0x16B AppliesToMajorMesmerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MESMER_RUNES_SUPERIOR_DOMINATION_MAGIC		= '0302E8217701'	;[v11 audit: AttributeRune(0x21E) DominationMagic +3, then Upgrade dword id 0x177 AppliesToSuperiorMesmerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MESMER_RUNES_SUPERIOR_FAST_CASTING			= '0300E8217701'	;[v11 audit: AttributeRune(0x21E) FastCasting +3, then Upgrade dword id 0x177 AppliesToSuperiorMesmerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MESMER_RUNES_SUPERIOR_ILLUSION_MAGIC		= '0301E8217701'	;[v11 audit: AttributeRune(0x21E) IllusionMagic +3, then Upgrade dword id 0x177 AppliesToSuperiorMesmerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_MESMER_RUNES_SUPERIOR_INSPIRATION_MAGIC	= '0303E8217701'	;[v11 audit: AttributeRune(0x21E) InspirationMagic +3, then Upgrade dword id 0x177 AppliesToSuperiorMesmerRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ELEMENTALIST_INSIGNIAS_HYDROMANCER			= 'F2010824'	;[v11 audit: Upgrade(0x240) id 0x1F2 = Py4GW ItemUpgradeId.Hydromancer (insignia)]
Global Const $STRUCT_ELEMENTALIST_INSIGNIAS_GEOMANCER			= 'F3010824'	;[v11 audit: Upgrade(0x240) id 0x1F3 = Py4GW ItemUpgradeId.Geomancer (insignia)]
Global Const $STRUCT_ELEMENTALIST_INSIGNIAS_PYROMANCER			= 'F4010824'	;[v11 audit: Upgrade(0x240) id 0x1F4 = Py4GW ItemUpgradeId.Pyromancer (insignia)]
Global Const $STRUCT_ELEMENTALIST_INSIGNIAS_AEROMANCER			= 'F5010824'	;[v11 audit: Upgrade(0x240) id 0x1F5 = Py4GW ItemUpgradeId.Aeromancer (insignia)]
Global Const $STRUCT_ELEMENTALIST_INSIGNIAS_PRISMATIC			= 'F1010824'	;[v11 audit: Upgrade(0x240) id 0x1F1 = Py4GW ItemUpgradeId.Prismatic (insignia)]
Global Const $STRUCT_ELEMENTALIST_RUNES_MINOR_AIR_MAGIC			= '0108E821'	;[v11 audit: AttributeRune(0x21E) AirMagic +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_ELEMENTALIST_RUNES_MINOR_EARTH_MAGIC		= '0109E821'	;[v11 audit: AttributeRune(0x21E) EarthMagic +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_ELEMENTALIST_RUNES_MINOR_ENERGY_STORAGE	= '010CE821'	;[v11 audit: AttributeRune(0x21E) EnergyStorage +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_ELEMENTALIST_RUNES_MINOR_WATER_MAGIC		= '010BE821'	;[v11 audit: AttributeRune(0x21E) WaterMagic +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_ELEMENTALIST_RUNES_MINOR_FIRE_MAGIC		= '010AE821'	;[v11 audit: AttributeRune(0x21E) FireMagic +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_ELEMENTALIST_RUNES_MAJOR_AIR_MAGIC			= '0208E8216F01'	;[v11 audit: AttributeRune(0x21E) AirMagic +2, then Upgrade dword id 0x16F AppliesToMajorElementalistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ELEMENTALIST_RUNES_MAJOR_EARTH_MAGIC		= '0209E8216F01'	;[v11 audit: AttributeRune(0x21E) EarthMagic +2, then Upgrade dword id 0x16F AppliesToMajorElementalistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ELEMENTALIST_RUNES_MAJOR_ENERGY_STORAGE	= '020CE8216F01'	;[v11 audit: AttributeRune(0x21E) EnergyStorage +2, then Upgrade dword id 0x16F AppliesToMajorElementalistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ELEMENTALIST_RUNES_MAJOR_FIRE_MAGIC		= '020AE8216F01'	;[v11 audit: AttributeRune(0x21E) FireMagic +2, then Upgrade dword id 0x16F AppliesToMajorElementalistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ELEMENTALIST_RUNES_MAJOR_WATER_MAGIC		= '020BE8216F01'	;[v11 audit: AttributeRune(0x21E) WaterMagic +2, then Upgrade dword id 0x16F AppliesToMajorElementalistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ELEMENTALIST_RUNES_SUPERIOR_AIR_MAGIC		= '0308E8217B01'	;[v11 audit: AttributeRune(0x21E) AirMagic +3, then Upgrade dword id 0x17B AppliesToSuperiorElementalistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ELEMENTALIST_RUNES_SUPERIOR_EARTH_MAGIC	= '0309E8217B01'	;[v11 audit: AttributeRune(0x21E) EarthMagic +3, then Upgrade dword id 0x17B AppliesToSuperiorElementalistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ELEMENTALIST_RUNES_SUPERIOR_ENERGY_STORAGE	= '030CE8217B01'	;[v11 audit: AttributeRune(0x21E) EnergyStorage +3, then Upgrade dword id 0x17B AppliesToSuperiorElementalistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ELEMENTALIST_RUNES_SUPERIOR_FIRE_MAGIC		= '030AE8217B01'	;[v11 audit: AttributeRune(0x21E) FireMagic +3, then Upgrade dword id 0x17B AppliesToSuperiorElementalistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ELEMENTALIST_RUNES_SUPERIOR_WATER_MAGIC	= '030BE8217B01'	;[v11 audit: AttributeRune(0x21E) WaterMagic +3, then Upgrade dword id 0x17B AppliesToSuperiorElementalistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ASSASSIN_INSIGNIAS_VANGUARDS				= 'DE010824'	;[v11 audit: Upgrade(0x240) id 0x1DE = Py4GW ItemUpgradeId.Vanguards (insignia)]
Global Const $STRUCT_ASSASSIN_INSIGNIAS_INFILTRATORS			= 'DF010824'	;[v11 audit: Upgrade(0x240) id 0x1DF = Py4GW ItemUpgradeId.Infiltrators (insignia)]
Global Const $STRUCT_ASSASSIN_INSIGNIAS_SABOTEURS				= 'E0010824'	;[v11 audit: Upgrade(0x240) id 0x1E0 = Py4GW ItemUpgradeId.Saboteurs (insignia)]
Global Const $STRUCT_ASSASSIN_INSIGNIAS_NIGHTSTALKERS			= 'E1010824'	;[v11 audit: Upgrade(0x240) id 0x1E1 = Py4GW ItemUpgradeId.Nightstalkers (insignia)]
Global Const $STRUCT_ASSASSIN_RUNES_MINOR_CRITICAL_STRIKES		= '0123E821'	;[v11 audit: AttributeRune(0x21E) CriticalStrikes +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_ASSASSIN_RUNES_MINOR_DAGGER_MASTERY		= '011DE821'	;[v11 audit: AttributeRune(0x21E) DaggerMastery +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_ASSASSIN_RUNES_MINOR_DEADLY_ARTS			= '011EE821'	;[v11 audit: AttributeRune(0x21E) DeadlyArts +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_ASSASSIN_RUNES_MINOR_SHADOW_ARTS			= '011FE821'	;[v11 audit: AttributeRune(0x21E) ShadowArts +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_ASSASSIN_RUNES_MAJOR_CRITICAL_STRIKES		= '0223E8217902'	;[v11 audit: AttributeRune(0x21E) CriticalStrikes +2, then Upgrade dword id 0x279 AppliesToMajorAssassinRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ASSASSIN_RUNES_MAJOR_DAGGER_MASTERY		= '021DE8217902'	;[v11 audit: AttributeRune(0x21E) DaggerMastery +2, then Upgrade dword id 0x279 AppliesToMajorAssassinRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ASSASSIN_RUNES_MAJOR_DEADLY_ARTS			= '021EE8217902'	;[v11 audit: AttributeRune(0x21E) DeadlyArts +2, then Upgrade dword id 0x279 AppliesToMajorAssassinRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ASSASSIN_RUNES_MAJOR_SHADOW_ARTS			= '021FE8217902'	;[v11 audit: AttributeRune(0x21E) ShadowArts +2, then Upgrade dword id 0x279 AppliesToMajorAssassinRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ASSASSIN_RUNES_SUPERIOR_CRITICAL_STRIKES	= '0323E8217B02'	;[v11 audit: AttributeRune(0x21E) CriticalStrikes +3, then Upgrade dword id 0x27B AppliesToSuperiorAssassinRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ASSASSIN_RUNES_SUPERIOR_DAGGER_MASTERY		= '031DE8217B02'	;[v11 audit: AttributeRune(0x21E) DaggerMastery +3, then Upgrade dword id 0x27B AppliesToSuperiorAssassinRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ASSASSIN_RUNES_SUPERIOR_DEADLY_ARTS		= '031EE8217B02'	;[v11 audit: AttributeRune(0x21E) DeadlyArts +3, then Upgrade dword id 0x27B AppliesToSuperiorAssassinRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ASSASSIN_RUNES_SUPERIOR_SHADOW_ARTS		= '031FE8217B02'	;[v11 audit: AttributeRune(0x21E) ShadowArts +3, then Upgrade dword id 0x27B AppliesToSuperiorAssassinRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RITUALIST_INSIGNIAS_SHAMANS				= '04020824'	;[v11 audit: Upgrade(0x240) id 0x204 = Py4GW ItemUpgradeId.Shamans (insignia)]
Global Const $STRUCT_RITUALIST_INSIGNIAS_GHOST_FORGE			= '05020824'	;[v11 audit: Upgrade(0x240) id 0x205 = Py4GW ItemUpgradeId.GhostForge (insignia)]
Global Const $STRUCT_RITUALIST_INSIGNIAS_MYSTICS				= '06020824'	;[v11 audit: Upgrade(0x240) id 0x206 = Py4GW ItemUpgradeId.Mystics (insignia)]
Global Const $STRUCT_RITUALIST_RUNES_MINOR_CHANNELING_MAGIC		= '0122E821'	;[v11 audit: AttributeRune(0x21E) ChannelingMagic +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_RITUALIST_RUNES_MINOR_COMMUNING			= '0120E821'	;[v11 audit: AttributeRune(0x21E) Communing +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_RITUALIST_RUNES_MINOR_RESTORATION_MAGIC	= '0121E821'	;[v11 audit: AttributeRune(0x21E) RestorationMagic +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_RITUALIST_RUNES_MINOR_SPAWNING_POWER		= '0124E821'	;[v11 audit: AttributeRune(0x21E) SpawningPower +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_RITUALIST_RUNES_MAJOR_CHANNELING_MAGIC		= '0222E8217F02'	;[v11 audit: AttributeRune(0x21E) ChannelingMagic +2, then Upgrade dword id 0x27F AppliesToMajorRitualistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RITUALIST_RUNES_MAJOR_COMMUNING			= '0220E8217F02'	;[v11 audit: AttributeRune(0x21E) Communing +2, then Upgrade dword id 0x27F AppliesToMajorRitualistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RITUALIST_RUNES_MAJOR_RESTORATION_MAGIC	= '0221E8217F02'	;[v11 audit: AttributeRune(0x21E) RestorationMagic +2, then Upgrade dword id 0x27F AppliesToMajorRitualistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RITUALIST_RUNES_MAJOR_SPAWNING_POWER		= '0224E8217F02'	;[v11 audit: AttributeRune(0x21E) SpawningPower +2, then Upgrade dword id 0x27F AppliesToMajorRitualistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RITUALIST_RUNES_SUPERIOR_CHANNELING_MAGIC	= '0322E8218102'	;[v11 audit: AttributeRune(0x21E) ChannelingMagic +3, then Upgrade dword id 0x281 AppliesToSuperiorRitualistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RITUALIST_RUNES_SUPERIOR_COMMUNING			= '0320E8218102'	;[v11 audit: AttributeRune(0x21E) Communing +3, then Upgrade dword id 0x281 AppliesToSuperiorRitualistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RITUALIST_RUNES_SUPERIOR_RESTORATION_MAGIC	= '0321E8218102'	;[v11 audit: AttributeRune(0x21E) RestorationMagic +3, then Upgrade dword id 0x281 AppliesToSuperiorRitualistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_RITUALIST_RUNES_SUPERIOR_SPAWNING_POWER	= '0324E8218102'	;[v11 audit: AttributeRune(0x21E) SpawningPower +3, then Upgrade dword id 0x281 AppliesToSuperiorRitualistRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_DERVISH_INSIGNIAS_WINDWALKER				= '02020824'	;[v11 audit: Upgrade(0x240) id 0x202 = Py4GW ItemUpgradeId.Windwalker (insignia)]
Global Const $STRUCT_DERVISH_INSIGNIAS_FORSAKEN					= '03020824'	;[v11 audit: Upgrade(0x240) id 0x203 = Py4GW ItemUpgradeId.Forsaken (insignia)]
Global Const $STRUCT_DERVISH_RUNES_MINOR_EARTH_PRAYERS			= '012BE821'	;[v11 audit: AttributeRune(0x21E) EarthPrayers +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_DERVISH_RUNES_MINOR_MYSTICISM				= '012CE821'	;[v11 audit: AttributeRune(0x21E) Mysticism +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_DERVISH_RUNES_MINOR_SCYTHE_MASTERY			= '0129E821'	;[v11 audit: AttributeRune(0x21E) ScytheMastery +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_DERVISH_RUNES_MINOR_WIND_PRAYERS			= '012AE821'	;[v11 audit: AttributeRune(0x21E) WindPrayers +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_DERVISH_RUNES_MAJOR_EARTH_PRAYERS			= '022BE8210703'	;[v11 audit: AttributeRune(0x21E) EarthPrayers +2, then Upgrade dword id 0x307 AppliesToMajorDervishRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_DERVISH_RUNES_MAJOR_MYSTICISM				= '022CE8210703'	;[v11 audit: AttributeRune(0x21E) Mysticism +2, then Upgrade dword id 0x307 AppliesToMajorDervishRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_DERVISH_RUNES_MAJOR_SCYTHE_MASTERY			= '0229E8210703'	;[v11 audit: AttributeRune(0x21E) ScytheMastery +2, then Upgrade dword id 0x307 AppliesToMajorDervishRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_DERVISH_RUNES_MAJOR_WIND_PRAYERS			= '022AE8210703'	;[v11 audit: AttributeRune(0x21E) WindPrayers +2, then Upgrade dword id 0x307 AppliesToMajorDervishRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_DERVISH_RUNES_SUPERIOR_EARTH_PRAYERS		= '032BE8210903'	;[v11 audit: AttributeRune(0x21E) EarthPrayers +3, then Upgrade dword id 0x309 AppliesToSuperiorDervishRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_DERVISH_RUNES_SUPERIOR_MYSTICISM			= '032CE8210903'	;[v11 audit: AttributeRune(0x21E) Mysticism +3, then Upgrade dword id 0x309 AppliesToSuperiorDervishRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_DERVISH_RUNES_SUPERIOR_SCYTHE_MASTERY		= '0329E8210903'	;[v11 audit: AttributeRune(0x21E) ScytheMastery +3, then Upgrade dword id 0x309 AppliesToSuperiorDervishRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_DERVISH_RUNES_SUPERIOR_WIND_PRAYERS		= '032AE8210903'	;[v11 audit: AttributeRune(0x21E) WindPrayers +3, then Upgrade dword id 0x309 AppliesToSuperiorDervishRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_PARAGON_INSIGNIAS_CENTURIONS				= '07020824'	;[v11 audit: Upgrade(0x240) id 0x207 = Py4GW ItemUpgradeId.Centurions (insignia)]
Global Const $STRUCT_PARAGON_RUNES_MINOR_COMMAND				= '0126E821'	;[v11 audit: AttributeRune(0x21E) Command +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_PARAGON_RUNES_MINOR_LEADERSHIP				= '0128E821'	;[v11 audit: AttributeRune(0x21E) Leadership +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_PARAGON_RUNES_MINOR_MOTIVATION				= '0127E821'	;[v11 audit: AttributeRune(0x21E) Motivation +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_PARAGON_RUNES_MINOR_SPEAR_MASTERY			= '0125E821'	;[v11 audit: AttributeRune(0x21E) SpearMastery +1 (minor rune) - attribute id per GWCA Constants::Attribute]
Global Const $STRUCT_PARAGON_RUNES_MAJOR_COMMAND				= '0226E8210D03'	;[v11 audit: AttributeRune(0x21E) Command +2, then Upgrade dword id 0x30D AppliesToMajorParagonRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_PARAGON_RUNES_MAJOR_LEADERSHIP				= '0228E8210D03'	;[v11 audit: AttributeRune(0x21E) Leadership +2, then Upgrade dword id 0x30D AppliesToMajorParagonRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_PARAGON_RUNES_MAJOR_MOTIVATION				= '0227E8210D03'	;[v11 audit: AttributeRune(0x21E) Motivation +2, then Upgrade dword id 0x30D AppliesToMajorParagonRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_PARAGON_RUNES_MAJOR_SPEAR_MASTERY			= '0225E8210D03'	;[v11 audit: AttributeRune(0x21E) SpearMastery +2, then Upgrade dword id 0x30D AppliesToMajorParagonRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_PARAGON_RUNES_SUPERIOR_COMMAND				= '0326E8210F03'	;[v11 audit: AttributeRune(0x21E) Command +3, then Upgrade dword id 0x30F AppliesToSuperiorParagonRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_PARAGON_RUNES_SUPERIOR_LEADERSHIP			= '0328E8210F03'	;[v11 audit: AttributeRune(0x21E) Leadership +3, then Upgrade dword id 0x30F AppliesToSuperiorParagonRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_PARAGON_RUNES_SUPERIOR_MOTIVATION			= '0327E8210F03'	;[v11 audit: AttributeRune(0x21E) Motivation +3, then Upgrade dword id 0x30F AppliesToSuperiorParagonRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_PARAGON_RUNES_SUPERIOR_SPEAR_MASTERY		= '0325E8210F03'	;[v11 audit: AttributeRune(0x21E) SpearMastery +3, then Upgrade dword id 0x30F AppliesToSuperiorParagonRune - attribute id per GWCA Constants::Attribute, upgrade id per Py4GW ItemUpgradeId]
Global Const $STRUCT_ALL_INSIGNIAS_SURVIVOR						= 'E6010824'	;[v11 audit: Upgrade(0x240) id 0x1E6 = Py4GW ItemUpgradeId.Survivor (insignia)]
Global Const $STRUCT_ALL_INSIGNIAS_RADIANT						= 'E5010824'	;[v11 audit: Upgrade(0x240) id 0x1E5 = Py4GW ItemUpgradeId.Radiant (insignia)]
Global Const $STRUCT_ALL_INSIGNIAS_STALWART						= 'E7010824'	;[v11 audit: Upgrade(0x240) id 0x1E7 = Py4GW ItemUpgradeId.Stalwart (insignia)]
Global Const $STRUCT_ALL_INSIGNIAS_BRAWLERS						= 'E8010824'	;[v11 audit: Upgrade(0x240) id 0x1E8 = Py4GW ItemUpgradeId.Brawlers (insignia)]
Global Const $STRUCT_ALL_INSIGNIAS_BLESSED						= 'E9010824'	;[v11 audit: Upgrade(0x240) id 0x1E9 = Py4GW ItemUpgradeId.Blessed (insignia)]
Global Const $STRUCT_ALL_INSIGNIAS_HERALDS						= 'EA010824'	;[v11 audit: Upgrade(0x240) id 0x1EA = Py4GW ItemUpgradeId.Heralds (insignia)]
Global Const $STRUCT_ALL_INSIGNIAS_SENTRYS						= 'EB010824'	;[v11 audit: Upgrade(0x240) id 0x1EB = Py4GW ItemUpgradeId.Sentrys (insignia)]
Global Const $STRUCT_ALL_RUNES_MINOR_VIGOR						= 'C202E827'	;[v11 audit: unknown id(0x27E) arg1=2 arg2=194]
Global Const $STRUCT_ALL_RUNES_VITAE							= '000A4823'	;[v11 audit: HealthPlus(0x234) arg1=10 arg2=0]
Global Const $STRUCT_ALL_RUNES_ATTUNEMENT						= '0200D822'	;[v11 audit: EnergyPlus(0x22D) arg1=0 arg2=2]
Global Const $STRUCT_ALL_RUNES_MAJOR_VIGOR						= 'C202E927'	;[v11 audit: unknown id(0x27E) arg1=2 arg2=194] [v19: +41 Health effect dword; in-game dumps carry it as 00010824 01023025 C202E927 = Upgrade id 0x100 (Py4GW ItemUpgradeId.OfMajorVigor) + tooltip + effect; Minor = ...E827 (0xFF), Superior = ...EA27 (0x101)]
Global Const $STRUCT_ALL_RUNES_RECOVERY							= '07047827'	;[v11 audit: ReduceConditionTupleDuration(0x277) arg1=4 arg2=7]
Global Const $STRUCT_ALL_RUNES_RESTORATION						= '00037827'	;[v11 audit: ReduceConditionTupleDuration(0x277) arg1=3 arg2=0]
Global Const $STRUCT_ALL_RUNES_CLARITY							= '01087827'	;[v11 audit: ReduceConditionTupleDuration(0x277) arg1=8 arg2=1]
Global Const $STRUCT_ALL_RUNES_PURITY							= '05067827'	;[v11 audit: ReduceConditionTupleDuration(0x277) arg1=6 arg2=5]
Global Const $STRUCT_ALL_RUNES_SUPERIOR_VIGOR					= 'C202EA27'	;[v11 audit: unknown id(0x27E) arg1=2 arg2=194]
#EndRegion Runes


#Region Default structure creation
;~ Creates a map to use to find whether an OS (Old School) weapon ITSELF has perfect mods or not
Func DefaultCreatePerfectModsByOSWeaponTypeMap()
	; For martial weapons, only one of those mods is enough to say the weapon is perfect
	; But for zealous strength and vampiric strength, we need to check that it is not the zealous/vampiric mod
	Local $martialWeapons = [ _
		$STRUCT_INSCRIPTION_STRENGTH_AND_HONOR, _
		$STRUCT_INSCRIPTION_GUIDED_BY_FATE, _
		$STRUCT_INSCRIPTION_DANCE_WITH_DEATH, _
		$STRUCT_INSCRIPTION_I_HAVE_THE_POWER, _
		$STRUCT_INHERENT_ZEALOUS_STRENGTH, _
		$STRUCT_INHERENT_VAMPIRIC_STRENGTH _
	]

	; Those are common to caster weapons and focii
	Local $casterAndFocus = [ _
		$STRUCT_INHERENT_FIRE_MAGIC_HCT, _
		$STRUCT_INHERENT_FIRE_MAGIC_HSR, _
		$STRUCT_INHERENT_WATER_MAGIC_HCT, _
		$STRUCT_INHERENT_WATER_MAGIC_HSR, _
		$STRUCT_INHERENT_AIR_MAGIC_HCT, _
		$STRUCT_INHERENT_AIR_MAGIC_HSR, _
		$STRUCT_INHERENT_EARTH_MAGIC_HCT, _
		$STRUCT_INHERENT_EARTH_MAGIC_HSR, _
		$STRUCT_INHERENT_ENERGY_STORAGE_HCT, _
		$STRUCT_INHERENT_ENERGY_STORAGE_HSR, _
		$STRUCT_INHERENT_SMITING_PRAYERS_HCT, _
		$STRUCT_INHERENT_SMITING_PRAYERS_HSR, _
		$STRUCT_INHERENT_DIVINE_FAVOR_HCT, _
		$STRUCT_INHERENT_DIVINE_FAVOR_HSR, _
		$STRUCT_INHERENT_HEALING_PRAYERS_HCT, _
		$STRUCT_INHERENT_HEALING_PRAYERS_HSR, _
		$STRUCT_INHERENT_PROTECTION_PRAYERS_HCT, _
		$STRUCT_INHERENT_PROTECTION_PRAYERS_HSR, _
		$STRUCT_INHERENT_CHANNELING_MAGIC_HCT, _
		$STRUCT_INHERENT_CHANNELING_MAGIC_HSR, _
		$STRUCT_INHERENT_RESTORATION_MAGIC_HCT, _
		$STRUCT_INHERENT_RESTORATION_MAGIC_HSR, _
		$STRUCT_INHERENT_COMMUNING_HCT, _
		$STRUCT_INHERENT_COMMUNING_HSR, _
		$STRUCT_INHERENT_SPAWNING_POWER_HCT, _
		$STRUCT_INHERENT_SPAWNING_POWER_HSR, _
		$STRUCT_INHERENT_ILLUSION_MAGIC_HCT, _
		$STRUCT_INHERENT_ILLUSION_MAGIC_HSR, _
		$STRUCT_INHERENT_DOMINATION_MAGIC_HCT, _
		$STRUCT_INHERENT_DOMINATION_MAGIC_HSR, _
		$STRUCT_INHERENT_INSPIRATION_MAGIC_HCT, _
		$STRUCT_INHERENT_INSPIRATION_MAGIC_HSR, _
		$STRUCT_INHERENT_DEATH_MAGIC_HCT, _
		$STRUCT_INHERENT_DEATH_MAGIC_HSR, _
		$STRUCT_INHERENT_BLOOD_MAGIC_HCT, _
		$STRUCT_INHERENT_BLOOD_MAGIC_HSR, _
		$STRUCT_INHERENT_SOUL_REAPING_HCT, _
		$STRUCT_INHERENT_SOUL_REAPING_HSR, _
		$STRUCT_INHERENT_CURSES_HCT, _
		$STRUCT_INHERENT_CURSES_HSR _
	]

	; Those are common to shield and focus - They might be less interesting on one or the other so maybe it will need to be splitted further
	Local $shieldAndFocus	= [ _
		$STRUCT_INSCRIPTION_NOT_THE_FACE, _
		$STRUCT_INSCRIPTION_LEAF_ON_THE_WIND, _
		$STRUCT_INSCRIPTION_LIKE_A_ROLLING_STONE, _
		$STRUCT_INSCRIPTION_SLEEP_NOW_IN_THE_FIRE, _
		$STRUCT_INSCRIPTION_RIDERS_ON_THE_STORM, _
		$STRUCT_INSCRIPTION_THROUGH_THICK_AND_THIN, _
		$STRUCT_INSCRIPTION_THE_RIDDLE_OF_STEEL, _
		$STRUCT_INSCRIPTION_SHELTERED_BY_FAITH, _
		$STRUCT_INSCRIPTION_RUN_FOR_YOUR_LIFE, _
		$STRUCT_INSCRIPTION_LUCK_OF_THE_DRAW, _
		$STRUCT_INHERENT_OF_ILLUSION_MAGIC, _
		$STRUCT_INHERENT_OF_DOMINATION_MAGIC, _
		$STRUCT_INHERENT_OF_INSPIRATION, _
		$STRUCT_INHERENT_OF_BLOOD_MAGIC, _
		$STRUCT_INHERENT_OF_DEATH_MAGIC, _
		$STRUCT_INHERENT_OF_SOUL_REAPING, _
		$STRUCT_INHERENT_OF_CURSE_MAGIC, _
		$STRUCT_INHERENT_OF_AIR_MAGIC, _
		$STRUCT_INHERENT_OF_EARTH_MAGIC, _
		$STRUCT_INHERENT_OF_FIRE_MAGIC, _
		$STRUCT_INHERENT_OF_WATER_MAGIC, _
		$STRUCT_INHERENT_OF_HEALING_PRAYERS, _
		$STRUCT_INHERENT_OF_SMITING_PRAYERS, _
		$STRUCT_INHERENT_OF_PROTECTION_PRAYERS, _
		$STRUCT_INHERENT_OF_DIVINE_FAVOR, _
		$STRUCT_INHERENT_OF_COMMUNING_MAGIC, _
		$STRUCT_INHERENT_OF_RESTORATION_MAGIC, _
		$STRUCT_INHERENT_OF_CHANNELING_MAGIC, _
		$STRUCT_INHERENT_OF_SPAWNING_MAGIC, _
		$STRUCT_INHERENT_ARMOR_VS_UNDEAD, _
		$STRUCT_INHERENT_ARMOR_VS_CHARR, _
		$STRUCT_INHERENT_ARMOR_VS_TROLLS, _
		$STRUCT_INHERENT_ARMOR_VS_PLANTS, _
		$STRUCT_INHERENT_ARMOR_VS_SKELETONS, _
		$STRUCT_INHERENT_ARMOR_VS_GIANTS, _
		$STRUCT_INHERENT_ARMOR_VS_DWARVES, _
		$STRUCT_INHERENT_ARMOR_VS_TENGU, _
		$STRUCT_INHERENT_ARMOR_VS_DEMONS, _
		$STRUCT_INHERENT_ARMOR_VS_DRAGONS, _
		$STRUCT_INHERENT_ARMOR_VS_OGRES, _
		$STRUCT_MOD_OF_DEVOTION, _
		$STRUCT_MOD_OF_ENDURANCE, _
		$STRUCT_MOD_OF_FORTITUDE _
	]

	Local $casterWeapons = [ _
		$STRUCT_INSCRIPTION_HALE_AND_HEARTY, _
		$STRUCT_INSCRIPTION_HAVE_FAITH, _
		$STRUCT_INSCRIPTION_SEIZE_THE_DAY, _
		$STRUCT_INSCRIPTION_APTITUDE_NOT_ATTITUDE _
	]
	_ArrayAdd($casterWeapons, $casterAndFocus)

	Local $focus = [ _
		$STRUCT_INSCRIPTION_FORGET_ME_NOT, _
		$STRUCT_INSCRIPTION_HAIL_TO_THE_KING, _
		$STRUCT_INSCRIPTION_FAITH_IS_MY_SHIELD, _
		$STRUCT_INSCRIPTION_LIFE_IS_PAIN, _
		$STRUCT_INSCRIPTION_LIVE_FOR_TODAY _
	]
	_ArrayAdd($focus, $casterAndFocus)
	_ArrayAdd($focus, $shieldAndFocus)

	Local $shield = [ _
		$STRUCT_INSCRIPTION_I_CAN_SEE_CLEARLY_NOW, _
		$STRUCT_INSCRIPTION_SWIFT_AS_THE_WIND, _
		$STRUCT_INSCRIPTION_ONLY_THE_STRONG_SURVIVE _
	]
	_ArrayAdd($shield, $shieldAndFocus)

	; Empty because there are no OS (Old School) scythes and spears
	Local $scytheAndSpear			= []

	; Redefining types here remove dependency on GWA2_ID - and we only execute this function once
	Local Const $IDTypeAxe					= 2
	Local Const $IDTypeBow					= 5
	Local Const $IDTypeOffhand				= 12
	Local Const $IDTypeHammer				= 15
	Local Const $IDTypeWand					= 22
	Local Const $IDTypeShield				= 24
	Local Const $IDTypeStaff				= 26
	Local Const $IDTypeSword				= 27
	Local Const $IDTypeDagger				= 32
	Local Const $IDTypeScythe				= 35
	Local Const $IDTypeSpear				= 36
	Local Const $allWeaponsArray			= [$IDTypeShield, $IDTypeOffhand, $IDTypeWand, $IDTypeStaff, $IDTypeBow, $IDTypeAxe, $IDTypeHammer, $IDTypeSword, $IDTypeDagger, $IDTypeScythe, $IDTypeSpear]
	Local Const $allWeaponsModsArray			= [$shield, $focus, $casterWeapons, $casterWeapons, $martialWeapons, $martialWeapons, $martialWeapons, _
													$martialWeapons, $martialWeapons, $scytheAndSpear, $scytheAndSpear]
	Local $weaponModsByType[]
	$weaponModsByType = MapFromArrays($allWeaponsArray, $allWeaponsModsArray)
	Return $weaponModsByType
EndFunc
#EndRegion Default structure creation


#Region Items tests
;~ Determines whether the provided OS (Old School) item has perfect mods
Func HasPerfectMods($item)
	Local $itemType	= DllStructGetData($item, 'type')
	Local $modstruct = GetModStruct($item)
	Local $typeMods	= $perfect_mods_by_weapon_type[$itemType]
	Switch $itemType
		; For martial weapons, only 1 inherent mod and the weapon is perfect
		Case $ID_TYPE_AXE, $ID_TYPE_BOW, $ID_TYPE_HAMMER, $ID_TYPE_SWORD, $ID_TYPE_DAGGER
			For $struct In $typeMods
				If StringInStr($modstruct, $struct) > 0 Then
					; If the mod found is vampiric or zealous strength, we need to check we are not mixing it with vampiric or zealous mod
					If $struct	== $STRUCT_INHERENT_ZEALOUS_STRENGTH Then
						If StringInStr($modstruct, $STRUCT_MOD_ZEALOUS) Then ContinueLoop
					EndIf
					If $struct	== $STRUCT_INHERENT_VAMPIRIC_STRENGTH Then
						If StringInStr($modstruct, $STRUCT_MOD_VAMPIRIC_3) Or StringInStr($modstruct, $STRUCT_MOD_VAMPIRIC_5) Then ContinueLoop
					EndIf
					Return True
				EndIf
			Next
			Return False
		; For staff, only 1 inherent mod as well, but no risk of zealous/vampiric
		Case $ID_TYPE_STAFF
			For $struct In $typeMods
				If StringInStr($modstruct, $struct) > 0 Then Return True
			Next
			Return False
		; For wand, offhand and shield, there are 2 inherent mods, we need to check twice
		Case $ID_TYPE_WAND, $ID_TYPE_OFFHAND, $ID_TYPE_SHIELD
			Local $count	= 0
			For $struct In $typeMods
				If StringInStr($modstruct, $struct) > 0 Then $count += 1
			Next
			Return $count > 1
		; For scythe and spear, if you are checking this, something is wrong, there are no OS scythe or spear. Congratulations.
		Case $ID_TYPE_SCYTHE, $ID_TYPE_SPEAR
			Return True
	EndSwitch
	Return False
EndFunc
#EndRegion Items tests


#Region Structure creation from UI
;~ v29: the 'Keep components' lists (ContainsValuableUpgrades, RefreshValuableListsFromCache, CreateValuable*, KeepUpgradePresent) were removed with the Keep components tree (AMG)
; Insignias are present at index 0 of their armor salvageable item
; Runes are present at index 1 of their armor salvageable item
Global $perfect_mods_by_weapon_type						= DefaultCreatePerfectModsByOSWeaponTypeMap()


;~ Raw modstruct (Binary read from memory, or a '0x...' string) -> upper-case hex string without '0x'
Func ModStructToHex($modStruct)
	Local $hex = StringUpper(String($modStruct))
	If StringLeft($hex, 2) == '0X' Then $hex = StringTrimLeft($hex, 2)
	Return $hex
EndFunc


#EndRegion Structure creation from UI


#Region Utils
Func IsWeaponUpgradeStruct($modStruct, $upgradePosition)
	If $upgradePosition < 5 Then Return False
	If StringMid($modStruct, $upgradePosition - 4, 2) == $STRUCT_WEAPON_UPGRADE Then Return True
	Return False
EndFunc


Func IsInscriptionStruct($modStruct, $upgradePosition)
	If $upgradePosition < 5 Then Return False
	If StringMid($modStruct, $upgradePosition - 4, 2) == $STRUCT_INSCRIPTION Then Return True
	Return False
EndFunc


;~ Too lazy to implement this today
Func HasAlmostPerfectMods($item)
	Return HasPerfectMods($item)
EndFunc


;~ Too lazy to implement this today
Func HasOkayMods($item)
	Return HasPerfectMods($item)
EndFunc


Func ModNameCleanupHelper($modName)
	; cleanup of all parentheses and contents in them
	$modName = StringRegExpReplace($modName, '\s*\(.*?\)', '')
	$modName = StringReplace($modName, ' ', '_')
	$modName = StringUpper($modName)
	Return $modName
EndFunc
#EndRegion Utils


#Region Upgrade leaf definitions (v5 - 'Extract upgrades only' and Store items > Components)
;~ Resolves ONE treeview leaf path (relative to its root, e.g. 'Armor upgrades.All.Runes.Superior Vigor',
;~ 'Mods.Sword.Suffix - Pommel.Of Fortitude (Health +30)', 'Inscriptions.Offhand.Focus.Forget me not (...)')
;~ into an upgrade definition, using the name -> STRUCT_* constant rules of the former 'Keep components' tree (removed in v29).
;~ Returns a map: path, structName, struct, kind ('insignia'|'rune'|'prefix'|'suffix'|'inscription'), armor (bool), types (array of item types)
;~ or Null when the leaf cannot be mapped.
Func ResolveUpgradeLeafDefinition($relativePath)
	Local $parts = StringSplit($relativePath, '.')
	If $parts[0] < 2 Then Return Null
	Local $definition[]
	$definition['path'] = $relativePath
	$definition['armor'] = False
	Local $emptyTypes[0]
	$definition['types'] = $emptyTypes
	Local $structName = ''
	Switch $parts[1]
		Case 'Armor upgrades'
			If $parts[0] <> 4 Then Return Null
			Switch $parts[3]
				Case 'Insignias'
					$definition['kind'] = 'insignia'
				Case 'Runes'
					$definition['kind'] = 'rune'
				Case Else
					Return Null
			EndSwitch
			$structName = StringUpper('STRUCT_' & StringReplace($parts[2] & '_' & $parts[3] & '_' & $parts[4], ' ', '_'))
			$definition['armor'] = True
		Case 'Mods'
			If $parts[0] <> 4 Then Return Null
			If StringLeft($parts[3], 6) == 'Prefix' Then
				$definition['kind'] = 'prefix'
			ElseIf StringLeft($parts[3], 6) == 'Suffix' Then
				$definition['kind'] = 'suffix'
			Else
				Return Null
			EndIf
			Local $weaponType = GetWeaponTypeFromName($parts[2])
			If $weaponType == -1 Then Return Null
			Local $modTypes[] = [$weaponType]
			$definition['types'] = $modTypes
			$structName = 'STRUCT_MOD_' & ModNameCleanupHelper($parts[4])
		Case 'Inscriptions'
			$definition['kind'] = 'inscription'
			Local $group = ''
			For $i = 2 To $parts[0] - 1
				$group &= ($group == '' ? '' : '.') & $parts[$i]
			Next
			Local $inscriptionTypes = GetInscriptionGroupItemTypes($group)
			If UBound($inscriptionTypes) == 0 Then Return Null
			$definition['types'] = $inscriptionTypes
			$structName = 'STRUCT_INSCRIPTION_' & ModNameCleanupHelper($parts[$parts[0]])
		Case Else
			Return Null
	EndSwitch
	$definition['structName'] = $structName
	; v12: extra max-roll effects for upgrades whose STRUCT_* constant only pins the fixed part (slaying %, To the Pain...)
	$definition['requirements'] = GetPerfectRollRequirements($structName)
	Local $struct = SafeEval($structName, False)
	If $struct == Null Or $struct == '' Then Return Null
	$definition['struct'] = StringUpper($struct)
	Return $definition
EndFunc


;~ Weapon type ID from the weapon name used in the treeview (Axe, Bow, Focus, Hammer, Wand, Shield, Staff, Sword, Dagger, Scythe, Spear); -1 if unknown
Func GetWeaponTypeFromName($weaponName)
	For $i = 0 To UBound($WEAPON_NAMES_ARRAY) - 1
		If $WEAPON_NAMES_ARRAY[$i] == $weaponName Then Return $WEAPON_TYPES_ARRAY[$i]
	Next
	Return -1
EndFunc


;~ Item types an inscription group of the treeview applies to (same grouping as the former Keep components inscriptions, v29)
Func GetInscriptionGroupItemTypes($group)
	Local Static $martial[] = [$ID_TYPE_AXE, $ID_TYPE_BOW, $ID_TYPE_HAMMER, $ID_TYPE_SWORD, $ID_TYPE_DAGGER, $ID_TYPE_SCYTHE, $ID_TYPE_SPEAR]
	Local Static $spellcasting[] = [$ID_TYPE_WAND, $ID_TYPE_STAFF]
	Local Static $weapons[] = [$ID_TYPE_AXE, $ID_TYPE_BOW, $ID_TYPE_HAMMER, $ID_TYPE_SWORD, $ID_TYPE_DAGGER, $ID_TYPE_SCYTHE, $ID_TYPE_SPEAR, $ID_TYPE_WAND, $ID_TYPE_STAFF]
	Local Static $offhands[] = [$ID_TYPE_OFFHAND, $ID_TYPE_SHIELD]
	Local Static $focus[] = [$ID_TYPE_OFFHAND]
	Local Static $shield[] = [$ID_TYPE_SHIELD]
	Local Static $all[] = [$ID_TYPE_AXE, $ID_TYPE_BOW, $ID_TYPE_HAMMER, $ID_TYPE_SWORD, $ID_TYPE_DAGGER, $ID_TYPE_SCYTHE, $ID_TYPE_SPEAR, _
		$ID_TYPE_WAND, $ID_TYPE_STAFF, $ID_TYPE_OFFHAND, $ID_TYPE_SHIELD]
	Local $none[0]
	Switch $group
		Case ''
			Return $all
		Case 'Weapon'
			Return $weapons
		Case 'Weapon.Martial'
			Return $martial
		Case 'Weapon.Spellcasting'
			Return $spellcasting
		Case 'Offhand'
			Return $offhands
		Case 'Offhand.Focus'
			Return $focus
		Case 'Offhand.Shield'
			Return $shield
	EndSwitch
	Return $none
EndFunc


;~ Item modstruct as an upper-case hex string without '0x' ('' if none)
Func GetModStructHex($item)
	Local $raw = GetModStruct($item)
	If $raw == Null Or $raw == '' Then Return ''
	Local $hex = String($raw)
	If StringLeft($hex, 2) == '0x' Then $hex = StringTrimLeft($hex, 2)
	Return StringUpper($hex)
EndFunc


;~ True if the struct occurs dword-aligned in the hex modstruct; with a marker ('30' upgrade, '32' inscription) the struct must be
;~ one of the effect dwords of an upgrade group of that kind (see FindUpgradeGroupForStruct).
;~ v11: $wantedKind ('prefix'|'suffix'|'inscription', '' = any) rejects a group whose upgrade id is known to be of another kind
;~ (e.g. a Hale staff head and a Wrapping of Fortitude carry the same Health +30 effect dword 001E4823).
;~ v12: $requirements (see GetPerfectRollRequirements) = extra max-roll effects the same upgrade group must carry.
Func HasUpgradeStructInModStruct($hex, $struct, $marker = '', $wantedKind = '', $requirements = '')
	If $hex == '' Or $struct == '' Then Return False
	If $marker <> '' Then Return FindUpgradeGroupForStruct($hex, $struct, $marker, $wantedKind, $requirements) >= 0
	Local $position = StringInStr($hex, $struct)
	While $position > 0
		If Mod($position - 1, 8) == 0 Then Return True
		$position = StringInStr($hex, $struct, 0, 1, $position + 1)
	WEnd
	Return False
EndFunc


#Region Modstruct upgrade groups (v11 - item & mod audit)
;~ Layout of a weapon/offhand upgrade inside a modstruct (verified against a GWToolbox modstruct dump and Py4GW decoded_modifier):
;~   [0x2408 Upgrade, arg = upgrade id] [0x2530 weapon mod tooltip | 0x2532 inscription tooltip] [effect dword] ([effect dword] ...)
;~ Every dword of the bot's hex string reads 'BBAAIIII' = arg2, arg1, identifier (little-endian), e.g. 0x2408 -> '....0824'.
;~ Multi-effect upgrades (Zealous, Vampiric, Sundering, To the Pain, Seize the Day...) carry up to 3 effect dwords.
Global Const $MODSTRUCT_MAX_EFFECTS_PER_UPGRADE = 3
;~ v27: Py4GW ModifierIdentifier effect ids used by the old-school auto-keep rules
Global Const $MODSTRUCT_EFFECT_ATTRIBUTE_REQUIREMENT = 0x279	; arg1 = attribute, arg2 = required level (GWA2 GetItemReq/GetItemAttribute '9827')
Global Const $MODSTRUCT_EFFECT_ENERGY_PLUS = 0x22D				; arg2 = energy ('0500D822' = +5)
Global Const $MODSTRUCT_EFFECT_HCT_ATTRIBUTE = 0x221				; HalvesCastingTimeAttribute: arg1 = chance %, arg2 = attribute
Global Const $MODSTRUCT_EFFECT_HSR_ATTRIBUTE = 0x239				; HalvesSkillRechargeAttribute: arg1 = chance %, arg2 = attribute
Global Const $MODSTRUCT_EFFECT_HCT_GENERAL = 0x220				; HalvesCastingTimeGeneral (all spells): arg1 = chance % ('000A0822' = 10%)
Global Const $MODSTRUCT_EFFECT_HSR_GENERAL = 0x23A				; HalvesSkillRechargeGeneral (all spells): arg1 = chance % ('000AA823' = 10%)
;~ v26: Py4GW ModifierIdentifier effect ids of the slaying suffixes
Global Const $MODSTRUCT_EFFECT_BANE_SPECIES = 0x008
Global Const $MODSTRUCT_EFFECT_DAMAGE_PLUS_VS_SPECIES = 0x224


;~ Identifier of the dword starting at (1-based, dword-aligned) $position, as 4 hex chars in natural order (e.g. '2408', '2530')
Func GetModStructDwordIdentifier($hex, $position)
	Return StringMid($hex, $position + 6, 2) & StringMid($hex, $position + 4, 2)
EndFunc


;~ 16-bit argument (arg1 << 8 | arg2) of the dword starting at $position - for a 0x2408 dword this is the upgrade id
Func GetModStructDwordArg($hex, $position)
	Return Dec(StringMid($hex, $position + 2, 2) & StringMid($hex, $position, 2))
EndFunc


;~ Kind of a weapon upgrade id: 'prefix', 'suffix', 'inscription', or '' when unknown
Func GetWeaponUpgradeKindFromId($upgradeId)
	Local $info = GetWeaponUpgradeInfoFromId($upgradeId)
	If $info == '' Then Return ''
	Return StringLeft($info, StringInStr($info, '|') - 1)
EndFunc


;~ Finds an upgrade group of the given marker ('30' weapon mod, '32' inscription) holding $struct as an effect dword.
;~ Returns the group's upgrade id (> 0, read from the 0x2408 dword in front of the tooltip), 0 when the struct directly follows
;~ a marker dword without a recognisable group header (legacy rule, kept so nothing that matched before is lost), -1 if not found.
;~ - effect dwords after the first one are only accepted inside a group whose upgrade id is a known weapon upgrade of the marker's kind
;~ - $wantedKind <> '': a group whose upgrade id is known to be of another kind is skipped (the next occurrence is tried)
;~ - v12 $requirements <> '': the group must also carry every listed max-roll effect (UpgradeGroupMeetsRequirements), else it is skipped
Func FindUpgradeGroupForStruct($hex, $struct, $marker, $wantedKind = '', $requirements = '')
	If $hex == '' Or $struct == '' Then Return -1
	; v26: slaying suffixes are identified by their BaneSpecies dword, which is an item-wide modifier (see FindSlayingUpgradeGroup)
	If IsBaneSpeciesStruct($struct) Then Return FindSlayingUpgradeGroup($hex, $struct, $marker, $wantedKind, $requirements)
	Local $length = StringLen($hex)
	For $i = 1 To $length - 15 Step 8
		; tooltip/marker dword: identifier low byte = marker (same rule as IsWeaponUpgradeStruct / IsInscriptionStruct)
		If StringMid($hex, $i + 4, 2) <> $marker Then ContinueLoop
		Local $upgradeId = 0
		If $i > 8 And GetModStructDwordIdentifier($hex, $i - 8) == '2408' Then $upgradeId = GetModStructDwordArg($hex, $i - 8)
		Local $groupKind = ($upgradeId > 0) ? GetWeaponUpgradeKindFromId($upgradeId) : ''
		Local $markerKindMatches = ($marker == $STRUCT_INSCRIPTION) ? ($groupKind == 'inscription') : ($groupKind == 'prefix' Or $groupKind == 'suffix')
		Local $maxEffects = $markerKindMatches ? $MODSTRUCT_MAX_EFFECTS_PER_UPGRADE : 1
		For $j = 1 To $maxEffects
			Local $effectPosition = $i + 8 * $j
			If $effectPosition > $length - 7 Then ExitLoop
			If $j > 1 And GetModStructDwordIdentifier($hex, $effectPosition) == '2408' Then ExitLoop
			If StringMid($hex, $effectPosition, 8) <> $struct Then ContinueLoop
			If $wantedKind <> '' And $groupKind <> '' And $groupKind <> $wantedKind Then ExitLoop
			If $requirements <> '' And Not UpgradeGroupMeetsRequirements($hex, $i, $requirements) Then ExitLoop
			Return $upgradeId
		Next
	Next
	Return -1
EndFunc


;~ v26: True if $struct is a BaneSpecies (effect 0x008) dword - the STRUCT_MOD_OF_*SLAYING / DEATHBANE / PRUNING constants
Func IsBaneSpeciesStruct($struct)
	If StringLen($struct) <> 8 Or Not StringIsXDigit($struct) Then Return False
	Return GetModStructDwordEffectId($struct, 1) == $MODSTRUCT_EFFECT_BANE_SPECIES
EndFunc


;~ v26: True if an effect dword with $effectId whose arg $argIndex equals $value occurs dword-aligned anywhere in the modstruct
Func ModStructHasEffectValue($hex, $effectId, $argIndex, $value)
	For $i = 1 To StringLen($hex) - 7 Step 8
		If GetModStructDwordEffectId($hex, $i) <> $effectId Then ContinueLoop
		If GetModStructDwordArgByte($hex, $i, $argIndex) == $value Then Return True
	Next
	Return False
EndFunc


;~ v26: slaying suffix matcher ('of Charrslaying', 'of Deathbane', 'of Pruning'... = Damage +15..20% vs <species>).
;~ Py4GW (upgrade_parser.py get_species / upgrades.py OfSlayingUpgrade) builds a slaying upgrade from the DamagePlusVsSpecies (0x224,
;~ arg1 = damage %) effect of the suffix group and reads the species from the BaneSpecies (0x008, arg1 = species) modifier found
;~ ANYWHERE in the item's modifiers - the BaneSpecies dword is not one of the group's effect dwords. Before v26 the bot required the
;~ BaneSpecies dword right after the weapon-mod tooltip, so a real slaying suffix never matched Keep / Extract / hold / Store components.
;~ Match = the item carries the BaneSpecies of the wanted species (dword-aligned, anywhere) AND a weapon-mod group ('30') - a
;~ suffix (OfSlaying_* in Py4GW), or a header-less legacy group - carries DamagePlusVsSpecies (or the BaneSpecies dword itself, old layout) and
;~ meets $requirements ('224:1:20' = +20%, the max roll). Returns the group's upgrade id (0 = header-less group), -1 if not found.
Func FindSlayingUpgradeGroup($hex, $struct, $marker, $wantedKind = '', $requirements = '')
	If $marker == $STRUCT_INSCRIPTION Then Return -1
	If $wantedKind <> '' And $wantedKind <> 'suffix' Then Return -1
	Local $species = GetModStructDwordArgByte($struct, 1, 1)
	If Not ModStructHasEffectValue($hex, $MODSTRUCT_EFFECT_BANE_SPECIES, 1, $species) Then Return -1
	Local $length = StringLen($hex)
	For $i = 1 To $length - 15 Step 8
		If $marker <> '' And StringMid($hex, $i + 4, 2) <> $marker Then ContinueLoop
		If $marker == '' And StringMid($hex, $i + 4, 2) <> $STRUCT_WEAPON_UPGRADE Then ContinueLoop
		Local $upgradeId = 0
		If $i > 8 And GetModStructDwordIdentifier($hex, $i - 8) == '2408' Then $upgradeId = GetModStructDwordArg($hex, $i - 8)
		; a group whose upgrade id is known to be a prefix or an inscription is skipped (slaying is a suffix: OfSlaying_* 0x00D4-0x00D8
		; in Py4GW's table); a suffix id outside that table is still accepted (the damage-vs-species effect only exists on slaying
		; suffixes) so a gap in the id table cannot hide a real slaying suffix. An unknown/absent header = legacy single-effect rule.
		Local $groupKind = ($upgradeId > 0) ? GetWeaponUpgradeKindFromId($upgradeId) : ''
		If $groupKind <> '' And $groupKind <> 'suffix' Then ContinueLoop
		Local $maxEffects = ($groupKind == 'suffix') ? $MODSTRUCT_MAX_EFFECTS_PER_UPGRADE : 1
		Local $slayingEffect = False
		For $j = 1 To $maxEffects
			Local $effectPosition = $i + 8 * $j
			If $effectPosition > $length - 7 Then ExitLoop
			If $j > 1 And GetModStructDwordIdentifier($hex, $effectPosition) == '2408' Then ExitLoop
			Local $effectId = GetModStructDwordEffectId($hex, $effectPosition)
			If $effectId == $MODSTRUCT_EFFECT_DAMAGE_PLUS_VS_SPECIES Or $effectId == $MODSTRUCT_EFFECT_BANE_SPECIES Then
				$slayingEffect = True
				ExitLoop
			EndIf
		Next
		If Not $slayingEffect Then ContinueLoop
		If $requirements <> '' And Not UpgradeGroupMeetsRequirements($hex, $i, $requirements) Then ContinueLoop
		Return $upgradeId
	Next
	Return -1
EndFunc


;~ v27: required level of the item (AttributeRequirement 0x279, dword-aligned), -1 if none; $attribute = the required attribute
Func GetModStructRequirement($hex, ByRef $attribute)
	$attribute = -1
	For $i = 1 To StringLen($hex) - 7 Step 8
		If GetModStructDwordEffectId($hex, $i) <> $MODSTRUCT_EFFECT_ATTRIBUTE_REQUIREMENT Then ContinueLoop
		$attribute = GetModStructDwordArgByte($hex, $i, 1)
		Return GetModStructDwordArgByte($hex, $i, 2)
	Next
	Return -1
EndFunc


;~ v27: True if an effect dword with $effectId, arg1 = $arg1 and arg2 = $arg2 occurs dword-aligned anywhere in the modstruct
Func ModStructHasEffectArgs($hex, $effectId, $arg1, $arg2)
	For $i = 1 To StringLen($hex) - 7 Step 8
		If GetModStructDwordEffectId($hex, $i) <> $effectId Then ContinueLoop
		If GetModStructDwordArgByte($hex, $i, 1) == $arg1 And GetModStructDwordArgByte($hex, $i, 2) == $arg2 Then Return True
	Next
	Return False
EndFunc


;~ v27: salvageable upgrades (Py4GW names in GetWeaponUpgradeInfoFromId) that carry the effects used by the OS auto-keep rules
;~ - Energy +5: Insightful staff head (prefix), 'I have the power!' (inscription)
;~ - Halves casting time 10% (0x220): Swift staff head (prefix), of Swiftness focus core (suffix), "Don't think twice" (inscription)
;~ - Halves skill recharge 10% (0x23A): of Quickening wand wrapping (suffix), 'Serenity now' / 'Let the memory live again' (inscriptions)
Global Const $OS_KEEP_ENERGY_UPGRADES = '|Insightful_Staff|IHaveThePower|'
Global Const $OS_KEEP_HCT_GENERAL_UPGRADES = '|Swift_Staff|OfSwiftness_Focus|DontThinkTwice|'
Global Const $OS_KEEP_HSR_GENERAL_UPGRADES = '|OfQuickening_Wand|SerenityNow|LetTheMemoryLiveAgain|'


;~ v27: True if the item has an INHERENT Energy +5 (EnergyPlus 0x22D, arg1 0, arg2 5): not an effect of a salvageable upgrade group
;~ carrying Energy +5 (Insightful staff head, 'I have the power!') or of a header-less group. Py4GW ItemModifierParser: inherent =
;~ the modifiers no prefix / suffix / inscription took.
Func HasInherentEnergyPlusFive($hex)
	Return HasInherentEffect($hex, $MODSTRUCT_EFFECT_ENERGY_PLUS, 0, 5, $OS_KEEP_ENERGY_UPGRADES)
EndFunc


;~ v27: True if an effect dword ($effectId, arg1, arg2) occurs dword-aligned and is NOT the effect of one of the $upgradeNames groups
;~ ('|Name|Name|') nor of a header-less mod/inscription group (effect right after the tooltip)
Func HasInherentEffect($hex, $effectId, $arg1, $arg2, $upgradeNames)
	For $i = 1 To StringLen($hex) - 7 Step 8
		If GetModStructDwordEffectId($hex, $i) <> $effectId Then ContinueLoop
		If GetModStructDwordArgByte($hex, $i, 1) <> $arg1 Or GetModStructDwordArgByte($hex, $i, 2) <> $arg2 Then ContinueLoop
		If Not IsEffectFromUpgrade($hex, $i, $upgradeNames) Then Return True
	Next
	Return False
EndFunc


;~ v27: True if the effect dword at $position is an effect (1st..3rd after the tooltip, same group) of an upgrade named in $upgradeNames
;~ (or directly follows a tooltip with no upgrade header - legacy rule)
Func IsEffectFromUpgrade($hex, $position, $upgradeNames)
	For $j = 1 To $MODSTRUCT_MAX_EFFECTS_PER_UPGRADE
		Local $markerPosition = $position - 8 * $j
		If $markerPosition < 1 Then ExitLoop
		If GetModStructDwordIdentifier($hex, $markerPosition) == '2408' Then ExitLoop
		Local $marker = StringMid($hex, $markerPosition + 4, 2)
		If $marker <> $STRUCT_WEAPON_UPGRADE And $marker <> $STRUCT_INSCRIPTION Then ContinueLoop
		Local $upgradeId = 0
		If $markerPosition > 8 And GetModStructDwordIdentifier($hex, $markerPosition - 8) == '2408' Then $upgradeId = GetModStructDwordArg($hex, $markerPosition - 8)
		If $upgradeId == 0 Then Return $j == 1
		Local $parts = StringSplit(GetWeaponUpgradeInfoFromId($upgradeId), '|')
		If $parts[0] < 2 Then Return False
		Return StringInStr($upgradeNames, '|' & $parts[2] & '|') > 0
	Next
	Return False
EndFunc


;~ v27 (AMG t35u-t38u): True if the item halves BOTH casting time and skill recharge, each one either as 20% of $attribute (the
;~ item's requirement attribute, HalvesCastingTimeAttribute / HalvesSkillRechargeAttribute) or as an inherent 10% of all spells
;~ (HalvesCastingTimeGeneral / HalvesSkillRechargeGeneral): 20/20, 10/10, 20% HCT + 10% HSR and 10% HCT + 20% HSR all qualify.
Func HasCasterHalvesPair($hex, $attribute)
	Local $casting = ($attribute >= 0 And ModStructHasEffectArgs($hex, $MODSTRUCT_EFFECT_HCT_ATTRIBUTE, 20, $attribute)) _
		Or HasInherentEffect($hex, $MODSTRUCT_EFFECT_HCT_GENERAL, 10, 0, $OS_KEEP_HCT_GENERAL_UPGRADES)
	If Not $casting Then Return False
	Return ($attribute >= 0 And ModStructHasEffectArgs($hex, $MODSTRUCT_EFFECT_HSR_ATTRIBUTE, 20, $attribute)) _
		Or HasInherentEffect($hex, $MODSTRUCT_EFFECT_HSR_GENERAL, 10, 0, $OS_KEEP_HSR_GENERAL_UPGRADES)
EndFunc


;~ v26: for logs - ' (slaying: species <n>, damage +<x>% vs species)' when the modstruct carries a BaneSpecies dword, else ''
;~ (lets an in-game log show why a slaying weapon was or was not matched: species = Py4GW ItemBaneSpecies, 1 = Charr, 8 = Demons...)
Func DescribeSlayingOnItem($hex)
	Local $species = -1, $damage = -1
	For $i = 1 To StringLen($hex) - 7 Step 8
		Local $effectId = GetModStructDwordEffectId($hex, $i)
		If $effectId == $MODSTRUCT_EFFECT_BANE_SPECIES And $species < 0 Then $species = GetModStructDwordArgByte($hex, $i, 1)
		If $effectId == $MODSTRUCT_EFFECT_DAMAGE_PLUS_VS_SPECIES And $damage < 0 Then $damage = GetModStructDwordArgByte($hex, $i, 1)
	Next
	If $species < 0 Then Return ''
	Return ' (slaying: species ' & $species & ', damage ' & ($damage < 0 ? '?' : '+' & $damage & '%') & ' vs species)'
EndFunc


;~ Human-readable description of every upgrade group of a modstruct, for logs: 'suffix OfEnchanting_Staff (0x00E1), inscription ...'
Func DescribeModStructUpgradeGroups($hex)
	Local $description = ''
	For $i = 9 To StringLen($hex) - 7 Step 8
		Local $marker = StringMid($hex, $i + 4, 2)
		If $marker <> $STRUCT_WEAPON_UPGRADE And $marker <> $STRUCT_INSCRIPTION Then ContinueLoop
		If GetModStructDwordIdentifier($hex, $i - 8) <> '2408' Then ContinueLoop
		Local $upgradeId = GetModStructDwordArg($hex, $i - 8)
		Local $info = GetWeaponUpgradeInfoFromId($upgradeId)
		Local $parts = StringSplit($info, '|')
		Local $label = ($info == '') ? ('unknown ' & ($marker == $STRUCT_INSCRIPTION ? 'inscription' : 'mod')) : ($parts[1] & ' ' & $parts[2])
		$description &= ($description == '' ? '' : ', ') & $label & ' (0x' & Hex($upgradeId, 4) & ')'
	Next
	Return $description
EndFunc


;~ Weapon/offhand upgrade ids (arg of the 0x2408 "Upgrade" modifier that heads every upgrade group in a modstruct).
;~ GENERATED by tools/itemaudit/gen_upgrade_ids.py from Py4GW Py4GWCoreLib/item_mods_src/types.py (ItemUpgradeId + ItemUpgrade maps)
;~ and upgrades.py (mod_type of each upgrade class). 220 ids: 90 prefix, 78 suffix, 52 inscription.
;~ Cross-checked against a GWToolbox modstruct dump (0x0139 Silencing_Daggers, 0x0143 OfShelter_Daggers, 0x0163 TooMuchInformation, 0x021F MeasureForMeasure).
;~ Returns "kind|name|item type" (kind = prefix, suffix or inscription) or "" when the id is not a known weapon upgrade.
Func GetWeaponUpgradeInfoFromId($upgradeId)
	Switch $upgradeId
		Case 0x0081
			Return 'prefix|Icy_Axe|Axe'
		Case 0x0082
			Return 'prefix|Ebon_Axe|Axe'
		Case 0x0083
			Return 'prefix|Shocking_Axe|Axe'
		Case 0x0084
			Return 'prefix|Fiery_Axe|Axe'
		Case 0x0085
			Return 'prefix|Icy_Bow|Bow'
		Case 0x0086
			Return 'prefix|Ebon_Bow|Bow'
		Case 0x0087
			Return 'prefix|Shocking_Bow|Bow'
		Case 0x0088
			Return 'prefix|Fiery_Bow|Bow'
		Case 0x0089
			Return 'prefix|Icy_Hammer|Hammer'
		Case 0x008A
			Return 'prefix|Ebon_Hammer|Hammer'
		Case 0x008B
			Return 'prefix|Shocking_Hammer|Hammer'
		Case 0x008C
			Return 'prefix|Fiery_Hammer|Hammer'
		Case 0x008D
			Return 'prefix|Icy_Sword|Sword'
		Case 0x008E
			Return 'prefix|Ebon_Sword|Sword'
		Case 0x008F
			Return 'prefix|Shocking_Sword|Sword'
		Case 0x0090
			Return 'prefix|Fiery_Sword|Sword'
		Case 0x0091
			Return 'prefix|Defensive_Staff|Staff'
		Case 0x0092
			Return 'prefix|Barbed_Axe|Axe'
		Case 0x0093
			Return 'prefix|Barbed_Sword|Sword'
		Case 0x0094
			Return 'prefix|Crippling_Axe|Axe'
		Case 0x0095
			Return 'prefix|Crippling_Sword|Sword'
		Case 0x0096
			Return 'prefix|Cruel_Axe|Axe'
		Case 0x0097
			Return 'prefix|Cruel_Hammer|Hammer'
		Case 0x0098
			Return 'prefix|Cruel_Sword|Sword'
		Case 0x0099
			Return 'prefix|Furious_Axe|Axe'
		Case 0x009A
			Return 'prefix|Furious_Hammer|Hammer'
		Case 0x009B
			Return 'prefix|Furious_Sword|Sword'
		Case 0x009C
			Return 'prefix|Insightful_Staff|Staff'
		Case 0x009D
			Return 'prefix|Hale_Staff|Staff'
		Case 0x009E
			Return 'prefix|Poisonous_Axe|Axe'
		Case 0x009F
			Return 'prefix|Poisonous_Bow|Bow'
		Case 0x00A0
			Return 'prefix|Poisonous_Sword|Sword'
		Case 0x00A1
			Return 'prefix|Heavy_Axe|Axe'
		Case 0x00A2
			Return 'prefix|Heavy_Hammer|Hammer'
		Case 0x00A3
			Return 'prefix|Zealous_Axe|Axe'
		Case 0x00A4
			Return 'prefix|Zealous_Hammer|Hammer'
		Case 0x00A5
			Return 'prefix|Zealous_Bow|Bow'
		Case 0x00A6
			Return 'prefix|Zealous_Sword|Sword'
		Case 0x00A7
			Return 'prefix|Vampiric_Axe|Axe'
		Case 0x00A8
			Return 'prefix|Vampiric_Hammer|Hammer'
		Case 0x00A9
			Return 'prefix|Vampiric_Bow|Bow'
		Case 0x00AA
			Return 'prefix|Vampiric_Sword|Sword'
		Case 0x00AB
			Return 'prefix|Sundering_Axe|Axe'
		Case 0x00AC
			Return 'prefix|Sundering_Hammer|Hammer'
		Case 0x00AD
			Return 'prefix|Sundering_Bow|Bow'
		Case 0x00AE
			Return 'prefix|Sundering_Sword|Sword'
		Case 0x00C3
			Return 'suffix|OfAttribute_Staff|Staff'
		Case 0x00C5
			Return 'suffix|OfDefense_Axe|Axe'
		Case 0x00C6
			Return 'suffix|OfDefense_Bow|Bow'
		Case 0x00C7
			Return 'suffix|OfWarding_Axe|Axe'
		Case 0x00C8
			Return 'suffix|OfWarding_Bow|Bow'
		Case 0x00C9
			Return 'suffix|OfWarding_Hammer|Hammer'
		Case 0x00CA
			Return 'suffix|OfWarding_Staff|Staff'
		Case 0x00CB
			Return 'suffix|OfWarding_Sword|Sword'
		Case 0x00CC
			Return 'suffix|OfDefense_Hammer|Hammer'
		Case 0x00CD
			Return 'suffix|OfShelter_Axe|Axe'
		Case 0x00CE
			Return 'suffix|OfShelter_Bow|Bow'
		Case 0x00CF
			Return 'suffix|OfShelter_Hammer|Hammer'
		Case 0x00D0
			Return 'suffix|OfShelter_Staff|Staff'
		Case 0x00D1
			Return 'suffix|OfShelter_Sword|Sword'
		Case 0x00D2
			Return 'suffix|OfDefense_Staff|Staff'
		Case 0x00D3
			Return 'suffix|OfDefense_Sword|Sword'
		Case 0x00D4
			Return 'suffix|OfSlaying_Axe|Axe'
		Case 0x00D5
			Return 'suffix|OfSlaying_Bow|Bow'
		Case 0x00D6
			Return 'suffix|OfSlaying_Hammer|Hammer'
		Case 0x00D7
			Return 'suffix|OfSlaying_Staff|Staff'
		Case 0x00D8
			Return 'suffix|OfSlaying_Sword|Sword'
		Case 0x00D9
			Return 'suffix|OfFortitude_Axe|Axe'
		Case 0x00DA
			Return 'suffix|OfFortitude_Bow|Bow'
		Case 0x00DB
			Return 'suffix|OfFortitude_Hammer|Hammer'
		Case 0x00DC
			Return 'suffix|OfFortitude_Staff|Staff'
		Case 0x00DD
			Return 'suffix|OfFortitude_Sword|Sword'
		Case 0x00DE
			Return 'suffix|OfEnchanting_Axe|Axe'
		Case 0x00DF
			Return 'suffix|OfEnchanting_Bow|Bow'
		Case 0x00E0
			Return 'suffix|OfEnchanting_Hammer|Hammer'
		Case 0x00E1
			Return 'suffix|OfEnchanting_Staff|Staff'
		Case 0x00E2
			Return 'suffix|OfEnchanting_Sword|Sword'
		Case 0x00E8
			Return 'suffix|OfAxeMastery|Axe'
		Case 0x00E9
			Return 'suffix|OfMarksmanship|Bow'
		Case 0x00EA
			Return 'suffix|OfHammerMastery|Hammer'
		Case 0x00EB
			Return 'suffix|OfSwordsmanship|Sword'
		Case 0x012E
			Return 'prefix|Icy_Daggers|Daggers'
		Case 0x012F
			Return 'prefix|Ebon_Daggers|Daggers'
		Case 0x0130
			Return 'prefix|Fiery_Daggers|Daggers'
		Case 0x0131
			Return 'prefix|Shocking_Daggers|Daggers'
		Case 0x0132
			Return 'prefix|Zealous_Daggers|Daggers'
		Case 0x0133
			Return 'prefix|Vampiric_Daggers|Daggers'
		Case 0x0134
			Return 'prefix|Sundering_Daggers|Daggers'
		Case 0x0135
			Return 'prefix|Barbed_Daggers|Daggers'
		Case 0x0136
			Return 'prefix|Crippling_Daggers|Daggers'
		Case 0x0137
			Return 'prefix|Cruel_Daggers|Daggers'
		Case 0x0138
			Return 'prefix|Poisonous_Daggers|Daggers'
		Case 0x0139
			Return 'prefix|Silencing_Daggers|Daggers'
		Case 0x013A
			Return 'prefix|Furious_Daggers|Daggers'
		Case 0x0141
			Return 'suffix|OfDefense_Daggers|Daggers'
		Case 0x0142
			Return 'suffix|OfWarding_Daggers|Daggers'
		Case 0x0143
			Return 'suffix|OfShelter_Daggers|Daggers'
		Case 0x0144
			Return 'suffix|OfEnchanting_Daggers|Daggers'
		Case 0x0145
			Return 'suffix|OfFortitude_Daggers|Daggers'
		Case 0x0146
			Return 'suffix|OfDaggerMastery|Daggers'
		Case 0x0147
			Return 'prefix|Barbed_Bow|Bow'
		Case 0x0148
			Return 'prefix|Crippling_Bow|Bow'
		Case 0x0149
			Return 'prefix|Silencing_Bow|Bow'
		Case 0x0151
			Return 'suffix|OfValor_Shield|Shield'
		Case 0x0152
			Return 'suffix|OfEndurance_Shield|Shield'
		Case 0x0153
			Return 'suffix|OfMastery_Staff|Staff'
		Case 0x0154
			Return 'suffix|OfDevotion_Staff|Staff'
		Case 0x0155
			Return 'suffix|OfValor_Staff|Staff'
		Case 0x0156
			Return 'suffix|OfEndurance_Staff|Staff'
		Case 0x015C
			Return 'inscription|IHaveThePower|Any'
		Case 0x015E
			Return 'inscription|LetTheMemoryLiveAgain|Any'
		Case 0x015F
			Return 'suffix|OfMemory_Wand|Wand'
		Case 0x0160
			Return 'suffix|OfQuickening_Wand|Wand'
		Case 0x0161
			Return 'suffix|OfFortitude_Shield|Shield'
		Case 0x0162
			Return 'suffix|OfDevotion_Shield|Shield'
		Case 0x0163
			Return 'inscription|TooMuchInformation|Any'
		Case 0x0164
			Return 'inscription|GuidedByFate|Any'
		Case 0x0165
			Return 'inscription|StrengthAndHonor|Any'
		Case 0x0166
			Return 'inscription|VengeanceIsMine|Any'
		Case 0x0167
			Return 'inscription|DontFearTheReaper|Any'
		Case 0x0168
			Return 'inscription|DanceWithDeath|Any'
		Case 0x0169
			Return 'inscription|BrawnOverBrains|Any'
		Case 0x016A
			Return 'inscription|ToThePain|Any'
		Case 0x016B
			Return 'prefix|Icy_Scythe|Scythe'
		Case 0x016C
			Return 'prefix|Ebon_Scythe|Scythe'
		Case 0x016D
			Return 'prefix|Fiery_Spear|Spear'
		Case 0x016E
			Return 'prefix|Shocking_Spear|Spear'
		Case 0x016F
			Return 'prefix|Zealous_Scythe|Scythe'
		Case 0x0170
			Return 'prefix|Zealous_Spear|Spear'
		Case 0x0171
			Return 'prefix|Vampiric_Scythe|Scythe'
		Case 0x0172
			Return 'prefix|Vampiric_Spear|Spear'
		Case 0x0173
			Return 'prefix|Sundering_Scythe|Scythe'
		Case 0x0174
			Return 'prefix|Barbed_Scythe|Scythe'
		Case 0x0175
			Return 'prefix|Crippling_Scythe|Scythe'
		Case 0x0176
			Return 'prefix|Cruel_Scythe|Scythe'
		Case 0x0177
			Return 'prefix|Poisonous_Scythe|Scythe'
		Case 0x0178
			Return 'prefix|Heavy_Scythe|Scythe'
		Case 0x0179
			Return 'prefix|Furious_Scythe|Scythe'
		Case 0x017A
			Return 'prefix|Sundering_Spear|Spear'
		Case 0x017B
			Return 'prefix|Barbed_Spear|Spear'
		Case 0x017C
			Return 'prefix|Crippling_Spear|Spear'
		Case 0x017D
			Return 'prefix|Cruel_Spear|Spear'
		Case 0x017E
			Return 'prefix|Poisonous_Spear|Spear'
		Case 0x017F
			Return 'prefix|Silencing_Spear|Spear'
		Case 0x0180
			Return 'prefix|Furious_Spear|Spear'
		Case 0x0181
			Return 'prefix|Heavy_Spear|Spear'
		Case 0x0188
			Return 'suffix|OfDefense_Scythe|Scythe'
		Case 0x0189
			Return 'suffix|OfWarding_Scythe|Scythe'
		Case 0x018A
			Return 'suffix|OfShelter_Scythe|Scythe'
		Case 0x018B
			Return 'suffix|OfEnchanting_Scythe|Scythe'
		Case 0x018C
			Return 'suffix|OfFortitude_Scythe|Scythe'
		Case 0x018D
			Return 'suffix|OfScytheMastery|Scythe'
		Case 0x018E
			Return 'suffix|OfDefense_Spear|Spear'
		Case 0x018F
			Return 'suffix|OfWarding_Spear|Spear'
		Case 0x0190
			Return 'suffix|OfShelter_Spear|Spear'
		Case 0x0191
			Return 'suffix|OfEnchanting_Spear|Spear'
		Case 0x0192
			Return 'suffix|OfFortitude_Spear|Spear'
		Case 0x0193
			Return 'suffix|OfSpearMastery|Spear'
		Case 0x01B6
			Return 'inscription|IgnoranceIsBliss|Any'
		Case 0x01B7
			Return 'inscription|LifeIsPain|Any'
		Case 0x01B8
			Return 'inscription|ManForAllSeasons|Any'
		Case 0x01B9
			Return 'inscription|SurvivalOfTheFittest|Any'
		Case 0x01BA
			Return 'inscription|MightMakesRight|Any'
		Case 0x01BB
			Return 'inscription|KnowingIsHalfTheBattle|Any'
		Case 0x01BC
			Return 'inscription|FaithIsMyShield|Any'
		Case 0x01BD
			Return 'inscription|DownButNotOut|Any'
		Case 0x01BE
			Return 'inscription|HailToTheKing|Any'
		Case 0x01BF
			Return 'inscription|BeJustAndFearNot|Any'
		Case 0x01C0
			Return 'inscription|LiveForToday|Any'
		Case 0x01C1
			Return 'inscription|SerenityNow|Any'
		Case 0x01C2
			Return 'inscription|ForgetMeNot|Any'
		Case 0x01C3
			Return 'inscription|NotTheFace|Any'
		Case 0x01C4
			Return 'inscription|LeafOnTheWind|Any'
		Case 0x01C5
			Return 'inscription|LikeARollingStone|Any'
		Case 0x01C6
			Return 'inscription|RidersOnTheStorm|Any'
		Case 0x01C7
			Return 'inscription|SleepNowInTheFire|Any'
		Case 0x01C8
			Return 'inscription|ThroughThickAndThin|Any'
		Case 0x01C9
			Return 'inscription|TheRiddleOfSteel|Any'
		Case 0x01CA
			Return 'inscription|FearCutsDeeper|Any'
		Case 0x01CB
			Return 'inscription|ICanSeeClearlyNow|Any'
		Case 0x01CC
			Return 'inscription|SwiftAsTheWind|Any'
		Case 0x01CD
			Return 'inscription|StrengthOfBody|Any'
		Case 0x01CE
			Return 'inscription|CastOutTheUnclean|Any'
		Case 0x01CF
			Return 'inscription|PureOfHeart|Any'
		Case 0x01D0
			Return 'inscription|SoundnessOfMind|Any'
		Case 0x01D1
			Return 'inscription|OnlyTheStrongSurvive|Any'
		Case 0x01D2
			Return 'inscription|LuckOfTheDraw|Any'
		Case 0x01D3
			Return 'inscription|ShelteredByFaith|Any'
		Case 0x01D4
			Return 'inscription|NothingToFear|Any'
		Case 0x01D5
			Return 'inscription|RunForYourLife|Any'
		Case 0x01D6
			Return 'inscription|MasterOfMyDomain|Any'
		Case 0x01D7
			Return 'inscription|AptitudeNotAttitude|Any'
		Case 0x01D8
			Return 'inscription|SeizeTheDay|Any'
		Case 0x01D9
			Return 'inscription|HaveFaith|Any'
		Case 0x01DA
			Return 'inscription|HaleAndHearty|Any'
		Case 0x01DB
			Return 'inscription|DontCallItAComeback|Any'
		Case 0x01DC
			Return 'inscription|IAmSorrow|Any'
		Case 0x01DD
			Return 'inscription|DontThinkTwice|Any'
		Case 0x020B
			Return 'prefix|Fiery_Scythe|Scythe'
		Case 0x020C
			Return 'prefix|Shocking_Scythe|Scythe'
		Case 0x020D
			Return 'prefix|Icy_Spear|Spear'
		Case 0x020E
			Return 'prefix|Ebon_Spear|Spear'
		Case 0x020F
			Return 'prefix|Swift_Staff|Staff'
		Case 0x0217
			Return 'suffix|OfAptitude_Focus|Offhand'
		Case 0x0218
			Return 'suffix|OfFortitude_Focus|Offhand'
		Case 0x0219
			Return 'suffix|OfDevotion_Focus|Offhand'
		Case 0x021A
			Return 'suffix|OfValor_Focus|Offhand'
		Case 0x021B
			Return 'suffix|OfEndurance_Focus|Offhand'
		Case 0x021C
			Return 'suffix|OfSwiftness_Focus|Offhand'
		Case 0x021E
			Return 'inscription|ShowMeTheMoney|Any'
		Case 0x021F
			Return 'inscription|MeasureForMeasure|Any'
		Case 0x0226
			Return 'suffix|OfTheProfession_Axe|Axe'
		Case 0x0227
			Return 'suffix|OfTheProfession_Bow|Bow'
		Case 0x0228
			Return 'suffix|OfTheProfession_Daggers|Daggers'
		Case 0x0229
			Return 'suffix|OfTheProfession_Hammer|Hammer'
		Case 0x022A
			Return 'suffix|OfTheProfession_Wand|Wand'
		Case 0x022B
			Return 'suffix|OfTheProfession_Staff|Staff'
		Case 0x022C
			Return 'suffix|OfTheProfession_Scythe|Scythe'
		Case 0x022D
			Return 'suffix|OfTheProfession_Spear|Spear'
		Case 0x022E
			Return 'suffix|OfTheProfession_Sword|Sword'
	EndSwitch
	Return ''
EndFunc
#EndRegion Modstruct upgrade groups


#Region Perfect-roll extraction (v12 - only perfect / max values can be extracted)
;~ Every 'Extract upgrades only' option must target the MAX roll of its upgrade on that item type (max ranges: Py4GW
;~ Py4GWCoreLib/item_mods_src/upgrades.py ranged()/fixed() instructions, see tools/itemaudit/py4gw_ranges.txt).
;~ For most upgrades the STRUCT_* constant already contains the rolled value (e.g. Of Enchanting '1400B822' = 20%, Of Fortitude
;~ '001E4823' = +30), so a lower roll is a different dword and never matches. The upgrades below are the exceptions: their constant
;~ pins only the fixed part, so the ranged part is checked here on the same upgrade group.
;~ Format: comma-separated 'EFFECTID:ARG:VALUE' (effect id = (identifier >> 4) & 0x3FF in hex, ARG 1|2 = arg1|arg2 of the dword).
;~ Effect ids / argument positions: Py4GW types.py ModifierIdentifier + upgrade_parser.py.
Func GetPerfectRollRequirements($structName)
	Switch $structName
		; slaying suffixes: BaneSpecies (0x008, arg1 = species) + DamagePlusVsSpecies (0x224, arg1 = damage %, range 15-20) -> +20%
		Case 'STRUCT_MOD_OF_DEATHBANE', 'STRUCT_MOD_OF_CHARRSLAYING', 'STRUCT_MOD_OF_TROLLSLAYING', 'STRUCT_MOD_OF_PRUNING', _
				'STRUCT_MOD_OF_SKELETON_SLAYING', 'STRUCT_MOD_OF_GIANT_SLAYING', 'STRUCT_MOD_OF_DWARF_SLAYING', 'STRUCT_MOD_OF_TENGU_SLAYING', _
				'STRUCT_MOD_OF_DEMON_SLAYING', 'STRUCT_MOD_OF_OGRE_SLAYING', 'STRUCT_MOD_OF_DRAGON_SLAYING'
			Return '224:1:20'
		; To the Pain (ArmorMinusAttacking 10 fixed) / Brawn over Brains (EnergyMinus 5 fixed): DamagePlusPercent (0x223, arg2, range 14-15) -> 15%
		Case 'STRUCT_INSCRIPTION_TO_THE_PAIN', 'STRUCT_INSCRIPTION_BRAWN_OVER_BRAIN'
			Return '223:2:15'
		; Ignorance is Bliss (EnergyMinus 5 fixed) / Life is Pain (HealthMinus 20 fixed): ArmorPlus (0x210, arg2, range 4-5) -> +5
		Case 'STRUCT_INSCRIPTION_IGNORANCE_IS_BLISS', 'STRUCT_INSCRIPTION_LIFE_IS_PAIN'
			Return '210:2:5'
	EndSwitch
	Return ''
EndFunc


;~ Effect id ((identifier >> 4) & 0x3FF, Py4GW decoded_modifier) of the dword starting at $position
Func GetModStructDwordEffectId($hex, $position)
	Return BitAND(BitShift(Dec(GetModStructDwordIdentifier($hex, $position)), 4), 0x3FF)
EndFunc


;~ arg1 ($argIndex = 1) or arg2 ($argIndex = 2) byte of the dword starting at $position ('BBAAIIII' = arg2, arg1, identifier)
Func GetModStructDwordArgByte($hex, $position, $argIndex)
	Return Dec(StringMid($hex, $position + (($argIndex == 1) ? 2 : 0), 2))
EndFunc


;~ True if the effect dwords of the upgrade group whose tooltip/marker dword starts at $markerPosition carry every requirement
;~ (the group ends at the next 0x2408 Upgrade dword or after $MODSTRUCT_MAX_EFFECTS_PER_UPGRADE effects)
Func UpgradeGroupMeetsRequirements($hex, $markerPosition, $requirements)
	If $requirements == '' Then Return True
	Local $length = StringLen($hex)
	Local $list = StringSplit($requirements, ',')
	For $r = 1 To $list[0]
		Local $fields = StringSplit($list[$r], ':')
		If $fields[0] <> 3 Then Return False
		Local $effectId = Dec($fields[1]), $argIndex = Int($fields[2]), $value = Int($fields[3])
		Local $found = False
		For $j = 1 To $MODSTRUCT_MAX_EFFECTS_PER_UPGRADE
			Local $position = $markerPosition + 8 * $j
			If $position > $length - 7 Then ExitLoop
			If GetModStructDwordIdentifier($hex, $position) == '2408' Then ExitLoop
			If GetModStructDwordEffectId($hex, $position) <> $effectId Then ContinueLoop
			If GetModStructDwordArgByte($hex, $position, $argIndex) == $value Then
				$found = True
				ExitLoop
			EndIf
		Next
		If Not $found Then Return False
	Next
	Return True
EndFunc


;~ v13: the upgrade-option roots that only offer perfect options (v29: only 'Extract upgrades only'; 'Keep components' was removed)
Global Const $PERFECT_OPTION_ROOTS[] = ['Extract Components']	; v29: 'Keep components' removed (dropped at load)


;~ Removes every leaf under the perfect-option roots that is not a perfect option (IsPerfectUpgradeOption) from a parsed loot
;~ configuration, e.g. Minor/Major runes saved by an older version. Other settings are untouched; ONE warning lists what was dropped.
Func PruneNonPerfectUpgradeOptions($jsonLootOptions)
	Local $removed = 0
	Local $removedChecked = ''
	; v35: also prune leftover 'Extract upgrades only' keys (pre-migration / unit tests)
	Local $roots[] = ['Extract Components', 'Extract upgrades only']
	For $root In $roots
		$jsonLootOptions = PruneNonPerfectOptionsInRoot($jsonLootOptions, $root, $removed, $removedChecked)
	Next
	If $removed > 0 Then
		Warn('[Loot] Ignored ' & $removed & ' non-perfect option(s) under "' & _ArrayToString($PERFECT_OPTION_ROOTS, '" / "') _
			& '" (only max rolls / Superior runes - plus the Major Vigor exception - can be kept or extracted)' & ($removedChecked == '' ? '' : ' - they were checked: ' & $removedChecked))
	EndIf
	Return $jsonLootOptions
EndFunc


;~ Same, for one root only (kept for callers/tests that prune a single branch)
Func PruneNonPerfectExtractOptions($jsonLootOptions, $root)
	Local $removed = 0
	Local $removedChecked = ''
	$jsonLootOptions = PruneNonPerfectOptionsInRoot($jsonLootOptions, $root, $removed, $removedChecked)
	If $removed > 0 Then
		Warn('[Extract] Ignored ' & $removed & ' non-perfect option(s) under "' & $root & '" (only max rolls / Superior runes - plus the Major Vigor exception - can be extracted)' _
			& ($removedChecked == '' ? '' : ' - they were checked: ' & $removedChecked))
	EndIf
	Return $jsonLootOptions
EndFunc


Func PruneNonPerfectOptionsInRoot($jsonLootOptions, $root, ByRef $removed, ByRef $removedChecked)
	If Not IsMap($jsonLootOptions) Then Return $jsonLootOptions
	If Not MapExists($jsonLootOptions, $root) Then Return $jsonLootOptions
	If Not IsMap($jsonLootOptions[$root]) Then Return $jsonLootOptions
	Local $checkedBefore = $removedChecked
	Local $checkedHere = ''
	$jsonLootOptions[$root] = PruneNonPerfectExtractNode($jsonLootOptions[$root], '', $removed, $checkedHere)
	If $checkedHere <> '' Then
		$checkedHere = $root & ': ' & $checkedHere
		$removedChecked = ($checkedBefore == '') ? $checkedHere : ($checkedBefore & '; ' & $checkedHere)
	EndIf
	Return $jsonLootOptions
EndFunc


Func PruneNonPerfectExtractNode($node, $relativePath, ByRef $removed, ByRef $removedChecked)
	For $key In MapKeys($node)
		Local $childPath = ($relativePath == '') ? $key : ($relativePath & '.' & $key)
		If IsMap($node[$key]) Then
			$node[$key] = PruneNonPerfectExtractNode($node[$key], $childPath, $removed, $removedChecked)
			If UBound(MapKeys($node[$key])) == 0 Then MapRemove($node, $key)
		ElseIf Not IsPerfectUpgradeOption($childPath) Then
			$removed += 1
			If $node[$key] == True Then $removedChecked &= ($removedChecked == '' ? '' : ', ') & $childPath
			MapRemove($node, $key)
		EndIf
	Next
	Return $node
EndFunc


;~ GENERATED by tools/itemaudit/perfect_options.py - the 447 perfect (max roll / max tier) upgrade options, relative to the
;~ 'Extract upgrades only' root (v29: Keep components removed): Superior-tier runes, single-tier runes, every insignia, max-roll weapon
;~ mods and inscriptions, plus the v19 exception Armor upgrades.All.Runes.Major Vigor. Anything else under those roots is dropped at load time
;~ (PruneNonPerfectUpgradeOptions).

;~ v36: a rune leaf (Armor upgrades.<All|Profession>.Runes.<name>) that maps to a real STRUCT_* constant
Func IsAllowedRuneUpgradeOption($relativePath)
	Local $parts = StringSplit($relativePath, '.')
	If $parts[0] <> 4 Then Return False
	If $parts[1] <> 'Armor upgrades' Then Return False
	If $parts[3] <> 'Runes' Then Return False
	Return IsMap(ResolveUpgradeLeafDefinition($relativePath))
EndFunc


Func IsPerfectUpgradeOption($relativePath)
	; v36: Minor and Major runes are valid extract/store options again (existing STRUCT_* / ID_* constants)
	If IsAllowedRuneUpgradeOption($relativePath) Then Return True
	Switch $relativePath
		Case 'Armor upgrades.All.Insignias.Survivor', 'Armor upgrades.All.Insignias.Radiant', 'Armor upgrades.All.Insignias.Stalwart', 'Armor upgrades.All.Insignias.Brawlers', 'Armor upgrades.All.Insignias.Blessed', 'Armor upgrades.All.Insignias.Heralds'
			Return True
		Case 'Armor upgrades.All.Insignias.Sentrys', 'Armor upgrades.All.Runes.Vitae', 'Armor upgrades.All.Runes.Attunement', 'Armor upgrades.All.Runes.Major Vigor', 'Armor upgrades.All.Runes.Recovery', 'Armor upgrades.All.Runes.Restoration'
			Return True
		Case 'Armor upgrades.All.Runes.Clarity', 'Armor upgrades.All.Runes.Purity', 'Armor upgrades.All.Runes.Superior Vigor', 'Armor upgrades.Assassin.Insignias.Vanguards', 'Armor upgrades.Assassin.Insignias.Infiltrators', 'Armor upgrades.Assassin.Insignias.Saboteurs'
			Return True
		Case 'Armor upgrades.Assassin.Insignias.Nightstalkers', 'Armor upgrades.Assassin.Runes.Superior Critical Strikes', 'Armor upgrades.Assassin.Runes.Superior Dagger Mastery', 'Armor upgrades.Assassin.Runes.Superior Deadly Arts', 'Armor upgrades.Assassin.Runes.Superior Shadow Arts', 'Armor upgrades.Dervish.Insignias.Windwalker'
			Return True
		Case 'Armor upgrades.Dervish.Insignias.Forsaken', 'Armor upgrades.Dervish.Runes.Superior Earth Prayers', 'Armor upgrades.Dervish.Runes.Superior Mysticism', 'Armor upgrades.Dervish.Runes.Superior Scythe Mastery', 'Armor upgrades.Dervish.Runes.Superior Wind Prayers', 'Armor upgrades.Elementalist.Insignias.Hydromancer'
			Return True
		Case 'Armor upgrades.Elementalist.Insignias.Geomancer', 'Armor upgrades.Elementalist.Insignias.Pyromancer', 'Armor upgrades.Elementalist.Insignias.Aeromancer', 'Armor upgrades.Elementalist.Insignias.Prismatic', 'Armor upgrades.Elementalist.Runes.Superior Air Magic', 'Armor upgrades.Elementalist.Runes.Superior Earth Magic'
			Return True
		Case 'Armor upgrades.Elementalist.Runes.Superior Energy Storage', 'Armor upgrades.Elementalist.Runes.Superior Fire Magic', 'Armor upgrades.Elementalist.Runes.Superior Water Magic', 'Armor upgrades.Mesmer.Insignias.Virtuosos', 'Armor upgrades.Mesmer.Insignias.Artificers', 'Armor upgrades.Mesmer.Insignias.Prodigys'
			Return True
		Case 'Armor upgrades.Mesmer.Runes.Superior Domination Magic', 'Armor upgrades.Mesmer.Runes.Superior Fast Casting', 'Armor upgrades.Mesmer.Runes.Superior Illusion Magic', 'Armor upgrades.Mesmer.Runes.Superior Inspiration Magic', 'Armor upgrades.Monk.Insignias.Wanderers', 'Armor upgrades.Monk.Insignias.Disciples'
			Return True
		Case 'Armor upgrades.Monk.Insignias.Anchorites', 'Armor upgrades.Monk.Runes.Superior Divine Favor', 'Armor upgrades.Monk.Runes.Superior Healing Prayers', 'Armor upgrades.Monk.Runes.Superior Protection Prayers', 'Armor upgrades.Monk.Runes.Superior Smiting Prayers', 'Armor upgrades.Necromancer.Insignias.Bloodstained'
			Return True
		Case 'Armor upgrades.Necromancer.Insignias.Tormentors', 'Armor upgrades.Necromancer.Insignias.Bonelace', 'Armor upgrades.Necromancer.Insignias.Minion Masters', 'Armor upgrades.Necromancer.Insignias.Blighters', 'Armor upgrades.Necromancer.Insignias.Undertakers', 'Armor upgrades.Necromancer.Runes.Superior Blood Magic'
			Return True
		Case 'Armor upgrades.Necromancer.Runes.Superior Curses', 'Armor upgrades.Necromancer.Runes.Superior Death Magic', 'Armor upgrades.Necromancer.Runes.Superior Soul Reaping', 'Armor upgrades.Paragon.Insignias.Centurions', 'Armor upgrades.Paragon.Runes.Superior Command', 'Armor upgrades.Paragon.Runes.Superior Leadership'
			Return True
		Case 'Armor upgrades.Paragon.Runes.Superior Motivation', 'Armor upgrades.Paragon.Runes.Superior Spear Mastery', 'Armor upgrades.Ranger.Insignias.Frostbound', 'Armor upgrades.Ranger.Insignias.Pyrebound', 'Armor upgrades.Ranger.Insignias.Stormbound', 'Armor upgrades.Ranger.Insignias.Scouts'
			Return True
		Case 'Armor upgrades.Ranger.Insignias.Earthbound', 'Armor upgrades.Ranger.Insignias.Beastmasters', 'Armor upgrades.Ranger.Runes.Superior Beast Mastery', 'Armor upgrades.Ranger.Runes.Superior Expertise', 'Armor upgrades.Ranger.Runes.Superior Marksmanship', 'Armor upgrades.Ranger.Runes.Superior Wilderness Survival'
			Return True
		Case 'Armor upgrades.Ritualist.Insignias.Shamans', 'Armor upgrades.Ritualist.Insignias.Ghost Forge', 'Armor upgrades.Ritualist.Insignias.Mystics', 'Armor upgrades.Ritualist.Runes.Superior Channeling Magic', 'Armor upgrades.Ritualist.Runes.Superior Communing', 'Armor upgrades.Ritualist.Runes.Superior Restoration Magic'
			Return True
		Case 'Armor upgrades.Ritualist.Runes.Superior Spawning Power', 'Armor upgrades.Warrior.Insignias.Knights', 'Armor upgrades.Warrior.Insignias.Lieutenants', 'Armor upgrades.Warrior.Insignias.Stonefist', 'Armor upgrades.Warrior.Insignias.Dreadnought', 'Armor upgrades.Warrior.Insignias.Sentinels'
			Return True
		Case 'Armor upgrades.Warrior.Runes.Superior Axe Mastery', 'Armor upgrades.Warrior.Runes.Superior Hammer Mastery', 'Armor upgrades.Warrior.Runes.Superior Strength', 'Armor upgrades.Warrior.Runes.Superior Swordsmanship', 'Armor upgrades.Warrior.Runes.Superior Tactics', 'Armor upgrades.Warrior.Runes.Superior Absorption'
			Return True
		Case 'Inscriptions.Measure for measure (Highly salvageable)', 'Inscriptions.Show me the money (Improved sale value)', 'Inscriptions.Weapon.Strength and honor (Damage +15% while Health is above 50%)', 'Inscriptions.Weapon.Guided by fate (Damage +15% while Enchanted)', 'Inscriptions.Weapon.Dance with death (Damage +15% while in a Stance)', 'Inscriptions.Weapon.Too much information (Damage +15% vs Hexed foes)'
			Return True
		Case 'Inscriptions.Weapon.To the pain (Damage +15% Armor -10 while attacking)', 'Inscriptions.Weapon.Brawn over brain (Damage +15% Energy -5)', 'Inscriptions.Weapon.Vengeance is mine (Damage +20% while Health is below 50%)', 'Inscriptions.Weapon.Dont fear the reaper (Damage +20% while Hexed)', 'Inscriptions.Weapon.Dont think twice (Halves casting time of spells)', 'Inscriptions.Weapon.Martial.I have the power (Energy +5)'
			Return True
		Case 'Inscriptions.Weapon.Martial.Let the memory live again (Halves skill recharge of spells)', 'Inscriptions.Weapon.Spellcasting.Hale and hearty (Energy +5 while Health is above 50%)', 'Inscriptions.Weapon.Spellcasting.Have faith (Energy +5 while Enchanted)', 'Inscriptions.Weapon.Spellcasting.Dont call it a come back (Energy +7 while Health is below 50%)', 'Inscriptions.Weapon.Spellcasting.I am sorrow (Energy +7 while Hexed)', 'Inscriptions.Weapon.Spellcasting.Seize the day (Energy +15 Energy regeneration -1)'
			Return True
		Case 'Inscriptions.Weapon.Spellcasting.Aptitude not attitude (Halves casting time of spells of item''s attribute)', 'Inscriptions.Offhand.Focus.Forget me not (Halves skill recharge of spells of item''s attribute)', 'Inscriptions.Offhand.Focus.Serenity now (Halves skill recharge of spells)', 'Inscriptions.Offhand.Focus.Hail to the king (Armor +5 while Health is above 50%)', 'Inscriptions.Offhand.Focus.Faith is my shield (Armor +5 while Enchanted)', 'Inscriptions.Offhand.Focus.Might makes right (Armor +5 while attacking)'
			Return True
		Case 'Inscriptions.Offhand.Focus.Knowing is half the battle (Armor +5 while casting)', 'Inscriptions.Offhand.Focus.Man for all seasons (Armor +5 vs Elemental damage)', 'Inscriptions.Offhand.Focus.Survival of the fittest (Armor +5 vs Physical damage)', 'Inscriptions.Offhand.Focus.Ignorance is bliss (Armor +5 Energy -5)', 'Inscriptions.Offhand.Focus.Life is pain (Armor +5 Health -20)', 'Inscriptions.Offhand.Focus.Down but not out (Armor +10 while Health is below 50%)'
			Return True
		Case 'Inscriptions.Offhand.Focus.Be just and fear not (Armor +10 while hexed)', 'Inscriptions.Offhand.Focus.Live for today (Energy +15 Energy regeneration -1)', 'Inscriptions.Offhand.Master of my domain (Item''s attribute +1)', 'Inscriptions.Offhand.Not the face (Armor +10 vs Blunt damage)', 'Inscriptions.Offhand.Leaf on the wind (Armor +10 vs Cold damage)', 'Inscriptions.Offhand.Like a rolling stone (Armor +10 vs Earth damage)'
			Return True
		Case 'Inscriptions.Offhand.Sleep now in the fire (Armor +10 vs Fire damage)', 'Inscriptions.Offhand.Riders on the storm (Armor +10 vs Lightning damage)', 'Inscriptions.Offhand.Through thick and thin (Armor +10 vs Piercing damage)', 'Inscriptions.Offhand.The riddle of steel (Armor +10 vs Slashing damage)', 'Inscriptions.Offhand.Sheltered by faith (Received physical damage -2 while Enchanted)', 'Inscriptions.Offhand.Run for your life (Received physical damage -2 while in a Stance)'
			Return True
		Case 'Inscriptions.Offhand.Nothing to fear (Received physical damage -3 while Hexed)', 'Inscriptions.Offhand.Luck of the draw (Received physical damage -5 - Chance 20%)', 'Inscriptions.Offhand.Fear cuts deeper (Reduces Bleeding duration on you by 20%)', 'Inscriptions.Offhand.I can see clearly now (Reduces Blind duration on you by 20%)', 'Inscriptions.Offhand.Swift as the wind (Reduces Crippled duration on you by 20%)', 'Inscriptions.Offhand.Soundness of mind (Reduces Dazed duration on you by 20%)'
			Return True
		Case 'Inscriptions.Offhand.Strength of body (Reduces Deep Wound duration on you by 20%)', 'Inscriptions.Offhand.Cast out the unclean (Reduces Disease duration on you by 20%)', 'Inscriptions.Offhand.Pure of heart (Reduces Poison duration on you by 20%)', 'Inscriptions.Offhand.Only the strong survive (Reduces Weakness duration on you by 20%)', 'Mods.Axe.Prefix - Haft.Ebon (Earth damage)', 'Mods.Axe.Prefix - Haft.Fiery (Fire damage)'
			Return True
		Case 'Mods.Axe.Prefix - Haft.Icy (Cold damage)', 'Mods.Axe.Prefix - Haft.Shocking (Lightning damage)', 'Mods.Axe.Prefix - Haft.Barbed (Lengthens Bleeding duration on foes by 33%)', 'Mods.Axe.Prefix - Haft.Cruel (Lengthens Deep Wound duration on foes by 33%)', 'Mods.Axe.Prefix - Haft.Crippling (Lengthens Crippled duration on foes by 33%)', 'Mods.Axe.Prefix - Haft.Heavy (Lengthens Weakness duration on foes by 33%)'
			Return True
		Case 'Mods.Axe.Prefix - Haft.Poisonous (Lengthens Poison duration on foes by 33%)', 'Mods.Axe.Prefix - Haft.Furious (Double Adrenaline on hit - Chance 10%)', 'Mods.Axe.Prefix - Haft.Sundering (Armor penetration +20% - Chance 20%)', 'Mods.Axe.Prefix - Haft.Vampiric 3 (Life Draining 3 Health regeneration -1)', 'Mods.Axe.Prefix - Haft.Zealous (Energy gain on hit: 1 Energy regeneration: -1)', 'Mods.Axe.Suffix - Grip.of Fortitude (Health +30)'
			Return True
		Case 'Mods.Axe.Suffix - Grip.Of Defense (Armor +5)', 'Mods.Axe.Suffix - Grip.Of Shelter (Armor +7 vs physical damage)', 'Mods.Axe.Suffix - Grip.Of Warding (Armor +7 vs elemental damage)', 'Mods.Axe.Suffix - Grip.Of Enchanting (Enchantments last 20% longer)', 'Mods.Axe.Suffix - Grip.Of The Warrior', 'Mods.Axe.Suffix - Grip.Of The Ranger'
			Return True
		Case 'Mods.Axe.Suffix - Grip.Of The Necromancer', 'Mods.Axe.Suffix - Grip.Of The Mesmer', 'Mods.Axe.Suffix - Grip.Of The Elementalist', 'Mods.Axe.Suffix - Grip.Of The Monk', 'Mods.Axe.Suffix - Grip.Of The Ritualist', 'Mods.Axe.Suffix - Grip.Of The Assassin'
			Return True
		Case 'Mods.Axe.Suffix - Grip.Of The Paragon', 'Mods.Axe.Suffix - Grip.Of The Dervish', 'Mods.Axe.Suffix - Grip.Of Deathbane', 'Mods.Axe.Suffix - Grip.Of Charrslaying', 'Mods.Axe.Suffix - Grip.Of Trollslaying', 'Mods.Axe.Suffix - Grip.Of Pruning'
			Return True
		Case 'Mods.Axe.Suffix - Grip.Of Skeleton Slaying', 'Mods.Axe.Suffix - Grip.Of Giant Slaying', 'Mods.Axe.Suffix - Grip.Of Dwarf Slaying', 'Mods.Axe.Suffix - Grip.Of Tengu Slaying', 'Mods.Axe.Suffix - Grip.Of Demon Slaying', 'Mods.Axe.Suffix - Grip.Of Ogre Slaying'
			Return True
		Case 'Mods.Axe.Suffix - Grip.Of Dragon Slaying', 'Mods.Axe.Suffix - Grip.Of Axe Mastery (Item''s attribute +1 - 20% chance while using skills)', 'Mods.Bow.Prefix - String.Ebon (Earth damage)', 'Mods.Bow.Prefix - String.Fiery (Fire damage)', 'Mods.Bow.Prefix - String.Icy (Cold damage)', 'Mods.Bow.Prefix - String.Shocking (Lightning damage)'
			Return True
		Case 'Mods.Bow.Prefix - String.Barbed (Lengthens Bleeding duration on foes by 33%)', 'Mods.Bow.Prefix - String.Crippling (Lengthens Crippled duration on foes by 33%)', 'Mods.Bow.Prefix - String.Poisonous (Lengthens Poison duration on foes by 33%)', 'Mods.Bow.Prefix - String.Silencing (Lengthens Dazed duration on foes by 33%)', 'Mods.Bow.Prefix - String.Sundering (Armor penetration +20% - Chance 20%)', 'Mods.Bow.Prefix - String.Vampiric 5 (Life Draining 5 Health regeneration -1)'
			Return True
		Case 'Mods.Bow.Prefix - String.Zealous (Energy gain on hit: 1 Energy regeneration: -1)', 'Mods.Bow.Suffix - Grip.of Fortitude (Health +30)', 'Mods.Bow.Suffix - Grip.Of Defense (Armor +5)', 'Mods.Bow.Suffix - Grip.Of Shelter (Armor +7 vs physical damage)', 'Mods.Bow.Suffix - Grip.Of Warding (Armor +7 vs elemental damage)', 'Mods.Bow.Suffix - Grip.Of Enchanting (Enchantments last 20% longer)'
			Return True
		Case 'Mods.Bow.Suffix - Grip.Of The Warrior', 'Mods.Bow.Suffix - Grip.Of The Ranger', 'Mods.Bow.Suffix - Grip.Of The Necromancer', 'Mods.Bow.Suffix - Grip.Of The Mesmer', 'Mods.Bow.Suffix - Grip.Of The Elementalist', 'Mods.Bow.Suffix - Grip.Of The Monk'
			Return True
		Case 'Mods.Bow.Suffix - Grip.Of The Ritualist', 'Mods.Bow.Suffix - Grip.Of The Assassin', 'Mods.Bow.Suffix - Grip.Of The Paragon', 'Mods.Bow.Suffix - Grip.Of The Dervish', 'Mods.Bow.Suffix - Grip.Of Deathbane', 'Mods.Bow.Suffix - Grip.Of Charrslaying'
			Return True
		Case 'Mods.Bow.Suffix - Grip.Of Trollslaying', 'Mods.Bow.Suffix - Grip.Of Pruning', 'Mods.Bow.Suffix - Grip.Of Skeleton Slaying', 'Mods.Bow.Suffix - Grip.Of Giant Slaying', 'Mods.Bow.Suffix - Grip.Of Dwarf Slaying', 'Mods.Bow.Suffix - Grip.Of Tengu Slaying'
			Return True
		Case 'Mods.Bow.Suffix - Grip.Of Demon Slaying', 'Mods.Bow.Suffix - Grip.Of Ogre Slaying', 'Mods.Bow.Suffix - Grip.Of Dragon Slaying', 'Mods.Bow.Suffix - Grip.Of Marksmanship (Item''s attribute +1 - 20% chance while using skills)', 'Mods.Dagger.Prefix - Tang.Ebon (Earth damage)', 'Mods.Dagger.Prefix - Tang.Fiery (Fire damage)'
			Return True
		Case 'Mods.Dagger.Prefix - Tang.Icy (Cold damage)', 'Mods.Dagger.Prefix - Tang.Shocking (Lightning damage)', 'Mods.Dagger.Prefix - Tang.Barbed (Lengthens Bleeding duration on foes by 33%)', 'Mods.Dagger.Prefix - Tang.Cruel (Lengthens Deep Wound duration on foes by 33%)', 'Mods.Dagger.Prefix - Tang.Crippling (Lengthens Crippled duration on foes by 33%)', 'Mods.Dagger.Prefix - Tang.Poisonous (Lengthens Poison duration on foes by 33%)'
			Return True
		Case 'Mods.Dagger.Prefix - Tang.Silencing (Lengthens Dazed duration on foes by 33%)', 'Mods.Dagger.Prefix - Tang.Furious (Double Adrenaline on hit - Chance 10%)', 'Mods.Dagger.Prefix - Tang.Sundering (Armor penetration +20% - Chance 20%)', 'Mods.Dagger.Prefix - Tang.Vampiric 3 (Life Draining 3 Health regeneration -1)', 'Mods.Dagger.Prefix - Tang.Zealous (Energy gain on hit: 1 Energy regeneration: -1)', 'Mods.Dagger.Suffix - Handle.of Fortitude (Health +30)'
			Return True
		Case 'Mods.Dagger.Suffix - Handle.Of Defense (Armor +5)', 'Mods.Dagger.Suffix - Handle.Of Shelter (Armor +7 vs physical damage)', 'Mods.Dagger.Suffix - Handle.Of Warding (Armor +7 vs elemental damage)', 'Mods.Dagger.Suffix - Handle.Of Enchanting (Enchantments last 20% longer)', 'Mods.Dagger.Suffix - Handle.Of The Warrior', 'Mods.Dagger.Suffix - Handle.Of The Ranger'
			Return True
		Case 'Mods.Dagger.Suffix - Handle.Of The Necromancer', 'Mods.Dagger.Suffix - Handle.Of The Mesmer', 'Mods.Dagger.Suffix - Handle.Of The Elementalist', 'Mods.Dagger.Suffix - Handle.Of The Monk', 'Mods.Dagger.Suffix - Handle.Of The Ritualist', 'Mods.Dagger.Suffix - Handle.Of The Assassin'
			Return True
		Case 'Mods.Dagger.Suffix - Handle.Of The Paragon', 'Mods.Dagger.Suffix - Handle.Of The Dervish', 'Mods.Dagger.Suffix - Handle.Of Dagger Mastery (Item''s attribute +1 - 20% chance while using skills)', 'Mods.Focus.Suffix - Core.of Fortitude (Health +30)', 'Mods.Focus.Suffix - Core.Of Devotion (Health +45 while Enchanted)', 'Mods.Focus.Suffix - Core.Of Endurance (Health +45 while in a Stance)'
			Return True
		Case 'Mods.Focus.Suffix - Core.Of Valor (Health +60 while Hexed)', 'Mods.Focus.Suffix - Core.Of Aptitude (Halves casting time of item''s attribute spells - Chance 20%)', 'Mods.Focus.Suffix - Core.Of Swiftness (Halves casting time of spells - Chance 10%)', 'Mods.Hammer.Prefix - Haft.Ebon (Earth damage)', 'Mods.Hammer.Prefix - Haft.Fiery (Fire damage)', 'Mods.Hammer.Prefix - Haft.Icy (Cold damage)'
			Return True
		Case 'Mods.Hammer.Prefix - Haft.Shocking (Lightning damage)', 'Mods.Hammer.Prefix - Haft.Cruel (Lengthens Deep Wound duration on foes by 33%)', 'Mods.Hammer.Prefix - Haft.Heavy (Lengthens Weakness duration on foes by 33%)', 'Mods.Hammer.Prefix - Haft.Furious (Double Adrenaline on hit - Chance 10%)', 'Mods.Hammer.Prefix - Haft.Sundering (Armor penetration +20% - Chance 20%)', 'Mods.Hammer.Prefix - Haft.Vampiric 5 (Life Draining 5 Health regeneration -1)'
			Return True
		Case 'Mods.Hammer.Prefix - Haft.Zealous (Energy gain on hit: 1 Energy regeneration: -1)', 'Mods.Hammer.Suffix - Grip.of Fortitude (Health +30)', 'Mods.Hammer.Suffix - Grip.Of Defense (Armor +5)', 'Mods.Hammer.Suffix - Grip.Of Shelter (Armor +7 vs physical damage)', 'Mods.Hammer.Suffix - Grip.Of Warding (Armor +7 vs elemental damage)', 'Mods.Hammer.Suffix - Grip.Of Enchanting (Enchantments last 20% longer)'
			Return True
		Case 'Mods.Hammer.Suffix - Grip.Of The Warrior', 'Mods.Hammer.Suffix - Grip.Of The Ranger', 'Mods.Hammer.Suffix - Grip.Of The Necromancer', 'Mods.Hammer.Suffix - Grip.Of The Mesmer', 'Mods.Hammer.Suffix - Grip.Of The Elementalist', 'Mods.Hammer.Suffix - Grip.Of The Monk'
			Return True
		Case 'Mods.Hammer.Suffix - Grip.Of The Ritualist', 'Mods.Hammer.Suffix - Grip.Of The Assassin', 'Mods.Hammer.Suffix - Grip.Of The Paragon', 'Mods.Hammer.Suffix - Grip.Of The Dervish', 'Mods.Hammer.Suffix - Grip.Of Deathbane', 'Mods.Hammer.Suffix - Grip.Of Charrslaying'
			Return True
		Case 'Mods.Hammer.Suffix - Grip.Of Trollslaying', 'Mods.Hammer.Suffix - Grip.Of Pruning', 'Mods.Hammer.Suffix - Grip.Of Skeleton Slaying', 'Mods.Hammer.Suffix - Grip.Of Giant Slaying', 'Mods.Hammer.Suffix - Grip.Of Dwarf Slaying', 'Mods.Hammer.Suffix - Grip.Of Tengu Slaying'
			Return True
		Case 'Mods.Hammer.Suffix - Grip.Of Demon Slaying', 'Mods.Hammer.Suffix - Grip.Of Ogre Slaying', 'Mods.Hammer.Suffix - Grip.Of Dragon Slaying', 'Mods.Hammer.Suffix - Grip.Of Hammer Mastery (Item''s attribute +1 - 20% chance while using skills)', 'Mods.Scythe.Prefix - Snathe.Ebon (Earth damage)', 'Mods.Scythe.Prefix - Snathe.Fiery (Fire damage)'
			Return True
		Case 'Mods.Scythe.Prefix - Snathe.Icy (Cold damage)', 'Mods.Scythe.Prefix - Snathe.Shocking (Lightning damage)', 'Mods.Scythe.Prefix - Snathe.Barbed (Lengthens Bleeding duration on foes by 33%)', 'Mods.Scythe.Prefix - Snathe.Cruel (Lengthens Deep Wound duration on foes by 33%)', 'Mods.Scythe.Prefix - Snathe.Crippling (Lengthens Crippled duration on foes by 33%)', 'Mods.Scythe.Prefix - Snathe.Heavy (Lengthens Weakness duration on foes by 33%)'
			Return True
		Case 'Mods.Scythe.Prefix - Snathe.Poisonous (Lengthens Poison duration on foes by 33%)', 'Mods.Scythe.Prefix - Snathe.Furious (Double Adrenaline on hit - Chance 10%)', 'Mods.Scythe.Prefix - Snathe.Sundering (Armor penetration +20% - Chance 20%)', 'Mods.Scythe.Prefix - Snathe.Vampiric 5 (Life Draining 5 Health regeneration -1)', 'Mods.Scythe.Prefix - Snathe.Zealous (Energy gain on hit: 1 Energy regeneration: -1)', 'Mods.Scythe.Suffix - Grip.of Fortitude (Health +30)'
			Return True
		Case 'Mods.Scythe.Suffix - Grip.Of Defense (Armor +5)', 'Mods.Scythe.Suffix - Grip.Of Shelter (Armor +7 vs physical damage)', 'Mods.Scythe.Suffix - Grip.Of Warding (Armor +7 vs elemental damage)', 'Mods.Scythe.Suffix - Grip.Of Enchanting (Enchantments last 20% longer)', 'Mods.Scythe.Suffix - Grip.Of The Warrior', 'Mods.Scythe.Suffix - Grip.Of The Ranger'
			Return True
		Case 'Mods.Scythe.Suffix - Grip.Of The Necromancer', 'Mods.Scythe.Suffix - Grip.Of The Mesmer', 'Mods.Scythe.Suffix - Grip.Of The Elementalist', 'Mods.Scythe.Suffix - Grip.Of The Monk', 'Mods.Scythe.Suffix - Grip.Of The Ritualist', 'Mods.Scythe.Suffix - Grip.Of The Assassin'
			Return True
		Case 'Mods.Scythe.Suffix - Grip.Of The Paragon', 'Mods.Scythe.Suffix - Grip.Of The Dervish', 'Mods.Scythe.Suffix - Grip.Of Scythe Mastery (Item''s attribute +1 - 20% chance while using skills)', 'Mods.Shield.Suffix - Handle.of Fortitude (Health +30)', 'Mods.Shield.Suffix - Handle.Of Devotion (Health +45 while Enchanted)', 'Mods.Shield.Suffix - Handle.Of Endurance (Health +45 while in a Stance)'
			Return True
		Case 'Mods.Shield.Suffix - Handle.Of Valor (Health +60 while Hexed)', 'Mods.Spear.Prefix - Head.Ebon (Earth damage)', 'Mods.Spear.Prefix - Head.Fiery (Fire damage)', 'Mods.Spear.Prefix - Head.Icy (Cold damage)', 'Mods.Spear.Prefix - Head.Shocking (Lightning damage)', 'Mods.Spear.Prefix - Head.Barbed (Lengthens Bleeding duration on foes by 33%)'
			Return True
		Case 'Mods.Spear.Prefix - Head.Cruel (Lengthens Deep Wound duration on foes by 33%)', 'Mods.Spear.Prefix - Head.Crippling (Lengthens Crippled duration on foes by 33%)', 'Mods.Spear.Prefix - Head.Heavy (Lengthens Weakness duration on foes by 33%)', 'Mods.Spear.Prefix - Head.Poisonous (Lengthens Poison duration on foes by 33%)', 'Mods.Spear.Prefix - Head.Silencing (Lengthens Dazed duration on foes by 33%)', 'Mods.Spear.Prefix - Head.Furious (Double Adrenaline on hit - Chance 10%)'
			Return True
		Case 'Mods.Spear.Prefix - Head.Sundering (Armor penetration +20% - Chance 20%)', 'Mods.Spear.Prefix - Head.Vampiric 3 (Life Draining 3 Health regeneration -1)', 'Mods.Spear.Prefix - Head.Zealous (Energy gain on hit: 1 Energy regeneration: -1)', 'Mods.Spear.Suffix - Grip.of Fortitude (Health +30)', 'Mods.Spear.Suffix - Grip.Of Defense (Armor +5)', 'Mods.Spear.Suffix - Grip.Of Shelter (Armor +7 vs physical damage)'
			Return True
		Case 'Mods.Spear.Suffix - Grip.Of Warding (Armor +7 vs elemental damage)', 'Mods.Spear.Suffix - Grip.Of Enchanting (Enchantments last 20% longer)', 'Mods.Spear.Suffix - Grip.Of The Warrior', 'Mods.Spear.Suffix - Grip.Of The Ranger', 'Mods.Spear.Suffix - Grip.Of The Necromancer', 'Mods.Spear.Suffix - Grip.Of The Mesmer'
			Return True
		Case 'Mods.Spear.Suffix - Grip.Of The Elementalist', 'Mods.Spear.Suffix - Grip.Of The Monk', 'Mods.Spear.Suffix - Grip.Of The Ritualist', 'Mods.Spear.Suffix - Grip.Of The Assassin', 'Mods.Spear.Suffix - Grip.Of The Paragon', 'Mods.Spear.Suffix - Grip.Of The Dervish'
			Return True
		Case 'Mods.Spear.Suffix - Grip.Of Spear Mastery (Item''s attribute +1 - 20% chance while using skills)', 'Mods.Staff.Prefix - Head.Hale (Health +30)', 'Mods.Staff.Prefix - Head.Adept (Halves casting time of spells of item''s attribute - Chance 20%)', 'Mods.Staff.Prefix - Head.Swift (Halves casting time of spells - Chance 10%)', 'Mods.Staff.Prefix - Head.Insightful (Energy +5)', 'Mods.Staff.Prefix - Head.Defensive (Armor +5)'
			Return True
		Case 'Mods.Staff.Suffix - Wrapping.of Fortitude (Health +30)', 'Mods.Staff.Suffix - Wrapping.Of Defense (Armor +5)', 'Mods.Staff.Suffix - Wrapping.Of Shelter (Armor +7 vs physical damage)', 'Mods.Staff.Suffix - Wrapping.Of Warding (Armor +7 vs elemental damage)', 'Mods.Staff.Suffix - Wrapping.Of Enchanting (Enchantments last 20% longer)', 'Mods.Staff.Suffix - Wrapping.Of The Warrior'
			Return True
		Case 'Mods.Staff.Suffix - Wrapping.Of The Ranger', 'Mods.Staff.Suffix - Wrapping.Of The Necromancer', 'Mods.Staff.Suffix - Wrapping.Of The Mesmer', 'Mods.Staff.Suffix - Wrapping.Of The Elementalist', 'Mods.Staff.Suffix - Wrapping.Of The Monk', 'Mods.Staff.Suffix - Wrapping.Of The Ritualist'
			Return True
		Case 'Mods.Staff.Suffix - Wrapping.Of The Assassin', 'Mods.Staff.Suffix - Wrapping.Of The Paragon', 'Mods.Staff.Suffix - Wrapping.Of The Dervish', 'Mods.Staff.Suffix - Wrapping.Of Deathbane', 'Mods.Staff.Suffix - Wrapping.Of Charrslaying', 'Mods.Staff.Suffix - Wrapping.Of Trollslaying'
			Return True
		Case 'Mods.Staff.Suffix - Wrapping.Of Pruning', 'Mods.Staff.Suffix - Wrapping.Of Skeleton Slaying', 'Mods.Staff.Suffix - Wrapping.Of Giant Slaying', 'Mods.Staff.Suffix - Wrapping.Of Dwarf Slaying', 'Mods.Staff.Suffix - Wrapping.Of Tengu Slaying', 'Mods.Staff.Suffix - Wrapping.Of Demon Slaying'
			Return True
		Case 'Mods.Staff.Suffix - Wrapping.Of Ogre Slaying', 'Mods.Staff.Suffix - Wrapping.Of Dragon Slaying', 'Mods.Staff.Suffix - Wrapping.Of Mastery (Item''s attribute +1 - 20% chance while using skills)', 'Mods.Staff.Suffix - Wrapping.Of Devotion (Health +45 while Enchanted)', 'Mods.Staff.Suffix - Wrapping.Of Endurance (Health +45 while in a Stance)', 'Mods.Staff.Suffix - Wrapping.Of Valor (Health +60 while Hexed)'
			Return True
		Case 'Mods.Sword.Prefix - Hilt.Ebon (Earth damage)', 'Mods.Sword.Prefix - Hilt.Fiery (Fire damage)', 'Mods.Sword.Prefix - Hilt.Icy (Cold damage)', 'Mods.Sword.Prefix - Hilt.Shocking (Lightning damage)', 'Mods.Sword.Prefix - Hilt.Barbed (Lengthens Bleeding duration on foes by 33%)', 'Mods.Sword.Prefix - Hilt.Cruel (Lengthens Deep Wound duration on foes by 33%)'
			Return True
		Case 'Mods.Sword.Prefix - Hilt.Crippling (Lengthens Crippled duration on foes by 33%)', 'Mods.Sword.Prefix - Hilt.Poisonous (Lengthens Poison duration on foes by 33%)', 'Mods.Sword.Prefix - Hilt.Furious (Double Adrenaline on hit - Chance 10%)', 'Mods.Sword.Prefix - Hilt.Sundering (Armor penetration +20% - Chance 20%)', 'Mods.Sword.Prefix - Hilt.Vampiric 3 (Life Draining 3 Health regeneration -1)', 'Mods.Sword.Prefix - Hilt.Zealous (Energy gain on hit: 1 Energy regeneration: -1)'
			Return True
		Case 'Mods.Sword.Suffix - Pommel.of Fortitude (Health +30)', 'Mods.Sword.Suffix - Pommel.Of Defense (Armor +5)', 'Mods.Sword.Suffix - Pommel.Of Shelter (Armor +7 vs physical damage)', 'Mods.Sword.Suffix - Pommel.Of Warding (Armor +7 vs elemental damage)', 'Mods.Sword.Suffix - Pommel.Of Enchanting (Enchantments last 20% longer)', 'Mods.Sword.Suffix - Pommel.Of The Warrior'
			Return True
		Case 'Mods.Sword.Suffix - Pommel.Of The Ranger', 'Mods.Sword.Suffix - Pommel.Of The Necromancer', 'Mods.Sword.Suffix - Pommel.Of The Mesmer', 'Mods.Sword.Suffix - Pommel.Of The Elementalist', 'Mods.Sword.Suffix - Pommel.Of The Monk', 'Mods.Sword.Suffix - Pommel.Of The Ritualist'
			Return True
		Case 'Mods.Sword.Suffix - Pommel.Of The Assassin', 'Mods.Sword.Suffix - Pommel.Of The Paragon', 'Mods.Sword.Suffix - Pommel.Of The Dervish', 'Mods.Sword.Suffix - Pommel.Of Deathbane', 'Mods.Sword.Suffix - Pommel.Of Charrslaying', 'Mods.Sword.Suffix - Pommel.Of Trollslaying'
			Return True
		Case 'Mods.Sword.Suffix - Pommel.Of Pruning', 'Mods.Sword.Suffix - Pommel.Of Skeleton Slaying', 'Mods.Sword.Suffix - Pommel.Of Giant Slaying', 'Mods.Sword.Suffix - Pommel.Of Dwarf Slaying', 'Mods.Sword.Suffix - Pommel.Of Tengu Slaying', 'Mods.Sword.Suffix - Pommel.Of Demon Slaying'
			Return True
		Case 'Mods.Sword.Suffix - Pommel.Of Ogre Slaying', 'Mods.Sword.Suffix - Pommel.Of Dragon Slaying', 'Mods.Sword.Suffix - Pommel.Of Swordmanship (Item''s attribute +1 - 20% chance while using skills)', 'Mods.Wand.Suffix - Wrapping.Of Memory (Halves skill recharge of item''s attribute spells - Chance 20%)', 'Mods.Wand.Suffix - Wrapping.Of Quickening (Halves skill recharge of spells - Chance 10%)', 'Mods.Wand.Suffix - Wrapping.Of The Warrior'
			Return True
		Case 'Mods.Wand.Suffix - Wrapping.Of The Ranger', 'Mods.Wand.Suffix - Wrapping.Of The Necromancer', 'Mods.Wand.Suffix - Wrapping.Of The Mesmer', 'Mods.Wand.Suffix - Wrapping.Of The Elementalist', 'Mods.Wand.Suffix - Wrapping.Of The Monk', 'Mods.Wand.Suffix - Wrapping.Of The Ritualist'
			Return True
		Case 'Mods.Wand.Suffix - Wrapping.Of The Assassin', 'Mods.Wand.Suffix - Wrapping.Of The Paragon', 'Mods.Wand.Suffix - Wrapping.Of The Dervish'
			Return True
	EndSwitch
	Return False
EndFunc
#EndRegion Perfect-roll extraction



;~ Counts dwords of the hex modstruct whose identifier (chars 5-8 of the dword) equals the given 4 hex chars (e.g. '3025', '3225', '0824')
Func CountModStructIdentifier($hex, $identifierHex)
	Local $count = 0
	For $i = 1 To StringLen($hex) - 7 Step 8
		If StringMid($hex, $i + 4, 4) == $identifierHex Then $count += 1
	Next
	Return $count
EndFunc
#EndRegion Upgrade leaf definitions
