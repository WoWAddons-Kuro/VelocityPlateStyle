-- Velocity Plate Style: core. Saved variables, the secret-value guard, the plate-owner
-- stand-down (R7), the plate lifecycle (NAME_PLATE_UNIT_ADDED/REMOVED, PLAYER_TARGET_CHANGED,
-- UNIT_LEVEL) and the post-hooks that re-apply our styling after Blizzard re-applies its own.
--
-- Design rules (SPECS\SPEC-VelocityPlateStyle.md): R1 never write a CVar; R2 never show/hide/
-- move a plate or a child we did not create (we alpha-zero); R4 event-driven only; R6 skip
-- forbidden frames; R8 every plate-unit value goes through VPS.Plain before Lua logic.
local ADDON, VPS = ...
local Client = VPS.Client

local VPS_DB_VERSION = 3   -- 1 -> 2: barStyle/borderDarken/showLevel dropped; elements list added. 2 -> 3: over-level default red/+2

-- Default VPS_TextElement rows, in stacking order. Copied (deep) into a fresh DB.
VPS.DEFAULT_ELEMENTS = {
	{ id = "name",      label = "Name",     format = "[name]",  anchor = "above",  align = "center", size = 10, color = "stock" },
	{ id = "level",     label = "Level",    format = "[level]", anchor = "inside", align = "right",  size = 9,  color = "difficulty" },
	{ id = "health",    label = "Health",   format = "[hp]",    anchor = "hidden", align = "right",  size = 9,  color = "white" },
	{ id = "healthpct", label = "Health %", format = "[hp%]",   anchor = "hidden", align = "right",  size = 9,  color = "white" },
}
VPS.BUILTIN_ELEMENT_IDS = { name = true, level = true, health = true, healthpct = true }

-- Account-wide defaults. Keys are documented in the spec's "Saved variables" section.
VPS.DEFAULTS = {
	Version = VPS_DB_VERSION,
	barTexture = "VPS:Flat",      -- key into VPS.Textures (Textures.lua)
	barHeight = 12,               -- px, 1..24
	backingAlpha = 0.6,           -- alpha of the black backing behind the fill
	targetColor = { 1, 1, 1, 1 },
	targetThickness = 2,          -- px, 1..4
	overLevelMode = "animatedRed",-- VPS_OverLevelMode: none | animated | red | animatedRed  (spell-activation proc glow,
	                              -- gold or tinted red; red modes also redden the outline + name; "red" = static)
	overLevelThreshold = 2,       -- unitLevel >= playerLevel + N (or skull) lights the over-level highlight (Hardcore: +2)
	nextCustomId = 1,             -- counter for custom element ids "c<n>"
	-- elements: filled by InitDB from DEFAULT_ELEMENTS (arrays are not merged by CopyDefaults)
}

-- VPS_Anchor / VPS_Align / VPS_ColorMode vocabularies (Options dropdowns + Skin).
VPS.ANCHORS = { "above", "below", "inside", "left", "right", "hidden" }
VPS.ALIGNS_H = { "left", "center", "right" }         -- for above / below / inside
VPS.ALIGNS_V = { "top", "middle", "bottom" }         -- for left / right side columns (baseline alignment)
VPS.COLOR_MODES = { "stock", "white", "difficulty", "class", "custom" }
VPS.SIZE_MIN, VPS.SIZE_MAX = 6, 20
VPS.OVER_LEVEL_MODES = { "none", "animated", "red", "animatedRed" }

VPS.styleVersion = 1          -- bumped on every settings change; uf.vpsStyled ~= styleVersion => restyle
VPS.standDown = nil           -- name of the plate-replacement addon that made us stand down, or nil
VPS.db = nil

local COLOR = "|cff80c0ff"
function VPS.Print(msg) print(COLOR .. "VelocityPlateStyle|r: " .. tostring(msg)) end

