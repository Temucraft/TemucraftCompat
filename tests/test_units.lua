-- standalone test of Units.lua with a small fake client
local dir = arg and arg[1] or "!TemucraftCompat/"
TemucraftCompat = {}
function TemucraftCompat.def(name, value) if _G[name] == nil then _G[name] = value end end
bit = bit or { band = function(a, b) local r, m = 0, 1 while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + m end a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2 end return r end }
local frames = {}
function CreateFrame() local f = { ev = {} } function f:RegisterEvent(e) self.ev[e] = true end function f:SetScript(_, fn) self.fn = fn end frames[#frames + 1] = f return f end
local guids = { target = "0xF130000001", player = "0x01" }
function UnitGUID(u) return guids[u] end
function UnitIsUnit(a, b) return a == b end
-- 3.3.5 shapes
local auras = { HELPFUL = { { "Power Word: Fortitude", "Rank 8", "icon1", 0, "Magic", 1800, 5000, "player", false, false, 48161 } },
	HARMFUL = { { "Sunder Armor", "Rank 7", "icon2", 5, nil, 30, 100, "party1", false, false, 47467 }, { "Rend", "", "icon3", 0, nil, 15, 50, "player", false, false, 47465 } } }
function UnitAura(u, i, filter) local a = auras[filter or "HELPFUL"][i] if a then return unpack(a, 1, 11) end end
function UnitBuff(u, i) return UnitAura(u, i, "HELPFUL") end
function UnitDebuff(u, i) return UnitAura(u, i, "HARMFUL") end
function UnitCastingInfo(u) if u == "target" then return "Shadow Bolt", "Rank 11", "Shadow Bolt", "icon", 1000, 3000, false, 55, true end end
function UnitChannelInfo(u) if u == "target" then return "Drain Life", "Rank 9", "Drain Life", "icon", 1000, 6000, false, false end end
local tank = false
function UnitGroupRolesAssigned(u) return tank, false, not tank end
function GetSpellName(i, book) if i == 1 then return "Fireball", "Rank 1", book end end
function GetSpellLink(i, book) if i == 1 then return "|cff71d5ff|Hspell:133|h[Fireball]|h|r" end end
function GetSpellTexture(i, book) return book end
function GetNumMacroIcons() return 2 end
function GetMacroIconInfo(i) return "Interface\\Icons\\I" .. i end
LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage" }
function GetBuildInfo() return "3.3.5", "12340", "Jun 24 2010" end
dofile(dir .. "Units.lua")
local M = TemucraftCompat.Modern
local function ok(c, what) if not c then error("FAIL: " .. what, 2) end print("ok  " .. what) end

-- combat log in the newer layout
local ev = frames[1]
ok(ev.ev.COMBAT_LOG_EVENT_UNFILTERED, "combat log frame registered")
ev.fn(ev, "COMBAT_LOG_EVENT_UNFILTERED", 123.5, "SPELL_CAST_START", "0xF130000001", "Defias", 0x10a48, "", nil, 0x80000000 + 0x200000, 5143, "Arcane Missiles", 64)
local ts, sub, hide, sg, sn, sf, srf, dg, dn, df, drf, spellId, spellName, school = CombatLogGetCurrentEventInfo()
ok(ts == 123.5 and sub == "SPELL_CAST_START" and hide == false and sg == "0xF130000001" and sn == "Defias" and sf == 0x10a48 and srf == 0, "source fields with hideCaster and raid flags")
ok(dg == "" and df == 0x80200000 and drf == 2 and spellId == 5143 and spellName == "Arcane Missiles" and school == 64, "dest raid flags from 3.3.5 flags, spell fields")
ev.fn(ev, "COMBAT_LOG_EVENT_UNFILTERED", 124, "UNIT_DIED", nil, nil, 0, "0x2", "Wolf", 0)
ok(select("#", CombatLogGetCurrentEventInfo()) == 11 and select(9, CombatLogGetCurrentEventInfo()) == "Wolf", "shorter event clears the old extra fields")

-- newer return orders
local name, icon, count, dtype, dur, exp, src, steal, showPersonal, sid, canApply, boss, byPlayer, showAll, timeMod = M.UnitAura("target", 1, "HARMFUL")
ok(name == "Sunder Armor" and icon == "icon2" and count == 5 and dur == 30 and exp == 100 and src == "party1" and sid == 47467 and byPlayer == false and timeMod == 1, "UnitAura newer order")
ok(select(10, M.UnitBuff("player", 1)) == 48161 and select(13, M.UnitBuff("player", 1)) == true, "UnitBuff spell id at 10, castByPlayer at 13")
ok(M.UnitAura("target", 9) == nil, "no aura: nil")
ev.fn(ev, "UNIT_SPELLCAST_START", "target", "Shadow Bolt", "Rank 11", 55, 47809)
local cn, ctext, ctex, cs, ce, trade, castID, noInt, cspell = M.UnitCastingInfo("target")
ok(cn == "Shadow Bolt" and ctext == "Shadow Bolt" and cs == 1000 and ce == 3000 and castID == 55 and noInt == true and cspell == 47809, "UnitCastingInfo newer order with spell id from the cast event")
local hn, htext, htex, hs, he, htrade, hnoInt, hspell = M.UnitChannelInfo("target")
ok(hn == "Drain Life" and he == 6000 and hnoInt == false and hspell == nil, "UnitChannelInfo newer order")
ok(M.UnitCastingInfo("focus") == nil, "not casting: nil")
ok(M.UnitGroupRolesAssigned("player") == "DAMAGER", "role as text")
tank = true
ok(M.UnitGroupRolesAssigned("player") == "TANK", "tank role")

-- aura slots
local token, s1, s2, s3 = UnitAuraSlots("target", "HARMFUL")
ok(token == nil and s1 == 101 and s2 == 102 and s3 == nil, "debuff slots")
local d = TemucraftCompat.AuraData("target", 102)
ok(d.name == "Rend" and d.isHarmful and d.auraInstanceID == 102 and d.isFromPlayerOrPlayerPet and d.applications == 0, "aura data by slot")
ok(select(10, UnitAuraBySlot("target", 1)) == 48161, "UnitAuraBySlot")

-- other stand-ins
ok(GetClassInfo(8) == "Mage" and select(2, GetClassInfo(8)) == "MAGE" and GetClassInfo(10) == nil, "GetClassInfo")
ok(C_CreatureInfo.GetClassInfo(8).classFile == "MAGE" and C_CreatureInfo.GetRaceInfo(5).clientFileString == "Scourge", "C_CreatureInfo")
local kind, id = GetSpellBookItemInfo(1, "player")
ok(kind == "SPELL" and id == 133 and GetSpellBookItemName(1, "player") == "Fireball" and GetSpellBookItemTexture(1, "player") == "spell", "spell book with 3.3.5 book names")
local icons = GetMacroIcons({})
ok(#icons == 2 and icons[2] == "Interface\\Icons\\I2", "macro icons table")
ok(UnitGetTotalAbsorbs("target") == 0 and UnitIsQuestBoss("target") == false and UnitIsOwnerOrControllerOfUnit("player", "pet"), "unit stand-ins")
ok(select(4, M.GetBuildInfo()) == 30300 and M.GetBuildInfo() == "3.3.5", "GetBuildInfo with interface version")
-- power events
local fired = {}
TemucraftCompat.FireEvent = function(e, u, t) fired[#fired + 1] = e .. ":" .. u .. ":" .. t end
TemucraftCompat.PowerEvent("UNIT_RAGE", "player")
TemucraftCompat.PowerEvent("UNIT_COMBO_POINTS", "vehicle")
TemucraftCompat.PowerEvent("UNIT_MAXMANA", "target")
ok(table.concat(fired, ",") == "UNIT_POWER_UPDATE:player:RAGE,UNIT_POWER_FREQUENT:player:RAGE,UNIT_POWER_UPDATE:player:COMBO_POINTS,UNIT_POWER_FREQUENT:player:COMBO_POINTS,UNIT_MAXPOWER:target:MANA", "power events in the newer form: " .. table.concat(fired, ","))
ok(TemucraftCompat.customEvents.UNIT_POWER_FREQUENT, "power events are custom events")
print("all passed")
