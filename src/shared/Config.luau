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

	-- Rounds
	FirstTakeDelay = 30, -- with 2+ players, if nobody has died by now, the house takes someone
	RoundEndDelay = 8,
	DemonNames = { "BAEL", "MORAX", "ZEPAR", "FURCAS", "VALAC", "ANDRAS", "BUNE", "HAAGENTI" },
}

return Config
