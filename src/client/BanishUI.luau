-- When a living player uses "Speak its name" at the board, a box opens to type the demon's name.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local BanishUI = {}

local localPlayer = Players.LocalPlayer

function BanishUI.Start()
	local banishAttempt = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BanishAttempt") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "Banish"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Enabled = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0, 360, 0, 170)
	panel.BackgroundColor3 = Color3.fromRGB(20, 16, 22)
	panel.BackgroundTransparency = 0.1
	panel.Parent = gui
	Instance.new("UICorner").Parent = panel

	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Size = UDim2.new(1, 0, 0, 40)
	heading.Font = Config.TextFont
	heading.TextSize = 24
	heading.TextColor3 = Color3.fromRGB(235, 225, 210)
	heading.Text = "Speak its true name"
	heading.Parent = panel

	local box = Instance.new("TextBox")
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 50)
	box.Size = UDim2.new(1, -40, 0, 44)
	box.BackgroundColor3 = Color3.fromRGB(214, 190, 150)
	box.TextColor3 = Color3.fromRGB(45, 28, 18)
	box.PlaceholderText = "the name the dead spelled..."
	box.Font = Config.TextFont
	box.TextSize = 24
	box.ClearTextOnFocus = false
	box.Text = ""
	box.Parent = panel
	Instance.new("UICorner").Parent = box

	local function button(label: string, x: number, color: Color3): TextButton
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.Position = UDim2.new(x, 0, 0, 110)
		b.Size = UDim2.new(0.4, 0, 0, 40)
		b.BackgroundColor3 = color
		b.TextColor3 = Color3.fromRGB(235, 225, 210)
		b.Font = Config.TextFont
		b.TextSize = 22
		b.Text = label
		b.Parent = panel
		Instance.new("UICorner").Parent = b
		return b
	end
	local speak = button("Speak", 0.72, Color3.fromRGB(130, 20, 20))
	local cancel = button("Cancel", 0.28, Color3.fromRGB(60, 55, 65))

	local function close()
		gui.Enabled = false
		box:ReleaseFocus()
	end
	local function submit()
		if box.Text ~= "" then
			banishAttempt:FireServer(box.Text)
		end
		close()
	end

	speak.Activated:Connect(submit)
	cancel.Activated:Connect(close)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed and gui.Enabled then
			submit()
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "SpeakName" and localPlayer:GetAttribute("IsGhost") ~= true then
			box.Text = ""
			gui.Enabled = true
			box:CaptureFocus()
		end
	end)
	localPlayer:GetAttributeChangedSignal("IsGhost"):Connect(close)
end

return BanishUI
