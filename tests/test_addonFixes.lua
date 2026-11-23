-- lua5.1 tests/test_addonFixes.lua (from the repository root)
local dir = arg and arg[1] or "!TemucraftCompat/"
local function ok(c, what) if not c then error("FAIL: " .. what, 2) end print("ok  " .. what) end
TemucraftCompat = {}
local handler, registered, frame
function CreateFrame()
	frame = { RegisterEvent = function(_, e) registered = e end, UnregisterEvent = function() registered = nil end,
		SetScript = function(_, _, fn) handler = fn end }
	return frame
end
local faction = "Alliance"
function UnitFactionGroup() return faction end
dofile(dir .. "AddonFixes.lua")
handler(frame, "ADDON_LOADED", "Bagnon")
ok(registered == "ADDON_LOADED", "waits while Questie is not loaded")
QuestieCompat = setmetatable({ ChrRaces = { Human = 1, Orc = 2, Goblin = 9 } }, { __index = _G })
handler(frame, "ADDON_LOADED", "Questie-335")
local r = QuestieCompat.ChrRaces
ok(registered == nil, "done after Questie loaded")
ok(r.Human == 1 and r.Worgen == 1 and r.Goblin == 2 and r.Nightborne == 10 and r.DarkIronDwarf == 3, "custom races mapped")
ok(r.SomeNewRace == 1, "unknown race: Human for Alliance")
faction = "Horde"
ok(r.SomeNewRace == 2, "unknown race: Orc for Horde")
print("all passed")
