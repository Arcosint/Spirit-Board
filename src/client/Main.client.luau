-- Client entry point: starts every player-side system.
local Client = script.Parent

require(Client.GhostVisuals).Start()
require(Client.GhostSight).Start()
require(Client.HUD).Start()
require(Client.GhostBoardUI).Start()
require(Client.GhostSecretUI).Start()
require(Client.BanishUI).Start()

print("[Client] Ouija game client started")
