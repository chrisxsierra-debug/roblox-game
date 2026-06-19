# ISHIMURA — Build Roadmap
## Step-by-Step Development Guide

> 🤖 = Claude does it via MCP (scripts injected directly into Studio)
> 🔨 = You do it in Roblox Studio
> 📁 = Git commit checkpoint

---

## Current Status: Starting Phase 1 — Dismemberment Prototype

- [x] Game concept finalized
- [x] GitHub repo set up
- [x] MCP connected (Claude ↔ Roblox Studio)
- [x] Studio folder structure planned
- [ ] **Phase 1: Dismemberment** ← YOU ARE HERE
- [ ] Phase 2: Enemy AI
- [ ] Phase 3: Co-op Systems
- [ ] Phase 4: Map Building
- [ ] Phase 5: HUD & UI
- [ ] Phase 6: Polish & Launch

---

## PHASE 0 — Studio Setup
> Complete before any code.

- [x] **0.1** 🔨 Open Roblox Studio → New → Baseplate → rename to `ISHIMURA`
- [x] **0.2** 🔨 Game Settings → Security → **Allow HTTP Requests ON** → Save
- [x] **0.3** 🔨 File → Save to Roblox (get a Place ID)
- [ ] **0.4** 🤖 Claude creates all service folders and RemoteEvents via MCP
- [ ] **0.5** 🔨 Verify folders in Explorer, report anything missing

---

## PHASE 1 — Dismemberment Prototype
> Goal: Shoot a stationary Necromorph → limbs fly off → enemy dies. Nothing else yet.

- [ ] **1.1** 🤖 Create `WeaponConfig` ModuleScript (damage values, ammo counts)
- [ ] **1.2** 🤖 Create `DismembermentModule` ModuleScript (limb HP, sever logic)
- [ ] **1.3** 🤖 Create `WeaponHandler` server Script (validates hits, applies damage)
- [ ] **1.4** 🤖 Create `WeaponController` LocalScript (raycast on click, fires RemoteEvent)
- [ ] **1.5** 🔨 Build test Necromorph model in Studio:
  - Model with `HumanoidRootPart`, `Humanoid`, `Torso`, `Head`, `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg`
  - Each limb Part: welded to Torso, `IsLimb = true` attribute
  - Tag model with CollectionService tag `"Necromorph"`
- [ ] **1.6** 🔨 Create `PlasmaCutter` Tool in `ReplicatedStorage/Assets/Weapons/` with a `Handle` Part
- [ ] **1.7** 🤖 Add firing LocalScript inside PlasmaCutter Tool (sound + visual feedback)
- [ ] **1.8** 🔨 Place Necromorph in Workspace, put PlasmaCutter in StarterPack, press Play
- [ ] **1.9** 🔨 Playtest checklist:
  - [ ] Shoot arm → arm flies off
  - [ ] Shoot leg → leg flies off
  - [ ] Body shots barely damage (5 per hit)
  - [ ] All limbs removed → enemy dies and disappears
  - [ ] No errors in Output window

📁 `"Phase 1: Dismemberment system working"`

---

## PHASE 2 — Enemy AI
> Goal: Necromorph chases, attacks, and reacts to lost limbs.

- [ ] **2.1** 🤖 Create `EnemyConfig` ModuleScript (speed, aggro range, damage per type)
- [ ] **2.2** 🤖 Create `NecromorphAI` Script (Patrol → Aggro → Attack state machine using PathfindingService)
- [ ] **2.3** 🤖 Create `PlayerDamageHandler` Script (server-side damage to players)
- [ ] **2.4** 🔨 Place `NecromorphAI` Script **inside** the Necromorph Model in Explorer
- [ ] **2.5** 🔨 Add 2–3 invisible Parts named `Waypoint1`, `Waypoint2` near the enemy
- [ ] **2.6** 🔨 Playtest checklist:
  - [ ] Enemy patrols waypoints when you're far away
  - [ ] Walk within 40 studs → enemy chases you
  - [ ] Enemy catches you → HP goes down
  - [ ] Shoot both legs → enemy crawls (slow)
  - [ ] Shoot both arms → enemy headbutts instead of grabbing

📁 `"Phase 2: Necromorph AI working"`

---

## PHASE 3 — Co-op Systems
> Goal: 2–4 players, downed state, revive, shared ammo, game over.

