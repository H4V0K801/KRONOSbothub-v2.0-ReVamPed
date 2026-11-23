#include '../LoadWaitHelpers.au3'
#CS ===========================================================================
; Author: caustic-kronos (aka Kronos, Night, Svarog)
; Contributor: Gahais
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
#include '../../lib/GWA2_ID_Maps.au3'
#include '../../lib/GWA2_ID_Skills.au3'
#include '../../lib/GWA2_ID.au3'
#include '../../lib/GWA2.au3'
#include '../../lib/Utils-Agents.au3'
#include '../../lib/Utils-Console.au3'
#include '../../lib/Utils-Storage.au3'
#include '../../lib/Utils.au3'

; Possible improvements :
; - Correct a crash happening when someone picks up items the bot wanted to pick up
; - speed up the bot by all ways possible (since it casts shouts it is always lagging behind)
;		- using a cupcake and a pumpkin pie might be a good idea


; ==== Constants ====
Global Const $FOLLOWER_INFORMATIONS = 'This bot makes your character follow the first other player in party.' & @CRLF _
	& 'It will attack everything that gets in range.' & @CRLF _
	& 'It will loot all items it can loot.' & @CRLF _
	& 'It will also loot all chests in range.'

Global Const $FOLLOWER_LEASH_RANGE = $RANGE_SPELLCAST - 200

Global $optionsFollower					= CloneMap($default_move_aggro_kill_options)
$optionsFollower['fightRange']			= $MOB_AGGRO_RANGE
$optionsFollower['callTarget']			= False
$optionsFollower['priorityTargeting']	= False
$optionsFollower['skillsCostMap']		= Null
;$optionsFollower['skillsCastTimeMap']	= Null
$optionsFollower['lootInCombat']		= False
$optionsFollower['openChests']			= True
$optionsFollower['followLeaderTarget']	= True
$optionsFollower['chestOpenRange']		= $MOB_AGGRO_RANGE
$optionsFollower['killMethod']			= UseSkillSequentially
$optionsFollower['abortCondition']		= FollowerNotInRangeOfLeader

Global $leaderID = Null
; v38.4: last typed name reported as not found (one warning per name)
Global $follower_leader_not_found_logged = ''
; v38.4: typed name (trimmed) the current $leaderID was resolved for
Global $follower_leader_resolved_name = ''
; v38.7: party names read on the last resolve (for the log)
Global $follower_party_names_read = ''

;~ Main loop
Func FollowerFarm()
	While $runtime_status == 'RUNNING'
		FollowerLoop()
	WEnd
	Return $runtime_status <> 'RUNNING' ? $PAUSE : $SUCCESS
EndFunc


;~ Follower loop
Func FollowerLoop($options = $optionsFollower)
	; Sync GUI options if available
	If MapExists($run_options_cache, 'follower.open_chests') Then $options['openChests'] = $run_options_cache['follower.open_chests']
	; GUI writes follower.leader_target; accept legacy follower.follow_leader_target too
	If MapExists($run_options_cache, 'follower.leader_target') Then $options['followLeaderTarget'] = $run_options_cache['follower.leader_target']
	If MapExists($run_options_cache, 'follower.follow_leader_target') Then $options['followLeaderTarget'] = $run_options_cache['follower.follow_leader_target']
	Local $permaSF = MapExists($run_options_cache, 'follower.perma_sf') And $run_options_cache['follower.perma_sf']
	If MapExists($run_options_cache, 'follower.leash') And Number($run_options_cache['follower.leash']) > 0 Then
		$options['leashRange'] = Number($run_options_cache['follower.leash'])
	EndIf
	Local Static $currentMap = Null, $resigned = False

	; Map change detection (even in outposts !)
	Local $mapID = GetMapID()
	If $mapID <> $currentMap Then
		$currentMap = $mapID
		$leaderID = Null
		$resigned = False
		SkipCinematic()
		RobustWaitMapLoading($mapID)
	EndIf

	; If map is not explorable, no following happening
	If GetMapType() <> $ID_EXPLORABLE Then
		Sleep(1000)
		Return
	EndIf

	; v38.4: drop a stale leader (agent gone, or the typed name changed / no longer matches) so it is resolved again
	If $leaderID <> Null And Not FollowerLeaderStillValid($leaderID) Then $leaderID = Null
	; Resolving leaderID if needed
	If $leaderID == Null Then $leaderID = FollowerResolveLeaderID()
	; If no leader found, wait, try next time
	If $leaderID == Null Then
		Sleep(1000)
		Return
	EndIf

	; Auto resigning
	If Not $resigned Then
		Info('Auto-resigning on explorable entry')
		Resign()
		$resigned = True
		RandomSleep(500)
	EndIf

	; Maintain Shadow Form if Perma SF option is enabled
	If $permaSF Then FollowerMaintainShadowForm()

	; Could set a run function to speed up team/follower
	If $options['runFunction'] <> Null Then $options['runFunction']()

	; Getting leader and moving to him
	Local $leader = GetAgentByID($leaderID)
	Local $me = GetMyAgent()

	; Trigger fight only if extremely close to leader - but leave fight if leader is far away
	If GetEnergy() < 5 Then Sleep(200)
	If FollowerInRangeOfLeader($leader, $me, $RANGE_NEARBY) Then
		Local $fightRange			= $options['fightRange'] <> Null ?			$options['fightRange'] : $WIDE_PLAYER_AGGRO_RANGE
		Local $fightHandler			= $options['fightHandler'] <> Null ?		$options['fightHandler'] : KillFoesInArea
		Local $unstuckHandler		= $options['unstuckHandler'] <> Null ?		$options['unstuckHandler'] : TryToGetUnstuck
		Local $openChests			= $options['openChests'] <> Null ?			$options['openChests'] : False
		Local $chestOpenRange		= $options['chestOpenRange'] <> Null ?		$options['chestOpenRange'] : $RANGE_SPIRIT

		Local $target = Null
		If $options['followLeaderTarget'] Then
			Local $leaderTargetID = DllStructGetData($leader, 'TargetID')
			If $leaderTargetID <> 0 Then
				$target = GetAgentByID($leaderTargetID)
				Sleep(50)
			EndIf
		EndIf
		If $target == Null Or DllStructGetData($target, 'ID') == 0 Then
			$target = GetNearestEnemyToAgent($me)
		EndIf
		If DllStructGetData($target, 'ID') <> 0 And GetDistance($me, $target) < $fightRange Then
			; No checks required on failure - follower just follows
			$fightHandler($options)
			; FIXME: add rezzing dead party members here

			; Refresh leader if fight happened
			$leader = GetAgentByID($leaderID)
		EndIf

		; Chest part
		If $openChests Then
			Local $chest = FindChest($chestOpenRange)
			If $chest <> Null Then
				FindAndOpenChests($chestOpenRange)

				; Refresh leader if chest opening happened
				$leader = GetAgentByID($leaderID)
			EndIf
		EndIf

		; Loot part
		PickUpItems(Null, DefaultShouldPickItem, $MOB_AGGRO_RANGE)
	EndIf

	GoPlayer($leader)
	Sleep(1000)
