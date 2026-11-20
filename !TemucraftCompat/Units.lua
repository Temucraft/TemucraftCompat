-- Unit, spell and combat log functions of newer clients, built on the 3.3.5 ones.
--
-- Some functions exist on 3.3.5 but return their values in an older order (UnitAura, UnitCastingInfo,
-- UnitChannelInfo, UnitGroupRolesAssigned). Those are never replaced: TemucraftCompat.Modern has versions with the
-- newer return values, for ports to use as locals ("local UnitAura = TemucraftCompat.Modern.UnitAura").
local TC = TemucraftCompat
local def = TC.def
local _G = _G
local select, type, tonumber, floor = select, type, tonumber, math.floor
local band = bit.band

local Modern = TC.Modern or {}
TC.Modern = Modern

-- ------------------------------------------------------------------------------------------------ spell ids of casts
-- 3.3.5 UnitCastingInfo has no spell id: the cast events and the combat log give it, so remember it per caster GUID.
local castSpell = {}   -- guid -> { name = spell name, id = spell id }
TC.castSpell = castSpell
local function remember(guid, name, id)
	if not guid or not id then return end
	local r = castSpell[guid]
	if not r then r = {} castSpell[guid] = r end
	r.name, r.id = name, id
end
TC.RememberCast = remember

