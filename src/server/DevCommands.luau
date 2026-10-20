-- Test-only chat commands. They only exist when playing in Studio, never in the live game.
--   /die     kill yourself to become a ghost
--   /revive  bring every ghost back to life
--   /relics  count every relic as placed (skip straight to the naming part)
--   /name    tells you the demon's name (so you can test banishing alone)
--   /scare   the demon takes you: plays the full jumpscare and kills you
--   /haunt   plays one of the random (harmless) scares on you right now
--   /event X fires the nearest placed house event of that kind (crawler, figure, mirror, writing, footsteps)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local GhostService = require(script.Parent.GhostService)
local RelicService = require(script.Parent.RelicService)
local DemonService = require(script.Parent.DemonService)
local RoundService = require(script.Parent.RoundService)
local Remotes = require(script.Parent.Remotes)

local DevCommands = {}

local function makeCommand(name: string, alias: string, handler: (Player, string) -> ())
	local command = Instance.new("TextChatCommand")
	command.Name = name
	command.PrimaryAlias = alias
	command.Parent = TextChatService
	command.Triggered:Connect(function(source: TextSource, text: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		if player then
			handler(player, text)
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

	makeCommand("DevScare", "/scare", function(player)
		DemonService.Take(player)
	end)

	local haunt = Remotes.Event("Haunt")
	makeCommand("DevHaunt", "/haunt", function(player)
		haunt:FireClient(player)
	end)

	local event = Remotes.Event("Event")
	makeCommand("DevEvent", "/event", function(player, text)
		event:FireClient(player, string.match(text or "", "^%S+%s+(%S+)") or "crawler")
	end)

	print("[Dev] Test commands ready: /die /revive /relics /name /scare /haunt /event")
end

return DevCommands
