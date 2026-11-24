if TemucraftCompat and TemucraftCompat.UnitEnv then setfenv(1, TemucraftCompat.UnitEnv) end -- Temucraft: nameplate unit tokens
-- Newer menus (MenuUtil, Menu, dropdown buttons) drawn with the 3.3.5 UIDropDownMenu.
local Description = {}
Description.__index = Description
local function newDesc(kind, text) return setmetatable({ kind = kind, text = text, children = {}, enabled = true }, Description) end
function Description:Add(d, index) if index then table.insert(self.children, index, d) else self.children[#self.children + 1] = d end return d end
function Description:Insert(d, index) return self:Add(d, index) end
function Description:CreateButton(text, cb, data) local d = self:Add(newDesc("button", text)) d.callback, d.data = cb, data return d end
function Description:CreateRadio(text, isSel, setSel, data) local d = self:Add(newDesc("radio", text)) d.isSelected, d.setSelected, d.data = isSel, setSel, data return d end
function Description:CreateCheckbox(text, isSel, setSel, data) local d = self:Add(newDesc("check", text)) d.isSelected, d.setSelected, d.data = isSel, setSel, data return d end
function Description:CreateTitle(text) return self:Add(newDesc("title", text)) end
function Description:CreateDivider() return self:Add(newDesc("divider", "")) end
function Description:CreateSpacer() return self:Add(newDesc("divider", "")) end
function Description:CreateColorSwatch(text, cb, color) local d = self:Add(newDesc("button", text)) d.callback = cb return d end
function Description:SetEnabled(on) self.enabled = on ~= false and (type(on) ~= "function" or on()) end
function Description:SetTooltip(fn) self.tooltip = fn end
function Description:SetScrollMode() end
function Description:SetTag() end
function Description:SetGridMode() end
function Description:AddInitializer() end
function Description:SetResponder() end
function Description:SetResponse() end
function Description:SetTitleAndTextTooltip(title, text) self.tooltipTitle, self.tooltipText = title, text end
function Description:GetData() return self.data end
function Description:EnumerateElementDescriptions() local i = 0 return function() i = i + 1 return self.children[i] end end
function Description:SetData(d) self.data = d end
function Description:SetOnEnter() end
function Description:SetOnLeave() end
function Description:SetMinimumWidth() end
function Description:SetFinalInitializer() end
function Description:SetCanSelect() end
function Description:SetIsSelected(fn) self.isSelected = fn end
function Description:SetSelectionIgnored() end
function Description:SetRadio() end
function Description:QueueTitle(t) return self:CreateTitle(t) end
function Description:QueueDivider() return self:CreateDivider() end
function Description:ClearQueuedDescriptions() end

local holder   -- the dropdown the menus are drawn in, made the first time a menu opens
local openOwner, openRoot

local function buildLevel(desc, level)
	for _, d in ipairs(desc.children) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = d.text
		info.disabled = not d.enabled
		if d.kind == "title" then
			info.isTitle, info.notCheckable = true, true
		elseif d.kind == "divider" then
			info.text, info.disabled, info.notCheckable = "", true, true
		elseif d.kind == "radio" or d.kind == "check" then
			info.checked = d.isSelected and d.isSelected(d.data) or false
			info.keepShownOnClick = d.kind == "check"
			info.func = function()
				if d.setSelected then d.setSelected(d.data, d) end
				if openOwner and openOwner.SignalUpdate then openOwner:SignalUpdate() end
			end
		else
			info.notCheckable = true
			info.func = function() if d.callback then d.callback(d.data, { buttonName = "LeftButton" }, d) end end
		end
		if #d.children > 0 then info.hasArrow, info.menuList = true, d end
		if d.tooltipTitle then info.tooltipTitle, info.tooltipText = d.tooltipTitle, d.tooltipText end
		UIDropDownMenu_AddButton(info, level)
	end
end
-- Made and set up only when an addon opens a menu: setting up a dropdown at load writes the dropdown globals
-- (UIDROPDOWNMENU_MENU_LEVEL and others) from addon code, and Blizzard's target and party frames read them.
local function Holder()
	if holder then return holder end
	holder = CreateFrame("Frame", "TemucraftCompatMenuDropDown", UIParent, "UIDropDownMenuTemplate")
	UIDropDownMenu_Initialize(holder, function(self, level, menuList)
		local desc = level == 1 and openRoot or menuList
		if desc then buildLevel(desc, level) end
	end, "MENU")
	return holder
end

local function open(owner, generator, anchorToCursor)
	local root = newDesc("root")
	generator(owner, root)
	openOwner, openRoot = owner, root
	ToggleDropDownMenu(1, nil, Holder(), anchorToCursor and "cursor" or owner, anchorToCursor and 0 or 0, 0)
	if owner then owner.menu = DropDownList1 end
	return DropDownList1
end
local menuFrame = DropDownList1
menuFrame.ReinitializeAll = function() if openRoot then CloseDropDownMenus() ToggleDropDownMenu(1, nil, Holder(), openOwner, 0, 0) end end
menuFrame:HookScript("OnHide", function()
	local owner = openOwner
	if owner and owner.menu then
		owner.menu = nil
		if owner.TriggerEvent then owner:TriggerEvent("OnMenuClose", owner, menuFrame) end
	end
end)

MenuUtil = MenuUtil or {}
MenuUtil.CreateContextMenu = MenuUtil.CreateContextMenu or function(owner, generator) return open(owner, generator, true) end
MenuUtil.CreateRadio = MenuUtil.CreateRadio or function(text, isSel, setSel, data) local d = newDesc("radio", text) d.isSelected, d.setSelected, d.data = isSel, setSel, data return d end
MenuUtil.CreateCheckbox = MenuUtil.CreateCheckbox or function(text, isSel, setSel, data) local d = newDesc("check", text) d.isSelected, d.setSelected, d.data = isSel, setSel, data return d end
MenuUtil.CreateButton = MenuUtil.CreateButton or function(text, cb, data) local d = newDesc("button", text) d.callback, d.data = cb, data return d end
MenuUtil.CreateRadioMenu = MenuUtil.CreateRadioMenu or function(dropdown, isSel, setSel, ...)
	local items = { ... }
	dropdown:SetupMenu(function(owner, root)
		for _, item in ipairs(items) do root:CreateRadio(item[1], isSel, setSel, item[2]) end
	end)
	dropdown.__radio = { items = items, isSel = isSel }
	dropdown:SignalUpdate()
end
MenuUtil.CreateCheckboxContextMenu = MenuUtil.CreateCheckboxContextMenu or function(owner, isSel, setSel, ...)
	local items = { ... }
	return open(owner, function(_, root) for _, item in ipairs(items) do root:CreateCheckbox(item[1], isSel, setSel, item[2]) end end, true)
end
MenuUtil.HideTooltip = MenuUtil.HideTooltip or function() GameTooltip:Hide() end
MenuUtil.ShowTooltip = MenuUtil.ShowTooltip or function(owner, fn) GameTooltip:SetOwner(owner, "ANCHOR_RIGHT") fn(GameTooltip) GameTooltip:Show() end
MenuUtil.GetElementText = MenuUtil.GetElementText or function(d) return d.text end
Menu = Menu or {}
Menu.ModifyMenu = Menu.ModifyMenu or function() end
Menu.PrintOpenMenuTags = Menu.PrintOpenMenuTags or function() end
Menu.GetManager = Menu.GetManager or function() return { IsAnyMenuOpen = function() return DropDownList1:IsShown() end, CloseMenus = CloseDropDownMenus } end

-- Dropdown buttons (WowStyle1DropdownTemplate)
DropdownButtonMixin = DropdownButtonMixin or { Event = { OnMenuOpen = "OnMenuOpen", OnMenuClose = "OnMenuClose", OnUpdate = "OnUpdate" } }
local D = DropdownButtonMixin
function D:RegisterCallback(event, fn, owner)
	self.__callbacks = self.__callbacks or {}
	self.__callbacks[event] = self.__callbacks[event] or {}
	table.insert(self.__callbacks[event], { fn = fn, owner = owner })
end
function D:UnregisterCallback(event, owner)
	local list = self.__callbacks and self.__callbacks[event]
	if not list then return end
	for i = #list, 1, -1 do if list[i].owner == owner then table.remove(list, i) end end
end
function D:TriggerEvent(event, ...)
	local list = self.__callbacks and self.__callbacks[event]
	if not list then return end
	for _, c in ipairs(list) do
		if c.owner ~= nil then c.fn(c.owner, ...) else c.fn(event, ...) end
	end
end
function D:SetupMenu(generator) self.__generator = generator self:SignalUpdate() end
function D:GenerateMenu() self:SignalUpdate() end
function D:SetDefaultText(t) self.__default = t self:SignalUpdate() end
function D:OverrideText(t) self.__override = t self.Text:SetText(t) end
function D:SetSelectionText() end
function D:SetSelectionTranslator(fn) self.__translator = fn end
function D:IsMenuOpen() return self.menu ~= nil end
function D:CloseMenu() CloseDropDownMenus() end
function D:OpenMenu()
	if not self.__generator then return end
	open(self, self.__generator, false)
	self:TriggerEvent("OnMenuOpen", self)
end
function D:SignalUpdate()
	if self.__override then return end
	local text = self.__default or ""
	if self.__generator then
		local root = newDesc("root")
		self.__generator(self, root)
		for _, d in ipairs(root.children) do
			if (d.kind == "radio" or d.kind == "check") and d.isSelected and d.isSelected(d.data) then text = self.__translator and self.__translator(d) or d.text break end
		end
	end
	self.Text:SetText(text)
end
function D:GetMenuDescription() local root = newDesc("root") if self.__generator then self.__generator(self, root) end return root end
-- Wheel over a closed radio dropdown steps through the choices (newer clients do this)
local function step(self, delta)
	local root = self:GetMenuDescription()
	local radios, cur = {}, nil
	for _, d in ipairs(root.children) do
		if d.kind == "radio" then radios[#radios + 1] = d if d.isSelected and d.isSelected(d.data) then cur = #radios end end
	end
	local nxt = cur and radios[cur + (delta < 0 and 1 or -1)]
	if nxt and nxt.setSelected then nxt.setSelected(nxt.data, nxt) self:SignalUpdate() end
end

function TemucraftCompat.InitDropdownButton(self)
	Mixin(self, D)
	local name = self:GetName()
	self.Left = self:CreateTexture(nil, "BACKGROUND")
	self.Left:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
	self.Left:SetSize(25, 64) self.Left:SetPoint("LEFT", -17, 0) self.Left:SetTexCoord(0, 0.1953125, 0, 1)
	self.Right = self:CreateTexture(nil, "BACKGROUND")
	self.Right:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
	self.Right:SetSize(25, 64) self.Right:SetPoint("RIGHT", 17, 0) self.Right:SetTexCoord(0.8046875, 1, 0, 1)
	self.Middle = self:CreateTexture(nil, "BACKGROUND")
	self.Middle:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
	self.Middle:SetPoint("LEFT", self.Left, "RIGHT") self.Middle:SetPoint("RIGHT", self.Right, "LEFT") self.Middle:SetHeight(64)
	self.Middle:SetTexCoord(0.1953125, 0.8046875, 0, 1)
	self.Text = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	self.Text:SetPoint("LEFT", 6, 0) self.Text:SetPoint("RIGHT", -22, 0) self.Text:SetJustifyH("LEFT")
	self.Arrow = CreateFrame("Button", nil, self)
	self.Arrow:SetSize(22, 22) self.Arrow:SetPoint("RIGHT", 2, 0)
	self.Arrow:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	self.Arrow:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
	self.Arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	self.Arrow:SetScript("OnClick", function() self:Click() end)
	self:SetHeight(26)
	self:RegisterForClicks("LeftButtonUp")
	self:SetScript("OnClick", function(b)
		if b.menu then CloseDropDownMenus() else PlaySound("igMainMenuOptionCheckBoxOn") b:OpenMenu() end
	end)
	self:HookScript("OnMouseWheel", function(b, delta) if not b.menu then step(b, delta) end end)
	self:SetScript("OnHide", function(b) if b.menu then CloseDropDownMenus() end end)
end
