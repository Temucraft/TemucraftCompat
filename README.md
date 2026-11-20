# !TemucraftCompat

Newer addon functions for the World of Warcraft 3.3.5a client, so addons written for Classic run with few changes.
Temucraft's ports (Leatrix Plus, Leatrix Maps, Leatrix Sounds, Plater, idTip and more) depend on it.

It only adds what the 3.3.5 client lacks and never replaces a function the client has.

| File | What it adds |
|---|---|
| Core.lua | Mixin, colours, vectors, C_Timer, EventUtil, PixelUtil, group functions (IsInGroup...), small helpers |
| Widgets.lua | Widget methods (SetShown, SetColorTexture, SetResizeBounds, RegisterUnitEvent, animation setters...) |
| Templates.xml | BackdropTemplate, ScrollFrameTemplate, SearchBoxTemplate, WowStyle1DropdownTemplate, WowScrollBoxList |
| Api.lua | C_AddOns, C_Container, C_Item, C_Spell, C_UnitAuras, C_QuestLog, C_GossipInfo, C_FriendList, Enum... |
| UiMapData.lua, Map.lua | C_Map with Classic uiMapIDs (data from Questie's 3.3.5 compatibility layer, GPL-3.0) |
| Menu.lua | MenuUtil, Menu and dropdown buttons, drawn with UIDropDownMenu |
| Settings.lua | Settings categories as Interface Options panels |
| ScrollBox.lua | ScrollBox, DataProvider and ScrollUtil for lists |

Things the 3.3.5 client can't do stay empty on purpose: muting single sounds, mask textures, edit mode, atlases.

## Nameplates

`NamePlates.lua` gives the 3.3.5 nameplates what newer nameplate addons expect: `C_NamePlate.GetNamePlates` /
`GetNamePlateForUnit`, a `nameplateN` unit token per shown plate, and the `NAME_PLATE_CREATED`,
`NAME_PLATE_UNIT_ADDED` and `NAME_PLATE_UNIT_REMOVED` events (frames can register them). The Unit functions take the
tokens: a plate that is your target, mouseover or focus is answered by that unit; any other plate by what it shows
(name, level, health, reaction and class from its colour, elite/boss icon, threat glow, raid icon). Health changes
fire `UNIT_HEALTH` for the token. Auras, casts and power of other plates are empty: the 3.3.5 plate doesn't show them.
Test: `lua5.1 tests/test_namePlates.lua` from the `!TemucraftCompat` folder (with `NamePlates.lua` next to it).
