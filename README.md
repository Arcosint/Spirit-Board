# Ouija Game (name TBD)

Roblox co-op horror: one player dies, becomes a ghost, and guides the living through a Ouija board.

## How this repo works
- **Scripts** live here in `src/` and sync into Studio with Rojo.
- **The map** lives in Roblox Team Create, not in this repo.
- `src/server` → ServerScriptService, `src/client` → StarterPlayerScripts, `src/shared` → ReplicatedStorage.

## Workflow
1. `git pull` before you start.
2. Run `rojo serve`, then click Connect in the Studio Rojo plugin.
3. Commit + push when a piece works, with a short note ("added chat lock").
4. Use GitHub Issues to claim tasks so we never build the same thing.
