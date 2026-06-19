# ISHIMURA

> **Co-op Sci-Fi Survival Horror on Roblox** | 2–4 players

You and your crew respond to a distress signal on an abandoned deep-space mining vessel. The crew has been slaughtered and mutated into Necromorphs. Survive. Find the exit. **Aim for the limbs.**

---

## Status: Phase 1 — Dismemberment Prototype

- [x] Game concept finalized
- [x] GitHub repo + docs set up
- [x] MCP connected (Claude ↔ Roblox Studio)
- [ ] **Phase 1: Dismemberment** ← IN PROGRESS
- [ ] Phase 2: Enemy AI
- [ ] Phase 3: Co-op Systems
- [ ] Phase 4: Map Building
- [ ] Phase 5: HUD & UI
- [ ] Phase 6: Polish & Launch

See [Roadmap](docs/ROADMAP.md) for step-by-step build checklist.

---

## Docs

| Document | What's in it |
|----------|-------------|
| [Roadmap](docs/ROADMAP.md) | Step-by-step build guide, Phase 0 → Launch, checkboxes |
| [Game Design Doc](docs/GAME_DESIGN_DOC.md) | Mechanics, dismemberment tables, weapons, map, tech architecture |
| [Team Roles](docs/TEAM_ROLES.md) | Who owns what |

---

## Core Mechanics

- **Dismemberment combat** — shoot limbs, not center mass. Body shots do 5 damage. Limb shots do 18.
- **2–4 player co-op** — revive downed teammates, share scarce ammo
- **Necromorph AI** — pathfinding enemies that change behavior when limbs are severed
- **Atmospheric horror** — near-total darkness, spatial audio, no health bar (suit color = HP)

---

## Roblox Game Link

> _Add Roblox experience URL once the place is published._

---

## How to Contribute

1. Read [Game Design Doc](docs/GAME_DESIGN_DOC.md) for the full vision
2. Check [Roadmap](docs/ROADMAP.md) for the current step
3. Add yourself to [Team Roles](docs/TEAM_ROLES.md)
4. Claude handles all scripting via MCP — builders focus on map geometry and playtesting