--------------------------------------------------------------------------------
-- Fail loudly. Every styling entry point (events, hooksecurefunc post-hooks) runs through
-- VPS.Guard so an error inside Skin can never be swallowed: it is re-raised to the global
-- error handler (BugSack/BugGrabber see it with the full stack), counted, and announced in chat
-- ONCE per distinct message so the owner knows the addon is throwing even with Lua errors
-- display off. /vps status prints the count; /vps debug prints the last message.
--
-- Throttled: styling runs on UNIT_HEALTH and every plate add, so a persistent fault would fire
-- dozens of times a second. Per distinct message: chat line once, error-handler delivery at most
-- once per THROTTLE_SEC, everything else just counted (the count is in /vps status).
--------------------------------------------------------------------------------
VPS.errorCount = 0
VPS.lastError = nil
local THROTTLE_SEC = 5
local seen = {}        -- key -> { announced = bool, lastDelivered = GetTime(), count = n }
function VPS.Guard(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if ok then return true end
	VPS.errorCount = VPS.errorCount + 1
	local msg = tostring(err)
	VPS.lastError = label .. ": " .. msg
	local key = label .. "|" .. (msg:gsub(":%d+:", ":"))
	local rec = seen[key]
	if not rec then rec = { count = 0, lastDelivered = -math.huge }; seen[key] = rec end
	rec.count = rec.count + 1
	if not rec.announced then
		rec.announced = true
		VPS.Print("|cffff4040ERROR|r in " .. label .. " - " .. msg .. "  (details in BugSack; repeats are counted, see /vps status)")
	end
	local now = GetTime()
	if now - rec.lastDelivered >= THROTTLE_SEC then
		rec.lastDelivered = now
		-- Hand it to the error handler so BugSack keeps a stack-bearing copy; repeat count attached.
		geterrorhandler()(VPS.lastError .. (rec.count > 1 and (" (x" .. rec.count .. ")") or ""))
	end
	return false
end

-- R8 / BUG 12: a secret value becomes nil; the caller skips the cue for this pass.
local issecretvalue = issecretvalue or function() return false end
function VPS.Plain(v)
	if v == nil or issecretvalue(v) then return nil end
	return v
end

--------------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------------
local function CopyDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			CopyDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

local function InitDB()
	if type(VelocityPlateStyleDB) ~= "table" then VelocityPlateStyleDB = {} end
	local d = VelocityPlateStyleDB
	-- v1 -> v2: the two-style split and the level toggle are gone (spec: Classic Clean retired).
	if (d.Version or 1) < 2 then
		d.barStyle, d.borderDarken, d.showLevel = nil, nil, nil
	end
	-- v2 -> v3: the over-level highlight shipped defaulting to "none"/3 for a day; this is a
	-- Hardcore addon, so everyone moves to the red animated glow at +2 (they can turn it off).
	if (d.Version or 1) < 3 then
		d.overLevelMode, d.overLevelThreshold = nil, nil
	end
	CopyDefaults(d, VPS.DEFAULTS)
	if type(d.elements) ~= "table" or #d.elements == 0 then
		d.elements = {}
		for _, e in ipairs(VPS.DEFAULT_ELEMENTS) do d.elements[#d.elements + 1] = CopyTable(e) end
	end
	-- Every built-in must exist exactly once (a missing one is appended, a duplicate dropped);
	-- every row gets any field a newer default introduced.
	local seen = {}
	for i = #d.elements, 1, -1 do
		local e = d.elements[i]
		if type(e) ~= "table" or type(e.id) ~= "string" or seen[e.id] then table.remove(d.elements, i) else seen[e.id] = true end
	end
	for _, def in ipairs(VPS.DEFAULT_ELEMENTS) do
		if not seen[def.id] then d.elements[#d.elements + 1] = CopyTable(def) end
	end
	for _, e in ipairs(d.elements) do
		local def = VPS.DefaultElement(e.id) or VPS.DEFAULT_ELEMENTS[1]
		for k, v in pairs(def) do if e[k] == nil and k ~= "id" and k ~= "label" and k ~= "format" then e[k] = v end end
		if e.id == "level" then e.color = "difficulty"; if e.anchor == "hidden" then e.anchor = "inside" end end   -- R3
	end
	d.Version = VPS_DB_VERSION
	VPS.db = d
end

function VPS.ResetToDefaults()
	wipe(VelocityPlateStyleDB)
	InitDB()
	VPS.RestyleAll()
end

--------------------------------------------------------------------------------
-- Text element helpers (VPS_TextElement rows in db.elements)
--------------------------------------------------------------------------------
function VPS.DefaultElement(id)
	for _, e in ipairs(VPS.DEFAULT_ELEMENTS) do if e.id == id then return e end end
	return nil
end

function VPS.IsBuiltinElement(id) return VPS.BUILTIN_ELEMENT_IDS[id] == true end

function VPS.ElementIndex(id)
	for i, e in ipairs(VPS.db.elements) do if e.id == id then return i end end
	return nil
end

-- Moves the element at `index` by `delta` (-1 up / +1 down). Order = stacking order.
function VPS.MoveElement(index, delta)
	local list = VPS.db.elements
	local j = index + delta
	if not list[index] or j < 1 or j > #list then return false end
	list[index], list[j] = list[j], list[index]
	VPS.RestyleAll()
	return true
end

function VPS.AddCustomElement(label, format)
	local d = VPS.db
	local id = "c" .. tostring(d.nextCustomId)
	d.nextCustomId = d.nextCustomId + 1
	d.elements[#d.elements + 1] = { id = id, label = label, format = format, anchor = "inside", align = "left", size = 9, color = "white" }
	VPS.RestyleAll()
	return id
end

function VPS.RemoveElement(id)
	if VPS.IsBuiltinElement(id) then return false end
	local i = VPS.ElementIndex(id)
	if not i then return false end
	table.remove(VPS.db.elements, i)
	VPS.RestyleAll()
	return true
end

--------------------------------------------------------------------------------
-- R7: stand down when a plate-replacement addon owns the plates
--------------------------------------------------------------------------------
local function IsAddOnLoaded(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
	if _G.IsAddOnLoaded then return _G.IsAddOnLoaded(name) end
	return false
end

local function DetectPlateOwner()
	for _, name in ipairs(Client.PlateOwnerAddons() or {}) do
		if IsAddOnLoaded(name) then
			-- ElvUI only counts when its nameplate module is on; it is not in the default list.
			return name
		end
	end
	if IsAddOnLoaded("ElvUI") and ElvUI and type(ElvUI[1]) == "table" and ElvUI[1].private
		and ElvUI[1].private.nameplates and ElvUI[1].private.nameplates.enable then
		return "ElvUI (nameplates)"
	end
	return nil
end

--------------------------------------------------------------------------------
-- Plate lookup
--------------------------------------------------------------------------------
-- Returns the styled object (plate.UnitFrame) for a plate unit, or nil when there is no
-- plate, the frame is forbidden (R6), or it is not the stock unit frame shape.
local function UnitFrameForUnit(unit)
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	local uf = plate and plate.UnitFrame
	if not uf or uf:IsForbidden() then return nil end
	if not Client.HealthBar(uf) then return nil end
	return uf
end
VPS.UnitFrameForUnit = UnitFrameForUnit

-- Iterates every visible, non-forbidden stock unit frame: fn(uf, unit).
local function ForEachUnitFrame(fn)
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
		local uf = plate.UnitFrame
		if uf and not uf:IsForbidden() and Client.HealthBar(uf) then
			fn(uf, plate.namePlateUnitToken or uf.unit)
		end
	end
end
VPS.ForEachUnitFrame = ForEachUnitFrame

--------------------------------------------------------------------------------
-- Styling entry points (Skin.lua does the drawing)
--------------------------------------------------------------------------------
local function StyleUnitFrame(uf, unit)
	if VPS.standDown then return end
	if uf.vpsStyled ~= VPS.styleVersion then
		if not VPS.Guard("ApplyStatic", VPS.Skin.ApplyStatic, uf) then return end
		uf.vpsStyled = VPS.styleVersion
		VPS.InstallFrameHooks(uf)
	end
	if unit then VPS.Guard("ApplyUnit", VPS.Skin.ApplyUnit, uf, unit) end
end

-- Re-run static + per-unit styling on every visible plate. Called by every option change.
function VPS.RestyleAll()
	VPS.styleVersion = VPS.styleVersion + 1
	if VPS.standDown then return end
	ForEachUnitFrame(StyleUnitFrame)
end

--------------------------------------------------------------------------------
-- Post-hooks: Blizzard re-applies texture/anchors/colours; we re-apply only what it undid.
-- Mixin methods are copied onto each frame by Mixin(), so hooking the global mixin table
-- misses frames created before we loaded; hook each frame once when we first style it.
--------------------------------------------------------------------------------
function VPS.InstallFrameHooks(uf)
	if uf.vpsHooked then return end
	uf.vpsHooked = true
	-- UpdateAnchors: re-sets barTexture (atlas/file), bgTexture anchors/layer, name anchors,
	-- HealthBarsContainer height. Fires on every nameplate CVar change.
	if type(uf.UpdateAnchors) == "function" then
		hooksecurefunc(uf, "UpdateAnchors", function(frame)
			if VPS.standDown or frame:IsForbidden() then return end
			VPS.Guard("ReapplyAfterAnchors", VPS.Skin.ReapplyAfterAnchors, frame)
		end)
	end
	-- UpdateSelectionBorder (health bar): shows selectedBorder/deselectedOverlay on target change.
	local hb = Client.HealthBar(uf)
	if hb and type(hb.UpdateSelectionBorder) == "function" then
		hooksecurefunc(hb, "UpdateSelectionBorder", function()
			if VPS.standDown or uf:IsForbidden() then return end
			VPS.Guard("ReapplySelection", VPS.Skin.ReapplySelection, uf)
		end)
	end
end

-- Global CUF functions: one hook each, filter to styled plate frames.
local function InstallGlobalHooks()
	if type(CompactUnitFrame_UpdateLevel) == "function" then
		hooksecurefunc("CompactUnitFrame_UpdateLevel", function(frame)
			if VPS.standDown or not frame.vpsStyled or frame:IsForbidden() then return end
			if frame.unit then VPS.Guard("ApplyTexts/UpdateLevel", VPS.Skin.ApplyTexts, frame, frame.unit) end
		end)
	end
	if type(CompactUnitFrame_UpdateName) == "function" then
		hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
			if VPS.standDown or not frame.vpsStyled or frame:IsForbidden() then return end
			-- Stock re-shows/re-colours uf.name; re-zero it and refresh the name element colour.
			VPS.Guard("ReapplyStockTexts", VPS.Skin.ReapplyStockTexts, frame)
			if frame.unit then VPS.Guard("ApplyTexts/UpdateName", VPS.Skin.ApplyTexts, frame, frame.unit) end
		end)
	end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")

local function OnPlateAdded(unit)
	local uf = UnitFrameForUnit(unit)
	if uf then StyleUnitFrame(uf, unit) end
end

local function OnPlateRemoved(unit)
	local uf = UnitFrameForUnit(unit)
	if uf then VPS.Guard("ClearUnit", VPS.Skin.ClearUnit, uf) end
end

local function OnTargetChanged()
	ForEachUnitFrame(function(uf, unit) if unit then VPS.Guard("ApplyTarget", VPS.Skin.ApplyTarget, uf, unit) end end)
end

-- Any unit event that can change a text element's value: level, name, health. healthOnly
-- restricts the refresh to elements whose format reads health (UNIT_HEALTH is frequent).
local function OnUnitText(unit, healthOnly)
	if type(unit) ~= "string" or not unit:find("^nameplate%d") then return end
	local uf = UnitFrameForUnit(unit)
	if uf and uf.vpsStyled then VPS.Guard("ApplyTexts/event", VPS.Skin.ApplyTexts, uf, unit, healthOnly) end
end

ev:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		InitDB()
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		VPS.standDown = DetectPlateOwner()
		if VPS.standDown then
			VPS.Print(VPS.standDown .. " is managing nameplates; Velocity Plate Style is standing down. Disable it to use this addon.")
			return
		end
		InstallGlobalHooks()
		self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
		self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("UNIT_LEVEL")
		self:RegisterEvent("PLAYER_LEVEL_UP")
		self:RegisterEvent("UNIT_NAME_UPDATE")
		-- Health text is computed in Lua only where UnitHealth is never secret (R5). On Forever the
		-- [hp] tokens expand to "" and there is nothing to refresh.
		if not Client.HasSecretValues() then self:RegisterEvent("UNIT_HEALTH") end
		VPS.RestyleAll()
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		OnPlateAdded(arg1)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		OnPlateRemoved(arg1)
	elseif event == "PLAYER_TARGET_CHANGED" then
		OnTargetChanged()
	elseif event == "UNIT_LEVEL" or event == "UNIT_NAME_UPDATE" then
		OnUnitText(arg1, false)
	elseif event == "UNIT_HEALTH" then
		OnUnitText(arg1, true)
	elseif event == "PLAYER_LEVEL_UP" then
		ForEachUnitFrame(function(uf, unit) if unit then VPS.Skin.ApplyTexts(uf, unit) end end)
	end
end)

--------------------------------------------------------------------------------
-- Status line for /vps status
--------------------------------------------------------------------------------
function VPS.StatusText()
	local lsm = VPS.Textures and VPS.Textures.HasLSM() and "LibSharedMedia present" or "no LibSharedMedia"
	local count = 0
	ForEachUnitFrame(function() count = count + 1 end)
	local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
	local errors = VPS.errorCount > 0 and string.format(" | |cffff4040%d error(s)|r, last: %s", VPS.errorCount, tostring(VPS.lastError)) or " | no errors"
	return string.format("%s | client %s | texture %s | %d plate(s) visible | %s%s%s",
		tostring(version), tostring(Client.flavour), tostring(VPS.db and VPS.db.barTexture),
		count, lsm, errors, VPS.standDown and (" | STANDING DOWN for " .. VPS.standDown) or "")
end
