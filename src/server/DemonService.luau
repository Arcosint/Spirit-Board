-- The demon. Only ghosts can see it (it's tagged GhostOnly), but the living can hear it breathing.
-- It wanders between rooms, and chases any living player it can see (with a growl when it spots you).
-- If it catches you it doesn't just kill you: you freeze, it looms in front of you, and your screen
-- plays the jumpscare (client/Jumpscare). Everyone nearby hears you scream. Then you die.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GhostService = require(script.Parent.GhostService)
local Remotes = require(script.Parent.Remotes)

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
local growlSound: Sound?
local nextGrowl = 0

-- kills in progress
local jumpscare: RemoteEvent
local taking: { [Player]: number } = {} -- player -> token for their kill
local takeToken = 0
local feeding: Player? = nil -- while it's got someone, it stands still in front of them

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

	-- The living can't see it, but they can hear it.
	local breath = Instance.new("Sound")
	breath.Name = "Breathing"
	breath.SoundId = Config.ScareSounds.Breathing
	breath.Looped = true
	breath.Volume = 1
	breath.PlaybackSpeed = 0.75
	breath.RollOffMode = Enum.RollOffMode.InverseTapered
	breath.RollOffMinDistance = 6
	breath.RollOffMaxDistance = Config.DemonBreathRange
	breath.Parent = r

	local growl = Instance.new("Sound")
	growl.Name = "Growl"
	growl.SoundId = Config.ScareSounds.Growl
	growl.Volume = 1.6
	growl.RollOffMode = Enum.RollOffMode.InverseTapered
	growl.RollOffMinDistance = 10
	growl.RollOffMaxDistance = 90
	growl.Parent = r
	growlSound = growl
	nextGrowl = os.clock() + math.random(10, 20)

	model.PrimaryPart = r
	CollectionService:AddTag(model, "GhostOnly")
	model.Parent = workspace
	r:SetNetworkOwner(nil) -- the server drives it, not a player
	breath:Play()
end

local function playGrowl()
	if growlSound then
		growlSound.PlaybackSpeed = 0.7 + math.random() * 0.2
		growlSound:Play()
	end
	nextGrowl = os.clock() + math.random(12, 25)
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
		if c and h and r and h.Health > 0 and not GhostService.IsGhost(p) and not taking[p] then
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

local function freeze(character: Model, frozen: boolean)
	local h = character:FindFirstChildOfClass("Humanoid")
	local r = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if h then
		if frozen then
			h:SetAttribute("SpeedBeforeTaken", h.WalkSpeed)
			h:SetAttribute("JumpBeforeTaken", h.JumpHeight)
			h:SetAttribute("JumpPowerBeforeTaken", h.JumpPower)
			h.WalkSpeed = 0
			h.JumpHeight = 0
			h.JumpPower = 0
		else
			h.WalkSpeed = h:GetAttribute("SpeedBeforeTaken") or 16
			h.JumpHeight = h:GetAttribute("JumpBeforeTaken") or 7.2
			h.JumpPower = h:GetAttribute("JumpPowerBeforeTaken") or 50
		end
	end
	if r then
		r.Anchored = frozen
	end
end

local function oneShot(parent: Instance, id: string, volume: number, speed: number, range: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = range
	s.Parent = parent
	s:Play()
	task.delay(8, function()
		s:Destroy()
	end)
end

-- A burst of blood from the victim and a pool spreading on the floor under them.
local function bleed(r: BasePart)
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, 1, 0)
	a.Parent = r
	local p = Instance.new("ParticleEmitter")
	p.Color = ColorSequence.new(Color3.fromRGB(120, 0, 0), Color3.fromRGB(50, 0, 0))
	p.LightEmission = 0
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.15) })
	p.Speed = NumberRange.new(8, 18)
	p.SpreadAngle = Vector2.new(70, 70)
	p.Acceleration = Vector3.new(0, -60, 0)
	p.Lifetime = NumberRange.new(0.6, 1.2)
	p.Drag = 1
	p.Rate = 0
	p.Parent = a
	p:Emit(70)
	task.delay(0.6, function()
		if a.Parent then
			p:Emit(40)
		end
	end)
	task.delay(3, function()
		a:Destroy()
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { r.Parent :: Instance, model :: Instance }
	local ray = workspace:Raycast(r.Position, Vector3.new(0, -8, 0), params)
	if ray then
		local pool = Instance.new("Part")
		pool.Name = "BloodPool"
		pool.Shape = Enum.PartType.Cylinder
		pool.Anchored = true
		pool.CanCollide = false
		pool.CanQuery = false
		pool.CanTouch = false
		pool.Material = Enum.Material.SmoothPlastic
		pool.Color = Color3.fromRGB(55, 0, 0)
		pool.Size = Vector3.new(0.05, 0.5, 0.5)
		pool.CFrame = CFrame.new(ray.Position + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90))
		pool.Parent = workspace
		local width = 5 + math.random() * 2
		TweenService:Create(pool, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.05, width, width),
		}):Play()
		task.delay(45, function()
			TweenService:Create(pool, TweenInfo.new(3), { Transparency = 1 }):Play()
			task.wait(3)
			pool:Destroy()
		end)
	end
