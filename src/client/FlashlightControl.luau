-- Q (or the on-screen button on mobile) turns your flashlight on and off. Living players only.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlashlightControl = {}

local localPlayer = Players.LocalPlayer
local ACTION = "ToggleFlashlight"

function FlashlightControl.Start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Flashlight") :: RemoteEvent
	local on = true

	local function toggle(_, state: Enum.UserInputState)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		on = not on
		remote:FireServer(on)
		return Enum.ContextActionResult.Sink
	end

	local function refresh()
		if localPlayer:GetAttribute("IsGhost") == true then
			ContextActionService:UnbindAction(ACTION)
		else
			ContextActionService:BindAction(ACTION, toggle, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
			ContextActionService:SetTitle(ACTION, "Light")
			ContextActionService:SetPosition(ACTION, UDim2.new(1, -150, 1, -160))
		end
	end
	localPlayer:GetAttributeChangedSignal("IsGhost"):Connect(refresh)
	-- a new body always starts with the light on
	localPlayer.CharacterAdded:Connect(function()
		on = true
	end)
	refresh()
end

return FlashlightControl
