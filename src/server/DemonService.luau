-- The demon. Only ghosts can see it (it's tagged GhostOnly).
-- It wanders between rooms, and chases any living player it can see. If it catches you, you die.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GhostService = require(script.Parent.GhostService)

local DemonService = {}
DemonService.Killed = Instance.new("BindableEvent") -- fires (player)

local HIP_HEIGHT = 2.5
local BODY_COLOR = Color3.fromRGB(14, 10, 12)
local EYE_COLOR = Color3.fromRGB(255, 30, 30)

local model: Model?
local humanoid: Humanoid?
local root: BasePart?
local speedBonus = 0
local lastKill = 0

-- movement state
local path = PathfindingService:CreatePath({
	AgentRadius = 2.5,
	AgentHeight = 9,
	AgentCanJump = false,
	WaypointSpacing = 4,
})
local waypoints: { PathWaypoint }? = nil
local waypointIndex = 1
local goalStarted = 0
local chasing = false
local lastSeen: Vector3? = nil

local function setupCollision()
	if not PhysicsService:IsCollisionGroupRegistered("Demon") then
		PhysicsService:RegisterCollisionGroup("Demon")
	end
	-- It doesn't physically shove players around (it kills them instead).
	for _, other in { "Living", "Ghosts" } do
		if PhysicsService:IsCollisionGroupRegistered(other) then
			PhysicsService:CollisionGroupSetCollidable("Demon", other, false)
		end
	end
end

local function bodyPart(name: string, size: Vector3, offset: CFrame, shape: Enum.PartType?, color: Color3?, neon: boolean?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Shape = shape or Enum.PartType.Block
	p.Color = color or BODY_COLOR
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = (root :: BasePart).CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

local function build(at: CFrame)
	model = Instance.new("Model")
	model.Name = "Demon"

	local r = Instance.new("Part")
	r.Name = "HumanoidRootPart"
	r.Size = Vector3.new(2, 2, 1)
	r.Transparency = 1
	r.CanCollide = true
	r.CollisionGroup = "Demon"
	r.CFrame = at
	r.Parent = model
	root = r

	-- The real look lives in ServerStorage.DemonModel (a mesh made in Studio / Blender).
	-- Its pivot is the floor point under its feet, facing -Z. Every part gets welded to the root.
	local template = ServerStorage:FindFirstChild("DemonModel")
	if template and template:IsA("Model") then
		local feet = r.CFrame * CFrame.new(0, -(HIP_HEIGHT + r.Size.Y / 2), 0)
		local pivot = template:GetPivot()
		for _, src in template:GetDescendants() do
			if src:IsA("BasePart") then
				local p = src:Clone()
				p:ClearAllChildren()
				for _, child in src:GetChildren() do
					child:Clone().Parent = p -- keep lights, particles, attachments
				end
				p.Anchored = false
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.Massless = true
				p.CFrame = feet * pivot:ToObjectSpace(src.CFrame)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = r
				weld.Part1 = p
				weld.Parent = p
				p.Parent = model
			end
		end
	else
		-- Fallback: tall, thin, too-long arms made of blocks.
		bodyPart("Torso", Vector3.new(2.2, 4.5, 1.1), CFrame.new(0, 2.5, 0))
		bodyPart("DemonHead", Vector3.new(1.8, 1.8, 1.8), CFrame.new(0, 5.7, 0), Enum.PartType.Ball)
		bodyPart("LeftEye", Vector3.new(0.35, 0.2, 0.1), CFrame.new(-0.35, 5.85, -0.85), nil, EYE_COLOR, true)
		bodyPart("RightEye", Vector3.new(0.35, 0.2, 0.1), CFrame.new(0.35, 5.85, -0.85), nil, EYE_COLOR, true)
		bodyPart("LeftArm", Vector3.new(0.45, 5.5, 0.45), CFrame.new(-1.45, 1.6, 0))
		bodyPart("RightArm", Vector3.new(0.45, 5.5, 0.45), CFrame.new(1.45, 1.6, 0))
		bodyPart("LeftLeg", Vector3.new(0.6, 3.5, 0.6), CFrame.new(-0.55, -1.75, 0))
		bodyPart("RightLeg", Vector3.new(0.6, 3.5, 0.6), CFrame.new(0.55, -1.75, 0))
	end

	local h = Instance.new("Humanoid")
	h.HipHeight = HIP_HEIGHT
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.BreakJointsOnDeath = false
	h.MaxHealth = math.huge
	h.Health = math.huge
	h.WalkSpeed = Config.DemonWalkSpeed
	h.Parent = model
	humanoid = h

	model.PrimaryPart = r
	CollectionService:AddTag(model, "GhostOnly")
	model.Parent = workspace
	r:SetNetworkOwner(nil) -- the server drives it, not a player
end

local function rayParams(): RaycastParams
	local exclude: { Instance } = { model :: Model }
	for _, p in Players:GetPlayers() do
		if GhostService.IsGhost(p) and p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

local function canSee(character: Model): boolean
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head or not root then
		return false
	end
	local eye = (root :: BasePart).Position + Vector3.new(0, 4, 0)
	local result = workspace:Raycast(eye, head.Position - eye, rayParams())
	return result ~= nil and result.Instance:IsDescendantOf(character)
end

local function findTarget(): (Player?, BasePart?)
	local best, bestRoot, bestDist = nil, nil, Config.DemonDetectRange
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if c and h and r and h.Health > 0 and not GhostService.IsGhost(p) then
			local d = (r.Position - (root :: BasePart).Position).Magnitude
			if d < bestDist and canSee(c) then
				best, bestRoot, bestDist = p, r, d
			end
		end
	end
	return best, bestRoot
end

local function goTo(position: Vector3)
	local ok = pcall(function()
		path:ComputeAsync((root :: BasePart).Position, position)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		waypoints = path:GetWaypoints()
		waypointIndex = 2
	else
		waypoints = nil
	end
	goalStarted = os.clock()
end

local function pickPatrolPoint()
	local folder = workspace:FindFirstChild("House") and workspace.House:FindFirstChild("DemonPatrol")
	if not folder then
		return
	end
	local points = folder:GetChildren()
	if #points == 0 then
		return
	end
	goTo(points[math.random(#points)].Position)
end

local function kill(player: Player)
	local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then
		h.Health = 0
		lastKill = os.clock()
		DemonService.Killed:Fire(player)
	end
end

local function step()
	if not model or not humanoid or not root then
		return
	end
	local target, targetRoot = findTarget()
	if target and targetRoot then
		chasing = true
		waypoints = nil
		lastSeen = targetRoot.Position
		humanoid.WalkSpeed = Config.DemonChaseSpeed + speedBonus
		humanoid:MoveTo(targetRoot.Position)
		local d = (targetRoot.Position - root.Position).Magnitude
		if d <= Config.DemonKillRange and os.clock() - lastKill > Config.DemonKillCooldown then
			kill(target)
		end
		return
	end

	humanoid.WalkSpeed = Config.DemonWalkSpeed + speedBonus
	if chasing then
		-- Lost sight of them: go check where it last saw them.
		chasing = false
		if lastSeen then
			goTo(lastSeen)
		end
	end

	if not waypoints or waypointIndex > #waypoints or os.clock() - goalStarted > 20 then
		pickPatrolPoint()
		return
	end
	local wp = waypoints[waypointIndex]
	humanoid:MoveTo(wp.Position)
	local flat = Vector3.new(wp.Position.X - root.Position.X, 0, wp.Position.Z - root.Position.Z)
	if flat.Magnitude < 3 then
		waypointIndex += 1
	end
end

function DemonService.Spawn()
	DemonService.Despawn()
	speedBonus = 0
	local spawnPart = workspace:FindFirstChild("House") and workspace.House:FindFirstChild("DemonSpawn")
	local at = if spawnPart then spawnPart.CFrame else CFrame.new(0, 5, 20)
	build(at + Vector3.new(0, 1, 0))
	waypoints = nil
	chasing = false
	lastSeen = nil
	lastKill = os.clock() -- short grace period at the start of a round
end

function DemonService.Despawn()
	if model then
		model:Destroy()
	end
	model, humanoid, root = nil, nil, nil
end

-- Someone spoke the wrong name.
function DemonService.Anger()
	speedBonus += Config.DemonAngerSpeedBonus
end

-- "The house takes someone": used to make sure every round has a ghost.
function DemonService.Take(player: Player)
	kill(player)
end

function DemonService.Start()
	setupCollision()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(step)
			if not ok then
				warn("[Demon] " .. tostring(err))
				task.wait(1)
			end
		end
	end)
end

return DemonService
