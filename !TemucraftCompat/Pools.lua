if TemucraftCompat and TemucraftCompat.UnitEnv then setfenv(1, TemucraftCompat.UnitEnv) end -- Temucraft: nameplate unit tokens
-- Object pools (ObjectPoolMixin, CreateFramePool, CreateTexturePool...) as newer clients have them.
-- Same calls and same order of callbacks as the 9.x client code: creationFunc(pool), resetterFunc(pool, object).
local def = TemucraftCompat.def

if not ObjectPoolMixin then
	ObjectPoolMixin = {}

	function ObjectPoolMixin:OnLoad(creationFunc, resetterFunc)
		self.creationFunc = creationFunc
		self.resetterFunc = resetterFunc
		self.activeObjects = {}
		self.inactiveObjects = {}
		self.numActiveObjects = 0
	end

	function ObjectPoolMixin:Acquire()
		local n = #self.inactiveObjects
		if n > 0 then
			local object = self.inactiveObjects[n]
			self.inactiveObjects[n] = nil
			self.activeObjects[object] = true
			self.numActiveObjects = self.numActiveObjects + 1
			return object, false
		end
		local object = self.creationFunc(self)
		if self.resetterFunc and not self.disallowResetIfNew then self.resetterFunc(self, object) end
		self.activeObjects[object] = true
		self.numActiveObjects = self.numActiveObjects + 1
		return object, true
	end

	function ObjectPoolMixin:Release(object)
		if not self.activeObjects[object] then return false end
		self.inactiveObjects[#self.inactiveObjects + 1] = object
		self.activeObjects[object] = nil
		self.numActiveObjects = self.numActiveObjects - 1
		if self.resetterFunc then self.resetterFunc(self, object) end
		return true
	end

	function ObjectPoolMixin:ReleaseAll()
		for object in pairs(self.activeObjects) do self:Release(object) end
	end

	function ObjectPoolMixin:SetResetDisallowedIfNew(disallowed) self.disallowResetIfNew = disallowed end
	function ObjectPoolMixin:EnumerateActive() return pairs(self.activeObjects) end
	function ObjectPoolMixin:GetNextActive(current) return (next(self.activeObjects, current)) end
	function ObjectPoolMixin:GetNextInactive(current) return (next(self.inactiveObjects, current)) end
	function ObjectPoolMixin:IsActive(object) return self.activeObjects[object] == true end
	function ObjectPoolMixin:GetNumActive() return self.numActiveObjects end
	function ObjectPoolMixin:EnumerateInactive() return ipairs(self.inactiveObjects) end
end

def("CreateObjectPool", function(creationFunc, resetterFunc)
	local pool = CreateFromMixins(ObjectPoolMixin)
	pool:OnLoad(creationFunc, resetterFunc)
	return pool
end)

def("Pool_HideAndClearAnchors", function(pool, region) region:Hide() region:ClearAllPoints() end)
def("FramePool_Hide", function(pool, frame) frame:Hide() end)
def("FramePool_HideAndClearAnchors", function(pool, frame) frame:Hide() frame:ClearAllPoints() end)

if not FramePoolMixin then
	FramePoolMixin = CreateFromMixins(ObjectPoolMixin)
	local function newFrame(pool)
		local frame = CreateFrame(pool.frameType, nil, pool.parent, pool.frameTemplate)
		if pool.frameInitFunc then pool.frameInitFunc(frame) end
		return frame
	end
	function FramePoolMixin:OnLoad(frameType, parent, frameTemplate, resetterFunc, forbidden, frameInitFunc)
		ObjectPoolMixin.OnLoad(self, newFrame, resetterFunc)
		self.frameType, self.parent, self.frameTemplate, self.frameInitFunc = frameType, parent, frameTemplate, frameInitFunc
	end
	function FramePoolMixin:GetTemplate() return self.frameTemplate end
end
def("CreateFramePool", function(frameType, parent, frameTemplate, resetterFunc, forbidden, frameInitFunc)
	local pool = CreateFromMixins(FramePoolMixin)
	pool:OnLoad(frameType, parent, frameTemplate, resetterFunc or FramePool_HideAndClearAnchors, forbidden, frameInitFunc)
	return pool
end)

if not TexturePoolMixin then
	TexturePoolMixin = CreateFromMixins(ObjectPoolMixin)
	local function newTexture(pool) return pool.parent:CreateTexture(nil, pool.layer, pool.textureTemplate, pool.subLayer) end
	function TexturePoolMixin:OnLoad(parent, layer, subLayer, textureTemplate, resetterFunc)
		ObjectPoolMixin.OnLoad(self, newTexture, resetterFunc)
		self.parent, self.layer, self.subLayer, self.textureTemplate = parent, layer, subLayer, textureTemplate
	end
end
def("CreateTexturePool", function(parent, layer, subLayer, textureTemplate, resetterFunc)
	local pool = CreateFromMixins(TexturePoolMixin)
	pool:OnLoad(parent, layer, subLayer, textureTemplate, resetterFunc or Pool_HideAndClearAnchors)
	return pool
end)

if not FontStringPoolMixin then
	FontStringPoolMixin = CreateFromMixins(ObjectPoolMixin)
	local function newFontString(pool) return pool.parent:CreateFontString(nil, pool.layer, pool.fontStringTemplate, pool.subLayer) end
	function FontStringPoolMixin:OnLoad(parent, layer, subLayer, fontStringTemplate, resetterFunc)
		ObjectPoolMixin.OnLoad(self, newFontString, resetterFunc)
		self.parent, self.layer, self.subLayer, self.fontStringTemplate = parent, layer, subLayer, fontStringTemplate
	end
end
def("CreateFontStringPool", function(parent, layer, subLayer, fontStringTemplate, resetterFunc)
	local pool = CreateFromMixins(FontStringPoolMixin)
	pool:OnLoad(parent, layer, subLayer, fontStringTemplate, resetterFunc or Pool_HideAndClearAnchors)
	return pool
end)

-- several pools keyed by template
if not FramePoolCollectionMixin then
	FramePoolCollectionMixin = {}
	function FramePoolCollectionMixin:OnLoad() self.pools = {} end
	function FramePoolCollectionMixin:GetOrCreatePool(frameType, parent, template, resetterFunc, forbidden)
		local key = tostring(frameType) .. ":" .. tostring(parent) .. ":" .. tostring(template)
		local pool = self.pools[key]
		if not pool then pool = CreateFramePool(frameType, parent, template, resetterFunc, forbidden) self.pools[key] = pool end
		return pool
	end
	function FramePoolCollectionMixin:Acquire(template)
		for _, pool in pairs(self.pools) do if pool.frameTemplate == template then return pool:Acquire() end end
	end
	function FramePoolCollectionMixin:Release(object)
		for _, pool in pairs(self.pools) do if pool:IsActive(object) then return pool:Release(object) end end
		return false
	end
	function FramePoolCollectionMixin:ReleaseAll() for _, pool in pairs(self.pools) do pool:ReleaseAll() end end
	function FramePoolCollectionMixin:EnumerateActive()
		local list = {}
		for _, pool in pairs(self.pools) do for object in pool:EnumerateActive() do list[object] = true end end
		return pairs(list)
	end
	function FramePoolCollectionMixin:GetNumActive()
		local n = 0
		for _, pool in pairs(self.pools) do n = n + pool:GetNumActive() end
		return n
	end
end
def("CreateFramePoolCollection", function()
	local collection = CreateFromMixins(FramePoolCollectionMixin)
	collection:OnLoad()
	return collection
end)
