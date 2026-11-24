-- Tests for ErrorLog.lua with client stand-ins. Run from the addon folder: lua5.1 ../tests/test_errorLog.lua
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

-- BugGrabber is installed: it keeps the error handler to itself and stores errors with StoreError
local stored = {}
BugGrabber = { StoreError = function(self, e) stored[#stored + 1] = e end }

dofile("ErrorLog.lua")

-- an error grabbed by BugGrabber lands in the log, without its locals
BugGrabber:StoreError({ message = "Hekili\\Core.lua:68: attempt to call method 'GetDefaults' (a nil value)\nCore.lua:68: in function <x>\n\nLocals:|r\nself = <table>", type = "error" })
local log = TemucraftErrorLog.errors
check(#stored == 1, "BugGrabber still stores the error")
check(#log == 1 and log[1].msg:find("GetDefaults") and log[1].kind == "error", "an error from BugGrabber is logged")
check(log[1].stack and log[1].stack:find("in function") and not log[1].stack:find("Locals"), "its stack is kept without the locals")

-- a blocked action from the event
local events
for _, o in ipairs(objects) do if o.events.ADDON_ACTION_BLOCKED then events = o end end
events.scripts.OnEvent(events, "ADDON_ACTION_BLOCKED", "SomeAddon", "TargetFrame:Show()")
check(#log == 2 and log[2].kind == "blocked", "a blocked action is logged")
events.scripts.OnEvent(events, "ADDON_ACTION_BLOCKED", "SomeAddon", "TargetFrame:Show()")
check(#log == 2 and log[2].count == 2, "the same blocked action counts up")

-- plain text, with filters
local all = TemucraftCompat.ErrorLogText()
check(all:find("GetDefaults") and all:find("TargetFrame:Show") and all:find("x2"), "the plain text holds every entry")
local onlyErrors = TemucraftCompat.ErrorLogText("error")
check(onlyErrors:find("GetDefaults") and not onlyErrors:find("TargetFrame"), "filter by kind")
local found = TemucraftCompat.ErrorLogText(nil, "targetframe")
check(found:find("TargetFrame") and not found:find("GetDefaults"), "filter by text")

-- the window: /tcerrors opens it with the whole log in one edit box, selected for copying
SlashCmdList.TEMUCRAFTERRORS("")
local edit = TemucraftErrorLogText
check(TemucraftErrorLogFrame.shown and edit.text:find("GetDefaults") and edit.text:find("TargetFrame"), "/tcerrors opens the window with the whole log")
check(edit.highlighted, "the text is selected (Ctrl+C copies it)")
edit:SetText("typed over")
check(edit.text:find("GetDefaults"), "typing in the box puts the log back")
TemucraftErrorLogSearch:SetText("GetDefaults")
check(edit.text:find("GetDefaults") and not edit.text:find("TargetFrame"), "the filter box narrows the text")

-- save: a plain text copy in the saved variable, then a reload so the file is written
SlashCmdList.TEMUCRAFTERRORS("save")
check(reloaded == 1 and type(TemucraftErrorLog.text) == "string" and TemucraftErrorLog.text:find("GetDefaults"), "/tcerrors save stores the text and reloads")
events.scripts.OnEvent(events, "PLAYER_LOGOUT")
check(TemucraftErrorLog.text:find("TargetFrame"), "logging out stores the text too")

SlashCmdList.TEMUCRAFTERRORS("clear")
check(#TemucraftErrorLog.errors == 0 and TemucraftErrorLog.text == nil, "/tcerrors clear empties the log")
io.write("all passed\n")
