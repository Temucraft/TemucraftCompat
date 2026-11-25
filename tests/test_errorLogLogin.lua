-- Tests for ErrorLog.lua without BugGrabber: login wrapping and the saved variables. Run from the addon folder: lua5.1 ../tests/test_errorLogLogin.lua
local function check(ok, what) if not ok then error("FAILED: " .. what, 2) end io.write("ok  ", what, "\n") end

-- client stand-ins
local objects = {}
local function object(kind, name)
  local o = { kind = kind, scripts = {}, text = "", shown = false, events = {}, highlighted = false }
  local mt = { __index = function(t, k)
    if not k:find("^%u") then return nil end -- fields are nil, methods are stand-ins
    return function(self, ...)
      if k == "SetScript" then local s, f = ... self.scripts[s] = f
      elseif k == "GetScript" then return self.scripts[(...)]
      elseif k == "SetText" then self.text = tostring((...)) if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
      elseif k == "GetText" then return self.text
      elseif k == "Show" then self.shown = true if self.scripts.OnShow then self.scripts.OnShow(self) end
      elseif k == "Hide" then self.shown = false
      elseif k == "IsShown" then return self.shown
      elseif k == "HighlightText" then self.highlighted = true
      elseif k == "GetFrameLevel" then return 2
      elseif k == "CreateFontString" or k == "CreateTexture" then return object("Region")
      elseif k == "RegisterEvent" then self.events[(...)] = true
      end
    end
  end }
  setmetatable(o, mt)
  if name then _G[name] = o end
  objects[#objects + 1] = o
  return o
end
function CreateFrame(kind, name) return object(kind, name) end
UIParent = object("Frame") ChatFontNormal = {} UISpecialFrames = {} SlashCmdList = {}
local printed = {}
function print(...) printed[#printed + 1] = table.concat({ ... }, " ") end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m end }
function date(f) return os.date(f) end
function GetBuildInfo() return "3.3.5", "12340" end
function debugstack() return "Some\\File.lua:1: in main chunk" end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
function InCombatLockdown() return false end
local reloaded = 0
function ReloadUI() reloaded = reloaded + 1 end
function ScrollingEdit_OnCursorChanged() end
function ScrollingEdit_OnUpdate() end
local handler
function geterrorhandler() return handler end
function seterrorhandler(f) handler = f end
function hooksecurefunc(t, name, hook) local orig = t[name] t[name] = function(...) local r = { orig(...) } hook(...) return unpack(r) end end

dofile("ErrorLog.lua")
local events
for _, o in ipairs(objects) do if o.events.ADDON_ACTION_BLOCKED then events = o end end

-- an error before the saved variables load, then the client puts the saved table in place
handler("early error")
local early = TemucraftErrorLog
TemucraftErrorLog = { errors = { { kind = "error", msg = "old error", count = 3, first = "x", last = "x" } } }
events.scripts.OnEvent(events, "ADDON_LOADED", "!TemucraftCompat")
local log = TemucraftErrorLog.errors
check(TemucraftErrorLog ~= early and #log == 2 and log[1].msg == "old error" and log[2].msg == "early error", "early entries are merged into the saved table")
handler("later error")
check(#TemucraftErrorLog.errors == 3 and TemucraftErrorLog.errors[3].msg == "later error", "later errors go to the saved table")

-- at login our handler is still the one set: it is not wrapped again, so an error counts once
local before = handler
events.scripts.OnEvent(events, "PLAYER_LOGIN")
check(handler == before, "our own handler is not wrapped again at login")
handler("later error")
check(TemucraftErrorLog.errors[3].count == 2, "an error after login counts once")

-- another addon wrapped ours: we wrap theirs at login, and the chain still records once
local theirs = 0
local ours = handler
seterrorhandler(function(m, ...) theirs = theirs + 1 return ours(m, ...) end)
events.scripts.OnEvent(events, "PLAYER_LOGIN")
check(handler ~= ours, "a foreign handler is wrapped at login")
handler("chain error")
local e = TemucraftErrorLog.errors[#TemucraftErrorLog.errors]
check(e.msg == "chain error" and e.count == 1 and theirs == 1, "through the chain the error counts once and the other handler runs")
handler("chain error")
check(e.count == 2, "and again")
io.write("all passed\n")
