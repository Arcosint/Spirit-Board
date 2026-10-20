-- The living can't see the demon, so this makes them feel it instead:
--   * lamps flicker and die as it walks past (for everyone)
--   * your heartbeat gets louder and faster the closer it is
--   * it whispers right next to you (3D, so you can tell which side it's on)
--   * once in a while you catch a split-second glimpse of it: the lamps cut out and it's just... there
-- The demon's breathing and growls come from the server (DemonService) so everyone hears the same thing.
-- All of this runs on your own screen only. Tuning numbers are in shared/Config.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DemonPresence = {}

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local lampBase: { [Light]: number } = {}
local lastGlimpse = 0
local nextWhisper = 0
local glimpsing = false

local function isLiving(): boolean
	return localPlayer:GetAttribute("IsGhost") ~= true and localPlayer:GetAttribute("BeingTaken") ~= true
end

local function demonRoot(): BasePart?
	local demon = workspace:FindFirstChild("Demon")
	return demon and demon:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function trackLamps()
	local house = workspace:FindFirstChild("House")
	local lights = house and house:FindFirstChild("Lights")
	if not lights then
		return
	end
	for _, d in lights:GetDescendants() do
		if d:IsA("Light") and lampBase[d] == nil then
			lampBase[d] = d.Brightness
		end
	end
end

-- Lamps near the demon stutter; right next to it they go out.
local function flickerLamps(demonPos: Vector3?)
	for light, base in lampBase do
		if not light.Parent then
			lampBase[light] = nil
			continue
		end
		if glimpsing or localPlayer:GetAttribute("HauntingLights") then
			continue -- a random scare (client/Haunting) has the lamps right now
		end
		local part = light.Parent
		local d = if demonPos and part:IsA("BasePart") then (part.Position - demonPos).Magnitude else math.huge
		if d < 8 then
			light.Brightness = if math.random() < 0.06 then base * 0.4 else 0
		elseif d < Config.DemonPresenceRange then
			local near = 1 - d / Config.DemonPresenceRange
			if math.random() < 0.08 + 0.35 * near then
				light.Brightness = base * math.random() * 0.35
			else
				light.Brightness = base * (1 - 0.3 * near)
			end
		else
			light.Brightness = base
		end
	end
end

local function setDemonVisible(demon: Instance, visible: boolean)
	for _, d in demon:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if visible then 0 else 1
		elseif d:IsA("PointLight") then
			d.Enabled = visible -- the red glow of its eyes
		end
	end
end

-- For a blink: the lamps die and it's standing right there. Then it's gone.
local function glimpse()
	local demon = workspace:FindFirstChild("Demon")
	if not demon or glimpsing then
		return
	end
	glimpsing = true
	lastGlimpse = os.clock()
	for light in lampBase do
		light.Brightness = 0
	end
	setDemonVisible(demon, true)
	task.wait(0.1 + math.random() * 0.1)
	if demon.Parent and isLiving() then
		setDemonVisible(demon, false)
	end
	task.wait(0.15)
	glimpsing = false
end

local function whisperFrom(at: BasePart)
	local s = Instance.new("Sound")
	s.SoundId = Config.ScareSounds.WhisperShort
	s.Volume = 1.6
	s.PlaybackSpeed = 0.85 + math.random() * 0.2
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 4
	s.RollOffMaxDistance = Config.DemonPresenceRange + 10
	s.Parent = at -- made on this client, so only you hear it
	s:Play()
	task.delay(5, function()
		s:Destroy()
	end)
end

function DemonPresence.Start()
	trackLamps()
	local house = workspace:FindFirstChild("House")
	if house then
		house.DescendantAdded:Connect(function(d)
			if d:IsA("Light") then
				trackLamps()
			end
		end)
	end
	workspace.ChildAdded:Connect(function(c)
		if c.Name == "House" then
			task.wait(1)
			trackLamps()
		end
	end)

	local heart = Instance.new("Sound")
	heart.Name = "DemonHeartbeat"
	heart.SoundId = Config.ScareSounds.Heartbeat
	heart.Looped = true
	heart.Volume = 0
	heart.Parent = SoundService

	local lampTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		local root = demonRoot()
		local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?

		lampTimer += dt
		if lampTimer > 0.08 then
			lampTimer = 0
			flickerLamps(root and root.Position)
		end

		if not root or not myRoot or not isLiving() then
			heart.Volume = 0
			if heart.Playing then
				heart:Pause()
			end
			return
		end

		local d = (root.Position - myRoot.Position).Magnitude
		local near = math.clamp(1 - d / Config.DemonPresenceRange, 0, 1)

		-- heartbeat
		if near > 0 then
			if not heart.Playing then
				heart:Resume()
			end
			heart.Volume = 0.3 + 1.7 * near
			heart.PlaybackSpeed = 1 + 0.9 * near
		else
			heart.Volume = 0
			if heart.Playing then
				heart:Pause()
			end
		end

		-- whispers
		local now = os.clock()
		if near > 0.3 and now > nextWhisper then
			nextWhisper = now + 8 + math.random() * 10
			whisperFrom(root)
		end

		-- glimpses: only when it's close and somewhere in front of you
		if near > 0.25 and now - lastGlimpse > Config.GlimpseCooldown then
			local toDemon = (root.Position - camera.CFrame.Position).Unit
			if toDemon:Dot(camera.CFrame.LookVector) > 0.55 and math.random() < dt * 0.4 then
				task.spawn(glimpse)
			end
		end
	end)
end

return DemonPresence
