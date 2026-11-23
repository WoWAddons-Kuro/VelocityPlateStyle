-- Velocity Plate Style: core. Saved variables, the secret-value guard, the plate-owner
-- stand-down (R7), the plate lifecycle (NAME_PLATE_UNIT_ADDED/REMOVED, PLAYER_TARGET_CHANGED,
-- UNIT_LEVEL) and the post-hooks that re-apply our styling after Blizzard re-applies its own.
--
-- Design rules (SPECS\SPEC-VelocityPlateStyle.md): R1 never write a CVar; R2 never show/hide/
-- move a plate or a child we did not create (we alpha-zero); R4 event-driven only; R6 skip
-- forbidden frames; R8 every plate-unit value goes through VPS.Plain before Lua logic.
local ADDON, VPS = ...
local Client = VPS.Client

local VPS_DB_VERSION = 1

-- Account-wide defaults. Keys are documented in the spec's "Saved variables" section.
VPS.DEFAULTS = {
	Version = VPS_DB_VERSION,
	barStyle = "modern",          -- "classic" (Classic Clean) | "modern" (Modern Square)
	barTexture = "VPS:Flat",      -- key into VPS.Textures (Textures.lua)
	barHeight = 12,               -- px, 6..24
	borderDarken = 0.6,           -- Classic Clean: 0 = stock border colour, 1 = black
	backingAlpha = 0.6,           -- Modern Square: alpha of the black backing behind the fill
	targetColor = { 1, 1, 1, 1 },
	targetThickness = 2,          -- px, 1..4
	showLevel = true,             -- Modern Square: level number inside the bar (R3: colour/placement only; the
	                              -- stock representation stays when this is off)
}

VPS.styleVersion = 1          -- bumped on every settings change; uf.vpsStyled ~= styleVersion => restyle
VPS.standDown = nil           -- name of the plate-replacement addon that made us stand down, or nil
VPS.db = nil

local COLOR = "|cff80c0ff"
function VPS.Print(msg) print(COLOR .. "VelocityPlateStyle|r: " .. tostring(msg)) end

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
	CopyDefaults(VelocityPlateStyleDB, VPS.DEFAULTS)
	VelocityPlateStyleDB.Version = VPS_DB_VERSION
	VPS.db = VelocityPlateStyleDB
end

function VPS.ResetToDefaults()
	wipe(VelocityPlateStyleDB)
	CopyDefaults(VelocityPlateStyleDB, VPS.DEFAULTS)
	VPS.db = VelocityPlateStyleDB
	VPS.RestyleAll()
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
		VPS.Skin.ApplyStatic(uf)
		uf.vpsStyled = VPS.styleVersion
		VPS.InstallFrameHooks(uf)
	end
	if unit then VPS.Skin.ApplyUnit(uf, unit) end
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
			VPS.Skin.ReapplyAfterAnchors(frame)
		end)
	end
	-- UpdateSelectionBorder (health bar): shows selectedBorder/deselectedOverlay on target change.
	local hb = Client.HealthBar(uf)
	if hb and type(hb.UpdateSelectionBorder) == "function" then
		hooksecurefunc(hb, "UpdateSelectionBorder", function()
			if VPS.standDown or uf:IsForbidden() then return end
			VPS.Skin.ReapplySelection(uf)
		end)
	end
end

-- Global CUF functions: one hook each, filter to styled plate frames.
local function InstallGlobalHooks()
	if type(CompactUnitFrame_UpdateLevel) == "function" then
		hooksecurefunc("CompactUnitFrame_UpdateLevel", function(frame)
			if VPS.standDown or not frame.vpsStyled or frame:IsForbidden() then return end
			if frame.unit then VPS.Skin.ApplyLevel(frame, frame.unit) end
		end)
	end
	if type(CompactUnitFrame_UpdateName) == "function" then
		hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
			if VPS.standDown or not frame.vpsStyled or frame:IsForbidden() then return end
			VPS.Skin.ReapplyName(frame)
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
	if uf then VPS.Skin.ClearUnit(uf) end
end

local function OnTargetChanged()
	ForEachUnitFrame(function(uf, unit) if unit then VPS.Skin.ApplyTarget(uf, unit) end end)
end

local function OnUnitLevel(unit)
	if type(unit) ~= "string" or not unit:find("^nameplate%d") then return end
	local uf = UnitFrameForUnit(unit)
	if uf and uf.vpsStyled then VPS.Skin.ApplyLevel(uf, unit) end
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
		VPS.RestyleAll()
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		OnPlateAdded(arg1)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		OnPlateRemoved(arg1)
	elseif event == "PLAYER_TARGET_CHANGED" then
		OnTargetChanged()
	elseif event == "UNIT_LEVEL" then
		OnUnitLevel(arg1)
	elseif event == "PLAYER_LEVEL_UP" then
		ForEachUnitFrame(function(uf, unit) if unit then VPS.Skin.ApplyLevel(uf, unit) end end)
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
	return string.format("%s | client %s | style %s/%s | %d plate(s) visible | %s%s",
		tostring(version), tostring(Client.flavour), tostring(VPS.db and VPS.db.barStyle), tostring(VPS.db and VPS.db.barTexture),
		count, lsm, VPS.standDown and (" | STANDING DOWN for " .. VPS.standDown) or "")
end