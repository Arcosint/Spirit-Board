-- Everything on screen that isn't the ghost board:
--   big announcements ("FLOOR 1", "BANISHED"), small notifications, the relic counter,
--   and a red tint for living players when the (invisible) demon gets close.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local HUD = {}

local localPlayer = Players.LocalPlayer
local TEXT = Color3.fromRGB(235, 225, 210)

local function text(parent: Instance, size: number, pos: UDim2, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = pos
	l.Size = UDim2.new(0.9, 0, 0, height)
	l.Font = Config.TextFont
	l.TextSize = size
	l.TextColor3 = TEXT
	l.TextStrokeTransparency = 0.4
	l.TextWrapped = true
	l.Text = ""
	l.Parent = parent
	return l
end

function HUD.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local announce = remotes:WaitForChild("Announce") :: RemoteEvent
	local notify = remotes:WaitForChild("Notify") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = true
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	-- Danger tint (living only)
	local danger = Instance.new("Frame")
	danger.Name = "Danger"
	danger.Size = UDim2.fromScale(1, 1)
	danger.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	danger.BackgroundTransparency = 1
	danger.BorderSizePixel = 0
	danger.ZIndex = 0
	danger.Parent = gui

	-- Big announcement
	local title = text(gui, 46, UDim2.new(0.5, 0, 0.2, 0), 56)
	local subtitle = text(gui, 20, UDim2.new(0.5, 0, 0.2, 60), 50)
	local announceToken = 0
	announce.OnClientEvent:Connect(function(t: string, sub: string?)
		announceToken += 1
		local mine = announceToken
		title.Text = t or ""
		subtitle.Text = sub or ""
		title.TextTransparency, subtitle.TextTransparency = 0, 0
		title.TextStrokeTransparency, subtitle.TextStrokeTransparency = 0.4, 0.4
		task.delay(4.5, function()
			if mine ~= announceToken then
				return
			end
			local info = TweenInfo.new(1)
			for _, l in { title, subtitle } do
				TweenService:Create(l, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	end)

	-- Small notification (bottom)
	local toast = text(gui, 20, UDim2.new(0.5, 0, 0.72, 0), 30)
	local toastToken = 0
	notify.OnClientEvent:Connect(function(message: string)
		toastToken += 1
		local mine = toastToken
		toast.Text = message
		task.delay(3, function()
			if mine == toastToken then
				toast.Text = ""
			end
		end)
	end)

	-- Relic counter (top)
	local counter = text(gui, 18, UDim2.new(0.5, 0, 0, 52), 24)
	local function updateCounter()
		local total = workspace:GetAttribute("RelicsTotal") or 0
		local placed = workspace:GetAttribute("RelicsPlaced") or 0
		if total == 0 then
			counter.Text = ""
		elseif workspace:GetAttribute("RitualReady") then
			counter.Text = "The board is ready. Speak its name."
		else
			counter.Text = ("Relics %d / %d"):format(placed, total)
		end
	end
	for _, attr in { "RelicsTotal", "RelicsPlaced", "RitualReady" } do
		workspace:GetAttributeChangedSignal(attr):Connect(updateCounter)
	end
	updateCounter()

	-- Danger tint follows the demon's distance; pulses like a heartbeat.
	RunService.RenderStepped:Connect(function()
		local demon = workspace:FindFirstChild("Demon")
		local demonRoot = demon and demon:FindFirstChild("HumanoidRootPart") :: BasePart?
		local myRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not demonRoot or not myRoot or localPlayer:GetAttribute("IsGhost") == true then
			danger.BackgroundTransparency = 1
			return
		end
		local d = (demonRoot.Position - myRoot.Position).Magnitude
		local closeness = math.clamp(1 - d / Config.DangerVignetteRange, 0, 1)
		local pulse = 0.75 + 0.25 * math.sin(os.clock() * (4 + closeness * 6))
		danger.BackgroundTransparency = 1 - 0.35 * closeness * pulse
	end)
end

return HUD
