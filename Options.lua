-- Velocity Plate Style: options page and slash command.
--
-- Canvas category in the GotJunk style (Settings.RegisterCanvasLayoutCategory, fallback
-- InterfaceOptions_AddCategory): a scroll frame over a 620px content frame, title + intro,
-- bordered Section boxes, OptionsSliderTemplate sliders with the label above-left,
-- UIDropDownMenu dropdowns. Every widget carries an Update() that re-reads VPS.db; the
-- page's OnShow calls them all. Every change restyles visible plates (VPS.RestyleAll).
--
-- Text section = the element grid (spec "Options page: the element grid"): one row per
-- VPS_TextElement with reorder arrows, label, anchor / align / size / colour cells, swatch,
-- delete; plus a Create-custom-element box.
local ADDON, VPS = ...

local optionsCategory, optionsFrame
local BOX_W, PAD = 580, 10

local function db() return VPS.db end
local function Changed() VPS.RestyleAll() end

local ANCHOR_LABEL = { above = "Above", below = "Below", inside = "Inside", left = "Left of bar", right = "Right of bar", hidden = "Hidden" }
local ALIGN_LABEL = { left = "Left", center = "Center", right = "Right", top = "Top", middle = "Middle", bottom = "Bottom" }
local COLOR_LABEL = { stock = "Stock", white = "White", difficulty = "Difficulty", class = "Class", custom = "Custom" }

local function IsSideAnchor(anchor) return anchor == "left" or anchor == "right" end

-- Translate an align value when the anchor flips between row and column vocabularies.
local function CoerceAlign(anchor, align)
	local side = IsSideAnchor(anchor)
	local map = side and { left = "top", center = "middle", right = "bottom" } or { top = "left", middle = "center", bottom = "right" }
	return map[align] or align
end

--------------------------------------------------------------------------------
-- Shared colour picker opener (swatch rows and grid swatches)
--------------------------------------------------------------------------------
local function OpenColorPicker(get, set, hasAlpha)
	local c = get()
	local prev = { c[1], c[2], c[3], c[4] or 1 }
	local function OnChange()
		local r, g, b = ColorPickerFrame:GetColorRGB()
		local a = prev[4]
		if hasAlpha then
			if ColorPickerFrame.GetColorAlpha then a = ColorPickerFrame:GetColorAlpha()
			elseif OpacitySliderFrame then a = 1 - OpacitySliderFrame:GetValue() end
		end
		set(r, g, b, a)
	end
	local function OnCancel() set(prev[1], prev[2], prev[3], prev[4]) end
	if ColorPickerFrame.SetupColorPickerAndShow then
		ColorPickerFrame:SetupColorPickerAndShow({ r = c[1], g = c[2], b = c[3], opacity = c[4] or 1, hasOpacity = hasAlpha,
			swatchFunc = OnChange, opacityFunc = OnChange, cancelFunc = OnCancel })
	else
		ColorPickerFrame.hasOpacity = hasAlpha
		ColorPickerFrame.opacity = 1 - (c[4] or 1)
		ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = OnChange, OnChange, OnCancel
		ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
		ColorPickerFrame:Show()
	end
end

