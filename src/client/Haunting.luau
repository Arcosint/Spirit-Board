-- The house is never quiet, and it plays with you even when the demon isn't killing you.
--
-- Always (everyone):
--   * a low drone and rumble under everything, with an echoey reverb
--   * a colder, darker grade and a dark vignette around the edges of the screen
--   * every so often a noise somewhere nearby: knocking, tapping on glass, floorboards, something falling,
--     and very rarely a music box starts playing in another room
--
-- Random scares (living players only, nobody dies). Every minute or two, more often when the demon is near:
--   * BLACKOUT FACE:  the lamps stutter, everything goes dark and silent... then a face slams onto your screen, shrieking
--   * BEHIND YOU:     the house goes silent, something whispers right behind you, "behind you" fades in, then a BANG
--   * I SEE YOU:      silence, the lamps fade, "i see you" whispered in your ear as the words appear... then a face
--   * LIGHTS DIE:     the lamps die one by one, and in the dark something is breathing right next to you
--
-- All of this runs only on your own screen. Every sound, image and timing is in shared/Config.
-- In Studio, /haunt plays a random scare on you right away (see server/DevCommands).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Haunting = {}

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local lamps: { [Light]: number } = {}
local scaring = false
local drone: Sound
local rumble: Sound
local gui: ScreenGui

