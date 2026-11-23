-- Velocity Plate Style: the bar texture list. Built-in textures shipped in Assets\ come
-- first; if another addon has already loaded LibSharedMedia-3.0 its statusbar textures
-- follow, alphabetically. LSM is never embedded and never required (spec: Alternatives).
--
-- A texture is identified everywhere by a VPS_TextureKey string:
--   "VPS:<Name>"  built-in (path from BUILTIN below)
--   "LSM:<Name>"  LibSharedMedia statusbar entry (path from LSM:Fetch at use time)
-- The saved variable barTexture holds a VPS_TextureKey. An unknown key (LSM addon removed)
-- falls back to the flat built-in.
local ADDON, VPS = ...

local Textures = {}
VPS.Textures = Textures

local ASSETS = "Interface\\AddOns\\" .. ADDON .. "\\Assets\\"
local WHITE8 = "Interface\\Buttons\\WHITE8x8"

-- name -> texture path. Order of DISPLAY is BUILTIN_ORDER.
local BUILTIN = {
	Flat  = WHITE8,                          -- solid; colour comes from the bar's vertex colour
	Soft  = ASSETS .. "soft.tga",            -- gentle vertical gradient
	Stock = nil,                             -- nil = leave Blizzard's own fill texture in place
}
local BUILTIN_ORDER = { "Flat", "Soft", "Stock" }

Textures.FALLBACK_KEY = "VPS:Flat"

local function LSM()
	if LibStub then
		local ok, lib = pcall(LibStub, "LibSharedMedia-3.0", true)
		if ok and lib then return lib end
	end
	return nil
end

function Textures.HasLSM() return LSM() ~= nil end

-- Splits a key into (source, name). Unknown shape -> nil.
local function ParseKey(key)
	if type(key) ~= "string" then return nil end
	local src, name = key:match("^(%u+):(.+)$")
	if src == "VPS" or src == "LSM" then return src, name end
	return nil
end

-- Resolves a key to a texture path. Returns nil for the "Stock" built-in (meaning: do not
-- touch the fill) and the flat fallback for anything unresolvable.
function Textures.PathForKey(key)
	local src, name = ParseKey(key)
	if src == "VPS" then
		if name == "Stock" then return nil end
		return BUILTIN[name] or BUILTIN.Flat
	elseif src == "LSM" then
		local lib = LSM()
		local path = lib and lib:Fetch("statusbar", name, true)
		if path then return path end
	end
	return BUILTIN.Flat
end

function Textures.IsStockKey(key) return key == "VPS:Stock" end

-- Display name for a key (what the dropdown shows).
function Textures.NameForKey(key)
	local src, name = ParseKey(key)
	if not src then return tostring(key) end
	if src == "LSM" then return name .. "  (SharedMedia)" end
	return name
end

-- Ordered list of { key = VPS_TextureKey, name = displayName, path = texturePath|nil }.
function Textures.List()
	local out = {}
	for _, name in ipairs(BUILTIN_ORDER) do
		out[#out + 1] = { key = "VPS:" .. name, name = name, path = BUILTIN[name] }
	end
	local lib = LSM()
	if lib then
		local names = lib:List("statusbar")
		local sorted = {}
		for _, n in ipairs(names or {}) do sorted[#sorted + 1] = n end
		table.sort(sorted, function(a, b) return a:lower() < b:lower() end)
		for _, n in ipairs(sorted) do
			out[#out + 1] = { key = "LSM:" .. n, name = n .. "  (SharedMedia)", path = lib:Fetch("statusbar", n, true) }
		end
	end
	return out
end

-- Validates a saved key against what is currently available.
function Textures.ValidKey(key)
	local src, name = ParseKey(key)
	if src == "VPS" then return name == "Stock" or BUILTIN[name] ~= nil end
	if src == "LSM" then local lib = LSM(); return lib ~= nil and lib:Fetch("statusbar", name, true) ~= nil end
	return false
end