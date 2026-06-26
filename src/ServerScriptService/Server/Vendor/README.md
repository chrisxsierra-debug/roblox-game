# Vendored third-party libraries

These are upstream open-source modules committed verbatim (not via a package
manager) so the project builds with zero extra tooling. They are excluded from
StyLua (`.styluaignore`) and Selene (`selene.toml`) — we keep them in upstream form.

## ProfileStore.luau
- **Source:** https://github.com/MadStudioRoblox/ProfileStore
- **Version:** 1.0.3 (upstream `lm-loleris/profilestore`)
- **License:** Apache-2.0 (see `ProfileStore-LICENSE.txt`)
- **Why:** session-locked DataStore persistence — the de-facto standard for
  idle/sim games (used by Grow a Garden). Wrapped by `Services/PlayerDataService`.
- **Update:** re-download `ProfileStore.luau` from the repo's `main` branch.
  Prefer pinning to a tagged release; re-run the static gates after updating.
