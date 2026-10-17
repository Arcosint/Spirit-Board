-- One place to get RemoteEvents. Creates them in ReplicatedStorage.Remotes the first time they're asked for.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local function folder(): Folder
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
	end
	return f :: Folder
end

function Remotes.Event(name: string): RemoteEvent
	local f = folder()
	local e = f:FindFirstChild(name)
	if not e then
		e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = f
	end
	return e :: RemoteEvent
end

return Remotes
