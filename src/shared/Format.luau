-- Format.luau -- small money / time helpers shared by server and client.
-- Both sides format the same way, so a number the HUD shows is the
-- number the server actually holds.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1500 -> "$1.50K", 2500000 -> "$2.50M", 999 -> "$999".
-- Non-numbers (a bad RemoteEvent argument, a corrupt save) format as $0
-- instead of crashing the caller.
function Format.money(amount)
	if type(amount) ~= "number" then
		return "$0"
	end
	local n = math.floor(amount + 0.5)
	if n < 0 then
		n = 0
	end
	if n < 1000 then
		return "$" .. tostring(n)
	end
	local tier = 0
	local value = n
	while value >= 1000 and tier < #SUFFIXES - 1 do
		value = value / 1000
		tier = tier + 1
	end
	return string.format("$%.2f%s", value, SUFFIXES[tier + 1])
end

-- 90 -> "1:30", 45 -> "0:45", anything negative -> "0:00".
function Format.clock(seconds)
	if type(seconds) ~= "number" then
		return "0:00"
	end
	seconds = math.max(0, math.floor(seconds + 0.5))
	local mins = math.floor(seconds / 60)
	local secs = seconds - mins * 60
	if secs < 10 then
		return tostring(mins) .. ":0" .. tostring(secs)
	end
	return tostring(mins) .. ":" .. tostring(secs)
end

return Format
