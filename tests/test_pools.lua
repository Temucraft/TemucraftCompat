-- standalone test of Pools.lua with a small fake client
local dir = arg and arg[1] or "!TemucraftCompat/"
TemucraftCompat = {}
function TemucraftCompat.def(name, value) if _G[name] == nil then _G[name] = value end end
function Mixin(o, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do o[k] = v end end return o end
function CreateFromMixins(...) return Mixin({}, ...) end
local made = 0
local function region(kind) return { kind = kind, shown = true, Hide = function(s) s.shown = false end, Show = function(s) s.shown = true end,
	ClearAllPoints = function(s) s.points = 0 end } end
function CreateFrame(kind, name, parent, template) made = made + 1 local f = region(kind) f.parent, f.template = parent, template
	f.CreateTexture = function(self, n, layer, tmpl, sub) local t = region("Texture") t.layer, t.sub = layer, sub return t end
	f.CreateFontString = function(self, n, layer, tmpl, sub) local t = region("FontString") t.layer = layer return t end
	return f end
dofile(dir .. "Pools.lua")
local function ok(c, what) if not c then error("FAIL: " .. what, 2) end print("ok  " .. what) end

local parent = CreateFrame("Frame")
local pool = CreateFramePool("Button", parent, "SomeTemplate")
local a, new = pool:Acquire()
ok(new == true and a.kind == "Button" and a.parent == parent and a.template == "SomeTemplate", "frame pool makes frames")
ok(a.shown == false, "new frame reset (hidden) like the 9.x pool")
local b = pool:Acquire()
ok(pool:GetNumActive() == 2 and pool:IsActive(a), "two active")
ok(pool:Release(a) and not pool:IsActive(a) and pool:GetNumActive() == 1, "release")
ok(pool:Release(a) == false, "double release refused")
local c, new2 = pool:Acquire()
ok(c == a and new2 == false, "reuses released frame")
local n = 0 for f in pool:EnumerateActive() do n = n + 1 end
ok(n == 2, "enumerate active")
pool:ReleaseAll()
ok(pool:GetNumActive() == 0, "release all")

local resets = 0
local tp = CreateTexturePool(parent, "ARTWORK", 7, nil, function(p, t) resets = resets + 1 t:Hide() end)
local t = tp:Acquire()
ok(t.kind == "Texture" and t.layer == "ARTWORK" and t.sub == 7 and resets == 1, "texture pool with resetter (pool, object)")
tp:Release(t)
ok(resets == 2, "resetter on release")

local GlowMaskPool = CreateFromMixins(ObjectPoolMixin)
ObjectPoolMixin.OnLoad(GlowMaskPool, function(p) return p.parent:CreateTexture() end, function(p, m) m:Hide() end)
GlowMaskPool.parent = parent
ok(GlowMaskPool:Acquire().kind == "Texture", "ObjectPoolMixin used directly, as LibCustomGlow does")
local op = CreateObjectPool(function() return {} end)
ok(type(op:Acquire()) == "table", "CreateObjectPool")
local fs = CreateFontStringPool(parent, "OVERLAY"):Acquire()
ok(fs.kind == "FontString", "font string pool")
local coll = CreateFramePoolCollection()
local p1 = coll:GetOrCreatePool("Frame", parent, "A")
ok(coll:GetOrCreatePool("Frame", parent, "A") == p1 and coll:Acquire("A") and coll:GetNumActive() == 1, "pool collection")
print("all passed")
