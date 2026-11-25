if TemucraftCompat and TemucraftCompat.UnitEnv then setfenv(1, TemucraftCompat.UnitEnv) end -- Temucraft: nameplate unit tokens
-- Widget methods newer clients have, added to the shared method tables of the 3.3.5 widget types.
local hidden = CreateFrame("Frame")
hidden:Hide()

local function methodsOf(object)
	local mt = getmetatable(object)
	return mt and mt.__index
end

local types = {}
local function addType(object) local m = methodsOf(object) if m and type(m) == "table" then types[#types + 1] = m end return m end
local frameTypes = { "Frame", "Button", "CheckButton", "EditBox", "Slider", "StatusBar", "ScrollFrame", "Cooldown", "Model",
	"PlayerModel", "DressUpModel", "TabardModel", "GameTooltip", "MessageFrame", "ScrollingMessageFrame", "SimpleHTML", "ColorSelect", "MovieFrame" }
local byType = {}
for _, t in ipairs(frameTypes) do
	local ok, f = pcall(CreateFrame, t, nil, hidden)
	if ok and f then byType[t] = addType(f) end
end
local texture = hidden:CreateTexture()
local fontString = hidden:CreateFontString()
local group = hidden:CreateAnimationGroup()
byType.Texture = addType(texture)
byType.FontString = addType(fontString)
byType.AnimationGroup = addType(group)
for _, t in ipairs({ "Alpha", "Scale", "Translation", "Rotation", "Animation", "Path" }) do
	local ok, a = pcall(group.CreateAnimation, group, t)
	if ok and a then byType[t] = addType(a) end
end
TemucraftCompat.widgetMethods = byType

-- add(name, fn [, which]): only where the type doesn't have it already
local function add(name, fn, which)
	for _, m in ipairs(which or types) do
		if m and m[name] == nil then m[name] = fn end
	end
end
local function only(...) local r = {} for i = 1, select("#", ...) do r[#r + 1] = byType[select(i, ...)] end return r end
local frames = {}
for _, t in ipairs(frameTypes) do if byType[t] then frames[#frames + 1] = byType[t] end end
local regions = { byType.Texture, byType.FontString }

-- Everything
add("SetShown", function(self, shown) if shown then self:Show() else self:Hide() end end)
add("IsForbidden", function() return false end)
add("GetDebugName", function(self) return self.GetName and self:GetName() or tostring(self) end)

-- Frames
add("SetResizeBounds", function(self, minW, minH, maxW, maxH)
	if minW then self:SetMinResize(minW, minH or minW) end
	if maxW then self:SetMaxResize(maxW, maxH or maxW) end
end, frames)
add("GetResizeBounds", function(self) local a, b = self:GetMinResize() local c, d = self:GetMaxResize() return a, b, c, d end, frames)
add("SetClipsChildren", function() end, frames)
add("DoesClipChildren", function() return false end, frames)
add("SetFixedFrameLevel", function() end, frames)
add("SetFixedFrameStrata", function() end, frames)
add("SetFlattensRenderLayers", function() end, frames)
add("SetIsFrameBuffer", function() end, frames)
add("SetPropagateKeyboardInput", function() end, frames)
add("GetPropagateKeyboardInput", function() return false end, frames)
add("SetIgnoreParentAlpha", function() end, frames)
add("SetIgnoreParentScale", function() end, frames)
add("EnableMouseMotion", function(self, on) self:EnableMouse(on) end, frames)
add("EnableMouseClicks", function() end, frames)
add("SetMouseMotionEnabled", function(self, on) self:EnableMouse(on) end, frames)
add("SetMouseClickEnabled", function() end, frames)
add("IsMouseMotionFocus", function(self) return GetMouseFocus() == self end, frames)
add("IsMouseMotionEnabled", function(self) return self:IsMouseEnabled() end, frames)
add("SetHitRectInsets", function() end, frames)
add("GetEffectiveAlpha", function(self) return self:GetAlpha() end, frames)
add("SetToplevel", function() end, frames)
add("CreateMaskTexture", function(self) local t = self:CreateTexture() t:Hide() return t end, frames)
add("CreateLine", function(self, name, layer, inherits, sub)
	-- Lines don't exist in 3.3.5: a texture drawn between the two points (horizontal or vertical lines only)
	local t = self:CreateTexture(name, layer, inherits, sub)
	t.isLine = true
	return t
end, frames)
-- RegisterUnitEvent: register normally and drop events for other units
do
	local function filtered(self, event, unit, ...)
		local units = self.__tcUnits and self.__tcUnits[event]
		if units and unit and not units[unit] then return end
		local f = self.__tcOnEvent
		if f then return f(self, event, unit, ...) end
	end
	add("RegisterUnitEvent", function(self, event, unit1, unit2)
		self.__tcUnits = self.__tcUnits or {}
		self.__tcUnits[event] = { [unit1 or "player"] = true }
		if unit2 then self.__tcUnits[event][unit2] = true end
		if not self.__tcHooked then
			self.__tcHooked = true
			self.__tcOnEvent = self:GetScript("OnEvent")
			self:SetScript("OnEvent", filtered)
			local set = self.SetScript
			self.SetScript = function(f, script, fn)
				if script == "OnEvent" then f.__tcOnEvent = fn return set(f, script, filtered) end
				return set(f, script, fn)
			end
			local get = self.GetScript
			self.GetScript = function(f, script) if script == "OnEvent" then return f.__tcOnEvent end return get(f, script) end
		end
		self:RegisterEvent(event)
	end, frames)
end
add("RegisterEventCallback", function() end, frames)

-- Buttons
add("SetEnabled", function(self, on) if on then self:Enable() else self:Disable() end end, only("Button", "CheckButton", "EditBox", "Slider"))
add("ClearNormalTexture", function(self) self:SetNormalTexture("") end, only("Button", "CheckButton"))
add("ClearPushedTexture", function(self) self:SetPushedTexture("") end, only("Button", "CheckButton"))
add("ClearHighlightTexture", function(self) self:SetHighlightTexture("") end, only("Button", "CheckButton"))
add("ClearDisabledTexture", function(self) self:SetDisabledTexture("") end, only("Button", "CheckButton"))
add("SetObeyStepOnDrag", function() end, only("Slider"))
add("SetStepsPerPage", function() end, only("Slider"))
add("SetHideCountdownNumbers", function() end, only("Cooldown"))
add("SetDrawEdge", function() end, only("Cooldown"))
add("SetDrawSwipe", function() end, only("Cooldown"))
add("SetSwipeColor", function() end, only("Cooldown"))
add("SetCountdownFont", function() end, only("Cooldown"))
add("Clear", function(self) self:Hide() end, only("Cooldown"))
add("SetFillStyle", function() end, only("StatusBar"))
add("SetStatusBarDesaturated", function() end, only("StatusBar"))
add("SetVisuallyEnabled", function() end, only("Button", "CheckButton"))

-- Models
local models = only("Model", "PlayerModel", "DressUpModel", "TabardModel")
add("SetPortraitZoom", function(self, z) if self.SetCamera and z and z > 0 then self:SetCamera(0) end end, models)
add("SetCamDistanceScale", function(self, s) if self.SetModelScale then self:SetModelScale(s) end end, models)
add("SetKeepModelOnHide", function() end, models)
add("RefreshCamera", function() end, models)
add("SetAnimation", function(self, anim) if self.SetSequence then self:SetSequence(anim) end end, models)
add("SetDisplayInfo", function(self, id) if self.SetCreature then self:SetCreature(id) end end, models)
add("GetDisplayInfo", function() return 0 end, models)
add("GetModelFileID", function(self) return self.GetModel and self:GetModel() end, models)
add("SetPitch", function() end, models)
add("UndressSlot", function(self) end, models)
add("SetUseTransmogSkin", function() end, models)

-- Textures
add("SetColorTexture", function(self, r, g, b, a) self:SetTexture(r, g, b, a) end, only("Texture"))
add("SetAtlas", function(self, atlas, useSize)
	local info = C_Texture and C_Texture.GetAtlasInfo(atlas)
	if info then
		self:SetTexture(info.file)
		self:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
		if useSize then self:SetSize(info.width, info.height) end
	end
	self.__atlas = atlas
end, only("Texture"))
add("GetAtlas", function(self) return self.__atlas end, only("Texture"))
add("AddMaskTexture", function() end, only("Texture"))
add("RemoveMaskTexture", function() end, only("Texture"))
add("SetSnapToPixelGrid", function() end, only("Texture"))
add("SetTexelSnappingBias", function() end, only("Texture"))
add("SetRotation", function(self, rad)
	local s, c = math.sin(rad), math.cos(rad)
	local function p(x, y) return 0.5 + (x - 0.5) * c - (y - 0.5) * s, 0.5 + (x - 0.5) * s + (y - 0.5) * c end
	local ulx, uly = p(0, 0) local llx, lly = p(0, 1) local urx, ury = p(1, 0) local lrx, lry = p(1, 1)
	self:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end, only("Texture"))
-- SetGradient: 3.3.5 has SetGradient(orient, r1, g1, b1, r2, g2, b2); newer clients SetGradient(orient, colorA, colorB)
-- with color tables (CreateColor). The native method is wrapped so both forms work: numbers go to the native method
-- unchanged, color tables to SetGradientAlpha. No Blizzard Lua in the 3.3.5 FrameXML calls SetGradient (checked in
-- locale-enUS / patch-enUS*.MPQ; XML <Gradient> is drawn natively), so no secure code runs through the wrapper.
do
	local T = byType.Texture
	local native = T and T.SetGradient
	if type(native) == "function" then
		local function c(t, k, i) local v = t[k] if v == nil then v = t[i] end return v end
		T.SetGradient = function(self, orient, a, b, ...)
			if type(a) == "table" and type(b) == "table" then
				return self:SetGradientAlpha(orient, c(a, "r", 1) or 1, c(a, "g", 2) or 1, c(a, "b", 3) or 1, c(a, "a", 4) or 1,
					c(b, "r", 1) or 1, c(b, "g", 2) or 1, c(b, "b", 3) or 1, c(b, "a", 4) or 1)
			end
			return native(self, orient, a, b, ...)
		end
	elseif T then
		add("SetGradient", function(self, orient, a, b)
			if type(a) == "table" then return self:SetGradientAlpha(orient, a.r, a.g, a.b, a.a or 1, b.r, b.g, b.b, b.a or 1) end
		end, only("Texture"))
	end
end
-- Lines (textures made by CreateLine)
add("SetStartPoint", function(self, point, rel, x, y) self.__p1 = { point, rel, x or 0, y or 0 } TemucraftCompat.LayoutLine(self) end, only("Texture"))
add("SetEndPoint", function(self, point, rel, x, y) self.__p2 = { point, rel, x or 0, y or 0 } TemucraftCompat.LayoutLine(self) end, only("Texture"))
add("SetThickness", function(self, t) self.__thick = t TemucraftCompat.LayoutLine(self) end, only("Texture"))
function TemucraftCompat.LayoutLine(t)
	local a, b = t.__p1, t.__p2
	if not (a and b) then return end
	local thick = t.__thick or 1
	t:ClearAllPoints()
	if math.abs((a[4] or 0) - (b[4] or 0)) < 0.5 then
		t:SetPoint("TOPLEFT", a[2], a[1], a[3], a[4] + thick / 2)
		t:SetPoint("BOTTOMRIGHT", b[2], b[1], b[3], b[4] - thick / 2)
	else
		t:SetPoint("TOPLEFT", a[2], a[1], a[3] - thick / 2, a[4])
		t:SetPoint("BOTTOMRIGHT", b[2], b[1], b[3] + thick / 2, b[4])
	end
end

-- Font strings
add("GetUnboundedStringWidth", function(self) return self:GetStringWidth() end, only("FontString"))
add("SetFontHeight", function(self, size) local f, _, flags = self:GetFont() if f then self:SetFont(f, size, flags) end end, only("FontString"))
add("SetMaxLines", function() end, only("FontString"))
add("SetWordWrap", function() end, only("FontString"))
add("IsTruncated", function() return false end, only("FontString"))
add("SetTextToFit", function(self, text) self:SetText(text) end, only("FontString"))

-- Animations: newer names on top of 3.3.5's SetChange
add("SetFromAlpha", function(self, a) self.__from = a if self.__to then self:SetChange(self.__to - a) end end, only("Alpha"))
add("SetToAlpha", function(self, a) self.__to = a self:SetChange(a - (self.__from or 0)) end, only("Alpha"))
add("SetScaleFrom", function(self, x, y) self.__sfrom = { x, y } end, only("Scale"))
add("SetScaleTo", function(self, x, y) local f = self.__sfrom or { 1, 1 } self:SetScale(x / f[1], y / f[2]) end, only("Scale"))
add("SetToFinalAlpha", function() end, only("AnimationGroup"))
add("SetPlaying", function(self, on) if on then self:Play() else self:Stop() end end, only("AnimationGroup"))

-- Edit boxes, tooltips
add("SetCountInvisibleLetters", function() end, only("EditBox"))
add("SetVisibleTextByteLimit", function(self, n) self:SetMaxBytes(n) end, only("EditBox"))
add("GetTooltipData", function() return nil end, only("GameTooltip"))
add("SetMinimumWidth", function() end, only("GameTooltip"))
add("SetHyperlinkIsSecret", function() end, only("GameTooltip"))

-- Scrolling message frames (chat)
add("ScrollToEnd", function(self) self:ScrollToBottom() end, only("ScrollingMessageFrame"))
add("ScrollToBegin", function(self) self:ScrollToTop() end, only("ScrollingMessageFrame"))
add("GetNumMessages", function(self) return self.GetNumLinesDisplayed and self:GetNumLinesDisplayed() or 0 end, only("ScrollingMessageFrame"))

-- Scroll frames (newer ScrollFrameTemplate methods)
add("SetPanExtent", function() end, only("ScrollFrame", "Frame"))
add("SetScrollPercentage", function(self, p) self:SetVerticalScroll(p * self:GetVerticalScrollRange()) end, only("ScrollFrame"))
add("GetScrollPercentage", function(self) local r = self:GetVerticalScrollRange() return r > 0 and self:GetVerticalScroll() / r or 0 end, only("ScrollFrame"))
add("ScrollToBegin", function(self) self:SetVerticalScroll(0) end, only("ScrollFrame"))
add("ScrollToEnd", function(self) self:SetVerticalScroll(self:GetVerticalScrollRange()) end, only("ScrollFrame"))
add("SetSecurityDisablePaste", function() end, only("EditBox"))
add("SetSecurityDisableSetText", function() end, only("EditBox"))
add("SetEnablePasting", function() end, only("EditBox"))
add("SetForbidden", function() end)

-- Cooldown swipe and edge settings (the 3.3.5 cooldown draws its own clock)
add("GetCooldownDuration", function() return 0 end, only("Cooldown"))
add("SetDrawBling", function() end, only("Cooldown"))
add("SetEdgeTexture", function() end, only("Cooldown"))
add("SetSwipeTexture", function() end, only("Cooldown"))
add("SetUseCircularEdge", function() end, only("Cooldown"))
add("SetEdgeScale", function() end, only("Cooldown"))
add("SetBlingTexture", function() end, only("Cooldown"))
-- Textures
add("GetDesaturated", function(self) return self:IsDesaturated() end, only("Texture"))
add("GetNumMaskTextures", function() return 0 end, only("Texture"))
add("GetMaskTexture", function() return nil end, only("Texture"))
-- Status bars: the 3.3.5 bar always fills from the left or the bottom
add("SetReverseFill", function(self, on) self.__reverseFill = on and true or false end, only("StatusBar"))
add("GetReverseFill", function(self) return self.__reverseFill or false end, only("StatusBar"))
-- Animations
add("GetFromAlpha", function(self) return self.__from or 0 end, only("Alpha"))
add("GetToAlpha", function(self) return self.__to or ((self.__from or 0) + (self.GetChange and self:GetChange() or 0)) end, only("Alpha"))
add("SetFromScale", function(self, x, y) self:SetScaleFrom(x, y) end, only("Scale"))
add("SetToScale", function(self, x, y) self:SetScaleTo(x, y) end, only("Scale"))
add("GetFromScale", function(self) local f = self.__sfrom or { 1, 1 } return f[1], f[2] end, only("Scale"))
-- 3.3.5 animations always move the frame that owns the group: a target can't be chosen
local anims = only("Alpha", "Scale", "Translation", "Rotation", "Animation", "Path")
add("SetTarget", function(self, target) self.__target = target end, anims)
add("GetTarget", function(self) return self.__target end, anims)
add("SetChildKey", function(self, key) self.__childKey = key end, anims)
add("SetTargetKey", function(self, key) self.__childKey = key end, anims)
add("SetTargetName", function() end, anims)
add("SetTargetParent", function() end, anims)
add("SetAnimationSpeedMultiplier", function(self, m) self.__speed = m end, only("AnimationGroup"))
add("GetAnimationSpeedMultiplier", function(self) return self.__speed or 1 end, only("AnimationGroup"))

-- BackdropTemplateMixin: 3.3.5 frames draw backdrops natively, so the mixin only has the newer helper methods
-- (it must not hold SetBackdrop & co, or Mixin would cover the native ones)
if not BackdropTemplateMixin then
	BackdropTemplateMixin = {}
	function BackdropTemplateMixin:OnBackdropLoaded()
		if self.backdropInfo then
			self:SetBackdrop(self.backdropInfo)
			local c, b = self.backdropColor, self.backdropBorderColor
			if c then self:SetBackdropColor(c.r or c[1], c.g or c[2], c.b or c[3], self.backdropColorAlpha or 1) end
			if b then self:SetBackdropBorderColor(b.r or b[1], b.g or b[2], b.b or b[3], self.backdropBorderColorAlpha or 1) end
		end
	end
	function BackdropTemplateMixin:OnBackdropSizeChanged() end
	function BackdropTemplateMixin:ApplyBackdrop() if self.backdropInfo then self:SetBackdrop(self.backdropInfo) end end
	function BackdropTemplateMixin:ClearBackdrop() self:SetBackdrop(nil) self.backdropInfo = nil end
	function BackdropTemplateMixin:HasBackdropInfo(info) return self.backdropInfo == info end
	function BackdropTemplateMixin:GetEdgeSize() return self.backdropInfo and self.backdropInfo.edgeSize or 0 end
	function BackdropTemplateMixin:SetupTextureCoordinates() end
end
add("GetLineHeight", function(self) local _, size = self:GetFont() return size or 12 end, only("FontString"))
