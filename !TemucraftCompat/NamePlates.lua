-- Nameplates for newer addons on 3.3.5: C_NamePlate, "nameplateN" unit tokens and the NAME_PLATE_* events.
--
-- The 3.3.5 client has nameplate frames but no unit for them. This finds the plates among WorldFrame's children,
-- gives each shown plate a token (nameplate1, nameplate2...), fires NAME_PLATE_CREATED / NAME_PLATE_UNIT_ADDED /
-- NAME_PLATE_UNIT_REMOVED, and lets the Unit functions take those tokens: a plate that is your target, focus or
-- mouseover is answered by the real unit, any other plate from what the plate itself shows (name, level, health,
-- colour, elite and boss icons, threat glow). Things a plate can't show (auras, casts of other plates, power) are
-- empty for plates that are not one of those units.
--
-- Unit events (casts, auras, threat...) only come for target, focus and mouseover on 3.3.5. They are sent again with
-- the plate token to frames that want plate events: frames that registered an event for a nameplate token with
-- RegisterUnitEvent, or frames given to TemucraftCompat.namePlates.WantEvents(frame). Cast events are sent with the
-- newer arguments (unit, castID, spellID). When a plate gets or loses its real unit, UNIT_AURA is sent for it, and
-- the cast start if that unit is casting.
local TC = TemucraftCompat
if TC.namePlates then return end

local _G = _G
local WorldFrame = WorldFrame
local select, type, tonumber, pairs, ipairs, next = select, type, tonumber, pairs, ipairs, next
local floor = math.floor

local NP = {}
TC.namePlates = NP

-- ------------------------------------------------------------------------------------------------ events
-- Frames can register the new events; every registration is remembered so TC.FireEvent reaches it too.
local custom = { NAME_PLATE_CREATED = true, NAME_PLATE_UNIT_ADDED = true, NAME_PLATE_UNIT_REMOVED = true,
	FORBIDDEN_NAME_PLATE_CREATED = true, FORBIDDEN_NAME_PLATE_UNIT_ADDED = true, FORBIDDEN_NAME_PLATE_UNIT_REMOVED = true }
TC.customEvents = TC.customEvents or {}
-- unit events that are sent again for plate tokens
TC.plateUnitEvents = TC.plateUnitEvents or {}
for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE",
	"UNIT_FACTION", "UNIT_FLAGS", "UNIT_LEVEL", "UNIT_CLASSIFICATION_CHANGED", "UNIT_AURA", "UNIT_TARGET",
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }) do
	TC.plateUnitEvents[e] = true
end
for e in pairs(custom) do TC.customEvents[e] = true end
local listeners = {}   -- event -> { frame = true }

local function remember(frame, event)
	local l = listeners[event]
	if not l then l = setmetatable({}, { __mode = "k" }) listeners[event] = l end
	l[frame] = true
end

for _, m in pairs(TC.widgetMethods or {}) do
	if type(m) == "table" and m.RegisterEvent and not m.__tcNamePlateEvents then
		m.__tcNamePlateEvents = true
		local register, unregister, isRegistered, unregisterAll = m.RegisterEvent, m.UnregisterEvent, m.IsEventRegistered, m.UnregisterAllEvents
		m.RegisterEvent = function(self, event, ...)
			if TC.customEvents[event] then remember(self, event) return true end
			if TC.plateUnitEvents[event] then remember(self, event) end
			return register(self, event, ...)
		end
		m.UnregisterEvent = function(self, event, ...)
			if listeners[event] then listeners[event][self] = nil end
			if TC.customEvents[event] then return end
			return unregister(self, event, ...)
		end
		if isRegistered then
			m.IsEventRegistered = function(self, event, ...)
				if TC.customEvents[event] then return listeners[event] and listeners[event][self] and true or false end
				return isRegistered(self, event, ...)
			end
		end
		m.UnregisterAllEvents = function(self, ...)
			for _, l in pairs(listeners) do l[self] = nil end
			return unregisterAll(self, ...)
		end
	end
end

-- Sends an event to every frame that registered it (through RegisterEvent or RegisterUnitEvent).
-- A frame that used RegisterUnitEvent only gets the event for its units.
local function unitAllowed(frame, event, unit)
	local units = frame.__tcUnits and frame.__tcUnits[event]
	return not units or type(unit) ~= "string" or units[unit] ~= nil
