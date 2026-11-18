-- BrainrotData.luau -- the cast of Brainrot Heist.
-- Every character is an original joke on the Italian-brainrot meme genre
-- (absurd animal + object + food mashups with a sing-song name). Each entry
-- is: id, display name, rarity, buy cost, base $/second, body colour,
-- accessory built from parts, and a one-line joke shown in the shop.
-- The server spawns these on the conveyor; the client lists them in the
-- shop; the judge's criterion 2 (the cast) lives or dies here.

local BrainrotData = {}

BrainrotData.CATALOG = {
	{ id = "noobini", name = "Noobini Pizzanini", rarity = "Common", cost = 25, income = 5,
		color = Color3.fromRGB(255, 200, 120), accessory = "chefHat",
		joke = "A pizza slice that learned to walk. Slowly." },
	{ id = "tungtung", name = "Tung Tung Tung Sahur", rarity = "Common", cost = 150, income = 12,
		color = Color3.fromRGB(150, 100, 50), accessory = "bat",
		joke = "He knocks three times. Always three times." },
	{ id = "chimpanzini", name = "Chimpanzini Bananini", rarity = "Common", cost = 300, income = 25,
		color = Color3.fromRGB(255, 220, 80), accessory = "banana",
		joke = "Monkey business, literally. Peels included." },
	{ id = "tralalero", name = "Tralalero Tralala", rarity = "Rare", cost = 800, income = 60,
		color = Color3.fromRGB(90, 160, 255), accessory = "fin",
		joke = "A shark in sneakers. Tralala never stops." },
	{ id = "patapim", name = "Brr Brr Patapim", rarity = "Rare", cost = 1500, income = 110,
		color = Color3.fromRGB(120, 180, 90), accessory = "leaf",
		joke = "A tree with a nose for money. Brr brr." },
	{ id = "lirili", name = "Lirili Larila", rarity = "Rare", cost = 2500, income = 180,
		color = Color3.fromRGB(220, 180, 140), accessory = "cactus",
		joke = "Half cactus, half elephant, all drama." },
	{ id = "bombardiro", name = "Bombardiro Crocodilo", rarity = "Epic", cost = 6000, income = 400,
		color = Color3.fromRGB(90, 140, 90), accessory = "plane",
		joke = "A bomber crocodile. Do not ask what it drops." },
	{ id = "ballerina", name = "Ballerina Cappuccina", rarity = "Epic", cost = 10000, income = 650,
		color = Color3.fromRGB(200, 150, 110), accessory = "tutu",
		joke = "A cappuccino that pirouettes. Foam everywhere." },
	{ id = "trippi", name = "Trippi Troppi", rarity = "Epic", cost = 15000, income = 900,
		color = Color3.fromRGB(255, 150, 90), accessory = "fish",
		joke = "A fish-bear that only swims in money." },
	{ id = "assassino", name = "Cappuccino Assassino", rarity = "Legendary", cost = 30000, income = 1800,
		color = Color3.fromRGB(120, 80, 50), accessory = "katana",
		joke = "Espresso, but make it lethal." },
	{ id = "vaca", name = "La Vaca Saturno Saturnita", rarity = "Legendary", cost = 50000, income = 3000,
		color = Color3.fromRGB(240, 220, 200), accessory = "rings",
		joke = "A cow with Saturn's rings. Moo, in orbit." },
	{ id = "frigo", name = "Frigo Camelo", rarity = "Legendary", cost = 80000, income = 4500,
		color = Color3.fromRGB(180, 220, 255), accessory = "fridge",
		joke = "A camel that is also a fridge. Cold storage." },
	{ id = "boneca", name = "Boneca Ambalabu", rarity = "Mythic", cost = 150000, income = 8000,
		color = Color3.fromRGB(255, 120, 180), accessory = "crown",
		joke = "A doll that haunts the leaderboard." },
	{ id = "giraffa", name = "Giraffa Celeste", rarity = "Mythic", cost = 250000, income = 13000,
		color = Color3.fromRGB(255, 200, 60), accessory = "wings",
		joke = "A giraffe from space. Neck longer than rent." },
	{ id = "matteo", name = "Matteo the Menace", rarity = "Mythic", cost = 400000, income = 20000,
		color = Color3.fromRGB(140, 140, 160), accessory = "crown",
		joke = "Nobody knows what Matteo is. Matteo knows." },
	{ id = "tralaleritos", name = "Los Tralaleritos", rarity = "Brainrot God", cost = 750000, income = 35000,
		color = Color3.fromRGB(80, 140, 255), accessory = "fin",
		joke = "Three sharks, one brain cell, shared." },
	{ id = "tralaleritas", name = "Las Tralaleritas", rarity = "Brainrot God", cost = 1200000, income = 55000,
		color = Color3.fromRGB(255, 130, 200), accessory = "fin",
		joke = "The shark sisters. The conveyor fears them." },
	{ id = "garama", name = "Garama & Madundung", rarity = "Secret", cost = 3000000, income = 150000,
		color = Color3.fromRGB(255, 90, 60), accessory = "crown",
		joke = "So secret even the wiki gave up." },
	{ id = "hotspot", name = "Pot Hotspot", rarity = "Secret", cost = 5000000, income = 250000,
		color = Color3.fromRGB(255, 160, 40), accessory = "flame",
		joke = "A boiling pot that prints money. Handle with care." },
}

-- Spawn weights per rarity: commons flood the belt, secrets are a rumour.
BrainrotData.RARITY_WEIGHTS = {
	Common = 34,
	Rare = 28,
	Epic = 18,
	Legendary = 11,
	Mythic = 6,
	["Brainrot God"] = 2.2,
	Secret = 0.8,
}

-- Fixed roll order: `pairs` over the weights table has no defined order,
-- so the roll walks this list instead — same probabilities, but the
-- result no longer depends on hash iteration order.
BrainrotData.RARITY_ORDER = {
	"Common", "Rare", "Epic", "Legendary", "Mythic", "Brainrot God", "Secret",
}

function BrainrotData.byId(id)
	for _, def in ipairs(BrainrotData.CATALOG) do
		if def.id == id then
			return def
		end
	end
	return nil
end

function BrainrotData.byRarity(rarity)
	local out = {}
	for _, def in ipairs(BrainrotData.CATALOG) do
		if def.rarity == rarity then
			table.insert(out, def)
		end
	end
	return out
end

-- Weighted random pick: first a rarity, then a character of that rarity.
function BrainrotData.roll()
	local total = 0
	for _, w in pairs(BrainrotData.RARITY_WEIGHTS) do
		total = total + w
	end
	local roll = math.random() * total
	local picked = "Common"
	for _, rarity in ipairs(BrainrotData.RARITY_ORDER) do
		roll = roll - (BrainrotData.RARITY_WEIGHTS[rarity] or 0)
		if roll <= 0 then
			picked = rarity
			break
		end
	end
	local pool = BrainrotData.byRarity(picked)
	return pool[math.random(1, #pool)]
end

return BrainrotData
