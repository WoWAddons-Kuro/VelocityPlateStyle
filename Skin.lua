-- Velocity Plate Style: the drawing. Two bar styles (Classic Clean / Modern Square), the
-- target border and the in-bar level number. Every stock region we replace is alpha-zeroed,
-- never hidden or reparented (R2). Our own regions are created once per pooled unit frame
-- (uf.vps*) and re-skinned on every pass, so a recycled frame always reflects the current
-- settings. Region names: _EXTERNAL_APIS\wow_nameplate_unitframe_regions.md.
local ADDON, VPS = ...
local Client = VPS.Client
local Plain = VPS.Plain

local Skin = {}
VPS.Skin = Skin

local WHITE8 = "Interface\\Buttons\\WHITE8x8"
local LEVEL_FONT = "SystemFont_NamePlate_Outlined"
local SKULL_TEXT = "??"
local SKULL_COLOR = { 1, 0.1, 0.1 }

local function db() return VPS.db end
local function IsModern() return db().barStyle == "modern" end

--------------------------------------------------------------------------------
-- Our own regions (created on first use, parented to the health bar)
--------------------------------------------------------------------------------
-- Four 1px textures around a rect; parent is the bar so they move/scale with it.
-- Snap every edge to the pixel grid so 1px lines stay 1 crisp pixel at any UI scale.
local function PixelSnap(t)
	if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(true) end
	if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
end

