-- !TemucraftCompat: UI error log.
-- The game hides Lua errors unless "Display Lua errors" is on, so a broken frame often just looks empty. This keeps
-- every UI error (and every blocked action) in TemucraftErrorLog, a saved variable the launcher reads for
-- "Copy diagnostics". It is saved when you log out or /reload, so a game crash loses what the last session caught.
-- /tcerrors shows the newest ones, /tcerrors clear empties the log, /tcerrors quiet stops the chat notice.
local MAX = 60          -- different errors kept (the oldest goes first)
local STACK_LINES = 8

TemucraftErrorLog = TemucraftErrorLog or {}
local log
local seen = {}         -- message -> true, this session: the chat notice comes once per error
local busy = false

local function Short(text)
	text = tostring(text or "")
	text = text:gsub("Interface\\AddOns\\", ""):gsub("Interface\\FrameXML\\", "FrameXML\\")
	return text
end

local function Record(kind, message, stack)
	if not log then
		TemucraftErrorLog.errors = TemucraftErrorLog.errors or {}
		log = TemucraftErrorLog
	end
	message = Short(message)
	local now = date("%Y-%m-%d %H:%M:%S")
	for i, e in ipairs(log.errors) do
		if e.msg == message then
			e.count = (e.count or 1) + 1
			e.last = now
			table.remove(log.errors, i)
			table.insert(log.errors, e)   -- newest at the end
			return e, false
		end
	end
	local e = { kind = kind, msg = message, stack = stack and Short(stack) or nil, count = 1, first = now, last = now }
	table.insert(log.errors, e)
	while #log.errors > MAX do table.remove(log.errors, 1) end
	return e, true
end

local function Notice(e)
	if seen[e.msg] or (TemucraftErrorLog.quiet) then return end
	seen[e.msg] = true
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff5050Temucraft:|r UI error logged: " .. e.msg:sub(1, 120) .. " |cff999999(/tcerrors)|r")
	end
end

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

-- catch errors from now on (other addons load after this one); at login, wrap whatever handler is set by then
-- (BugGrabber and others set their own), so both keep working
seterrorhandler(Handler(geterrorhandler()))

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterEvent("MACRO_ACTION_BLOCKED")
frame:RegisterEvent("MACRO_ACTION_FORBIDDEN")
frame:SetScript("OnEvent", function(_, event, who, what)
	if event == "PLAYER_LOGIN" then
		seterrorhandler(Handler(geterrorhandler()))
		return
	end
	-- a blocked action is silent: the button just does nothing
	local e = Record("blocked", ("%s: %s tried %s"):format(event, tostring(who or "?"), tostring(what or "?")), nil)
	if e then Notice(e) end
end)

SLASH_TEMUCRAFTERRORS1 = "/tcerrors"
SlashCmdList.TEMUCRAFTERRORS = function(arg)
	arg = (arg or ""):lower()
	local list = TemucraftErrorLog.errors or {}
	if arg == "clear" then
		TemucraftErrorLog.errors = {}
		log = nil
		wipe(seen)
		print("|cffffcc00Temucraft:|r UI error log cleared.")
		return
	elseif arg == "quiet" then
		TemucraftErrorLog.quiet = not TemucraftErrorLog.quiet
		print("|cffffcc00Temucraft:|r chat notice for UI errors " .. (TemucraftErrorLog.quiet and "off" or "on") .. ".")
		return
	end
	if #list == 0 then print("|cffffcc00Temucraft:|r no UI errors logged.") return end
	print(("|cffffcc00Temucraft:|r %d UI errors logged, newest last:"):format(#list))
	for i = math.max(1, #list - 4), #list do
		local e = list[i]
		print(("|cffff5050%d.|r %s |cff999999(x%d, %s)|r"):format(i, e.msg, e.count or 1, e.last or "?"))
	end
end
