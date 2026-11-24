-- !TemucraftCompat: UI error log.
-- The game hides Lua errors unless "Display Lua errors" is on, so a broken frame often just looks empty. This keeps
-- every UI error (and every blocked action) in TemucraftErrorLog, a saved variable the launcher reads for
-- "Copy diagnostics". It is saved when you log out or /reload, so a game crash loses what the last session caught.
--   /tcerrors          opens the log window (the whole log as plain text: Ctrl+A, Ctrl+C to copy it)
--   /tcerrors list     prints the newest ones in the chat
--   /tcerrors save     writes the log to the saved variables file now (reloads the UI)
--   /tcerrors clear    empties the log
--   /tcerrors quiet    turns the chat notice on or off
-- With BugGrabber (or BugSack) installed, errors are read from it: it keeps the error handler to itself.
local MAX = 60          -- different errors kept (the oldest goes first)
local STACK_LINES = 8
local STACK_CHARS = 1500

TemucraftErrorLog = TemucraftErrorLog or {}
local log
local seen = {}         -- message -> true, this session: the chat notice comes once per error
local busy = false
local window            -- the log window, made the first time it opens
local Refresh           -- fills the window again (set when the window is made)

local function Short(text)
	text = tostring(text or "")
	text = text:gsub("Interface\\AddOns\\", ""):gsub("Interface\\FrameXML\\", "FrameXML\\")
	return text
end

local function Errors()
	if not log then
		TemucraftErrorLog.errors = TemucraftErrorLog.errors or {}
		log = TemucraftErrorLog
	end
	return log.errors
end

local function Record(kind, message, stack)
	local errors = Errors()
	message = Short(message)
	local now = date("%Y-%m-%d %H:%M:%S")
	for i, e in ipairs(errors) do
		if e.msg == message then
			e.count = (e.count or 1) + 1
			e.last = now
			if stack and not e.stack then e.stack = Short(stack):sub(1, STACK_CHARS) end
			table.remove(errors, i)
			table.insert(errors, e)   -- newest at the end
			if Refresh then Refresh() end
			return e, false
		end
	end
	local e = { kind = kind, msg = message, stack = stack and Short(stack):sub(1, STACK_CHARS) or nil, count = 1, first = now, last = now }
	table.insert(errors, e)
	while #errors > MAX do table.remove(errors, 1) end
	if Refresh then Refresh() end
	return e, true
end
TemucraftCompat = TemucraftCompat or {}
TemucraftCompat.RecordError = Record

local function Notice(e)
	if seen[e.msg] or (TemucraftErrorLog.quiet) then return end
	seen[e.msg] = true
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5050Temucraft:|r UI error logged: " .. e.msg:sub(1, 120) .. " |cff999999(/tcerrors)|r")
	end
end