EndFunc


Func FollowerMaintainShadowForm()
	; Find Shadow Form on the skillbar and keep it up
	Local $sfSlot = 0
	For $slot = 1 To 8
		If GetSkillbarSkillID($slot) == $ID_SHADOW_FORM Then
			$sfSlot = $slot
			ExitLoop
		EndIf
	Next
	If $sfSlot == 0 Then Return
	; v20: original timing back - only once Shadow Form has dropped, SF recharged, 5 energy. Kept from v18: Deadly Paradox
	; first if it is on the bar (and only with 20 energy)
	If GetEffect($ID_SHADOW_FORM) <> Null Then Return
	If Not IsRecharged($sfSlot) Then Return
	If GetEnergy() < $SF_ENERGY_COST Then Return
	CastShadowFormPair(FindSkillSlot($ID_DEADLY_PARADOX), $sfSlot, $SF_ENERGY_COST)
	Sleep(50)
EndFunc


Func FollowerNotInRangeOfLeader()
	Local $range = $FOLLOWER_LEASH_RANGE
	If MapExists($run_options_cache, 'follower.leash') And Number($run_options_cache['follower.leash']) > 0 Then
		$range = Number($run_options_cache['follower.leash'])
	EndIf
	Return Not FollowerInRangeOfLeader(GetAgentByID($leaderID), GetMyAgent(), $range)
EndFunc


Func FollowerInRangeOfLeader($leader = GetAgentByID($leaderID), $me = GetMyAgent(), $range = $FOLLOWER_LEASH_RANGE)
	Return $leader == Null Or GetDistance($me, $leader) < $range
EndFunc


