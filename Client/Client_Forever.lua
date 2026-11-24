-- Velocity Plate Style: WoW Forever (Camelot flavour, 1.60.x, interface 16001).
--
-- Same Midnight-style plate code as Era 1.15.9, plus (see
-- _EXTERNAL_APIS\wow_nameplate_unitframe_regions.md):
--   * uf.PlayerLevelDiffFrame is a real level box drawn beside the bar
--     (Camelot\Blizzard_NamePlateLevelFrame: playerLevelDiffText, highLevelTexture, selectedBorder).
--   * SECRET VALUES (BUG 12): UnitHealth, UnitThreatSituation and hostile UnitName/UnitGUID of
--     nameplate units can be secret. HasSecretValues() = true routes Skin/Core to the
--     restyle-only paths; every unit read still goes through VPS.Plain.
local ADDON, VPS = ...
local Client = VPS.Client

local impl = Client.SharedRegionResolvers()

-- Stock regions that display the unit's level: the inert LevelFrame and the Camelot level box.
function impl.StockLevelRegions(uf)
	local out = {}
	if uf.LevelFrame then out[#out + 1] = uf.LevelFrame end
	if uf.PlayerLevelDiffFrame then out[#out + 1] = uf.PlayerLevelDiffFrame end
	return out
end

function impl.HasSecretValues() return true end
-- UnitHealth of a hostile is secret here, so our Health element adopts the game's own health
-- string. TextStatusBarMixin:UpdateTextStringWithValues (Blizzard_TextStatusBar) writes:
--   * Health Value only           -> hb.Text  ("86")
--   * Health Percentage only      -> hb.Text  ("72%")
--   * both ticked                 -> hb.RightText = value, hb.LeftText = percent; hb.Text hidden
-- hb.Text is therefore the right string for the common single-option cases (confirmed in game
-- 2026-11-23: RightText stayed "" with only Health Value on). Both-ticked shows nothing in our
-- element and the two stock strings fall back to stock placement; acceptable for now.
function impl.StockHealthValueText(uf) local hb = Client.HealthBar(uf); return hb and hb.Text end
function impl.StockUsesClassicArt() return Client.SharedStockUsesClassicArt() end
function impl.DifficultyColor(playerLevel, unitLevel) return Client.SharedDifficultyColor(playerLevel, unitLevel) end
function impl.PlateOwnerAddons() return Client.SHARED_PLATE_OWNER_ADDONS end

-- Names. Forever characters (players AND mobs) have a first name and a surname; UnitName(unit)
-- returns them as two values (the surname rides in the old "server" slot; Camelot NameUtil.lua
-- confirms: `local name, surname = UnitName(unit)`). The stock plate displays
--   GetUnitName(unit, updateNameUsesGetUnitName and not hideRealmName)      (CompactUnitFrame.lua:843)
-- where hideRealmName is true only for a friendly PLAYER while the CVar
-- nameplateShowFriendlyRealmName is off (NamePlateUnitFrameMixin:UpdateNameRealmDisplay).
-- We call the same GetUnitName so the join is Blizzard's, not ours.
local SHOW_FRIENDLY_REALM_NAME_CVAR = "nameplateShowFriendlyRealmName"

function impl.UnitShowsFullName(unit)
	local Plain = VPS.Plain
	local isFriend = Plain(UnitIsFriend("player", unit))
	local isPlayer = Plain(UnitIsPlayer(unit))
	-- A secret flag (hostile in restricted content) can only belong to a unit that shows the full
	-- name anyway, so "unknown" resolves to true.
	if isFriend == true and isPlayer == true then
		return GetCVarBool(SHOW_FRIENDLY_REALM_NAME_CVAR) == true
	end
	return true
end

function impl.UnitDisplayName(unit)
	local Plain = VPS.Plain
	local first, second = UnitName(unit)
	if first == nil then return nil end
	-- Either half secret: GetUnitName would concatenate a secret and raise. Hand back the raw first
	-- return for a display-only SetText (BUG 12 pattern 1); the caller never compares it.
	if Plain(first) == nil or (second ~= nil and Plain(second) == nil) then return first end
	if type(GetUnitName) == "function" then
		return GetUnitName(unit, impl.UnitShowsFullName(unit))
	end
	if second and second ~= "" and impl.UnitShowsFullName(unit) then return first .. " " .. second end
	return first
end

VPS.ClientFlavours.forever = impl