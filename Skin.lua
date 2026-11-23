-- Velocity Plate Style: the drawing. Flat bar (backing + 1px outline), target border, and the
-- text element layout engine (spec "Text elements - the layout grid").
--
-- Every stock region we replace is alpha-zeroed, never hidden or reparented (R2). Our own
-- regions are created once per pooled unit frame (uf.vps*) and re-skinned on every pass, so a
-- recycled frame always reflects the current settings.
--
-- Era 1.15.9 hard rule: stock plate regions (uf.name at least) are RESTRICTED - measuring them
-- (GetPoint/GetWidth/GetStringWidth/GetEffectiveScale) raises, and PixelUtil silently fails on
-- them. Writes are fine. We therefore never measure a stock region and never pass one to
-- PixelUtil; every text string on the plate is our own FontString.
local ADDON, VPS = ...
local Client = VPS.Client
local Plain = VPS.Plain
local Format = VPS.Format

local Skin = {}
VPS.Skin = Skin

local WHITE8 = "Interface\\Buttons\\WHITE8x8"
local TEXT_FONT = "SystemFont_NamePlate_Outlined"
local SKULL_COLOR = { 1, 0.1, 0.1 }
local GAP = 4            -- px between elements flowing in one group, and between a side column and the bar
local ROW_OFF = 2        -- px between the bar outline and an above/below row

local function db() return VPS.db end

--------------------------------------------------------------------------------
-- Our own regions (created on first use, parented to the health bar)
--------------------------------------------------------------------------------
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

-- Lays the four edges `thickness` px wide, `inset` px OUTSIDE the rect `rel` (our own regions only).
local function LayoutEdges(edges, rel, thickness, inset)
	local o, t = inset, thickness
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
		local backing = hb:CreateTexture(nil, "BACKGROUND", nil, -7)
		backing:SetTexture(WHITE8)
		backing:SetVertexColor(0, 0, 0, 1)
		backing:SetAllPoints(hb)
		uf.vpsBacking = backing
		uf.vpsOutline = AcquireEdges(hb, "vpsOutlineEdges", "BACKGROUND", -6)
		uf.vpsTarget = AcquireEdges(hb, "vpsTargetEdges", "BACKGROUND", -5)
		uf.vpsText = {}          -- VPS_ElementID -> FontString
	end
	return hb
end

-- One FontString per element id, created on demand and parented to the bar.
local function AcquireText(uf, hb, id)
	local fs = uf.vpsText[id]
	if fs then return fs end
	fs = hb:CreateFontString(nil, "OVERLAY", TEXT_FONT)
	fs:SetWordWrap(false)
	uf.vpsText[id] = fs
	return fs
end

-- SetFont (re-rasterise at size), never SetTextHeight (stretches, blurry).
local function ApplyFont(fs, size)
	local path, _, flags = fs:GetFont()
	if not path then
		local fo = _G[TEXT_FONT]
		if fo then path, _, flags = fo:GetFont() end
	end
	if path then fs:SetFont(path, size, flags or "OUTLINE") end
end

--------------------------------------------------------------------------------
-- Static styling (per settings version)
--------------------------------------------------------------------------------
local function ApplyFillTexture(uf)
	local key = db().barTexture
	if VPS.Textures.IsStockKey(key) then return end
	local path = VPS.Textures.PathForKey(key)
	local fill = Client.HealthBarFill(uf)
	if fill and path then
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

-- Stock backing+border atlas and non-target darkening off; our backing + outline on.
local function ApplyBorderStyle(uf)
	local backingStock = Client.HealthBarBacking(uf)
	local deselected = Client.DeselectedOverlay(uf)
	local hb = Client.HealthBar(uf)
	if backingStock then backingStock:SetAlpha(0) end
	if deselected then deselected:SetAlpha(0) end
	uf.vpsBacking:SetVertexColor(0, 0, 0, db().backingAlpha)
	uf.vpsBacking:Show()
	LayoutEdges(uf.vpsOutline, hb, 1, 0)
	SetEdges(uf.vpsOutline, 0, 0, 0, 1, true)
end

-- Stock target cues off while our border is on.
local function ApplyStockTargetCueAlpha(uf)
	local selected = Client.SelectedBorder(uf)
	local highlight = Client.SelectionHighlight(uf)
	if selected then selected:SetAlpha(0) end
	if highlight then highlight:SetAlpha(0) end
end

