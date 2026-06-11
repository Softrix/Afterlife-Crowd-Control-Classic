--[[
	Afterlife Crowd Control — class CC spell database
	TBC Classic (20505) and Mists of Pandaria Classic (50503)

	Durations and cooldowns sourced from wowclassicdb.com, Wowhead MoP/TBC Classic.

	Fields per entry:
	  spellId, class, duration, cooldown, breakable, instant, nosound, rank (optional), family (optional), diminishReturns
]]

Afterlife_CCById = {}
Afterlife_CCByName = {}
Afterlife_CCByClass = {}

local DR_FAMILIES = {
	polymorph = true, polymorph_turtle = true, polymorph_pig = true,
	polymorph_black_cat = true, polymorph_rabbit = true, polymorph_turkey = true,
	fear = true, sap = true, cyclone = true, hibernate = true,
	entangling_roots = true, blind = true, shackle_undead = true,
	mind_control = true, banish = true, hex = true, repentance = true,
	scare_beast = true, howl_of_terror = true, psychic_scream = true,
	freezing_trap_effect = true, wyvern_sting = true, scatter_shot = true,
	turn_evil = true, paralysis = true, seduction = true,
}

--- Register one CC spell in the lookup tables used by combat-log handling.
--- @param class string Class tag (e.g. MAGE)
--- @param spellId number Spell id
--- @param duration number CC duration in seconds
--- @param cooldown number Associated cooldown in seconds
--- @param instant boolean True for instant AoE CC (no cast bar)
--- @param breakable boolean True if damage can break the effect
--- @param rank number|nil Spell rank within the family
--- @param family string|nil DR family key
--- @param nosound boolean|nil True to skip default CC sounds for this spell
local function Add(class, spellId, duration, cooldown, instant, breakable, rank, family, nosound)
	local familyKey = family and strlower(family) or nil
	Afterlife_CCById[spellId] = {
		spellId = spellId,
		class = class,
		duration = duration,
		cooldown = cooldown or 0,
		instant = instant and true or false,
		breakable = breakable and true or false,
		nosound = nosound and true or false,
		rank = rank,
		family = family,
		diminishReturns = familyKey and DR_FAMILIES[familyKey] or false,
	}
end

-- =============================================================================
-- DRUID
-- =============================================================================
Add("DRUID", 2637,  20, 0, false, true,  1, "hibernate")
Add("DRUID", 18657, 30, 0, false, true,  2, "hibernate")
Add("DRUID", 18658, 40, 0, false, true,  3, "hibernate")

Add("DRUID", 339,   12, 0, false, true,  1, "entangling_roots")
Add("DRUID", 1062,  21, 0, false, true,  2, "entangling_roots")
Add("DRUID", 5195,  24, 0, false, true,  3, "entangling_roots")
Add("DRUID", 5196,  24, 0, false, true,  4, "entangling_roots")
Add("DRUID", 9852,  27, 0, false, true,  5, "entangling_roots")
Add("DRUID", 9853,  27, 0, false, true,  6, "entangling_roots")
Add("DRUID", 26989, 27, 0, false, true,  7, "entangling_roots")

Add("DRUID", 33786,  6, 0, false, false, nil, "cyclone")

Add("DRUID", 5211,   2, 60, true,  false, 1, "bash")
Add("DRUID", 6798,   3, 60, true,  false, 2, "bash")
Add("DRUID", 8983,   4, 60, true,  false, 3, "bash")

Add("DRUID", 9005,   2, 0, true, false, 1, "pounce")
Add("DRUID", 9823,   3, 0, true, false, 2, "pounce")
Add("DRUID", 9827,   3, 0, true, false, 3, "pounce")
Add("DRUID", 27006,  3, 0, true, false, 4, "pounce")

Add("DRUID", 22570,  4, 10, true, false, nil, "maim")
Add("DRUID", 45334,  4, 0,  true, true,  nil, "feral_charge_root")

