-- A small ScrollBox / DataProvider for lists (newer list widgets), built on a 3.3.5 scroll frame.
local DataProvider = {}
DataProvider.__index = DataProvider
function DataProvider:Insert(...) for i = 1, select("#", ...) do self.items[#self.items + 1] = select(i, ...) end self:Changed() end
function DataProvider:InsertTable(t) for _, v in ipairs(t) do self.items[#self.items + 1] = v end self:Changed() end
function DataProvider:Remove(v) for i = #self.items, 1, -1 do if self.items[i] == v then table.remove(self.items, i) end end self:Changed() end
function DataProvider:Flush() wipe(self.items) self:Changed() end
function DataProvider:GetSize() return #self.items end
function DataProvider:Find(i) return self.items[i] end
function DataProvider:FindIndex(v) for i, x in ipairs(self.items) do if x == v then return i end end end
function DataProvider:FindElementDataByPredicate(p) for _, x in ipairs(self.items) do if p(x) then return x end end end
function DataProvider:FindIndexByPredicate(p) for i, x in ipairs(self.items) do if p(x) then return i, x end end end
function DataProvider:Enumerate() return ipairs(self.items) end
function DataProvider:ForEach(fn) for _, x in ipairs(self.items) do fn(x) end end
function DataProvider:SetSortComparator(fn) self.sort = fn self:Changed() end
function DataProvider:Sort() if self.sort then table.sort(self.items, self.sort) end self:Changed() end
function DataProvider:Changed() if self.box then self.box:Update() end end
function DataProvider:IsEmpty() return #self.items == 0 end
TemucraftCompat.DataProvider = DataProvider
if not CreateDataProvider then
	function CreateDataProvider(t)
		local p = setmetatable({ items = {} }, DataProvider)
		if t then for _, v in ipairs(t) do p.items[#p.items + 1] = v end end
		return p
	end
end
if not CreateIndexRangeDataProvider then
	function CreateIndexRangeDataProvider(n) local t = {} for i = 1, n do t[i] = i end return CreateDataProvider(t) end
end

local View = {}
View.__index = View
function View:SetElementInitializer(template, fn) self.template, self.init = template, fn end
function View:SetElementExtent(h) self.extent = h end
function View:SetPadding(t, b, l, r, s) self.padTop, self.padLeft, self.spacing = t or 0, l or 0, s or 0 end
function View:SetElementFactory(fn) self.factory = fn end
function View:SetElementResetter() end
function View:SetDataProvider(p) self.box:SetDataProvider(p) end
function View:GetDataProvider() return self.box.provider end
if not CreateScrollBoxListLinearView then
	function CreateScrollBoxListLinearView(t, b, l, r, s) local v = setmetatable({ extent = 20 }, View) v:SetPadding(t, b, l, r, s) return v end
end

local Box = {}
function Box:Init(view) self.view = view view.box = self self:Update() end
function Box:SetDataProvider(p) self.provider = p p.box = self self.offset = 0 self:Update() end
function Box:GetDataProvider() return self.provider end
function Box:ForEachFrame(fn) for _, b in ipairs(self.buttons) do if b:IsShown() then fn(b, b.__data) end end end
function Box:EnumerateFrames() local list = {} self:ForEachFrame(function(b) list[#list + 1] = b end) return ipairs(list) end
function Box:FindFrame(data) for _, b in ipairs(self.buttons) do if b:IsShown() and b.__data == data then return b end end end
function Box:ScrollToElementData(data) local i = self.provider and self.provider:FindIndex(data) if i then self.offset = math.max(0, i - 1) self:Update() end end
function Box:ScrollToElementDataIndex(i) self.offset = math.max(0, (i or 1) - 1) self:Update() end
function Box:ScrollToBegin() self.offset = 0 self:Update() end
function Box:ScrollToEnd() self.offset = math.huge self:Update() end
function Box:SetScrollPercentage(p) self.offset = math.floor(((self.provider and self.provider:GetSize() or 0) - self:Visible()) * p) self:Update() end
function Box:GetScrollPercentage() local max = (self.provider and self.provider:GetSize() or 0) - self:Visible() return max > 0 and self.offset / max or 0 end
function Box:Visible() return math.max(1, math.floor((self:GetHeight() - (self.view and self.view.padTop or 0)) / (self.view and (self.view.extent + (self.view.spacing or 0)) or 20))) end
function Box:HasScrollableExtent() return (self.provider and self.provider:GetSize() or 0) > self:Visible() end
function Box:SetPanExtent() end
function Box:FullUpdate() self:Update() end
function Box:Rebuild() self:Update() end
function Box:RegisterCallback(event, fn, owner) self.__cb = self.__cb or {} self.__cb[#self.__cb + 1] = { event, fn, owner } end
function Box:Update()
	local view, p = self.view, self.provider
	if not view or not p then return end
	local n, vis = p:GetSize(), self:Visible()
	self.offset = math.max(0, math.min(self.offset or 0, n - vis))
	local step = view.extent + (view.spacing or 0)
	for i = 1, vis do
		local b = self.buttons[i]
		if not b then
			b = CreateFrame("Button", nil, self, view.template ~= "Button" and view.template or nil)
			b:SetHeight(view.extent)
			b:SetPoint("TOPLEFT", view.padLeft or 0, -(view.padTop or 0) - (i - 1) * step)
			b:SetPoint("RIGHT", self, "RIGHT", -2, 0)
			self.buttons[i] = b
		end
		local data = p:Find(self.offset + i)
		b.__data = data
		b.GetElementData = function() return data end
		if data ~= nil then
			if view.init then view.init(b, data) end
			b:Show()
		else
			b:Hide()
		end
	end
	for i = vis + 1, #self.buttons do self.buttons[i]:Hide() end
	if self.ScrollBar then self.ScrollBar:Sync(self.offset, math.max(0, n - vis)) end
end

function TemucraftCompat.InitScrollBox(self)
	Mixin(self, Box)
	self.buttons, self.offset = {}, 0
	self:EnableMouseWheel(true)
	self:SetScript("OnMouseWheel", function(b, delta) b.offset = (b.offset or 0) - delta * 3 b:Update() end)
	self:SetScript("OnSizeChanged", function(b) b:Update() end)
end
function TemucraftCompat.InitScrollBar(self)
	self.Sync = function(bar, offset, max)
		bar.__syncing = true
		bar:SetMinMaxValues(0, math.max(0, max))
		bar:SetValue(offset)
		bar.__syncing = false
		bar:SetShown(max > 0 or not bar.__hideIfUnscrollable)
	end
	self.SetHideIfUnscrollable = function(bar, on) bar.__hideIfUnscrollable = on end
	self:SetValueStep(1)
	self:SetScript("OnValueChanged", function(bar, v)
		if bar.__syncing or not bar.__box then return end
		bar.__box.offset = math.floor(v + 0.5) bar.__box:Update()
	end)
end

ScrollUtil = ScrollUtil or {}
ScrollUtil.InitScrollBoxListWithScrollBar = ScrollUtil.InitScrollBoxListWithScrollBar or function(box, bar, view)
	if bar then box.ScrollBar, bar.__box = bar, box end
	box:Init(view)
end
ScrollUtil.InitScrollBoxWithScrollBar = ScrollUtil.InitScrollBoxWithScrollBar or ScrollUtil.InitScrollBoxListWithScrollBar
ScrollUtil.AddManagedScrollBarVisibilityBehavior = ScrollUtil.AddManagedScrollBarVisibilityBehavior or function() end
ScrollUtil.RegisterScrollBoxWithScrollBar = ScrollUtil.RegisterScrollBoxWithScrollBar or function(box, bar) box.ScrollBar, bar.__box = bar, box end
ScrollBoxConstants = ScrollBoxConstants or { AlignBegin = 0, AlignCenter = 0.5, AlignEnd = 1, NoScrollInterpolation = true, RetainScrollPosition = true, DiscardScrollPosition = false }