- [ ] **3.1** 🤖 Create `ReviveSystem` Script (downed state, 30s bleedout timer, revive logic)
- [ ] **3.2** 🤖 Create `RevivePrompt` LocalScript (proximity E-hold UI, progress bar)
- [ ] **3.3** 🤖 Add ammo tracking to `WeaponHandler` (per-player ammo table, pickup system)
- [ ] **3.4** 🤖 Create `GameManager` Script (tracks alive players, checkpoints, win/loss state)
- [ ] **3.5** 🤖 Create `DataStoreManager` Script (saves checkpoint on reach, loads on rejoin)
- [ ] **3.6** 🔨 Test with 2 players (Test tab → Local Server → 2 Clients):
  - [ ] Player 1 downed → timer counts down
  - [ ] Player 2 holds E near Player 1 → revived at 50 HP
  - [ ] Both downed → Game Over screen
  - [ ] Ammo pickup increases count
  - [ ] Shoot until empty → gun stops firing
  - [ ] Step on Checkpoint Part → saves (check Output)

📁 `"Phase 3: Co-op, ammo, and checkpoints working"`

---

## PHASE 4 — Map Building
> Goal: All 4 zones playable start to finish.

- [ ] **4.1** 🔨 Build **Airlock Entry** (tutorial, no enemies):
  - Dark corridor 20L × 6W × 8H studs
  - Crashed hallway with debris to jump over
  - Checkpoint Part at end
  - Red PointLights on walls, 2–3 tagged `FlickerLight`
- [ ] **4.2** 🔨 Build **Engineering Deck** (Zone 1):
  - Engine Room A: 2 Necromorphs, patrol waypoints
  - Maintenance tunnel (tight, forces care)
  - Ammo crate room
  - Engine Room B: 2 Standard + 1 Crawler
  - Checkpoint 2
- [ ] **4.3** 🔨 Build **Medical Bay** (Zone 2):
  - Reception: 4 beds, 2 hidden Crawlers
  - Surgery room with health kit pickup
  - Morgue with scripted jumpscare (invisible enemy activates on proximity)
  - Checkpoint 3
- [ ] **4.4** 🔨 Build **Reactor Core** (final zone):
  - Circular room 60 studs diameter
  - Console in center (ProximityPrompt: "Activate Reactor")
  - Boss wave on activation: 3 Standard + 2 Crawlers from vents
  - Survive 60s → escape pod door opens → Victory trigger
- [ ] **4.5** 🤖 Create `AtmosphereController` LocalScript (flickering lights via TweenService, personal flashlight toggled with F)
- [ ] **4.6** 🔨 Add `Sound` inside each Necromorph Torso (groan SFX, RollOffMaxDistance=50, Looped=true)
- [ ] **4.7** 🔨 Full run playtest (2–4 players):
  - [ ] Airlock → Reactor completable in ~20 min
  - [ ] Flickering lights work
  - [ ] Enemy audio fades with distance
  - [ ] Boss wave spawns correctly
  - [ ] Victory screen triggers

📁 `"Phase 4: Full map playable end-to-end"`

---

## PHASE 5 — HUD & UI
> Goal: Looks and feels like a real game.

- [ ] **5.1** 🤖 Create `SuitHUD` ScreenGui (ammo bottom-right, team helmets top-left, 4-dot crosshair center)
- [ ] **5.2** 🤖 Create `SuitGlowController` LocalScript (HP → suit color: blue/yellow/red + heartbeat SFX)
- [ ] **5.3** 🤖 Create `StartScreen` ScreenGui ("ISHIMURA" title, "JOIN CREW" button, ambient audio)
- [ ] **5.4** 🤖 Create `GameOverScreen` ScreenGui (fade to black, "The ship claims another crew...", Try Again / Leave)
- [ ] **5.5** 🤖 Create `VictoryScreen` ScreenGui ("ESCAPE SUCCESSFUL", run time, Play Again)

📁 `"Phase 5: HUD, suit glow, and screens complete"`

---

## PHASE 6 — Polish & Launch
> Goal: Content creator ready. Ship it.

- [ ] **6.1** 🤖 Create `Ripper` weapon (physical spinning disc projectile, multi-limb hits)
- [ ] **6.2** 🤖 Create suit upgrade pickup system (Heavy Suit +25HP, Enhanced Optics wider flashlight)
- [ ] **6.3** 🤖 Create `Monetization` Script (Survivor Pack game pass, Revive Token dev product)
- [ ] **6.4** 🔨 Performance pass: target 30+ FPS with 4 players (merge Unions, disable CastShadow on props, cap enemies at 6 active)
- [ ] **6.5** 🔨 3 full playtests: Solo / Duo / Full Squad — bug list → fix
- [ ] **6.6** 🔨 Publish: set Public, write description, set thumbnail, genre = Horror

📁 `"Launch: ISHIMURA v1.0 published"`
