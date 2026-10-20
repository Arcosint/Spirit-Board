-- Scripted scares tied to places in the house. Nobody dies from these; they're there to make you jump.
-- Everything runs on your own screen only (each player gets their own scares).
--
-- Placed events live in Workspace.House.Events. Each one is a Model with an "Event" attribute and:
--   * a part named "Trigger" (invisible box): the event fires when you walk into it
--   * whatever else that event needs (see below)
-- Optional attributes on the Model: Chance (0-1, default 1), Cooldown (seconds, default 180).
--
--   Event = "Crawler"   Folders named "Path..." holding parts "1", "2", "3"... laid on walls/ceilings.
--                       Each part's top (UpVector) points away from the surface it's on, its front (LookVector)
--                       the way to crawl. Something pale and wrong scuttles along whichever path is most in
--                       front of you, then is gone. The lamps stutter while it does.
--   Event = "Figure"    A part named "Spot" on the floor. A tall dark figure is standing there at the end of the
--                       hall. Look at it for a moment, or get close, and the lamps cut out... and it's gone.
--   Event = "Mirror"    A part named "Glass" over the mirror. When you look into it, a face is looking back.
--   Event = "Writing"   A part named "Wall" against a wall (front facing into the room). The second time you come
--                       into the room, "GET OUT" is written there in blood, on the wall behind you.
--   Event = "Footsteps" Something walks across the ceiling above you, following you, then stops dead.
--
-- Always on, no setup needed:
--   * candle flames (tagged "Candle") flicker
--   * lightning flashes through the boarded windows (tagged "StormWindow") with thunder
--   * the rocking chair (tagged "RockingChair") rocks by itself while you're in the room, and stops when you get close
--   * portraits (tagged "Portrait") are, for a split second when you glance at them, a screaming face
--
-- In Studio, /event <name> fires an event right away (e.g. "/event crawler"), see server/DevCommands.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Events = {}

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local S = Config.EventSounds

local lastEvent = 0
local busy = false
local zoneState: { [Instance]: { inside: boolean, entries: number, lastFired: number } } = {}

local function isLiving(): boolean
	return localPlayer:GetAttribute("IsGhost") ~= true and localPlayer:GetAttribute("BeingTaken") ~= true
end

local function canScare(): boolean
	return isLiving() and not busy and localPlayer:GetAttribute("HauntingLights") == nil
end