-- Every stock text we replace with our own elements: name, health strings, level regions.
function Skin.ReapplyStockTexts(uf)
	if not Skin.IsBarMode(uf) then Skin.RestoreStock(uf); return end
	local name = Client.NameText(uf)
	if name then name:SetAlpha(0) end
	for _, fs in ipairs(Client.HealthTexts(uf) or {}) do fs:SetAlpha(0) end
	for _, region in ipairs(Client.StockLevelRegions(uf) or {}) do region:SetAlpha(0) end
end

-- A plate is only ours to restyle while Blizzard draws its health bar. Friendly NPCs/players
-- with "show only names" (and simplified / widgets-only plates) have the bar Hide()-den and
-- the stock name standing alone where the bar would be; those plates stay exactly stock.
function Skin.IsBarMode(uf)
	local hb = Client.HealthBar(uf)
	if not hb or not hb:IsShown() then return false end
	if uf.IsShowOnlyName and uf:IsShowOnlyName() then return false end
	if uf.widgetsOnlyMode then return false end
	return true
end

-- Put every stock region we touch back to its default alpha and hide our own regions.
function Skin.RestoreStock(uf)
	local name = Client.NameText(uf)
	if name then name:SetAlpha(1) end
	for _, fs in ipairs(Client.HealthTexts(uf) or {}) do fs:SetAlpha(1) end
	for _, region in ipairs(Client.StockLevelRegions(uf) or {}) do region:SetAlpha(1) end
	local backingStock = Client.HealthBarBacking(uf)
	local deselected = Client.DeselectedOverlay(uf)
	local selected = Client.SelectedBorder(uf)
	local highlight = Client.SelectionHighlight(uf)
	if backingStock then backingStock:SetAlpha(1); backingStock:SetVertexColor(1, 1, 1, 1) end
	if deselected then deselected:SetAlpha(1) end
	if selected then selected:SetAlpha(1) end
	if highlight then highlight:SetAlpha(0.25) end          -- XML default alpha
	if uf.vpsBacking then uf.vpsBacking:Hide() end
	if uf.vpsOutline then SetEdges(uf.vpsOutline, 0, 0, 0, 0, false) end
	if uf.vpsTarget then SetEdges(uf.vpsTarget, 1, 1, 1, 1, false) end
	if uf.vpsText then for _, fs in pairs(uf.vpsText) do fs:Hide(); fs.vpsVisible = false end end
	uf.vpsStockMode = true
end

function Skin.ApplyStatic(uf)
	local hb = AcquireOwnRegions(uf)
	if not hb then return end
	if not Skin.IsBarMode(uf) then Skin.RestoreStock(uf); return end
	uf.vpsStockMode = nil
	ApplyFillTexture(uf)
	ApplyBarHeight(uf)
	ApplyBorderStyle(uf)
	ApplyStockTargetCueAlpha(uf)
	Skin.ReapplyStockTexts(uf)
	LayoutEdges(uf.vpsTarget, hb, db().targetThickness, 1)
	-- Fonts for every element; hide strings for elements that no longer exist.
	local live = {}
	for _, e in ipairs(db().elements) do
		live[e.id] = true
		ApplyFont(AcquireText(uf, hb, e.id), e.size or 9)
	end
	for id, fs in pairs(uf.vpsText) do if not live[id] then fs:Hide(); fs:SetText("") end end
end

--------------------------------------------------------------------------------
-- Text elements: value + colour
--------------------------------------------------------------------------------
local function ColorFor(uf, e, unit, level)
	local mode = e.color
	if e.id == "level" then mode = "difficulty" end                         -- R3
	if mode == "custom" and type(e.customColor) == "table" then
		local c = e.customColor; return c[1] or 1, c[2] or 1, c[3] or 1
	elseif mode == "difficulty" then
		if level == nil then return 1, 1, 1 end
		if level < 0 then return SKULL_COLOR[1], SKULL_COLOR[2], SKULL_COLOR[3] end
		if Plain(UnitCanAttack("player", unit)) == false then return 0.8, 0.8, 0.8 end
		return Client.DifficultyColor(UnitLevel("player") or 1, level)
	elseif mode == "class" then
		local _, class = UnitClass(unit)
		class = Plain(class)
		local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b end
		return 1, 1, 1
	elseif mode == "stock" then
		-- Copy the stock name's reaction/tap colour (reading vertex colour is not a measurement).
		local name = Client.NameText(uf)
		if name then
			local ok, r, g, b = pcall(name.GetTextColor, name)
			if ok and r then return r, g, b end
		end
		return 1, 1, 1
	end
	return 1, 1, 1