local function rand(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

local function isLiving(): boolean
	return localPlayer:GetAttribute("IsGhost") ~= true and localPlayer:GetAttribute("BeingTaken") ~= true
end

local function trackLamps()
	local house = workspace:FindFirstChild("House")
	local folder = house and house:FindFirstChild("Lights")
	if not folder then
		return
	end
	for _, d in folder:GetDescendants() do
		if d:IsA("Light") and lamps[d] == nil then
			lamps[d] = d.Brightness
		end
	end
end

local function setLamps(mult: number)
	for light, base in lamps do
		if light.Parent then
			light.Brightness = base * mult
		end
	end
end

local function sound2D(id: string, volume: number, speed: number?): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed or 1
	s.Parent = SoundService
	s.Ended:Connect(function()
		s:Destroy()
	end)
	s:Play()
	return s
end

-- A sound coming from a spot in the world (you can tell which direction it's from).
local function soundAt(position: Vector3, id: string, volume: number, speed: number?, lifetime: number?): Sound
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 5
	s.RollOffMaxDistance = 80
	s.Parent = a
	s:Play()
	task.delay(lifetime or 12, function()
		a:Destroy()
	end)
	return s
end

-- A random spot somewhere around you (in the next room, behind a wall...).
local function nearbySpot(minDist: number, maxDist: number): Vector3
	local angle = math.random() * math.pi * 2
	local d = minDist + math.random() * (maxDist - minDist)
	local base = camera.CFrame.Position
	return Vector3.new(base.X + math.cos(angle) * d, base.Y, base.Z + math.sin(angle) * d)
end

local function duckAmbience(to: number, time: number)
	local info = TweenInfo.new(time)
	TweenService:Create(drone, info, { Volume = 0.45 * to }):Play()
	TweenService:Create(rumble, info, { Volume = 0.3 * to }):Play()
end

-- Darken the room on this screen only. Returns a function that puts it back.
local function darkenRoom(): () -> ()
	local ambient, outdoor, exposure = Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.ExposureCompensation
	Lighting.Ambient = Color3.new(0, 0, 0)
	Lighting.OutdoorAmbient = Color3.new(0, 0, 0)
	Lighting.ExposureCompensation = exposure - 1.5
	return function()
		Lighting.Ambient = ambient
		Lighting.OutdoorAmbient = outdoor
		Lighting.ExposureCompensation = exposure
	end
end

-- Stutter the lamps for a while.
local function flicker(duration: number, darkChance: number)
	local stop = os.clock() + duration
	while os.clock() < stop and isLiving() do
		setLamps(if math.random() < darkChance then math.random() * 0.15 else 0.6 + math.random() * 0.5)
		task.wait(0.04 + math.random() * 0.1)
	end
end

local function overlayFrame(color: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = z
	f.Parent = gui
	return f
end

local function faceSlam(duration: number)
	local holder = overlayFrame(Color3.new(0, 0, 0), 10)
	local face = Instance.new("ImageLabel")
	face.BackgroundTransparency = 1
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.SizeConstraint = Enum.SizeConstraint.RelativeYY
	face.Size = UDim2.fromScale(0.7, 0.7)
	face.ScaleType = Enum.ScaleType.Fit
	face.Image = Config.ScareFlashImages[math.random(#Config.ScareFlashImages)]
	face.ZIndex = 11
	face.Parent = holder
	TweenService:Create(face, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1.5, 1.5),
	}):Play()
	sound2D(Config.ScareSounds.ShriekShort, 3.5, 0.9 + math.random() * 0.2)
	local stop = os.clock() + duration
	while os.clock() < stop do
		face.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.04, 0.5 + (math.random() - 0.5) * 0.04)
		face.ImageColor3 = if math.random() < 0.3 then Color3.fromRGB(255, 70, 70) else Color3.new(1, 1, 1)
		holder.BackgroundColor3 = if math.random() < 0.25 then Color3.fromRGB(60, 0, 0) else Color3.new(0, 0, 0)
		RunService.RenderStepped:Wait()
	end
	holder:Destroy()
end

-- The scares ---------------------------------------------------------------------------------

local function blackoutFace()
	flicker(1.4, 0.45)
	setLamps(0)
	local restoreRoom = darkenRoom()
	duckAmbience(0, 0.2)
	task.wait(0.9 + math.random() * 0.9) -- dark. silent. waiting.
	if isLiving() then
		faceSlam(0.45)
	end
	local black = overlayFrame(Color3.new(0, 0, 0), 9)
	task.wait(0.35)
	black:Destroy()
	restoreRoom()
	flicker(0.9, 0.5)
	setLamps(1)
	duckAmbience(1, 2)
end

local function behindYou()
	duckAmbience(0, 0.6)
	setLamps(0.3)
	task.wait(1.2)
	local behind = camera.CFrame * CFrame.new(0.6, -0.3, 2.5)
	soundAt(behind.Position, Config.ScareSounds.WhisperShort, 2.5, 0.8, 6)

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.82)
	text.Size = UDim2.fromScale(0.8, 0.07)
	text.Font = Config.TextFont
	text.TextScaled = true
	text.Text = "behind you"
	text.TextColor3 = Color3.fromRGB(220, 215, 205)
	text.TextTransparency = 1
	text.TextStrokeTransparency = 1
	text.ZIndex = 5
	text.Parent = gui
	TweenService:Create(text, TweenInfo.new(1.2), { TextTransparency = 0.05, TextStrokeTransparency = 0.6 }):Play()
	task.wait(2.2)
	TweenService:Create(text, TweenInfo.new(0.25), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	-- BANG, right next to you
	soundAt((camera.CFrame * CFrame.new(-3, 0, 1)).Position, Config.HouseNoises[4], 3, 0.9, 6)
	flicker(0.5, 0.6)
	setLamps(1)
	duckAmbience(1, 1.5)
	text:Destroy()
end

-- Silence. The lamps fade. Something whispers "i see you" right in your ear, and the words appear...
-- then the lights snap off and a face slams onto the screen.
local function iSeeYou()
	duckAmbience(0, 0.8)
	local fadeOut = os.clock() + 1.2
	while os.clock() < fadeOut and isLiving() do
		setLamps(math.max(0.12, (fadeOut - os.clock()) / 1.2))
		task.wait(0.05)
	end
	sound2D(Config.ScareSounds.WhisperShort, 3.5, 0.75)

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.45)
	text.Size = UDim2.fromScale(0.8, 0.14)
	text.Font = Config.TextFont
	text.TextScaled = true
	text.Text = "I SEE YOU"
	text.TextColor3 = Color3.fromRGB(150, 0, 10)
	text.TextTransparency = 1
	text.TextStrokeColor3 = Color3.new(0, 0, 0)
	text.TextStrokeTransparency = 1
	text.ZIndex = 5
	text.Parent = gui
	TweenService:Create(text, TweenInfo.new(1.6, Enum.EasingStyle.Sine), {
		TextTransparency = 0,
		TextStrokeTransparency = 0.3,
		Size = UDim2.fromScale(0.95, 0.17),
	}):Play()
	task.wait(2)

	-- SNAP
	text:Destroy()
	setLamps(0)
	local restoreRoom = darkenRoom()
	task.wait(0.25)
	if isLiving() then
		faceSlam(0.4)
	end
	restoreRoom()
	flicker(0.8, 0.5)
	setLamps(1)
	duckAmbience(1, 2)
end

local function lightsDie()
	-- one by one...
	local list = {}
	for light in lamps do
		table.insert(list, light)
	end
	table.sort(list, function(a, b)
		local pa = a.Parent :: BasePart
		local pb = b.Parent :: BasePart
		local cam = camera.CFrame.Position
		return (pa.Position - cam).Magnitude > (pb.Position - cam).Magnitude -- furthest first, the dark comes towards you
	end)
	for _, light in list do
		for _ = 1, 3 do
			light.Brightness = 0
			task.wait(0.04)
			light.Brightness = lamps[light]
			task.wait(0.05)
		end
		light.Brightness = 0
		task.wait(0.25)
	end
	local restoreRoom = darkenRoom()
	duckAmbience(0.2, 1)
	-- something breathing right next to you
	local breath = soundAt((camera.CFrame * CFrame.new(1.5, 0, 1)).Position, Config.ScareSounds.Breathing, 2.5, 0.8, 7)
	task.wait(3.5)
	breath:Stop()
	restoreRoom()
	flicker(0.7, 0.4)
	setLamps(1)
	duckAmbience(1, 2)
end

-- name, function, how often it's picked
local SCARES = {
	{ "iseeyou", iSeeYou, 35 },
	{ "blackout", blackoutFace, 30 },
	{ "behind", behindYou, 20 },
	{ "lights", lightsDie, 15 },
}

local function pickScare(): () -> ()
	local total = 0
	for _, s in SCARES do
		total += s[3]
	end
	local r = math.random() * total
	for _, s in SCARES do
		r -= s[3]
		if r <= 0 then
			return s[2]
		end
	end
	return SCARES[1][2]
end

local function runScare(fn: (() -> ())?)
	if scaring or not isLiving() then
		return
	end
	scaring = true
	localPlayer:SetAttribute("HauntingLights", true) -- tells DemonPresence to leave the lamps alone
	local ok, err = pcall(fn or pickScare())
	if not ok then
		warn("[Haunting] " .. tostring(err))
	end
	setLamps(1)
	duckAmbience(1, 1)
	localPlayer:SetAttribute("HauntingLights", nil)
	scaring = false
end

-- Setup --------------------------------------------------------------------------------------

local function buildScreen()
	gui = Instance.new("ScreenGui")
	gui.Name = "Haunting"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	-- Dark vignette around the edges of the screen.
	local vignette = Instance.new("ScreenGui")
	vignette.Name = "Vignette"
	vignette.IgnoreGuiInset = true
	vignette.ResetOnSpawn = false
	vignette.DisplayOrder = -1
	vignette.Parent = gui.Parent
	local sides = {
		{ UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0), 90 }, -- top
		{ UDim2.fromScale(1, 0.35), UDim2.fromScale(0, 0.65), -90 }, -- bottom
		{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0, 0), 0 }, -- left
		{ UDim2.fromScale(0.3, 1), UDim2.fromScale(0.7, 0), 180 }, -- right
	}
	for _, s in sides do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Size = s[1]
		f.Position = s[2]
		f.Parent = vignette
		local g = Instance.new("UIGradient")
		g.Rotation = s[3]
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
	end
