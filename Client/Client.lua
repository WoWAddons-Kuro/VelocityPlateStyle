-- Velocity Plate Style: the client interface. Skin.lua and Core.lua only ever call
-- VPS.Client.*; they never touch a Blizzard region name or a WOW_PROJECT_ID directly.
-- One implementation file per game flavour conforms to the interface declared here:
--
--   Client/Client_ClassicEra.lua  Classic Era / Hardcore (1.15.9, interface 11509)
--   Client/Client_Forever.lua     WoW Forever (Camelot flavour, 1.60.x, interface 16001)
--
-- Load order (TOC): Client.lua, every Client_*.lua, then Client_Select.lua picks the
-- flavour and verifies the method set. Region names come from Blizzard's own source:
-- AddonManagement\_EXTERNAL_APIS\wow_nameplate_unitframe_regions.md.
--
-- Every region resolver takes the plate's unit frame (plate.UnitFrame) and returns the
-- region or nil. nil means "this client has no such thing"; the caller degrades to stock.
local ADDON, VPS = ...

local Client = {}
VPS.Client = Client
VPS.ClientFlavours = {}  -- flavour name -> implementation table, filled by the flavour files

Client.INTERFACE = {
	-- Regions ----------------------------------------------------------------------
	"HealthBar",            -- (uf) -> StatusBar   the fill bar (uf.HealthBarsContainer.healthBar)
	"HealthBarFill",        -- (uf) -> Texture     the bar's fill texture (healthBar.barTexture)
	"HealthBarBacking",     -- (uf) -> Texture     stock backing+border atlas (healthBar.bgTexture)
	"HealthBarContainer",   -- (uf) -> Frame       the frame whose height is the bar height
	"SelectedBorder",       -- (uf) -> Texture     stock target border (Modern style)
	"DeselectedOverlay",    -- (uf) -> Texture     stock darkening of non-target bars (Modern style)
	"SelectionHighlight",   -- (uf) -> Texture     stock target brighten (Classic style)
	"NameText",             -- (uf) -> FontString
	"HealthTexts",          -- (uf) -> { FontString, ... }  the stock health text strings
	"StockLevelRegions",    -- (uf) -> { Region, ... }      every stock region that shows the level (may be empty)
	"ClassificationIcon",   -- (uf) -> Texture|nil
	"AggroGlowTextures",    -- (uf) -> { Texture, ... }    the stock aggro flare pieces
	-- Capabilities / helpers ------------------------------------------------------
	"HasSecretValues",      -- () -> boolean     true on clients where non-player unit values can be secret (BUG 12)
	"StockHealthValueText", -- (uf) -> FontString|nil  the ONE stock string the game fills with the unit's current health
	                        --   value when Options > Nameplates > "Health Value" is on (healthBar.RightText). Where
	                        --   HasSecretValues() is true this is the only way to show health: our Health element
	                        --   ADOPTS it (re-anchor, re-font) instead of computing [hp]. nil = client has no such string.
	"StockUsesClassicArt",  -- () -> boolean     true while Blizzard's own "Classic" nameplate style is selected
	"DifficultyColor",      -- (playerLevel, unitLevel) -> r, g, b
	"PlateOwnerAddons",     -- () -> { addonName, ... }  plate-replacement addons that trigger the R7 stand-down
}

--------------------------------------------------------------------------------
-- Shared helpers for the flavour files (identical on every client).
--------------------------------------------------------------------------------

-- The shared Midnight-style plate layout. Both clients use it; a flavour file may
-- override any entry after copying this table.
function Client.SharedRegionResolvers()
	return {
		HealthBar = function(uf) return uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar end,
		HealthBarFill = function(uf) local hb = Client.HealthBar(uf); return hb and hb.barTexture end,
		HealthBarBacking = function(uf) local hb = Client.HealthBar(uf); return hb and hb.bgTexture end,
		HealthBarContainer = function(uf) return uf.HealthBarsContainer end,
		SelectedBorder = function(uf) local hb = Client.HealthBar(uf); return hb and hb.selectedBorder end,
		DeselectedOverlay = function(uf) local hb = Client.HealthBar(uf); return hb and hb.deselectedOverlay end,
		SelectionHighlight = function(uf) return uf.selectionHighlight end,
		NameText = function(uf) return uf.name end,
		HealthTexts = function(uf)
			local hb = Client.HealthBar(uf)
			if not hb then return {} end
			return { hb.Text, hb.RightText, hb.LeftText }
		end,
		ClassificationIcon = function(uf) return uf.ClassificationFrame and uf.ClassificationFrame.classificationIndicator end,
		AggroGlowTextures = function(uf) return uf.aggroHighlightTextures or {} end,
	}
end

-- Blizzard's own style switch: NamePlateSetupOptions.useClassicHealthBar is set by
-- NamePlateDriverMixin:UpdateNamePlateOptions from the nameplateStyle CVar. Read-only for us.
function Client.SharedStockUsesClassicArt()
	return NamePlateSetupOptions ~= nil and NamePlateSetupOptions.useClassicHealthBar == true
end

-- GetRelativeDifficultyColor exists on both clients (CompactUnitFrame_UpdateLevel uses it).
-- Falls back to the quest-difficulty function, then to white.
function Client.SharedDifficultyColor(playerLevel, unitLevel)
	local c
	if type(GetRelativeDifficultyColor) == "function" then
		c = GetRelativeDifficultyColor(playerLevel, unitLevel)
	elseif type(GetQuestDifficultyColor) == "function" then
		c = GetQuestDifficultyColor(unitLevel)
	end
	if type(c) == "table" and c.r then return c.r, c.g, c.b end
	return 1, 1, 1
end

Client.SHARED_PLATE_OWNER_ADDONS = {
	"TidyPlates_ThreatPlates", "TidyPlates", "Plater", "KuiNameplates", "NeatPlates", "Platynator",
	"NamePlateKAI", "BetterBlizzPlates",
}