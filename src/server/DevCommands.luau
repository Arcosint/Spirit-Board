-- Test-only chat commands. They only exist when playing in Studio, never in the live game.
--   /die     kill yourself to become a ghost
--   /revive  bring every ghost back to life
--   /relics  count every relic as placed (skip straight to the naming part)
--   /name    tells you the demon's name (so you can test banishing alone)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local GhostService = require(script.Parent.GhostService)
local RelicService = require(script.Parent.RelicService)
local RoundService = require(script.Parent.RoundService)
local Remotes = require(script.Parent.Remotes)

local DevCommands = {}

local function makeCommand(name: string, alias: string, handler: (Player) -> ())
	local command = Instance.new("TextChatCommand")
	command.Name = name
	command.PrimaryAlias = alias
	command.Parent = TextChatService
	command.Triggered:Connect(function(source: TextSource)
		local player = Players:GetPlayerByUserId(source.UserId)
		if player then
			handler(player)
		end
	end)
end

function DevCommands.Start()
	if not RunService:IsStudio() then
		return
	end
	local notify = Remotes.Event("Notify")

	makeCommand("DevDie", "/die", function(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end)

	makeCommand("DevRevive", "/revive", function()
		GhostService.ReviveAll()
	end)

	makeCommand("DevRelics", "/relics", function()
		RelicService.DevPlaceAll()
	end)

	makeCommand("DevName", "/name", function(player)
		notify:FireClient(player, "[dev] The name is " .. RoundService.GetDemonName())
	end)

	print("[Dev] Test commands ready: /die /revive /relics /name")
end

return DevCommands