end
function TC.FireEvent(event, ...)
	local l = listeners[event]
	if not l then return end
	for frame in pairs(l) do
		if unitAllowed(frame, event, (...)) then
			local f = frame:GetScript("OnEvent")
			if f then f(frame, event, ...) end
		end
	end
end

-- frames that want unit events for plate tokens
local wanted = setmetatable({}, { __mode = "k" })
local function wantsPlateEvents(frame)
	if wanted[frame] then return true end
	local units = frame.__tcUnits
	if units then
		for _, set in pairs(units) do
			for u in pairs(set) do if type(u) == "string" and u:find("^nameplate%d+$") then return true end end
		end
	end
	return false
end
-- Sends a unit event for a plate token to the frames that want plate events.
function TC.FirePlateEvent(event, token, ...)
	local l = listeners[event]
	if not l then return end
	for frame in pairs(l) do
		if wantsPlateEvents(frame) and unitAllowed(frame, event, token) then
			local f = frame:GetScript("OnEvent")
			if f then f(frame, event, token, ...) end
		end
	end
end
-- Makes a frame get unit events for plate tokens (UNIT_AURA, casts...) even when it registered them with RegisterEvent.
function NP.WantEvents(frame) wanted[frame] = true end

-- ------------------------------------------------------------------------------------------------ plates
local plates = {}        -- plate frame -> info table
local byToken = {}       -- "nameplateN" -> plate
local seen = 0           -- WorldFrame children already looked at

local CLASS_BY_COLOR = {}
for class, c in pairs(RAID_CLASS_COLORS or {}) do
	CLASS_BY_COLOR[floor(c.r * 100 + 0.5) .. ":" .. floor(c.g * 100 + 0.5) .. ":" .. floor(c.b * 100 + 0.5)] = class
end

-- the 3.3.5 nameplate: an unnamed frame whose second region is the nameplate border
local function isNamePlate(frame)
	if frame:GetName() then return false end
	local border = select(2, frame:GetRegions())
	return border and border.GetObjectType and border:GetObjectType() == "Texture"
		and border:GetTexture() == "Interface\\Tooltips\\Nameplate-Border"
end
NP.IsNamePlate = isNamePlate

local function freeToken()
	local i = 1
	while byToken["nameplate" .. i] do i = i + 1 end
	return "nameplate" .. i
end

local function regionsOf(plate)
	local glow, border, castBorder, castNoStop, spellIcon, highlight, name, level, boss, raid, elite = plate:GetRegions()
	local health, cast = plate:GetChildren()
	return { glow = glow, border = border, highlight = highlight, name = name, level = level, boss = boss, raid = raid,
		elite = elite, health = health, cast = cast, spellIcon = spellIcon }
end

local function add(plate)
	local info = plates[plate]
	if info.token then return end
	local token = freeToken()
	info.token = token
	info.guid = nil
	byToken[token] = plate
	plate.namePlateUnitToken = token
	plate.UnitFrame = plate.UnitFrame or plate
	plate.UnitFrame.unit = token
	NP.Bind(plate)
	TC.FireEvent("NAME_PLATE_UNIT_ADDED", token)
end

local function remove(plate)
	local info = plates[plate]
	if not info or not info.token then return end
	local token = info.token
	TC.FireEvent("NAME_PLATE_UNIT_REMOVED", token)
	byToken[token] = nil
	info.token, info.guid, info.unit, info.relayed = nil, nil, nil, nil
	plate.namePlateUnitToken = nil
end

local function setup(plate)
	if plates[plate] then return end
	local info = regionsOf(plate)
	info.plate = plate
	plates[plate] = info
	plate:HookScript("OnShow", add)
	plate:HookScript("OnHide", remove)
	if info.health and info.health.HookScript then
		info.health:HookScript("OnValueChanged", function()
			if info.token then TC.FireEvent("UNIT_HEALTH", info.token) end
		end)
		info.health:HookScript("OnMinMaxChanged", function()
			if info.token then TC.FireEvent("UNIT_MAXHEALTH", info.token) end
		end)
	end
	TC.FireEvent("NAME_PLATE_CREATED", plate)
	if plate:IsShown() then add(plate) end