-- =============================================================================
-- HUNTER
-- =============================================================================
Add("HUNTER", 1499,  20, 30, true,  true, 1, "freezing_trap")
Add("HUNTER", 14310, 20, 30, true,  true, 2, "freezing_trap")
Add("HUNTER", 14311, 20, 30, true,  true, 3, "freezing_trap")
Add("HUNTER", 3355,  20, 30, true,  true, nil, "freezing_trap_effect")

Add("HUNTER", 19503,  4, 30, true, true, nil, "scatter_shot")

Add("HUNTER", 1513,   4, 30, false, true, 1, "scare_beast")
Add("HUNTER", 14326,  4, 30, false, true, 2, "scare_beast")
Add("HUNTER", 14327,  4, 30, false, true, 3, "scare_beast")

Add("HUNTER", 19386, 12, 0,  true, true, 1, "wyvern_sting")
Add("HUNTER", 24132, 12, 0,  true, true, 2, "wyvern_sting")
Add("HUNTER", 24133, 12, 0,  true, true, 3, "wyvern_sting")
Add("HUNTER", 27068, 12, 0,  true, true, 4, "wyvern_sting")
Add("HUNTER", 49011, 12, 0,  true, true, 5, "wyvern_sting")
Add("HUNTER", 49012, 12, 0,  true, true, 6, "wyvern_sting")

Add("HUNTER", 19577,  3, 60, true, false, nil, "intimidation")

-- =============================================================================
-- MAGE
-- =============================================================================
Add("MAGE", 118,    20, 0, false, true, 1, "polymorph")
Add("MAGE", 12824,  30, 0, false, true, 2, "polymorph")
Add("MAGE", 12825,  40, 0, false, true, 3, "polymorph")
Add("MAGE", 12826,  50, 0, false, true, 4, "polymorph")
Add("MAGE", 28271,  50, 0, false, true, nil, "polymorph_turtle")
Add("MAGE", 28272,  50, 0, false, true, nil, "polymorph_pig")
Add("MAGE", 61305,  50, 0, false, true, nil, "polymorph_black_cat")
Add("MAGE", 61721,  50, 0, false, true, nil, "polymorph_rabbit")
Add("MAGE", 61780,  50, 0, false, true, nil, "polymorph_turkey")

Add("MAGE", 122,    8, 0, true, true, 1, "frost_nova", true)
Add("MAGE", 865,    8, 0, true, true, 2, "frost_nova", true)
Add("MAGE", 6131,   8, 0, true, true, 3, "frost_nova", true)
Add("MAGE", 10230,  8, 0, true, true, 4, "frost_nova", true)
Add("MAGE", 27088,  9, 0, true, true, 5, "frost_nova", true)

Add("MAGE", 31661,  3, 0, true, true, 1, "dragons_breath")
Add("MAGE", 33041,  4, 0, true, true, 2, "dragons_breath")
Add("MAGE", 33042,  4, 0, true, true, 3, "dragons_breath")
Add("MAGE", 33043,  3, 0, true, true, 4, "dragons_breath")

-- =============================================================================
-- PALADIN
-- =============================================================================
Add("PALADIN", 853,    3, 60, true, false, 1, "hammer_of_justice")
Add("PALADIN", 5588,   4, 60, true, false, 2, "hammer_of_justice")
Add("PALADIN", 5589,   5, 60, true, false, 3, "hammer_of_justice")
Add("PALADIN", 10308,  6, 60, true, false, 4, "hammer_of_justice")

Add("PALADIN", 20066,  6, 60, true, true, nil, "repentance")
Add("PALADIN", 10326, 20,  0, false, true, nil, "turn_evil")

-- =============================================================================
-- PRIEST
-- =============================================================================
Add("PRIEST", 8122,  8, 30, true, true, 1, "psychic_scream")
Add("PRIEST", 8124,  8, 30, true, true, 2, "psychic_scream")
Add("PRIEST", 10888, 8, 30, true, true, 3, "psychic_scream")
Add("PRIEST", 10890, 8, 30, true, true, 4, "psychic_scream")

