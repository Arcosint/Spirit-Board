-- Builds the Ouija board in the world and moves the planchette when a ghost picks a key.
-- The planchette moves slowly and shakily on purpose: the living have to read it in real time.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BoardLayout = require(Shared:WaitForChild("BoardLayout"))
local GhostService = require(script.Parent.GhostService)

local BoardService = {}

local BOARD_SIZE = Vector3.new(8, 0.3, 5.5)
local PLANCHETTE_SIZE = Vector3.new(0.9, 0.12, 1.1)

local origin: CFrame
local planchette: BasePart
local labels: { [string]: TextLabel } = {}
local busy = false
local rng = Random.new()

local LETTER_COLOR = Color3.fromRGB(45, 28, 18)
local GLOW_COLOR = Color3.fromRGB(170, 20, 20)

local function getOrigin(): CFrame
	local spawnPart = workspace:FindFirstChild("BoardSpawn")
	if spawnPart and spawnPart:IsA("BasePart") then
		spawnPart.Transparency = 1
		spawnPart.CanCollide = false
		spawnPart.CanQuery = false
		return spawnPart.CFrame
	end
	return Config.BoardDefaultCFrame
end

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Wood
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Position on the board surface for a U/V spot (0..1 each way).
local function surfaceCFrame(u: number, v: number, lift: number): CFrame
	return origin * CFrame.new((u - 0.5) * BOARD_SIZE.X, BOARD_SIZE.Y / 2 + lift, (v - 0.5) * BOARD_SIZE.Z)
end

local function planchetteCFrame(u: number, v: number): CFrame
	return surfaceCFrame(u, v, PLANCHETTE_SIZE.Y / 2 + 0.02)
end

local function buildBoard()
	origin = getOrigin()

	local model = Instance.new("Model")
	model.Name = "SpiritBoard"

	-- Table under the board
	makePart(
		"TableTop",
		Vector3.new(BOARD_SIZE.X + 1.5, 0.5, BOARD_SIZE.Z + 1.5),
		origin * CFrame.new(0, -(BOARD_SIZE.Y / 2 + 0.25), 0),
		Color3.fromRGB(60, 40, 30),
		model
	)
	local legHeight = math.max(0.5, origin.Position.Y - BOARD_SIZE.Y / 2 - 0.5)
	makePart(
		"TableLeg",
		Vector3.new(1.5, legHeight, 1.5),
		origin * CFrame.new(0, -(BOARD_SIZE.Y / 2 + 0.5 + legHeight / 2), 0),
		Color3.fromRGB(50, 32, 24),
		model
	)

	-- The board itself
	local board = makePart("Board", BOARD_SIZE, origin, Color3.fromRGB(214, 190, 150), model)
	board.Name = "Board"

	-- Letters: each one sits on its own invisible tile, placed with the same math as the planchette,
	-- so the planchette always lands exactly on the letter.
	-- SurfaceGui text on a Top face runs along the part's Z axis, so each tile is turned 90 degrees
	-- (and built long on Z) to make the words run left-to-right across the board.
	local yaw = CFrame.Angles(0, math.rad(-90 + Config.LetterYawDegrees), 0)
	for _, entry in BoardLayout.Entries do
		local width = if #entry.Label > 1 then 0.32 * #entry.Label + 0.3 else 0.5
		local tile = makePart(
			"Key_" .. entry.Key,
			Vector3.new(0.55, 0.02, width),
			surfaceCFrame(entry.U, entry.V, 0.011) * yaw,
			board.Color,
			model
		)
		tile.Transparency = 1
		tile.CanCollide = false
		tile.CanQuery = false
		tile.CanTouch = false

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 100
		gui.LightInfluence = 1
		gui.Parent = tile

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = entry.Label
		label.TextScaled = true
		label.Font = Config.TextFont
		label.TextColor3 = LETTER_COLOR
		label.Parent = gui

		labels[entry.Key] = label
	end

	-- The planchette (the pointer the ghost moves)
	planchette = makePart(
		"Planchette",
		PLANCHETTE_SIZE,
		planchetteCFrame(BoardLayout.Rest.U, BoardLayout.Rest.V),
		Color3.fromRGB(30, 22, 18),
		model
	)
	planchette.CanCollide = false
	planchette.Transparency = 0.15

	model.PrimaryPart = board
	model.Parent = workspace
end

local function glow(key: string)
	if not Config.HighlightLetters then
		return
	end
	local label = labels[key]
	if not label then
		return
	end
	label.TextColor3 = GLOW_COLOR
	task.delay(Config.PlanchetteHold + 0.4, function()
		label.TextColor3 = LETTER_COLOR
	end)
end

local function tweenTo(target: CFrame, duration: number)
	local tween = TweenService:Create(
		planchette,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = target }
	)
	tween:Play()
	tween.Completed:Wait()
end

-- Moves the planchette to a key. Only one move at a time, so two ghosts can't fight over it mid-move.
function BoardService.Move(key: string): boolean
	if busy then
		return false
	end
	local entry = BoardLayout.ByKey[key]
	if not entry then
		return false
	end
	busy = true

	local startCF = planchette.CFrame
	local targetCF = planchetteCFrame(entry.U, entry.V)
	local distance = (targetCF.Position - startCF.Position).Magnitude
	local total = math.max(Config.PlanchetteMinTime, distance / Config.PlanchetteSpeed)

	-- Shaky path: drift off to a random point halfway, then settle on the letter.
	local w = Config.PlanchetteWobble
	local midCF = startCF:Lerp(targetCF, 0.5)
		* CFrame.new(rng:NextNumber(-w, w), 0, rng:NextNumber(-w, w))
		* CFrame.Angles(0, math.rad(rng:NextNumber(-12, 12)), 0)

	tweenTo(midCF, total / 2)
	tweenTo(targetCF, total / 2)
	glow(key)
	task.wait(Config.PlanchetteHold)

	busy = false
	return true
end

function BoardService.Start()
	buildBoard()

	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage

	local boardMove = Instance.new("RemoteEvent")
	boardMove.Name = "BoardMove"
	boardMove.Parent = remotes

	boardMove.OnServerEvent:Connect(function(player: Player, key: unknown)
		-- Never trust the client: only ghosts can move it, and only to real keys.
		if typeof(key) ~= "string" or not GhostService.IsGhost(player) then
			return
		end
		task.spawn(BoardService.Move, key)
	end)
end

return BoardService