-- ------------------------------------------------------------------------------------------------ combat log
-- 3.3.5 sends the combat log as event arguments; newer clients read them with CombatLogGetCurrentEventInfo, in a
-- layout with hideCaster and the raid flags added. This frame registers first (the addon loads first), keeps the
-- arguments of the current event and gives them in the newer layout.
local current, currentCount = {}, 0
local function raidFlags(flags) return flags and floor(flags / 0x100000) % 256 or 0 end
local function store(timestamp, subevent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	current[1], current[2], current[3] = timestamp, subevent, false
	current[4], current[5], current[6], current[7] = srcGUID, srcName, srcFlags, raidFlags(srcFlags)
	current[8], current[9], current[10], current[11] = dstGUID, dstName, dstFlags, raidFlags(dstFlags)
	local n = select("#", ...)
	for i = 1, n do current[11 + i] = (select(i, ...)) end
	for i = 12 + n, currentCount do current[i] = nil end
	currentCount = 11 + n
	if subevent == "SPELL_CAST_START" then remember(srcGUID, (select(2, ...)), (...)) end
end
TC.StoreCombatLogEvent = store
def("CombatLogGetCurrentEventInfo", function() return unpack(current, 1, currentCount) end)

local events = CreateFrame("Frame")
events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
events:RegisterEvent("UNIT_SPELLCAST_START")
events:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
events:SetScript("OnEvent", function(_, event, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then return store(...) end
	local unit, name, _, _, id = ...
	remember(UnitGUID(unit), name, id)
end)

-- ------------------------------------------------------------------------------------------------ power events
-- 3.3.5 has one event per power type (UNIT_MANA, UNIT_RAGE...); newer clients send UNIT_POWER_UPDATE,
-- UNIT_POWER_FREQUENT and UNIT_MAXPOWER with the power token. Those are sent from the old ones.
TC.customEvents = TC.customEvents or {}
TC.customEvents.UNIT_POWER_UPDATE, TC.customEvents.UNIT_POWER_FREQUENT, TC.customEvents.UNIT_MAXPOWER = true, true, true
local POWER = { UNIT_MANA = "MANA", UNIT_RAGE = "RAGE", UNIT_FOCUS = "FOCUS", UNIT_ENERGY = "ENERGY", UNIT_RUNIC_POWER = "RUNIC_POWER",
	UNIT_HAPPINESS = "HAPPINESS", UNIT_COMBO_POINTS = "COMBO_POINTS" }
local MAXPOWER = { UNIT_MAXMANA = "MANA", UNIT_MAXRAGE = "RAGE", UNIT_MAXFOCUS = "FOCUS", UNIT_MAXENERGY = "ENERGY",
	UNIT_MAXRUNIC_POWER = "RUNIC_POWER", UNIT_MAXHAPPINESS = "HAPPINESS" }
function TC.PowerEvent(event, unit)
	if not TC.FireEvent then return end
	local token = POWER[event]
	if token then
		-- combo points belong to the player (3.3.5 sends UNIT_COMBO_POINTS for "player" or the vehicle)
		if event == "UNIT_COMBO_POINTS" then unit = "player" end
		TC.FireEvent("UNIT_POWER_UPDATE", unit, token)
		TC.FireEvent("UNIT_POWER_FREQUENT", unit, token)
		return
	end
	token = MAXPOWER[event]
	if token then TC.FireEvent("UNIT_MAXPOWER", unit, token) end
end
local power = CreateFrame("Frame")
for e in pairs(POWER) do power:RegisterEvent(e) end
for e in pairs(MAXPOWER) do power:RegisterEvent(e) end
power:SetScript("OnEvent", function(_, event, unit) TC.PowerEvent(event, unit) end)

-- ------------------------------------------------------------------------------------------------ newer return values
-- UnitAura: name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal,
-- spellId, canApplyAura, isBossDebuff, castByPlayer, nameplateShowAll, timeMod
local function auraModern(name, rank, icon, count, debuffType, duration, expirationTime, source, isStealable, consolidate, spellId)
	if not name then return nil end
	local mine = source == "player" or source == "pet" or source == "vehicle"
	return name, icon, count or 0, debuffType, duration or 0, expirationTime or 0, source, isStealable and true or false,
		mine, spellId, false, false, mine, false, 1
end
TC.AuraModern = auraModern
Modern.UnitAura = function(unit, index, filter) return auraModern(_G.UnitAura(unit, index, filter)) end
Modern.UnitBuff = function(unit, index, filter) return auraModern(_G.UnitBuff(unit, index, filter)) end
Modern.UnitDebuff = function(unit, index, filter) return auraModern(_G.UnitDebuff(unit, index, filter)) end

local function castSpellId(unit, name)
	local r = castSpell[UnitGUID(unit) or ""]
	if r and r.name == name then return r.id end
end
-- UnitCastingInfo: name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellId
Modern.UnitCastingInfo = function(unit)
	local name, _, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = _G.UnitCastingInfo(unit)
	if not name then return nil end
	return name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, castSpellId(unit, name)
end
-- UnitChannelInfo: name, text, texture, startTimeMS, endTimeMS, isTradeSkill, notInterruptible, spellId
Modern.UnitChannelInfo = function(unit)
	local name, _, text, texture, startTime, endTime, isTradeSkill, notInterruptible = _G.UnitChannelInfo(unit)
	if not name then return nil end
	return name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, castSpellId(unit, name)
end
-- UnitGroupRolesAssigned: "TANK", "HEALER", "DAMAGER" or "NONE" (3.3.5 gives three booleans)
Modern.UnitGroupRolesAssigned = function(unit)
	local tank, healer, dps = _G.UnitGroupRolesAssigned(unit)
	if type(tank) == "string" then return tank end
	return (tank and "TANK") or (healer and "HEALER") or (dps and "DAMAGER") or "NONE"
end
-- GetBuildInfo: newer clients add the interface version as a fourth value
Modern.GetBuildInfo = function()
	local version, build, date, toc = _G.GetBuildInfo()
	return version, build, date, toc or 30300
end
-- classic era names for the player's casts
def("CastingInfo", function() return Modern.UnitCastingInfo("player") end)
def("ChannelInfo", function() return Modern.UnitChannelInfo("player") end)

-- ------------------------------------------------------------------------------------------------ aura slots
-- Newer clients read auras by slot or aura instance id. Here both are the aura index: 1-40 for buffs, 101-140 for
-- debuffs. They change when auras come and go, like the 3.3.5 indexes.
local function decode(slot)
	slot = tonumber(slot)
	if not slot then return nil end
	if slot > 100 then return slot - 100, "HARMFUL" end
	return slot, "HELPFUL"
end
local function auraData(unit, slot)
	local index, filter = decode(slot)
	if not index then return nil end
	local name, rank, icon, count, debuffType, duration, expirationTime, source, isStealable, _, spellId = _G.UnitAura(unit, index, filter)
	if not name then return nil end
	local mine = source == "player" or source == "pet" or source == "vehicle"
	return { name = name, icon = icon, applications = count or 0, charges = 1, maxCharges = 1, dispelName = debuffType,
		duration = duration or 0, expirationTime = expirationTime or 0, sourceUnit = source, isStealable = isStealable and true or false,
		spellId = spellId, auraInstanceID = slot, isHelpful = filter == "HELPFUL", isHarmful = filter == "HARMFUL",
		isFromPlayerOrPlayerPet = mine, nameplateShowPersonal = mine, nameplateShowAll = false, canApplyAura = false,
		isBossAura = false, isRaid = false, isNameplateOnly = false, timeMod = 1, points = {} }
end
TC.AuraData = auraData
def("UnitAuraSlots", function(unit, filter, maxSlots, continuationToken)
	if continuationToken then return nil end
	local harmful = type(filter) == "string" and filter:find("HARMFUL")
	local slots = {}
	for i = 1, maxSlots or 40 do
		if not _G.UnitAura(unit, i, harmful and "HARMFUL" or "HELPFUL") then break end
		slots[#slots + 1] = harmful and 100 + i or i
	end
	return nil, unpack(slots)
end)
def("UnitAuraBySlot", function(unit, slot)
	local index, filter = decode(slot)
	if not index then return nil end
	return auraModern(_G.UnitAura(unit, index, filter))
end)

-- ------------------------------------------------------------------------------------------------ unit stand-ins
-- 3.3.5 has no absorb or incoming heal values, quest bosses, battle pets or unit widgets
def("UnitGetIncomingHeals", function() return 0 end)
def("UnitGetTotalAbsorbs", function() return 0 end)
def("UnitGetTotalHealAbsorbs", function() return 0 end)
def("UnitIsQuestBoss", function() return false end)
def("UnitIsBattlePet", function() return false end)
def("UnitIsBattlePetCompanion", function() return false end)
def("UnitNameplateShowsWidgetsOnly", function() return false end)
def("UnitWidgetSet", function() return 0 end)
def("UnitPowerBarID", function() return 0 end)
def("GetUnitPowerBarInfoByID", function() return nil end)
def("UnitPowerDisplayMod", function() return 1 end)
def("GetUnitChargedPowerPoints", function() return nil end)
def("GetPowerRegenForPowerType", function() return GetPowerRegen() end)
def("UnitIsOwnerOrControllerOfUnit", function(owner, unit)
	if UnitIsUnit(owner, "player") then return UnitIsUnit(unit, "pet") or UnitIsUnit(unit, "vehicle") end
	return false
end)
def("GetRelativeDifficultyColor", function(playerLevel, unitLevel) return GetQuestDifficultyColor(unitLevel) end)
def("GetArenaOpponentSpec", function() return nil end)
def("GetNumArenaOpponentSpecs", function() return 0 end)

-- role of the player's active talents: 3.3.5 has no role per talent group, so guess it from stance and auras
def("GetTalentGroupRole", function()
	local _, class = UnitClass("player")
	local form = GetShapeshiftForm()
	if class == "WARRIOR" and form == 2 then return "TANK" end
	if class == "DRUID" and form == 1 then return "TANK" end
	if class == "PALADIN" and UnitBuff("player", (GetSpellInfo(25780))) then return "TANK" end
	if class == "DEATHKNIGHT" and UnitBuff("player", (GetSpellInfo(48263))) then return "TANK" end
	return "DAMAGER"
end)

-- ------------------------------------------------------------------------------------------------ classes and races
local CLASS_BY_ID = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", nil, "DRUID" }
local RACE_BY_ID = { [1] = { "Human", "Human" }, [2] = { "Orc", "Orc" }, [3] = { "Dwarf", "Dwarf" }, [4] = { "Night Elf", "NightElf" },
	[5] = { "Undead", "Scourge" }, [6] = { "Tauren", "Tauren" }, [7] = { "Gnome", "Gnome" }, [8] = { "Troll", "Troll" },
	[10] = { "Blood Elf", "BloodElf" }, [11] = { "Draenei", "Draenei" } }
def("MAX_CLASSES", 11)
def("GetClassInfo", function(classID)
	local file = CLASS_BY_ID[classID]
	if not file then return nil end
	return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]) or file, file, classID
end)
C_CreatureInfo = C_CreatureInfo or {}
local creature = C_CreatureInfo
creature.GetClassInfo = creature.GetClassInfo or function(classID)
	local name, file = GetClassInfo(classID)
	if not name then return nil end
	return { className = name, classFile = file, classID = classID }
end
creature.GetRaceInfo = creature.GetRaceInfo or function(raceID)
	local r = RACE_BY_ID[raceID]
	if not r then return nil end
	return { raceName = r[1], clientFileString = r[2], raceID = raceID }
end
creature.GetFactionInfo = creature.GetFactionInfo or function() return nil end

-- specializations don't exist on 3.3.5
def("GetNumSpecializationsForClassID", function() return 0 end)
def("GetSpecializationInfoForClassID", function() return nil end)
def("GetSpecializationRole", function() return nil end)
def("GetTalentInfoByID", function() return nil end)
def("GetPvpTalentInfoByID", function() return nil end)

-- ------------------------------------------------------------------------------------------------ spell book
-- newer clients say "player"/"pet" for the book; 3.3.5 says "spell"/"pet"
local function book(b) if b == "pet" or b == BOOKTYPE_PET then return "pet" end return "spell" end
def("GetSpellBookItemName", function(index, bookType) return GetSpellName(index, book(bookType)) end)
def("GetSpellBookItemTexture", function(index, bookType) return GetSpellTexture(index, book(bookType)) end)
def("GetSpellBookItemInfo", function(index, bookType)
	local name = GetSpellName(index, book(bookType))
	if not name then return nil end
	local link = GetSpellLink(index, book(bookType))
	local id = link and tonumber(link:match("spell:(%d+)"))
	return "SPELL", id
end)
def("GetFlyoutInfo", function() return nil end)
def("GetFlyoutSlotInfo", function() return nil end)

-- macro icons: newer clients fill a table with every icon
def("GetMacroIcons", function(t)
	t = t or {}
	for i = 1, GetNumMacroIcons() do t[#t + 1] = GetMacroIconInfo(i) end
	return t
end)
def("GetMacroItemIcons", function(t)
	t = t or {}
	for i = 1, GetNumMacroItemIcons() do t[#t + 1] = GetMacroItemIconInfo(i) end
	return t
end)
def("GetLooseMacroIcons", function(t) return t end)
def("GetLooseMacroItemIcons", function(t) return t end)
