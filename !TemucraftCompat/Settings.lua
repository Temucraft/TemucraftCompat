-- Settings (the newer interface options) as 3.3.5 Interface Options panels.
Settings = Settings or {}
local categories = {}
local Category = {}
Category.__index = Category
function Category:GetID() return self.ID end
function Category:GetName() return self.name end
function Category:SetOrder() end
local function make(frame, name, parent)
	frame.name = name
	if parent then frame.parent = parent.name end
	local c = setmetatable({ frame = frame, name = name, ID = name }, Category)
	categories[name] = c
	return c
end
Settings.RegisterCanvasLayoutCategory = Settings.RegisterCanvasLayoutCategory or function(frame, name) return make(frame, name) end
Settings.RegisterCanvasLayoutSubcategory = Settings.RegisterCanvasLayoutSubcategory or function(parent, frame, name) local c = make(frame, name, parent) InterfaceOptions_AddCategory(frame) return c end
Settings.RegisterVerticalLayoutCategory = Settings.RegisterVerticalLayoutCategory or function(name) return make(CreateFrame("Frame"), name) end
Settings.RegisterAddOnCategory = Settings.RegisterAddOnCategory or function(c) if c and c.frame then InterfaceOptions_AddCategory(c.frame) end end
Settings.OpenToCategory = Settings.OpenToCategory or function(id)
	local c = type(id) == "table" and id or categories[id]
	local target = c and c.frame or id
	InterfaceOptionsFrame_OpenToCategory(target)
	InterfaceOptionsFrame_OpenToCategory(target) -- twice: the 3.3.5 panel opens on the wrong page the first time
end
Settings.GetCategory = Settings.GetCategory or function(id) return categories[id] end
SettingsPanel = SettingsPanel or InterfaceOptionsFrame
