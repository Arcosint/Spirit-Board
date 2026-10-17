-- Server entry point: starts every server system in order.
local Server = script.Parent

require(Server.GhostService).Start()
require(Server.ChatLock).Start()
require(Server.BoardService).Start()
require(Server.RelicService).Start()
require(Server.DemonService).Start()
require(Server.RoundService).Start()
require(Server.DevCommands).Start()

print("[Server] Ouija game server started")
