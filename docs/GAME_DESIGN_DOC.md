# Game Design Document (GDD)

> **Last Updated:** June 2026
> **Status:** Active Development

---

## 1. Game Overview

| Field | Details |
|-------|---------|
| **Working Title** | ISHIMURA |
| **Genre** | Co-op Sci-Fi Survival Horror |
| **Platform** | Roblox |
| **Players** | 2–4 co-op |
| **Target Audience** | Roblox horror fans, ages 13+ |
| **Short Description** | You and your crew respond to a distress signal on an abandoned deep-space mining vessel. The crew has been slaughtered and mutated into Necromorphs. Survive. Find the exit. Aim for the limbs. |

---

## 2. Core Gameplay Loop

```
Explore dark corridors → Encounter Necromorphs → Aim for limbs to dismember
→ Manage scarce ammo/health → Revive teammates → Reach next checkpoint → Repeat
```

The tension comes from resource scarcity, enemy aggression, and the darkness of the ship.

---

## 3. Mechanics

### 3.1 Dismemberment System (Core Differentiator)
Each Necromorph has multiple independent hit zones with their own HP:
- **Body** — low damage, brief stagger only
- **Arms (x2)** — remove to disarm the enemy
- **Legs (x2)** — remove to cripple/crawl state
- **Head** — remove for instakill

Body-shot-only kills are intentionally inefficient. Players must aim strategically.

**Implementation:** Multiple `Part` hitboxes per enemy model, each tracked server-side with individual HP values.

### 3.2 Weapons (Engineering Tools)

| Weapon | Description | Best Used For |
|--------|-------------|---------------|
| **Plasma Cutter** | Precision single-shot laser beam | Limb targeting |
| **Ripper** | Launches a spinning saw blade | Crowd control, multi-limb hits |

Ammo drops are scarce and shared between players. Teamwork required.

### 3.3 Enemy AI (Necromorphs)
- Roam the ship on patrol paths when not aggroed
- Aggro triggers: line of sight OR proximity sound
- Pathfind to players using Roblox `PathfindingService`
- Behaviors change based on missing limbs:
  - No legs → crawls, slower but still bites
  - No arms → charges and headbutts
  - Full limbs → standard attack + lunge

### 3.4 Co-op System
- 2–4 players share the same map
- Downed players bleed out over 30 seconds — teammates can revive (hold E near body)
- If all players die → game over, return to checkpoint
- Shared ammo/health crate pool placed around the map

### 3.5 Atmosphere
- Near-total darkness — players have a small personal light radius
- Flickering lights built with `TweenService` on `PointLight` instances
- Spatial audio — enemy groans audible through walls, louder as they approach
- Minimal HUD — health shown on character suit glow (not a health bar)
- Scripted jumpscare moments at key locations

---

## 4. World / Map

**Setting:** The USG Ishimura — a colossal deep-space mining vessel, completely dark

**Key Locations (v1 scope):**
1. Airlock Entry / Crash Site — tutorial section
2. Engineering Deck — industrial corridors, first Necromorphs
3. Medical Bay — scattered bodies, resource caches
4. Reactor Core — final area, boss encounter

**Visual Style:** Industrial sci-fi, grimy metal, emergency red lighting, flickering terminals

---

## 5. Progression System

- No leveling — tension comes from scarcity, not stats
- Suit upgrades found in the environment (passive: more health, bigger light radius)
- Weapon upgrades: pick up schematic items that unlock attachments

---

## 6. Monetization Ideas

- [ ] **Game Pass: Survivor Pack** — extra starting ammo + flashlight skin
- [ ] **Developer Product: Revive Token** — instant team revive (not pay-to-win, just convenience)
- [ ] **VIP Server** — private session for friend groups

---

## 7. Art Style

- **Style:** Realistic-lean, dark sci-fi (as detailed as Roblox allows)
- **Color Palette:** Black, dark grey, emergency red, pale blue glow
- **Reference:** Dead Space (2008), Alien: Isolation
- **Enemy Design:** Mutated humanoids, limbs visible as separate model parts

---

## 8. Audio

- **Music:** Ambient industrial drone, no traditional BGM — silence is a tool
- **Key Sound Effects:**
  - Plasma Cutter beam + impact
  - Necromorph groan (distance-attenuated)
  - Limb-sever crunch
  - Heartbeat when low health
  - Teammate revive prompt chime