end

-- Fills every element's text + colour for `unit`. healthOnly: only formats that read health.
-- Returns true when any element's shown-state or text changed (caller relays out).
function Skin.ApplyTexts(uf, unit, healthOnly)
	if not uf.vpsText then return end
	if uf.vpsStockMode or not Skin.IsBarMode(uf) then Skin.RestoreStock(uf); return end
	local hb = Client.HealthBar(uf)
	if not hb then return end
	local level = Plain(UnitLevel(unit))
	local changed = false
	for _, e in ipairs(db().elements) do
		if not healthOnly or Format.UsesHealth(e.format) then
			local fs = AcquireText(uf, hb, e.id)
			local text
			if Format.IsBareName(e.format) then
				-- Display-only pass-through: a secret name may go straight to SetText (BUG 12 pattern 1).
				text = UnitName(unit)
				if text == nil then text = "" end
			else
				text = Format.ExpandOrEmpty(e.format, unit)
			end
			local visible = e.anchor ~= "hidden" and not (type(text) == "string" and text == "")
			if fs.vpsVisible ~= visible then changed = true end
			fs.vpsVisible = visible
			fs:SetText(text)
			fs:SetTextColor(ColorFor(uf, e, unit, level))
			fs:SetShown(visible)
			if visible and not Format.IsBareName(e.format) then
				local w = fs:GetStringWidth() or 0
				if fs.vpsWidth ~= w then changed = true end
				fs.vpsWidth = w
			else
				changed = true     -- bare-name width may be a secret; always relayout
			end
		end
	end
	Skin.LayoutTexts(uf)
	Skin.ApplyOverLevel(uf, unit)        -- same input (UnitLevel); every level/name refresh path lands here
	return changed
end

--------------------------------------------------------------------------------
-- Text elements: the flow layout
--------------------------------------------------------------------------------
-- Six slots on the bar. above/below/inside are horizontal rows: elements grouped by align
-- (left/center/right) flow from that edge in list order with GAP between them. left/right
-- are vertical columns beside the bar: align top/middle/bottom is which baseline lines up with
-- the bar; elements in one group flow outward (away from the bar) in list order.

