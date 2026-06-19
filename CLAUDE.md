# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repo is the planning and documentation hub for **ISHIMURA** — a 2–4 player co-op sci-fi survival horror game on Roblox, inspired by Dead Space. No Lua/Roblox code lives here yet; all scripts will be written in Roblox Studio. This repo tracks the game design, roadmap, and team coordination via markdown docs.

**Current phase:** Phase 0 (Planning). See [docs/ROADMAP.md](docs/ROADMAP.md).

## Repository Structure

```
docs/
  GAME_DESIGN_DOC.md   — Full game design: mechanics, weapons, enemy AI, map, art/audio
  ROADMAP.md           — Phase 0–4 milestones with checkboxes
  TEAM_ROLES.md        — Team roster and Claude scripting responsibilities
README.md              — Project pitch and contribution guide
```

## Working in This Repo

All meaningful changes are commits to these markdown docs. After editing any file:

```
git add .
git commit -m "<description>"
git push origin master
```

The remote is `https://github.com/chrisxsierra-debug/roblox-game` and `gh` CLI is authenticated as `chrisxsierra-debug`.

## Roblox Scripting Context

When asked to write Lua scripts for this game, the key systems and their intended architecture are:

- **Dismemberment system** — Server-side `Script` inside each Necromorph model. Each limb is a separate `Part` with its own HP value tracked in a module. Hit detection uses `Raycast` from the client weapon, firing a `RemoteEvent` to the server to apply damage to the correct limb part.
- **Enemy AI** — `Script` using `PathfindingService` for navigation. State machine: `Patrol → Aggro → Attack`. Behavior changes based on which limbs are missing (stored in the enemy's module state).
- **Weapons** — `LocalScript` handles client-side aim/fire input and visual effects; a `RemoteEvent` (`FireWeapon`) sends the ray hit data to the server for authoritative damage.
- **Co-op revive** — Proximity check via `magnitude` in a `LocalScript`; hold-progress UI fires a `RemoteEvent` to server on completion. Downed state managed server-side.
- **Flickering lights** — `Script` using `TweenService` on `PointLight.Brightness` with randomized intervals per light instance.
- **Checkpoints/DataStore** — `Script` in `ServerScriptService` using `DataStoreService` to save player progress between sessions.

All game logic that affects state (damage, death, revive, pickups) must run server-side. Clients only handle input and visual feedback.