-- the log as plain text, newest last. kind: nil for all, "error" or "blocked". find: only entries with this text.
local function AsText(kind, find)
	local out = {}
	local errors = Errors()
	find = find and find ~= "" and find:lower() or nil
	for i, e in ipairs(errors) do
		local whole = e.msg .. "\n" .. (e.stack or "")
		if (not kind or e.kind == kind) and (not find or whole:lower():find(find, 1, true)) then
			out[#out + 1] = ("#%d [%s] x%d, first %s, last %s"):format(i, e.kind or "error", e.count or 1, e.first or "?", e.last or "?")
			out[#out + 1] = e.msg
			if e.stack and e.stack ~= "" then out[#out + 1] = e.stack end
			out[#out + 1] = ""
		end
	end
	if #out == 0 then return "No UI errors logged." end
	local _, build = GetBuildInfo()
	table.insert(out, 1, ("Temucraft UI error log, %d entries, written %s (client build %s)\n"):format(#errors, date("%Y-%m-%d %H:%M:%S"), tostring(build)))
	return table.concat(out, "\n")
end
TemucraftCompat.ErrorLogText = AsText

local function Stack()
	local s = debugstack and debugstack(4, STACK_LINES, 0) or nil
	return s
end

local function Handler(previous)
	return function(message, ...)
		if not busy then
			busy = true
			local ok, e = pcall(Record, "error", message, Stack())
			if ok and e then pcall(Notice, e) end
			busy = false
		end
		if previous then return previous(message, ...) end
	end
end

-- BugGrabber makes seterrorhandler do nothing, so errors are read from it instead. Its error text holds the
-- message, then the stack and the locals.
local hookedBugGrabber = false
local function FromBugGrabber(errorObject)
	if busy or type(errorObject) ~= "table" then return end
	if errorObject.type == "event" then return end   -- blocked actions come from the events below
	local text = errorObject.message
	if type(text) == "table" then text = text[1] end
	if type(text) ~= "string" then return end
	text = text:gsub("|r", ""):gsub("|c%x%x%x%x%x%x%x%x", "")
	local message, rest = text:match("^([^\n]*)\n?(.*)$")
	rest = (rest or ""):gsub("\nLocals:.*$", "")
	busy = true
	local ok, e = pcall(Record, "error", message or text, rest)
	if ok and e then pcall(Notice, e) end
	busy = false
end
local function HookBugGrabber()
	if hookedBugGrabber then return true end
	local bg = rawget(_G, "BugGrabber")
	if type(bg) ~= "table" then return false end
	if type(bg.StoreError) == "function" then
		hooksecurefunc(bg, "StoreError", function(_, errorObject) FromBugGrabber(errorObject) end)
		hookedBugGrabber = true
	elseif type(bg.RegisterCallback) == "function" then
		bg.RegisterCallback(TemucraftCompat, "BugGrabber_BugGrabbed", function(_, errorObject) FromBugGrabber(errorObject) end)
		hookedBugGrabber = true
	end
	return hookedBugGrabber
end

-- catch errors from now on (other addons load after this one); at login, wrap whatever handler is set by then
-- (other addons set their own), so both keep working
seterrorhandler(Handler(geterrorhandler()))
HookBugGrabber()

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterEvent("MACRO_ACTION_BLOCKED")
frame:RegisterEvent("MACRO_ACTION_FORBIDDEN")
frame:SetScript("OnEvent", function(_, event, who, what)
	if event == "ADDON_LOADED" then
		HookBugGrabber()
		return
	elseif event == "PLAYER_LOGIN" then
		if not HookBugGrabber() then seterrorhandler(Handler(geterrorhandler())) end
		return
	elseif event == "PLAYER_LOGOUT" then
		-- a plain text copy next to the entries, for the launcher and for reading the file by hand
		TemucraftErrorLog.text = AsText()
		TemucraftErrorLog.textWritten = date("%Y-%m-%d %H:%M:%S")
		return
	end
	-- a blocked action is silent: the button just does nothing
	local e = Record("blocked", ("%s: %s tried %s"):format(event, tostring(who or "?"), tostring(what or "?")), nil)
	if e then Notice(e) end
end)

local function Clear()
	TemucraftErrorLog.errors = {}
	TemucraftErrorLog.text = nil
	log = nil
	wipe(seen)
	if Refresh then Refresh() end
	print("|cffffcc00Temucraft:|r UI error log cleared.")
end

local function Save()
	if InCombatLockdown() then
		print("|cffffcc00Temucraft:|r the log is saved after combat (the UI reloads).")
		local f = CreateFrame("Frame")
		f:RegisterEvent("PLAYER_REGEN_ENABLED")
		f:SetScript("OnEvent", function(self) self:UnregisterAllEvents() ReloadUI() end)
		return
	end
	TemucraftErrorLog.text = AsText()
	TemucraftErrorLog.textWritten = date("%Y-%m-%d %H:%M:%S")
	ReloadUI()   -- saved variables are written to the file on reload
end

-- ------------------------------------------------------------------------------------------------ window
local function Button(parent, text, width)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetWidth(width or 90)
	b:SetHeight(22)
	b:SetText(text)
	return b
end

local function MakeWindow()
	local f = CreateFrame("Frame", "TemucraftErrorLogFrame", UIParent)
	f:SetWidth(720)
	f:SetHeight(480)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
	f:Hide()
	tinsert(UISpecialFrames, "TemucraftErrorLogFrame")   -- Escape closes it

	local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOP", 0, -16)
	title:SetText("Temucraft UI error log")
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)

	-- filter: which kind, and a search box
	f.kind = nil
	local kinds = { { nil, "All" }, { "error", "Errors" }, { "blocked", "Blocked" } }
	local kindButtons = {}
	local x = 20
	for _, k in ipairs(kinds) do
		local b = Button(f, k[2], 80)
		b:SetPoint("TOPLEFT", x, -40)
		b.kind = k[1]
		b:SetScript("OnClick", function(self) f.kind = self.kind Refresh() end)
		kindButtons[#kindButtons + 1] = b
		x = x + 84
	end
	local searchLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	searchLabel:SetPoint("TOPLEFT", x + 10, -46)
	searchLabel:SetText("Filter:")
	local search = CreateFrame("EditBox", "TemucraftErrorLogSearch", f, "InputBoxTemplate")
	search:SetAutoFocus(false)
	search:SetWidth(200)
	search:SetHeight(20)
	search:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
	search:SetScript("OnTextChanged", function() Refresh() end)
	search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	local count = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	count:SetPoint("TOPRIGHT", -24, -46)

	-- the log: one edit box in a scroll frame, so the whole text can be selected and copied
	local scroll = CreateFrame("ScrollFrame", "TemucraftErrorLogScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 22, -72)
	scroll:SetPoint("BOTTOMRIGHT", -40, 48)
	local bg = CreateFrame("Frame", nil, f)
	bg:SetPoint("TOPLEFT", scroll, -6, 6)
	bg:SetPoint("BOTTOMRIGHT", scroll, 28, -6)
	bg:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
	bg:SetBackdropColor(0, 0, 0, 0.8)
	bg:SetFrameLevel(scroll:GetFrameLevel() - 1)

	local edit = CreateFrame("EditBox", "TemucraftErrorLogText", scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(640)
	edit:SetHeight(400)
	edit:SetMaxLetters(0)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	-- the box is for reading and copying: typing puts the log back
	edit:SetScript("OnTextChanged", function(self, userInput)
		if self.logText and self:GetText() ~= self.logText then self:SetText(self.logText) self:HighlightText() end
	end)
	edit:SetScript("OnCursorChanged", function(self, x, y, w, h) ScrollingEdit_OnCursorChanged(self, x, y, w, h) end)
	edit:SetScript("OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, scroll) end)
	scroll:SetScrollChild(edit)
	scroll:EnableMouse(true)
	scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
	f.edit = edit

	-- buttons along the bottom
	local selectAll = Button(f, "Select all", 100)
	selectAll:SetPoint("BOTTOMLEFT", 20, 16)
	selectAll:SetScript("OnClick", function() edit:SetFocus() edit:HighlightText() end)
	local hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)
	hint:SetText("then Ctrl+C to copy")
	local closeBottom = Button(f, "Close", 90)
	closeBottom:SetPoint("BOTTOMRIGHT", -20, 16)
	closeBottom:SetScript("OnClick", function() f:Hide() end)
	local save = Button(f, "Save to file", 110)
	save:SetPoint("RIGHT", closeBottom, "LEFT", -6, 0)
	save:SetScript("OnClick", Save)
	save:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Save to file")
		GameTooltip:AddLine("Reloads the UI, which writes the log to\nWTF\\Account\\<account>\\SavedVariables\\!TemucraftCompat.lua.\nThe launcher's Copy diagnostics reads it from there.", 1, 1, 1)
		GameTooltip:Show()
	end)
	save:SetScript("OnLeave", function() GameTooltip:Hide() end)
	local clear = Button(f, "Clear", 90)
	clear:SetPoint("RIGHT", save, "LEFT", -6, 0)
	clear:SetScript("OnClick", Clear)

	Refresh = function()
		if not f:IsShown() then return end
		local text = AsText(f.kind, search:GetText())
		edit.logText = text
		edit:SetText(text)
		edit:SetCursorPosition(0)
		local errors = Errors()
		local n = 0
		for _, e in ipairs(errors) do if not f.kind or e.kind == f.kind then n = n + 1 end end
		count:SetText(("%d of %d entries"):format(n, #errors))
		for _, b in ipairs(kindButtons) do
			if b.kind == f.kind then b:LockHighlight() else b:UnlockHighlight() end
		end
	end
	f:SetScript("OnShow", function() Refresh() end)
	return f
end

local function Open()
	window = window or MakeWindow()
	window:Show()
	window.edit:SetFocus()
	window.edit:HighlightText()
end
TemucraftCompat.OpenErrorLog = Open

SLASH_TEMUCRAFTERRORS1 = "/tcerrors"
SlashCmdList.TEMUCRAFTERRORS = function(arg)
	arg = (arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local list = Errors()
	if arg == "clear" then
		Clear()
		return
	elseif arg == "quiet" then
		TemucraftErrorLog.quiet = not TemucraftErrorLog.quiet
		print("|cffffcc00Temucraft:|r chat notice for UI errors " .. (TemucraftErrorLog.quiet and "off" or "on") .. ".")
		return
	elseif arg == "save" then
		Save()
		return
	elseif arg == "list" then
		if #list == 0 then print("|cffffcc00Temucraft:|r no UI errors logged.") return end
		print(("|cffffcc00Temucraft:|r %d UI errors logged, newest last:"):format(#list))
		for i = math.max(1, #list - 4), #list do
			local e = list[i]
			print(("|cffff5050%d.|r %s |cff999999(x%d, %s)|r"):format(i, e.msg, e.count or 1, e.last or "?"))
		end
		print("|cffffcc00Temucraft:|r /tcerrors opens the whole log, /tcerrors save writes it to the file.")
		return
	end
	Open()
end