end

function NP.Scan()
	local n = WorldFrame:GetNumChildren()
	if n == seen then return end
	for i = seen + 1, n do
		local child = select(i, WorldFrame:GetChildren())
		if child and not plates[child] and isNamePlate(child) then setup(child) end
	end
	seen = n
end

-- ------------------------------------------------------------------------------------------------ plate data
local function rgbKey(r, g, b) return floor(r * 100 + 0.5) .. ":" .. floor(g * 100 + 0.5) .. ":" .. floor(b * 100 + 0.5) end

-- what the plate shows: name, level, classification, health, reaction (2 hostile / 4 neutral / 5 friendly), player, class
local function plateData(info)
	local d = {}
	d.name = info.name and info.name:GetText()
	local lvl = info.level and info.level:IsShown() and tonumber(info.level:GetText() or "")
	local boss = info.boss and info.boss:IsShown()
	d.level = boss and -1 or lvl or -1
	d.classification = boss and "worldboss" or (info.elite and info.elite:IsShown() and "elite") or "normal"
	if info.health then
		local lo, hi = info.health:GetMinMaxValues()
		d.health, d.healthMax = info.health:GetValue() or 0, hi or 1
		local r, g, b = info.health:GetStatusBarColor()
		d.r, d.g, d.b = r, g, b
		d.class = CLASS_BY_COLOR[rgbKey(r, g, b)]
		if d.class then d.reaction, d.isPlayer = 2, true
		elseif r > 0.9 and g < 0.2 and b < 0.2 then d.reaction = 2
		elseif r > 0.9 and g > 0.9 and b < 0.2 then d.reaction = 4
		elseif r < 0.2 and g > 0.9 and b < 0.2 then d.reaction = 5
		elseif r < 0.2 and g < 0.2 and b > 0.9 then d.reaction, d.isPlayer = 5, true
		else d.reaction = 2 end
	end
	if info.glow and info.glow:IsShown() then
		local r, g, b = info.glow:GetVertexColor()
		d.threat = (g > 0.9 and 1) or (g > 0.4 and 2) or 3
	else
		d.threat = 0
	end
	d.mouseover = info.highlight and info.highlight:IsShown()
	return d
end
NP.PlateData = function(plate) return plates[plate] and plateData(plates[plate]) end

-- ------------------------------------------------------------------------------------------------ real units
local rawUnitExists, rawUnitGUID, rawUnitName, rawUnitHealth = UnitExists, UnitGUID, UnitName, UnitHealth
local rawCasting, rawChannel = UnitCastingInfo, UnitChannelInfo

-- the plate's real unit right now: target (the only plate at full alpha while you have a target), mouseover, focus
function NP.Bind(plate)
	local info = plates[plate]
	if not info or not info.token then return end
	local d = plateData(info)
	info.unit = nil
	if rawUnitExists("target") and plate:GetAlpha() >= 0.99 and rawUnitName("target") == d.name then
		info.unit = "target"
	elseif d.mouseover and rawUnitExists("mouseover") and rawUnitName("mouseover") == d.name then
		info.unit = "mouseover"
	elseif rawUnitExists("focus") and rawUnitName("focus") == d.name and rawUnitHealth("focus") == d.health then
		info.unit = "focus"
	end
	if info.unit then info.guid = rawUnitGUID(info.unit) end
	NP.BindChanged(info)
	return info.unit
end

-- the spell id of a cast, from the cast events or the combat log (Units.lua)
local function castSpellId(guid, name)
	local r = TC.castSpell and TC.castSpell[guid or ""]
	if r and r.name == name then return r.id end
end