Add("PRIEST", 9484,  30, 0, false, true, 1, "shackle_undead")
Add("PRIEST", 9485,  40, 0, false, true, 2, "shackle_undead")
Add("PRIEST", 10955, 50, 0, false, true, 3, "shackle_undead")

Add("PRIEST", 605,   60, 0, false, true, 1, "mind_control")
Add("PRIEST", 10911, 60, 0, false, true, 2, "mind_control")
Add("PRIEST", 10912, 60, 0, false, true, 3, "mind_control")

-- =============================================================================
-- ROGUE
-- =============================================================================
Add("ROGUE", 2094, 10, 120, true, true, nil, "blind")

Add("ROGUE", 6770,  25, 10, true, true, 1, "sap")
Add("ROGUE", 2070,  35, 10, true, true, 2, "sap")
Add("ROGUE", 11297, 45, 10, true, true, 3, "sap")

Add("ROGUE", 1776,  4, 10, true, true, 1, "gouge")
Add("ROGUE", 1777,  4, 10, true, true, 2, "gouge")
Add("ROGUE", 8629,  4, 10, true, true, 3, "gouge")
Add("ROGUE", 11285, 5, 10, true, true, 4, "gouge")
Add("ROGUE", 11286, 6, 10, true, true, 5, "gouge")

Add("ROGUE", 408,   5, 20, true, false, 1, "kidney_shot")
Add("ROGUE", 8643,  6, 20, true, false, 2, "kidney_shot")

Add("ROGUE", 1833,  4, 0, true, false, nil, "cheap_shot")

-- =============================================================================
-- SHAMAN
-- =============================================================================
Add("SHAMAN", 51514, 60, 45, false, true, nil, "hex")

-- =============================================================================
-- WARLOCK
-- =============================================================================
Add("WARLOCK", 5782,  10, 0, false, true, 1, "fear")
Add("WARLOCK", 6213,  15, 0, false, true, 2, "fear")
Add("WARLOCK", 6215,  20, 0, false, true, 3, "fear")

Add("WARLOCK", 710,   20, 0, false, false, 1, "banish")
Add("WARLOCK", 18647, 30, 0, false, false, 2, "banish")

Add("WARLOCK", 5484,  8, 0, false, true, 1, "howl_of_terror")
Add("WARLOCK", 17928, 8, 0, false, true, 2, "howl_of_terror")

Add("WARLOCK", 6789,  3, 120, true, false, 1, "death_coil")
Add("WARLOCK", 17925, 3, 120, true, false, 2, "death_coil")
Add("WARLOCK", 17926, 3, 120, true, false, 3, "death_coil")
Add("WARLOCK", 27223, 3, 120, true, false, 4, "death_coil")

Add("WARLOCK", 30283, 2, 20, false, false, 1, "shadowfury")
Add("WARLOCK", 30413, 3, 20, false, false, 2, "shadowfury")
Add("WARLOCK", 30414, 3, 20, false, false, 3, "shadowfury")

Add("WARLOCK", 6358, 15, 0, false, true, nil, "seduction")

-- =============================================================================
-- WARRIOR
-- =============================================================================
Add("WARRIOR", 5246,  8, 180, true, true, nil, "intimidating_shout")
Add("WARRIOR", 7922,  1, 0,   true, false, nil, "charge_stun")
Add("WARRIOR", 20253, 3, 0,   true, false, nil, "intercept_stun")
Add("WARRIOR", 25274, 3, 30,  true, false, nil, "intercept_stun")
Add("WARRIOR", 12809, 5, 45,  true, false, nil, "concussion_blow")
Add("WARRIOR", 46968, 4, 40,  true, false, nil, "shockwave")

