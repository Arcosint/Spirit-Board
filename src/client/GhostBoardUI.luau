-- The on-screen board only ghosts get. Tap a key and the real planchette in the world slides to it.
-- Works the same with mouse or touch, so mobile ghosts can play too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BoardLayout = require(Shared:WaitForChild("BoardLayout"))

local GhostBoardUI = {}

local localPlayer = Players.LocalPlayer

local BG = Color3.fromRGB(20, 16, 22)
local KEY_BG = Color3.fromRGB(214, 190, 150)
local KEY_TEXT = Color3.fromRGB(45, 28, 18)
local KEY_FLASH = Color3.fromRGB(170, 20, 20)
local GHOST_TEXT = Color3.fromRGB(190, 220, 255)

local ROW_HEIGHT = 40
local ROW_GAP = 4
local PADDING = 8

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(text: string, size: number, y: number, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.Position = UDim2.new(0, 0, 0, y)
	l.Font = Enum.Font.Fantasy
	l.TextSize = size
	l.TextColor3 = GHOST_TEXT
	l.TextStrokeTransparency = 0.5
	l.Text = text
	l.Parent = parent
	return l
end

function GhostBoardUI.Start()
	local boardMove = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BoardMove") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "GhostBoard"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	label("YOU ARE DEAD", 32, 8, gui)
	label("Only you can see what's coming. They can't hear you. Spell it.", 16, 46, gui)

	-- Group keys by row
	local rows: { { any } } = {}
	for r = 1, BoardLayout.RowCount do
		rows[r] = {}
	end
	for _, entry in BoardLayout.Entries do
		table.insert(rows[entry.Row], entry)
	end

	local panelHeight = BoardLayout.RowCount * ROW_HEIGHT + (BoardLayout.RowCount - 1) * ROW_GAP + PADDING * 2

	local panel = Instance.new("Frame")
	panel.Name = "Board"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -16)
	panel.Size = UDim2.new(0.95, 0, 0, panelHeight)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.25
	panel.Parent = gui
	corner(panel, 12)

	local maxSize = Instance.new("UISizeConstraint")
	maxSize.MaxSize = Vector2.new(680, panelHeight)
	maxSize.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, PADDING)
	padding.PaddingBottom = UDim.new(0, PADDING)
	padding.PaddingLeft = UDim.new(0, PADDING)
	padding.PaddingRight = UDim.new(0, PADDING)
	padding.Parent = panel

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, ROW_GAP)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panel

	local lastClick = 0

	for r, entries in rows do
		local rowFrame = Instance.new("Frame")
		rowFrame.Name = "Row" .. r
		rowFrame.LayoutOrder = r
		rowFrame.BackgroundTransparency = 1
		rowFrame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		rowFrame.Parent = panel

		local rowList = Instance.new("UIListLayout")
		rowList.FillDirection = Enum.FillDirection.Horizontal
		rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowList.Padding = UDim.new(0, 4)
		rowList.SortOrder = Enum.SortOrder.LayoutOrder
		rowList.Parent = rowFrame

		local width = math.min(1 / #entries, 0.3)
		for i, entry in entries do
			local button = Instance.new("TextButton")
			button.Name = entry.Key
			button.LayoutOrder = i
			button.Size = UDim2.new(width, -4, 1, 0)
			button.BackgroundColor3 = KEY_BG
			button.TextColor3 = KEY_TEXT
			button.Font = Enum.Font.Fantasy
			button.TextScaled = true
			button.Text = entry.Label
			button.AutoButtonColor = true
			button.Parent = rowFrame
			corner(button, 6)

			local textLimit = Instance.new("UITextSizeConstraint")
			textLimit.MaxTextSize = 22
			textLimit.Parent = button

			button.Activated:Connect(function()
				local now = os.clock()
				if now - lastClick < Config.ClientClickCooldown then
					return
				end
				lastClick = now
				boardMove:FireServer(entry.Key)
				button.BackgroundColor3 = KEY_FLASH
				task.delay(0.2, function()
					button.BackgroundColor3 = KEY_BG
				end)
			end)
		end
	end

	-- Hide/show toggle so the board doesn't block a phone screen while the ghost looks around.
	local toggle = Instance.new("TextButton")
	toggle.Name = "Toggle"
	toggle.AnchorPoint = Vector2.new(1, 1)
	toggle.Position = UDim2.new(1, -16, 1, -(panelHeight + 24))
	toggle.Size = UDim2.new(0, 110, 0, 32)
	toggle.BackgroundColor3 = BG
	toggle.BackgroundTransparency = 0.25
	toggle.TextColor3 = GHOST_TEXT
	toggle.Font = Enum.Font.Fantasy
	toggle.TextSize = 18
	toggle.Text = "Hide board"
	toggle.Parent = gui
	corner(toggle, 8)

	-- Shrink the board on short screens (phones in landscape) so it never covers the title.
	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	local function placeToggle()
		toggle.Position = if panel.Visible
			then UDim2.new(1, -16, 1, -(panelHeight * panelScale.Scale + 24))
			else UDim2.new(1, -16, 1, -16)
	end

	local function fit()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local available = camera.ViewportSize.Y - 140 -- room left under the title text
		panelScale.Scale = math.clamp(available / (panelHeight + 16), 0.55, 1)
		placeToggle()
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()

	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
		toggle.Text = if panel.Visible then "Hide board" else "Show board"
		placeToggle()
	end)

	local function refresh()
		gui.Enabled = localPlayer:GetAttribute("IsGhost") == true
	end
	localPlayer:GetAttributeChangedSignal("IsGhost"):Connect(refresh)
	refresh()
end

return GhostBoardUI
