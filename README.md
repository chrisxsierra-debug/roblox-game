# Funnel Runners: Storm Chasers (Roblox)

An intense multiplayer storm-chasing Roblox game inspired by *Funnel Runners* and real-world extreme meteorology.

## Features
- **Dynamic Tornado Simulation**:
  - Realistic Rankine combined vortex physics (inner core rigid rotation, outer potential inflow).
  - Multi-tier dynamic wind field with structural damage, debris launching, and player pull physics.
  - Custom rotating mesocyclone supercell funnel mesh with ground dust ring and debris cloud.
- **Drivable Interceptor & Scout Vehicles**:
  - Chassis-rigged `VehicleSeat` scout truck.
  - Functional toggles for emergency strobe lightbars, headlights, and warning sirens.
- **Underground Storm Bunkers**:
  - Reinforced shelter safe-zones powered by `ZonePlus`.
  - Zero wind and complete damage immunity while inside bunkers.
- **Doppler Weather Radar**:
  - In-vehicle and on-screen CRT Doppler Radar HUD showing storm position, track, intensity, and distance.
- **High-Visibility Daylight Atmosphere**:
  - Dramatic supercell daylight lighting with green/gray atmospheric tint and ominous cloud cover.

---

## Team Collaboration & Live Sync Setup (Rojo + GitHub)

This repository is set up with [Rojo](https://rojo.space/) so you and your team can collaborate on code using Git and have all changes sync directly into Roblox Studio in real time.

### 1. Prerequisites (For You and Your Friend)
1. **Roblox Studio**: Installed on your PC.
2. **Rojo Studio Plugin**:
   - Open Roblox Studio -> **Plugins** -> **Manage Plugins** -> Search for **Rojo 7** and install it (or download from [rojo.space](https://rojo.space/)).
3. **Git**: Installed on your PC ([git-scm.com](https://git-scm.com/)).
4. **Rojo CLI**:
   - Installed via [Rojo releases](https://github.com/rojo-rbx/rojo/releases) or Cargo (`cargo install rojo`).

---

### 2. Super Easy 1-Click Start (Automatic Live Sync)

1. **Clone the repository**:
   ```bash
   git clone https://github.com/chrisxsierra-debug/roblox-game.git
   cd roblox-game
   ```

2. **Double-click `START-ALL-SYNC.bat`**:
   - Automatically starts the **Rojo live sync server**.
   - Automatically starts the **GitHub auto-sync watcher** (polls for teammate commits every 10s).
   - Automatically opens **`game.rbxl`** in Roblox Studio!

3. **Connect in Roblox Studio**:
   - In Roblox Studio, click the **Plugins** tab in the top ribbon.
   - Click the **Rojo** button -> click **Connect** (port: `34872`).
   - You should see `Connected to Rojo!` in the Output window.

That's it! Any time anyone on the team pushes to GitHub, everyone's Roblox Studio will update automatically!

---

### 3. Pushing Changes to GitHub

Whenever you or your friend finish editing scripts or building:
1. Double-click **`push-changes.bat`**.
2. Type an optional note about what you changed and hit Enter.
3. It rebuilds `game.rbxl`, integrates any teammate commits, and pushes everything to GitHub!

Whenever you or your friend want to work on the game:

1. **Get the latest code before editing**:
   ```bash
   git pull origin main
   ```
2. **Edit your scripts**:
   - Code is located in:
     - `src/server/` -> Server scripts (Tornado physics, bunker detection, game loop)
     - `src/client/` -> Client scripts (Doppler radar HUD, vehicle controls, sirens)
     - `src/shared/` -> Shared modules (Weather constants, vehicle configs)
3. **See changes instantly**:
   - As soon as you save any script file in your editor (VS Code, etc.), Rojo instantly syncs it into Roblox Studio without restarting.
4. **Push your changes to GitHub**:
   ```bash
   git add .
   git commit -m "Add new storm mechanics"
   git push origin main
   ```
5. **Updating Map & 3D Models**:
   - If you build or edit 3D parts, models, or terrain inside Roblox Studio:
   - Click **File > Save to File** and overwrite `game.rbxl`.
   - Commit and push `game.rbxl` so your friend gets the updated map layout!