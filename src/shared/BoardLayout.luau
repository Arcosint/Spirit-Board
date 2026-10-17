-- Where every key sits on the board.
-- U = left->right (0..1), V = top->bottom (0..1), Row = which row in the ghost's on-screen board.
-- Both the 3D board (server) and the ghost UI (client) read from this, so they always match.
local entries = {}

local function add(key: string, label: string, u: number, v: number, row: number)
	table.insert(entries, { Key = key, Label = label, U = u, V = v, Row = row })
end

add("YES", "YES", 0.15, 0.12, 1)
add("NO", "NO", 0.85, 0.12, 1)

local function addRow(chars: string, startU: number, endU: number, v: number, row: number)
	local count = #chars
	for i = 1, count do
		local c = chars:sub(i, i)
		local u = startU + (i - 1) * ((endU - startU) / (count - 1))
		add(c, c, u, v, row)
	end
end

addRow("ABCDEFGHIJKLM", 0.06, 0.94, 0.36, 2)
addRow("NOPQRSTUVWXYZ", 0.06, 0.94, 0.56, 3)
addRow("1234567890", 0.1, 0.9, 0.76, 4)

add("GOODBYE", "GOODBYE", 0.5, 0.92, 5)

local byKey = {}
for _, entry in entries do
	byKey[entry.Key] = entry
end

return {
	Entries = entries,
	ByKey = byKey,
	Rest = { U = 0.5, V = 0.12 }, -- where the planchette sits at the start (between YES and NO)
	RowCount = 5,
}