end

function Haunting.Start()
	trackLamps()
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Light") and d:IsDescendantOf(workspace:FindFirstChild("House") or workspace) then
			task.defer(trackLamps)
		end
	end)

	buildScreen()

	-- colder, darker, a little washed out
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "HauntGrade"
	grade.Saturation = -0.15
	grade.Contrast = 0.12
	grade.TintColor = Color3.fromRGB(225, 235, 255)
	grade.Parent = Lighting

	-- echoey house
	pcall(function()
		SoundService.AmbientReverb = Enum.ReverbType.Hallway
	end)

	-- the drone that never stops
	drone = Instance.new("Sound")
	drone.Name = "HauntDrone"
	drone.SoundId = Config.AmbientSounds.Drone
	drone.Looped = true
	drone.Volume = 0.45
	drone.PlaybackSpeed = 0.85
	drone.Parent = SoundService
	drone:Play()
	rumble = Instance.new("Sound")
	rumble.Name = "HauntRumble"
	rumble.SoundId = Config.AmbientSounds.Rumble
	rumble.Looped = true
	rumble.Volume = 0.3
	rumble.PlaybackSpeed = 0.7
	rumble.Parent = SoundService
	rumble:Play()

	-- noises in the house
	task.spawn(function()
		while true do
			task.wait(rand(Config.HouseNoiseEvery))
			if math.random() < 0.08 then
				local box = soundAt(nearbySpot(25, 40), Config.MusicBox, 0.9, 0.82, 16)
				task.delay(12, function()
					TweenService:Create(box, TweenInfo.new(3), { Volume = 0 }):Play()
				end)
			else
				local id = Config.HouseNoises[math.random(#Config.HouseNoises)]
				soundAt(nearbySpot(12, 35), id, 1.2 + math.random() * 0.8, 0.85 + math.random() * 0.2, 8)
			end
		end
	end)

	-- random scares
	local nextScare = os.clock() + Config.FirstRandomScareAfter + rand(Config.RandomScareEvery) * 0.5
	localPlayer.CharacterAdded:Connect(function()
		nextScare = math.max(nextScare, os.clock() + Config.FirstRandomScareAfter)
	end)
	task.spawn(function()
		while true do
			local dt = task.wait(0.5)
			-- time runs out twice as fast while the demon is close
			local demon = workspace:FindFirstChild("Demon")
			local root = demon and demon:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - camera.CFrame.Position).Magnitude < Config.DemonPresenceRange then
				nextScare -= dt
			end
			if os.clock() >= nextScare and not scaring and isLiving() then
				nextScare = os.clock() + rand(Config.RandomScareEvery)
				task.spawn(runScare)
			end
		end
	end)

	-- Studio test hook: /haunt
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local function hook(r: Instance)
		if r.Name == "Haunt" and r:IsA("RemoteEvent") then
			r.OnClientEvent:Connect(function(which: string?)
				local pick = nil
				for _, s in SCARES do
					if s[1] == which then
						pick = s[2]
					end
				end
				task.spawn(runScare, pick)
			end)
		end
	end
	for _, r in remotes:GetChildren() do
		hook(r)
	end
	remotes.ChildAdded:Connect(hook)
end

return Haunting
