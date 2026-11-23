; Build Info tab (v34): display-only builds and notes for the selected farm.
; Generated from tools/out/v34_buildinfo_inventory.json + tools/buildinfo/notes_additions.json.
; Does not change any template a farm loads or any farm logic.
#include-once
#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <WindowsConstants.au3>

Global Const $BUILDINFO_MAX_ROWS = 16
Global Const $BUILDINFO_EMPTY_TITLE = 'Select a farm to see its builds'
Global Const $BUILDINFO_EMPTY_HINT = 'Use the farm list at the bottom left: its builds, hero builds and farm notes appear here right away.'

Global $buildinfo_title = ''
Global $buildinfo_summary = ''
Global $buildinfo_caption = ''
Global $buildinfo_notes = ''
Global $buildinfo_rowcount = 0
Global $buildinfo_role[$BUILDINFO_MAX_ROWS]
Global $buildinfo_prof[$BUILDINFO_MAX_ROWS]
Global $buildinfo_code[$BUILDINFO_MAX_ROWS]
Global $buildinfo_attrs[$BUILDINFO_MAX_ROWS]

Global $gui_buildinfo_ready = False
Global $gui_buildinfo_empty1, $gui_buildinfo_empty2
Global $gui_buildinfo_title, $gui_buildinfo_summary
Global $gui_buildinfo_h_build, $gui_buildinfo_h_prof, $gui_buildinfo_h_code, $gui_buildinfo_h_attrs, $gui_buildinfo_hline
Global $gui_buildinfo_role[$BUILDINFO_MAX_ROWS]
Global $gui_buildinfo_proflbl[$BUILDINFO_MAX_ROWS]
Global $gui_buildinfo_codeedit[$BUILDINFO_MAX_ROWS]
Global $gui_buildinfo_attrslbl[$BUILDINFO_MAX_ROWS]
Global $gui_buildinfo_caption, $gui_buildinfo_notes_title, $gui_buildinfo_notes_line, $gui_buildinfo_notes


Func BuildInfoIsEmptySelection($farm)
	Return $farm == '' Or $farm == 'Choose a farm' Or $farm == Null
EndFunc


Func BuildInfoClear()
	$buildinfo_title = ''
	$buildinfo_summary = ''
	$buildinfo_caption = ''
	$buildinfo_notes = ''
	$buildinfo_rowcount = 0
EndFunc


Func BuildInfoAddRow($role, $prof, $code, $attrs)
	If $buildinfo_rowcount >= $BUILDINFO_MAX_ROWS Then Return
	$buildinfo_role[$buildinfo_rowcount] = $role
	$buildinfo_prof[$buildinfo_rowcount] = $prof
	$buildinfo_code[$buildinfo_rowcount] = $code
	$buildinfo_attrs[$buildinfo_rowcount] = $attrs
	$buildinfo_rowcount += 1
EndFunc


Func BuildInfoNotesHaveLink($text)
	If $text == '' Then Return False
	If StringRegExp($text, '(?i)https?://') Then Return True
	If StringInStr($text, 'gwpvx.fandom.com') > 0 Then Return True
	Return False
EndFunc

