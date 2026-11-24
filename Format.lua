-- Velocity Plate Style: VPS_FormatString expansion for text elements.
--
-- A format string is player (or default) text containing tokens in square brackets. Every
-- unit read goes through VPS.Plain (R8); a secret or missing value makes the token "" and an
-- element whose whole expansion is "" is hidden for that pass (Skin.lua). Colour codes the
-- player types (|cAARRGGBB ... |r) are left untouched.
--
-- Tokens:  [name] [level] [hp] [hp%] [hpmax] [class] [class+] [creature]
local ADDON, VPS = ...
local Plain = VPS.Plain

local Format = {}
VPS.Format = Format

Format.TOKENS = { "[name]", "[level]", "[hp]", "[hp%]", "[hpmax]", "[class]", "[class+]", "[creature]" }
Format.SKULL_TEXT = "??"
-- Inline skull glyph (|T..|t escape; :0 = font height). Shown NEXT TO the number when the mob is
-- >= player + db.skullAtLevelsAbove; the game's own -1 still reads "??".
Format.SKULL_ICON = "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:0|t"

-- 709000 -> "709K", 1234567 -> "1.2M", 999 -> "999"
local function Abbreviate(n)
	if n >= 1e6 then return string.format("%.1fM", n / 1e6):gsub("%.0M", "M") end
	if n >= 1e4 then return string.format("%dK", math.floor(n / 1e3 + 0.5)) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3):gsub("%.0K", "K") end
	return tostring(n)
end
Format.Abbreviate = Abbreviate

local CLASSIFICATION_WORD = { elite = "elite", rare = "rare", rareelite = "rare elite", worldboss = "boss" }
local CLASSIFICATION_SUFFIX = { elite = "+", rare = "r", rareelite = "r+", worldboss = "??" }

-- Per-token resolvers: (unit) -> string. Always return a string ("" when unavailable).
local resolvers = {
	["[name]"] = function(unit)
		-- Flavour-owned (Era one name; Forever "First Surname" like the stock plate). Secret -> "".
		local v = Plain(VPS.Client.UnitDisplayName(unit))
		return v or ""
	end,
	["[level]"] = function(unit)
		local v = Plain(UnitLevel(unit))
		if v == nil then return "" end
		local n = VPS.SkullCount(v, unit)           -- -1 = "??", 0 = none, N = N skulls then the number; friendlies 0
		if n < 0 then return Format.SKULL_TEXT end
		if n > 0 then return string.rep(Format.SKULL_ICON, n) .. tostring(v) end
		return tostring(v)
	end,
	["[hp]"] = function(unit)
		local v = Plain(UnitHealth(unit))
		return v and Abbreviate(v) or ""
	end,
	["[hpmax]"] = function(unit)
		local v = Plain(UnitHealthMax(unit))
		return v and Abbreviate(v) or ""
	end,
	["[hp%]"] = function(unit)
		local hp, max = Plain(UnitHealth(unit)), Plain(UnitHealthMax(unit))
		if not hp or not max or max <= 0 then return "" end
		return tostring(math.floor(hp / max * 100 + 0.5)) .. "%"
	end,
	["[class]"] = function(unit)
		local c = Plain(UnitClassification(unit))
		return c and CLASSIFICATION_WORD[c] or ""
	end,
	["[class+]"] = function(unit)
		local c = Plain(UnitClassification(unit))
		return c and CLASSIFICATION_SUFFIX[c] or ""
	end,
	["[creature]"] = function(unit)
		local v = Plain(UnitCreatureType(unit))
		return v or ""
	end,
}

-- Expands `format` for `unit`. Unknown [tokens] are left as typed.
function Format.Expand(format, unit)
	if type(format) ~= "string" or format == "" then return "" end
	return (format:gsub("%[[%w%%%+]+%]", function(token)
		local r = resolvers[token]
		if r then return r(unit) end
		return token
	end))
end

-- True when the format reads health (so the element must refresh on UNIT_HEALTH).
function Format.UsesHealth(format)
	return type(format) == "string" and (format:find("[hp]", 1, true) or format:find("[hp%]", 1, true) or format:find("[hpmax]", 1, true)) ~= nil
end

-- True when the format is exactly one [name] token: the only case where a secret name may be
-- handed straight to SetText (display-only pass-through, BUG 12 coping pattern 1).
function Format.IsBareName(format)
	return format == "[name]"
end

-- Expand but treat a result that is only whitespace as empty.
function Format.ExpandOrEmpty(format, unit)
	local s = Format.Expand(format, unit)
	if s:match("^%s*$") then return "" end
	return s
end