-- =============================================================================
-- DEATH KNIGHT (MoP Classic)
-- =============================================================================
Add("DEATHKNIGHT", 108194, 5, 60, true, false, nil, "asphyxiate")
Add("DEATHKNIGHT", 47481,  3, 0,  true, false, nil, "gnaw")
Add("DEATHKNIGHT", 47476,  5, 60, true, false, nil, "strangulate")

-- =============================================================================
-- MONK (MoP Classic)
-- =============================================================================
Add("MONK", 115078, 40, 15, true, true, nil, "paralysis")
Add("MONK", 119381,  5, 45, true, false, nil, "leg_sweep")
Add("MONK", 116844,  5, 45, true, true,  nil, "ring_of_peace")
Add("MONK", 119392,  3, 30, false, false, nil, "charging_ox_wave")
Add("MONK", 123393,  4, 0,  true, true,  nil, "breath_of_fire")

-- =============================================================================
-- Index builders
-- =============================================================================
--- Rebuild name and class indexes from Afterlife_CCById (called at load and PLAYER_LOGIN).
local function BuildIndexes()
	wipe(Afterlife_CCByName)
	wipe(Afterlife_CCByClass)

	for spellId, entry in pairs(Afterlife_CCById) do
		local classTable = Afterlife_CCByClass[entry.class]
		if not classTable then
			classTable = {}
			Afterlife_CCByClass[entry.class] = classTable
		end
		classTable[spellId] = entry

		local name = GetSpellInfo(spellId)
		if name and name ~= "" then
			local key = strlower(name)
			local existingId = Afterlife_CCByName[key]
			if not existingId then
				Afterlife_CCByName[key] = spellId
			else
				local existing = Afterlife_CCById[existingId]
				local existingRank = existing and existing.rank or 0
				local newRank = entry.rank or 0
				if newRank >= existingRank then
					Afterlife_CCByName[key] = spellId
				end
			end
		end
	end
end

BuildIndexes()

local indexFrame = CreateFrame("Frame")
indexFrame:RegisterEvent("PLAYER_LOGIN")
indexFrame:SetScript("OnEvent", function()
	BuildIndexes()
end)

-- =============================================================================
-- Lookup API
-- =============================================================================

--- Return CC spell data for a spell ID or spell name (highest rank when names collide).
--- @param spellIdOrName number|string
--- @return table|nil { spellId, class, duration, cooldown, breakable, instant, nosound, rank?, family? }
function Afterlife_GetCCSpell(spellIdOrName)
	if spellIdOrName == nil then
		return nil
	end

	if type(spellIdOrName) == "number" then
		return Afterlife_CCById[spellIdOrName]
	end

	if type(spellIdOrName) ~= "string" then
		return nil
	end

	local trimmed = strtrim(spellIdOrName)
	if trimmed == "" then
		return nil
	end

	local key = strlower(trimmed)
	local spellId = Afterlife_CCByName[key]
	if spellId then
		return Afterlife_CCById[spellId]
	end

	local _, _, _, _, _, _, resolvedId = GetSpellInfo(trimmed)
	if resolvedId then
		return Afterlife_CCById[resolvedId]
	end

	return nil
end

--- Return all CC entries for a class (table keyed by spell ID).
--- @param class string e.g. "MAGE", "ROGUE"
--- @return table|nil
function Afterlife_GetCCSpellsByClass(class)
	if not class or class == "" then
		return nil
	end
	return Afterlife_CCByClass[strupper(class)]
end

--- Return all ranks for a spell family name or family key (e.g. "polymorph", "fear").
--- @param family string
--- @return table array of spell entries sorted by rank
function Afterlife_GetCCSpellRanks(family)
	if not family or family == "" then
		return nil
	end

	local key = strlower(strtrim(family))
	local ranks = {}

	for _, entry in pairs(Afterlife_CCById) do
		if entry.family and strlower(entry.family) == key then
			ranks[#ranks + 1] = entry
		end
	end

	table.sort(ranks, function(a, b)
		return (a.rank or 0) < (b.rank or 0)
	end)

	return ranks
end
