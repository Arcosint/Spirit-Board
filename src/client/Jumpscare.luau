-- The kill, on the victim's screen. The server fires "start" (with how long the dread lasts) when the demon grabs you:
--   1. DREAD: you're frozen. The lamps around you die, the dark closes in from the edges, your heart pounds,
--      something breathes heavily right in your ear and whispers "i see you"... and your view is slowly
--      dragged around to look behind you, where it's standing.
--   2. FALSE CALM: you've turned around and... nothing. The lamps flicker back on, your heart stops pounding.
--   3. SILENCE: everything cuts to black and dead silence for a moment.
--   4. THE FACE: the demon itself (the real 3D one) lunges into your face, lit red from below, with a heavy
--      impact, a shriek, a scream and a roar. It bites: bones crack, blood splatters across the screen, it bites again.
--      (If there's no demon in the world, a face image lunges at the screen instead.)
--   5. DEAD: your view drops to the floor as the screen floods red, then black, and blood runs down it until
--      you come back as a ghost.
-- "cancel" stops it early (e.g. the demon got banished mid-kill).
-- Timings, images and sounds all live in shared/Config.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Jumpscare = {}

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local token = 0
local cleanupFns: { () -> () } = {}

local function newSound(id: string, volume: number, speed: number?, looped: boolean?): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed or 1
	s.Looped = looped == true
	s.Parent = SoundService -- not in the world, so it plays straight into your ears
	table.insert(cleanupFns, function()
		s:Destroy()
	end)
	return s
end

local function setCoreGui(enabled: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, enabled)
	end)
end

local function cleanup()
	for _, fn in cleanupFns do
		pcall(fn)
	end
	table.clear(cleanupFns)
end

