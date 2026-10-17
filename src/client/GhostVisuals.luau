-- Decides, on each player's own screen, who can see the ghosts.
--   Living players: ghosts are fully invisible.
--   Ghosts: other ghosts (and themselves) show up see-through.
-- Done on the client so the server never fights the client over transparency.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local GhostVisuals = {}

local localPlayer = Players.LocalPlayer

local function targetTransparency(): number
	if localPlayer:GetAttribute("IsGhost") == true then
		return Config.GhostSeeEachOtherTransparency
	end
	return 1
end

local function hideThing(thing: Instance, transparency: number)
	if thing:IsA("BasePart") then
		if thing.Name ~= "HumanoidRootPart" then
			thing.Transparency = transparency
		end
	elseif thing:IsA("Decal") then
		thing.Transparency = transparency
	end
end

local function applyToCharacter(player: Player)
	local character = player.Character
	if not character or player:GetAttribute("IsGhost") ~= true then
		return
	end
	local transparency = targetTransparency()
	for _, d in character:GetDescendants() do
		hideThing(d, transparency)
	end
end

local function refreshAll()
	for _, player in Players:GetPlayers() do
		applyToCharacter(player)
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		-- Accessories and the face load in after the character, so catch those as they arrive.
		character.DescendantAdded:Connect(function(d)
			if player:GetAttribute("IsGhost") == true then
				hideThing(d, targetTransparency())
			end
		end)
		applyToCharacter(player)
	end)
	player:GetAttributeChangedSignal("IsGhost"):Connect(function()
		applyToCharacter(player)
	end)
	applyToCharacter(player)
end

function GhostVisuals.Start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	-- When *you* die, everyone who was already a ghost should become visible to you.
	localPlayer:GetAttributeChangedSignal("IsGhost"):Connect(refreshAll)
end

return GhostVisuals
