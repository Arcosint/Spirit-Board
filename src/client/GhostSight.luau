-- Things tagged "GhostOnly" (the demon, hidden relics) are invisible to the living and visible to ghosts.
-- Prompts tagged "LivingOnlyPrompt" (search, place relic, speak name) don't work for ghosts.
-- All done locally, so the server never has to know who sees what.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local GhostSight = {}

local localPlayer = Players.LocalPlayer
local tracked: { [Instance]: boolean } = {}
local promptRange: { [ProximityPrompt]: number } = {}

local function isGhost(): boolean
	return localPlayer:GetAttribute("IsGhost") == true
end

local function applyOne(inst: Instance, hidden: boolean)
	if inst:IsA("BasePart") then
		inst.LocalTransparencyModifier = if hidden then 1 else 0
	elseif
		inst:IsA("Light")
		or inst:IsA("ParticleEmitter")
		or inst:IsA("BillboardGui")
		or inst:IsA("SurfaceGui")
		or inst:IsA("Highlight")
	then
		(inst :: any).Enabled = not hidden
	end
end

local function applyTree(root: Instance, hidden: boolean)
	applyOne(root, hidden)
	for _, d in root:GetDescendants() do
		applyOne(d, hidden)
	end
end

local function track(inst: Instance)
	tracked[inst] = true
	applyTree(inst, not isGhost())
	inst.DescendantAdded:Connect(function(d)
		if tracked[inst] then
			applyOne(d, not isGhost())
		end
	end)
end

local function untrack(inst: Instance)
	tracked[inst] = nil
	applyTree(inst, false) -- e.g. a relic someone picked up: now everyone sees it
end

local function applyPrompt(prompt: ProximityPrompt)
	if promptRange[prompt] == nil then
		promptRange[prompt] = prompt.MaxActivationDistance
	end
	prompt.MaxActivationDistance = if isGhost() then 0 else promptRange[prompt]
end

local function refreshAll()
	for inst in tracked do
		applyTree(inst, not isGhost())
	end
	for prompt in promptRange do
		applyPrompt(prompt)
	end
end

function GhostSight.Start()
	for _, inst in CollectionService:GetTagged("GhostOnly") do
		track(inst)
	end
	CollectionService:GetInstanceAddedSignal("GhostOnly"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("GhostOnly"):Connect(untrack)

	for _, p in CollectionService:GetTagged("LivingOnlyPrompt") do
		applyPrompt(p)
	end
	CollectionService:GetInstanceAddedSignal("LivingOnlyPrompt"):Connect(applyPrompt)
	CollectionService:GetInstanceRemovedSignal("LivingOnlyPrompt"):Connect(function(p)
		promptRange[p] = nil
	end)

	localPlayer:GetAttributeChangedSignal("IsGhost"):Connect(refreshAll)
end

return GhostSight
