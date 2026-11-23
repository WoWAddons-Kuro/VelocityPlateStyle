-- Velocity Plate Style: options page and slash command.
--
-- Canvas category in the GotJunk style (Settings.RegisterCanvasLayoutCategory, fallback
-- InterfaceOptions_AddCategory): a scroll frame over a 620px content frame, title + intro,
-- bordered Section boxes, InterfaceOptionsCheckButtonTemplate checkboxes, OptionsSliderTemplate
-- sliders with the label above-left, UIRadioButtonTemplate radio groups, UIDropDownMenu dropdowns.
-- Every widget carries an Update() that re-reads VPS.db; the page's OnShow calls them all.
-- Every change bumps the style version and restyles visible plates (VPS.RestyleAll).
local ADDON, VPS = ...

local optionsCategory, optionsFrame
local BOX_W, PAD = 580, 10

local function db() return VPS.db end

local function Changed()
	VPS.RestyleAll()
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
	content:SetSize(620, 900)   -- height corrected after layout
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

	-- Stand-down notice (R7); text filled in Update.
	local notice = content:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
	notice:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -8); notice:SetWidth(560); notice:SetJustifyH("LEFT")

	local updaters = {}
	local function Track(w) updaters[#updaters + 1] = w; return w end

	local last, lastDy = notice, -10
	local function Place(w, dy, dx) w:SetPoint("TOPLEFT", last, "BOTTOMLEFT", dx or 0, dy or lastDy); last = w; lastDy = -6 end

	-- Checkbox bound to db[key].
	local function Check(parent, key, label, tip)
		local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
		cb.Text:SetText(label)
		cb.tooltipText = tip
		cb:SetScript("OnClick", function(self) db()[key] = self:GetChecked() and true or false; Changed() end)
		cb.Update = function(self) self:SetChecked(db()[key] and true or false) end
		return Track(cb)
	end

	-- Slider with its label above-left. `scale` maps db value <-> slider value (e.g. 100 for 0..1 alphas).
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

	-- Dropdown bound to db[key]; `items()` returns { { key=, name= }, ... }.
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
		UIDropDownMenu_Initialize(dd, function(self, level)
			for _, it in ipairs(items()) do
				local info = UIDropDownMenu_CreateInfo()
				info.text = it.name
				info.checked = (it.key == db()[key])
				info.func = function() db()[key] = it.key; UIDropDownMenu_SetText(dd, it.name); Changed() end
				UIDropDownMenu_AddButton(info, level)
			end
		end)
		holder.Update = function() UIDropDownMenu_SetText(dd, CurrentName()) end
		return Track(holder)
	end

	-- Colour swatch bound to db[key] = { r, g, b, a }.
	local function ColorRow(parent, key, label, hasAlpha)
		local holder = CreateFrame("Frame", nil, parent); holder:SetSize(BOX_W - 2 * PAD, 24)
		local swatch = CreateFrame("Button", nil, holder)
		swatch:SetSize(20, 20); swatch:SetPoint("LEFT", 4, 0)
		swatch.tex = swatch:CreateTexture(nil, "ARTWORK"); swatch.tex:SetAllPoints(); swatch.tex:SetTexture("Interface\\Buttons\\WHITE8x8")
		swatch.border = swatch:CreateTexture(nil, "BACKGROUND"); swatch.border:SetPoint("TOPLEFT", -1, 1); swatch.border:SetPoint("BOTTOMRIGHT", 1, -1)
		swatch.border:SetTexture("Interface\\Buttons\\WHITE8x8"); swatch.border:SetVertexColor(0.6, 0.6, 0.6)
		local lbl = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); lbl:SetPoint("LEFT", swatch, "RIGHT", 8, 0); lbl:SetText(label)
		local function Apply(r, g, b, a)
			local c = db()[key]; c[1], c[2], c[3], c[4] = r, g, b, a or 1
			swatch.tex:SetVertexColor(r, g, b, 1); Changed()
		end
		swatch:SetScript("OnClick", function()
			local c = db()[key]
			local prev = { c[1], c[2], c[3], c[4] or 1 }
			local function OnChange()
				local r, g, b = ColorPickerFrame:GetColorRGB()
				local a = prev[4]
				if hasAlpha then
					if ColorPickerFrame.GetColorAlpha then a = ColorPickerFrame:GetColorAlpha()
					elseif OpacitySliderFrame then a = 1 - OpacitySliderFrame:GetValue() end
				end
				Apply(r, g, b, a)
			end
			local function OnCancel() Apply(prev[1], prev[2], prev[3], prev[4]) end
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
		end)
		holder.Update = function() local c = db()[key]; swatch.tex:SetVertexColor(c[1], c[2], c[3], 1) end
		return Track(holder)
	end

	-- Radio group bound to db[key].
	local function RadioGroup(section, key, entries)
		local radios = {}
		for _, e in ipairs(entries) do
			local r = CreateFrame("CheckButton", nil, section, "UIRadioButtonTemplate"); r:SetSize(16, 16)
			r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"); r.text:SetPoint("LEFT", r, "RIGHT", 4, 0); r.text:SetText(e.label)
			r.tooltipText = e.tip
			r.value = e.value
			r:SetScript("OnClick", function() db()[key] = e.value; for _, o in ipairs(radios) do o:SetChecked(o.value == e.value) end; Changed(); optionsFrame:Update() end)
			r.Update = function(self) self:SetChecked(db()[key] == e.value) end
			radios[#radios + 1] = Track(r)
			section:Add(r, 16, -6, 0)
		end
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
	RadioGroup(st, "barStyle", {
		{ value = "modern", label = "Modern Square - flat bar, 1px outline, black backing, level inside the bar" },
		{ value = "classic", label = "Classic Clean - Blizzard's bar art with a darkened border" },
	})
	st:Add(Dropdown(st, "VelocityPlateStyleTextureDropdown", "barTexture", "Bar texture", function()
		local out = {}
		for _, t in ipairs(VPS.Textures.List()) do out[#out + 1] = { key = t.key, name = t.name } end
		return out
	end), 48, -8)
	st:Add(Slider(st, "VelocityPlateStyleBarHeight", "barHeight", 6, 24, 1, function(v) return "Bar height: " .. v .. " px" end), 44, -4)
	local backing = st:Add(Slider(st, "VelocityPlateStyleBackingAlpha", "backingAlpha", 0, 100, 5,
		function(v) return string.format("Backing darkness (Modern Square): %d%%", math.floor(v * 100 + 0.5)) end, 100), 44, -4)
	local darken = st:Add(Slider(st, "VelocityPlateStyleBorderDarken", "borderDarken", 0, 100, 5,
		function(v) return string.format("Border darkening (Classic Clean): %d%%", math.floor(v * 100 + 0.5)) end, 100), 44, -4)
	st:Add(Check(st, "showLevel", "Show the level inside the bar (Modern Square)",
		"The level is always shown somewhere: off, Blizzard's own level display is left in place."), 26, -4)
	st:Finish()

	-- Section: Target -----------------------------------------------------------------
	local tg = Section("Target")
	tg:Add(ColorRow(tg, "targetColor", "Target border colour", true), 24, -6)
	tg:Add(Slider(tg, "VelocityPlateStyleTargetThickness", "targetThickness", 1, 4, 1, function(v) return "Target border thickness: " .. v .. " px" end), 44, -6)
	tg:Finish()

	-- Section: Reset ------------------------------------------------------------------
	local rs = Section("Reset")
	local resetBtn = CreateFrame("Button", nil, rs, "UIPanelButtonTemplate")
	resetBtn:SetSize(160, 22); resetBtn:SetText("Reset to defaults")
	resetBtn:SetScript("OnClick", function() VPS.ResetToDefaults(); optionsFrame:Update() end)
	rs:Add(resetBtn, 22, -6)
	local status = rs:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"); status:SetJustifyH("LEFT"); status:SetWidth(BOX_W - 2 * PAD)
	rs:Add(status, 14, -8)
	rs:Finish()

	-- Update: re-read every widget, grey out the sliders that do not apply to the current style.
	function optionsFrame:Update()
		if not VPS.db then return end
		for _, w in ipairs(updaters) do if w.Update then w:Update() end end
		local modern = db().barStyle == "modern"
		backing:SetAlpha(modern and 1 or 0.4); darken:SetAlpha(modern and 0.4 or 1)
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
		-- Dumps what we did to the TARGET's plate so layout problems can be read off chat.
		local uf = VPS.UnitFrameForUnit("target")
		if not uf then VPS.Print("target has no (non-forbidden) nameplate"); return end
		local name = VPS.Client.NameText(uf)
		VPS.Print(string.format("styled=%s hooked=%s version=%s", tostring(uf.vpsStyled), tostring(uf.vpsHooked), tostring(VPS.styleVersion)))
		if name then
			VPS.Print(string.format("name justify=%s points=%d shown=%s", tostring(name:GetJustifyH()), name:GetNumPoints(), tostring(name:IsShown())))
			for i = 1, name:GetNumPoints() do
				local p, rel, rp, x, y = name:GetPoint(i)
				local relName = rel and (rel.GetName and rel:GetName() or (rel == VPS.Client.HealthBarContainer(uf) and "HealthBarsContainer") or (rel == VPS.Client.HealthBar(uf) and "healthBar") or "?") or "nil"
				VPS.Print(string.format("  %s -> %s.%s (%.1f, %.1f)", p, relName, tostring(rp), x or 0, y or 0))
			end
		end
		if uf.vpsLevel then
			local path, size, flags = uf.vpsLevel:GetFont()
			VPS.Print(string.format("level text=%q font=%s size=%s flags=%s", uf.vpsLevel:GetText() or "", tostring(path), tostring(size), tostring(flags)))
		end
		VPS.Print("stock: useClassicHealthBar=" .. tostring(NamePlateSetupOptions and NamePlateSetupOptions.useClassicHealthBar) .. " nameAnchorStyle=" .. tostring(NamePlateSetupOptions and NamePlateSetupOptions.unitNameAnchorStyle))
	else
		VPS.Print("/vps  |  /vps status  |  /vps reset  |  /vps debug (target's plate)")
	end
end

-- Build the page at login so Options > AddOns lists it without a slash command first.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self) self:UnregisterEvent("PLAYER_LOGIN"); CreateOptions() end)