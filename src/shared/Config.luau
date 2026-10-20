-- Shared settings both server and client can read.
-- Tweak numbers here instead of digging through scripts.
local Config = {
	-- Round
	MaxPlayers = 6,
	FloorsToWin = 3,
	SearchTime = 2.5, -- seconds to search a cabinet for a relic
	RespawnTime = 3, -- seconds before a dead player comes back as a ghost

	-- Ouija board
	-- Where the board goes if there's no Part named "BoardSpawn" in Workspace.
	-- Put a Part called BoardSpawn on the parlor table later and the board will sit there instead.
	BoardDefaultCFrame = CFrame.new(0, 3.3, -12),
	PlanchetteSpeed = 3, -- studs per second; lower = slower, scarier spelling
	PlanchetteMinTime = 0.5, -- shortest time a single move can take
	PlanchetteHold = 0.5, -- pause on a letter before the ghost can move again
	PlanchetteWobble = 0.35, -- how shaky the path is (studs)
	HighlightLetters = true, -- briefly tint the letter the planchette lands on
	LetterYawDegrees = 0, -- rotate the letters if they read upside down / sideways

	-- Ghost
	GhostSeeEachOtherTransparency = 0.6, -- how ghosts look to other ghosts (and themselves)
	ClientClickCooldown = 0.25,

	-- Relics
	RelicCount = 3, -- how many relics are hidden each round (out of the searchable spots)

	-- Demon (only ghosts can see it)
	DemonWalkSpeed = 8, -- patrolling
	DemonChaseSpeed = 14.5, -- players run at 16, so you can only escape if you see it coming
	DemonDetectRange = 35, -- how far it can spot a living player (needs line of sight)
	DemonKillRange = 4,
	DemonKillCooldown = 3,
	DemonAngerSpeedBonus = 1.5, -- added every time someone speaks the wrong name
	DangerVignetteRange = 18, -- living players' screens tint red when it's this close

	-- Flashlight (living players only, toggle with Q or the mobile button)
	FlashlightRange = 40,
	FlashlightAngle = 50,
	FlashlightBrightness = 2.2,

	-- Scares
	-- How the demon kills you: you freeze, the lamps die and the dark closes in while something breathes
	-- in your ear... black and silence... then its face lunges at you, bites, blood everywhere. Then you're dead.
	ScareDreadTime = 2.2, -- frozen, dark closing in, breathing + "i see you" (used if ScareDreadRange is missing)
	ScareDreadRange = { 2.4, 4 }, -- the dread lasts a random time in this range, so nobody can count it down
	ScareCalmPart = 0.72, -- how far into the dread the false calm starts (lights come back... nothing's there)
	ScareBlackoutTime = 0.45, -- dead silence right before the face
	ScareFaceTime = 1.4, -- the face on screen
	ScareFaceImage = "rbxassetid://9855149781", -- the big face when it kills you
	-- Faces that slam onto the screen in the random scares.
	ScareFlashImages = {
		"rbxassetid://82604934512029",
		"rbxassetid://90796705261100",
		"rbxassetid://83803054077955",
		"rbxassetid://102932462054006",
	},
	ScareSounds = {
		Whisper = "rbxassetid://85064677546638", -- in your ear while you glitch
		WhisperShort = "rbxassetid://136833080474934", -- the demon whispering near you
		Scream = "rbxassetid://9043346336",
		Shriek = "rbxassetid://9118153393", -- piercing shriek, layered on the kill
		ShriekShort = "rbxassetid://9125910582", -- short screech for the random scares
		Roar = "rbxassetid://9113985717",
		Breathing = "rbxassetid://9113984056", -- always on the demon; the living hear it
		Growl = "rbxassetid://9113980319", -- when it spots someone
		Heartbeat = "rbxassetid://9043365842",
		Sting = "rbxassetid://9113225986", -- a deep, heavy impact layered on the moment it lunges
	},
	-- Blood and gore for the kill
	Gore = {
		Splatters = { -- slam onto the screen when it bites
			"rbxassetid://124577604084059",
			"rbxassetid://2511795864",
		},
		Drips = "rbxassetid://10921124431", -- runs down the screen after you die
		Border = "rbxassetid://176533208", -- bloody ring around the edges
		BoneCrack = "rbxassetid://9113542694",
		Splatter = "rbxassetid://7837512412",
	},
	-- The house itself (client/Haunting)
	TextFont = Enum.Font.Garamond, -- Roblox has no Times New Roman; Garamond is the closest serif it has
	AmbientSounds = {
		Drone = "rbxassetid://9114353273", -- always under everything, low
		Rumble = "rbxassetid://9112863181",
	},
	HouseNoises = { -- one plays somewhere nearby every so often
		"rbxassetid://9114141751", -- knocking
		"rbxassetid://9119919844", -- tapping on glass
		"rbxassetid://9113134455", -- bumps in the walls
		"rbxassetid://9126090621", -- something heavy falls
		"rbxassetid://9114494416", -- floorboards creak
		"rbxassetid://9120762268", -- window rattles
	},
	MusicBox = "rbxassetid://1839910323", -- rare: a music box starts playing in another room
	HouseNoiseEvery = { 9, 22 }, -- seconds between house noises (random in this range)
	RandomScareEvery = { 50, 110 }, -- seconds between random scares for each living player (halved when the demon is near)
	FirstRandomScareAfter = 35, -- no random scares in the first seconds of a round
	DemonBreathRange = 45, -- how far away the living can hear it breathing
	DemonPresenceRange = 30, -- inside this: lamps flicker, your heart pounds, it whispers, you might glimpse it
	GlimpseCooldown = 7, -- shortest time between split-second glimpses of the demon

	-- Scares placed around the house (client/Events, zones in Workspace.House.Events)
	EventSounds = {
		Scuttle = "rbxassetid://9120926150", -- rattling, played fast: limbs on plaster
		Creak = "rbxassetid://9114494416", -- floorboard creak (footsteps above)
		Thud = "rbxassetid://9113134455", -- one heavy bump
		Thunder = "rbxassetid://91289467382888",
		Rocking = "rbxassetid://9118635478", -- rocking chair creak
	},
	EventGap = 25, -- shortest time between two placed scares for one player
	LightningEvery = { 25, 60 }, -- seconds between lightning flashes
	PortraitFlashCooldown = 40, -- shortest time between portraits flashing a face at you

	-- Rounds
	FirstTakeDelay = 30, -- with 2+ players, if nobody has died by now, the house takes someone
	RoundEndDelay = 8,
	DemonNames = { "BAEL", "MORAX", "ZEPAR", "FURCAS", "VALAC", "ANDRAS", "BUNE", "HAAGENTI" },
}

return Config
