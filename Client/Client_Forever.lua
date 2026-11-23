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

VPS.ClientFlavours.forever = impl