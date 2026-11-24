-- Velocity Plate Style: the game's ACTIVE EDIT MODE LAYOUT name, for the "layout" danger scope.
--
-- Copy of VelocityQuestTracker\Core\LayoutProfile.lua (workspace rule: no shared code across repos),
-- reduced to name tracking + record bookkeeping. Every client we ship to (Forever 16001, Era 11509)
-- has Edit Mode; the game is the profile picker (its layout dropdown), we only LISTEN for the active
-- layout's name. Records live in a table the caller hands to Init (VelocityPlateStyleDB.dangerByLayout):
-- a layout created in Edit Mode (always a copy of the active one) gets a copy of the active record;
-- rename moves the record; delete drops it. API ground truth and the two index-space traps:
-- AddonManagement\_EXTERNAL_APIS\wow_edit_mode_layouts_api.md.
local ADDON, VPS = ...

local LayoutProfile = {}
VPS.LayoutProfile = LayoutProfile

local PLACEHOLDER = "Default"       -- VPS_LayoutName reported until Edit Mode tells us the real one (a moment after PLAYER_LOGIN)
local name = PLACEHOLDER
local resolved = false
local lastName                      -- previous resolved name: copy source for a record created on demand
local savedNamesCache               -- layoutName list of SAVED layouts, for create/rename/delete detection
local listeners = {}
local records                       -- VPS_LayoutName -> record (the caller's table)
local seedFn                        -- () -> fresh record when nothing can be copied

local function Records() return records end

-- Merged layout list in the activeLayout index space (presets first) and the active index.
local function MergedLayouts()
	local mgr = EditModeManagerFrame
	if mgr and mgr.layoutInfo and mgr.layoutInfo.layouts and mgr.layoutInfo.activeLayout then
		return mgr.layoutInfo.layouts, mgr.layoutInfo.activeLayout
	end
	if not (C_EditMode and C_EditMode.GetLayouts) then return nil end
	local ok, info = pcall(C_EditMode.GetLayouts)
	if not ok or type(info) ~= "table" or not info.layouts or not info.activeLayout then return nil end
	local list = {}
	local okp, presets = pcall(function() return EditModePresetLayoutManager:GetCopyOfPresetLayouts() end)
	if okp and type(presets) == "table" then for _, l in ipairs(presets) do list[#list + 1] = l end
	else
		list[1] = { layoutName = HUD_EDIT_MODE_PRESET_LAYOUT_MODERN or "Modern" }
		list[2] = { layoutName = HUD_EDIT_MODE_PRESET_LAYOUT_CLASSIC or "Classic" }
	end
	for _, l in ipairs(info.layouts) do list[#list + 1] = l end
	return list, info.activeLayout
end

local function SavedNamesNow()
	local names = {}
	if C_EditMode and C_EditMode.GetLayouts then
		local ok, info = pcall(C_EditMode.GetLayouts)
		if ok and type(info) == "table" then for _, l in ipairs(info.layouts or {}) do names[#names + 1] = l.layoutName end end
	end
	return names
end

local function Fire(newName, oldName)
	for _, fn in ipairs(listeners) do
		local ok, err = pcall(fn, newName, oldName)
		if not ok then geterrorhandler()(err) end
	end
end

local function SetName(n)
	if not n or n == "" then return end
	local old, wasResolved = name, resolved
	resolved = true
	if n == old and wasResolved then return end
	lastName = wasResolved and old or nil         -- the unresolved placeholder is never a copy source
	name = n
	Fire(n, wasResolved and old or nil)
end

local function ResolveFromGame()
	local list, active = MergedLayouts()
	local l = list and active and list[active]
	if l and l.layoutName then SetName(l.layoutName) end
end

-- Saved-layout list changed: create (copy the active record), rename (move it), delete (drop it).
local function ReconcileSavedNames()
	local newSaved = SavedNamesNow()
	local oldSaved = savedNamesCache
	savedNamesCache = newSaved
	if not oldSaved or not records then return end
	local recs = Records()
	if #newSaved > #oldSaved then
		local known = {}; for _, n in ipairs(oldSaved) do known[n] = true end
		for _, n in ipairs(newSaved) do if not known[n] and not recs[n] then recs[n] = CopyTable(recs[name] or seedFn()) end end
	elseif #newSaved < #oldSaved then
		local keep = {}; for _, n in ipairs(newSaved) do keep[n] = true end
		for _, l in ipairs(MergedLayouts() or {}) do keep[l.layoutName] = true end     -- never drop a preset's record
		for _, n in ipairs(oldSaved) do if not keep[n] then recs[n] = nil end end
	else
		for i, n in ipairs(newSaved) do
			local o = oldSaved[i]
			if o ~= n then
				if recs[o] and not recs[n] then recs[n] = recs[o]; recs[o] = nil end
				if name == o then name = n; Fire(n, o) end
			end
		end
	end
end

-- Public -----------------------------------------------------------------------------------------
-- recordsTable: where per-layout records live (persisted by the caller). seed: () -> a fresh record.
function LayoutProfile.Init(recordsTable, seed)
	records, seedFn = recordsTable, seed
	savedNamesCache = SavedNamesNow()
	ResolveFromGame()
	if EventRegistry then
		pcall(EventRegistry.RegisterFrameEventAndCallback, EventRegistry, "EDIT_MODE_LAYOUTS_UPDATED", function()
			C_Timer.After(0, function() ReconcileSavedNames(); ResolveFromGame() end)
		end, LayoutProfile)
		pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.SavedLayouts", ReconcileSavedNames, LayoutProfile)
	end
end

function LayoutProfile.Name() return name end
function LayoutProfile.IsResolved() return resolved end
function LayoutProfile.OnChanged(fn) listeners[#listeners + 1] = fn end

-- The record for the active layout; created on demand as a copy of the previous layout's record (a
-- freshly created layout always inherits), else from the seed.
function LayoutProfile.Current()
	local recs = Records()
	local r = recs[name]
	if not r then
		r = CopyTable((lastName and recs[lastName]) or seedFn())
		recs[name] = r
	end
	return r
end

function LayoutProfile.Status()
	return string.format("layout %q%s", name, resolved and "" or " (not yet reported by Edit Mode)")
end