-- Every living player carries a flashlight (a SpotLight in their head), so other players see the beam too.
-- Ghosts don't get one. Clients toggle it with the "Flashlight" remote.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GhostService = require(script.Parent.GhostService)
local Remotes = require(script.Parent.Remotes)

local FlashlightService = {}

local lastToggle: { [Player]: number } = {}

local function getLight(player: Player): SpotLight?
	local head = player.Character and player.Character:FindFirstChild("Head")
	return head and head:FindFirstChild("Flashlight") :: SpotLight?
end

local function giveFlashlight(player: Player, character: Model)
	if GhostService.IsGhost(player) then
		return
	end
	local head = character:WaitForChild("Head", 5)
	if not head then
		return
	end
	local light = Instance.new("SpotLight")
	light.Name = "Flashlight"
	light.Face = Enum.NormalId.Front
	light.Angle = Config.FlashlightAngle
	light.Range = Config.FlashlightRange
	light.Brightness = Config.FlashlightBrightness
	light.Color = Color3.fromRGB(255, 244, 222)
	light.Shadows = true
	light.Enabled = true
	light.Parent = head
end

function FlashlightService.Start()
	local remote = Remotes.Event("Flashlight")
	remote.OnServerEvent:Connect(function(player: Player, on: unknown)
		if typeof(on) ~= "boolean" or GhostService.IsGhost(player) then
			return
		end
		local now = os.clock()
		if lastToggle[player] and now - lastToggle[player] < 0.15 then
			return
		end
		lastToggle[player] = now
		local light = getLight(player)
		if light then
			light.Enabled = on
		end
	end)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			giveFlashlight(player, character)
		end)
		if player.Character then
			task.spawn(giveFlashlight, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastToggle[p] = nil
	end)
end

return FlashlightService
