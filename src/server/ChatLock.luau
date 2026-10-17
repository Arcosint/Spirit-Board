-- The core rule of the game: ghosts can't talk to the living.
-- Ghost messages are only delivered to other ghosts. Ghosts can still read everyone.
-- This covers normal chat, bubble chat, and whispers.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatLock = {}

local function isGhost(userId: number): boolean
	local player = Players:GetPlayerByUserId(userId)
	return player ~= nil and player:GetAttribute("IsGhost") == true
end

local function lockChannel(channel: Instance)
	if not channel:IsA("TextChannel") then
		return
	end
	channel.ShouldDeliverCallback = function(message: TextChatMessage, receiver: TextSource)
		local sender = message.TextSource
		if not sender then
			return true -- system messages always go through
		end
		if isGhost(sender.UserId) and not isGhost(receiver.UserId) then
			return false -- the living can't hear the dead
		end
		return true
	end
end

function ChatLock.Start()
	local channels = TextChatService:WaitForChild("TextChannels")
	for _, channel in channels:GetChildren() do
		lockChannel(channel)
	end
	-- Whisper channels get created on the fly, so lock those too.
	channels.ChildAdded:Connect(lockChannel)
end

return ChatLock
