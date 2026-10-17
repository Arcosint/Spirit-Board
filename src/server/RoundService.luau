-- Runs a round of floor 1:
--   1. Relics are hidden. The demon spawns. The stairs are locked.
--   2. Living players find the relics (ghosts can see them) and bring them to the board.
--   3. Once every relic is placed, ghosts learn the demon's true name and spell it on the board.
--   4. A living player speaks the name at the board. Right = banished, stairs open. Wrong = it gets faster.
--   Everyone dead = the house wins. Either way a new round starts.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GhostService = require(script.Parent.GhostService)
local RelicService = require(script.Parent.RelicService)
local DemonService = require(script.Parent.DemonService)
local Remotes = require(script.Parent.Remotes)

local RoundService = {}

local state = "Waiting" -- Waiting | Playing | Ended
local roundId = 0
local demonName = ""
local ritualReady = false
local lastAttempt: { [Player]: number } = {}

local announce: RemoteEvent
local notify: RemoteEvent
local ghostSecret: RemoteEvent
local banishAttempt: RemoteEvent
local speakPrompt: ProximityPrompt?

local function livingPlayers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if not GhostService.IsGhost(p) and h and h.Health > 0 then
			table.insert(list, p)
		end
	end
	return list
end

local function ghostCount(): number
	local n = 0
	for _, p in Players:GetPlayers() do
		if GhostService.IsGhost(p) then
			n += 1
		end
	end
	return n
end

local function setStairsLocked(locked: boolean)
	local door = workspace:FindFirstChild("House") and workspace.House:FindFirstChild("StairDoor")
	if door and door:IsA("BasePart") then
		door.CanCollide = locked
		door.Transparency = if locked then 0 else 0.85
		door:SetAttribute("Locked", locked)
	end
end

-- Only ghosts are told the name. It's sent privately, never stored where the living could read it.
local function sendSecret(player: Player)
	if ritualReady and GhostService.IsGhost(player) then
		ghostSecret:FireClient(player, demonName)
	end
end

local function setRitualReady(ready: boolean)
	ritualReady = ready
	workspace:SetAttribute("RitualReady", ready)
	if speakPrompt then
		speakPrompt.Enabled = ready
	end
	if ready then
		for _, p in Players:GetPlayers() do
			sendSecret(p)
		end
	else
		ghostSecret:FireAllClients(nil)
	end
end

local startRound -- forward declaration

local function endRound(won: boolean)
	if state ~= "Playing" then
		return
	end
	state = "Ended"
	setRitualReady(false)
	DemonService.Despawn()
	if won then
		setStairsLocked(false)
		GhostService.ReviveAll()
		announce:FireAllClients("BANISHED", demonName .. " is gone. The stairs are open... (more floors coming soon)")
		task.wait(Config.RoundEndDelay * 2)
	else
		announce:FireAllClients("THE HOUSE WINS", "Nobody made it out.")
		task.wait(Config.RoundEndDelay)
	end
	GhostService.ReviveAll()
	task.wait(1)
	startRound()
end

startRound = function()
	roundId += 1
	local thisRound = roundId
	state = "Playing"
	demonName = Config.DemonNames[math.random(#Config.DemonNames)]
	table.clear(lastAttempt)
	setRitualReady(false)
	setStairsLocked(true)
	RelicService.Reset()
	DemonService.Spawn()
	announce:FireAllClients("FLOOR 1", "Find the relics and bring them to the board. If you die... guide the others.")

	-- Make sure someone becomes a ghost, otherwise nobody can ever learn the name.
	task.delay(Config.FirstTakeDelay, function()
		if roundId ~= thisRound or state ~= "Playing" then
			return
		end
		local living = livingPlayers()
		if #Players:GetPlayers() >= 2 and ghostCount() == 0 and #living > 0 then
			local victim = living[math.random(#living)]
			DemonService.Take(victim)
			announce:FireAllClients("", victim.Name .. " was taken. Watch the board.")
		end
	end)
end

local function onRelicsChanged(placed: number, total: number)
	if state ~= "Playing" or total == 0 then
		return
	end
	if placed > 0 and placed < total then
		notify:FireAllClients(("A relic was placed (%d/%d)"):format(placed, total))
	elseif placed >= total and not ritualReady then
		setRitualReady(true)
		announce:FireAllClients("THE BOARD IS READY", "Only the dead can read its true name. Ask them.")
	end
end

local function onBanishAttempt(player: Player, text: unknown)
	if state ~= "Playing" or not ritualReady or GhostService.IsGhost(player) or typeof(text) ~= "string" then
		return
	end
	local now = os.clock()
	if lastAttempt[player] and now - lastAttempt[player] < 2 then
		return
	end
	lastAttempt[player] = now

	local guess = string.upper(text):gsub("[^A-Z]", "")
	if guess == demonName then
		task.spawn(endRound, true)
	else
		DemonService.Anger()
		announce:FireAllClients("WRONG NAME", player.Name .. " said '" .. guess .. "'. It's angrier now.")
	end
end

function RoundService.GetDemonName(): string
	return demonName
end

function RoundService.Start()
	announce = Remotes.Event("Announce")
	notify = Remotes.Event("Notify")
	ghostSecret = Remotes.Event("GhostSecret")
	banishAttempt = Remotes.Event("BanishAttempt")
	banishAttempt.OnServerEvent:Connect(onBanishAttempt)
	RelicService.Changed.Event:Connect(onRelicsChanged)

	-- "Speak its name" prompt on the board (only on once the ritual is ready)
	local board = workspace:FindFirstChild("SpiritBoard") and workspace.SpiritBoard:FindFirstChild("Board")
	if board then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SpeakName"
		prompt.ActionText = "Speak its name"
		prompt.ObjectText = "Spirit board"
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = board
		CollectionService:AddTag(prompt, "LivingOnlyPrompt")
		speakPrompt = prompt
	end

	-- Anyone who dies after the ritual is ready learns the name too.
	local function watch(p: Player)
		p:GetAttributeChangedSignal("IsGhost"):Connect(function()
			sendSecret(p)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastAttempt[p] = nil
	end)

	-- Lose check
	task.spawn(function()
		while true do
			task.wait(0.5)
			if state == "Playing" and #Players:GetPlayers() > 0 and #livingPlayers() == 0 then
				-- give the respawn a moment so a single death doesn't race the check
				task.wait(0.5)
				if state == "Playing" and #livingPlayers() == 0 then
					task.spawn(endRound, false)
				end
			end
		end
	end)

	-- First round starts once somebody is here.
	task.spawn(function()
		if #Players:GetPlayers() == 0 then
			Players.PlayerAdded:Wait()
		end
		task.wait(3)
		startRound()
	end)
end

return RoundService
