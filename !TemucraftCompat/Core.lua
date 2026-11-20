-- !TemucraftCompat: newer addon functions for the 3.3.5a client.
-- Only adds what is missing (never replaces a function the client has), so it is safe next to other addons.
local _G = _G
local function def(name, value) if _G[name] == nil then _G[name] = value end end
TemucraftCompat = TemucraftCompat or { version = 1 }
local TC = TemucraftCompat
TC.def = def

-- Game flavour: modern addons test these. 3.3.5 is "Wrath", the closest classic project.
def("WOW_PROJECT_MAINLINE", 1)
def("WOW_PROJECT_CLASSIC", 2)
def("WOW_PROJECT_BURNING_CRUSADE_CLASSIC", 5)
def("WOW_PROJECT_WRATH_CLASSIC", 11)
def("WOW_PROJECT_ID", 11)
def("LE_EXPANSION_LEVEL_CURRENT", 2)

-- Lua helpers
def("strmatch", string.match)
def("issecretvalue", function() return false end)
def("canaccessvalue", function() return true end)
def("canaccesstable", function() return true end)
def("securecallfunction", function(f, ...) return f(...) end)
def("secureexecuterange", function(t, f, ...) for k, v in pairs(t) do f(k, v, ...) end end)
def("Clamp", function(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end)
def("Saturate", function(v) return Clamp(v, 0, 1) end)
def("Lerp", function(a, b, t) return a + (b - a) * t end)
def("Round", function(v) return math.floor(v + 0.5) end)
def("tContains", function(t, v) for _, x in pairs(t) do if x == v then return true end end return false end)
def("tInvert", function(t) local r = {} for k, v in pairs(t) do r[v] = k end return r end)
def("CopyTable", function(t, shallow)
	local r = {}
	for k, v in pairs(t) do if type(v) == "table" and not shallow then r[k] = CopyTable(v) else r[k] = v end end
	return r
end)
def("GetOrCreateTableEntry", function(t, k, default) local v = t[k] if v == nil then v = default or {} t[k] = v end return v end)
def("ExecuteFrameScript", function(frame, script, ...) local f = frame:GetScript(script) if f then return f(frame, ...) end end)
def("BreakUpLargeNumbers", function(n)
	local s = tostring(math.floor(n or 0))
	local neg = s:sub(1, 1) == "-" and "-" or ""
	s = s:gsub("^-", "")
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return neg .. out
end)
def("RunNextFrame", function(f) C_Timer.After(0, f) end)
def("IsMetaKeyDown", function() return false end)
def("GetServerTime", function() return time() end)
def("GetCurrentRegion", function() return 3 end)
def("GetCurrentRegionName", function() return "EU" end)
def("GetPhysicalScreenSize", function()
	local w, h = string.match(GetCVar("gxResolution") or "", "(%d+)x(%d+)")
	return tonumber(w) or 1920, tonumber(h) or 1080
end)
def("UnitFullName", function(unit) local n, r = UnitName(unit) return n, r or (UnitIsUnit(unit, "player") and GetRealmName():gsub("%s", "") or nil) end)
def("GetNormalizedRealmName", function() return (GetRealmName():gsub("[%s%-]", "")) end)
def("Ambiguate", function(name) return name end)
def("UnitIsTapDenied", function(unit) return UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) end)
def("UnitPosition", function() return nil end)
def("IsInRaid", function() return GetNumRaidMembers() > 0 end)
def("IsInGroup", function() return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 end)
def("GetNumGroupMembers", function()
	local r = GetNumRaidMembers()
	if r > 0 then return r end
	local p = GetNumPartyMembers()
	return p > 0 and p + 1 or 0
end)
def("GetNumSubgroupMembers", function() return GetNumPartyMembers() end)
def("UnitIsGroupLeader", function(unit)
	if UnitIsUnit(unit, "player") then return IsRaidLeader() or IsPartyLeader() end
	if GetNumRaidMembers() > 0 then
		for i = 1, GetNumRaidMembers() do
			local name, rank = GetRaidRosterInfo(i)
			if name == UnitName(unit) then return rank == 2 end
		end
		return false
	end
	local idx = tonumber(string.match(unit or "", "^party(%d)$"))
	return idx ~= nil and GetPartyLeaderIndex() == idx
end)
def("UnitIsGroupAssistant", function(unit)
	if UnitIsUnit(unit, "player") then return IsRaidOfficer() end
	for i = 1, GetNumRaidMembers() do
		local name, rank = GetRaidRosterInfo(i)
		if name == UnitName(unit) then return rank == 1 end
	end
	return false
end)
def("GetAverageItemLevel", function()
	local total, n = 0, 0
	for slot = 1, 18 do
		if slot ~= 4 then
			local link = GetInventoryItemLink("player", slot)
			if link then local _, _, _, lvl = GetItemInfo(link) if lvl then total, n = total + lvl, n + 1 end end
		end
	end
	local avg = n > 0 and total / n or 0
	return avg, avg
end)
def("GetDetailedItemLevelInfo", function(item) local _, _, _, lvl = GetItemInfo(item) return lvl, nil, lvl end)
def("GetItemInfoInstant", function(item)
	local name, link, quality, level, minLevel, typeName, subType, stack, equipLoc, icon = GetItemInfo(item)
	local id = type(item) == "number" and item or (link and tonumber(link:match("item:(%d+)"))) or tonumber(tostring(item):match("item:(%d+)"))
	return id, typeName, subType, equipLoc, icon
end)
def("GetItemInfoFromHyperlink", function(link) return link and tonumber(link:match("item:(%d+)")) end)
def("GetMaxBattlefieldID", function() return MAX_BATTLEFIELD_QUEUES or 2 end)
def("GetQuestLogIndexByID", function(questID)
	for i = 1, GetNumQuestLogEntries() do
		local link = GetQuestLink(i)
		if link and tonumber(link:match("quest:(%d+)")) == questID then return i end
	end
	return 0
end)
def("IsQuestComplete", function(questID)
	local i = GetQuestLogIndexByID(questID)
	if i == 0 then return false end
	local _, _, _, _, _, _, complete = GetQuestLogTitle(i)
	return complete == 1
end)
def("GetQuestLogIsAutoComplete", function() return false end)
def("ShowQuestComplete", function() end)
def("GetSpellSubtext", function(spell) local _, rank = GetSpellInfo(spell) return rank end)
def("IsPlayerSpell", function(id) local name = GetSpellInfo(id) return name ~= nil and GetSpellInfo(name) ~= nil end)
def("IsSpellKnownOrOverridesKnown", function(id) return IsSpellKnown and IsSpellKnown(id) end)
def("GetFileIDFromPath", function(path) return path end)
def("IsMoviePlayable", function() return false end)
def("GetCreatureDifficultyColor", function(level) return GetQuestDifficultyColor(level) end)
def("GetInspectSpecialization", function() return 0 end)
def("GetSpecialization", function() return GetActiveTalentGroup and GetActiveTalentGroup() or 1 end)
def("GetSpecializationInfo", function() return nil end)
def("GetSpecializationInfoByID", function() return nil end)
def("SellCursorItem", function() end)
def("MuteSoundFile", function() end)   -- the 3.3.5 client can't mute single sounds
def("UnmuteSoundFile", function() end)
def("StopSound", function(handle) if handle == "music" then StopMusic() end end) -- music started as handle "music"
def("PlaySoundKitID", function(id) return PlaySound(id) end)
def("ConvertRGBtoColorString", function(c) return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end)
def("RGBToColorCode", function(r, g, b) return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255) end)
def("RGBTableToColorCode", function(c) return RGBToColorCode(c.r, c.g, c.b) end)
def("FormatLargeNumber", BreakUpLargeNumbers)
def("GetMinimapShape", function() return "ROUND" end)
def("GetAutoCompleteRealms", function() return nil end)
def("BNGetFriendIndex", function() return nil end)
def("BNInviteFriend", function() end)
def("FCF_IsChatWindowIndexActive", function(i) local _, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(i) return shown or docked end)
def("FCF_GetChatFrameByID", function(i) return _G["ChatFrame" .. i] end)
def("CooldownFrame_Set", function(cd, start, duration, enable) CooldownFrame_SetTimer(cd, start, duration, enable) end)
def("RETRIEVING_DATA", "Retrieving item information")
def("SEARCH_LOADING_TEXT", "Loading...")

