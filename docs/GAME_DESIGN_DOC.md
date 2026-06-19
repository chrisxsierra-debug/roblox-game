# Game Design Document — ISHIMURA

> **Status:** Prototyping (Phase 1)

---

## Overview

| Field | Details |
|-------|---------|
| **Title** | ISHIMURA |
| **Genre** | Co-op Sci-Fi Survival Horror |
| **Platform** | Roblox |
| **Players** | 2–4 co-op |
| **Pitch** | You and your crew respond to a distress signal on an abandoned deep-space mining vessel. The crew has been slaughtered and mutated into Necromorphs. Survive. Find the exit. Aim for the limbs. |

---

## Core Gameplay Loop

```
Move through dark corridor
  → Hear Necromorph groan (audio cue)
  → Encounter enemy → AIM FOR LIMBS, not body
  → Limbs removed → enemy crippled or killed
  → Scavenge ammo/health from crates
  → Revive downed teammate if needed
  → Reach checkpoint → repeat
```

**Win:** All 4 zones cleared, Reactor Core activated, team reaches escape pod.
**Loss:** All players downed simultaneously → Game Over → return to last checkpoint.

---

## Dismemberment System

The core differentiator. Every Necromorph has 6 independent hit zones with their own HP:

| Part | HP (Standard) | HP (Crawler) | Effect when destroyed |
|------|--------------|--------------|----------------------|
| Head | 20 | 15 | Instakill |
| LeftArm | 35 | 25 | Disarms enemy |
| RightArm | 35 | 25 | Disarms enemy |
| LeftLeg | 40 | 0 | Cripples (crawl) |
| RightLeg | 40 | 0 | Cripples (crawl) |
| Torso | 200 | 120 | Death only when depleted |

Body shots do only 5 damage per hit. Limb shots do 18. Players **must** aim for limbs.

**Implementation:** Each limb is a separate `Part` welded to the Torso. HP stored as Attributes. Server-side only.

---

## Weapons

| Weapon | Damage/Limb | Damage/Body | Ammo | Cooldown | Best For |
|--------|-------------|-------------|------|----------|----------|
| Plasma Cutter | 18 | 5 | 12 | 0.4s | Precision limb shots |
| Ripper | 30 | 8 | 6 | 1.2s | Crowd control, multi-limb |

Ammo is scarce and shared between players. Cooperation required.

---

## Enemy Types

**Standard Necromorph**
- Walk speed: 16 studs/s (6 when legless)
- Aggro range: 40 studs
- Attack damage: 15 HP per hit, 1.5s cooldown
- Behavior: Patrol → Aggro → Attack. Reacts to missing limbs.

**Crawler** (legless from spawn)
- Crawl speed: 14 studs/s (fast on the ground — more dangerous than it looks)
- Aggro range: 25 studs
- Attack damage: 20 HP per hit, 1.0s cooldown
- Behavior: Hides under objects, activates when player is close

---

## Co-op System

- **Downed state:** HP reaches 0 → can't move, 30s bleedout timer begins
- **Revive:** Living player holds E within 6 studs for 3 seconds → revived at 50 HP
- **Game over:** All players downed simultaneously
- **Checkpoints:** Saved to DataStore on reach. Team respawns here on game over.

---

## Map — 4 Zones

| Zone | Enemies | Key Feature |
|------|---------|-------------|
| Airlock Entry | None | Tutorial, atmosphere intro |
| Engineering Deck | 2 Standard + 1 Crawler | First combat, tight corridors |
| Medical Bay | 3 Crawlers + 1 Standard | Jumpscare, wider rooms |
| Reactor Core | Boss wave (3+2) | Final escape sequence |

---

## Technical Architecture

```
ServerScriptService/ISHIMURA/
  Modules/
    WeaponConfig         ← damage, ammo, cooldowns
    DismembermentModule  ← limb HP tables, sever logic
    EnemyConfig          ← speed, aggro, attack values
  WeaponHandler          ← server: validates hits, routes damage
  NecromorphAI           ← per-enemy state machine
  PlayerDamageHandler    ← server: applies damage to players
  ReviveSystem           ← downed/revive/bleedout
  GameManager            ← win/loss, checkpoints
  DataStoreManager       ← checkpoint persistence

ReplicatedStorage/Remotes/
  FireWeapon, LimbDestroyed, PlayerDowned,
  RevivePlayer, UpdateSuitGlow

StarterPlayerScripts/
  WeaponController       ← raycast on click, fires FireWeapon
  SuitGlowController     ← HP → suit color feedback
  RevivePrompt           ← proximity E-hold UI
  AtmosphereController   ← flickering lights, personal flashlight
```

**Rule:** All state changes (damage, death, revive, pickups) run server-side. Clients handle input and visual feedback only.

---

## Art Direction

- **Style:** Dark industrial sci-fi — grimy metal, exposed pipes, emergency lighting
- **Palette:** Black, dark grey, emergency red accents, pale blue suit/terminal glow
- **Lighting:** Near-total darkness. Players have a narrow personal flashlight (30° beam). Flickering PointLights on walls.
- **HUD:** Minimal — no health bar. Suit color = health. Ammo number bottom-right. Team helmets top-left.

---

## Audio

| Sound | Trigger |
|-------|---------|
| Industrial ambient drone | Always looping |
| Heartbeat | HP < 30%, pitch rises with damage |
| Necromorph groan | Enemy within 50 studs (3D spatial) |
| Limb sever crunch | Limb HP → 0 |
| Plasma Cutter fire | Weapon fired |
| Revive chime | Revive complete |
| Jumpscare sting | Scripted trigger zones |
