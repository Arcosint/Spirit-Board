# Spirit Board (name TBD)

Roblox co-op horror: one player dies, becomes a ghost, and guides the living through a Ouija board.

## How this repo works
- **Scripts** live here in `src/` and sync into Studio with Rojo.
- **The map** lives in Roblox Team Create, not in this repo.
- `src/server` → ServerScriptService, `src/client` → StarterPlayerScripts, `src/shared` → ReplicatedStorage.

## What's built so far
- **Ghosts** (`server/GhostService`): when you die you respawn as a ghost. The living can't see you or bump into you.
- **Chat lock** (`server/ChatLock`): ghost messages never reach the living (normal chat, bubbles, and whispers). Ghosts can still read everyone.
- **Ouija board** (`server/BoardService`): a board with YES / NO / A–Z / 0–9 / GOODBYE and a planchette. Ghosts get an on-screen board (`client/GhostBoardUI`); tapping a key slides the real planchette there, slowly and shakily.
- Put a Part named `BoardSpawn` in Workspace to choose where the board goes. Otherwise it spawns at the spot in `shared/Config`.
- **Relics** (`server/RelicService`): each round 3 relics hide in random furniture (out of 7 search spots). Only ghosts can see them. Living players hold E to search, carry the relic, and place it at the board.
- **Demon** (`server/DemonService`): only ghosts can see it. It patrols the rooms and chases any living player it can see. Living players get a red pulse on screen when it's close.
- **Rounds** (`server/RoundService`): all relics placed -> ghosts see the demon's true name -> they spell it on the board -> a living player uses "Speak its name" (F) at the board. Right name = banished, stairs unlock. Wrong name = it gets faster. Everyone dead = the house wins. With 2+ players, if nobody has died after 30s, the house takes someone.
- **HUD** (`client/HUD`), ghost-only visibility (`client/GhostSight`), name entry (`client/BanishUI`), the ghost's secret name (`client/GhostSecretUI`).
- All the tuning numbers (planchette speed, demon speed, relic count, timers, demon names) are in `shared/Config.luau`.

## The map
Floor 1 lives in Studio/Team Create under `Workspace.House` (not in this repo). Scripts look for these names, so keep them if you rebuild it:
`House.SearchSpots` (parts with a `SpotName` attribute), `House.DemonPatrol` (invisible points), `House.DemonSpawn`, `House.StairDoor`, and `Workspace.BoardSpawn`.

The demon's look is `ServerStorage.DemonModel`: a Model whose pivot is the floor point under its feet, facing -Z. `DemonService` welds a copy of it onto the demon every round (lights, smoke and the red outline come with it). Swap in a new model (e.g. from Blender) with the same pivot rule and the game uses it automatically. If it's missing, the demon falls back to a block body.

## Testing (in Studio)
1. Test tab → Clients and Servers → pick 2 players → Start.
2. In one player window, type `/die` in chat. That player becomes a ghost and gets the board.
3. Tap letters on the ghost's board and watch the planchette move in the other window.
4. Chat as the ghost: the living player shouldn't see it.
5. `/revive` brings every ghost back.
6. `/relics` counts all relics as placed, `/name` tells you the demon's name (to test banishing alone).
   All of these commands only work in Studio.

## Workflow
1. `git pull` before you start.
2. Make sure Rojo is running, then click Connect in the Studio Rojo plugin.
3. Commit + push when a piece works, with a short note ("added chat lock").
4. Use GitHub Issues to claim tasks so we never build the same thing.
