-- Velocity Plate Style: Classic Era / Hardcore (1.15.9, interface 11509).
--
-- Era moved to the shared Midnight-style plate code in 1.15.9. Differences from Forever
-- that matter here (see _EXTERNAL_APIS\wow_nameplate_unitframe_regions.md):
--   * no PlayerLevelDiffFrame level box; the stock LevelFrame is only shown in Blizzard's
--     own "Classic" plate style, so in Modern style there is NO stock level text at all.
--   * no secret values: UnitLevel/UnitClassification/UnitHealth of plate units are plain.
local ADDON, VPS = ...
local Client = VPS.Client

local impl = Client.SharedRegionResolvers()

-- Stock regions that display the unit's level. Era: the inert LevelFrame only.
function impl.StockLevelRegions(uf)
	local out = {}
	if uf.LevelFrame then out[#out + 1] = uf.LevelFrame end
	return out
end

function impl.HasSecretValues() return false end
function impl.StockUsesClassicArt() return Client.SharedStockUsesClassicArt() end
function impl.DifficultyColor(playerLevel, unitLevel) return Client.SharedDifficultyColor(playerLevel, unitLevel) end
function impl.PlateOwnerAddons() return Client.SHARED_PLATE_OWNER_ADDONS end

VPS.ClientFlavours.classic_era = impl