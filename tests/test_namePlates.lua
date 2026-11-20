-- standalone test of NamePlates.lua with a small fake client
local function newObj(kind, mt)
  local o = setmetatable({ kind = kind, scripts = {}, shown = true, alpha = 1, kids = {}, regions = {} }, mt)
  return o
end
local Methods = {}
local function methods(kind)
  if Methods[kind] then return Methods[kind] end
  local m = {}
  function m:GetObjectType() return self.kind end
  function m:GetName() return self.name end
  function m:SetScript(s, f) self.scripts[s] = f end
  function m:GetScript(s) return self.scripts[s] end
  function m:HookScript(s, f) local old = self.scripts[s]; self.scripts[s] = function(...) if old then old(...) end f(...) end end
  function m:IsShown() return self.shown end
  function m:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
  function m:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
  function m:GetAlpha() return self.alpha end
  function m:GetRegions() return unpack(self.regions) end
  function m:GetChildren() return unpack(self.kids) end
  function m:GetNumChildren() return #self.kids end
  function m:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
  function m:UnregisterEvent(e) if self.events then self.events[e] = nil end end
  function m:UnregisterAllEvents() self.events = {} end
  function m:IsEventRegistered(e) return self.events and self.events[e] end
  function m:GetTexture() return self.tex end
  function m:GetText() return self.text end
  function m:GetVertexColor() return unpack(self.color or {1,1,1}) end
  function m:GetTexCoord() return 0,0.25,0,0.25 end
  function m:GetMinMaxValues() return self.min or 0, self.max or 100 end
  function m:GetValue() return self.value or 0 end
  function m:GetStatusBarColor() return unpack(self.color or {1,0,0}) end
  Methods[kind] = { __index = m }
  return Methods[kind]
end
function CreateFrame(kind) return newObj(kind, methods(kind)) end
WorldFrame = CreateFrame("Frame")
RAID_CLASS_COLORS = { MAGE = { r = 0.41, g = 0.80, b = 0.94 } }
LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage" }
local target = nil
function UnitExists(u) return u == "player" or (u == "target" and target ~= nil) end
function UnitGUID(u) if u == "target" and target then return target.guid end if u == "player" then return "0x0000000000000001" end end
function UnitName(u) if u == "target" and target then return target.name end if u == "player" then return "Me" end end
function UnitHealth(u) if u == "target" and target then return target.hp end return 100 end
function UnitHealthMax(u) return 100 end
function UnitLevel(u) if u == "target" then return 99 end return 80 end
function UnitClassification() return "normal" end
function UnitReaction() return 4 end
function UnitIsEnemy() return false end
function UnitCanAttack() return false end
function UnitIsFriend() return true end
function UnitIsPlayer() return true end
function UnitClass() return "Warrior", "WARRIOR" end
function UnitIsUnit(a, b) return a == b end
function UnitThreatSituation() return 3 end
function UnitDetailedThreatSituation() return true, 3, 100, 100, 1 end
TemucraftCompat = { widgetMethods = { Frame = methods("Frame").__index } }

local function newPlate(name, level, color, hp, elite)
  local p = CreateFrame("Frame")
  local t = function(tex) local r = CreateFrame("Texture"); r.tex = tex; r.shown = false; return r end
  local fs = function(text) local r = CreateFrame("FontString"); r.text = text; return r end
  local glow = t("glow"); local border = t("Interface\\Tooltips\\Nameplate-Border"); border.shown = true
  local elt = t("elite"); elt.shown = elite or false
  p.regions = { glow, border, t("cb"), t("cns"), t("icon"), t("hl"), fs(name), fs(tostring(level)), t("boss"), t("raid"), elt }
  local h = CreateFrame("StatusBar"); h.value = hp; h.max = 1000; h.color = color
  p.kids = { h, CreateFrame("StatusBar") }
  return p, h
end

