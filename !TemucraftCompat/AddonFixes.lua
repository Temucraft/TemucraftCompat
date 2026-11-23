-- Fixes for other addons that don't know Temucraft's races.
local TC = TemucraftCompat

-- Questie finds the player's race by its file name (UnitRace's second value) to read the quests' race masks. Temucraft's
-- own races are not in its list, so it stopped at start with "playerRaceId (a nil value)". Its quest data has the
-- standard masks, and the server lets Worgen take Human quests and Goblins take Orc quests, so each race here is
-- given the standard race whose quests it should see. Any other race gets Human or Orc by faction.
TC.questRaceBase = {
	Goblin = 2, Worgen = 1, Gilnean = 1,
	AlliancePandaren = 1, HordePandaren = 2,
	Nightborne = 10, HighmountainTauren = 6, VoidElf = 1, LightforgedDraenei = 11,
	ZandalariTroll = 8, KulTiran = 1, Vulpera = 2, DarkIronDwarf = 3, Maghar = 2, Mechagnome = 7,
	AllianceDracthyr = 1, HordeDracthyr = 2, AllianceEarthen = 3, HordeEarthen = 2,
	AllianceHaranir = 4, HordeHaranir = 6,
}

local function fixQuestie()
	local qc = rawget(_G, "QuestieCompat")
	local races = type(qc) == "table" and rawget(qc, "ChrRaces")
	if type(races) ~= "table" then return false end
	for file, base in pairs(TC.questRaceBase) do races[file] = base end
	if not getmetatable(races) then
		setmetatable(races, { __index = function()
			return UnitFactionGroup("player") == "Alliance" and 1 or 2
		end })
	end
	return true
end
TC.FixQuestie = fixQuestie

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self)
	if fixQuestie() then self:UnregisterEvent("ADDON_LOADED") end
end)
