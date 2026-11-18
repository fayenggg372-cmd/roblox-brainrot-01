-- DailyRewardsData.luau -- Daily Heist Bonus tuning, shared by server + client.
-- One 7-day cycle: come back on consecutive UTC days to climb the ladder.
-- Day 7 pays the jackpot, then the cycle wraps to day 1 while the streak
-- itself keeps counting. Cash amounts live here only so both sides can
-- display them; the server alone decides what a claim actually pays.

local DailyRewardsData = {}

-- How many days one reward cycle lasts.
DailyRewardsData.CYCLE_LENGTH = 7

-- Cash paid for each day of the cycle, plus the label shown on the panel.
-- The ladder climbs gently for days 1-6, then day 7 pays a jackpot worth
-- more than the first six days combined.
DailyRewardsData.REWARDS = {
	{ day = 1, cash = 500, label = "Warm-Up Heist" },
	{ day = 2, cash = 750, label = "Second Wind" },
	{ day = 3, cash = 1000, label = "Triple Threat" },
	{ day = 4, cash = 1500, label = "Midweek Score" },
	{ day = 5, cash = 2000, label = "High Roller" },
	{ day = 6, cash = 3000, label = "Almost There" },
	{ day = 7, cash = 10000, label = "JACKPOT DAY" },
}

-- The reward entry for a day inside the cycle (1..CYCLE_LENGTH).
function DailyRewardsData.rewardForDay(day)
	local index = math.clamp(math.floor(day or 1), 1, DailyRewardsData.CYCLE_LENGTH)
	return DailyRewardsData.REWARDS[index]
end

-- The reward a streak is standing on: the streak keeps counting past day 7,
-- but the paid day wraps around the cycle.
function DailyRewardsData.rewardForStreak(streak)
	local day = ((math.floor(streak or 1) - 1) % DailyRewardsData.CYCLE_LENGTH) + 1
	return DailyRewardsData.rewardForDay(day)
end

-- The day of the cycle the next claim will pay for (1 when the streak is
-- fresh or has just wrapped past day 7).
function DailyRewardsData.nextRewardDay(streak)
	local current = math.floor(streak or 0)
	if current <= 0 then
		return 1
	end
	return (current % DailyRewardsData.CYCLE_LENGTH) + 1
end

-- True when the given cycle day pays the jackpot (the last day).
function DailyRewardsData.isJackpotDay(day)
	return math.floor(day or 0) == DailyRewardsData.CYCLE_LENGTH
end

-- "$1,500" style formatting, written here so the panel never needs the
-- economy's own formatter.
function DailyRewardsData.formatCash(amount)
	local text = tostring(math.floor(amount or 0))
	local grouped = ""
	while #text > 3 do
		grouped = "," .. string.sub(text, -3) .. grouped
		text = string.sub(text, 1, -4)
	end
	return "$" .. text .. grouped
end

return DailyRewardsData