dofile(arg and arg[1] or "NamePlates.lua")
local log = {}
local listener = CreateFrame("Frame")
listener:RegisterEvent("NAME_PLATE_UNIT_ADDED"); listener:RegisterEvent("NAME_PLATE_UNIT_REMOVED"); listener:RegisterEvent("NAME_PLATE_CREATED")
listener:SetScript("OnEvent", function(_, e, u) log[#log + 1] = e .. ":" .. tostring(type(u) == "table" and "plate" or u) end)
local function ok(c, what) if not c then error("FAIL: " .. what, 2) end print("ok  " .. what) end

ok(listener:IsEventRegistered("NAME_PLATE_UNIT_ADDED"), "custom event registers")
local named = CreateFrame("Frame"); named.name = "Other"
local p1, h1 = newPlate("Defias Thug", 12, {1, 0, 0}, 400)
local p2, h2 = newPlate("Jaina", 80, {0.41, 0.80, 0.94}, 1000, true)
WorldFrame.kids = { named, p1, p2 }
TemucraftCompat.namePlates.Scan()
ok(log[1] == "NAME_PLATE_CREATED:plate" and log[2] == "NAME_PLATE_UNIT_ADDED:nameplate1" and log[4] == "NAME_PLATE_UNIT_ADDED:nameplate2", table.concat(log, ","))
ok(UnitName("nameplate1") == "Defias Thug" and UnitLevel("nameplate1") == 12 and UnitHealth("nameplate1") == 400 and UnitHealthMax("nameplate1") == 1000, "plate data")
ok(UnitReaction("nameplate1", "player") == 2 and UnitCanAttack("player", "nameplate1") == true, "hostile from red")
local _, class = UnitClass("nameplate2")
ok(class == "MAGE" and UnitIsPlayer("nameplate2") and UnitClassification("nameplate2") == "elite", "class from colour, elite icon")
ok(UnitGUID("nameplate1") == nil and UnitExists("nameplate1") and not UnitExists("nameplate9"), "no guid until bound; missing token")
ok(C_NamePlate.GetNamePlateForUnit("nameplate2") == p2 and #C_NamePlate.GetNamePlates() == 2, "C_NamePlate")
-- the second plate becomes the target
target = { name = "Jaina", guid = "0x0000000000000042", hp = 1000 }; p1.alpha = 0.5; p2.alpha = 1
listener.scripts.OnEvent = listener.scripts.OnEvent
TemucraftCompat.namePlates.Bind(p2)
ok(UnitGUID("nameplate2") == "0x0000000000000042" and UnitLevel("nameplate2") == 99, "bound plate answers as the target")
ok(C_NamePlate.GetNamePlateForUnit("target") == p2 and UnitIsUnit("nameplate2", "target") and not UnitIsUnit("nameplate1", "target"), "target plate and UnitIsUnit")
ok(UnitThreatSituation("player", "nameplate2") == 3 and UnitThreatSituation("player", "nameplate1") == 0, "threat")
target = nil
ok(UnitLevel("nameplate2") == 80, "target gone: back to the plate's own data")
-- health events
local hits = {}
local hf = CreateFrame("Frame"); hf:RegisterEvent("UNIT_HEALTH"); hf:SetScript("OnEvent", function(_, e, u) hits[#hits + 1] = u end)
h1.value = 300; h1.scripts.OnValueChanged(h1)
ok(hits[1] == "nameplate1" and UnitHealth("nameplate1") == 300, "UNIT_HEALTH for plate tokens")
p1:Hide()
ok(log[#log] == "NAME_PLATE_UNIT_REMOVED:nameplate1" and not UnitExists("nameplate1"), "hidden plate removed")
local p3 = newPlate("Wolf", 5, {1, 1, 0}, 50); WorldFrame.kids[4] = p3; TemucraftCompat.namePlates.Scan()
ok(log[#log] == "NAME_PLATE_UNIT_ADDED:nameplate1" and UnitReaction("nameplate1") == 4, "token reused, neutral from yellow")
ok(UnitName("player") == "Me" and UnitLevel("player") == 80, "other units untouched")
print("all passed")