end

-- Grab a living player and run the jumpscare on them. They die when it ends.
local function take(player: Player)
	if taking[player] then
		return
	end
	local character = player.Character
	local h = character and character:FindFirstChildOfClass("Humanoid")
	local r = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not h or not r or h.Health <= 0 or GhostService.IsGhost(player) then
		return
	end
	takeToken += 1
	local mine = takeToken
	taking[player] = mine
	lastKill = os.clock()
	player:SetAttribute("BeingTaken", true)
	freeze(character, true)

	-- It appears right behind them, looming over their shoulder (the ghosts get to watch).
	-- Their screen slowly makes them turn around to face it.
	if model and root and humanoid then
		feeding = player
		local look = r.CFrame.LookVector * Vector3.new(1, 0, 1)
		look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
		local at = r.Position - look * 3.2
		local y = r.Position.Y + 0.5 -- its root sits a little higher than a player's
		root.CFrame = CFrame.lookAt(Vector3.new(at.X, y, at.Z), Vector3.new(r.Position.X, y, r.Position.Z))
		humanoid:MoveTo(root.Position)
	end

	-- A different length every time, so nobody can count it down.
	local range = Config.ScareDreadRange
	local dread = if range then range[1] + math.random() * (range[2] - range[1]) else Config.ScareDreadTime
	jumpscare:FireClient(player, "start", dread)

	task.spawn(function()
		task.wait(dread + Config.ScareBlackoutTime)
		if taking[player] ~= mine then
			return -- called off (round ended)
		end
		-- The face moment. Everyone nearby hears it happen, and the ghosts watching see the blood.
		if r.Parent then
			oneShot(r, Config.ScareSounds.Scream, 1.4, 1, 90)
			oneShot(r, Config.Gore.BoneCrack, 2, 0.9, 40)
			oneShot(r, Config.Gore.Splatter, 2, 0.8, 40)
			bleed(r)
		end
		if root and feeding == player then
			oneShot(root, Config.ScareSounds.Roar, 1.6, 0.75, 90)
		end
		task.wait(Config.ScareFaceTime)
		if taking[player] ~= mine then
			return
		end
		taking[player] = nil
		if feeding == player then
			feeding = nil
		end
		player:SetAttribute("BeingTaken", nil)
		if player.Parent and player.Character == character and h.Health > 0 then
			r.Anchored = false -- let the body drop
			h.Health = 0
			lastKill = os.clock()
			DemonService.Killed:Fire(player)
		end
	end)
end

-- Stop every kill that's mid-jumpscare (the round ended, e.g. the demon was banished).
local function cancelTakes()
	for player in taking do
		taking[player] = nil
		player:SetAttribute("BeingTaken", nil)
		if player.Character then
			freeze(player.Character, false)
		end
		if player.Parent then
			jumpscare:FireClient(player, "cancel")
		end
	end
	feeding = nil
end

local function step()
	if not model or not humanoid or not root then
		return
	end
	if feeding then
		if feeding.Parent and taking[feeding] then
			humanoid:MoveTo(root.Position) -- hold still, it's busy
			return
		end
		feeding = nil
	end
	local target, targetRoot = findTarget()
	if target and targetRoot then
		if not chasing then
			playGrowl() -- it's seen you
		end
		chasing = true
		waypoints = nil
		lastSeen = targetRoot.Position
		humanoid.WalkSpeed = Config.DemonChaseSpeed + speedBonus
		humanoid:MoveTo(targetRoot.Position)
		local d = (targetRoot.Position - root.Position).Magnitude
		if d <= Config.DemonKillRange and os.clock() - lastKill > Config.DemonKillCooldown then
			take(target)
		end
		return
	end

	if os.clock() > nextGrowl then
		playGrowl()
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
	cancelTakes()
	growlSound = nil
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
	take(player)
end

function DemonService.Start()
	setupCollision()
	jumpscare = Remotes.Event("Jumpscare")
	Players.PlayerRemoving:Connect(function(player)
		taking[player] = nil
		if feeding == player then
			feeding = nil
		end
	end)
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