local function myRoot(): BasePart?
	local c = localPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function inside(part: BasePart, pos: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y + 4 and math.abs(p.Z) <= h.Z
end

-- how much the camera is looking at a point (1 = dead center, 0 = 90 degrees off)
local function facing(pos: Vector3): number
	local cf = camera.CFrame
	return (pos - cf.Position).Unit:Dot(cf.LookVector)
end

local function soundAt(position: Vector3, id: string, volume: number, speed: number?, life: number?): Sound
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 90
	s.Parent = a
	s:Play()
	task.delay(life or 8, function()
		a:Destroy()
	end)
	return s
end

local function sound2D(id: string, volume: number, speed: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed or 1
	s.Parent = SoundService
	s.Ended:Connect(function()
		s:Destroy()
	end)
	s:Play()
end

-- Lamps -----------------------------------------------------------------------------------------
local lamps: { [Light]: number } = {}
local function trackLamps()
	local house = workspace:FindFirstChild("House")
	local folder = house and house:FindFirstChild("Lights")
	if folder then
		for _, d in folder:GetDescendants() do
			if d:IsA("Light") and lamps[d] == nil then
				lamps[d] = d.Brightness
			end
		end
	end
end

-- Stutter the lamps near a spot (or all of them). Borrows the lamps from the other scripts while it runs.
local function stutterLamps(near: Vector3?, radius: number, duration: number, endDark: boolean?)
	localPlayer:SetAttribute("HauntingLights", true)
	local stop = os.clock() + duration
	while os.clock() < stop do
		for l, b in lamps do
			local p = l.Parent
			if p and p:IsA("BasePart") and (not near or (p.Position - near).Magnitude < radius) then
				l.Brightness = if math.random() < 0.5 then b * math.random() * 0.2 else b
			end
		end
		task.wait(0.04 + math.random() * 0.08)
	end
	if not endDark then
		for l, b in lamps do
			l.Brightness = b
		end
		localPlayer:SetAttribute("HauntingLights", nil)
	end
end

local function restoreLamps()
	for l, b in lamps do
		l.Brightness = b
	end
	localPlayer:SetAttribute("HauntingLights", nil)
end

-- THE CRAWLER --------------------------------------------------------------------------------------
-- Built from parts so its limbs can move: a long pale body, a head twisted sideways, four limbs far too long.
local SKIN = Color3.fromRGB(150, 143, 130)
local DIRTY = Color3.fromRGB(96, 84, 72)

local function limbPart(model: Model, size: Vector3): BasePart
	local p = Instance.new("Part")
	p.Size = size
	p.Color = SKIN
	p.Material = Enum.Material.Slate -- mottled, dead-looking skin
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Parent = model
	return p
end

local function buildCrawler(): (Model, (CFrame, number) -> ())
	local m = Instance.new("Model")
	m.Name = "Crawler"
	local torso = limbPart(m, Vector3.new(1.3, 0.8, 3.2))
	local hips = limbPart(m, Vector3.new(1.1, 0.7, 1.2))
	local neck = limbPart(m, Vector3.new(0.35, 0.35, 0.9))
	local head = limbPart(m, Vector3.new(0.95, 1.35, 1.05))
	-- rounded flesh instead of boxes
	for _, p in { torso, hips, head } do
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	local eyeL = limbPart(m, Vector3.new(0.22, 0.3, 0.1))
	local eyeR = limbPart(m, Vector3.new(0.22, 0.3, 0.1))
	local mouth = limbPart(m, Vector3.new(0.5, 0.45, 0.1))
	for _, p in { eyeL, eyeR, mouth } do
		p.Color = Color3.new(0, 0, 0)
	end
	-- ribs
	local ribs = {}
	for i = 1, 4 do
		local r = limbPart(m, Vector3.new(1.42, 0.08, 0.12))
		r.Color = Color3.fromRGB(170, 162, 150)
		ribs[i] = r
	end
	-- four limbs: { shoulder offset, upper, lower, phase }
	local limbs = {}
	for i, def in {
		{ Vector3.new(-0.6, 0, -1.3), 0 },
		{ Vector3.new(0.6, 0, -1.3), math.pi },
		{ Vector3.new(-0.5, 0, 1.4), math.pi },
		{ Vector3.new(0.5, 0, 1.4), 0 },
	} do
		limbs[i] = {
			root = def[1],
			phase = def[2],
			upper = limbPart(m, Vector3.new(0.34, 0.34, 2.5)),
			lower = limbPart(m, Vector3.new(0.28, 0.28, 2.7)),
			elbow = limbPart(m, Vector3.new(0.36, 0.36, 0.36)),
			hand = limbPart(m, Vector3.new(0.34, 0.1, 0.4)),
			fingers = {},
		}
		local l = limbs[i]
		l.elbow.Shape = Enum.PartType.Ball
		l.lower.Color = DIRTY
		l.hand.Color = DIRTY
		for f = 1, 4 do
			local finger = limbPart(m, Vector3.new(0.07, 0.07, 0.75 + math.random() * 0.25))
			finger.Color = DIRTY
			l.fingers[f] = finger
		end
	end
	-- long black hair hanging straight down from the head, whatever surface it's on
	local hair = {}
	for i = 1, 7 do
		local h = limbPart(m, Vector3.new(0.09, 0.09, 1.6 + math.random() * 1.4))
		h.Color = Color3.fromRGB(10, 9, 9)
		h.CastShadow = false
		hair[i] = { part = h, off = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.7 }
	end

	-- place every part for a body frame (CFrame: Y = away from surface, -Z = forward) and gait time t
	local function pose(cf: CFrame, t: number)
		local bob = math.sin(t * 22) * 0.12
		local body = cf * CFrame.new(0, 1.3 + bob, 0) * CFrame.Angles(math.rad(-6), math.sin(t * 11) * 0.12, 0)
		torso.CFrame = body
		hips.CFrame = body * CFrame.new(0, 0.05, 1.7)
		neck.CFrame = body * CFrame.new(0, 0.2, -1.9) * CFrame.Angles(math.rad(25), 0, 0)
		-- head twisted almost upside down, twitching
		local twitch = (math.random() < 0.08) and math.rad(math.random(-35, 35)) or 0
		local h = body * CFrame.new(0, 0.45, -2.5) * CFrame.Angles(0, 0, math.rad(115) + twitch)
		head.CFrame = h
		eyeL.CFrame = h * CFrame.new(-0.22, 0.12, -0.47)
		eyeR.CFrame = h * CFrame.new(0.22, 0.12, -0.47)
		mouth.CFrame = h * CFrame.new(0, -0.28, -0.45)
		for _, hr in hair do
			local top = h.Position + hr.off
			local len = hr.part.Size.Z
			local sway = Vector3.new(math.sin(t * 9 + hr.off.X * 10), 0, math.cos(t * 7 + hr.off.Z * 10)) * 0.15
			local bottom = top + Vector3.new(0, -len, 0) + sway
			hr.part.CFrame = CFrame.lookAt((top + bottom) / 2, bottom)
		end
		for i, r in ribs do
			r.CFrame = body * CFrame.new(0, 0.02, -1.0 + i * 0.35) * CFrame.Angles(0, 0, 0)
		end
		for _, l in limbs do
			local swing = math.sin(t * 22 + l.phase)
			local lift = math.max(0, math.cos(t * 22 + l.phase)) * 0.9
			local shoulder = body * CFrame.new(l.root)
			local side = if l.root.X < 0 then -1 else 1
			-- hand lands out to the side, ahead/behind with the gait
			local handPos = (cf * CFrame.new(l.root.X * 3.6, lift, l.root.Z * 1.5 + swing * 1.1)).Position
			local s = shoulder.Position
			local mid = (s + handPos) / 2 + cf.UpVector * 1.9 + (shoulder.RightVector * side * 0.6)
			l.upper.CFrame = CFrame.lookAt((s + mid) / 2, mid) * CFrame.new(0, 0, 0)
			l.upper.Size = Vector3.new(0.34, 0.34, (mid - s).Magnitude)
			l.elbow.CFrame = CFrame.new(mid)
			l.lower.CFrame = CFrame.lookAt((mid + handPos) / 2, handPos)
			l.lower.Size = Vector3.new(0.28, 0.28, (handPos - mid).Magnitude)
			local palm = CFrame.lookAt(handPos, handPos + (handPos - mid))
			l.hand.CFrame = palm * CFrame.Angles(math.rad(90), 0, 0)
			-- long fingers splayed out flat against the surface
			for f, finger in l.fingers do
				local spread = math.rad((f - 2.5) * 22)
				local dir = (palm.LookVector * math.cos(spread) + palm.RightVector * math.sin(spread))
				dir = dir - cf.UpVector * dir:Dot(cf.UpVector)
				dir = if dir.Magnitude > 0.01 then dir.Unit else cf.LookVector
				local len = finger.Size.Z
				local tip = handPos + dir * len
				finger.CFrame = CFrame.lookAt((handPos + tip) / 2, tip)
			end
		end
	end
	return m, pose
end

-- frame on the path: position on the surface, Y = surface normal, -Z = direction of travel
local function pathFrame(points: { BasePart }, u: number): CFrame
	local n = #points
	local f = math.clamp(u, 0, 1) * (n - 1)
	local i = math.clamp(math.floor(f) + 1, 1, n - 1)
	local a, b = points[i], points[i + 1]
	local k = f - (i - 1)
	local pos = a.Position:Lerp(b.Position, k)
	local up = a.CFrame.UpVector:Lerp(b.CFrame.UpVector, k).Unit
	local fwd = (b.Position - a.Position)
	fwd = (fwd - up * fwd:Dot(up))
	if fwd.Magnitude < 0.01 then
		fwd = a.CFrame.LookVector
	end
	fwd = fwd.Unit
	local right = fwd:Cross(up)
	return CFrame.fromMatrix(pos, right, up, -fwd)
end

local function pathLength(points: { BasePart }): number
	local len = 0
	for i = 2, #points do
		len += (points[i].Position - points[i - 1].Position).Magnitude
	end
	return len
end

local function getPaths(zone: Instance): { { BasePart } }
	local paths = {}
	for _, f in zone:GetChildren() do
		if f.Name:sub(1, 4) == "Path" then
			local pts = {}
			for _, p in f:GetChildren() do
				if p:IsA("BasePart") and tonumber(p.Name) then
					table.insert(pts, p)
				end
			end
			table.sort(pts, function(a, b)
				return tonumber(a.Name) < tonumber(b.Name)
			end)
			if #pts >= 2 then
				table.insert(paths, pts)
			end
		end
	end
	return paths
end

local function runCrawler(zone: Instance)
	local paths = getPaths(zone)
	if #paths == 0 then
		return
	end
	-- the path most in front of you
	local best, bestScore = paths[1], -math.huge
	for _, pts in paths do
		local mid = pts[math.ceil(#pts / 2)].Position
		local score = facing(mid)
		if score > bestScore then
			best, bestScore = pts, score
		end
	end

	local model, pose = buildCrawler()
	model.Parent = workspace
	local start = best[1].Position
	local scuttle = soundAt(start, S.Scuttle, 2.2, 2.3, 6)
	scuttle.Looped = true
	soundAt(start, Config.ScareSounds.ShriekShort, 1.2, 0.6, 4) -- a wet little screech as it moves
	task.spawn(stutterLamps, start, 35, 1.4)

	local len = pathLength(best)
	local speed = 18
	local dur = len / speed
	local t0 = os.clock()
	local paused = 0
	local pauseAt = 0.35 + math.random() * 0.3 -- it stops dead for a moment partway, then keeps going
	while true do
		local now = os.clock()
		local u = (now - t0 - paused) / dur
		if u >= pauseAt and pauseAt > 0 then
			local p0 = os.clock()
			local cf = pathFrame(best, pauseAt)
			while os.clock() - p0 < 0.35 do
				pose(cf, 0) -- frozen, head twitching
				RunService.RenderStepped:Wait()
			end
			paused += os.clock() - p0
			pauseAt = -1
			continue
		end
		if u >= 1 then
			break
		end
		local cf = pathFrame(best, u)
		pose(cf, now)
		scuttle.Parent.WorldPosition = cf.Position
		RunService.RenderStepped:Wait()
	end
	-- gone into the dark
	scuttle:Stop()
	model:Destroy()
end

-- THE FIGURE -------------------------------------------------------------------------------------
local function buildFigure(at: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Figure"
	local function p(size: Vector3, cf: CFrame, shape: Enum.PartType?)
		local x = Instance.new("Part")
		x.Size = size
		x.CFrame = at * cf
		x.Color = Color3.fromRGB(8, 7, 9)
		x.Material = Enum.Material.SmoothPlastic
		x.Anchored = true
		x.CanCollide = false
		x.CanQuery = false
		x.CastShadow = false
		if shape then
			x.Shape = shape
		end
		x.Parent = m
		return x
	end
	p(Vector3.new(1.6, 4.2, 0.8), CFrame.new(0, 5.6, 0)) -- torso, too long
	p(Vector3.new(0.5, 4.4, 0.5), CFrame.new(-0.6, 1.9, 0)) -- legs
	p(Vector3.new(0.5, 4.4, 0.5), CFrame.new(0.6, 1.9, 0))
	p(Vector3.new(0.4, 5.6, 0.4), CFrame.new(-1.15, 5, 0) * CFrame.Angles(0, 0, math.rad(4))) -- arms to the knees
	p(Vector3.new(0.4, 5.6, 0.4), CFrame.new(1.15, 5, 0) * CFrame.Angles(0, 0, math.rad(-4)))
	p(Vector3.new(1.1, 1.3, 1.1), CFrame.new(0.15, 8.4, 0) * CFrame.Angles(0, 0, math.rad(-18)), Enum.PartType.Ball) -- head, tilted
	-- two faint pale eyes
	for _, x in { -0.22, 0.22 } do
		local e = p(Vector3.new(0.12, 0.12, 0.05), CFrame.new(0.15 + x, 8.5, -0.55))
		e.Color = Color3.fromRGB(235, 230, 220)
		e.Material = Enum.Material.Neon
	end
	m.Parent = workspace
	return m
end

local function runFigure(zone: Instance)
	local spot = zone:FindFirstChild("Spot") :: BasePart?
	local root = myRoot()
	if not spot or not root then
		return
	end
	-- it faces you
	local look = Vector3.new(root.Position.X, spot.Position.Y, root.Position.Z)
	local at = CFrame.lookAt(spot.Position, look) * CFrame.new(0, spot.Size.Y / 2, 0)
	local fig = buildFigure(at)
	local seen = 0
	local t0 = os.clock()
	while os.clock() - t0 < 12 and isLiving() do
		local dt = RunService.RenderStepped:Wait()
		local r = myRoot()
		if not r then
			break
		end
		if facing(spot.Position + Vector3.new(0, 6, 0)) > 0.9 then
			seen += dt
		end
		if seen > 1.1 or (r.Position - spot.Position).Magnitude < 22 then
			break
		end
	end
	-- the lamps die... and it's gone
	localPlayer:SetAttribute("HauntingLights", true)
	for l in lamps do
		l.Brightness = 0
	end
	soundAt(spot.Position, Config.ScareSounds.WhisperShort, 2, 0.6, 5)
	task.wait(0.5)
	fig:Destroy()
	task.wait(0.4)
	stutterLamps(nil, 0, 0.6)
	restoreLamps()
end

-- THE MIRROR -------------------------------------------------------------------------------------
local function runMirror(zone: Instance)
	local glass = zone:FindFirstChild("Glass") :: BasePart?
	if not glass then
		return
	end
	-- wait until you're actually looking into it
	local t0 = os.clock()
	while facing(glass.Position) < 0.8 do
		if os.clock() - t0 > 6 or not isLiving() then
			return
		end
		RunService.RenderStepped:Wait()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0.4
	gui.CanvasSize = Vector2.new(300, 340)
	local img = Instance.new("ImageLabel")
	img.BackgroundColor3 = Color3.new(0, 0, 0)
	img.BackgroundTransparency = 0.2
	img.Size = UDim2.fromScale(1, 1)
	img.ScaleType = Enum.ScaleType.Fit
	img.Image = Config.ScareFlashImages[math.random(#Config.ScareFlashImages)]
	img.Parent = gui
	gui.Adornee = glass
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	sound2D(Config.ScareSounds.ShriekShort, 2.5, 0.8)
	task.spawn(stutterLamps, glass.Position, 20, 0.7)
	task.wait(0.7)
	gui:Destroy()
end

-- THE WRITING ------------------------------------------------------------------------------------
local written: { [Instance]: boolean } = {}
local function runWriting(zone: Instance)
	local wall = zone:FindFirstChild("Wall") :: BasePart?
	if not wall or written[zone] then
		return
	end
	-- it appears while your back is turned
	local t0 = os.clock()
	while facing(wall.Position) > -0.1 do
		if os.clock() - t0 > 20 or not isLiving() then
			return
		end
		task.wait(0.1)
	end
	written[zone] = true
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BloodWriting"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 1
	gui.CanvasSize = Vector2.new(800, 300)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.Creepster -- scrawled by a finger, not typed
	t.TextScaled = true
	t.Text = "GET OUT"
	t.TextColor3 = Color3.fromRGB(95, 4, 4)
	t.Rotation = -5
	t.Size = UDim2.fromScale(1, 0.8)
	t.Parent = gui
	-- drips running down from the letters, thinning out
	for i = 1, 14 do
		local d = Instance.new("Frame")
		d.BackgroundColor3 = Color3.fromRGB(85, 3, 3)
		d.BorderSizePixel = 0
		d.Position = UDim2.new(0.1 + math.random() * 0.8, 0, 0.55 + math.random() * 0.12, 0)
		d.Size = UDim2.new(0, math.random(3, 7), 0.1 + math.random() * 0.3, 0)
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.85, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = d
		d.Parent = gui
	end
	gui.Adornee = wall
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	soundAt(wall.Position, Config.Gore.Splatter, 1.5, 0.6, 4)
	-- it stays until you die or the round resets
	local conn
	conn = localPlayer.CharacterAdded:Connect(function()
		gui:Destroy()
		written[zone] = nil
		conn:Disconnect()
	end)
end

-- FOOTSTEPS ABOVE --------------------------------------------------------------------------------
local function runFootsteps()
	local root = myRoot()
	if not root then
		return
	end
	local ceilingY = root.Position.Y + 11
	local steps = 9 + math.random(0, 5)
	for i = 1, steps do
		local r = myRoot()
		if not r or not isLiving() then
			return
		end
		-- each step lands a little behind you, then catches up
		local back = r.CFrame.LookVector * -(6 - i * 0.5)
		soundAt(Vector3.new(r.Position.X, ceilingY, r.Position.Z) + back, S.Creak, 1.6, 0.8 + math.random() * 0.2, 4)
		task.wait(0.55 - i * 0.02)
	end
	-- ...right above you. Then nothing.
	local r = myRoot()
	if r then
		soundAt(Vector3.new(r.Position.X, ceilingY, r.Position.Z), S.Thud, 2.5, 0.8, 4)
	end
end

local RUNNERS = {
	Crawler = runCrawler,
	Figure = runFigure,
	Mirror = runMirror,
	Writing = runWriting,
	Footsteps = runFootsteps,
}

local function fire(zone: Instance)
	local kind = zone:GetAttribute("Event")
	local run = kind and RUNNERS[kind]
	if not run then
		return
	end
	busy = true
	lastEvent = os.clock()
	local ok, err = pcall(run, zone)
	if not ok then
		warn("[Events] " .. tostring(kind) .. ": " .. tostring(err))
		restoreLamps()
	end
	busy = false
end

-- Always-on ambience ------------------------------------------------------------------------------
local function candles()
	local base: { [Light]: number } = {}
	RunService.Heartbeat:Connect(function()
		for _, flame in CollectionService:GetTagged("Candle") do
			local l = flame:FindFirstChildOfClass("PointLight")
			if l then
				if base[l] == nil then
					base[l] = l.Brightness
				end
				l.Brightness = base[l] * (0.75 + math.random() * 0.4)
				if flame:IsA("BasePart") then
					flame.LocalTransparencyModifier = math.random() * 0.25
				end
			end
		end
	end)
end

local function lightning()
	while true do
		task.wait(Config.LightningEvery[1] + math.random() * (Config.LightningEvery[2] - Config.LightningEvery[1]))
		local wins = CollectionService:GetTagged("StormWindow")
		if #wins == 0 then
			continue
		end
		local base = {}
		for _, w in wins do
			local l = w:FindFirstChild("Moonlight")
			if l then
				base[l] = { l.Brightness, l.Color }
			end
		end
		for flash = 1, math.random(1, 3) do
			for l in base do
				l.Brightness = 9
				l.Color = Color3.fromRGB(225, 235, 255)
			end
			task.wait(0.05 + math.random() * 0.08)
			for l, b in base do
				l.Brightness = b[1]
				l.Color = b[2]
			end
			task.wait(0.06 + math.random() * 0.15)
		end
		task.wait(0.4 + math.random() * 1.2) -- thunder follows the flash
		local near = wins[math.random(#wins)]
		soundAt(near.Position, S.Thunder, 2.5, 0.9 + math.random() * 0.2, 12)
	end
end

local function rockingChairs()
	local creaks: { [Instance]: Sound } = {}
	RunService.RenderStepped:Connect(function()
		local r = myRoot()
		for _, chair in CollectionService:GetTagged("RockingChair") do
			local base = (chair :: Model).PrimaryPart
			if not base then
				continue
			end
			if not base:GetAttribute("RestCFrame") then
				base:SetAttribute("RestCFrame", base.CFrame)
			end
			local rest = base:GetAttribute("RestCFrame") :: CFrame
			local d = r and (r.Position - base.Position).Magnitude or math.huge
			-- rocks by itself while you're in the room (not too close)
			local rocking = d < 30 and d > 8 and isLiving()
			local angle = if rocking then math.sin(os.clock() * 2.2) * math.rad(9) else 0
			base.CFrame = rest * CFrame.new(0, 0, 0) * CFrame.Angles(angle, 0, 0)
			local creak = creaks[chair]
			if not creak then
				creak = Instance.new("Sound")
				creak.SoundId = S.Rocking
				creak.Looped = true
				creak.Volume = 1.2
				creak.RollOffMode = Enum.RollOffMode.InverseTapered
				creak.RollOffMinDistance = 4
				creak.RollOffMaxDistance = 35
				creak.Parent = base
				creaks[chair] = creak
			end
			if rocking and not creak.Playing then
				creak:Play()
			elseif not rocking and creak.Playing then
				creak:Stop()
			end
		end
	end)
end

local function portraits()
	local lastFlash = 0
	RunService.RenderStepped:Connect(function()
		if os.clock() - lastFlash < Config.PortraitFlashCooldown or not isLiving() then
			return
		end
		local r = myRoot()
		if not r then
			return
		end
		for _, p in CollectionService:GetTagged("Portrait") do
			local decal = p:FindFirstChild("Portrait") :: Decal?
			if decal and (p.Position - r.Position).Magnitude < 18 and facing(p.Position) > 0.93 and math.random() < 0.01 then
				lastFlash = os.clock()
				local original = decal.Texture
				decal.Texture = Config.ScareFlashImages[math.random(#Config.ScareFlashImages)]
				decal.Color3 = Color3.new(1, 1, 1)
				task.delay(0.12, function()
					decal.Texture = original
					decal.Color3 = Color3.fromRGB(150, 140, 125)
				end)
				break
			end
		end
	end)
end

function Events.Start()
	-- load the faces now so they're ready the instant they're needed
	task.spawn(function()
		local preload = {}
		for _, id in Config.ScareFlashImages do
			local d = Instance.new("Decal")
			d.Texture = id
			table.insert(preload, d)
		end
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(preload)
		end)
	end)
	trackLamps()
	task.delay(5, trackLamps)
	candles()
	rockingChairs()
	portraits()
	task.spawn(lightning)

	-- placed events
	task.spawn(function()
		while true do
			task.wait(0.15)
			local house = workspace:FindFirstChild("House")
			local folder = house and house:FindFirstChild("Events")
			local r = myRoot()
			if not folder or not r then
				continue
			end
			for _, zone in folder:GetChildren() do
				local trig = zone:FindFirstChild("Trigger") :: BasePart?
				if not trig then
					continue
				end
				local st = zoneState[zone]
				if not st then
					st = { inside = false, entries = 0, lastFired = -math.huge }
					zoneState[zone] = st
				end
				local now = inside(trig, r.Position)
				if now and not st.inside then
					st.entries += 1
					local needEntries = if zone:GetAttribute("Event") == "Writing" then 2 else 1
					local chance = zone:GetAttribute("Chance") or 1
					local cooldown = zone:GetAttribute("Cooldown") or 180
					if st.entries >= needEntries
						and canScare()
						and os.clock() - st.lastFired > cooldown
						and os.clock() - lastEvent > Config.EventGap
						and math.random() < chance
					then
						st.lastFired = os.clock()
						task.spawn(fire, zone)
					end
				end
				st.inside = now
			end
		end
	end)
	-- a fresh life, fresh scares
	localPlayer.CharacterAdded:Connect(function()
		for _, st in zoneState do
			st.lastFired = -math.huge
			st.entries = 0
		end
	end)

	-- Studio test hook: /event <name>
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local function hook(r: Instance)
		if r.Name == "Event" and r:IsA("RemoteEvent") then
			r.OnClientEvent:Connect(function(name: string)
				local folder = workspace:FindFirstChild("House") and workspace.House:FindFirstChild("Events")
				if not folder then
					return
				end
				-- the matching zone nearest you
				local best, bestD = nil, math.huge
				local root = myRoot()
				for _, zone in folder:GetChildren() do
					local kind = zone:GetAttribute("Event")
					if kind and string.lower(kind) == string.lower(name or "") then
						local t = zone:FindFirstChild("Trigger") :: BasePart?
						local d = (t and root) and (t.Position - root.Position).Magnitude or 0
						if d < bestD then
							best, bestD = zone, d
						end
					end
				end
				if best then
					if (best :: Instance):GetAttribute("Event") == "Writing" then
						written[best] = nil
					end
					task.spawn(fire, best)
				end
			end)
		end
	end
	for _, r in remotes:GetChildren() do
		hook(r)
	end
	remotes.ChildAdded:Connect(hook)
end

return Events
