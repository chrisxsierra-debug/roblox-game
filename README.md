# Brainrot Farm: Grow & Raid

> **Plant Something Dumb. Grow Something Huge.**

A mobile-first, server-authoritative Roblox idle-farming game. Plant a creature egg,
watch it grow through four silly stages, discover its species + mutation, harvest it for
Coins, buy more slots, unlock stronger seeds, and rebirth for a permanent multiplier.

**Core loop:** `Plant → Wait → Reveal → Harvest → Upgrade → Rebirth`

This repository is the **shared foundation + scaffold** for a 3-person team build. The
fully-implemented shared layer (config, definitions, utilities, remotes contract) is done
and unit-tested; the server/client/world systems are stubbed with locked interfaces and
split into three ownable tracks. **Start at [`TASK_SPLIT.md`](TASK_SPLIT.md).**

---

## Status

| Layer | State |
| --- | --- |
| Toolchain + Rojo project | ✅ done |
| Shared Config / Definitions / Utility / Constants / Types | ✅ done + unit-tested |
| Remotes contract | ✅ done |
| Server services (Track A) | 🟡 stubbed — interfaces locked, bodies TODO |
| Client UI/controllers (Track B) | 🟡 stubbed |
| World / creatures / QA (Track C) | 🟡 stubbed |
| In-Studio assembly + playtest | ⛔ deferred (needs Studio; see QA_CHECKLIST.md) |

Nothing here has been runtime-tested in Roblox Studio yet — see
[`QA_CHECKLIST.md`](QA_CHECKLIST.md). The pure-logic tests **have** been run via Lune.

---

## Getting started

### 1. Install the toolchain
This project pins its tools in [`rokit.toml`](rokit.toml). Install
[Rokit](https://github.com/rojo-rbx/rokit), then:

```sh
rokit install      # gets rojo, lune, selene, stylua at the pinned versions
```

### 2. Run the pure-logic tests
```sh
lune run tests/run
```

### 3. Lint + format
```sh
selene src
stylua --check src tests
```

### 4. Build / sync into Studio
```sh
rojo build default.project.json -o build.rbxlx   # one-off place file
# or, for live editing:
rojo serve                                        # then connect the Rojo Studio plugin
```

---

## Project layout

```
src/
  ReplicatedStorage/
    Shared/         Config, Definitions, Types, Constants, Utility   (DONE, dependency-free)
    Remotes/        RemoteEvent/Function registry                     (DONE)
  ServerScriptService/
    ServerBootstrap.server.luau   service lifecycle entry point       (DONE)
    Server/Services|Factories|Utility  Track A + C systems            (stubs)
  StarterPlayer/StarterPlayerScripts/
    FarmClient.client.luau        controller lifecycle entry point    (DONE)
    Client/Controllers|UI         Track B systems                     (stubs)
tests/            Lune pure-logic tests                               (DONE)
```

Architecture details: [`ARCHITECTURE.md`](ARCHITECTURE.md) ·
Data: [`DATA_SCHEMA.md`](DATA_SCHEMA.md) ·
Money: [`MONETIZATION_SETUP.md`](MONETIZATION_SETUP.md) ·
World: [`MAP_BUILDING_GUIDE.md`](MAP_BUILDING_GUIDE.md) ·
Work split: [`TASK_SPLIT.md`](TASK_SPLIT.md) ·
Remaining work: [`TODO.md`](TODO.md) · Log: [`DEVELOPMENT_LOG.md`](DEVELOPMENT_LOG.md)

## Golden rules (non-negotiable)
- **Server-authoritative** for all economy/progress. The client sends *intent* only.
- Validate + rate-limit **every** remote; never trust client values.
- All balance numbers live in `Shared/Config`; all IDs in `MonetizationConfig`/`AssetConfig`.
- Original creatures only. Placeholder Parts for art. `--!strict` everywhere.
