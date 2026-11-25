# !TemucraftCompat

Newer addon functions for the World of Warcraft 3.3.5a client, so addons written for Classic run with few changes.
Temucraft's ports (Leatrix Plus, Leatrix Maps, Leatrix Sounds, Plater, idTip and more) depend on it.

It only adds what the 3.3.5 client lacks and never replaces a function the client has, with one exception: the
Texture method `SetGradient` is wrapped so it also takes the newer `(orient, colorA, colorB)` form (the 3.3.5 number
form goes to the native method unchanged; no Blizzard Lua calls it, so it taints nothing).
`GetSpecialization` is not defined in `_G` (ported code takes it as a sign of a retail client); code run in
`TemucraftCompat.UnitEnv` gets one that returns nil (no specialization).

| File | What it adds |
|---|---|
| Core.lua | Mixin, colours, vectors, C_Timer, EventUtil, PixelUtil, group functions (IsInGroup...), small helpers |
| Widgets.lua | Widget methods (SetShown, SetColorTexture, SetResizeBounds, RegisterUnitEvent, animation setters, cooldown swipe setters...), BackdropTemplateMixin |
| Pools.lua | ObjectPoolMixin, CreateObjectPool, CreateFramePool, CreateTexturePool, CreateFontStringPool, pool collections |
| Templates.xml | BackdropTemplate, ScrollFrameTemplate, SearchBoxTemplate, WowStyle1DropdownTemplate, WowScrollBoxList, ButtonFrameTemplate, DialogBorderOpaqueTemplate, MicroButtonAlertTemplate, MainHelpPlateButton, ModelWithControlsTemplate, UIWidgetContainer templates |
| Api.lua | C_AddOns, C_Container, C_Item, C_Spell, C_UnitAuras (also by slot / aura instance id), C_QuestLog, C_GossipInfo, C_FriendList, C_CreatureInfo, empty retail namespaces (C_ChallengeMode, C_PvP, C_TaskQuest...), Enum... |
| Units.lua | CombatLogGetCurrentEventInfo (newer layout), UNIT_POWER_UPDATE / UNIT_POWER_FREQUENT / UNIT_MAXPOWER, aura slots, spell book, macro icons, class and race info, unit stand-ins (absorbs, quest boss...), `TemucraftCompat.Modern` |
| UiMapData.lua, Map.lua | C_Map with Classic uiMapIDs (data from Questie's 3.3.5 compatibility layer, GPL-3.0) |
| Menu.lua | MenuUtil, Menu and dropdown buttons, drawn with UIDropDownMenu |
| Settings.lua | Settings categories as Interface Options panels |
| ScrollBox.lua | ScrollBox, DataProvider and ScrollUtil for lists |
| ErrorLog.lua | The UI error log (every Lua error and blocked action, also when BugGrabber is installed), `/tcerrors` |

## UI error log

`/tcerrors` opens a window with the whole log as plain text in one box: Select all, then Ctrl+C copies it. Buttons
filter by kind (All, Errors, Blocked), a filter box finds text, Clear empties the log and Save to file reloads the UI,
which writes the log (also as plain text, in `TemucraftErrorLog.text`) to
`WTF\Account\<account>\SavedVariables\!TemucraftCompat.lua`. The launcher's Copy diagnostics reads it from there.
`/tcerrors list` prints the newest in the chat, `/tcerrors save`, `/tcerrors clear` and `/tcerrors quiet` do the same as
the buttons and turn the chat notice off.

Blizzard functions are never replaced (PlaySound already takes sound kit numbers on 3.3.5): a replaced function
that Blizzard's frames call taints them, and in combat they can no longer show or hide.

Things the 3.3.5 client can't do stay empty on purpose: muting single sounds, mask textures, edit mode, atlases
(except a few drawn from 3.3.5 textures, like the combo points).

## Newer return values

Some functions exist on 3.3.5 but give their values in an older order. They are not replaced; ports use the
versions in `TemucraftCompat.Modern` as locals:

| Function | 3.3.5 | `TemucraftCompat.Modern` |
|---|---|---|
| UnitAura, UnitBuff, UnitDebuff | name, rank, icon, ... spellId 11th | name, icon, count, ... spellId 10th, castByPlayer, ... |
| UnitCastingInfo | name, rank, text, ..., castID, notInterruptible | name, text, texture, ..., castID, notInterruptible, spellId |
| UnitChannelInfo | name, rank, text, ..., notInterruptible | name, text, texture, ..., notInterruptible, spellId |
| UnitGroupRolesAssigned | isTank, isHealer, isDamage | "TANK", "HEALER", "DAMAGER" or "NONE" |
| GetBuildInfo | version, build, date | version, build, date, 30300 |

The spell id of a cast comes from the cast events or the combat log of that caster.

## Nameplates

`NamePlates.lua` gives the 3.3.5 nameplates what newer nameplate addons expect: `C_NamePlate.GetNamePlates` /
`GetNamePlateForUnit`, a `nameplateN` unit token per shown plate, and the `NAME_PLATE_CREATED`,
`NAME_PLATE_UNIT_ADDED` and `NAME_PLATE_UNIT_REMOVED` events (frames can register them). The Unit functions take the
tokens: a plate that is your target, mouseover or focus is answered by that unit; any other plate by what it shows
(name, level, health, reaction and class from its colour, elite/boss icon, threat glow, raid icon). Health changes
fire `UNIT_HEALTH` for the token. Auras, casts and power of other plates are empty: the 3.3.5 plate doesn't show them.

Unit events (casts, auras, threat, faction...) only come for target, focus and mouseover on 3.3.5. They are sent
again with the plate token to frames that want plate events: frames that registered an event for a nameplate token
with `RegisterUnitEvent`, or frames given to `TemucraftCompat.namePlates.WantEvents(frame)`. Cast events are sent
with the newer arguments (unit, castID, spellID). When a plate gets or loses its real unit, `UNIT_AURA` is sent for
it, and the cast start if the unit is casting; `TemucraftCompat.namePlates.RegisterBindCallback(fn)` calls
`fn(plate, token, unit)` then. Range checks (`IsSpellInRange`, `IsItemInRange`, `CheckInteractDistance`,
`UnitInRange`) take the tokens too; a plate without a real unit counts as in range.

The Unit functions that take tokens are not put in `_G`: replacing the client's own Unit functions there taints
Blizzard's secure frames (target, focus and party frames get blocked in combat). They live in
`TemucraftCompat.UnitEnv`, and an addon that wants the tokens starts each Lua file with
`if TemucraftCompat and TemucraftCompat.UnitEnv then setfenv(1, TemucraftCompat.UnitEnv) end`. Reads fall through to
`_G` and writes go to `_G`, so the file works as before. Plater and Leatrix Plus do this.

## Other addons

`AddonFixes.lua`: Questie looks up the player's race by name to read quest race masks and stopped with
"playerRaceId (a nil value)" for Temucraft's own races. Each of them is given the standard race whose quests it
should see (Worgen: Human, Goblin: Orc...), and any race not in the list gets Human or Orc by faction.

## Tests

From the repository root, with plain Lua 5.1 and small stand-ins for the client:

    lua5.1 tests/test_namePlates.lua '!TemucraftCompat/NamePlates.lua'
    lua5.1 tests/test_units.lua '!TemucraftCompat/'
    lua5.1 tests/test_pools.lua '!TemucraftCompat/'