-- SOUNDKIT: the names modern addons use, as 3.3.5 sound names
def("SOUNDKIT", setmetatable({
	IG_MAINMENU_OPEN = "igMainMenuOpen", IG_MAINMENU_CLOSE = "igMainMenuClose", IG_MAINMENU_OPTION = "igMainMenuOption",
	IG_MAINMENU_OPTION_CHECKBOX_ON = "igMainMenuOptionCheckBoxOn", IG_MAINMENU_OPTION_CHECKBOX_OFF = "igMainMenuOptionCheckBoxOff",
	U_CHAT_SCROLL_BUTTON = "UChatScrollButton", IG_CHARACTER_INFO_TAB = "igCharacterInfoTab", IG_QUEST_LIST_OPEN = "igQuestListOpen",
	IG_QUEST_LIST_CLOSE = "igQuestListClose", IG_SPELLBOOK_OPEN = "igSpellBookOpen", IG_SPELLBOOK_CLOSE = "igSpellBookClose",
	GS_TITLE_OPTION_OK = "gsTitleOptionOK", IG_PLAYER_INVITE = "igPlayerInvite", READY_CHECK = "ReadyCheck", RAID_WARNING = "RaidWarning",
	LEVEL_UP = "LEVELUP", MONEY_FRAME_OPEN = "MONEYFRAMEOPEN", MONEY_FRAME_CLOSE = "MONEYFRAMECLOSE", LOOT_WINDOW_COIN_SOUND = "LOOTWINDOWCOINSOUND",
	IG_BACKPACK_OPEN = "igBackPackOpen", IG_BACKPACK_CLOSE = "igBackPackClose", TELL_MESSAGE = "TellMessage", AUCTION_WINDOW_OPEN = "AuctionWindowOpen",
	AUCTION_WINDOW_CLOSE = "AuctionWindowClose", PVP_THROUGH_QUEUE = "PVPTHROUGHQUEUE", ALARM_CLOCK_WARNING_3 = "AlarmClockWarning3",
}, { __index = function() return "igMainMenuOption" end }))
-- PlaySound in 3.3.5 takes a name; modern addons pass numbers. Numbers become the nearest known name.
do
	local real = PlaySound
	local byId = { [850] = "igMainMenuOpen", [851] = "igMainMenuClose", [852] = "igMainMenuOption", [856] = "igMainMenuOptionCheckBoxOn",
		[857] = "igMainMenuOptionCheckBoxOff", [1115] = "UChatScrollButton", [8959] = "RaidWarning", [8960] = "ReadyCheck", [3175] = "TellMessage" }
	PlaySound = function(sound, channel, ...)
		if type(sound) == "number" then sound = byId[sound] or "igMainMenuOption" end
		if channel == "Master" or channel == "SFX" or channel == nil then return real(sound) end
		return real(sound, channel, ...)
	end
