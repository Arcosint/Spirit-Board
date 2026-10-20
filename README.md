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
- **Demon** (`server/DemonService`): only ghosts can see it, but everyone can hear it breathing, and it growls when it spots someone. It patrols the rooms and chases any living player it can see. Living players get a red pulse on screen when it's close.
- **The kill / jumpscare** (`server/DemonService` + `client/Jumpscare`): when the demon catches you, you freeze and it appears right behind you (the ghosts can watch). On your screen: the lamps die, the dark closes in, your heart pounds, something breathes in your ear and whispers "i see you", and your view is slowly dragged around to look behind you. Then a false calm: nothing's there, the lamps come back, your heart stops. Then black and silence... and the real 3D demon lunges into your face out of the dark, lit red from below, with a heavy impact, screams and a roar. It bites (bones crack, blood splatters across the screen), bites again, and your view drops to the floor as the screen floods red. The dread lasts a random time (`Config.ScareDreadRange`) so nobody can count it down. Everyone nearby hears it, and anyone watching sees a burst of blood and a pool spreading under the body.
- **The haunting** (`client/Haunting`): the house is never quiet. A low drone and rumble play under everything with an echoey reverb, the picture is colder and darker with a vignette, and every so often there's a knock, a bang, creaking floorboards or tapping on glass somewhere nearby (rarely, a music box in another room). Living players also get random harmless scares every minute or two (more often when the demon is close): "I SEE YOU" (the house goes silent, the lamps fade, it's whispered in your ear as the words appear, then a face slams onto the screen), the lights die and a screaming face slams onto the screen, something whispers "behind you", or the lamps go out one by one while something breathes next to you. Nobody dies from these.
- **Scares around the house** (`client/Events`, living only, nobody dies): walk into certain spots and something happens, once in a while (each has a chance and a cooldown, and there's always a gap between two of them):
  - **The crawler**: in the middle of the hall, or stepping into the parlor, a pale, too-long thing with its head twisted upside down and black hair hanging off it scuttles up the wall and across the ceiling right in front of you, freezes for a second, then keeps going and is gone. The lamps stutter while it moves.
  - **The figure**: walk into the west end of the hall and a tall dark figure with pale eyes is standing at the far end, facing you. Stare at it or get close and the lamps cut out... and it's gone.
  - **The mirror**: in the bathroom, look into the mirror and a face is looking back for a split second.
  - **The writing**: the second time you walk into the kitchen, "GET OUT" is written in dripping blood on the wall behind you.
  - **Footsteps**: in the study, something walks across the ceiling right above you, following you, then stops dead.
  - Always going: candles flicker, lightning flashes through the boarded windows followed by thunder, the rocking chair in the parlor rocks by itself (and stops when you get close), and the portraits sometimes flash a screaming face when you glance at them.
- **Flashlight** (`server/FlashlightService`, `client/FlashlightControl`): living players carry a light (Q, or the button on mobile). Other players see your beam. Ghosts don't get one.
- **Font**: all text uses Garamond (`Config.TextFont`). Roblox doesn't have Times New Roman, and Garamond is the closest serif it has.
- **Feeling the demon** (`client/DemonPresence`, living only): lamps flicker and die as it passes, your heartbeat gets louder and faster the closer it is, it whispers right next to you, and sometimes the lamps cut out and you catch a split-second glimpse of it.
- **Rounds** (`server/RoundService`): all relics placed -> ghosts see the demon's true name -> they spell it on the board -> a living player uses "Speak its name" (F) at the board. Right name = banished, stairs unlock. Wrong name = it gets faster. Everyone dead = the house wins. With 2+ players, if nobody has died after 30s, the house takes someone.
- **HUD** (`client/HUD`), ghost-only visibility (`client/GhostSight`), name entry (`client/BanishUI`), the ghost's secret name (`client/GhostSecretUI`).
- All the tuning numbers (planchette speed, demon speed, relic count, timers, demon names) are in `shared/Config.luau`. The jumpscare timings, the face image and every scary sound ID are in its "Scares" section, so you can swap any of them without touching the scripts.

## The map
Floor 1 lives in Studio/Team Create under `Workspace.House` (not in this repo). Scripts look for these names, so keep them if you rebuild it:
`House.SearchSpots` (parts with a `SpotName` attribute), `House.DemonPatrol` (invisible points), `House.DemonSpawn`, `House.StairDoor`, and `Workspace.BoardSpawn`.

The scares in `client/Events` are placed with `House.Events`: each Model there has an `Event` attribute (Crawler, Figure, Mirror, Writing, Footsteps), an invisible `Trigger` box, and optional `Chance`/`Cooldown` attributes. A Crawler has `Path...` folders of numbered parts laid on the walls/ceiling (each part's top faces out of the surface). Copy one and move it to add a scare somewhere new. The comment at the top of `client/Events.luau` explains every type.

The demon's look is `ServerStorage.DemonModel`: a Model whose pivot is the floor point under its feet, facing -Z. `DemonService` welds a copy of it onto the demon every round (lights, smoke and the red outline come with it). Swap in a new model (e.g. from Blender) with the same pivot rule and the game uses it automatically. If it's missing, the demon falls back to a block body.

## Testing (in Studio)
1. Test tab → Clients and Servers → pick 2 players → Start.
2. In one player window, type `/die` in chat. That player becomes a ghost and gets the board.
3. Tap letters on the ghost's board and watch the planchette move in the other window.
4. Chat as the ghost: the living player shouldn't see it.
5. `/revive` brings every ghost back.
6. `/relics` counts all relics as placed, `/name` tells you the demon's name (to test banishing alone).
7. `/haunt` plays one of the random harmless scares on you right away.
   `/event crawler` (or `figure`, `mirror`, `writing`, `footsteps`) sets off the nearest placed scare of that kind right away.
8. `/scare` makes the demon take you, so you can see the whole jumpscare without getting caught. Turn your volume up.
   All of these commands only work in Studio.

## Workflow
1. `git pull` before you start.
2. Make sure Rojo is running, then click Connect in the Studio Rojo plugin.
3. Commit + push when a piece works, with a short note ("added chat lock").
4. Use GitHub Issues to claim tasks so we never build the same thing.