;~ Fill the module-level row/notes fields for $farm. Returns False for the empty selection.
Func BuildInfoLoad($farm)
	BuildInfoClear()
	If BuildInfoIsEmptySelection($farm) Then Return False
	Switch $farm
		Case 'Asuran'
			$buildinfo_title = 'ASURAN - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = 'Asuran title farm, bring solid heroes composition' & @CRLF & _
			'Area: Magus Stones (Asura title)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'Boreal'
			$buildinfo_title = 'BOREAL - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  No heroes'
			$buildinfo_caption = 'One build per profession: the bot loads the row matching your primary profession when it has one.'
			$buildinfo_notes = 'Must have skills: Dash, Dwarven Stability, I am Unstoppable' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- dwarves rank 5 minimum' & @CRLF & _
			'- norn rank 5 minimum' & @CRLF & _
			'Must have skills: Dash, Dwarven Stability, I am Unstoppable' & @CRLF & _
			'Optional skills (for more survivability and unblocking): Shroud of Distress, Heart of Shadow, Deaths Charge'
			BuildInfoAddRow('Player', 'W/A', 'OQcT8ZPHHiHRn5A6ukmcCC3BBC', 'Shadow Arts 12, Deadly Arts 12, Strength 3')
			BuildInfoAddRow('Player', 'R/A', 'OgcT8ZPfHiHRn5A6ukmcCC3BBC', 'Shadow Arts 12, Deadly Arts 12, Expertise 3')
			BuildInfoAddRow('Player', 'Mo/A', 'OwcT8ZPDHiHRn5A6ukmcCC3BBC', 'Shadow Arts 12, Deadly Arts 12, Divine Favor 3')
			BuildInfoAddRow('Player', 'N/A', 'OAdTY4P7HiHRn5A6ukmcCC3BBC', 'Soul Reaping 12, Shadow Arts 12, Deadly Arts 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT8ZPDGiHRn5A6ukmcCC3BBC', 'Shadow Arts 12, Deadly Arts 12, Fast Casting 3')
			BuildInfoAddRow('Player', 'E/A', 'OgdT8Z/wYiHRn5A6ukmcCC3BBC', 'Shadow Arts 12, Deadly Arts 3, Energy Storage 12')
			BuildInfoAddRow('Player', 'A/X', 'OwBj8xe84Q8I6MHQ3l0kTQ4OIQ', 'Shadow Arts 12, Deadly Arts 12, Critical Strikes 3')
			BuildInfoAddRow('Player', 'Rt/A', 'OAej8xeM5Q8I6MHQ3l0kTQ4OIQ', 'Shadow Arts 12, Deadly Arts 12, Spawning Power 3')
			BuildInfoAddRow('Player', 'P/A', 'OQej8xeM6Q8I6MHQ3l0kTQ4OIQ', 'Shadow Arts 12, Deadly Arts 12, Leadership 3')
			BuildInfoAddRow('Player', 'D/A', 'Ogej4NfMLTbXHYHQ3l0kTQ4OIQA', 'Deadly Arts 3, Shadow Arts 12, Mysticism 12')
			Return True
		Case 'CoF'
			$buildinfo_title = 'COF - BUILDS'
			$buildinfo_summary = 'Required primary: Dervish  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = '- This bot enters the Quest Temple of the Damned, but bot does not finish it' & @CRLF & _
			'- +1+3 Wind Prayers Rune' & @CRLF & _
			'- +1 Mystisicm Rune' & @CRLF & _
			'- +1 Scythe Mastery Runed' & @CRLF & _
			'- +50 HP Rune' & @CRLF & _
			'- +2 Energy Rune' & @CRLF & _
			'- Windwalker or blessed insignias' & @CRLF & _
			'- Zealous Scythe of Enchanting (20% longer enchantments duration) with a random inscription' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- +1+3 Wind Prayers Rune' & @CRLF & _
			'- +1 Mystisicm Rune' & @CRLF & _
			'- +1 Scythe Mastery Runed' & @CRLF & _
			'- +50 HP Rune' & @CRLF & _
			'- +2 Energy Rune' & @CRLF & _
			'- Windwalker or blessed insignias' & @CRLF & _
			'- Zealous Scythe of Enchanting (20% longer enchantments duration) with a random inscription' & @CRLF & _
			'- This bot enters the Quest Temple of the Damned, but bot does not finish it' & @CRLF & _
			'- This bot farms Golden Rin Relics and Diessa Chalices and bones in the Cathedral of Flames' & @CRLF & _
			'- If you do not have I Am Unstoppable skill then it is no problem, bot will still work, but the fail rate will increase slightly' & @CRLF & _
			'' & @CRLF & _
			'Equipment: 5x Windwalker Insignia, 1x Superior Vigor, 1x Vitae' & @CRLF & _
			'Weapon: Zealous Scythe of Enchanting with "Guided by Fate"' & @CRLF & _
			'Take the quest Temple of the Damned before entering the Cathedral of Flames' & @CRLF & _
			'Optional: the Dwarven Raider blessing from the Beacon of Droknar' & @CRLF & _
			'Equipment: 5x Windwalker Insignia, 1x Superior Vigor, 1x Vitae' & @CRLF & _
			'Weapon: Zealous Scythe of Enchanting with "Guided by Fate"' & @CRLF & _
			'Take the quest Temple of the Damned before entering the Cathedral of Flames' & @CRLF & _
			'Optional: the Dwarven Raider blessing from the Beacon of Droknar'
			BuildInfoAddRow('Player', 'D/X', 'OgCjkqqLrSihdftXYijhOXhX0kA', 'Scythe 10, Wind 11, Mysticism 10')
			Return True
		Case 'Corsairs'
			$buildinfo_title = 'CORSAIRS - BUILDS'
			$buildinfo_summary = 'Required primary: Ranger  |  Heroes: set up the 2 heroes yourself (Team tab)'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = '- Required hero for mission Dunkoro' & @CRLF & _
			'- A shield with the inscription Through Thick and Thin (+10 armor against Piercing damage)' & @CRLF & _
			'- A spear +5 energy +5 armor or +20% enchantment duration' & @CRLF & _
			'- Sentry or Blessed insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- 16 in Expertise' & @CRLF & _
			'- 12 in Shadow Arts' & @CRLF & _
			'- A shield with the inscription Through Thick and Thin (+10 armor against Piercing damage)' & @CRLF & _
			'- A spear +5 energy +5 armor or +20% enchantment duration' & @CRLF & _
			'- Sentry or Blessed insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'- Required hero for mission Dunkoro' & @CRLF & _
			'' & @CRLF & _
			'- A shield with the inscription Through Thick and Thin (+10 armor against Piercing damage)' & @CRLF & _
			'- Sentry or Blessed insignias on all the armor pieces' & @CRLF & _
			'Armor: full Blessed Insignias, 3x Vitae, highest Vigor rune possible' & @CRLF & _
			'Weapon: caster-modded one-handed weapon (+5 energy, +20% enchantment duration)' & @CRLF & _
			'Shield: +10 vs piercing damage with a Fortitude or Devotion mod' & @CRLF & _
			'Farmed in Hard Mode' & @CRLF & _
			'Armor: full Blessed Insignias, 3x Vitae, highest Vigor rune possible' & @CRLF & _
			'Weapon: caster-modded one-handed weapon (+5 energy, +20% enchantment duration)' & @CRLF & _
			'Shield: +10 vs piercing damage with a Fortitude or Devotion mod' & @CRLF & _
			'Farmed in Hard Mode'
			BuildInfoAddRow('Player', 'R/A', 'OgcSc5PT3lCHIQHQj1xlpZ4O', 'Expertise 12, Shadow Arts 12')
			BuildInfoAddRow('Hero 1', 'Mo/P', 'OwkjAlNpJP3Ya8HRmAAAAAAAA', 'Divine Favor 9, Healing 9, Command 12')
			BuildInfoAddRow('Hero 2', 'D/R', 'OgKjwOqMGPPn7LAAAAAAA+mhD', 'Mysticism 3, Wind 12, Wilderness Survival 12')
			Return True
		Case 'Deldrimor'
			$buildinfo_title = 'DELDRIMOR - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = '15-20mn average in HM with cons (automatically used if HM is on)' & @CRLF & _
			'You must have already completed the 4 map pieces and at least one' & @CRLF & _
			'For best results, do not cheap out on heroes' & @CRLF & _
			'I recommend using a range build to avoid pulling extra groups in crowded rooms' & @CRLF & _
			'Recommend two healer heroes. Tested with BIP + SOS Healer.' & @CRLF & _
			'10-15mn average in NM' & @CRLF & _
			'15-20mn average in HM with cons (automatically used if HM is on)' & @CRLF & _
			'You must have already completed the 4 map pieces and at least one' & @CRLF & _
			'Manual run of the Dungeon Prior to running this script' & @CRLF & _
			'15-20mn average in HM with cons (automatically used if HM is on)' & @CRLF & _
			'You must have already completed the 4 map pieces and at least one' & @CRLF & _
			'Area: Secret Lair of the Snowmen (Deldrimor title)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'Drake Flesh'
			$buildinfo_title = 'DRAKE FLESH - BUILDS'
			$buildinfo_summary = 'Required primary: Warrior  |  Heroes: set up the 1 heroes yourself (Team tab)'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = '- the quest Drakes on the Plain that makes the drakes show up (without it you cant farm)' & @CRLF & _
			'- 10 in Swordsmanship' & @CRLF & _
			'- A tactic shield +30 health with +10 armor against Dragons' & @CRLF & _
			'- A sword +5 energy +7 armor against physical damage' & @CRLF & _
			'- Knights insignias on all the armor pieces and a run of superior absorption' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- the quest Drakes on the Plain that makes the drakes show up (without it you cant farm)' & @CRLF & _
			'- 12 in Curses' & @CRLF & _
			'- 12 in Tactics' & @CRLF & _
			'- 10 in Swordsmanship' & @CRLF & _
			'- the rest in Strength' & @CRLF & _
			'- A tactic shield +30 health with +10 armor against Dragons' & @CRLF & _
			'- A sword +5 energy +7 armor against physical damage' & @CRLF & _
			'- Knights insignias on all the armor pieces and a run of superior absorption' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'- Knights insignias on all the armor pieces and a run of superior absorption'
			BuildInfoAddRow('Player', 'W/N', 'OQQUc4oQt6SWC0kqM9F5F5ija7gA', 'Curses 12, Strength 2, Swordsmanship 6, Tactics 11')
			BuildInfoAddRow('Hero 1', 'W/P', 'OQkiExm8Yivx6YWMAAAQiBAA', 'Strength 12, Command 12')
			Return True
		Case 'Dragon Moss'
			$buildinfo_title = 'DRAGON MOSS - BUILDS'
			$buildinfo_summary = 'Required primary: Ranger  |  Heroes: set up the 1 heroes yourself (Team tab)'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = '- the quest A New Escort that makes the dragon moss show up (without it you cant farm)' & @CRLF & _
			'- A shield of devotion (+45 health while enchanted) with the inscription Riders on the storm (+10 armor against Lightning damage)' & @CRLF & _
			'- A spear +5 energy +20% enchantment duration' & @CRLF & _
			'- Sentry or Blessed insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- the quest A New Escort that makes the dragon moss show up (without it you cant farm)' & @CRLF & _
			'- 16 in Expertise' & @CRLF & _
			'- 12 in Shadow Arts' & @CRLF & _
			'- 3 in Wilderness Survival' & @CRLF & _
			'- A shield of devotion (+45 health while enchanted) with the inscription Riders on the storm (+10 armor against Lightning damage)' & @CRLF & _
			'- A spear +5 energy +20% enchantment duration' & @CRLF & _
			'- Sentry or Blessed insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'- Sentry or Blessed insignias on all the armor pieces' & @CRLF & _
			'Equipment: full Blessed Insignias, Attunement runes, Spear/Axe/Sword of Enchanting (+5 energy), Shield of Fortitude (+10 armor vs piercing)' & @CRLF & _
			'The quest "A New Escort" is needed for the Dragon Mosses to spawn' & @CRLF & _
			'Equipment: full Blessed Insignias, Attunement runes, Spear/Axe/Sword of Enchanting (+5 energy), Shield of Fortitude (+10 armor vs piercing)' & @CRLF & _
			'The quest "A New Escort" is needed for the Dragon Mosses to spawn'
			BuildInfoAddRow('Player', 'R/A', 'OgcTcZ88Z6u844AiHRnhAC3R4AA', 'Expertise 12, Wilderness Survival 3, Shadow Arts 12')
			BuildInfoAddRow('Hero 1', 'R/P', 'OgkjYxYjJP8YAA9+GXjBAQnnDA', 'Beast 12, Wilderness Survival 3, Command 12')
			Return True
		Case 'Eden Iris'
			$buildinfo_title = 'EDEN IRIS - BUILDS'
			$buildinfo_summary = 'Any primary  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = 'Only thing needed for this farm is a character in Eden and Ashford Abbey unlocked.' & @CRLF & _
			'Area: Pre-Searing (Iris)'
			Return True
		Case 'Feathers'
			$buildinfo_title = 'FEATHERS - BUILDS'
			$buildinfo_summary = 'Required primary: Dervish  |  No heroes  |  Uses a city speed boost'
			$buildinfo_caption = ''
			$buildinfo_notes = '- 10 in Scythe Mastery' & @CRLF & _
			'- A scythe with +5 energy and +20% enchantment duration' & @CRLF & _
			'- Windwalker or Blessed insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- 16 in Earth Prayers' & @CRLF & _
			'- 10 in Scythe Mastery' & @CRLF & _
			'- 10 in Mysticism' & @CRLF & _
			'- A scythe with +5 energy and +20% enchantment duration' & @CRLF & _
			'- Windwalker or Blessed insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'- Windwalker or Blessed insignias on all the armor pieces'
			BuildInfoAddRow('Player', 'D/X', 'OgCjkmrMbS3ljbHY7XmXsXfbNXA', 'Scythe 9, Earth 12, Mysticism 9')
			Return True
		Case 'Follower'
			$buildinfo_title = 'FOLLOWER - BUILDS'
			$buildinfo_summary = 'Any primary  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = 'No checks required on failure - follower just follows' & @CRLF & _
			'This bot makes your character follow the first other player in party.' & @CRLF & _
			'It will attack everything that gets in range.' & @CRLF & _
			'It will loot all items it can loot.' & @CRLF & _
			'It will also loot all chests in range.' & @CRLF & _
			'- using a cupcake and a pumpkin pie might be a good idea'
			Return True
		Case 'Monk Bonder'
			$buildinfo_title = 'MONK BONDER'
			$buildinfo_summary = 'Any primary  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = 'Spam Burning Speed for energy if needed' & @CRLF & _
			'Monk bonder follower: maintain enchantments on the party leader and recover energy.' & @CRLF & _
			'No template code is shown here: the stored bar in the script is not a Monk bonder and is not loaded by this mode.'
			Return True
		Case 'EleMonk UW Bonder'
			$buildinfo_title = 'ELEMONK UW BONDER - BUILDS'
			$buildinfo_summary = 'Any primary  |  No heroes'
			$buildinfo_caption = 'Display only: this PvX template is not loaded by the bot.'
			$buildinfo_notes = 'Spam Burning Speed for energy if needed' & @CRLF & _
			'Ele/Monk UW Ether Prodigy bonder: maintain bonds on the party leader while keeping Ether Prodigy up.' & @CRLF & _
			'The template code above is the PvX E/Mo bar shown for reference only; the bot does not load it.'
			BuildInfoAddRow('Player', 'E/Mo', 'OgNDwcPPT1C3MaRkEyDxDHE0lA', 'Energy Storage 12, Healing 3, Protection 12')
			Return True
		Case 'FoW'
			$buildinfo_title = 'FOW - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = 'YYmn average in HM with consets (automatically used if HM is on)' & @CRLF & _
			'We have to send dialog here because quest is not ''complete'' in quest log' & @CRLF & _
			'For best results, do not cheap out on heroes' & @CRLF & _
			'I recommend using a range build to avoid pulling extra groups in crowded areas' & @CRLF & _
			'XXmn average in NM' & @CRLF & _
			'YYmn average in HM with consets (automatically used if HM is on)' & @CRLF & _
			'If you add a summon to this farm, do it so that it despawned once at forest of the wailing lord' & @CRLF & _
			'Drops: Obsidian Shards, Obsidian Edge, Shadow weapons'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'FoW Tower of Courage'
			$buildinfo_title = 'FOW TOWER OF COURAGE - BUILDS'
			$buildinfo_summary = 'Required primary: Ranger  |  Heroes: set up the 2 heroes yourself (Team tab)'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = 'This bot farms obsidian shards in Tower of Courage in Fissure of Woe location in normal mode.' & @CRLF & _
			'- Armor with HP/Energy runes and 5 blessed insignias (+50 armor when enchanted)' & @CRLF & _
			'- Spear/Sword/Axe +5 energy of Enchanting (20% longer enchantments duration)' & @CRLF & _
			'- A shield with the inscription Through Thick and Thin (+10 armor against piercing damage) and +45 health while enchanted or in stance' & @CRLF & _
			'If you have FoW scrolls then can set in GUI to enter FoW only through FoW scrolls and stop the bot when FoW scrolls run out' & @CRLF & _
			'Dark escape can be replaced by other skills like great dwarf armor to increase survivability at the cost of farm speed' & @CRLF & _
			'Longest bow range is around 1500' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- Armor with HP/Energy runes and 5 blessed insignias (+50 armor when enchanted)' & @CRLF & _
			'- Spear/Sword/Axe +5 energy of Enchanting (20% longer enchantments duration)' & @CRLF & _
			'- A shield with the inscription Through Thick and Thin (+10 armor against piercing damage) and +45 health while enchanted or in stance' & @CRLF & _
			'- At least 5th level in Deldrimor, Asura and Norn reputation ranks' & @CRLF & _
			'- one monk and one paragon heroes' & @CRLF & _
			'' & @CRLF & _
			'This bot farms obsidian shards in Tower of Courage in Fissure of Woe location in normal mode.' & @CRLF & _
			'If you have FoW scrolls then can set in GUI to enter FoW only through FoW scrolls and stop the bot when FoW scrolls run out' & @CRLF & _
			'It is recommended to run this farm mostly during weeks with Pantheon bonus active which gives free entry to FoW and UW' & @CRLF & _
			'Otherwise this farm bot can flush gold storage to 0. However income from obsidian shards and other loot should outweight the platinum cost' & @CRLF & _
			'' & @CRLF & _
			'- A shield with the inscription Through Thick and Thin (+10 armor against piercing damage) and +45 health while enchanted or in stance' & @CRLF & _
			'If you have FoW scrolls then can set in GUI to enter FoW only through FoW scrolls and stop the bot when FoW scrolls run out' & @CRLF & _
			'Equipment: full Blessed Insignias, Attunement runes, Spear/Axe/Sword of Enchanting (+5 energy), Shield of Fortitude (+10 armor vs piercing), +20 energy Staff of Enchanting as backup' & @CRLF & _
			'Enter The Fissure of Woe in Normal Mode' & @CRLF & _
			'Only viable during weeks with an active Pantheon bonus' & @CRLF & _
			'Equipment: full Blessed Insignias, Attunement runes, Spear/Axe/Sword of Enchanting (+5 energy), Shield of Fortitude (+10 armor vs piercing), +20 energy Staff of Enchanting as backup' & @CRLF & _
			'Enter The Fissure of Woe in Normal Mode' & @CRLF & _
			'Only viable during weeks with an active Pantheon bonus'
			BuildInfoAddRow('Player', 'R/A', 'OgcTc5+8Z6Aims4ABC35uU4IuEA', 'Expertise 12, Dagger 3, Shadow Arts 12')
			BuildInfoAddRow('Hero 1', 'Mo/X', 'OwAS8YIH2Eg/LeyLiAAA', 'Protection 12, Divine Favor 12')
			BuildInfoAddRow('Hero 2', 'P/Rt', 'OQijEqmMKODbe8OGAYiJx1YWMA', 'Restoration 10, Command 12, Leadership 8')
			Return True
		Case 'Froggy'
			$buildinfo_title = 'FROGGY - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone, uses consumables if available'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = '41mn average in HM with consets (automatically used if HM is on)' & @CRLF & _
			'Take quest rewards, refresh quest by entering dungeon and exiting it, then take quest again and reenter dungeon' & @CRLF & _
			'This is Giriff War version. To use Tekk War quest instead, replace:' & @CRLF & _
			'after rezoning quest npc agent could have changed so getting quest npc again' & @CRLF & _
			'This is not taking the quest, this is validating the first step of it' & @CRLF & _
			'For best results, do not cheap out on heroes' & @CRLF & _
			'Testing was done with a ROJ monk and an adapted mesmerway (1 E-surge replaced by a ROJ, ineptitude replaced by blinding surge)' & @CRLF & _
			'I recommend using a range build to avoid pulling extra groups in crowded rooms' & @CRLF & _
			'32mn average in NM' & @CRLF & _
			'41mn average in HM with consets (automatically used if HM is on)' & @CRLF & _
			'Area: Bogroot Growths (Froggy scepters)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'Gemstones'
			$buildinfo_title = 'GEMSTONES - BUILDS'
			$buildinfo_summary = 'Required primary: Mesmer  |  Heroes: set up the 7 heroes yourself (Team tab)  |  Uses a summoning stone'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = 'Requirements:' & @CRLF & _
			'- Access to Mallyx (finished all 4 DoA parts); progress in the quest Mallyx the Unyielding' & @CRLF & _
			'- Recommended: maxed Lightbringer title (display it before starting)' & @CRLF & _
			'- Strong hero build' & @CRLF & _
			'- Hero order: 1-3. Energy Surge mesmers (Me/Mo), 4. MM Lich Necro (N/P), 5. MM Necro (N/Rt), 6. BiP Necro (N/Rt), 7. ST Ritu (Rt)' & @CRLF & _
			'- Hero behaviour: all heroes on Fight, except the BiP Necro on Guard' & @CRLF & _
			'' & @CRLF & _
			'Equipment (player):' & @CRLF & _
			'- 5x Artificer Rune, 1x Superior Vigor, 2x Vitae' & @CRLF & _
			'- 1x Minor Fast Casting + 1x Major Fast Casting' & @CRLF & _
			'- 40/40 Domination set; character stats: 14 Fast Casting, 13 Domination Magic' & @CRLF & _
			'- If available: a defensive shield set, ideally +10 armor against demons' & @CRLF & _
			'' & @CRLF & _
			'Hero equipment:' & @CRLF & _
			'- Heroes 1-3 (Energy Surge): Adept Domination staff of Fortitude with "Aptitude not Attitude"; 5x Prodigy''s Insignia; Superior Vigor; Vitae' & @CRLF & _
			'- Hero 4 (MM Lich): 40/40 Death Magic set; 1x Bloodstained Insignia (not chest/legs) + 4x Tormentor''s Insignia; Superior Vigor; 2x Vitae' & @CRLF & _
			'- Hero 5 (MM): 40/20/20 Death Magic staff; same insignias and runes as Hero 4' & @CRLF & _
			'- Hero 6 (BiP): 40/20/20 Restoration staff; 5x Tormentor''s Insignia; Superior Vigor; 2x Attunement' & @CRLF & _
			'- Hero 7 (ST): 40/20/20 Spawning Power staff; 5x Blessed Insignia; Superior Vigor; Vitae' & @CRLF & _
			'' & @CRLF & _
			'Notes:' & @CRLF & _
			'- The Ebony Citadel of Mallyx is unlocked after defeating all 4 Lords of Anguish in the quest Mallyx the Unyielding.' & @CRLF & _
			'- Caution: do not defeat Mallyx the Unyielding: that finishes the quest and the 4 DoA parts must be done again.' & @CRLF & _
			'- This bot does not defeat Mallyx, it only clears the 19 waves, which does not finish the quest.' & @CRLF & _
			'- If gemstones stop dropping after 100+ consecutive runs on one character, switch to another character.'
			BuildInfoAddRow('Player', 'Me/X', 'OQBDAcMCT7iTPNB/AmO5ZcNyiA', 'Fast Casting 12, Illusion 3, Domination 12')
			BuildInfoAddRow('Hero 1', 'Me/Mo', 'OQNUAUBPwmMnAcqpb6lDyAXA0I', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 2', 'Me/Mo', 'OQNUAUBPwmMnAcqpb6lDyAXA0I', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNUAUBPwmMnAcqpb6lDyAXA0I', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 5', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 6', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 7', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			Return True
		Case 'Gemstone Margonite'
			$buildinfo_title = 'GEMSTONE MARGONITE - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: set up the 1 heroes yourself (Team tab)'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = 'Player needs to have access to Gate of Anguish outpost which has exit to City of Torcqua location' & @CRLF & _
			'Recommended to have maxed out Lightbringer title. If not maxed out then this farm is good for raising lightbringer rank' & @CRLF & _
			'Can switch to normal mode in case of low success rate but hard mode has better loots' & @CRLF & _
			'- Armor with HP runes and 5 blessed insignias (+50 armor when enchanted)' & @CRLF & _
			'- Spear/Sword/Axe +5 energy of Enchanting (20% longer enchantments duration)' & @CRLF & _
			'- Shield of Fortitude (+30 HP) with +10 vs Demons (like Stygian Aegis)' & @CRLF & _
			'- Monk hero armor and weapons with bonus to energy and HP' & @CRLF & _
			'You can run this farm as Assassin or Mesmer or Ranger or Elementalist. Bot will set up build automatically for these professions' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- Armor with HP runes and 5 blessed insignias (+50 armor when enchanted)' & @CRLF & _
			'- Spear/Sword/Axe +5 energy of Enchanting (20% longer enchantments duration)' & @CRLF & _
			'- Shield of Fortitude (+30 HP) with +10 vs Demons (like Stygian Aegis)' & @CRLF & _
			'- Monk hero with +4 Protection prayers (+3+1 headgear)' & @CRLF & _
			'- Monk hero armor and weapons with bonus to energy and HP' & @CRLF & _
			'' & @CRLF & _
			'You can run this farm as Assassin or Mesmer or Ranger or Elementalist. Bot will set up build automatically for these professions' & @CRLF & _
			'This bot farms margonite gemstones (1 of 4 types) in City of Torcqua location' & @CRLF & _
			'Player needs to have access to Gate of Anguish outpost which has exit to City of Torcqua location' & @CRLF & _
			'This farm reduces energy of margonites to 0 with ancestors visage skill which deals damage to margonites because margonites create Famine spirit' & @CRLF & _
			'Recommended to have maxed out Lightbringer title. If not maxed out then this farm is good for raising lightbringer rank' & @CRLF & _
			'Can switch to normal mode in case of low success rate but hard mode has better loots' & @CRLF & _
			'Gemstones can be exchanged into armbrace of truth (15 of each type) or coffer of whisper (1 of each type)' & @CRLF & _
			'For Assassin and Mesmer and Elementalist this bot works by casting Visage skills that reduce energy of Margonites to 0 which deals damage to them because they create Famine spirit' & @CRLF & _
			'' & @CRLF & _
			'Armor: full Blessed Insignias' & @CRLF & _
			'Weapon: Spear/Sword/Axe of Enchanting with +5 energy; Shield of Fortitude with +10 vs demons' & @CRLF & _
			'Backup: Staff of Enchanting, preferably Illusion' & @CRLF & _
			'Keep only one Visage active at a time' & @CRLF & _
			'Armor: full Blessed Insignias' & @CRLF & _
			'Weapon: Spear/Sword/Axe of Enchanting with +5 energy; Shield of Fortitude with +10 vs demons' & @CRLF & _
			'Backup: Staff of Enchanting, preferably Illusion' & @CRLF & _
			'Keep only one Visage active at a time'
			BuildInfoAddRow('Player', 'A/Me', 'OwVT4nPHYiHRn5AiVE3hm0D6iD', 'Deadly Arts 3, Shadow Arts 12, Illusion 12')
			BuildInfoAddRow('Player', 'Me/A', 'OQdTAmA/ZiHRn5AiAC3hm0DyiD', 'Fast Casting 3, Illusion 12, Shadow Arts 12')
			BuildInfoAddRow('Player', 'E/Me', 'OgVUEQkkYmSSfaDfVug0C0keQiAA', 'Illusion 8, Air 2, Earth 12, Energy Storage 10')
			BuildInfoAddRow('Player', 'R/A', 'OgcTcZ/8ZiHRn5AKCC3hm8uU4A', 'Expertise 12, Deadly Arts 3, Shadow Arts 12')
			BuildInfoAddRow('Hero 1', 'Mo/R', 'OwITAnHb5Qe/zhxLkpE6+G', 'Divine Favor 3, Protection 12, Beast 12')
			Return True
		Case 'Gemstone Stygian'
			$buildinfo_title = 'GEMSTONE STYGIAN - BUILDS'
			$buildinfo_summary = 'Required primary: Ranger  |  Heroes: set up the 1 heroes yourself (Team tab)'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = 'Player needs to have access to Gate of Anguish outpost which has exit to Stygian Veil location' & @CRLF & _
			'Recommended to have maxed out Lightbringer title. If not maxed out then this farm is good for raising lightbringer rank' & @CRLF & _
			'Can switch to normal mode in case of low success rate but hard mode has better loots' & @CRLF & _
			'- Armor with Skills/HP/Energy runes and 5 blessed insignias (+50 armor when enchanted)' & @CRLF & _
			'- Weapon of Enchanting (20% longer enchantments duration) to make Shadow Form permanent' & @CRLF & _
			'You can run this farm as Assassin or Mesmer or Ranger. Bot will set up build automatically for these professions' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- Armor with Skills/HP/Energy runes and 5 blessed insignias (+50 armor when enchanted)' & @CRLF & _
			'- Weapon of Enchanting (20% longer enchantments duration) to make Shadow Form permanent' & @CRLF & _
			'' & @CRLF & _
			'You can run this farm as Assassin or Mesmer or Ranger. Bot will set up build automatically for these professions' & @CRLF & _
			'This bot farms stygian gemstones (1 of 4 types) in Stygian Veil location' & @CRLF & _
			'Player needs to have access to Gate of Anguish outpost which has exit to Stygian Veil location' & @CRLF & _
			'Recommended to have maxed out Lightbringer title. If not maxed out then this farm is good for raising lightbringer rank' & @CRLF & _
			'Can switch to normal mode in case of low success rate but hard mode has better loots' & @CRLF & _
			'Gemstones can be exchanged into armbrace of truth (15 of each type) or coffer of whisper (1 of each type)' & @CRLF & _
			'For Mesmer and Assassin this bot works by exploitation of Guild Wars bug in pathing AI, which causes mobs to not attack player' & @CRLF & _
			'' & @CRLF & _
			'Armor: Radiant Insignias' & @CRLF & _
			'Weapon: +20 energy Staff of Fortitude (optionally a spear or bow for extra Mark of Pain triggers)' & @CRLF & _
			'Armor: Radiant Insignias' & @CRLF & _
			'Weapon: +20 energy Staff of Fortitude (optionally a spear or bow for extra Mark of Pain triggers)'
			BuildInfoAddRow('Player', 'A/Me', 'OwVT8ZBPGiHRn5mat0E4uM0ZCC', 'Shadow Arts 12, Domination 12, Inspiration 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdTI4x8ZiHRn5mat0E4uM0ZCC', 'Domination 12, Inspiration 3, Shadow Arts 12')
			BuildInfoAddRow('Player', 'R/N', 'OgQTcybiZK5o5Y5wSIXc465o7AA', 'Curses 9, Expertise 9, Wilderness Survival 12')
			BuildInfoAddRow('Hero 1', 'R/Mo', 'OgMTY5LjHhmgugf2BAAAAkJA', 'Beast 12, Expertise 12, Wilderness Survival 3')
			Return True
		Case 'Gemstone Torment'
			$buildinfo_title = 'GEMSTONE TORMENT - BUILDS'
			$buildinfo_summary = 'Required primary: Elementalist  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = 'Player needs to have access to Gate of Anguish outpost which has exit to RavenHeart Gloom location' & @CRLF & _
			'Recommended to have maxed out Lightbringer title. If not maxed out then this farm is good for raising lightbringer rank' & @CRLF & _
			'It is recommended to run this farm in normal mode' & @CRLF & _
			'- Full Radiant Armor with Attunement Runes to max out energy' & @CRLF & _
			'- Spear/Sword/Axe +5 energy of Enchanting (20% longer enchantments duration)' & @CRLF & _
			'- A focus with a Live for Today inscription (+15 energy, -1 energy degeneration) to max out energy' & @CRLF & _
			'You can run this farm as Elementalist. Bot will set up build automatically' & @CRLF & _
			'Staff of enchanting 20% for the run and faster energy regeneration' & @CRLF & _
			'Weapon of enchanting 20% and +5 Energy and a focus +15Energy/-1Regeneration for more energy' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- At least 100 energy to be able to cast all the spells' & @CRLF & _
			'- Full Radiant Armor with Attunement Runes to max out energy' & @CRLF & _
			'- Spear/Sword/Axe +5 energy of Enchanting (20% longer enchantments duration)' & @CRLF & _
			'- A focus with a Live for Today inscription (+15 energy, -1 energy degeneration) to max out energy' & @CRLF & _
			'' & @CRLF & _
			'You can run this farm as Elementalist. Bot will set up build automatically' & @CRLF & _
			'This bot farms torment gemstones (1 of 4 types) in Ravenheart Gloom location' & @CRLF & _
			'Player needs to have access to Gate of Anguish outpost which has exit to RavenHeart Gloom location' & @CRLF & _
			'Recommended to have maxed out Lightbringer title. If not maxed out then this farm is good for raising lightbringer rank' & @CRLF & _
			'It is recommended to run this farm in normal mode' & @CRLF & _
			'Gemstones can be exchanged into armbrace of truth (15 of each type) or coffer of whisper (1 of each type)' & @CRLF & _
			'' & @CRLF & _
			'At least 100 energy is needed' & @CRLF & _
			'Armor: Radiant Insignias with Attunement runes' & @CRLF & _
			'Weapons: a staff with +20% enchantment for running; a one-handed +5 energy / +20% enchantment weapon with a focus "Live for Today" (+15 energy, -1 regeneration)' & @CRLF & _
			'At least 100 energy is needed' & @CRLF & _
			'Armor: Radiant Insignias with Attunement runes' & @CRLF & _
			'Weapons: a staff with +20% enchantment for running; a one-handed +5 energy / +20% enchantment weapon with a focus "Live for Today" (+15 energy, -1 regeneration)'
			BuildInfoAddRow('Player', 'E/A', 'OgdTkSFzSC3xF0YQbAYYYgXoXA', 'Earth 9, Fire 12, Energy Storage 9')
			Return True
		Case 'Glint Challenge'
			$buildinfo_title = 'GLINT''S CHALLENGE - BUILDS'
			$buildinfo_summary = 'Any primary  |  Heroes: set up the 6 heroes yourself (Team tab)  |  Uses a summoning stone'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = 'in Glint Challenge location, the agent ID of Baby Dragon is always assigned to 19, when party has 8 members (can be accessed in GWToolbox)' & @CRLF & _
			'Brotherhood armor farm in Glints challenge with 7 hero team' & @CRLF & _
			'It is advisable to unequip staves, wands and focuses from player and heroes so that foes will not cast chaos storm on them:' & @CRLF & _
			'Main loop for the Mysterious armor farm' & @CRLF & _
			'Brotherhood armor farm in Glints challenge with 7 hero team' & @CRLF & _
			'It is advisable to unequip staves, wands and focuses from player and heroes so that foes will not cast chaos storm on them:' & @CRLF & _
			'Heroes work without equipment; do NOT give them wands or staves (foes then use Chaos Storm on them)' & @CRLF & _
			'Optional gear: Artificer''s (or Prodigy''s) Insignias on mesmers, Undertaker''s on necromancers (one Bloodstained on the healer), Herald''s on the ritualist' & @CRLF & _
			'Mesmers ideally 13 Fast Casting and 16 Illusion/Domination; shields improve survivability' & @CRLF & _
			'Heroes work without equipment; do NOT give them wands or staves (foes then use Chaos Storm on them)' & @CRLF & _
			'Optional gear: Artificer''s (or Prodigy''s) Insignias on mesmers, Undertaker''s on necromancers (one Bloodstained on the healer), Herald''s on the ritualist' & @CRLF & _
			'Mesmers ideally 13 Fast Casting and 16 Illusion/Domination; shields improve survivability'
			BuildInfoAddRow('Player', 'Me/X', 'OQBDAcMCT7iTPNB/AmO5ZcNyiA', 'Fast Casting 12, Illusion 3, Domination 12')
			BuildInfoAddRow('Hero 1', 'Rt/X', 'OACjAyhDJPYTnp17xFOtmFsLG', 'Communing 12, Restoration 3, Spawning Power 12')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjUsGWIPAtFBxTaO5EeDzxJ', 'Death 11, Soul Reaping 6, Restoration 12')
			BuildInfoAddRow('Hero 3', 'N/Me', 'OAVSIYDT1MJgVVmO4UyA5AXAA', 'Domination 12, Soul Reaping 12')
			BuildInfoAddRow('Hero 4', 'N/Me', 'OAVTIYCa05OMHqqmOc6NNHcBA', 'Domination 12, Blood 8, Soul Reaping 10')
			BuildInfoAddRow('Hero 5', 'Me/X', 'OQBTAWBPshGM9yBmOcaGIudBA', 'Fast Casting 11, Domination 12, Inspiration 6')
			BuildInfoAddRow('Hero 6', 'Me/Mo', 'OQNEAbwj1C9CgAmnRCwBlBE3gGB', 'Fast Casting 11, Illusion 12, Inspiration 6, Healing 2')
			Return True
		Case 'Jade Brotherhood'
			$buildinfo_title = 'JADE BROTHERHOOD - BUILDS'
			$buildinfo_summary = 'Required primary: Dervish  |  Heroes: set up the 1 heroes yourself (Team tab)'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = '- The Missing Daughter quest not completed' & @CRLF & _
			'Talk to Aiko and take her quest' & @CRLF & _
			'- 9+ in scythe mastery (enough to use your scythe)' & @CRLF & _
			'- A scythe Guided by Fate, enchantements last 20% longer' & @CRLF & _
			'- Windwalker insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- 16 in earth prayers' & @CRLF & _
			'- 11+ in mysticism' & @CRLF & _
			'- 9+ in scythe mastery (enough to use your scythe)' & @CRLF & _
			'- A scythe Guided by Fate, enchantements last 20% longer' & @CRLF & _
			'- Windwalker insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'- General Morgahn with 16 in Command, 10 in restoration and the rest in Leadership' & @CRLF & _
			'- The Missing Daughter quest not completed' & @CRLF & _
			'- Windwalker insignias on all the armor pieces'
			BuildInfoAddRow('Player', 'D/A', 'OgejkirMrSqimXfXfbrXaXNX4OA', 'Scythe 8, Earth 12, Mysticism 10')
			BuildInfoAddRow('Hero 1', 'P/Rt', 'OQijEqmMKODbe8O2Efjrx0bWMA', 'Restoration 10, Command 12, Leadership 8')
			Return True
		Case 'Kilroy'
			$buildinfo_title = 'KILROY - BUILDS'
			$buildinfo_summary = 'Any primary  |  No heroes  |  Uses consumables if available'
			$buildinfo_caption = ''
			$buildinfo_notes = 'This bot runs the Kilroy Stonekins Punch Out Extravaganza quest' & @CRLF & _
			'No setup required' & @CRLF & _
			'Deal with the quest shenanigans: take quest, take reward ...' & @CRLF & _
			'Ideal setup: sup vigor, insignias (stalwart or better), rune of Clarity and Recovery,' & @CRLF & _
			'As much in Dagger Mastery and your primary attribute as possible' & @CRLF & _
			'This bot runs the Kilroy Stonekins Punch Out Extravaganza quest' & @CRLF & _
			'Ideal setup: sup vigor, insignias (stalwart or better), rune of Clarity and Recovery,' & @CRLF & _
			'Thunderfists Brass Knuckles +15^-5e, vampiric, of Shelter (customized)' & @CRLF & _
			'As much in Dagger Mastery and your primary attribute as possible' & @CRLF & _
			'Consumables: pumpkin pie, cupcakes can be used' & @CRLF & _
			'IMPORTANT: this bot has not been proven survival safe yet' & @CRLF & _
			'Consumables: pumpkin pie, cupcakes can be used'
			Return True
		Case 'Kournans'
			$buildinfo_title = 'KOURNANS - BUILDS'
			$buildinfo_summary = 'Required primary: Elementalist  |  Heroes: set up the 3 heroes yourself (Team tab)'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = '- The quest Fish in a Barrel not completed' & @CRLF & _
			'Talk to Margrid and take her quest' & @CRLF & _
			'- Any weapon that gives you energy or maybe life' & @CRLF & _
			'- A spear +5 energy +20% enchantment duration' & @CRLF & _
			'- Blessed insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- 16 in Earth Magic' & @CRLF & _
			'- 13 in Energy Storage' & @CRLF & _
			'- 3 in Shadow Arts' & @CRLF & _
			'- Any weapon that gives you energy or maybe life' & @CRLF & _
			'- A spear +5 energy +20% enchantment duration' & @CRLF & _
			'- Blessed insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'- The quest Fish in a Barrel not completed' & @CRLF & _
			'- Blessed insignias on all the armor pieces'
			BuildInfoAddRow('Player', 'E/A', 'OgdTkYG/HCHMXctUVwHC3xVI1BA', 'Earth 12, Energy Storage 12, Shadow Arts 3')
			BuildInfoAddRow('Hero 1', 'R/X', 'OgATYnLjZB6C+Zn76OzGAAAA', 'Beast 3, Expertise 12, Wilderness Survival 12')
			BuildInfoAddRow('Hero 2', 'Rt/X', 'OACjAyhDJPBTy58M5CAAAAAAAA', 'Communing 12, Restoration 3, Spawning Power 12')
			BuildInfoAddRow('Hero 3', 'P/Rt', 'OQijEqmMKO84dM92HbiH26YcMA', 'Restoration 10, Command 12, Leadership 8')
			Return True
		Case 'Kurzick Ferndale'
			$buildinfo_title = 'KURZICK FERNDALE - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = '- a full hero team that can clear HM content easily' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- a full hero team that can clear HM content easily' & @CRLF & _
			'- a build that can be played from skill 1 to 8 easily (no combos or complicated builds)' & @CRLF & _
			'This bot does not load hero builds - please use your own teambuild' & @CRLF & _
			'Bring plenty of enchantment removal on the hero bars for the Gardeners' & @CRLF & _
			'Area: Ferndale (Kurzick faction)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'Kurzick Drazach'
			$buildinfo_title = 'KURZICK DRAZACH - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = '- a full hero team that can clear HM content easily' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- a full hero team that can clear HM content easily' & @CRLF & _
			'- a build that can be played from skill 1 to 8 easily (no combos or complicated builds)' & @CRLF & _
			'This bot does not load hero builds - please use your own teambuild' & @CRLF & _
			'An Alternative Farm to Ferndale. This Bot will farm Drazach Thicket' & @CRLF & _
			'Area: Drazach Thicket (Kurzick faction)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'LDOA'
			$buildinfo_title = 'LDOA - BUILDS'
			$buildinfo_summary = 'Required primary: Monk  |  No heroes  |  Uses consumables if available'
			$buildinfo_caption = ''
			$buildinfo_notes = '- do a few quests and kill worms outside Ashford until level 2' & @CRLF & _
			'- between level 2 and 9, does the quest Charr at the Gate repeatedly' & @CRLF & _
			'- between level 10 and 19 does the quest Farmer Hamnet which is only available one day of the week' & @CRLF & _
			'Main method to get LDOA title' & @CRLF & _
			'LDOA Title farm setup' & @CRLF & _
			'Initial setup for LDOA title farm if new char, this is done only once' & @CRLF & _
			'First Sir Tydus quest to get some skills' & @CRLF & _
			'Determine War Preparation and Profession Test quest IDs and dialog IDs depending on the primary profession' & @CRLF & _
			'Could talk to Baron Egan to get Bandit Raid Quest' & @CRLF & _
			'$questNPC = GetNearestNPCToCoords(11060, 10775)' & @CRLF & _
			'TakeQuest($questNPC, $ID_QUEST_BANDIT_RAID, $ID_DIALOG_ACCEPT_QUEST_BANDIT_RAID)' & @CRLF & _
			'Could also get Namar quest' & @CRLF & _
			'$questNPC = GetNearestNPCToCoords(6760, 9720)' & @CRLF & _
			'TakeQuest($questNPC, $ID_QUEST_POOR_TENANT, $ID_DIALOG_ACCEPT_QUEST_POOR_TENANT)' & @CRLF & _
			'This quest never appears as completed because taking the reward is the completion' & @CRLF & _
			'This quest never appears as completed either - last dialog to get reward is the completion' & @CRLF & _
			'Get weapons for LDOA title farm' & @CRLF & _
			'Setup Charr at the gate quest' & @CRLF & _
			'Setup Hamnet quest' & @CRLF & _
			'LDOA Title farm loop' & @CRLF & _
			'- gets weapons and summoning stone' & @CRLF & _
			'Get weapons for LDOA title farm' & @CRLF & _
			'This bot:' & @CRLF & _
			'- gets weapons and summoning stone' & @CRLF & _
			'- do a few quests and kill worms outside Ashford until level 2' & @CRLF & _
			'- between level 2 and 9, does the quest Charr at the Gate repeatedly' & @CRLF & _
			'- between level 10 and 19 does the quest Farmer Hamnet which is only available one day of the week' & @CRLF & _
			'- stops once Legendary Defender of Ascalon.' & @CRLF & _
			'- gets weapons and summoning stone' & @CRLF & _
			'Area: Pre-Searing (Legendary Defender of Ascalon)'
			Return True
		Case 'Lightbringer'
			$buildinfo_title = 'LIGHTBRINGER - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = 'Lightbringer title farm' & @CRLF & _
			'Main loop for the Lightbringer title farm' & @CRLF & _
			'Lightbringer title farm' & @CRLF & _
			'Area: Mirror of Lyss (Lightbringer title)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'Lightbringer & Sunspear'
			$buildinfo_title = 'LIGHTBRINGER & SUNSPEAR - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = '- the quest A Show of Force' & @CRLF & _
			'- the quest Requiem for a Brain' & @CRLF & _
			'- rune of doom in your inventory' & @CRLF & _
			'- equip holy damage weapons (monk staves/wands, Verdict (monk hammer) and Unveil (dervish staff)) and on your heroes too if possible' & @CRLF & _
			'- use weapons in this order : holy/daggers-scythes/axe-sword/spear/hammer/wand-staff/bow' & @CRLF & _
			'Set to 1300 for axe, dagger and sword, 1500 for scythe and spear, 1700 for hammer, wand and staff' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- the quest A Show of Force' & @CRLF & _
			'- the quest Requiem for a Brain' & @CRLF & _
			'- rune of doom in your inventory' & @CRLF & _
			'- use low level heroes to level them up' & @CRLF & _
			'- equip holy damage weapons (monk staves/wands, Verdict (monk hammer) and Unveil (dervish staff)) and on your heroes too if possible' & @CRLF & _
			'- use weapons in this order : holy/daggers-scythes/axe-sword/spear/hammer/wand-staff/bow' & @CRLF & _
			'Area: Sulfurous Wastes (Sunspear and Lightbringer titles)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'LuxonMQ'
			$buildinfo_title = 'LUXONMQ - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = '- a full hero team that can clear HM content easily' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- a full hero team that can clear HM content easily' & @CRLF & _
			'- a build that can be played from skill 1 to 8 easily (no combos or complicated builds)' & @CRLF & _
			'This bot does not load hero builds - please use your own teambuild' & @CRLF & _
			'Area: Mount Qinkai (Luxon faction)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'LuxonSS'
			$buildinfo_title = 'LUXONSS - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = '- a full hero team that can clear HM content easily' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- a full hero team that can clear HM content easily' & @CRLF & _
			'- a build that can be played from skill 1 to 8 easily (no combos or complicated builds)' & @CRLF & _
			'This bot does not load hero builds - please use your own teambuild' & @CRLF & _
			'Area: Silent Surf (Luxon faction)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'Mantids'
			$buildinfo_title = 'MANTIDS - BUILDS'
			$buildinfo_summary = 'Required primary: Ranger  |  Heroes: set up the 1 heroes yourself (Team tab)'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = '- A shield with the inscription Through Thick and Thin (+10 armor against Piercing damage)' & @CRLF & _
			'- A one hand weapon with +5 energy +20% enchantment duration' & @CRLF & _
			'- Sentry or Blessed insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- 14 in Expertise' & @CRLF & _
			'- 12 in Shadow Arts' & @CRLF & _
			'- 8 in Beast Mastery' & @CRLF & _
			'- A shield with the inscription Through Thick and Thin (+10 armor against Piercing damage)' & @CRLF & _
			'- A one hand weapon with +5 energy +20% enchantment duration' & @CRLF & _
			'- Sentry or Blessed insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'- A shield with the inscription Through Thick and Thin (+10 armor against Piercing damage)' & @CRLF & _
			'- Sentry or Blessed insignias on all the armor pieces'
			BuildInfoAddRow('Player', 'R/A', 'OgcTYxr+5B5ozOgFHCIuT4AdAA', 'Beast 8, Expertise 10, Shadow Arts 12')
			BuildInfoAddRow('Hero 1', 'P/Rt', 'OQijEqmMKODbe8OmEbi7x3YWMA', 'Restoration 10, Command 12, Leadership 8')
			Return True
		Case 'Ministerial Commendations'
			$buildinfo_title = 'MINISTERIAL COMMENDATIONS - BUILDS'
			$buildinfo_summary = 'Required primary: Dervish  |  No heroes  |  Uses a city speed boost; uses consumables if available'
			$buildinfo_caption = ''
			$buildinfo_notes = '- a full hero team that can clear HM content easily' & @CRLF & _
			'- 10 Tactics (shield Req + weakness)' & @CRLF & _
			'- 10 Swordsmanship (sword Req + weakness)' & @CRLF & _
			'- Blessed insignias or Windwalker insignias' & @CRLF & _
			'- A tactics shield q9 or less with the inscription Sleep now in the fire (+10 armor against fire damage)' & @CRLF & _
			'- A main hand with +20% enchantments duration and +5 armor' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- a full hero team that can clear HM content easily' & @CRLF & _
			'- 13 Earth Prayers' & @CRLF & _
			'- 7 Mysticism' & @CRLF & _
			'- 4 Wind Prayers' & @CRLF & _
			'- 10 Tactics (shield Req + weakness)' & @CRLF & _
			'- 10 Swordsmanship (sword Req + weakness)' & @CRLF & _
			'- Blessed insignias or Windwalker insignias' & @CRLF & _
			'- A tactics shield q9 or less with the inscription Sleep now in the fire (+10 armor against fire damage)' & @CRLF & _
			'- A main hand with +20% enchantments duration and +5 armor' & @CRLF & _
			'- any PCons you wish to use' & @CRLF & _
			'This bot does not load hero builds - please use your own teambuild' & @CRLF & _
			'- any PCons you wish to use'
			BuildInfoAddRow('Player', 'D/W', 'OgGlQlVp6smsJRg19RTKexTkL2XsDC', 'Swordsmanship 9, Tactics 9, Wind 3, Earth 9, Mysticism 9')
			Return True
		Case 'Minotaurs'
			$buildinfo_title = 'MINOTAURS - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = 'For best results, have :' & @CRLF & _
			'- a build that can be played from skill 1 to 8 easily (no combos or complicated builds)' & @CRLF & _
			'- Solid heroes team composition, which can be loaded from GUI' & @CRLF & _
			'' & @CRLF & _
			'This bot farms minotaur horns which can be salvaged for materials, or given to Nicholas the Traveler' & @CRLF & _
			'' & @CRLF & _
			'Drops: materials (minotaur horns)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'Nexus Challenge'
			$buildinfo_title = 'NEXUS CHALLENGE - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = 'Mysterious armor farm' & @CRLF & _
			'Main loop for the Mysterious armor farm' & @CRLF & _
			'Mysterious armor farm' & @CRLF & _
			'Drops: Mysterious armor hero pieces'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'Norn'
			$buildinfo_title = 'NORN - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = 'Norn title farm, bring solid heroes composition' & @CRLF & _
			'Area: Varajar Fells (Norn title)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'OmniFarm'
			$buildinfo_title = 'OMNIFARM - BUILDS'
			$buildinfo_summary = 'Any primary  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = 'Zephyr Ranger - Quickening Zephyr and serpents quickness must be locked so hero does not use them'
			Return True
		Case 'Pongmei'
			$buildinfo_title = 'PONGMEI - BUILDS'
			$buildinfo_summary = 'Required primary: Dervish  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = 'Note: in HM, very frequent failures on Am Fah - I suggest cutting that part of the farm if you wish to run in HM' & @CRLF & _
			'- A staff +20e and +20% enchantment duration' & @CRLF & _
			'- caster weapons on all heroes' & @CRLF & _
			'- Windwalker insignias on all the armor pieces' & @CRLF & _
			'- Vigor' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- 12 in Shadow Arts' & @CRLF & _
			'- 16 in Mysticism if playing Dervish' & @CRLF & _
			'- 3 in Deadly Arts' & @CRLF & _
			'- A staff +20e and +20% enchantment duration' & @CRLF & _
			'- caster weapons on all heroes' & @CRLF & _
			'- Windwalker insignias on all the armor pieces' & @CRLF & _
			'- Vigor' & @CRLF & _
			'Note: in HM, very frequent failures on Am Fah - I suggest cutting that part of the farm if you wish to run in HM' & @CRLF & _
			'- Windwalker insignias on all the armor pieces'
			BuildInfoAddRow('Player', 'D/A', 'OgejwyezHT8I6MHQ3l0kNQ4OIQ', 'Mysticism 12, Deadly Arts 3, Shadow Arts 12')
			Return True
		Case 'Raptors'
			$buildinfo_title = 'RAPTORS - BUILDS'
			$buildinfo_summary = 'Any primary  |  Heroes: set up the 1 heroes yourself (Team tab)'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = 'Get Asura blessing only if title is not maxed yet' & @CRLF & _
			'- 9+ in swordsmanship (enough to use your sword)' & @CRLF & _
			'- A Tactics shield with the inscription Through Thick and Thin (+10 armor against Piercing damage)' & @CRLF & _
			'- A sword of Shelter, prefix and inscription do not matter' & @CRLF & _
			'- Knight insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'- A superior Absorption rune' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- 12 in curses' & @CRLF & _
			'- 12+ in tactics' & @CRLF & _
			'- 9+ in swordsmanship (enough to use your sword)' & @CRLF & _
			'- A Tactics shield with the inscription Through Thick and Thin (+10 armor against Piercing damage)' & @CRLF & _
			'- A sword of Shelter, prefix and inscription do not matter' & @CRLF & _
			'- Knight insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'- A superior Absorption rune' & @CRLF & _
			'- General Morgahn with 16 in Command, 10 in restoration and the rest in Leadership' & @CRLF & _
			'		and all of his skills locked' & @CRLF & _
			'' & @CRLF & _
			'- A Tactics shield with the inscription Through Thick and Thin (+10 armor against Piercing damage)' & @CRLF & _
			'- Knight insignias on all the armor pieces' & @CRLF & _
			'- Use pumpkin pie slices ? Reduce cast time and increase attack speed reducing chances to be interrupted during MoP or Whirlwind' & @CRLF & _
			'Armor: Knight''s Insignias with high health runes' & @CRLF & _
			'Weapon: Sword of Fortitude or Shelter with "I Have the Power!" ("Dance with Death" at high Asura rank)' & @CRLF & _
			'Shield: Tactics shield of Fortitude with armor vs piercing ("Through Thick and Thin")' & @CRLF & _
			'Armor: Knight''s Insignias with high health runes' & @CRLF & _
			'Weapon: Sword of Fortitude or Shelter with "I Have the Power!" ("Dance with Death" at high Asura rank)' & @CRLF & _
			'Shield: Tactics shield of Fortitude with armor vs piercing ("Through Thick and Thin")'
			BuildInfoAddRow('Player', 'W/N', 'OQQUc4oQt6SWC0kqM5F9Fja7grFA', 'Curses 12, Strength 2, Swordsmanship 6, Tactics 11')
			BuildInfoAddRow('Hero 1', 'P/Rt', 'OQijEqmMKODbe8O2Efjrx0bWMA', 'Restoration 10, Command 12, Leadership 8')
			Return True
		Case 'Skale Fins'
			$buildinfo_title = 'SKALE FINS - BUILDS'
			$buildinfo_summary = 'Required primary: Dervish  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = '- 12 in Scythe Mastery' & @CRLF & _
			'- A max damage scythe' & @CRLF & _
			'Focus on killing a Skale' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- 16 in Mysticism' & @CRLF & _
			'- 12 in Scythe Mastery' & @CRLF & _
			'- A max damage scythe'
			BuildInfoAddRow('Player', 'D/A', 'OgeikysMdXuddgh7QBJG2cJdBA', 'Scythe 12, Mysticism 12')
			Return True
		Case 'Skrees'
			$buildinfo_title = 'SKREES - BUILDS'
			$buildinfo_summary = 'Required primary: Ranger  |  Heroes: set up the 2 heroes yourself (Team tab)'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = '- the quest Desperate Measures that makes the skrees show up (without it you cant farm)' & @CRLF & _
			'Ritualist skills that could be used (but require additional hero)' & @CRLF & _
			'Necro skills that could be used (but require additional hero)' & @CRLF & _
			'- A shield +30 health with +10 armor against piercing damage' & @CRLF & _
			'- A sword +5 energy +7 armor against physical damage or +20% enchantment duration' & @CRLF & _
			'- Sentry or Blessed insignias on all armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- the quest Desperate Measures that makes the skrees show up (without it you cant farm)' & @CRLF & _
			'- 16 in Expertise' & @CRLF & _
			'- 12 in Shadow Arts' & @CRLF & _
			'- A shield +30 health with +10 armor against piercing damage' & @CRLF & _
			'- A sword +5 energy +7 armor against physical damage or +20% enchantment duration' & @CRLF & _
			'- Sentry or Blessed insignias on all armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'- A shield +30 health with +10 armor against piercing damage' & @CRLF & _
			'- Sentry or Blessed insignias on all armor pieces'
			BuildInfoAddRow('Player', 'R/A', 'OgcTcZ88Z6AiV8uMuE4Q4A3BBCA', 'Expertise 12, Wilderness Survival 3, Shadow Arts 12')
			BuildInfoAddRow('Hero 1', 'R/Rt', 'OggjYxYDIPQnnz1ReCAAAAAAAA', 'Beast 12, Wilderness Survival 3, Communing 12')
			BuildInfoAddRow('Hero 2', 'P/Rt', 'OQijEqmMKOD7dsJuHziJx1YaMA', 'Restoration 10, Command 12, Leadership 8')
			Return True
		Case 'SoO'
			$buildinfo_title = 'SOO - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone, uses consumables if available'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = '60mn average in HM with cons (automatically used if HM is on)' & @CRLF & _
			'Take quest rewards, refresh quest by entering dungeon and exiting it, then take quest again and reenter dungeon' & @CRLF & _
			'after rezoning quest npc agent could have changed so getting quest npc again' & @CRLF & _
			'For best results, do not cheap out on heroes' & @CRLF & _
			'Testing was done with a ROJ monk and an adapted mesmerway (1esurge replaced by a ROJ, inept replaced by blinding surge)' & @CRLF & _
			'I recommend using a range build to avoid pulling extra groups in crowded rooms' & @CRLF & _
			'45mn average in NM' & @CRLF & _
			'60mn average in HM with cons (automatically used if HM is on)' & @CRLF & _
			'Drops: Dragon Bone Staff'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'SpiritSlaves'
			$buildinfo_title = 'SPIRITSLAVES - BUILDS'
			$buildinfo_summary = 'Required primary: Ritualist  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = '- the quest Destroy the Ungrateful Slaves not completed' & @CRLF & _
			'Need a lot of energy in case both energy spirits are there: Zephyr add 30% mana cost and quicksand adds 1 energy' & @CRLF & _
			'- Herald insignias, Superior Vigor and 3 attunement runes' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- 16 Restoration Magic' & @CRLF & _
			'- 12 Inspiration Magic' & @CRLF & _
			'- Herald insignias, Superior Vigor and 3 attunement runes' & @CRLF & _
			'- the quest Destroy the Ungrateful Slaves not completed'
			BuildInfoAddRow('Player', 'Rt/Me', 'OAWjMwhM5QRAmAsiLBWMEP0krlA', 'Inspiration 12, Restoration 12, Spawning Power 3')
			Return True
		Case 'Sunspear Armor'
			$buildinfo_title = 'SUNSPEAR ARMOR - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = 'Sunspear armor farm with 7heroes GWReborn s comp' & @CRLF & _
			'Main loop for the Sunspear Armor farm' & @CRLF & _
			'Cleaning Sunspear Armors function' & @CRLF & _
			'Sunspear armor farm with 7heroes GWReborn s comp' & @CRLF & _
			'Area: Dajkah Inlet Challenge (Sunspear armor hero pieces)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'Tasca'
			$buildinfo_title = 'TASCA''S CHEST RUN - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  No heroes  |  Uses consumables if available'
			$buildinfo_caption = 'One build per profession: the bot loads the row matching your primary profession when it has one.'
			$buildinfo_notes = 'For best results, have:' & @CRLF & _
			'- 12 in Shadow Arts; 16 in Mysticism if playing Dervish; 3 in Deadly Arts' & @CRLF & _
			'- A staff +20e and +20% enchantment duration' & @CRLF & _
			'- Caster weapons on all heroes' & @CRLF & _
			'- Windwalker insignias on all the armor pieces, Vigor' & @CRLF & _
			'' & @CRLF & _
			'Notes:' & @CRLF & _
			'- Outpost: The Granite Citadel; area: Tasca''s Demise (Hard Mode in the shipped config)' & @CRLF & _
			'- Every chest needs a Lockpick; keep a stack in the inventory' & @CRLF & _
			'- The bot does not load a skill bar for this run: load the row for your primary yourself' & @CRLF & _
			'- Average run about 3 minutes'
			BuildInfoAddRow('Player', 'D/A', 'OgejwyezHT8I6MHQ3l0kNQ4OIQ', 'Mysticism 12, Deadly Arts 3, Shadow Arts 12')
			BuildInfoAddRow('Player', 'A/X', 'OwBj4pf8YQ8I6MHQ3lxlpZ4OIQA', 'Deadly Arts 10, Shadow Arts 12, Critical Strikes 1')
			BuildInfoAddRow('Player', 'Me/A', 'OQdTAmP7ZiHRn5A6ukmsBC3BBC', 'Fast Casting 3, Shadow Arts 12, Deadly Arts 12')
			BuildInfoAddRow('Player', 'E/A', 'OgdTw4P7HiHRn5A6ukmsBC3BBC', 'Energy Storage 12, Shadow Arts 12, Deadly Arts 3')
			BuildInfoAddRow('Player', 'Mo/A', 'OwcTAnP7ZiHRn5A6ukmsBC3BBC', 'Divine Favor 3, Shadow Arts 12, Deadly Arts 12')
			BuildInfoAddRow('Player', 'N/A', 'OAdT8Z/YYiHRn5A6ukmsBC3BBC', 'Shadow Arts 12, Deadly Arts 3, Soul Reaping 12')
			BuildInfoAddRow('Player', 'Rt/A', 'OAej8xeM5Q8I6MHQ3l0kNQ4OIQ', 'Shadow Arts 12, Deadly Arts 12, Spawning Power 3')
			Return True
		Case 'MagmasRun'
			$buildinfo_title = 'MAGMAS RUN - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  No heroes  |  Uses consumables if available'
			$buildinfo_caption = 'One build per profession: the bot loads the row matching your primary profession when it has one.'
			$buildinfo_notes = '- A staff +20e and +20% enchantment duration' & @CRLF & _
			'- caster weapons on all heroes' & @CRLF & _
			'- Windwalker insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- 12 in Shadow Arts' & @CRLF & _
			'- 16 in Mysticism if playing Dervish' & @CRLF & _
			'- 3 in Deadly Arts' & @CRLF & _
			'- A staff +20e and +20% enchantment duration' & @CRLF & _
			'- caster weapons on all heroes' & @CRLF & _
			'- Windwalker insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'- Windwalker insignias on all the armor pieces'
			BuildInfoAddRow('Player', 'D/A', 'OgejwyezHT8I6MHQ3l0kNQ4OIQ', 'Mysticism 12, Deadly Arts 3, Shadow Arts 12')
			BuildInfoAddRow('Player', 'A/X', 'OwBj4pf8YQ8I6MHQ3lxlpZ4OIQA', 'Deadly Arts 10, Shadow Arts 12, Critical Strikes 1')
			BuildInfoAddRow('Player', 'Me/A', 'OQdTAmP7ZiHRn5A6ukmsBC3BBC', 'Fast Casting 3, Shadow Arts 12, Deadly Arts 12')
			BuildInfoAddRow('Player', 'E/A', 'OgdTw4P7HiHRn5A6ukmsBC3BBC', 'Energy Storage 12, Shadow Arts 12, Deadly Arts 3')
			BuildInfoAddRow('Player', 'Mo/A', 'OwcTAnP7ZiHRn5A6ukmsBC3BBC', 'Divine Favor 3, Shadow Arts 12, Deadly Arts 12')
			BuildInfoAddRow('Player', 'N/A', 'OAdT8Z/YYiHRn5A6ukmsBC3BBC', 'Shadow Arts 12, Deadly Arts 3, Soul Reaping 12')
			BuildInfoAddRow('Player', 'Rt/A', 'OAej8xeM5Q8I6MHQ3l0kNQ4OIQ', 'Shadow Arts 12, Deadly Arts 12, Spawning Power 3')
			Return True
		Case 'TunnelsOfTheForsaken'
			$buildinfo_title = 'TUNNELS OF THE FORSAKEN - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone, uses consumables if available'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = '41mn average in HM with consets (automatically used if HM is on)' & @CRLF & _
			'For best results, do not cheap out on heroes' & @CRLF & _
			'Testing was done with a ROJ monk and an adapted mesmerway (1 E-surge replaced by a ROJ, ineptitude replaced by blinding surge)' & @CRLF & _
			'I recommend using a range build to avoid pulling extra groups in crowded rooms' & @CRLF & _
			'32mn average in NM' & @CRLF & _
			'41mn average in HM with consets (automatically used if HM is on)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'Underworld'
			$buildinfo_title = 'UNDERWORLD - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'First rows: specialized Underworld bars. Then suggested skill 1-8 bars and the Team tab default heroes (display only).'
			$buildinfo_notes = 'In NM with quests disabled bot takes about 1 hour 30 minutes to clear/farm on average.' & @CRLF & _
			'In NM with quests enabled bot takes about 2 hours 15 minutes to clear on average.' & @CRLF & _
			'Bot not tested in HM' & @CRLF & _
			'Make sure to set loot filters to purple swords in case crystalline sword drops from quest chests.' & @CRLF & _
			'Or disable specific Reaper quests that take too long.' & @CRLF & _
			'Must be Rt/A or A/Rt in order to do Four Horsemen quest.' & @CRLF & _
			'Specific Quest Knobs' & @CRLF & _
			'Accept reward & take quest Restoring Grenths Monuments' & @CRLF & _
			'doing ''Clear the Chamber'' quest' & @CRLF & _
			'Take Quest Wrathful spirits from the Reaper and complete' & @CRLF & _
			'Take Quest Servants of Grenth from Reaper of the Ice Wastes' & @CRLF & _
			'Take Quest Terrorweb Queen from the Reaper of the Spawning Pools' & @CRLF & _
			'Take Quest Imprisoned Spirits from the Reaper of the Bone Pits' & @CRLF & _
			'Pre-Clear for Unwanted Guests Quest' & @CRLF & _
			'Take Quest Demon Assassin from the Reaper of the Twin Serpent Mountains & defend' & @CRLF & _
			'Take Quest Escort of Souls from the Reaper in the Labyrinth' & @CRLF & _
			'Take Quest Unwanted Guests from the Reaper in the Labyrinth' & @CRLF & _
			'If quest still is not complete, roam and search for stuck horseman' & @CRLF & _
			'Make sure to set loot filters to purple swords in case crystalline sword drops from quest chests.' & @CRLF & _
			'Manually set $ATTEMPT_REAPER_QUESTS to False if you want to farm ecto only.' & @CRLF & _
			'For best results, dont cheap out on heroes' & @CRLF & _
			'I recommend using a range build to avoid pulling extra groups in crowded areas' & @CRLF & _
			'Due to Hero Flag mechanics place healers in slots 6-8' & @CRLF & _
			'In NM with quests disabled bot takes about 1 hour 30 minutes to clear/farm on average.' & @CRLF & _
			'In NM with quests enabled bot takes about 2 hours 15 minutes to clear on average.' & @CRLF & _
			'Bot not tested in HM' & @CRLF & _
			'Make sure to set loot filters to purple swords in case crystalline sword drops from quest chests.' & @CRLF & _
			'Manually set $ATTEMPT_REAPER_QUESTS to False if you want to farm ecto only.' & @CRLF & _
			'Or disable specific Reaper quests that take too long.' & @CRLF & _
			'Must be Rt/A or A/Rt in order to do Four Horsemen quest.' & @CRLF & _
			'' & @CRLF & _
			'Small wrapper to use both conset and legionnaire summoning crystal'
			BuildInfoAddRow('Player', 'Rt/A', 'OAejAqiMpR0gXT+glTfTQTVTdOA', 'Communing 10, Channeling 12, Spawning Power 6')
			BuildInfoAddRow('Player', 'A/Rt', 'OwhjAyi84Q0gXT+glTfTQTVTdOA', 'Communing 12, Channeling 12, Critical Strikes 3')
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'Vaettirs'
			$buildinfo_title = 'VAETTIRS - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  No heroes  |  Uses consumables if available'
			$buildinfo_caption = 'One build per profession: the bot loads the row matching your primary profession when it has one.'
			$buildinfo_notes = 'Recommended to have maxed out Norn title. If not maxed out then this farm is good for raising Norn rank' & @CRLF & _
			'Vaettir farm can be a good way to max out survivor title' & @CRLF & _
			'Setup player skills and title depending on his profession' & @CRLF & _
			'giving more health to monk 55hp from norn title effect would screw up farm, so no displayed title for monk' & @CRLF & _
			'Get Norn blessing only if title is not maxed yet. Assuming that Norn has been already defeated' & @CRLF & _
			'Caution, monk 55hp needs protective spirit before casting shadow form, otherwise damage reduction will not be applied' & @CRLF & _
			'- Armor with HP runes and 5 blessed/prodigy insignias (+50 armor when enchanted)' & @CRLF & _
			'- A shield with the inscription Like a rolling stone (+10 armor against earth damage) and +45 health while enchanted' & @CRLF & _
			'- In case of Monk 55hp, use grim cesta -50hp and armor with 5*-75hp runes' & @CRLF & _
			'- In case of Obsidian Flesh Elementalist, recommended to have armor full with geomancer runes' & @CRLF & _
			'- Spear/Sword/Axe +5 energy of Enchanting (20% longer enchantments duration)' & @CRLF & _
			'You can run this farm as Assassin or Mesmer or Monk or Elementalist. Bot will set up build automatically for these professions' & @CRLF & _
			'Select mesmer attributes depending on whether it has the anniversary shield and proper runes' & @CRLF & _
			'No anniversary shield, so it doesn''t matter what value of Fast Casting we actually have' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- +4 Shadow Arts (+3 +1 headgear)' & @CRLF & _
			'- Armor with HP runes and 5 blessed/prodigy insignias (+50 armor when enchanted)' & @CRLF & _
			'- A shield with the inscription Like a rolling stone (+10 armor against earth damage) and +45 health while enchanted' & @CRLF & _
			'- In case of Monk 55hp, use grim cesta -50hp and armor with 5*-75hp runes' & @CRLF & _
			'- In case of Obsidian Flesh Elementalist, recommended to have armor full with geomancer runes' & @CRLF & _
			'- Spear/Sword/Axe +5 energy of Enchanting (20% longer enchantments duration)' & @CRLF & _
			'- Cupcakes' & @CRLF & _
			'Recommended to have maxed out Norn title. If not maxed out then this farm is good for raising Norn rank' & @CRLF & _
			'Vaettir farm can be a good way to max out survivor title' & @CRLF & _
			'You can run this farm as Assassin or Mesmer or Monk or Elementalist. Bot will set up build automatically for these professions' & @CRLF & _
			'- Cupcakes' & @CRLF & _
			'A/Me and Me/A: Blessed Insignias, Attunement runes, +5 energy / +20% enchantment Sword/Spear/Axe, shield +10 armor vs earth ("Like a Rolling Stone")' & @CRLF & _
			'E/Me: Geomancer Insignias, +20% enchantment weapon, about 50+ energy; 40/40 Domination set optional' & @CRLF & _
			'Mo/A 55hp: a superior attribute rune on every armor piece (base health 105), +5 energy / +20% enchantment weapon, the -50 health Grim Cesta' & @CRLF & _
			'A/Me and Me/A: Blessed Insignias, Attunement runes, +5 energy / +20% enchantment Sword/Spear/Axe, shield +10 armor vs earth ("Like a Rolling Stone")' & @CRLF & _
			'E/Me: Geomancer Insignias, +20% enchantment weapon, about 50+ energy; 40/40 Domination set optional' & @CRLF & _
			'Mo/A 55hp: a superior attribute rune on every armor piece (base health 105), +5 energy / +20% enchantment weapon, the -50 health Grim Cesta'
			BuildInfoAddRow('Player', 'A/Me', 'OwVU4lPL2hN8Id2BEBSANBLhbK', 'Deadly Arts 2, Shadow Arts 12, Domination 11, Inspiration 6')
			BuildInfoAddRow('Player', 'Me/A', 'OQdVASBOKv85hHpzOgIQCoJYJcTB', 'Fast Casting 9, Domination 8, Inspiration 5, Deadly Arts 2, Shadow Arts 12')
			BuildInfoAddRow('Player', 'Me/A', 'OQdVAQROKv85hHpzOgIQCoJYJcTB', 'Fast Casting 8, Domination 9, Inspiration 5, Deadly Arts 2, Shadow Arts 12')
			BuildInfoAddRow('Player', 'Me/A', 'OQdVAOhOIf85hHpzOgIQCoJYJcTB', 'Fast Casting 7, Domination 10, Inspiration 4, Deadly Arts 1, Shadow Arts 12')
			BuildInfoAddRow('Player', 'Me/A', 'OQdVAMhOK/85hHpzOgIQCoJYJcTB', 'Fast Casting 6, Domination 10, Inspiration 5, Deadly Arts 3, Shadow Arts 12')
			BuildInfoAddRow('Player', 'Mo/A', 'OwcV4o3CLf85hHpzqHIQISW8eIPA', 'Smiting 4, Protection 11, Divine Favor 5, Deadly Arts 1, Shadow Arts 12')
			BuildInfoAddRow('Player', 'E/Me', 'OgVFwDKJL7Uk0n2wXlLoBgJwSwNF', 'Energy Storage 3, Air 2, Earth 12, Domination 11, Inspiration 5')
			Return True
		Case 'Vanguard'
			$buildinfo_title = 'VANGUARD - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone'
			$buildinfo_caption = 'Player rows: suggested skill 1-8 bars (optional, display only). Hero rows: Team tab default team.'
			$buildinfo_notes = 'Vanguard title farm' & @CRLF & _
			'Area: Dalada Uplands (Vanguard title)'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'Voltaic'
			$buildinfo_title = 'VOLTAIC - BUILDS'
			$buildinfo_summary = 'Any primary: the bot uses the bar matching your profession when it has one  |  Heroes: 7-hero team (Team tab default, display only)  |  Uses consets if available; uses a summoning stone, uses consumables if available'
			$buildinfo_caption = 'Player rows: suggested builds (optional). Hero rows: Team tab default team.'
			$buildinfo_notes = 'For best results, have:' & @CRLF & _
			'- completed the EotN story once' & @CRLF & _
			'- a full and efficient 7-hero team, with Frozen Soil on one hero' & @CRLF & _
			'- a build that can be run from skill 1 to 8 (no complex combos or conditional skills)' & @CRLF & _
			'' & @CRLF & _
			'Builds:' & @CRLF & _
			'- Player: a simple skill 1-8 build, e.g. Assassin''s Promise (rows above; fill the optional slots yourself)' & @CRLF & _
			'- Player: a Paragon with Heroic Refrain is detected automatically (last Player row; Arias and Adrenaline variants also work); Signet of Spirits (SoS) also recommended' & @CRLF & _
			'- Heroes: an offensive Mesmerway team (7-, 5- or 3-hero) or a 3-hero balanced team; the default team above works' & @CRLF & _
			'' & @CRLF & _
			'Notes:' & @CRLF & _
			'- Area: Slaver''s Exile (Voltaic Spears)' & @CRLF & _
			'- In NM the bot takes 13 min (with cons) or 15 min (without cons) on average; runs stable without cons or summons' & @CRLF & _
			'- Not tested in HM.'
			BuildInfoAddRow('Player', 'N/A', 'OAdTUYD6VSBcXcBKmkKAAAAYLE', 'Death 12, Soul Reaping 8, Deadly Arts 10')
			BuildInfoAddRow('Player', 'E/A', 'OgdS4Z2Q7i2kLQxkAAAAIDAAA', 'Deadly Arts 12, Energy Storage 3')
			BuildInfoAddRow('Player', 'Me/A', 'OQdT4TAOQaBymcJYXMmEAAAQ0B', 'Deadly Arts 9, Fast Casting 8, Inspiration 8')
			BuildInfoAddRow('Player', 'P/X', 'OQCjUamLKTn19Y1YAh0b4ioYsYA', 'Spear 6, Command 11, Leadership 12')
			BuildInfoAddRow('Hero 1', 'N/P', 'OAljUwGopSUBHVyBoBVVbh4B1YA', 'Death 12, Soul Reaping 8, Command 10')
			BuildInfoAddRow('Hero 2', 'N/Rt', 'OAhjQoGYIP3hhWVVaO5EeDzxJ', 'Blood 10, Soul Reaping 8, Restoration 12')
			BuildInfoAddRow('Hero 3', 'Me/Mo', 'OQNEAqwD2ycC0AmupXOIDQEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 4', 'N/Rt', 'OAhjUwGYoSUBHVoBbhVVWbTODTA', 'Death 12, Soul Reaping 8, Restoration 10')
			BuildInfoAddRow('Hero 5', 'Me/Mo', 'OQNEAqwD2ycCwpmupXOIDcBQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			BuildInfoAddRow('Hero 6', 'Rt/X', 'OACiAyk8gNtePuwJ00ZOPLYA', 'Communing 12, Spawning Power 12')
			BuildInfoAddRow('Hero 7', 'Me/Mo', 'OQNEAqwD2ycCaCmupXOIDMEQj', 'Fast Casting 10, Domination 12, Inspiration 8, Healing 2')
			Return True
		Case 'War Supply Keiran'
			$buildinfo_title = 'WAR SUPPLY KEIRAN - BUILDS'
			$buildinfo_summary = 'Any primary  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = '- This bot does not need any specific builds for main character or heroes' & @CRLF & _
			'- Only main character enters Auspicious Beginnings mission and is assigned Keiran Thackerays build for the duration of the quest' & @CRLF & _
			'You just need the Keirans Bow which Gwen gives when the right dialog ID is sent to Guild Wars client' & @CRLF & _
			'You do not need to have progress in Guild Wars Beyond campaign to be able enter this mission (even when these dialog options are not visible)' & @CRLF & _
			'Only Krytan chests in Auspicious Beginnings quest which may have useless loot' & @CRLF & _
			'in Auspicious Beginnings location, the agent ID of Player is always assigned to 2 (can be accessed in GWToolbox)' & @CRLF & _
			'in Auspicious Beginnings location, the agent ID of Miku is always assigned to 3 (can be accessed in GWToolbox)' & @CRLF & _
			'hexadecimal code of dialog id to start Auspicious Beginnings quest' & @CRLF & _
			'proceeding with the quest, second dialogs can be safely skipped to speed up farm runs' & @CRLF & _
			'loop to wait out in-game countdown to exit quest automatically' & @CRLF & _
			'check to prevent data races when exited quest after doing above map check' & @CRLF & _
			'other important skills casted by foes in Auspicious Beginnings quest that are easy to interrupt' & @CRLF & _
			'or another important skills casted by foes in Auspicious Beginnings quest that are easy to interrupt' & @CRLF & _
			'- (Weapon Slot-3) Shortbow +15/-5 vamp +5 armor is the best weapon' & @CRLF & _
			'- (Weapon Slot-4) Keirans Bow' & @CRLF & _
			'- Ideal character is warrior with 5x Knights Insignias and the Absorption -3 superior rune and 4 runes each of restoration/recovery/clarity/purity' & @CRLF & _
			'- When in Keiran Thackerays disguise, armor is 70, health is 600 and energy is 25' & @CRLF & _
			'- Consumables, insignias, runes, weapon upgrade components will not change health, energy, or attributes; they will otherwise work as expected (e.g. they will increase armor rating)' & @CRLF & _
			'You just need the Keirans Bow which Gwen gives when the right dialog ID is sent to Guild Wars client' & @CRLF & _
			'hexadecimal code of dialog ID to receive keirans bow' & @CRLF & _
			'start a dialog with Gwen and send a packet for receiving Keiran Bow' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- (Weapon Slot-3) Shortbow +15/-5 vamp +5 armor is the best weapon' & @CRLF & _
			'- (Weapon Slot-4) Keirans Bow' & @CRLF & _
			'- Ideal character is warrior with 5x Knights Insignias and the Absorption -3 superior rune and 4 runes each of restoration/recovery/clarity/purity' & @CRLF & _
			'- When in Keiran Thackerays disguise, armor is 70, health is 600 and energy is 25' & @CRLF & _
			'- Consumables, insignias, runes, weapon upgrade components will not change health, energy, or attributes; they will otherwise work as expected (e.g. they will increase armor rating)' & @CRLF & _
			'- This bot does not need any specific builds for main character or heroes' & @CRLF & _
			'- Only main character enters Auspicious Beginnings mission and is assigned Keiran Thackerays build for the duration of the quest' & @CRLF & _
			'' & @CRLF & _
			'Any character can go into Auspicious Beginnings mission if you send the right dialog ID (already in script) to Guild Wars client' & @CRLF & _
			'You just need the Keirans Bow which Gwen gives when the right dialog ID is sent to Guild Wars client' & @CRLF & _
			'You do not need to have progress in Guild Wars Beyond campaign to be able enter this mission (even when these dialog options are not visible)' & @CRLF & _
			'This bot is useful for farming War Supplies, festival items, platinum and Ebon Vanguard reputation' & @CRLF & _
			'' & @CRLF & _
			'Quest: Auspicious Beginnings (War Supplies, festive items, gold, Vanguard points)'
			Return True
		Case 'Zodiac'
			$buildinfo_title = 'ZODIAC - BUILDS'
			$buildinfo_summary = 'Any primary  |  Heroes: set up the 1 heroes yourself (Team tab)  |  Uses consumables if available'
			$buildinfo_caption = 'Hero builds in the bot''s hero order (same as Team tab > Load Hero N Build).'
			$buildinfo_notes = '- A shield with the inscription Sleep Now in the Fire (+10 armor against fire damage)' & @CRLF & _
			'- A one hand weapon with +5 energy +20% enchantment duration' & @CRLF & _
			'- Sentry or Blessed insignias on all the armor pieces' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'For best results, have :' & @CRLF & _
			'- 16 in Expertise' & @CRLF & _
			'- 12 in Shadow Arts' & @CRLF & _
			'- 3 in Wilderness Survival' & @CRLF & _
			'- A shield with the inscription Sleep Now in the Fire (+10 armor against fire damage)' & @CRLF & _
			'- A one hand weapon with +5 energy +20% enchantment duration' & @CRLF & _
			'- Sentry or Blessed insignias on all the armor pieces' & @CRLF & _
			'- Cupcakes' & @CRLF & _
			'- A superior vigor rune' & @CRLF & _
			'This bot has a high failure rate - it is expected.' & @CRLF & _
			'- Sentry or Blessed insignias on all the armor pieces' & @CRLF & _
			'- Cupcakes' & @CRLF & _
			'Cupcake is mandatory - otherwise we do not lose aggro of dredges and we do not pack foes properly'
			BuildInfoAddRow('Player', 'R/A', 'OgcTcZ88Z6ukHRn5Aim84Q445AA', 'Expertise 12, Wilderness Survival 3, Shadow Arts 12')
			BuildInfoAddRow('Hero 1', 'P/Rt', 'OQijEqmMKOD7dMAwEfjBAAAaMA', 'Restoration 10, Command 12, Leadership 8')
			Return True
		Case 'Manual Mode'
			$buildinfo_title = 'MANUAL MODE'
			$buildinfo_summary = 'Any primary  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = 'This mode allows you to use BotsHub to:' & @CRLF & _
			'- open Xunlai Storage' & @CRLF & _
			'- run custom AutoIt instructions from the Manual input box on the Setup tab' & @CRLF & _
			'- enable or disable rendering without running anything special'
			Return True
		Case 'Storage'
			$buildinfo_title = 'STORAGE - BUILDS'
			$buildinfo_summary = 'Any primary  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = 'This runs the inventory management without having to run any specific bot.'
			Return True
		Case 'Tests'
			$buildinfo_title = 'TESTS - BUILDS'
			$buildinfo_summary = 'Any primary  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = 'This runs the RunTests function at the top of the TestSuite.au3 file, allowing you to run anything you want to test.'
			Return True
		Case 'TestSuite'
			$buildinfo_title = 'TESTSUITE - BUILDS'
			$buildinfo_summary = 'Any primary  |  No heroes'
			$buildinfo_caption = ''
			$buildinfo_notes = 'This runs a tests suite to verify some required behaviours from the Hub.'
			Return True
		Case Else
			$buildinfo_title = StringUpper($farm) & ' - BUILDS'
			$buildinfo_notes = 'No build notes for this selection.'
			Return True
	EndSwitch
EndFunc


Func BuildInfoStyleLabel($id, $color, $bold = False)
	If $bold Then GUICtrlSetFont($id, 8.5, 700)
	GUICtrlSetColor($id, $color)
	GUICtrlSetBkColor($id, $THEME_PANEL_BG)
	Return $id
EndFunc


Func BuildInfoCreate()
	$gui_buildinfo_empty1 = BuildInfoStyleLabel(GUICtrlCreateLabel($BUILDINFO_EMPTY_TITLE, 20, 200, 610, 20), $THEME_TEXT_DIM, True)
	GUICtrlSetStyle($gui_buildinfo_empty1, 0x0001) ; SS_CENTER
	$gui_buildinfo_empty2 = BuildInfoStyleLabel(GUICtrlCreateLabel($BUILDINFO_EMPTY_HINT, 20, 226, 610, 16), $THEME_TEXT_DISABLED)
	GUICtrlSetStyle($gui_buildinfo_empty2, 0x0001)

	$gui_buildinfo_title = BuildInfoStyleLabel(GUICtrlCreateLabel('', 20, 38, 400, 16), $THEME_ACCENT_GOLD, True)
	$gui_buildinfo_summary = BuildInfoStyleLabel(GUICtrlCreateLabel('', 20, 57, 610, 16), $THEME_TEXT_DIM)
	$gui_buildinfo_h_build = BuildInfoStyleLabel(GUICtrlCreateLabel('Build', 20, 76, 52, 16), $THEME_TEXT_DIM)
	$gui_buildinfo_h_prof = BuildInfoStyleLabel(GUICtrlCreateLabel('Prof.', 74, 76, 40, 16), $THEME_TEXT_DIM)
	$gui_buildinfo_h_code = BuildInfoStyleLabel(GUICtrlCreateLabel('Template code (click, Ctrl+A, Ctrl+C)', 118, 76, 200, 16), $THEME_TEXT_DIM)
	$gui_buildinfo_h_attrs = BuildInfoStyleLabel(GUICtrlCreateLabel('Attributes', 326, 76, 300, 16), $THEME_TEXT_DIM)
	$gui_buildinfo_hline = GUICtrlCreateLabel('', 20, 93, 610, 1)
	GUICtrlSetBkColor($gui_buildinfo_hline, $THEME_HEADER_ROW_BG)

	Local $i
	For $i = 0 To $BUILDINFO_MAX_ROWS - 1
		Local $y = 97 + 20 * $i
		$gui_buildinfo_role[$i] = BuildInfoStyleLabel(GUICtrlCreateLabel('', 20, $y + 2, 52, 16), $THEME_ACCENT_GOLD)
		$gui_buildinfo_proflbl[$i] = BuildInfoStyleLabel(GUICtrlCreateLabel('', 74, $y + 2, 40, 16), $THEME_TEXT)
		$gui_buildinfo_codeedit[$i] = GUICtrlCreateInput('', 118, $y, 200, 18, 0x0800) ; ES_READONLY
		GUICtrlSetColor($gui_buildinfo_codeedit[$i], $THEME_VALUE)
		GUICtrlSetBkColor($gui_buildinfo_codeedit[$i], $THEME_INPUT_BG)
		$gui_buildinfo_attrslbl[$i] = BuildInfoStyleLabel(GUICtrlCreateLabel('', 326, $y + 2, 304, 16), $THEME_TEXT_DIM)
	Next

	$gui_buildinfo_caption = BuildInfoStyleLabel(GUICtrlCreateLabel('', 20, 97, 610, 16), $THEME_TEXT_DISABLED)
	$gui_buildinfo_notes_title = BuildInfoStyleLabel(GUICtrlCreateLabel('FARM NOTES', 20, 117, 300, 16), $THEME_ACCENT_GOLD, True)
	$gui_buildinfo_notes_line = GUICtrlCreateLabel('', 20, 134, 610, 1)
	GUICtrlSetBkColor($gui_buildinfo_notes_line, $THEME_HEADER_ROW_BG)
	$gui_buildinfo_notes = GUICtrlCreateEdit('', 20, 139, 610, 297, BitOR($ES_MULTILINE, $ES_READONLY, $ES_AUTOVSCROLL, $WS_VSCROLL))
	GUICtrlSetColor($gui_buildinfo_notes, $THEME_TEXT)
	GUICtrlSetBkColor($gui_buildinfo_notes, $THEME_INPUT_BG)
	$gui_buildinfo_ready = True
	BuildInfoShow('')
EndFunc


Func BuildInfoSetVisible($id, $show)
	GUICtrlSetState($id, $show ? $GUI_SHOW : $GUI_HIDE)
EndFunc


Func BuildInfoShow($farm)
	If Not $gui_buildinfo_ready Then
		; data-only (tests): still load
		BuildInfoLoad($farm)
		Return
	EndIf
	Local $ok = BuildInfoLoad($farm)
	Local $i
	If Not $ok Then
		BuildInfoSetVisible($gui_buildinfo_empty1, True)
		BuildInfoSetVisible($gui_buildinfo_empty2, True)
		BuildInfoSetVisible($gui_buildinfo_title, False)
		BuildInfoSetVisible($gui_buildinfo_summary, False)
		BuildInfoSetVisible($gui_buildinfo_h_build, False)
		BuildInfoSetVisible($gui_buildinfo_h_prof, False)
		BuildInfoSetVisible($gui_buildinfo_h_code, False)
		BuildInfoSetVisible($gui_buildinfo_h_attrs, False)
		BuildInfoSetVisible($gui_buildinfo_hline, False)
		For $i = 0 To $BUILDINFO_MAX_ROWS - 1
			BuildInfoSetVisible($gui_buildinfo_role[$i], False)
			BuildInfoSetVisible($gui_buildinfo_proflbl[$i], False)
			BuildInfoSetVisible($gui_buildinfo_codeedit[$i], False)
			BuildInfoSetVisible($gui_buildinfo_attrslbl[$i], False)
		Next
		BuildInfoSetVisible($gui_buildinfo_caption, False)
		BuildInfoSetVisible($gui_buildinfo_notes_title, False)
		BuildInfoSetVisible($gui_buildinfo_notes_line, False)
		BuildInfoSetVisible($gui_buildinfo_notes, False)
		Return
	EndIf

	BuildInfoSetVisible($gui_buildinfo_empty1, False)
	BuildInfoSetVisible($gui_buildinfo_empty2, False)
	GUICtrlSetData($gui_buildinfo_title, $buildinfo_title)
	GUICtrlSetData($gui_buildinfo_summary, $buildinfo_summary)
	BuildInfoSetVisible($gui_buildinfo_title, True)
	BuildInfoSetVisible($gui_buildinfo_summary, True)

	Local $hasRows = $buildinfo_rowcount > 0
	BuildInfoSetVisible($gui_buildinfo_h_build, $hasRows)
	BuildInfoSetVisible($gui_buildinfo_h_prof, $hasRows)
	BuildInfoSetVisible($gui_buildinfo_h_code, $hasRows)
	BuildInfoSetVisible($gui_buildinfo_h_attrs, $hasRows)
	BuildInfoSetVisible($gui_buildinfo_hline, $hasRows)

	For $i = 0 To $BUILDINFO_MAX_ROWS - 1
		If $i < $buildinfo_rowcount Then
			Local $y = 97 + 20 * $i
			GUICtrlSetData($gui_buildinfo_role[$i], $buildinfo_role[$i])
			GUICtrlSetData($gui_buildinfo_proflbl[$i], $buildinfo_prof[$i])
			GUICtrlSetData($gui_buildinfo_codeedit[$i], $buildinfo_code[$i])
			GUICtrlSetData($gui_buildinfo_attrslbl[$i], $buildinfo_attrs[$i])
			GUICtrlSetPos($gui_buildinfo_role[$i], 20, $y + 2, 52, 16)
			GUICtrlSetPos($gui_buildinfo_proflbl[$i], 74, $y + 2, 40, 16)
			GUICtrlSetPos($gui_buildinfo_codeedit[$i], 118, $y, 200, 18)
			GUICtrlSetPos($gui_buildinfo_attrslbl[$i], 326, $y + 2, 304, 16)
			BuildInfoSetVisible($gui_buildinfo_role[$i], True)
			BuildInfoSetVisible($gui_buildinfo_proflbl[$i], True)
			BuildInfoSetVisible($gui_buildinfo_codeedit[$i], True)
			BuildInfoSetVisible($gui_buildinfo_attrslbl[$i], True)
		Else
			BuildInfoSetVisible($gui_buildinfo_role[$i], False)
			BuildInfoSetVisible($gui_buildinfo_proflbl[$i], False)
			BuildInfoSetVisible($gui_buildinfo_codeedit[$i], False)
			BuildInfoSetVisible($gui_buildinfo_attrslbl[$i], False)
		EndIf
	Next

	Local $yAfter = 97
	If $hasRows Then $yAfter = 97 + 20 * $buildinfo_rowcount + 1
	If $buildinfo_caption <> '' Then
		GUICtrlSetData($gui_buildinfo_caption, $buildinfo_caption)
		GUICtrlSetPos($gui_buildinfo_caption, 20, $yAfter, 610, 16)
		BuildInfoSetVisible($gui_buildinfo_caption, True)
		$yAfter += 20
	Else
		BuildInfoSetVisible($gui_buildinfo_caption, False)
	EndIf

	GUICtrlSetPos($gui_buildinfo_notes_title, 20, $yAfter, 300, 16)
	GUICtrlSetPos($gui_buildinfo_notes_line, 20, $yAfter + 17, 610, 1)
	Local $editH = 436 - ($yAfter + 22)
	If $editH < 80 Then $editH = 80
	GUICtrlSetPos($gui_buildinfo_notes, 20, $yAfter + 22, 610, $editH)
	GUICtrlSetData($gui_buildinfo_notes, $buildinfo_notes)
	GUICtrlSendMsg($gui_buildinfo_notes, 0xB1, 0, 0) ; EM_SETSEL
	BuildInfoSetVisible($gui_buildinfo_notes_title, True)
	BuildInfoSetVisible($gui_buildinfo_notes_line, True)
	BuildInfoSetVisible($gui_buildinfo_notes, True)
EndFunc