--------------------------------------------------------------------------------
-- Page
--------------------------------------------------------------------------------
local function CreateOptions()
	if optionsFrame then return end
	optionsFrame = CreateFrame("Frame", "VelocityPlateStyleOptions")
	optionsFrame.name = "Velocity Plate Style"

	local scroll = CreateFrame("ScrollFrame", "VelocityPlateStyleOptionsScroll", optionsFrame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -4)
	scroll:SetPoint("BOTTOMRIGHT", -28, 4)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(620, 900)
	scroll:SetScrollChild(content)
	scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(math.max(620, w)) end)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local max = self:GetVerticalScrollRange()
		self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 40)))
	end)

	local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16); title:SetText("Velocity Plate Style")
	local sub = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6); sub:SetWidth(560); sub:SetJustifyH("LEFT")
	sub:SetText("Restyles Blizzard's own nameplates. Which plates appear, their size and distance stay with the game's "
		.. "Options > Nameplates. Changes here apply to visible plates immediately.")
	local notice = content:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
	notice:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -8); notice:SetWidth(560); notice:SetJustifyH("LEFT")

	local updaters = {}
	local function Track(w) updaters[#updaters + 1] = w; return w end

	local last, lastDy = notice, -10
	local function Place(w, dy, dx) w:SetPoint("TOPLEFT", last, "BOTTOMLEFT", dx or 0, dy or lastDy); last = w; lastDy = -6 end

	-- Slider with its label above-left. `scale` maps db value <-> slider value (100 for 0..1 alphas).
	local function Slider(parent, name, key, minV, maxV, step, labelFn, scale)
		scale = scale or 1
		local holder = CreateFrame("Frame", nil, parent); holder:SetSize(BOX_W - 2 * PAD, 44)
		local label = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); label:SetPoint("TOPLEFT", 4, 0)
		local s = CreateFrame("Slider", name, holder, "OptionsSliderTemplate")
		s:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 2, -6); s:SetWidth(220)
		s:SetMinMaxValues(minV, maxV); s:SetValueStep(step); s:SetObeyStepOnDrag(true)
		_G[name .. "Low"]:SetText(tostring(minV / scale)); _G[name .. "High"]:SetText(tostring(maxV / scale)); _G[name .. "Text"]:SetText("")
		local updating = false
		s:SetScript("OnValueChanged", function(self, v)
			v = math.floor(v / step + 0.5) * step
			label:SetText(labelFn(v / scale))
			if updating then return end
			if db()[key] ~= v / scale then db()[key] = v / scale; Changed() end
		end)
		holder.Update = function()
			updating = true
			s:SetValue((db()[key] or 0) * scale); label:SetText(labelFn(db()[key] or 0))
			updating = false
		end
		return Track(holder)
	end

	-- Labelled dropdown bound to db[key]; `items()` returns { { key=, name= }, ... }.
	local function Dropdown(parent, name, key, label, items, width)
		local holder = CreateFrame("Frame", nil, parent); holder:SetSize(BOX_W - 2 * PAD, 48)
		local lbl = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); lbl:SetPoint("TOPLEFT", 4, 0); lbl:SetText(label)
		local dd = CreateFrame("Frame", name, holder, "UIDropDownMenuTemplate")
		dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", -16, -4)
		UIDropDownMenu_SetWidth(dd, width or 220)
		local function CurrentName()
			for _, it in ipairs(items()) do if it.key == db()[key] then return it.name end end
			return tostring(db()[key])
		end
		local function Init(self, level)
			for _, it in ipairs(items()) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = it.name; info.checked = (it.key == db()[key])
				info.func = function() db()[key] = it.key; UIDropDownMenu_SetText(dd, it.name); Changed() end
				UIDropDownMenu_AddButton(info, level)
			end
		end
		UIDropDownMenu_Initialize(dd, Init)
		-- UIDropDownMenu_SetText only sticks once the menu has been initialised with a
		-- selection context; re-initialise before every SetText so the first show is right.
		holder.Update = function() UIDropDownMenu_Initialize(dd, Init); UIDropDownMenu_SetText(dd, CurrentName()) end
		return Track(holder)
	end

	-- Colour swatch row bound to db[key] = { r, g, b, a }.
	local function ColorRow(parent, key, label, hasAlpha)
		local holder = CreateFrame("Frame", nil, parent); holder:SetSize(BOX_W - 2 * PAD, 24)
		local swatch = CreateFrame("Button", nil, holder)
		swatch:SetSize(20, 20); swatch:SetPoint("LEFT", 4, 0)
		swatch.tex = swatch:CreateTexture(nil, "ARTWORK"); swatch.tex:SetAllPoints(); swatch.tex:SetTexture("Interface\\Buttons\\WHITE8x8")
		swatch.border = swatch:CreateTexture(nil, "BACKGROUND"); swatch.border:SetPoint("TOPLEFT", -1, 1); swatch.border:SetPoint("BOTTOMRIGHT", 1, -1)
		swatch.border:SetTexture("Interface\\Buttons\\WHITE8x8"); swatch.border:SetVertexColor(0.6, 0.6, 0.6)
		local lbl = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); lbl:SetPoint("LEFT", swatch, "RIGHT", 8, 0); lbl:SetText(label)
		swatch:SetScript("OnClick", function()
			OpenColorPicker(function() return db()[key] end, function(r, g, b, a)
				local c = db()[key]; c[1], c[2], c[3], c[4] = r, g, b, a or 1
				swatch.tex:SetVertexColor(r, g, b, 1); Changed()
			end, hasAlpha)
		end)
		holder.Update = function() local c = db()[key]; swatch.tex:SetVertexColor(c[1], c[2], c[3], 1) end
		return Track(holder)
	end

	-- Bordered section with its own layout chain.
	local function Section(header)
		local box = CreateFrame("Frame", nil, content, BackdropTemplateMixin and "BackdropTemplate" or nil)
		box:SetWidth(BOX_W)
		if box.SetBackdrop then
			box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
			box:SetBackdropColor(0, 0, 0, 0.25); box:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.6)
		end
		local h = box:CreateFontString(nil, "ARTWORK", "GameFontNormal"); h:SetPoint("TOPLEFT", PAD, -PAD); h:SetText(header)
		box.inner_last, box.inner_h = h, PAD + 14
		function box:Add(w, height, dy, dx)
			dy = dy or -6
			w:SetPoint("TOPLEFT", self.inner_last, "BOTTOMLEFT", dx or 0, dy)
			self.inner_last, self.inner_h = w, self.inner_h - dy + height
			return w
		end
		function box:Finish() self:SetHeight(self.inner_h + PAD) end
		Place(box, -14)
		return box
	end

	-- Section: Style ---------------------------------------------------------------
	local st = Section("Style")
	st:Add(Dropdown(st, "VelocityPlateStyleTextureDropdown", "barTexture", "Bar texture", function()
		local out = {}
		for _, t in ipairs(VPS.Textures.List()) do out[#out + 1] = { key = t.key, name = t.name } end
		return out
	end), 48, -4)
	st:Add(Slider(st, "VelocityPlateStyleBarHeight", "barHeight", 1, 24, 1, function(v) return "Bar height: " .. v .. " px" end), 44, -4)
	st:Add(Slider(st, "VelocityPlateStyleBackingAlpha", "backingAlpha", 0, 100, 5,
		function(v) return string.format("Backing darkness: %d%%", math.floor(v * 100 + 0.5)) end, 100), 44, -4)
	st:Finish()

	-- Section: Target Highlight --------------------------------------------------------
	local tg = Section("Target Highlight")
	tg:Add(ColorRow(tg, "targetColor", "Target border colour", true), 24, -6)
	tg:Add(Slider(tg, "VelocityPlateStyleTargetThickness", "targetThickness", 1, 4, 1, function(v) return "Target border thickness: " .. v .. " px" end), 44, -6)
	local OVER_LEVEL_LABEL = { none = "None", animated = "Pulsing glow (gold)", red = "Red outline", animatedRed = "Pulsing glow (red)" }
	tg:Add(Dropdown(tg, "VelocityPlateStyleOverLevelDropdown", "overLevelMode", "Over-leveled highlight", function()
		local out = {}
		for _, m in ipairs(VPS.OVER_LEVEL_MODES) do out[#out + 1] = { key = m, name = OVER_LEVEL_LABEL[m] } end
		return out
	end), 48, -6)
	tg:Add(Slider(tg, "VelocityPlateStyleOverLevelThreshold", "overLevelThreshold", -5, 10, 1,
		function(v) return v <= 0 and string.format("Over-leveled when the mob is at most %d levels below you (TEST: negative = light up everything)", -v) or string.format("Over-leveled when the mob is %d+ levels above you (skull always counts)", v) end), 44, -4)
	tg:Finish()

	-- Section: Text (the element grid) -------------------------------------------------
	local tx = Section("Text")
	local GRID_W = BOX_W - 2 * PAD
	local ROW_H = 24
	-- Column x offsets within a row: arrows | label | anchor | align | size | colour | swatch | delete
	local COL = { arrows = 0, label = 36, anchor = 150, align = 258, size = 350, color = 404, swatch = 512, delete = 540 }
	local DD_W = { anchor = 100, align = 84, size = 46, color = 100 }

	local header = CreateFrame("Frame", nil, tx); header:SetSize(GRID_W, 16)
	for _, h in ipairs({ { "label", "Element" }, { "anchor", "Position" }, { "align", "Align" }, { "size", "Size" }, { "color", "Colour" } }) do
		local fs = header:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"); fs:SetPoint("LEFT", COL[h[1]], 0); fs:SetText(h[2])
	end
	tx:Add(header, 16, -4)

	local gridHolder = CreateFrame("Frame", nil, tx); gridHolder:SetSize(GRID_W, ROW_H)
	tx:Add(gridHolder, ROW_H, -2)
	local rows = {}

	-- A compact dropdown cell. `items(e)` -> { { key=, name= } }, `get(e)`, `set(e, key)`.
	local function Cell(row, name, x, width, items, get, set)
		local dd = CreateFrame("Frame", name, row, "UIDropDownMenuTemplate")
		dd:SetPoint("LEFT", x - 16, -2)
		UIDropDownMenu_SetWidth(dd, width)
		UIDropDownMenu_Initialize(dd, function(self, level)
			local e = row.element; if not e then return end
			for _, it in ipairs(items(e)) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = it.name; info.checked = (it.key == get(e))
				info.func = function() set(e, it.key); Changed(); optionsFrame:Update() end
				UIDropDownMenu_AddButton(info, level)
			end
		end)
		dd.Refresh = function()
			local e = row.element; if not e then return end
			local cur = get(e); local label = tostring(cur)
			for _, it in ipairs(items(e)) do if it.key == cur then label = it.name end end
			UIDropDownMenu_SetText(dd, label)
		end
		return dd
	end

	local function AnchorItems(e)
		local out = {}
		for _, a in ipairs(VPS.ANCHORS) do
			if not (a == "hidden" and e.id == "level") then out[#out + 1] = { key = a, name = ANCHOR_LABEL[a] } end   -- R3
		end
		return out
	end
	local function AlignItems(e)
		local out = {}
		for _, a in ipairs(IsSideAnchor(e.anchor) and VPS.ALIGNS_V or VPS.ALIGNS_H) do out[#out + 1] = { key = a, name = ALIGN_LABEL[a] } end
		return out
	end
	local function SizeItems() local out = {}; for s = VPS.SIZE_MIN, VPS.SIZE_MAX do out[#out + 1] = { key = s, name = tostring(s) } end; return out end
	local function ColorItems(e)
		if e.id == "level" then return { { key = "difficulty", name = COLOR_LABEL.difficulty } } end            -- R3
		local out = {}
		for _, c in ipairs(VPS.COLOR_MODES) do out[#out + 1] = { key = c, name = COLOR_LABEL[c] } end
		return out
	end

	local function AcquireRow(i)
		local row = rows[i]
		if row then return row end
		row = CreateFrame("Frame", nil, gridHolder); row:SetSize(GRID_W, ROW_H)
		row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
		if i % 2 == 0 then
			local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetTexture("Interface\\Buttons\\WHITE8x8"); bg:SetVertexColor(1, 1, 1, 0.04)
		end
		local function Arrow(x, delta, tex)
			local b = CreateFrame("Button", nil, row); b:SetSize(14, 14); b:SetPoint("LEFT", x, 0)
			b:SetNormalTexture(tex); b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
			b:SetScript("OnClick", function() if row.index and VPS.MoveElement(row.index, delta) then optionsFrame:Update() end end)
			return b
		end
		row.up = Arrow(COL.arrows, -1, "Interface\\Buttons\\Arrow-Up-Up")
		row.down = Arrow(COL.arrows + 16, 1, "Interface\\Buttons\\Arrow-Down-Up")
		row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"); row.label:SetPoint("LEFT", COL.label, 0); row.label:SetWidth(COL.anchor - COL.label - 6); row.label:SetJustifyH("LEFT"); row.label:SetWordWrap(false)
		row.labelBtn = CreateFrame("Button", nil, row); row.labelBtn:SetAllPoints(row.label)
		row.labelBtn:SetScript("OnEnter", function(self)
			local e = row.element; if not e then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(e.label or e.id)
			GameTooltip:AddLine("Format: " .. tostring(e.format), 1, 1, 1)
			if not VPS.IsBuiltinElement(e.id) then GameTooltip:AddLine("Click to rename", 0.7, 0.7, 0.7) end
			GameTooltip:Show()
		end)
		row.labelBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row.labelBtn:SetScript("OnClick", function()
			local e = row.element; if not e or VPS.IsBuiltinElement(e.id) then return end
			StaticPopupDialogs.VPS_RENAME_ELEMENT = StaticPopupDialogs.VPS_RENAME_ELEMENT or {
				text = "Rename element", button1 = ACCEPT, button2 = CANCEL, hasEditBox = true, timeout = 0, whileDead = true, hideOnEscape = true,
				OnAccept = function(self, data) local t = self.editBox:GetText(); if t and t ~= "" then data.label = t; optionsFrame:Update() end end,
				OnShow = function(self, data) self.editBox:SetText(data.label or ""); self.editBox:HighlightText() end,
				EditBoxOnEnterPressed = function(self) local p = self:GetParent(); p.button1:Click() end,
			}
			local dlg = StaticPopup_Show("VPS_RENAME_ELEMENT"); if dlg then dlg.data = e end
		end)
		row.anchor = Cell(row, "VPSGridAnchor" .. i, COL.anchor, DD_W.anchor, AnchorItems, function(e) return e.anchor end,
			function(e, k) e.anchor = k; e.align = CoerceAlign(k, e.align) end)
		row.align = Cell(row, "VPSGridAlign" .. i, COL.align, DD_W.align, AlignItems, function(e) return e.align end, function(e, k) e.align = k end)
		row.size = Cell(row, "VPSGridSize" .. i, COL.size, DD_W.size, SizeItems, function(e) return e.size end, function(e, k) e.size = k end)
		row.color = Cell(row, "VPSGridColor" .. i, COL.color, DD_W.color, ColorItems, function(e) return e.color end, function(e, k) e.color = k end)
		row.swatch = CreateFrame("Button", nil, row); row.swatch:SetSize(16, 16); row.swatch:SetPoint("LEFT", COL.swatch, 0)
		row.swatch.tex = row.swatch:CreateTexture(nil, "ARTWORK"); row.swatch.tex:SetAllPoints(); row.swatch.tex:SetTexture("Interface\\Buttons\\WHITE8x8")
		row.swatch.border = row.swatch:CreateTexture(nil, "BACKGROUND"); row.swatch.border:SetPoint("TOPLEFT", -1, 1); row.swatch.border:SetPoint("BOTTOMRIGHT", 1, -1)
		row.swatch.border:SetTexture("Interface\\Buttons\\WHITE8x8"); row.swatch.border:SetVertexColor(0.6, 0.6, 0.6)
		row.swatch:SetScript("OnClick", function()
			local e = row.element; if not e then return end
			e.customColor = e.customColor or { 1, 1, 1 }
			OpenColorPicker(function() return e.customColor end, function(r, g, b) e.customColor[1], e.customColor[2], e.customColor[3] = r, g, b; row.swatch.tex:SetVertexColor(r, g, b); Changed() end, false)
		end)
		row.delete = CreateFrame("Button", nil, row, "UIPanelCloseButton"); row.delete:SetSize(20, 20); row.delete:SetPoint("LEFT", COL.delete, 0)
		row.delete:SetScript("OnClick", function() local e = row.element; if e and VPS.RemoveElement(e.id) then optionsFrame:Update() end end)
		rows[i] = row
		return row
	end

	local function RenderGrid()
		local list = db().elements
		for i, e in ipairs(list) do
			local row = AcquireRow(i)
			row.element, row.index = e, i
			row.label:SetText(e.label or e.id)
			row.up:SetEnabled(i > 1); row.down:SetEnabled(i < #list)
			row.up:SetAlpha(i > 1 and 1 or 0.3); row.down:SetAlpha(i < #list and 1 or 0.3)
			row.anchor.Refresh(); row.align.Refresh(); row.size.Refresh(); row.color.Refresh()
			local custom = e.color == "custom" and e.id ~= "level"
			row.swatch:SetShown(custom)
			if custom then local c = e.customColor or { 1, 1, 1 }; row.swatch.tex:SetVertexColor(c[1], c[2], c[3]) end
			row.delete:SetShown(not VPS.IsBuiltinElement(e.id))
			row:Show()
		end
		for i = #list + 1, #rows do rows[i]:Hide(); rows[i].element = nil end
		gridHolder:SetHeight(math.max(ROW_H, #list * ROW_H))
	end

	-- Create custom element ------------------------------------------------------------
	local createHdr = tx:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); createHdr:SetText("Create custom element")
	tx:Add(createHdr, 14, -10)
	local nameLbl = tx:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"); nameLbl:SetText("Name")
	local nameBox = CreateFrame("EditBox", "VelocityPlateStyleNewElementName", tx, "InputBoxTemplate"); nameBox:SetSize(140, 20); nameBox:SetAutoFocus(false)
	nameLbl:SetPoint("RIGHT", nameBox, "LEFT", -8, 0)
	local fmtLbl = tx:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"); fmtLbl:SetText("Format")
	local fmtBox = CreateFrame("EditBox", "VelocityPlateStyleNewElementFormat", tx, "InputBoxTemplate"); fmtBox:SetSize(260, 20); fmtBox:SetAutoFocus(false)
	fmtLbl:SetPoint("RIGHT", fmtBox, "LEFT", -8, 0)
	fmtBox:SetPoint("LEFT", nameBox, "RIGHT", 52, 0)
	local addBtn = CreateFrame("Button", nil, tx, "UIPanelButtonTemplate"); addBtn:SetSize(60, 22); addBtn:SetText("Add")
	addBtn:SetPoint("LEFT", fmtBox, "RIGHT", 8, 0)
	tx:Add(nameBox, 20, -6, 44)
	local tokens = tx:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"); tokens:SetJustifyH("LEFT"); tokens:SetWidth(GRID_W)
	tokens:SetText("Tokens: " .. table.concat(VPS.Format.TOKENS, "  ") .. "   Colour codes |cAARRGGBB...|r pass through."
		.. (VPS.Client.HasSecretValues() and "  On this client [hp] tokens are blank in restricted content." or ""))
	tx:Add(tokens, 14, -6, -44)
	local function DoAdd()
		local label = (nameBox:GetText() or ""):match("^%s*(.-)%s*$")
		local format = (fmtBox:GetText() or ""):match("^%s*(.-)%s*$")
		if label == "" or format == "" then VPS.Print("give the new element a name and a format, e.g.  Elite  [class+]"); return end
		VPS.AddCustomElement(label, format)
		nameBox:SetText(""); fmtBox:SetText(""); nameBox:ClearFocus(); fmtBox:ClearFocus()
		optionsFrame:Update()
	end
	addBtn:SetScript("OnClick", DoAdd)
	fmtBox:SetScript("OnEnterPressed", DoAdd); nameBox:SetScript("OnEnterPressed", function() fmtBox:SetFocus() end)
	nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end); fmtBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	tx:Finish()
	local txBaseH = tx.inner_h - gridHolder:GetHeight()

	-- Section: Reset ------------------------------------------------------------------
	local rs = Section("Reset")
	local resetBtn = CreateFrame("Button", nil, rs, "UIPanelButtonTemplate")
	resetBtn:SetSize(160, 22); resetBtn:SetText("Reset to defaults")
	resetBtn:SetScript("OnClick", function() VPS.ResetToDefaults(); optionsFrame:Update() end)
	rs:Add(resetBtn, 22, -6)
	local status = rs:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"); status:SetJustifyH("LEFT"); status:SetWidth(BOX_W - 2 * PAD)
	rs:Add(status, 14, -8)
	rs:Finish()

	function optionsFrame:Update()
		if not VPS.db then return end
		for _, w in ipairs(updaters) do if w.Update then w:Update() end end
		RenderGrid()
		-- The grid grows/shrinks: resize the Text section and the scroll content.
		tx.inner_h = txBaseH + gridHolder:GetHeight(); tx:Finish()
		notice:SetText(VPS.standDown and (VPS.standDown .. " is managing nameplates. Velocity Plate Style is standing down; disable that addon to use this one.") or "")
		status:SetText(VPS.StatusText())
		local top, bottom = content:GetTop(), rs:GetBottom()
		if top and bottom then content:SetHeight(top - bottom + 24) end
	end
	optionsFrame:SetScript("OnShow", optionsFrame.Update)

	if Settings and Settings.RegisterCanvasLayoutCategory then
		optionsCategory = Settings.RegisterCanvasLayoutCategory(optionsFrame, "Velocity Plate Style")
		Settings.RegisterAddOnCategory(optionsCategory)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(optionsFrame)
	end
end

function VPS.OpenOptions()
	CreateOptions()
	if Settings and Settings.OpenToCategory and optionsCategory then
		Settings.OpenToCategory(optionsCategory:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(optionsFrame); InterfaceOptionsFrame_OpenToCategory(optionsFrame)
	end
end

--------------------------------------------------------------------------------
-- Slash
--------------------------------------------------------------------------------
SLASH_VELOCITYPLATESTYLE1 = "/vps"
SLASH_VELOCITYPLATESTYLE2 = "/velocityplatestyle"
SlashCmdList.VELOCITYPLATESTYLE = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "" or msg == "options" or msg == "config" then
		VPS.OpenOptions()
	elseif msg == "status" then
		VPS.Print(VPS.StatusText())
	elseif msg == "reset" then
		VPS.ResetToDefaults(); VPS.Print("settings reset to defaults")
	elseif msg == "debug" then
		local uf = VPS.UnitFrameForUnit("target")
		if not uf then VPS.Print("target has no (non-forbidden) nameplate"); return end
		VPS.Print(string.format("styled=%s hooked=%s version=%s", tostring(uf.vpsStyled), tostring(uf.vpsHooked), tostring(VPS.styleVersion)))
		for _, e in ipairs(VPS.db.elements) do
			local fs = uf.vpsText and uf.vpsText[e.id]
			local path, size = fs and fs:GetFont()
			VPS.Print(string.format("  %-10s %s/%s size=%s %s text=%q w=%s", e.id, e.anchor, e.align, tostring(size), e.color,
				fs and (fs:GetText() or "") or "-", fs and tostring(fs.vpsWidth) or "-"))
		end
		local glow = uf.vpsGlow
		VPS.Print(string.format("overlevel: mode=%s threshold=%s unitLevel=%s playerLevel=%s verdict=%s glow=%s shown=%s scrolling=%s",
			tostring(VPS.db.overLevelMode), tostring(VPS.db.overLevelThreshold), tostring(UnitLevel("target")), tostring(UnitLevel("player")),
			tostring(VPS.Skin.IsOverLevel("target")), glow and "created" or "nil", glow and tostring(glow.tex:IsShown()) or "-",
			glow and tostring(glow.scrollGroup:IsPlaying()) or "-"))
		VPS.Print("stock: useClassicHealthBar=" .. tostring(NamePlateSetupOptions and NamePlateSetupOptions.useClassicHealthBar) .. " nameAnchorStyle=" .. tostring(NamePlateSetupOptions and NamePlateSetupOptions.unitNameAnchorStyle))
	else
		VPS.Print("/vps  |  /vps status  |  /vps reset  |  /vps debug (target's plate)")
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self) self:UnregisterEvent("PLAYER_LOGIN"); CreateOptions() end)