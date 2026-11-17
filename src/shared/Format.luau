-- Format.luau -- small money / time helpers shared by server and client.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1500 -> "$1.50K", 2500000 -> "$2.50M", 999 -> "$999".
function Format.money(amount)
	local n = math.floor(amount + 0.5)
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

-- 90 -> "1:30", 45 -> "0:45".
function Format.clock(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	local mins = math.floor(seconds / 60)
	local secs = seconds - mins * 60
	if secs < 10 then
		return tostring(mins) .. ":0" .. tostring(secs)
	end
	return tostring(mins) .. ":" .. tostring(secs)
end

return Format
