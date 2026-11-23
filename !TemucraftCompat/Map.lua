if TemucraftCompat and TemucraftCompat.UnitEnv then setfenv(1, TemucraftCompat.UnitEnv) end -- Temucraft: nameplate unit tokens
-- C_Map on 3.3.5: classic uiMapIDs (TemucraftCompat.UiMapData) on top of the old world map functions.
local data = TemucraftCompat.UiMapData
local byLegacy = {}
for ui, d in pairs(data) do
	local legacy = d.mapID
	if legacy and legacy >= 0 then
		local old = byLegacy[legacy]
		if not old or (data[old].mapType ~= 3 and d.mapType == 3) then byLegacy[legacy] = ui end
	end
end
TemucraftCompat.UiMapIDFromAreaID = function(areaID) return byLegacy[areaID] end
TemucraftCompat.AreaIDFromUiMapID = function(ui) return data[ui] and data[ui].mapID end

local current -- the player's uiMapID, read while the world map is closed
local function refresh()
	if WorldMapFrame and WorldMapFrame:IsShown() then return end
	SetMapToCurrentZone()
	current = byLegacy[GetCurrentMapAreaID()] or current
end
local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }) do f:RegisterEvent(e) end
f:SetScript("OnEvent", refresh)
if WorldMapFrame then WorldMapFrame:HookScript("OnHide", refresh) end

local function worldPos(ui, x, y)
	local d = data[ui]
	if not d or not d[1] or d[1] == 0 then return nil end
	return d[3] - d[1] * x, d[4] - d[2] * y, d.instance
end
local function mapPos(ui, wx, wy)
	local d = data[ui]
	if not d or not d[1] or d[1] == 0 then return nil end
	return (d[3] - wx) / d[1], (d[4] - wy) / d[2]
end

C_Map = C_Map or {}
local function fill(k, v) if C_Map[k] == nil then C_Map[k] = v end end
fill("GetMapInfo", function(ui)
	local d = data[ui]
	if not d then return nil end
	return { mapID = ui, name = d.name, mapType = d.mapType, parentMapID = d.parentMapID, flags = 0 }
end)
fill("GetBestMapForUnit", function(unit)
	if unit ~= "player" and not UnitIsUnit(unit, "player") then return current end
	refresh()
	return current
end)
fill("GetPlayerMapPosition", function(ui, unit)
	local open = WorldMapFrame and WorldMapFrame:IsShown()
	if not open then SetMapToCurrentZone() end
	local x, y = GetPlayerMapPosition(unit or "player")
	if not x or (x == 0 and y == 0) then return nil end
	local shown = byLegacy[GetCurrentMapAreaID()]
	if shown ~= ui then
		local wx, wy = worldPos(shown, x, y)
		if not wx then return nil end
		x, y = mapPos(ui, wx, wy)
		if not x then return nil end
	end
	return CreateVector2D(x, y)
end)
fill("GetWorldPosFromMapPos", function(ui, pos)
	local wx, wy, inst = worldPos(ui, pos.x, pos.y)
	if not wx then return nil end
	return inst, CreateVector2D(wx, wy)
end)
fill("GetMapPosFromWorldPos", function(inst, pos, ui)
	local x, y = mapPos(ui, pos.x, pos.y)
	if not x then return nil end
	return ui, CreateVector2D(x, y)
end)
fill("GetMapArtID", function(ui) return ui end)
fill("GetMapChildrenInfo", function(parent, mapType, all)
	local r = {}
	for ui, d in pairs(data) do
		local p, ok = d.parentMapID, false
		while p and p ~= 0 do
			if p == parent then ok = true break end
			if not all then break end
			p = data[p] and data[p].parentMapID
		end
		if ok and (not mapType or d.mapType == mapType) then r[#r + 1] = C_Map.GetMapInfo(ui) end
	end
	return r
end)
fill("GetAreaInfo", function(areaID) return GetMapNameByID and GetMapNameByID(areaID) end)
fill("GetMapGroupID", function() return nil end)
fill("GetFallbackWorldMapID", function() return 947 end)
fill("CanSetUserWaypointOnMap", function() return false end)
fill("GetMapLevels", function() return 0, 0, 0, 0 end)
fill("GetMapRectOnMap", function() return 0, 1, 0, 1 end)
fill("GetMapDisplayInfo", function() return false end)

C_MapExplorationInfo = C_MapExplorationInfo or {}
if not C_MapExplorationInfo.GetExploredMapTextures then C_MapExplorationInfo.GetExploredMapTextures = function() return {} end end
