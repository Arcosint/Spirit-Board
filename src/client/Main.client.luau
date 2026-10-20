-- Client entry point: starts every player-side system.
-- Each one starts on its own, so if one breaks (or waits on something), the rest still run.
local Client = script.Parent

local SYSTEMS = {
	"GhostVisuals", -- who can see the ghosts
	"GhostSight", -- ghost-only things (demon, relics), living-only prompts
	"HUD", -- announcements, relic counter, red danger tint
	"Haunting", -- ambience, house noises, random scares
	"DemonPresence", -- feeling the invisible demon: lamps, heartbeat, whispers, glimpses
	"Events", -- placed scares: crawler, figure, mirror, writing, footsteps; lightning, rocking chair
	"Jumpscare", -- the kill on the victim's screen
	"FlashlightControl", -- Q / mobile button
	"GhostBoardUI", -- the ghost's on-screen Ouija board
	"GhostSecretUI", -- the demon's name, for ghosts
	"BanishUI", -- typing the name at the board
}

for _, name in SYSTEMS do
	task.spawn(function()
		local ok, err = pcall(function()
			require(Client:WaitForChild(name)).Start()
		end)
		if not ok then
			warn("[Client] " .. name .. " failed to start: " .. tostring(err))
		end
	end)
end

print("[Client] Ouija game client started")