local function AcquireEdges(parent, key, layer, sublevel)
	local edges = parent[key]
	if edges then return edges end
	edges = {}
	for _, side in ipairs({ "Top", "Bottom", "Left", "Right" }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(WHITE8)
		PixelSnap(t)
		edges[side] = t
	end
	parent[key] = edges
	return edges
end

-- Lays the four edges `thickness` px wide, `inset` px OUTSIDE the rect `rel` (inset >= 0).
local function LayoutEdges(edges, rel, thickness, inset)
	local o = inset
	local t = thickness
	PixelUtil.SetPoint(edges.Top, "BOTTOMLEFT", rel, "TOPLEFT", -o - t, o)
	PixelUtil.SetPoint(edges.Top, "BOTTOMRIGHT", rel, "TOPRIGHT", o + t, o)
	PixelUtil.SetHeight(edges.Top, t)
	PixelUtil.SetPoint(edges.Bottom, "TOPLEFT", rel, "BOTTOMLEFT", -o - t, -o)
	PixelUtil.SetPoint(edges.Bottom, "TOPRIGHT", rel, "BOTTOMRIGHT", o + t, -o)
	PixelUtil.SetHeight(edges.Bottom, t)
	PixelUtil.SetPoint(edges.Left, "TOPRIGHT", rel, "TOPLEFT", -o, o)
	PixelUtil.SetPoint(edges.Left, "BOTTOMRIGHT", rel, "BOTTOMLEFT", -o, -o)
	PixelUtil.SetWidth(edges.Left, t)
	PixelUtil.SetPoint(edges.Right, "TOPLEFT", rel, "TOPRIGHT", o, o)
	PixelUtil.SetPoint(edges.Right, "BOTTOMLEFT", rel, "BOTTOMRIGHT", o, -o)
	PixelUtil.SetWidth(edges.Right, t)
end

local function SetEdges(edges, r, g, b, a, shown)
	for _, t in pairs(edges) do
		t:SetVertexColor(r, g, b, a)
		t:SetShown(shown)
	end
end

local function AcquireOwnRegions(uf)
	local hb = Client.HealthBar(uf)
	if not hb then return nil end
	if not uf.vpsBacking then
		-- Backing: below the fill. The fill (barTexture) is on ARTWORK sublevel 0 of the StatusBar.
		local backing = hb:CreateTexture(nil, "BACKGROUND", nil, -7)
		backing:SetTexture(WHITE8)
		backing:SetVertexColor(0, 0, 0, 1)
		backing:SetAllPoints(hb)
		uf.vpsBacking = backing
		-- 1px outline hugging the bar; drawn above the backing, below foreign icons (which are on
		-- frames of their own with a higher level).
		uf.vpsOutline = AcquireEdges(hb, "vpsOutlineEdges", "BACKGROUND", -6)
		-- Target border: outside the outline.
		uf.vpsTarget = AcquireEdges(hb, "vpsTargetEdges", "BACKGROUND", -5)
		-- Level number inside the bar, right edge.
		local lvl = hb:CreateFontString(nil, "OVERLAY", LEVEL_FONT)
		lvl:SetJustifyH("RIGHT")
		lvl:SetWordWrap(false)
		uf.vpsLevel = lvl
	end
	return hb
end

--------------------------------------------------------------------------------
-- Static styling (per settings version)
--------------------------------------------------------------------------------
local function ApplyFillTexture(uf)
	local hb = Client.HealthBar(uf)
	if not hb then return end
	local key = db().barTexture
	if VPS.Textures.IsStockKey(key) then return end       -- leave Blizzard's fill alone
	local path = VPS.Textures.PathForKey(key)
	local fill = Client.HealthBarFill(uf)
	if fill and path then
		-- Set the texture on the existing barTexture region: colour (reaction) stays stock.
		fill:SetTexture(path)
		fill:SetTexCoord(0, 1, 0, 1)
		fill:SetHorizTile(false)
		fill:SetVertTile(false)
	end
end

local function ApplyBarHeight(uf)
	local container = Client.HealthBarContainer(uf)
	if container then PixelUtil.SetHeight(container, db().barHeight) end
end

-- Modern Square: hide (alpha) the stock backing+border atlas and the non-target darkening,
-- show our backing + outline. Classic Clean: restore stock alphas, darken the stock backing.
local function ApplyBorderStyle(uf)
	local d = db()
	local backingStock = Client.HealthBarBacking(uf)
	local deselected = Client.DeselectedOverlay(uf)
	local hb = Client.HealthBar(uf)
	if IsModern() then
		if backingStock then backingStock:SetAlpha(0) end
		if deselected then deselected:SetAlpha(0) end
		uf.vpsBacking:SetVertexColor(0, 0, 0, d.backingAlpha)
		uf.vpsBacking:Show()
		LayoutEdges(uf.vpsOutline, hb, 1, 0)
		SetEdges(uf.vpsOutline, 0, 0, 0, 1, true)
	else
		if backingStock then
			backingStock:SetAlpha(1)
			local k = 1 - d.borderDarken
			backingStock:SetVertexColor(k, k, k, 1)
		end
		if deselected then deselected:SetAlpha(1) end
		uf.vpsBacking:Hide()
		SetEdges(uf.vpsOutline, 0, 0, 0, 0, false)
	end
end

-- Stock target cues are alpha-zeroed while our border is on (both styles).
local function ApplyStockTargetCueAlpha(uf)
	local selected = Client.SelectedBorder(uf)
	local highlight = Client.SelectionHighlight(uf)
	if selected then selected:SetAlpha(0) end
	if highlight then highlight:SetAlpha(0) end
end

-- Level placement. Modern Square: our FontString inside the bar; Forever's stock level box
-- (PlayerLevelDiffFrame) alpha-zeroed. Classic Clean: ours hidden, stock regions restored.
--
-- Font size is set with SetFont (re-rasterises the glyphs at that size), NOT SetTextHeight,
-- which stretches the already-rendered string and is what makes stock plate text blurry.
local function ApplyLevelFont(lvl)
	local size = math.max(8, math.floor(db().barHeight * 0.75 + 0.5))
	local path, _, flags = lvl:GetFont()
	if not path then
		local fo = _G[LEVEL_FONT]
		if fo then path, _, flags = fo:GetFont() end
	end
	if path then lvl:SetFont(path, size, flags or "OUTLINE") end
end

local function ApplyLevelPlacement(uf)
	local hb = Client.HealthBar(uf)
	local lvl = uf.vpsLevel
	local useOurs = IsModern() and db().showLevel
	for _, region in ipairs(Client.StockLevelRegions(uf) or {}) do
		region:SetAlpha(useOurs and 0 or 1)
	end
	if useOurs then
		lvl:ClearAllPoints()
		PixelUtil.SetPoint(lvl, "RIGHT", hb, "RIGHT", -3, 0)
		ApplyLevelFont(lvl)
		lvl:Show()
	else
		lvl:Hide()
	end
end

-- Keep the stock name clear of our level number (Modern style anchors the name to the
-- health text; when health text is empty the name runs to the bar's right edge).
local function ApplyNameClearance(uf)
	local name = Client.NameText(uf)
	local lvl = uf.vpsLevel
	if not (name and lvl) then return end
	if IsModern() and db().showLevel and lvl:IsShown() then
		-- Only the RIGHT point is ours to move; stock re-sets it in UpdateAnchors, which we hook.
		local w = lvl:GetStringWidth() or 0
		name.vpsRightPad = w + 6
	else
		name.vpsRightPad = nil
	end
end

function Skin.ApplyStatic(uf)
	local hb = AcquireOwnRegions(uf)
	if not hb then return end
	ApplyFillTexture(uf)
	ApplyBarHeight(uf)
	ApplyBorderStyle(uf)
	ApplyStockTargetCueAlpha(uf)
	ApplyLevelPlacement(uf)
	LayoutEdges(uf.vpsTarget, hb, db().targetThickness, IsModern() and 1 or 2)
end

--------------------------------------------------------------------------------
-- Per-unit styling
--------------------------------------------------------------------------------
function Skin.ApplyTarget(uf, unit)
	if not uf.vpsTarget then return end
	local isTarget = Plain(UnitIsUnit(unit, "target"))
	local c = db().targetColor
	SetEdges(uf.vpsTarget, c[1], c[2], c[3], c[4] or 1, isTarget == true)
end

function Skin.ApplyLevel(uf, unit)
	local lvl = uf.vpsLevel
	if not lvl or not (IsModern() and db().showLevel) then return end
	local level = Plain(UnitLevel(unit))
	if level == nil then
		-- secret (Forever restricted content): leave whatever stock shows; show nothing of ours
		lvl:SetText("")
		return
	end
	if level < 0 then
		lvl:SetText(SKULL_TEXT)
		lvl:SetTextColor(SKULL_COLOR[1], SKULL_COLOR[2], SKULL_COLOR[3])
	else
		lvl:SetText(tostring(level))
		local playerLevel = UnitLevel("player") or 1
		local attackable = Plain(UnitCanAttack("player", unit))
		if attackable == false then
			lvl:SetTextColor(0.8, 0.8, 0.8)
		else
			local r, g, b = Client.DifficultyColor(playerLevel, level)
			lvl:SetTextColor(r, g, b)
		end
	end
	Skin.ReapplyName(uf)
end

function Skin.ApplyUnit(uf, unit)
	Skin.ApplyTarget(uf, unit)
	Skin.ApplyLevel(uf, unit)
end

-- The frame is going back to the pool: per-unit cues off so the next unit starts clean.
function Skin.ClearUnit(uf)
	if uf.vpsTarget then SetEdges(uf.vpsTarget, 1, 1, 1, 1, false) end
	if uf.vpsLevel then uf.vpsLevel:SetText("") end
end

--------------------------------------------------------------------------------
-- Re-application after stock code undoes a property (hooks in Core.lua)
--------------------------------------------------------------------------------
-- NamePlateUnitFrameMixin:UpdateAnchors re-sets barTexture, bgTexture anchors/layer, name
-- anchors and container height.
function Skin.ReapplyAfterAnchors(uf)
	if not uf.vpsBacking then return end
	ApplyFillTexture(uf)
	ApplyBarHeight(uf)
	ApplyBorderStyle(uf)
	ApplyLevelPlacement(uf)
	Skin.ReapplyName(uf)
end

-- NamePlateHealthBarMixin:UpdateSelectionBorder re-shows selectedBorder/deselectedOverlay.
function Skin.ReapplySelection(uf)
	ApplyStockTargetCueAlpha(uf)
	if IsModern() then
		local deselected = Client.DeselectedOverlay(uf)
		if deselected then deselected:SetAlpha(0) end
	end
end

-- Stock Modern style anchors the name LEFT to the bar and RIGHT to the health text and
-- left-justifies it, which reads as "right-justified" once the health text is empty and our
-- level sits at the right. In Modern Square we own the name's anchors: centred above the bar,
-- spanning the bar width. UpdateAnchors (hooked) and UpdateName (hooked) both land here.
function Skin.ReapplyName(uf)
	local name = Client.NameText(uf)
	if not name then return end
	local hb = Client.HealthBar(uf)
	if not hb then return end
	if not IsModern() then return end          -- Classic Clean keeps the stock layout
	local container = Client.HealthBarContainer(uf) or hb
	name:ClearAllPoints()
	name:SetJustifyH("CENTER")
	PixelUtil.SetPoint(name, "BOTTOMLEFT", container, "TOPLEFT", 0, 2)
	PixelUtil.SetPoint(name, "BOTTOMRIGHT", container, "TOPRIGHT", 0, 2)
end