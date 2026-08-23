# [TF2] Admin Cheats (tfhacks)

Per-player hack-style cheat features for Team Fortress 2, restricted to admins.
Intended for your own server: fun rounds, training/practice, testing, and messing
around with friends. Every feature is toggled per-target from an admin menu or
console command, so you can give one player homing rockets without touching anyone else.

## Features

| Feature | What it does |
|---|---|
| Silent Aimbot | Shots snap to the nearest enemy head within a 30-degree FOV; viewangle stays untouched |
| Infinite Ammo | Clip + reserve never run dry |
| Always Crits | Permanent crit boost |
| Rapid Fire | Attack speed cranked up |
| Kill Aura | Damages every visible enemy within 600 units for 500 dmg |
| Homing Projectiles | Rockets/pipes/arrows/etc steer toward the closest enemy (see notes) |
| Speed Hack | 1.5x move speed (custom multiplier via sm_speedhack) |
| Invisibility | Player model hidden |
| Infinite Health | Health pinned to max |
| Godmode | m_takedamage = 0 |
| Noclip | Fly through the world |
| No Fall Damage | Self-explanatory |
| One-Shot Kill | Any hit is lethal |
| Infinite Cloak | Cloak meter pinned at 100 |
| Instant Uber | Medigun charge pinned at full |
| Hacked Stats | 5x outgoing damage, 1.75x projectile speed |
| Instant Lvl3 Buildings | Engineer buildings spawn as maxed sentries (lvl3 model/stats) |
| Instant Charge | Demo shield meter, sniper charge, medigun uber, and Huntsman draw all fill instantly |
| Auto Strafe | Perfect air-strafing while airborne - just move your mouse |
| Infinite Money | MvM credits pinned to 1,000,000 (MvM only) |
| Infinite Canteen | Canteen charge meters never drain (MvM only) |
| Cash Magnet | Every dropped cash pack on the map teleports straight to you, unlimited range (MvM only) |

## Commands

```
sm_hacks <target> [feature|all] [0/1]   Main command - opens menu if no args
sm_cheats                               Alias of sm_hacks
sm_speedhack <target> <multiplier>      Set custom speed multiplier
sm_tp                                   Teleport to where you are looking
sm_respawnme                            Instant respawn
sm_thirdperson                          Force third person camera
sm_firstperson                          Restore first person camera
sm_hdebug                               Toggle verbose homing debug output
sm_givecash <target|all> <amount>       Grant MvM credits to players
sm_purgerobots                          Kill every robot bot on the field
sm_killtank                             Instantly destroy the tank
sm_cashrain <count>                     Spawn up to 50 cash packs around you
sm_resetbomb                            Send the bomb back to the hatch
```

`feature` accepts the short name shown by the menu, e.g.:

```
sm_hacks @me homing 1
sm_hacks @me aimbot 1
sm_hacks @me all_on        (turns everything on at 1.5x speed)
sm_hacks @me all_off       (everything off)
```

Access requires the `ADMFLAG_CHEATS` flag ("o" flag).

## Requirements

- SourceMod 1.12+
- **[vphysics](https://forums.alliedmods.net/showthread.php?t=197860) extension (required)** - the plugin refuses to load without it and prints an error telling you where to put it

## Installation

1. Grab `tfhacks.smx` from the [Releases page](../../releases), or compile `scripting/tfhacks.sp` yourself with spcomp
2. Drop `tfhacks.smx` into `addons/sourcemod/plugins/`
3. Reload: `sm plugins reload tfhacks`

No gamedata files needed - everything is done through netprops and entity props.

## Technical notes

The interesting part is the homing system:

- Projectiles are registered in `OnEntityCreated` and processed on `OnGameFrame`
  via entity references (arrows don't reliably fire Think hooks).
- vphysics-driven projectiles (pipes, arrows) report zero `m_vecAbsVelocity`,
  so velocity is estimated from position deltas between frames as a fallback.
- Steering recomputes direction every frame toward the target's body center
  (eye position for arrows), preserving launch speed.
- Velocity is applied through angles + `TeleportEntity` because TF2's rocket
  code recomputes velocity from stored angles each tick - writing raw vectors
  alone gets overwritten.

## Disclaimer

For use on servers you own/administer. Using this against players who didn't
opt in makes you a bad person.
