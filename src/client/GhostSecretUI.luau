-- Once all relics are placed, ghosts see the demon's true name here. Their job: spell it on the board.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local GhostSecretUI = {}

local localPlayer = Players.LocalPlayer

function GhostSecretUI.Start()
	local ghostSecret = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GhostSecret") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "GhostSecret"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Enabled = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Position = UDim2.new(0, 16, 0, 90)
	panel.Size = UDim2.new(0, 220, 0, 86)
	panel.BackgroundColor3 = Color3.fromRGB(20, 16, 22)
	panel.BackgroundTransparency = 0.25
	panel.Parent = gui
	Instance.new("UICorner").Parent = panel

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, 0, 0, 28)
	hint.Font = Config.TextFont
	hint.TextSize = 16
	hint.TextColor3 = Color3.fromRGB(190, 220, 255)
	hint.Text = "Its true name. Spell it for them:"
	hint.Parent = panel

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 0, 0, 28)
	nameLabel.Size = UDim2.new(1, 0, 0, 50)
	nameLabel.Font = Config.TextFont
	nameLabel.TextSize = 38
	nameLabel.TextColor3 = Color3.fromRGB(220, 40, 40)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Text = ""
	nameLabel.Parent = panel

	local secret: string? = nil
	local function refresh()
		gui.Enabled = secret ~= nil and localPlayer:GetAttribute("IsGhost") == true
		nameLabel.Text = secret or ""
	end
	ghostSecret.OnClientEvent:Connect(function(name: string?)
		secret = name
		refresh()
	end)
	localPlayer:GetAttributeChangedSignal("IsGhost"):Connect(function()
		if localPlayer:GetAttribute("IsGhost") ~= true then
			secret = nil -- revived: forget it
		end
		refresh()
	end)
end

return GhostSecretUI
