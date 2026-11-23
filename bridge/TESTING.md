# BotsHub v38.12-bridge: how to test the bridge (reads only)

This build includes GWBridge. It is the same bot, plus one change: when it attaches to a game client, it loads
a small helper (GWBridge) into that client. Game *reads* (your position, energy, skill recharge, map, target, bags)
then come from the helper instead of many slow memory reads. Every *action* (moving, skills, talking, picking up,
using items) still goes through the normal GWA2 code, exactly like the classic build.

If anything about the bridge is wrong or missing, the bot falls back to normal (classic) GWA2 by itself, and the log
says so.

## Before you start

* **Never run GWToolbox++ or Py4GW in a client you test this on.** The bot checks for them. If it sees either one
  in the client, or GWToolbox.exe / Py4GW running at all, it will not load the bridge and runs classic. If one gets
  injected later, the bridge switches itself off. Still: keep them closed for the whole test.
* Use a throwaway or low-value character first.
* Run BotsHub as administrator, the same as always.

## Install (separate from any other copy)

1. Unzip `BotHub2.0_v38.12-bridge.zip` into a **new folder**, for example `C:\BotsHub-bridgeA\`. You get
   `C:\BotsHub-bridgeA\BotHub2.0\...`. Do not unzip it over another BotHub2.0 folder.
2. Copy over your own settings if you want them: your `conf` files (run configs, loot JSONs). This copy ships only the
   Default configs and Masterloot.json.
3. Check that `BotHub2.0\bridge\bin\` contains `GWBridge.dll` and `gwca.dll`. Both must stay together in that folder.
   Some antivirus tools quarantine DLLs that get loaded into other programs. If either file goes missing, the bot
   just runs classic and logs why.
4. Start `BotHub2.0\BotsHub.au3` with 32-bit AutoIt, as usual. The window title says **GW Bot Hub [v38.12-bridge]**.

## What to look for in the log

At start:

    BotsHub 2.0 v38.12-bridge (v10-improved) | AutoIt ...
    GWBridge test build v38.12-bridge: the bridge starts when the bot attaches to a game client (reads only, commands stay classic GWA2)

When it attaches to your character, you get exactly one of these:

    GWBridge: ACTIVE - game reads through the bridge, commands classic GWA2 (pid 1234, GWBridge 0.1 ..., GW build 38xxx)
    GWBridge: OFF - classic GWA2 for everything. Reason: ...

Common OFF reasons:
* `GWToolboxdll.dll is loaded in the client` / `Py4GW... is loaded` / `GWToolbox.exe is running`: close those tools,
  restart the game client, try again.
* `DLL error 4: GW::Initialize failed`: the helper can't find its way around this game version. Send the line to AMG (see Feedback in README.md).
* `DLL loaded but no frame published within 8000 ms`: the helper loaded, but its per-frame hook never ran. Send the line to AMG (see Feedback in README.md).
* `DLL not found`: `bridge\bin\GWBridge.dll` is missing (antivirus?).

While running, you only see more bridge lines if something changes:

    GWBridge: no frames from the game for 2 s - classic GWA2 until frames come back
    GWBridge: frames again - reads through the bridge
    GWBridge: STOPPED (...) - classic GWA2 from now on

A short "no frames" during a very long loading screen, or with the game minimised, is fine if "frames again"
follows. STOPPED means the bridge is off for the rest of that session; the bot keeps going on classic.

## The test, step by step

1. **Classic baseline.** Run your live v38.9 for one short run on the same character so you know what "normal" looks
   like (run time, loot, no errors).
2. **Attach.** Start the bridgeA bot in its own folder and select your character in an outpost. Look for
   `GWBridge: ACTIVE`. If you get OFF instead, stop here and send the line to AMG.
3. **Sanity in town.** Stay in the outpost for a minute. The game must stay smooth (no stutter, no FPS drop) and the
   bot's Main tab must show the right character, map and values.
4. **Map change.** Travel to another outpost or start a run. Watch the loading screen: no crash, no freeze. After
   it, no `STOPPED` line (one `no frames` + `frames again` pair is OK).
5. **Bags.** In town, move or sell an item, then check that the Items panel and inventory numbers update like they
   do in v38.9.
6. **One short farm run.** One Pongmei or Tasca run (or your usual farm). Same behaviour as v38.9: skills used at the
   right time, same route, same loot picked up. It should feel the same or snappier, especially skill timing.
7. **Long run.** Let it loop 30 minutes or more across several map changes. No crash, no freeze, no `STOPPED` line,
   and run times about the same as or better than classic.
8. **Commands stay classic.** Nothing to switch on. Movement, skills, dialogs and pickups in this build are the
   normal GWA2 ones. If anything about *actions* behaves differently from v38.9, that's worth telling me.
9. **Clean exit.** Close BotsHub while the game keeps running. The game must keep running normally. (The bot
   unloads the helper on exit. With Process Explorer you can check that `GWBridge.dll` is gone from Gw.exe;
   `gwca.dll` should be gone too.)
10. **Two clients (optional).** With two game clients, attach to one, then restart BotsHub and attach to the other.
    Each attach gives its own `GWBridge: ACTIVE` line for that client's pid.

Stop at the first crash, freeze or odd behaviour. Send the log file to AMG from `BotHub2.0\logs\` and tell me what you
were doing.

## Turning the bridge off (without uninstalling)

Open `BotHub2.0\bridge\au3\GWBridge_BotsHub.au3` and find this line:

    If GWBridge_Start($pid, $dllDir, $dllName) Then

Change it to:

    If False And GWBridge_Start($pid, $dllDir, $dllName) Then

The bot then logs `GWBridge: OFF` and runs fully classic, without loading anything into the game. Even simpler:
rename or delete the `bridge\bin\GWBridge.dll` file. The bot logs `GWBridge: OFF ... DLL not found` and runs classic.

(The internal switch is `$g_GWB_Hook`. This build sets it to True only after the bridge is up, and back to False if
the bridge stops. `$g_GWB_HookCommands` is False and nothing in this build turns it on.)

## Rolling back

This build lives in its own folder, so rolling back just means **using your live v38.9 folder again** and
deleting `C:\BotsHub-bridgeA\` whenever you like. Nothing was changed in your live bot. If a game client still has
the helper loaded (e.g. after a BotsHub crash), restarting that game client clears it.
