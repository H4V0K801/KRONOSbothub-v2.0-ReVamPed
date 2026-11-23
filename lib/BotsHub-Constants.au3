#CS ===========================================================================
; BotsHub - central tuning constants for reliability / recovery behaviour.
; Every timeout and retry limit introduced by the hardening pass lives here so it
; can be tuned in one place. Values are in milliseconds unless stated otherwise.
; This file has no dependencies and may be included from anywhere.
#CE ===========================================================================

#include-once

#Region Movement and interaction timeouts
; MoveTo() gives up after max(this, 3x the unboosted walking time to the target)
Global Const $MOVE_TO_MIN_TIMEOUT			= 45000
; Max time spent walking up to an agent / NPC (GoToAgent, GoNearestNPCToCoords)
Global Const $GO_TO_AGENT_TIMEOUT			= 30000
; Max time waiting for an NPC to appear near given coordinates
Global Const $NPC_APPEAR_TIMEOUT			= 10000
; Max time trying to pull one foe with AggroAgent()
Global Const $AGGRO_AGENT_TIMEOUT			= 20000
#EndRegion Movement and interaction timeouts

#Region Combat
; Max time UseSkillSequentially() spends on a single target before re-targeting
Global Const $KILL_TARGET_TIMEOUT			= 60000
; Max time a farm keeps re-casting one skill waiting for it to go on recharge
Global Const $SKILL_SPAM_TIMEOUT			= 10000
; Max time a farm waits for one skill to come off recharge (longest farm recharges are ~60s) (ms)
Global Const $SKILL_RECHARGE_WAIT_TIMEOUT	= 90000
#EndRegion Combat

#Region Map travel and loading
; How many times a farm walks into a portal before giving up on the run (count)
Global Const $MAP_ENTRY_MAX_ATTEMPTS		= 5
; How many times a farm setup run (walk to dungeon/zone) is retried (count)
Global Const $SETUP_MAX_ATTEMPTS			= 3
; Map-load wait for same-map-ID transitions: an instance younger than this counts as freshly loaded
Global Const $NEW_INSTANCE_FRESH_MS			= 5000
; Max time waiting for a new instance to start loading on same-map-ID transitions
Global Const $NEW_INSTANCE_START_TIMEOUT	= 20000
#EndRegion Map travel and loading

#Region Session watchdog
; v24: the 'pause after 10 failed runs in a row' rule was removed (AMG); stuck runs: Utils-StuckWatchdog.au3
; Hard per-run deadline used by IsRunFailed(): max(expected farm duration x factor, minimum) (ms)
Global Const $RUN_DEADLINE_FACTOR			= 4
Global Const $RUN_DEADLINE_MIN				= 30 * 60 * 1000
#EndRegion Session watchdog

#Region Logging
; Rich-edit console is trimmed when it grows beyond this many characters (keeps long sessions responsive)
Global Const $LOG_CONSOLE_MAX_CHARS			= 400000
; Characters removed from the top of the console when trimming
Global Const $LOG_CONSOLE_TRIM_CHARS		= 100000
#EndRegion Logging