local function frame(parent: Instance, color: Color3, transparency: number, z: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function image(parent: Instance, id: string, z: number): ImageLabel
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = id
	i.ZIndex = z
	i.Parent = parent
	return i
end

local function run(dreadOverride: number?)
	token += 1
	local mine = token
	cleanup()

	local character = localPlayer.Character
	if not character then
		return
	end
	local dreadEnd = dreadOverride or Config.ScareDreadTime
	local calmAt = dreadEnd * (Config.ScareCalmPart or 0.72) -- when the false calm starts
	local blackEnd = dreadEnd + Config.ScareBlackoutTime
	local faceEnd = blackEnd + Config.ScareFaceTime

	-- Screen pieces -------------------------------------------------------
	local gui = Instance.new("ScreenGui")
	gui.Name = "Jumpscare"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	table.insert(cleanupFns, function()
		gui:Destroy()
	end)

	-- the dark closing in from the edges
	local closing = {}
	for _, s in {
		{ UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0.5), -90 },
		{ UDim2.fromScale(0.5, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.5, 1), UDim2.fromScale(0.5, 0), 180 },
	} do
		local f = frame(gui, Color3.new(0, 0, 0), 0, 1)
		f.Size = s[1]
		f.Position = s[2]
		local g = Instance.new("UIGradient")
		g.Rotation = s[3]
		g.Parent = f
		table.insert(closing, g)
	end
	local function setClosing(k: number) -- 0 = open, 1 = almost shut
		local edge = 0.15 + 0.85 * (1 - k)
		for _, g in closing do
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1 - k * 0.95),
				NumberSequenceKeypoint.new(math.clamp(edge, 0.05, 0.99), 1),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	end
	setClosing(0)

	local redWash = frame(gui, Color3.fromRGB(110, 0, 0), 1, 2)
	local black = frame(gui, Color3.new(0, 0, 0), 1, 5)

	local faceBg = frame(gui, Color3.new(0, 0, 0), 0, 6)
	faceBg.Visible = false

	local face = image(faceBg, Config.ScareFaceImage, 7)
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.SizeConstraint = Enum.SizeConstraint.RelativeYY
	face.Size = UDim2.fromScale(0.6, 0.6)
	face.ScaleType = Enum.ScaleType.Fit

	-- blood: a ring around the edges, splatters that slam onto the screen, drips that run down it
	local bloodRing = image(gui, Config.Gore.Border, 8)
	bloodRing.Size = UDim2.fromScale(1, 1)
	bloodRing.ScaleType = Enum.ScaleType.Stretch
	bloodRing.ImageTransparency = 1

	local splats: { ImageLabel } = {}
	local function splatter(count: number)
		for _ = 1, count do
			local s = image(gui, Config.Gore.Splatters[math.random(#Config.Gore.Splatters)], 9)
			s.AnchorPoint = Vector2.new(0.5, 0.5)
			s.SizeConstraint = Enum.SizeConstraint.RelativeYY
			-- around the face, not on top of it
			local angle = math.random() * math.pi * 2
			local dist = 0.22 + math.random() * 0.2
			s.Position = UDim2.fromScale(0.5 + math.cos(angle) * dist * 1.4, 0.5 + math.sin(angle) * dist)
			s.Rotation = math.random(0, 359)
			s.ScaleType = Enum.ScaleType.Fit
			s.Size = UDim2.fromScale(0.2, 0.2)
			local final = 0.3 + math.random() * 0.35
			TweenService:Create(s, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(final, final),
			}):Play()
			table.insert(splats, s)
		end
	end

	local drips = image(gui, Config.Gore.Drips, 10)
	drips.Size = UDim2.fromScale(1, 0.7)
	drips.Position = UDim2.fromScale(0, -0.7)
	drips.ScaleType = Enum.ScaleType.Stretch
	drips.Visible = false

	-- Lighting: drain the colour, darken -------------------------------------
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "JumpscareGrade"
	grade.Parent = Lighting
	table.insert(cleanupFns, function()
		grade:Destroy()
	end)

	-- The lamps near you die (only on your screen).
	local dimmed: { [Light]: number } = {}
	local house = workspace:FindFirstChild("House")
	local lights = house and house:FindFirstChild("Lights")
	local myRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if lights and myRoot then
		for _, l in lights:GetDescendants() do
			local p = l.Parent
			if l:IsA("Light") and p and p:IsA("BasePart") and (p.Position - myRoot.Position).Magnitude < 40 then
				dimmed[l] = l.Brightness
			end
		end
	end
	localPlayer:SetAttribute("HauntingLights", true) -- keep the other scripts off the lamps
	table.insert(cleanupFns, function()
		for l, b in dimmed do
			l.Brightness = b
		end
		localPlayer:SetAttribute("HauntingLights", nil)
	end)

	-- Camera: you can't look away ------------------------------------------
	local baseCFrame = camera.CFrame
	local baseFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	table.insert(cleanupFns, function()
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = baseFov
	end)

	setCoreGui(false)
	table.insert(cleanupFns, function()
		setCoreGui(true)
	end)

	-- Hide the rest of our own UI (relic counter etc.) so nothing breaks the moment.
	local hidden: { ScreenGui } = {}
	for _, g in localPlayer.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	table.insert(cleanupFns, function()
		for _, g in hidden do
			if g.Parent then
				g.Enabled = true
			end
		end
	end)

	-- Sounds -----------------------------------------------------------------
	local heart = newSound(Config.ScareSounds.Heartbeat, 1.4, 1.5, true)
	local breath = newSound(Config.ScareSounds.Breathing, 0, 0.8, true)
	local whisper = newSound(Config.ScareSounds.WhisperShort, 3, 0.8)
	local scream = newSound(Config.ScareSounds.Scream, 3)
	local shriek = newSound(Config.ScareSounds.Shriek, 3.5)
	local roar = newSound(Config.ScareSounds.Roar, 2.5, 0.7)
	heart:Play()
	breath:Play()
	task.delay(dreadEnd * 0.45, function()
		if mine == token then
			whisper:Play()
		end
	end)
	local sting = newSound(Config.ScareSounds.Sting or Config.Gore.BoneCrack, 4, 0.8)

	-- The demon itself. The living can't normally see it; for this, you do.
	local demon = workspace:FindFirstChild("Demon")
	local demonRoot = demon and demon:FindFirstChild("HumanoidRootPart") :: BasePart?
	local in3D = demonRoot ~= nil
	local headPos = Vector3.zero
	local demonLook = Vector3.new(0, 0, -1)
	local faceLight: PointLight? = nil

	local function reveal(on: boolean)
		if not demon then
			return
		end
		for _, d in demon:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name ~= "HumanoidRootPart" then
					d.LocalTransparencyModifier = if on then 0 else 1
				end
			elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Highlight") then
				(d :: any).Enabled = on
			end
		end
	end
	table.insert(cleanupFns, function()
		-- called off before you died: it goes back to being invisible
		if demon and demon.Parent and localPlayer:GetAttribute("IsGhost") ~= true then
			reveal(false)
		end
	end)

	-- where its face is, and which way it's facing (towards you)
	local function findFace()
		if not demon or not demonRoot then
			return
		end
		local cf, size = (demon :: Model):GetBoundingBox()
		demonLook = demonRoot.CFrame.LookVector
		local top = cf.Position.Y + size.Y / 2
		headPos = Vector3.new(demonRoot.Position.X, top - 1.1, demonRoot.Position.Z) + demonLook * 0.4
	end

	-- a red light under its face, the only thing lighting it in the dark
	local function lightFace()
		local a = Instance.new("Attachment")
		a.WorldPosition = headPos + demonLook * 1.6 - Vector3.new(0, 1, 0)
		a.Parent = workspace.Terrain
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 70, 45)
		l.Brightness = 4
		l.Range = 9
		l.Shadows = false
		l.Parent = a
		faceLight = l
		table.insert(cleanupFns, function()
			a:Destroy()
		end)
	end

	local function bite()
		newSound(Config.Gore.BoneCrack, 3, 0.9 + math.random() * 0.2):Play()
		newSound(Config.Gore.Splatter, 3, 0.8 + math.random() * 0.2):Play()
		newSound(Config.Gore.Splatter, 2.5, 0.6):Play()
		splatter(3)
		redWash.BackgroundTransparency = 0.25
		TweenService:Create(redWash, TweenInfo.new(0.35), { BackgroundTransparency = 0.7 }):Play()
		baseCFrame = baseCFrame * CFrame.Angles(math.rad(math.random(-6, 6)), math.rad(math.random(-8, 8)), math.rad(math.random(-10, 10)))
	end

	-- Timeline ------------------------------------------------------------
	local start = os.clock()
	local phase = "dread"
	local faceStart = 0
	local bitten = 0
	local heldView = baseCFrame -- where the camera ended up after turning around
	local fallStart = 0
	local fallFrom = baseCFrame

	-- You've turned around. Nothing's there. The lamps come back, your heart stops pounding. Silence.
	local function enterCalm()
		phase = "calm"
		heart:Stop()
		breath:Stop()
		for l, b in dimmed do
			l.Brightness = b
		end
		setClosing(0.25)
		grade.Saturation = -0.3
		grade.Brightness = 0
		grade.TintColor = Color3.new(1, 1, 1)
		redWash.BackgroundTransparency = 1
	end

	local function enterBlackout()
		phase = "black"
		heart:Stop()
		breath:Stop()
		black.BackgroundTransparency = 0
	end

	local function enterFace()
		phase = "face"
		faceStart = os.clock()
		if in3D and demon and demon.Parent then
			findFace()
			reveal(true)
			lightFace()
			for l in dimmed do
				l.Brightness = 0 -- only its face is lit
			end
			black.BackgroundTransparency = 1
		else
			in3D = false
			faceBg.Visible = true
		end
		redWash.ZIndex = 8
		sting:Play()
		scream:Play()
		shriek:Play()
		roar:Play()
		-- It lunges at you.
		face.Size = UDim2.fromScale(0.5, 0.5)
		TweenService:Create(face, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(1.5, 1.5),
		}):Play()
		TweenService:Create(bloodRing, TweenInfo.new(0.5), { ImageTransparency = 0.05 }):Play()
	end

	local function finish()
		phase = "done"
		faceBg.Visible = false
		scream.Volume = 1.2 -- let the scream ring out
		-- flood red, then black, with blood running down
		if in3D then
			-- you drop: the view falls to the floor, looking up at it, as the red floods in
			fallStart = os.clock()
			fallFrom = camera.CFrame
			black.BackgroundTransparency = 0.6
			black.BackgroundColor3 = Color3.fromRGB(110, 0, 0)
			TweenService:Create(black, TweenInfo.new(1.1), {
				BackgroundTransparency = 0,
				BackgroundColor3 = Color3.new(0, 0, 0),
			}):Play()
		else
			black.BackgroundTransparency = 0
			black.BackgroundColor3 = Color3.fromRGB(90, 0, 0)
			TweenService:Create(black, TweenInfo.new(1.2), { BackgroundColor3 = Color3.new(0, 0, 0) }):Play()
		end
		for _, s in splats do
			s.ZIndex = 9
			TweenService:Create(s, TweenInfo.new(4, Enum.EasingStyle.Linear), {
				Position = s.Position + UDim2.fromScale(0, 0.25),
				ImageTransparency = 0.3,
			}):Play()
		end
		bloodRing.ZIndex = 9
		drips.Visible = true
		TweenService:Create(drips, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0, 0),
		}):Play()
	end

	local renderName = "Jumpscare" .. mine
	RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function()
		if mine ~= token then
			return
		end
		local t = os.clock() - start

		if phase == "dread" then
			local k = math.clamp(t / dreadEnd, 0, 1) -- 0 -> 1 as it gets worse

			-- the lamps sputter out
			for l, b in dimmed do
				l.Brightness = if math.random() < 0.15 + 0.6 * k then 0 else b * (1 - k)
			end

			-- the dark closes in, the colour drains, it gets redder
			setClosing(k)
			grade.Saturation = -0.8 * k
			grade.Brightness = -0.2 * k
			grade.TintColor = Color3.new(1, 1 - 0.45 * k, 1 - 0.45 * k)
			redWash.BackgroundTransparency = 1 - 0.25 * k * (0.6 + 0.4 * math.sin(t * 9))

			-- breathing gets louder, heart faster
			breath.Volume = 0.5 + 2.5 * k
			heart.PlaybackSpeed = 1.5 + 0.7 * k

			-- you're trembling, the view slowly pushes in, and something drags it around to look behind you
			local shake = 0.15 + 0.8 * k
			local view = baseCFrame
			if demonRoot and demonRoot.Parent then
				local target = Vector3.new(demonRoot.Position.X, baseCFrame.Position.Y, demonRoot.Position.Z)
				if (target - baseCFrame.Position).Magnitude > 0.5 then
					local turn = math.clamp(t / calmAt, 0, 1)
					turn = turn * turn * (3 - 2 * turn) -- slow start, slow end
					view = baseCFrame:Lerp(CFrame.lookAt(baseCFrame.Position, target), turn)
				end
			end
			heldView = view
			camera.CFrame = view
				* CFrame.Angles(math.rad((math.random() - 0.5) * shake), math.rad((math.random() - 0.5) * shake), 0)
			camera.FieldOfView = baseFov - 25 * k * k

			if t >= calmAt then
				enterCalm()
			end
		elseif phase == "calm" then
			-- nothing there. just you, breathing, in a quiet room
			local c = math.clamp((t - calmAt) / math.max(dreadEnd - calmAt, 0.01), 0, 1)
			camera.CFrame = heldView * CFrame.Angles(math.rad(math.sin(t * 2) * 0.4), math.rad(math.sin(t * 1.3) * 0.6), 0)
			camera.FieldOfView = baseFov - 25 + 18 * math.min(c * 3, 1)
			for l, b in dimmed do
				l.Brightness = if math.random() < 0.04 then b * 0.5 else b
			end
			if t >= dreadEnd then
				enterBlackout()
			end
		elseif phase == "black" then
			if t >= blackEnd then
				enterFace()
			end
		elseif phase == "face" then
			local f = os.clock() - faceStart
			if bitten == 0 and f > 0.15 then
				bitten = 1
				bite()
			elseif bitten == 1 and f > Config.ScareFaceTime * 0.55 then
				bitten = 2
				bite()
				face.Size = UDim2.fromScale(1.75, 1.75) -- it lunges in again
			end
			if in3D then
				-- it lunges out of the dark into your face, and lunges again on the second bite
				local lunge = math.clamp(f / 0.16, 0, 1)
				lunge = 1 - (1 - lunge) ^ 3
				local dist = 5.5 + (1.3 - 5.5) * lunge - (if bitten == 2 then 0.45 else 0)
				local violence = 7 * (1 - 0.35 * f / Config.ScareFaceTime)
				camera.FieldOfView = baseFov - 36 * lunge
				camera.CFrame = CFrame.lookAt(headPos + demonLook * dist, headPos)
					* CFrame.Angles(
						math.rad((math.random() - 0.5) * violence),
						math.rad((math.random() - 0.5) * violence),
						math.rad((math.random() - 0.5) * violence * 1.5)
					)
				if faceLight then
					faceLight.Brightness = 2.5 + math.random() * 3.5
				end
			else
				local shake = 0.04 * (1 - 0.4 * f / Config.ScareFaceTime)
				face.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * shake, 0.5 + (math.random() - 0.5) * shake)
				face.ImageColor3 = if math.random() < 0.15 then Color3.fromRGB(255, 80, 80) else Color3.new(1, 1, 1)
				camera.CFrame = baseCFrame * CFrame.Angles(math.rad((math.random() - 0.5) * 5), math.rad((math.random() - 0.5) * 5), 0)
			end
			if t >= faceEnd then
				finish()
			end
		elseif phase == "done" and in3D and os.clock() - fallStart < 0.9 then
			-- falling: the view drops to the floor and tips over, still looking up at it
			local k = math.clamp((os.clock() - fallStart) / 0.8, 0, 1)
			k = k * k
			local r = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local floor = (if r then r.Position else fallFrom.Position) - Vector3.new(0, 2.4, 0)
			local down = CFrame.lookAt(floor, headPos) * CFrame.Angles(0, 0, math.rad(70))
			camera.CFrame = fallFrom:Lerp(down, k)
		end
	end)
	table.insert(cleanupFns, function()
		RunService:UnbindFromRenderStep(renderName)
	end)

	-- Afterwards: hold until you come back as a ghost, then fade in.
	task.spawn(function()
		local respawned = false
		local conn = localPlayer.CharacterAdded:Connect(function()
			respawned = true
		end)
		table.insert(cleanupFns, function()
			conn:Disconnect()
		end)
		local deadline = os.clock() + faceEnd + Config.RespawnTime + 6
		while mine == token and not respawned and os.clock() < deadline do
			task.wait(0.1)
		end
		if mine ~= token then
			return
		end
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = baseFov
		faceBg.Visible = false
		local fade = TweenInfo.new(1.5)
		TweenService:Create(black, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(drips, fade, { ImageTransparency = 1 }):Play()
		TweenService:Create(bloodRing, fade, { ImageTransparency = 1 }):Play()
		for _, s in splats do
			TweenService:Create(s, fade, { ImageTransparency = 1 }):Play()
		end
		task.wait(1.6)
		if mine == token then
			cleanup()
		end
	end)
end

function Jumpscare.Start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Jumpscare") :: RemoteEvent
	remote.OnClientEvent:Connect(function(action: string, dread: number?)
		if action == "start" then
			run(if typeof(dread) == "number" then dread else nil)
		elseif action == "cancel" then
			token += 1
			cleanup()
		end
	end)
end

return Jumpscare
