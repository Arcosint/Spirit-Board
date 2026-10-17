-- Tracks who is dead. Dead players come back as ghosts:
-- they can't be seen or touched by the living, and their chat doesn't reach the living.
-- The player attribute "IsGhost" is the single source of truth (clients read it too).
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local GhostService = {}

local LIVING_GROUP = "Living"
local GHOST_GROUP = "Ghosts"

local function setupCollisionGroups()
	for _, name in { LIVING_GROUP, GHOST_GROUP } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	-- Ghosts walk through the living and through each other, but still stand on floors.
	PhysicsService:CollisionGroupSetCollidable(GHOST_GROUP, LIVING_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(GHOST_GROUP, GHOST_GROUP, false)
end

local function setCharacterGroup(character: Model, group: string)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end)
end

function GhostService.IsGhost(player: Player): boolean
	return player:GetAttribute("IsGhost") == true
end

function GhostService.MakeGhost(player: Player)
	if GhostService.IsGhost(player) then
		return
	end
	player:SetAttribute("IsGhost", true)
	print(("[Ghost] %s died and is now a ghost"):format(player.Name))
end

function GhostService.Revive(player: Player)
	player:SetAttribute("IsGhost", false)
	player:LoadCharacter()
end

function GhostService.ReviveAll()
	for _, player in Players:GetPlayers() do
		if GhostService.IsGhost(player) then
			GhostService.Revive(player)
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local ghost = GhostService.IsGhost(player)
	setCharacterGroup(character, ghost and GHOST_GROUP or LIVING_GROUP)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if ghost then
		-- Hide the name tag so the living can't spot ghosts by their name.
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	humanoid.Died:Connect(function()
		GhostService.MakeGhost(player)
	end)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("IsGhost", false)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function GhostService.Start()
	setupCollisionGroups()
	Players.RespawnTime = Config.RespawnTime
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return GhostService