end

-- Mixins
def("Mixin", function(object, ...)
	for i = 1, select("#", ...) do
		local mixin = select(i, ...)
		if mixin then for k, v in pairs(mixin) do object[k] = v end end
	end
	return object
end)
def("CreateFromMixins", function(...) return Mixin({}, ...) end)
def("CreateAndInitFromMixin", function(mixin, ...) local o = CreateFromMixins(mixin) if o.Init then o:Init(...) end return o end)

-- Colours
ColorMixin = ColorMixin or {}
function ColorMixin:OnLoad(r, g, b, a) self:SetRGBA(r, g, b, a) end
function ColorMixin:SetRGBA(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end
function ColorMixin:SetRGB(r, g, b) self:SetRGBA(r, g, b, nil) end
function ColorMixin:GetRGB() return self.r, self.g, self.b end
function ColorMixin:GetRGBA() return self.r, self.g, self.b, self.a or 1 end
function ColorMixin:GetRGBAsBytes() return self.r * 255, self.g * 255, self.b * 255 end
function ColorMixin:IsEqualTo(o) return self.r == o.r and self.g == o.g and self.b == o.b and (self.a or 1) == (o.a or 1) end
function ColorMixin:GenerateHexColor() return string.format("ff%02x%02x%02x", self.r * 255, self.g * 255, self.b * 255) end
function ColorMixin:GenerateHexColorMarkup() return "|c" .. self:GenerateHexColor() end
function ColorMixin:WrapTextInColorCode(text) return "|c" .. self:GenerateHexColor() .. tostring(text) .. "|r" end
function ColorMixin:GetHSV() return 0, 0, 0 end
def("CreateColor", function(r, g, b, a) local c = CreateFromMixins(ColorMixin) c:OnLoad(r, g, b, a) return c end)
def("CreateColorFromHexString", function(hex)
	local a, r, g, b = hex:match("^(%x%x)(%x%x)(%x%x)(%x%x)$")
	if not a then return nil end
	return CreateColor(tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, tonumber(a, 16) / 255)
end)
local function upgrade(c) if c and not c.WrapTextInColorCode then Mixin(c, ColorMixin) end end
for _, c in pairs(RAID_CLASS_COLORS) do upgrade(c) c.colorStr = c.colorStr or ColorMixin.GenerateHexColor(c) end
for _, name in ipairs({ "NORMAL_FONT_COLOR", "HIGHLIGHT_FONT_COLOR", "RED_FONT_COLOR", "GREEN_FONT_COLOR", "GRAY_FONT_COLOR", "YELLOW_FONT_COLOR", "LIGHTYELLOW_FONT_COLOR", "ORANGE_FONT_COLOR", "PASSIVE_SPELL_FONT_COLOR", "BATTLENET_FONT_COLOR" }) do upgrade(_G[name]) end
def("WHITE_FONT_COLOR", CreateColor(1, 1, 1))
def("DISABLED_FONT_COLOR", CreateColor(0.5, 0.5, 0.5))
def("DARKGRAY_COLOR", CreateColor(0.4, 0.4, 0.4))
def("LIGHTGRAY_FONT_COLOR", CreateColor(0.6, 0.6, 0.6))
def("BLUE_FONT_COLOR", CreateColor(0, 0.749, 0.953))
def("EPIC_PURPLE_COLOR", CreateColor(0.64, 0.21, 0.93))
def("ITEM_QUALITY_COLORS", ITEM_QUALITY_COLORS)
for _, c in pairs(ITEM_QUALITY_COLORS or {}) do upgrade(c) c.color = c.color or c end
def("GetClassColor", function(class) local c = RAID_CLASS_COLORS[class] if c then return c.r, c.g, c.b, c.colorStr end return 1, 1, 1, "ffffffff" end)
def("GetClassColorObj", function(class) return RAID_CLASS_COLORS[class] end)

-- Vectors
Vector2DMixin = Vector2DMixin or {}
function Vector2DMixin:GetXY() return self.x, self.y end
function Vector2DMixin:SetXY(x, y) self.x, self.y = x, y end
function Vector2DMixin:Add(o) self.x, self.y = self.x + o.x, self.y + o.y end
function Vector2DMixin:Subtract(o) self.x, self.y = self.x - o.x, self.y - o.y end
function Vector2DMixin:ScaleBy(s) self.x, self.y = self.x * s, self.y * s end
function Vector2DMixin:GetLength() return math.sqrt(self.x * self.x + self.y * self.y) end
function Vector2DMixin:Clone() return CreateVector2D(self.x, self.y) end
def("CreateVector2D", function(x, y) local v = CreateFromMixins(Vector2DMixin) v:SetXY(x, y) return v end)

-- C_Timer
if not C_Timer then
	C_Timer = {}
	local timers, frame = {}, CreateFrame("Frame")
	local function add(t) timers[#timers + 1] = t frame:Show() end
	frame:Hide()
	frame:SetScript("OnUpdate", function(self, elapsed)
		local now = GetTime()
		local i = 1
		while i <= #timers do
			local t = timers[i]
			if t.cancelled then
				table.remove(timers, i)
			elseif now >= t.due then
				local ok, err = pcall(t.callback, t)
				if not ok then geterrorhandler()(err) end
				if t.iterations and not t.cancelled then
					t.iterations = t.iterations - 1
					if t.iterations == 0 then t.cancelled = true end
				end
				if t.repeating and not t.cancelled then t.due = now + t.duration i = i + 1 else table.remove(timers, i) end
			else
				i = i + 1
			end
		end
		if #timers == 0 then self:Hide() end
	end)
	local Handle = {}
	Handle.__index = Handle
	function Handle:Cancel() self.cancelled = true end
	function Handle:IsCancelled() return self.cancelled == true end
	function C_Timer.After(duration, callback) add({ due = GetTime() + (duration or 0), callback = function() callback() end }) end
	function C_Timer.NewTimer(duration, callback)
		local t = setmetatable({ due = GetTime() + duration, duration = duration, callback = callback }, Handle)
		add(t) return t
	end
	function C_Timer.NewTicker(duration, callback, iterations)
		local t = setmetatable({ due = GetTime() + duration, duration = duration, callback = callback, repeating = true, iterations = iterations }, Handle)
		add(t) return t
	end
	TickerMetatable = Handle
end

-- Scrolling multi-line edit boxes (newer InputScrollFrameTemplate script)
def("InputScrollFrame_OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, self:GetParent()) end)

-- Mouse focus list (newer clients can have several)
def("GetMouseFoci", function() local f = GetMouseFocus() return f and { f } or {} end)
def("LE_PARTY_CATEGORY_HOME", 1)
def("LE_PARTY_CATEGORY_INSTANCE", 2)
def("Constants", {})
def("GetSpellDescription", function(spell) return C_Spell.GetSpellDescription(spell) end)
def("StaticPopup_ForEachShownDialog", function(fn)
	for i = 1, STATICPOPUP_NUMDIALOGS or 4 do
		local d = _G["StaticPopup" .. i]
		if d and d:IsShown() then fn(d, d.which) end
	end
end)

-- EventUtil
EventUtil = EventUtil or {}
local function onEvent(events, fn, once)
	local f = CreateFrame("Frame")
	for _, e in ipairs(events) do f:RegisterEvent(e) end
	f:SetScript("OnEvent", function(self, ...) if once then self:UnregisterAllEvents() end fn(...) end)
	return f
end
EventUtil.ContinueOnAddOnLoaded = EventUtil.ContinueOnAddOnLoaded or function(addon, fn)
	if IsAddOnLoaded(addon) then fn() return end
	local f = CreateFrame("Frame")
	f:RegisterEvent("ADDON_LOADED")
	f:SetScript("OnEvent", function(self, _, name) if name == addon then self:UnregisterAllEvents() fn() end end)
end
EventUtil.ContinueOnPlayerLogin = EventUtil.ContinueOnPlayerLogin or function(fn)
	if IsLoggedIn() then fn() else onEvent({ "PLAYER_LOGIN" }, fn, true) end
end
EventUtil.RegisterOnceFrameEventAndCallback = EventUtil.RegisterOnceFrameEventAndCallback or function(event, fn) onEvent({ event }, fn, true) end
EventUtil.RegisterFrameEventAndCallback = EventUtil.RegisterFrameEventAndCallback or function(event, fn) onEvent({ event }, fn, false) end
EventUtil.AreVariablesLoaded = EventUtil.AreVariablesLoaded or function() return IsLoggedIn() end

-- PixelUtil: the 3.3.5 client places at the given size already
PixelUtil = PixelUtil or {}
PixelUtil.SetPoint = PixelUtil.SetPoint or function(r, ...) r:SetPoint(...) end
PixelUtil.SetSize = PixelUtil.SetSize or function(r, w, h) r:SetWidth(w) r:SetHeight(h) end
PixelUtil.SetWidth = PixelUtil.SetWidth or function(r, w) r:SetWidth(w) end
PixelUtil.SetHeight = PixelUtil.SetHeight or function(r, h) r:SetHeight(h) end
PixelUtil.GetPixelToUIUnitFactor = PixelUtil.GetPixelToUIUnitFactor or function() local _, h = GetPhysicalScreenSize() return 768 / h end
PixelUtil.GetNearestPixelSize = PixelUtil.GetNearestPixelSize or function(v) return v end

-- ItemUtil
ItemUtil = ItemUtil or {}
ItemUtil.GetItemHyperlink = ItemUtil.GetItemHyperlink or function(id) return select(2, GetItemInfo(id)) end

-- Tree data provider: a flat list whose nodes can take children (enough for addon lists)
if not CreateTreeDataProvider then
	local Node = {}
	Node.__index = Node
	function Node:Insert(data) local n = setmetatable({ data = data, nodes = {}, parent = self }, Node) self.nodes[#self.nodes + 1] = n return n end
	function Node:GetData() return self.data end
	function Node:GetNodes() return self.nodes end
	function Node:SetCollapsed(c) self.collapsed = c end
	function Node:IsCollapsed() return self.collapsed end
	function Node:Flush() wipe(self.nodes) end
	function CreateTreeDataProvider()
		local root = setmetatable({ nodes = {} }, Node)
		root.GetRootNode = function() return root end
		root.Enumerate = function()
			local flat = {}
			local function walk(n) for _, c in ipairs(n.nodes) do flat[#flat + 1] = c if not c.collapsed then walk(c) end end end
			walk(root)
			return ipairs(flat)
		end
		root.GetSize = function() local n = 0 for _ in root.Enumerate() do n = n + 1 end return n end
		return root
	end
end
def("TaxiRequestEarlyLanding", function() end) -- no early landing on 3.3.5 (kept so addons can hook it)
def("ToggleWorldMap", function() ToggleFrame(WorldMapFrame) end)
-- Flight route hops: the node index at a hop of the route to a node, found from the 3.3.5 hop coordinates
def("TaxiGetNodeSlot", function(node, slot, isDest)
	local x, y
	if slot <= 1 then x, y = TaxiGetSrcX(node, 1), TaxiGetSrcY(node, 1)
	else x, y = TaxiGetDestX(node, slot - 1), TaxiGetDestY(node, slot - 1) end
	if not x then return node end
	local best, dist = node, math.huge
	for i = 1, NumTaxiNodes() do
		local nx, ny = TaxiNodePosition(i)
		local d = (nx - x) ^ 2 + (ny - y) ^ 2
		if d < dist then best, dist = i, d end
	end
	return best
end)
-- Model zoom and panning (newer Model functions; 3.3.5 models move by camera position)
def("Model_OnMouseWheel", function(self, delta)
	self.zoomLevel = Clamp((self.zoomLevel or 0) + delta * 0.15, 0, 1)
	local _, y, z = self:GetPosition()
	self:SetPosition(self.zoomLevel * 2, y or 0, z or 0)
end)
def("Model_StartPanning", function() end)
def("Model_StopPanning", function() end)
