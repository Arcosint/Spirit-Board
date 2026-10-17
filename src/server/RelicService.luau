-- Relics are hidden in some of the searchable furniture each round.
-- Only ghosts can see where they are, so the living depend on the board to know where to search.
-- Search a spot (hold E) -> carry the relic -> place it at the board.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GhostService = require(script.Parent.GhostService)
local Remotes = require(script.Parent.Remotes)

local RelicService = {}
RelicService.Changed = Instance.new("BindableEvent") -- fires (placed, total)

local relicAt: { [BasePart]: BasePart } = {} -- spot -> hidden relic
local carrying: { [Player]: { relic: BasePart, spot: BasePart } } = {}
local placed, total = 0, 0
local relicFolder: Folder
local notify: RemoteEvent

local RELIC_COLOR = Color3.fromRGB(150, 60, 255)

local function makeRelic(): Part
	local p = Instance.new("Part")
	p.Name = "Relic"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1.2, 1.2, 1.2)
	p.Material = Enum.Material.Neon
	p.Color = RELIC_COLOR
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Anchored = true
	local light = Instance.new("PointLight")
	light.Color = RELIC_COLOR
	light.Range = 8
	light.Brightness = 2
	light.Parent = p
	return p
end

local function hideRelicAt(spot: BasePart)
	local relic = makeRelic()
	relic.CFrame = CFrame.new(spot.Position + Vector3.new(0, spot.Size.Y / 2 + 0.8, 0))
	CollectionService:AddTag(relic, "GhostOnly") -- invisible to the living
	relic.Parent = relicFolder
	relicAt[spot] = relic
end

local function setCarrying(player: Player, value)
	carrying[player] = value
	player:SetAttribute("HasRelic", value ~= nil)
end

local function giveRelic(player: Player, spot: BasePart)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local relic = relicAt[spot]
	if not root or not relic then
		return
	end
	relicAt[spot] = nil
	CollectionService:RemoveTag(relic, "GhostOnly") -- once it's in someone's hands, everyone can see it
	relic.Anchored = false
	relic.Massless = true
	relic.CFrame = root.CFrame * CFrame.new(0.9, 0.3, -1.2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = relic
	weld.Parent = relic
	relic.Parent = character
	setCarrying(player, { relic = relic, spot = spot })
	notify:FireClient(player, "You found a relic! Bring it to the board.")
end

-- If you die holding a relic, it goes back where it was (hidden again).
local function dropRelic(player: Player)
	local c = carrying[player]
	if not c then
		return
	end
	setCarrying(player, nil)
	c.relic:Destroy()
	hideRelicAt(c.spot)
end

local function clearAll()
	for _, relic in relicAt do
		relic:Destroy()
	end
	table.clear(relicAt)
	for player, c in carrying do
		c.relic:Destroy()
		player:SetAttribute("HasRelic", false)
	end
	table.clear(carrying)
end

local function addPrompt(parent: Instance, name: string, action: string, object: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	CollectionService:AddTag(prompt, "LivingOnlyPrompt") -- ghosts can't use it
	return prompt
end

function RelicService.Reset()
	clearAll()
	placed = 0
	local spots = {}
	local folder = workspace:FindFirstChild("House") and workspace.House:FindFirstChild("SearchSpots")
	if folder then
		spots = folder:GetChildren()
	end
	-- shuffle, then hide relics in the first few
	for i = #spots, 2, -1 do
		local j = math.random(i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	total = math.min(Config.RelicCount, #spots)
	for i = 1, total do
		hideRelicAt(spots[i])
	end
	workspace:SetAttribute("RelicsPlaced", 0)
	workspace:SetAttribute("RelicsTotal", total)
	RelicService.Changed:Fire(placed, total)
end

function RelicService.IsComplete(): boolean
	return total > 0 and placed >= total
end

-- Studio testing helper: count every relic as placed.
function RelicService.DevPlaceAll()
	clearAll()
	placed = total
	workspace:SetAttribute("RelicsPlaced", placed)
	RelicService.Changed:Fire(placed, total)
end

function RelicService.Start()
	notify = Remotes.Event("Notify")
	relicFolder = Instance.new("Folder")
	relicFolder.Name = "Relics"
	relicFolder.Parent = workspace

	-- Search prompts on every searchable spot
	local folder = workspace:FindFirstChild("House") and workspace.House:FindFirstChild("SearchSpots")
	if folder then
		for _, spot in folder:GetChildren() do
			if spot:IsA("BasePart") then
				local prompt = addPrompt(spot, "Search", "Search", spot:GetAttribute("SpotName") or spot.Name, Config.SearchTime)
				prompt.Triggered:Connect(function(player)
					if GhostService.IsGhost(player) then
						return
					end
					if carrying[player] then
						notify:FireClient(player, "Your hands are full. Take it to the board.")
					elseif relicAt[spot] then
						giveRelic(player, spot)
					else
						notify:FireClient(player, "Nothing here...")
					end
				end)
			end
		end
	end

	-- "Place relic" prompt on the board
	local board = workspace:FindFirstChild("SpiritBoard") and workspace.SpiritBoard:FindFirstChild("Board")
	if board then
		local prompt = addPrompt(board, "PlaceRelic", "Place relic", "Spirit board", 1)
		prompt.Triggered:Connect(function(player)
			local c = carrying[player]
			if not c or GhostService.IsGhost(player) then
				notify:FireClient(player, "Bring a relic here.")
				return
			end
			setCarrying(player, nil)
			c.relic:Destroy()
			placed += 1
			workspace:SetAttribute("RelicsPlaced", placed)
			RelicService.Changed:Fire(placed, total)
		end)
	end

	local function watch(player: Player)
		local function hook(character: Model)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				dropRelic(player)
			end)
		end
		player.CharacterAdded:Connect(hook)
		if player.Character then
			task.spawn(hook, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(dropRelic)
end

return RelicService