-- Horizontal row anchoring. `rowPoint` is the bar point the row hangs off ("TOP" for above,
-- "BOTTOM" for below, "" for inside) and `yOff` its offset.
local function LayoutRow(fsList, hb, slot)
	local yOff, barPointV, fsPointV
	if slot == "above" then yOff, barPointV, fsPointV = ROW_OFF, "TOP", "BOTTOM"
	elseif slot == "below" then yOff, barPointV, fsPointV = -ROW_OFF, "BOTTOM", "TOP"
	else yOff, barPointV, fsPointV = 0, "", "" end
	local groups = { left = {}, center = {}, right = {} }
	for _, item in ipairs(fsList) do
		local g = groups[item.align] or groups.left
		g[#g + 1] = item.fs
	end
	-- Overflow policy: the RIGHT group is laid first (fixed-width values: level, health). The
	-- LEFT group's last element and the CENTER chain are then bounded on the right by the
	-- innermost right element, so a long name truncates with "..." instead of running under it.
	local inset = slot == "inside" and 3 or 0
	-- right group: first at bar right, next to its left
	local prev
	local rightInner           -- the right-group element nearest the bar's centre, if any
	for _, fs in ipairs(groups.right) do
		fs:ClearAllPoints()
		fs:SetJustifyH("RIGHT")
		fs:SetWidth(0)                         -- natural width
		if prev then PixelUtil.SetPoint(fs, fsPointV .. "RIGHT", prev, fsPointV .. "LEFT", -GAP, 0)
		else PixelUtil.SetPoint(fs, fsPointV .. "RIGHT", hb, barPointV .. "RIGHT", -inset, yOff) end
		prev = fs
		rightInner = fs
	end
	-- left group: first at bar left, next to its right; the last one is bounded on the right
	prev = nil
	local n = #groups.left
	for i, fs in ipairs(groups.left) do
		fs:ClearAllPoints()
		fs:SetJustifyH("LEFT")
		fs:SetWidth(0)
		if prev then PixelUtil.SetPoint(fs, fsPointV .. "LEFT", prev, fsPointV .. "RIGHT", GAP, 0)
		else PixelUtil.SetPoint(fs, fsPointV .. "LEFT", hb, barPointV .. "LEFT", inset, yOff) end
		if i == n then
			-- Two-point anchor: width = free space, text truncates. (SetWordWrap(false) is set at creation.)
			if rightInner then PixelUtil.SetPoint(fs, fsPointV .. "RIGHT", rightInner, fsPointV .. "LEFT", -GAP, 0)
			else PixelUtil.SetPoint(fs, fsPointV .. "RIGHT", hb, barPointV .. "RIGHT", -inset, yOff) end
		end
		prev = fs
	end
	local leftOuter = groups.left[n]      -- the left-group element nearest the centre, if any
	-- center group: first centred; the rest alternate right/left of the chain
	local first = groups.center[1]
	if first then
		first:ClearAllPoints()
		first:SetJustifyH("CENTER")
		first:SetWidth(0)
		if #groups.center == 1 and (leftOuter or rightInner) then
			-- Single centred element with neighbours: span the free space so it truncates rather
			-- than overlapping. (The left group's last element then truncates against the bar edge;
			-- re-bound it to this element instead.)
			if leftOuter then PixelUtil.SetPoint(first, fsPointV .. "LEFT", leftOuter, fsPointV .. "RIGHT", GAP, 0)
			else PixelUtil.SetPoint(first, fsPointV .. "LEFT", hb, barPointV .. "LEFT", inset, yOff) end
			if rightInner then PixelUtil.SetPoint(first, fsPointV .. "RIGHT", rightInner, fsPointV .. "LEFT", -GAP, 0)
			else PixelUtil.SetPoint(first, fsPointV .. "RIGHT", hb, barPointV .. "RIGHT", -inset, yOff) end
			if leftOuter then
				leftOuter:ClearAllPoints()
				leftOuter:SetJustifyH("LEFT")
				leftOuter:SetWidth(0)
				local before = groups.left[n - 1]
				if before then PixelUtil.SetPoint(leftOuter, fsPointV .. "LEFT", before, fsPointV .. "RIGHT", GAP, 0)
				else PixelUtil.SetPoint(leftOuter, fsPointV .. "LEFT", hb, barPointV .. "LEFT", inset, yOff) end
			end
		else
			PixelUtil.SetPoint(first, fsPointV == "" and "CENTER" or fsPointV, hb, barPointV == "" and "CENTER" or barPointV, 0, yOff)
		end
		local rightMost, leftMost = first, first
		for i = 2, #groups.center do
			local fs = groups.center[i]
			fs:ClearAllPoints()
			fs:SetWidth(0)
			if i % 2 == 0 then
				fs:SetJustifyH("LEFT")
				PixelUtil.SetPoint(fs, fsPointV .. "LEFT", rightMost, fsPointV .. "RIGHT", GAP, 0); rightMost = fs
			else
				fs:SetJustifyH("RIGHT")
				PixelUtil.SetPoint(fs, fsPointV .. "RIGHT", leftMost, fsPointV .. "LEFT", -GAP, 0); leftMost = fs
			end
		end
	end
end

-- Side column anchoring: left/right of the bar, outside the outline + GAP.
local function LayoutColumn(fsList, hb, slot)
	local outward = slot == "left" and -1 or 1
	local barSide = slot == "left" and "LEFT" or "RIGHT"
	local nearSide = slot == "left" and "RIGHT" or "LEFT"     -- the FontString side that faces the bar
	local groups = { top = {}, middle = {}, bottom = {} }
	for _, item in ipairs(fsList) do
		local g = groups[item.align] or groups.middle
		g[#g + 1] = item.fs
	end
	for valign, list in pairs(groups) do
		local v = valign == "top" and "TOP" or valign == "bottom" and "BOTTOM" or ""
		local prev
		for _, fs in ipairs(list) do
			fs:ClearAllPoints()
			fs:SetJustifyH(slot == "left" and "RIGHT" or "LEFT")
			if prev then PixelUtil.SetPoint(fs, v .. nearSide, prev, v .. barSide, outward * GAP, 0)
			else PixelUtil.SetPoint(fs, v .. nearSide, hb, v .. barSide, outward * (GAP + 1), 0) end
			prev = fs
		end
	end
end

function Skin.LayoutTexts(uf)
	if not uf.vpsText then return end
	local hb = Client.HealthBar(uf)
	if not hb then return end
	local slots = { above = {}, below = {}, inside = {}, left = {}, right = {} }
	for _, e in ipairs(db().elements) do
		local fs = uf.vpsText[e.id]
		if fs and fs.vpsVisible and slots[e.anchor] then
			local list = slots[e.anchor]
			list[#list + 1] = { fs = fs, align = e.align }
		end
	end
	LayoutRow(slots.above, hb, "above")
	LayoutRow(slots.below, hb, "below")
	LayoutRow(slots.inside, hb, "inside")
	LayoutColumn(slots.left, hb, "left")
	LayoutColumn(slots.right, hb, "right")
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

function Skin.ApplyUnit(uf, unit)
	Skin.ApplyTarget(uf, unit)
	Skin.ApplyTexts(uf, unit)        -- also refreshes the over-level highlight
end

--------------------------------------------------------------------------------
-- Over-level highlight: unitLevel >= playerLevel + threshold, or skull.
--
-- "animated" / "animatedRed" (owner's spec, 2026-11-23): the bar keeps Blizzard's own fill colour
-- (red hostile / yellow neutral) and we ADD one layer over it: the SharedMedia "Perl" statusbar
-- texture (Assets\perl.tga, from EasyFrames), vertex-coloured the COMPLEMENTARY colour - yellow
-- over a red bar, red over a yellow bar - additive blend, with its UVs scrolled left-to-right by a
-- looping TextureCoordTranslation (the client-side mechanism Blizzard's own aggro flare uses).
-- No Lua runs per frame (R4). "animated" = the same, but a fixed gold overlay instead of the
-- complementary colour. Rejected on the way here: the 10.x proc flipbook (58cb482), dense
-- diagonal stripes (9f5b39e), a single white sweep band (0d5e14f).
-- Red modes also turn the 1px outline and the name element red. "red": static, no sheen.
--------------------------------------------------------------------------------
local OVER_LEVEL_RED = { 1, 0.15, 0.1 }
local OVER_LEVEL_YELLOW = { 1, 0.85, 0.1 }
local GLOW_TEXTURE = "Interface\\AddOns\\" .. ADDON .. "\\Assets\\perl.tga"
local GLOW_SWEEP_SEC = 1.4                           -- time for the Perl pattern to travel one full bar width
local GLOW_ALPHA = 0.9
local GLOW_PAD = 0                                   -- stays inside the 1px outline

local function AcquireGlow(uf, hb)
	if uf.vpsGlow then return uf.vpsGlow end
	-- OVERLAY sublevel -1: a StatusBar composites its fill ABOVE its BACKGROUND/BORDER/ARTWORK
	-- regions, so anything meant to sit on top of the fill must be OVERLAY (our text is OVERLAY 0
	-- and visibly draws over the fill; the same texture on ARTWORK 1 was fully occluded - 3 builds
	-- of "nothing changed", 9f5b39e..1b57f85).
	local tex = hb:CreateTexture(nil, "OVERLAY", nil, -1)
	tex:SetTexture(GLOW_TEXTURE)
	tex:SetHorizTile(true)
	tex:SetVertTile(false)
	tex:SetBlendMode("ADD")
	tex:SetAlpha(GLOW_ALPHA)
	tex:Hide()
	local scrollGroup = tex:CreateAnimationGroup()
	scrollGroup:SetLooping("REPEAT")
	local scroll = scrollGroup:CreateAnimation("TextureCoordTranslation")
	-- The tile is mapped once across the bar (U 0..1), so an offset of -1 per cycle moves the
	-- single band the full bar width left-to-right.
	scroll:SetOffset(-1, 0); scroll:SetDuration(GLOW_SWEEP_SEC)
	uf.vpsGlow = { tex = tex, scrollGroup = scrollGroup }
	return uf.vpsGlow
end

local function LayoutGlow(glow, hb)
	glow.tex:ClearAllPoints()
	PixelUtil.SetPoint(glow.tex, "TOPLEFT", hb, "TOPLEFT", -GLOW_PAD, GLOW_PAD)
	PixelUtil.SetPoint(glow.tex, "BOTTOMRIGHT", hb, "BOTTOMRIGHT", GLOW_PAD, -GLOW_PAD)
	glow.tex:SetTexCoord(0, 1, 0, 1)     -- one band per bar width
end

-- Overlay colour. "animatedRed": the complement of the bar's own fill colour - yellow over a
-- red (hostile) bar, red over a yellow (neutral) bar - so the sweep contrasts whatever Blizzard
-- painted. "animated": a fixed yellow. Reading the StatusBar's colour is not a measurement.
local function GlowColor(mode, hb)
	if mode ~= "animatedRed" then return OVER_LEVEL_YELLOW[1], OVER_LEVEL_YELLOW[2], OVER_LEVEL_YELLOW[3] end
	local ok, r, g = pcall(hb.GetStatusBarColor, hb)
	-- yellow-ish bar (neutral): g high relative to r  ->  red overlay. Otherwise -> yellow overlay.
	if ok and r and g and g > 0.5 then
		return OVER_LEVEL_RED[1], OVER_LEVEL_RED[2], OVER_LEVEL_RED[3]
	end
	return OVER_LEVEL_YELLOW[1], OVER_LEVEL_YELLOW[2], OVER_LEVEL_YELLOW[3]
end

function Skin.IsOverLevel(unit)
	local level = Plain(UnitLevel(unit))
	if level == nil then return false end
	if level < 0 then return true end
	local attackable = Plain(UnitCanAttack("player", unit))
	if attackable == false then return false end
	return level >= (UnitLevel("player") or 1) + (db().overLevelThreshold or 3)
end

function Skin.ApplyOverLevel(uf, unit)
	local hb = Client.HealthBar(uf)
	if not hb or not uf.vpsOutline then return end
	local mode = db().overLevelMode or "none"
	local on = mode ~= "none" and Skin.IsOverLevel(unit)
	local isRed = mode == "red" or mode == "animatedRed"
	-- every red mode turns the 1px outline red so the cue reads at any bar size
	if on and isRed then SetEdges(uf.vpsOutline, OVER_LEVEL_RED[1], OVER_LEVEL_RED[2], OVER_LEVEL_RED[3], 1, true)
	else SetEdges(uf.vpsOutline, 0, 0, 0, 1, true) end
	-- Text colours are never touched by the highlight (owner rule 2026-11-23): the name keeps whatever
	-- its element's colour mode says. Sweep layer:
	local wantGlow = on and (mode == "animated" or mode == "animatedRed")
	local glow = uf.vpsGlow or (wantGlow and AcquireGlow(uf, hb))
	if not glow then return end
	if wantGlow then
		glow.tex:SetVertexColor(GlowColor(mode, hb))
		LayoutGlow(glow, hb)
		glow.tex:Show()
		if not glow.scrollGroup:IsPlaying() then glow.scrollGroup:Play() end
	elseif glow.tex:IsShown() then
		glow.scrollGroup:Stop()
		glow.tex:Hide()
	end
end

-- The frame is going back to the pool: per-unit cues off so the next unit starts clean.
function Skin.ClearUnit(uf)
	if uf.vpsTarget then SetEdges(uf.vpsTarget, 1, 1, 1, 1, false) end
	if uf.vpsText then for _, fs in pairs(uf.vpsText) do fs:SetText(""); fs.vpsVisible = false; fs:Hide() end end
end

--------------------------------------------------------------------------------
-- Re-application after stock code undoes a property (hooks in Core.lua)
--------------------------------------------------------------------------------
-- NamePlateUnitFrameMixin:UpdateAnchors re-sets barTexture, bgTexture anchors/layer, the
-- stock name anchors and container height.
function Skin.ReapplyAfterAnchors(uf)
	if not uf.vpsBacking then return end
	-- Show-only-name / simplified state may have flipped; UpdateAnchors runs on every such change.
	if not Skin.IsBarMode(uf) then Skin.RestoreStock(uf); return end
	if uf.vpsStockMode then Skin.ApplyStatic(uf); if uf.unit then Skin.ApplyTexts(uf, uf.unit) end; return end
	ApplyFillTexture(uf)
	ApplyBarHeight(uf)
	ApplyBorderStyle(uf)
	Skin.ReapplyStockTexts(uf)
	Skin.LayoutTexts(uf)
end

-- NamePlateHealthBarMixin:UpdateSelectionBorder re-shows selectedBorder/deselectedOverlay.
function Skin.ReapplySelection(uf)
	if not Skin.IsBarMode(uf) then return end
	ApplyStockTargetCueAlpha(uf)
	local deselected = Client.DeselectedOverlay(uf)
	if deselected then deselected:SetAlpha(0) end
end