-- callback(plate, token, unit or nil) runs when a plate gets or loses its real unit
NP.bindCallbacks = {}
function NP.RegisterBindCallback(callback) NP.bindCallbacks[#NP.bindCallbacks + 1] = callback end

-- When a plate gets or loses its real unit its auras change, and a cast of the new unit can be shown.
function NP.BindChanged(info)
	local now = (info.unit and info.guid) or false
	if now == (info.relayed or false) then return end
	info.relayed = now
	local token = info.token
	if not token then return end
	for _, callback in ipairs(NP.bindCallbacks) do callback(info.plate, token, info.unit) end
	TC.FirePlateEvent("UNIT_AURA", token)
	if not now then return end
	if not rawCasting then return end
	local name, _, _, _, _, _, _, castID = rawCasting(info.unit)
	if name then return TC.FirePlateEvent("UNIT_SPELLCAST_START", token, castID, castSpellId(info.guid, name)) end
	name = rawChannel and rawChannel(info.unit)
	if name then return TC.FirePlateEvent("UNIT_SPELLCAST_CHANNEL_START", token, nil, castSpellId(info.guid, name)) end
end

local function realUnit(token)
	local plate = byToken[token]
	local info = plate and plates[plate]
	if not info then return nil, nil end
	if info.unit and rawUnitExists(info.unit) and rawUnitGUID(info.unit) == info.guid then return info.unit, info end
	info.unit = nil
	return nil, info
end
NP.RealUnit = realUnit

local function isToken(u) return type(u) == "string" and byToken[u] ~= nil end
local function isPlateToken(u) return type(u) == "string" and u:find("^nameplate%d+$") ~= nil end

-- Unit functions: a nameplate token is answered by its real unit when it has one, else by fallback(info, data, ...)
local function wrap(name, fallback)
	local raw = _G[name]
	if type(raw) ~= "function" then return end
	_G[name] = function(unit, ...)
		if isPlateToken(unit) then
			local real, info = realUnit(unit)
			if real then return raw(real, ...) end
			if not fallback then return nil end
			if not info then return fallback(nil, nil, ...) end
			return fallback(info, plateData(info), ...)
		end
		return raw(unit, ...)
	end
end

-- two-unit functions (UnitCanAttack("player", plate)): the token can be either unit
local function wrapPair(name, fallback)
	local raw = _G[name]
	if type(raw) ~= "function" then return end
	_G[name] = function(a, b, ...)
		local pa, pb = isPlateToken(a), isPlateToken(b)
		if not pa and not pb then return raw(a, b, ...) end
		local ra, ia, rb, ib
		if pa then ra, ia = realUnit(a) else ra = a end
		if pb then rb, ib = realUnit(b) else rb = b end
		if ra and rb then return raw(ra, rb, ...) end
		local info = ia or ib
		if not info then return fallback(nil, nil) end
		return fallback(info, plateData(info))
	end
end

local hostile = function(_, d) return d ~= nil and d.reaction <= 4 end
wrap("UnitExists", function(info) return info ~= nil end)
wrap("UnitGUID", function(info) return info and info.guid end)
wrap("UnitName", function(_, d) return d and d.name, nil end)
wrap("GetUnitName", function(_, d) return d and d.name end)
wrap("UnitHealth", function(_, d) return d and d.health or 0 end)
wrap("UnitHealthMax", function(_, d) return d and d.healthMax or 1 end)
wrap("UnitLevel", function(_, d) return d and d.level or -1 end)
wrap("UnitEffectiveLevel", function(_, d) return d and d.level or -1 end)
wrap("UnitClassification", function(_, d) return d and d.classification or "normal" end)
wrapPair("UnitReaction", function(_, d) return d and d.reaction end)
wrapPair("UnitIsEnemy", function(_, d) return d ~= nil and d.reaction == 2 end)
wrapPair("UnitCanAttack", hostile)
wrapPair("UnitIsFriend", function(_, d) return d ~= nil and d.reaction == 5 end)
wrapPair("UnitCanAssist", function(_, d) return d ~= nil and d.reaction == 5 end)
wrap("UnitIsPlayer", function(_, d) return d ~= nil and d.isPlayer == true end)
wrap("UnitPlayerControlled", function(_, d) return d ~= nil and d.isPlayer == true end)
wrap("UnitClass", function(_, d)
	if d and d.class then return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[d.class] or d.class, d.class end
	return nil, nil
end)
wrap("UnitIsDead", function(_, d) return d ~= nil and d.health <= 0 end)
wrap("UnitIsDeadOrGhost", function(_, d) return d ~= nil and d.health <= 0 end)
wrap("UnitIsConnected", function(info) return info ~= nil end)
wrap("UnitIsVisible", function(info) return info ~= nil end)
wrap("UnitAffectingCombat", function(_, d) return d ~= nil and d.threat > 0 end)
wrap("UnitSelectionColor", function(_, d) if d then return d.r, d.g, d.b, 1 end return 1, 1, 1, 1 end)
wrap("UnitPower", function() return 0 end)
wrap("UnitPowerMax", function() return 0 end)
wrap("UnitPowerType", function() return 0, "MANA" end)
wrap("UnitIsTapped", function() return false end)
wrap("UnitIsTappedByPlayer", function() return false end)
wrap("UnitIsTrivial", function() return false end)
wrap("UnitIsPVP", function(_, d) return d ~= nil and d.isPlayer == true end)
wrap("UnitCreatureType", function() return nil end)
wrap("UnitRace", function() return nil, nil end)
wrap("UnitSex", function() return 1 end)
wrap("UnitCastingInfo", function() return nil end)
wrap("UnitChannelInfo", function() return nil end)
wrap("UnitAura", function() return nil end)
wrap("UnitBuff", function() return nil end)
wrap("UnitDebuff", function() return nil end)
wrap("GetRaidTargetIndex", function(info)
	if not info or not info.raid or not info.raid:IsShown() then return nil end
	local l, r, t, b = info.raid:GetTexCoord()
	return floor(l * 4 + 0.5) + floor(t * 4 + 0.5) * 4 + 1
end)

-- range checks: the unit can be any argument. A plate without a real unit counts as in range (the client shows
-- plates only for units near you, and it can't tell how near).
local function wrapRange(name, ...)
	local raw = _G[name]
	if type(raw) ~= "function" then return end
	local fallback = { ... }
	_G[name] = function(a, b, c, ...)
		local token = (isPlateToken(a) and 1) or (isPlateToken(b) and 2) or (isPlateToken(c) and 3)
		if not token then return raw(a, b, c, ...) end
		local real = realUnit(token == 1 and a or token == 2 and b or c)
		if not real then return unpack(fallback) end
		if token == 1 then return raw(real, b, c, ...) elseif token == 2 then return raw(a, real, c, ...) end
		return raw(a, b, real, ...)
	end
end
wrapRange("IsSpellInRange", 1)
wrapRange("IsItemInRange", 1)
wrapRange("CheckInteractDistance", 1)
wrapRange("UnitInRange", true, true)

-- threat: the unit-to-unit functions take the plate token as the second unit
local rawThreat = UnitThreatSituation
if rawThreat then
	UnitThreatSituation = function(unit, other, ...)
		if isPlateToken(other) then
			local real, info = realUnit(other)
			if real then return rawThreat(unit, real, ...) end
			return info and plateData(info).threat or nil
		end
		if isPlateToken(unit) then
			local real = realUnit(unit)
			if real then return rawThreat(real, other, ...) end
			return nil
		end
		return rawThreat(unit, other, ...)
	end
end
local rawDetailed = UnitDetailedThreatSituation
if rawDetailed then
	UnitDetailedThreatSituation = function(unit, other, ...)
		if isPlateToken(other) then
			local real, info = realUnit(other)
			if real then return rawDetailed(unit, real, ...) end
			local t = info and plateData(info).threat or 0
			return t >= 2, t, t >= 2 and 100 or 0, t >= 2 and 100 or 0, 0
		end
		return rawDetailed(unit, other, ...)
	end
end
local rawIsUnit = UnitIsUnit
UnitIsUnit = function(a, b)
	if a == b then return rawUnitExists(a) or isToken(a) end
	local pa, pb = isPlateToken(a), isPlateToken(b)
	if pa or pb then
		local ra = pa and realUnit(a) or (not pa and a)
		local rb = pb and realUnit(b) or (not pb and b)
		if not ra or not rb then return false end
		return rawIsUnit(ra, rb)
	end
	return rawIsUnit(a, b)
end

-- ------------------------------------------------------------------------------------------------ C_NamePlate
C_NamePlate = C_NamePlate or {}
C_NamePlate.GetNamePlates = function()
	local list = {}
	for plate, info in pairs(plates) do if info.token and plate:IsShown() then list[#list + 1] = plate end end
	return list
end
C_NamePlate.GetNamePlateForUnit = function(unit)
	if isPlateToken(unit) then return byToken[unit] end
	if type(unit) ~= "string" or not rawUnitExists(unit) then return nil end
	local guid = rawUnitGUID(unit)
	for plate, info in pairs(plates) do
		if info.token then
			if not info.unit then NP.Bind(plate) end
			if info.guid == guid then return plate end
		end
	end
	return nil
end
for _, name in ipairs({ "SetNamePlateFriendlySize", "SetNamePlateEnemySize", "SetNamePlateSelfSize",
	"SetNamePlateFriendlyClickThrough", "SetNamePlateEnemyClickThrough", "SetNamePlateSelfClickThrough",
	"SetNamePlateFriendlyPreferredClickInsets", "SetNamePlateEnemyPreferredClickInsets", "SetNamePlateSelfPreferredClickInsets",
	"SetTargetClampingInsets" }) do
	C_NamePlate[name] = C_NamePlate[name] or function() end
end
C_NamePlate.GetNamePlateFriendlySize = C_NamePlate.GetNamePlateFriendlySize or function() return 110, 45 end
C_NamePlate.GetNamePlateEnemySize = C_NamePlate.GetNamePlateEnemySize or function() return 110, 45 end
C_NamePlate.GetNamePlateSelfSize = C_NamePlate.GetNamePlateSelfSize or function() return 110, 45 end
C_NamePlate.GetNamePlateEnemyClickThrough = C_NamePlate.GetNamePlateEnemyClickThrough or function() return false end
C_NamePlate.GetNamePlateFriendlyClickThrough = C_NamePlate.GetNamePlateFriendlyClickThrough or function() return false end

-- ------------------------------------------------------------------------------------------------ driver
local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, e)
	elapsed = elapsed + e
	if elapsed < 0.1 then return end
	elapsed = 0
	NP.Scan()
	-- a plate's alpha shows the target one frame after the target changes: keep binding the ones without a unit
	if rawUnitExists("target") or rawUnitExists("mouseover") or rawUnitExists("focus") then
		for plate, info in pairs(plates) do if info.token and not info.unit then NP.Bind(plate) end end
	end
end)
-- who is the target / mouseover / focus changes the plates' real units
driver:RegisterEvent("PLAYER_TARGET_CHANGED")
driver:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
driver:RegisterEvent("PLAYER_FOCUS_CHANGED")
driver:SetScript("OnEvent", function()
	NP.Scan()
	for plate, info in pairs(plates) do if info.token then NP.Bind(plate) end end
end)

-- unit events of target, focus and mouseover are sent again for the plates that show those units
local relay = CreateFrame("Frame")
local CAST = { UNIT_SPELLCAST_START = 1, UNIT_SPELLCAST_STOP = 1, UNIT_SPELLCAST_FAILED = 1, UNIT_SPELLCAST_INTERRUPTED = 1,
	UNIT_SPELLCAST_DELAYED = 1, UNIT_SPELLCAST_SUCCEEDED = 1, UNIT_SPELLCAST_CHANNEL_START = 2, UNIT_SPELLCAST_CHANNEL_UPDATE = 2,
	UNIT_SPELLCAST_CHANNEL_STOP = 2, UNIT_SPELLCAST_INTERRUPTIBLE = 2, UNIT_SPELLCAST_NOT_INTERRUPTIBLE = 2 }
local SOURCES = { target = true, focus = true, mouseover = true }
for e in pairs(TC.plateUnitEvents) do
	if e ~= "UNIT_HEALTH" and e ~= "UNIT_MAXHEALTH" then relay:RegisterEvent(e) end
end
function NP.Relay(event, unit, ...)
	if not SOURCES[unit] then return end
	local guid = rawUnitGUID(unit)
	if not guid then return end
	for plate, info in pairs(plates) do
		if info.token and info.unit == unit and info.guid == guid then
			local kind = CAST[event]
			if kind then
				-- 3.3.5: unit, spellName, rank, lineID, spellID; newer clients: unit, castID, spellID
				local _, _, lineID, spellID = ...
				TC.FirePlateEvent(event, info.token, kind == 1 and lineID or nil, spellID)
			else
				TC.FirePlateEvent(event, info.token, ...)
			end
		end
	end
end
relay:SetScript("OnEvent", function(_, event, unit, ...) NP.Relay(event, unit, ...) end)