;~ Resolve the agent struct of leader by reading the agent ID directly out of the player record array.
;~ Works in both outposts and explorables. Bypasses the lib GetFirstPlayerOfParty, which fails in
;~ outposts because party agent structs report LoginNumber=0 there.
;~ Player records are 80 bytes wide; agent ID is at offset 0 of each record.
;~ v38.4: a typed name is trimmed and compared exactly (case-sensitive, full name, never a substring) with each other
;~ player's real name read by GetPlayerName() - the agent struct has no 'Name' field, so the old StringInStr check never
;~ matched and the bot always fell back to the first other player. The bot's own character is skipped. A typed name that
;~ is not in the party returns Null (the loop waits) instead of following someone else. Blank name: fallback unchanged.
Func FollowerResolveLeaderID()
	Local $me = GetMyAgent()
	Local $myID = DllStructGetData($me, 'ID')
	Local $myLoginNumber = DllStructGetData($me, 'LoginNumber')
	Local $partyMembers = GetParty()
	Local $namedLeader = FollowerTypedLeaderName()
	$follower_leader_resolved_name = $namedLeader
	; If a name is typed, only that exact party member may be followed
	If $namedLeader <> '' Then
		; v38.7: every player name read is listed in the log, so a name that does not match can be seen as read
		Local $namesRead = '', $heroesSkipped = 0, $found = Null, $foundLogin = 0
		For $member In $partyMembers
			Local $memberLogin = DllStructGetData($member, 'LoginNumber')
			Local $memberID = DllStructGetData($member, 'ID')
			; heroes / henchmen have no player record (and no player name)
			If $memberLogin <= 0 Then
				$heroesSkipped += 1
				ContinueLoop
			EndIf
			Local $isSelf = $memberLogin == $myLoginNumber Or $memberID == $myID
			Local $readName = FollowerReadPlayerName($member)
			$namesRead &= ($namesRead == '' ? '' : ', ') & '"' & $readName & '" (login ' & $memberLogin & ($isSelf ? ', you' : '') & ')'
			If $isSelf Or $found <> Null Then ContinueLoop
			If FollowerNameMatches($readName, $namedLeader) Then
				$found = $memberID
				$foundLogin = $memberLogin
			EndIf
		Next
		$follower_party_names_read = $namesRead & ($heroesSkipped > 0 ? '; ' & $heroesSkipped & ' hero/henchman skipped' : '')
		If $found <> Null Then
			FollowerNoteLeaderFound($namedLeader, $foundLogin, $found)
			Return $found
		EndIf
		FollowerNoteLeaderNotFound($namedLeader)
		Return Null
	EndIf
	; Fall back to first other party member (party leader)
	For $member In $partyMembers
		Local $loginNumber = DllStructGetData($member, 'LoginNumber')
		If $loginNumber <= 0 Then ContinueLoop
		If $loginNumber == $myLoginNumber Then ContinueLoop
		Return DllStructGetData($member, 'ID')
	Next
	Return Null
EndFunc


;~ v38.4: leader name typed in the Follower tab, trimmed. Live GUI value when the GUI exists, saved configuration value
;~ otherwise (headless mode has no controls)
Func FollowerTypedLeaderName()
	Local $namedLeader = MapExists($run_options_cache, 'follower.name') ? $run_options_cache['follower.name'] : ''
	If $gui_enabled Then $namedLeader = GUICtrlRead($gui_input_follower_name)
	Return StringStripWS(String($namedLeader), 3)
EndFunc


;~ v38.4: exact, case-sensitive, full-name comparison ('Charname' matches 'Charname' only - not 'Charname Il', 'charname' or 'Charname V')
Func FollowerNameMatches($playerName, $typedName)
	If $typedName == '' Then Return False
	Return StringCompare(String($playerName), String($typedName), 1) == 0
EndFunc


;~ v38.4: True while $id is still the right leader: the agent still exists and, when a name is typed, that agent's real
;~ name is still exactly the typed name. A blank name keeps the fallback leader until its agent is gone, but typing a
;~ name (or changing it) mid-run makes the leader resolve again.
Func FollowerLeaderStillValid($id)
	Local $namedLeader = FollowerTypedLeaderName()
	; the typed name changed since the leader was resolved
	If Not ($follower_leader_resolved_name == $namedLeader) Then Return False
	Local $leader = GetAgentByID($id)
	; agent gone
	If $id == 0 Or DllStructGetData($leader, 'ID') <> $id Then Return False
	If $namedLeader == '' Then Return True
	Return FollowerNameMatches(FollowerReadPlayerName($leader), $namedLeader)
EndFunc


;~ v38.7: a party member's real name (GetPlayerName via its login number), as text, outer whitespace / nulls removed
Func FollowerReadPlayerName($agent)
	Local $name = GetPlayerName($agent)
	If Not IsString($name) Then Return ''
	Return StringStripWS(StringReplace($name, Chr(0), ''), 3)
EndFunc


;~ v38.4: the typed name was not found in the party - log once per name (v38.7: and per set of names read, which are
;~ listed), then keep waiting silently
Func FollowerNoteLeaderNotFound($namedLeader)
	Local $key = $namedLeader & '|' & $follower_party_names_read
	If $follower_leader_not_found_logged == $key Then Return
	$follower_leader_not_found_logged = $key
	Warn('Follower: no party member is named exactly "' & $namedLeader & '" - waiting (not following anyone else). Party names read: ' _
		& ($follower_party_names_read == '' ? '(none)' : $follower_party_names_read))
EndFunc


;~ v38.4: the typed name was found - allow the not-found warning again later (v38.7: always logged, once per resolve)
Func FollowerNoteLeaderFound($namedLeader, $loginNumber = 0, $agentID = 0)
	$follower_leader_not_found_logged = ''
	Info('Follower: following "' & $namedLeader & '" (login ' & $loginNumber & ', agent ' & $agentID & '). Party names read: ' & $follower_party_names_read)
EndFunc
