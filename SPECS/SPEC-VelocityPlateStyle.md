# SPEC-VelocityPlateStyle: Single-purpose nameplate restyle addon

- **Status:** Draft v2 (2026-11-22) — reviewed against workspace rules; decisions from the review are marked **[D]**.
- **Name:** `VelocityPlateStyle`. Repo `VelocityPlateStyle\`, TOC `VelocityPlateStyle.toc`, SavedVariables
  `VelocityPlateStyleDB`, slash `/vps` and `/velocityplatestyle`, namespace `VPS` (`local ADDON, VPS = ...`).
- **Clients:** Classic Era / Hardcore (1.15.9, interface 11509) and WoW Forever (1.60.1, interface 16001).
  Retail 12.x is **deferred** (no retail executable installed; see Milestones).
- **Owner test order [D]:** Classic Era first (owner is playing Era Hardcore), then Forever.
- **References:**
  - [Blizzard: Combat philosophy and addon disarmament in Midnight](https://news.blizzard.com/en-us/article/24246290/combat-philosophy-and-addon-disarmament-in-midnight)
  - [Blizzard: User Interface Updates in Classic (1.15.9)](https://us.forums.blizzard.com/en/wow/t/user-interface-updates-in-classic/2325408) — Era plates moved to the shared Midnight plate code
  - [Blizzard UI source mirror](https://github.com/Gethe/wow-ui-source) — branches `classic_era`, `live`; Forever = Camelot flavour
  - Workspace: `AddonManagement\PROJECT_STRUCTURE.md` (TOC/flavour/client-file rules),
    `AddonManagement\_BUGFIX\12_BUG_Forever_SecretValues_UnitData_In_Instances.md` (secret values on Forever),
    `AddonManagement\_BUGFIX\13_BUG_Forever_SettingsPanel_Taint_IsUserOAuthed.md` (settings-panel taint, deferred),
    `GotJunk\GotJunk.lua` `CreateOptions()` (the options-page style to copy).

## Milestones

- [x] **M0 — Research (done 2026-11-22).** Fetch `Blizzard_NamePlates` + `CompactUnitFrame.lua` (+ `NamePlates.xml`)
      for the `classic_era` and Forever/Camelot source branches into `_ref\blizzard\classic_era\nameplates\` and
      `_ref\blizzard\forever\nameplates\`; write `AddonManagement\_EXTERNAL_APIS\wow_nameplate_unitframe_regions.md`
      with the confirmed region names per client (the ClientMap table below) and the list of stock functions that
      re-apply colour/size. Confirm in game with `/fstack` on Era.
- [x] **M1 — Era bring-up (done 2026-11-22, commits 2458359..e243d7b).** Three TOCs, `Client\` layout,
      Core plate lifecycle, Classic Clean + Modern Square, bar texture (built-ins + opportunistic LSM, **text dropdown
      first**), bar height, backing alpha, border darkness, target border, level number with difficulty colour and stock
      classification icon re-anchored, GotJunk-style canvas options page, R7 stand-down. **No threat/aggro features.**
      In-game findings folded into "Era 1.15.9 restricted regions" and "Text elements" below.
- [x] **M2 — Text element layout grid (built 2026-11-23, cd96c33 + 03573ed; Era verification pending).** `db.elements` model, `VPS.Format` token expander, Skin flow-layout engine
      for the six anchor slots, stock name/health/level alpha-zeroed, Era `UNIT_HEALTH` path, options grid with
      reorder arrows + create-custom-element box, Classic Clean retired (`barStyle`/`borderDarken` dropped).
      Plates in Blizzard's show-only-name / widgets-only mode are left fully stock (`Skin.IsBarMode`).
- [ ] **M2b — Visual texture picker** (per-row-textured list for textures; fonts if a font column is added later).
- [x] **M2c — Over-leveled highlight (2026-11-23, 58cb482..9f5b39e).** Target section renamed *Target Highlight*;
      `overLevelMode` none / animated / red / animatedRed (default **animatedRed**, threshold **+2**, skull always).
      Animated = our own `Assets\hatch.tga` stripes tiled over the bar, scrolled by a looping `TextureCoordTranslation`
      (Blizzard's aggro-flare mechanism) + alpha pulse, additive, gold/red; red modes also redden the outline and name.
      Tried and rejected: the 10.x `ActionButtonSpellAlertTemplate` flipbook (smears to a static tint on a bar).
      Lesson: XML template names are not Lua globals — never guard on them.
- [x] **M2d — Danger cues: how dangerous, and how much (2026-11-24, 4123e4f..5f7fe57).** The over-level sweep was
      too subtle and said nothing about *how many* levels. Decided **[D]**: the animation conveys *danger*, the level
      text conveys *magnitude*. (1) A 50 % black dimmer (`glow.dim`) sits under the sweep while it runs, so the yellow
      wave reads against a half-bright bar; Blizzard's fill colour is still never written. (2) The level number turns
      skull-red at the user's `overLevelThreshold`, in every mode including *None*. (3) New `db.skullAtLevelsAbove`
      (slider 1–10, default 10 = the game's own `-1` point): from that gap the `[level]` token renders **one inline
      skull per level above the player** (`|T…UI-TargetingFrame-Skull:0|t` × gap) before the number, via
      `VPS.SkullCount(level, unit)` → `0 | 1..10 | -1 ("??")`; 11+ or a real `-1` is the plain `??`. (4) Friendly /
      non-attackable units (`VPS.IsHostileThreat`, secret ⇒ threat) get **no** danger cue of any kind. (5) `/vps
      forcedangerlevel N` previews the highlight on every hostile plate (not saved). **Rejected:** N phase-shifted sweep
      layers per level — re-issuing `SetTexCoord` under a running `TextureCoordTranslation` resets its base and the
      sweep degrades to a flash; a tried ADD blend was less visible than BLEND; outline changes are "just another outline".
- [ ] **M2e — Danger Highlight section + settings scope (global / Edit Mode layout / character).** See "Danger Highlight scope".
- [ ] **M3 — Threat level (classification) modes + danger emphasis.** Text / Frame / Icon+Frame modes, danger threshold.
- [ ] **M4 — Forever client file + verification pass** on 1.60.1 (R5 path throughout).
- [x] **M5 — Blizzard nameplate settings (done 2026-11-23, 9b87713) [D: button, not mirror].** A "Blizzard Nameplate
      Settings" section above Reset with one button that opens the game's own Nameplates page via
      `Settings.NAMEPLATE_OPTIONS_CATEGORY_ID`. The CVar mirror is dropped: one writer per setting, R1 stays absolute.
- [ ] **M6 — Aggro indicator.** Era: Lua threat path. Forever: restyle of the stock aggro highlight only.
- [ ] **M7 — Compatibility pass** (Questie, raid markers, stock cast bar/auras), publish via `cmd\release.cmd` (owner).
- [ ] **M8 (deferred) — Retail `_Mainline.toc` + client file** when a retail install exists.

## Overview

VelocityPlateStyle changes how Blizzard's own nameplates look. It does not create plates, replace plates, or decide
which units get plates. The stock client remains the owner of plate existence, visibility, range, stacking, and
health fill; VelocityPlateStyle only changes textures, sizes, anchors, fonts, and a small number of added indicator
textures.

Three criteria shape every decision below:

1. **One thing.** Restyle stock plates. Nothing else.
2. **Native settings.** One category in Options > AddOns, in the workspace's GotJunk options-page style.
3. **One addon, all clients.** Era and Forever from a single folder (retail later), via the workspace `Client\` layout.

## Design rules (invariants)

| # | Rule | Consequence |
|---|------|-------------|
| R1 | Never writes a CVar on its own initiative | No login, combat, or zone handler touches CVars. Only the mirror section (M5) writes CVars, and only when the user moves a control. |
| R2 | Never shows, hides, moves or reparents a plate, or any child it did not create | Visibility and position stay with the client. Foreign decorations (quest icons, raid marks, auras) keep working. Stock regions we replace are **alpha-zeroed**, never hidden. |
| R3 | Threat-level information is never removable | Elite / rare / boss / skull / level always has a visible representation. Options choose *how*, never *whether*. |
| R4 | Event-driven only | No `OnUpdate`, no tickers. Work happens on plate add, target change, threat events (M6), settings changes, and `hooksecurefunc` post-hooks. |
| R5 | **Secret-value-safe on clients that have secret values (Forever now, retail later) [D]** | On Forever, `UnitHealth`, `UnitThreatSituation`, hostile `UnitName`/`UnitGUID` of `nameplateN` units can be secret (BUG 12). Forever never reads them into Lua logic; where a cue needs them the stock element is restyled instead. Only Era computes health/threat in Lua. |
| R6 | Forbidden frames are skipped | `plate.UnitFrame:IsForbidden()` plates are left exactly as stock. |
| R7 | Stand down when another plate owner is present | If a plate-replacement addon is loaded, skip all styling and print one line naming it. Era test machine has **TidyPlates_ThreatPlates** installed — owner disables it to test. |
| R8 | Unit values that *are* used in Lua pass through `VPS.Plain(v)` | `UnitLevel`, `UnitClassification`, `UnitIsUnit`, reaction: per BUG 12, any non-player unit value is `Plain()`-ed before comparison/arithmetic; a secret becomes `nil` and that cue degrades to stock for that pass. |

## Files

```
VelocityPlateStyle/
  VelocityPlateStyle.toc            ## Interface: 16001  (Forever, default TOC — publish.cs convention)
  VelocityPlateStyle_Camelot.toc    ## Interface: 16001  (Forever flavour suffix)
  VelocityPlateStyle_Vanilla.toc    ## Interface: 11509  (Classic Era)
  Client/Client.lua                 Client.INTERFACE list + VPS.ClientFlavours = {}
  Client/Client_ClassicEra.lua      VPS.ClientFlavours.classic_era = { ... }
  Client/Client_Forever.lua         VPS.ClientFlavours.forever     = { ... }
  Client/Client_Select.lua          picks by WOW_PROJECT_ID / GetBuildInfo(), binds VPS.Client, warns on interface mismatch
  Core.lua                          saved vars + defaults, VPS.Plain, events, plate lifecycle, restyle-all, stand-down
  Skin.lua                          bar styles, backing, outline, target border, level placement
  Textures.lua                      built-in texture/font lists; LSM discovery
  Options.lua                       canvas options page (GotJunk style), slash commands
  Assets/  flat.tga soft.tga glow_calm.tga glow_loud.tga skull.tga VelocityPlateStyle.tga (icon)
  README.md  LICENSE  .pkgmeta (package-as: VelocityPlateStyle, ignore: *.md, SPECS) .gitignore  SPECS/
```

TOC load order: `Client\Client.lua`, `Client\Client_*.lua`, `Client\Client_Select.lua`, `Core.lua`, `Textures.lua`,
`Skin.lua`, `Options.lua`. No embedded libraries in M1 (LibSharedMedia used only if another addon loaded it).

## Architecture

```
   NAME_PLATE_UNIT_ADDED / REMOVED       PLAYER_TARGET_CHANGED        Options change
   hooksecurefunc(stock restyle fns)     UNIT_LEVEL / UNIT_CLASSIFICATION_CHANGED
                      |                              |                     |
                      v                              v                     v
                 +----------+   RestyleAll()   +--------------+
                 |   Core   |<-----------------|   Options    |
                 +----------+                  +--------------+
                      |
        +-------------+-------------+
        v             v             v
   +---------+   +----------+   +------------+
   |  Skin   |   | Textures |   |   Client   |   per-client region resolvers + capability flags
   +---------+   +----------+   +------------+
```

### Client (per-flavour region map)

The workspace rule: flavour-specific shapes live in separate files, one method set, never `if IsForever` at a use
site. Each resolver returns the region or `nil`; a `nil` region means that feature degrades to stock appearance.
Field names below are **unconfirmed until M0**.

```lua
-- Client/Client.lua
Client.INTERFACE = {
  "HealthBar",          -- (uf) -> StatusBar          uf.healthBar
  "HealthBarBorder",    -- (uf) -> Frame/Texture      uf.healthBar.border (Midnight-style plate)
  "NameText",           -- (uf) -> FontString         uf.name
  "LevelText",          -- (uf) -> FontString|nil     uf.LevelFrame.levelText (Era?) / nil
  "ClassificationIcon", -- (uf) -> Texture|nil        uf.ClassificationFrame.classificationIndicator
  "SelectionHighlight", -- (uf) -> Texture|nil        uf.selectionHighlight
  "AggroHighlight",     -- (uf) -> Texture|nil        uf.aggroHighlight
  "HealthText",         -- (uf) -> FontString|nil     stock health text, if the client draws one
  "RestyleHookNames",   -- () -> { "CompactUnitFrame_UpdateHealthColor", "CompactUnitFrame_UpdateHealthBorder", ... }
  "HasSecretValues",    -- () -> boolean   Era false, Forever true   (drives R5 paths)
  "DifficultyColor",    -- (level) -> r,g,b   wraps GetCreatureDifficultyColor / GetQuestDifficultyColor per client
  "PlateOwnerAddons",   -- () -> { "TidyPlates_ThreatPlates", "Plater", "KuiNameplates", "NeatPlates", "Platynator", "ElvUI" }
}
```

Era 1.15.9 and Forever are both on the shared Midnight plate code, so the two files are expected to differ mainly in
`HasSecretValues`, `DifficultyColor`, and any region that one client lacks. M0 decides.

### Core

- `VPS.Plain(v)`: `if v == nil or (issecretvalue and issecretvalue(v)) then return nil end; return v` (BUG 12 helper).
- `PLAYER_LOGIN`: init `VelocityPlateStyleDB` from defaults; R7 check via `C_AddOns.IsAddOnLoaded` over
  `Client.PlayerOwnerAddons()`; if one is loaded set `VPS.standDown = name`, print once, register nothing else.
- `NAME_PLATE_UNIT_ADDED(unit)`: `plate = C_NamePlate.GetNamePlateForUnit(unit)`; `uf = plate.UnitFrame`; skip if
  `uf:IsForbidden()`. If `uf.vpsStyled ~= VPS.styleVersion` run `Skin.ApplyStatic(uf)` (idempotent; plates are pooled).
  Then `Skin.ApplyUnit(uf, unit)` (level, classification, target).
- `NAME_PLATE_UNIT_REMOVED(unit)`: clear per-unit textures (target border off) so a recycled plate starts clean.
- `PLAYER_TARGET_CHANGED`: `Skin.UpdateTarget(uf, unit)` over `C_NamePlate.GetNamePlates()`.
- `UNIT_LEVEL`, `UNIT_CLASSIFICATION_CHANGED` (if the client fires it for plates): re-run the level/classification part
  for that unit's plate.
- `hooksecurefunc` on each name in `Client.RestyleHookNames()`: post-hook receives the frame; if it is a styled plate
  unit frame, re-apply only the property the stock function overwrote (texture after `UpdateHealthColor`, border alpha
  after `UpdateHealthBorder`, ...).
- `VPS.RestyleAll()`: bump `VPS.styleVersion`, re-run `ApplyStatic` + `ApplyUnit` for every visible plate. Called by
  every option change.

### Skin: bar styles (M1)

| Setting | Key | Default | Range |
|---|---|---|---|
| Bar style | `barStyle` | `"modern"` | `"classic"` (Classic Clean) / `"modern"` (Modern Square) |
| Bar texture | `barTexture` | `"VPS:Flat"` | built-ins `VPS:Flat`, `VPS:Soft`, `VPS:Stock`; then LSM statusbar names when LSM is present |
| Bar height | `barHeight` | 12 | 6–24 px |
| Border darkness (Classic Clean) | `borderDarken` | 0.6 | 0–1 vertex-colour toward black |
| Backing alpha (Modern Square) | `backingAlpha` | 0.6 | 0–1 |
| Target border colour | `targetColor` | `{1,1,1,1}` | colour picker |
| Target border thickness | `targetThickness` | 2 | 1–4 px |

**Classic Clean.** Stock art and proportions kept; stock border vertex-coloured toward black by `borderDarken`; stock
fill texture; level in the stock position.

**Modern Square.** Stock border alpha → 0 (not hidden, R2). Added regions on the health bar, all on sublayers
*below* the bar's ARTWORK so foreign icons draw on top:

- `uf.vpsBacking` — BACKGROUND, black at `backingAlpha`, same rect as the bar.
- `uf.vpsOutline` — four 1px textures (pixel-snapped via `PixelUtil.SetPoint`) hugging the bar.
- Fill: `healthBar:SetStatusBarTexture(path)` only. **Colour is never set by us** — stock reaction colouring
  (hostile red / neutral yellow / friendly green / tapped grey) stays, which also keeps this path R5-safe.
- `uf.vpsTarget` — border outside the bar in `targetColor` at `targetThickness`, shown when
  `VPS.Plain(UnitIsUnit(unit, "target"))` is true. Stock `SelectionHighlight` alpha → 0 while this is enabled.

**Level number (M1 part of R3).** M0 finding: in Blizzard's Modern plate style the stock `LevelFrame` is never shown
(Era), and Forever instead draws a separate `PlayerLevelDiffFrame` box beside the bar. So VelocityPlateStyle **owns its
own** `uf.vpsLevel` FontString on the health bar, right inside edge, text from `Plain(UnitLevel(unit))`, colour from
`Client.DifficultyColor(level)` (`GetRelativeDifficultyColor`). `-1` (skull) → `??` in red until M3 adds the glyph.
Modern Square: Forever's `PlayerLevelDiffFrame` alpha → 0 (R2). Classic Clean: `vpsLevel` hidden, stock level left as
is. `ClassificationIcon` (elite/rare dragons) already sits left of the bar beside the raid icon and is left **stock** in M1.
Level and classification values go through `VPS.Plain`; `nil` → leave stock.

Region names, overwrite functions and CVars: `AddonManagement\_EXTERNAL_APIS\wow_nameplate_unitframe_regions.md`.

Size: bar height only. Plate width/scale are client settings (mirror section, M5).

### Text elements — the layout grid (M2) **[D 2026-11-23]**

Replaces the fixed name/level/health rows. Every piece of text on the plate is a **VPS_TextElement** with the same
five controls, laid out by one engine. The owner's picture: "for each thing: {above, below, inside, left, right,
hidden} × {left, center, right} × size, plus a colour column, plus a box below to create custom elements".

```lua
-- VPS_TextElement (one row of VelocityPlateStyleDB.elements, in display order)
{
  id      = "name",            -- VPS_ElementID: built-ins "name" | "level" | "health" | "healthpct"; custom = "c<n>"
  label   = "Name",            -- shown in the grid; editable for custom elements
  format  = "[name]",          -- VPS_FormatString; built-ins are fixed, custom is player-entered
  anchor  = "above",           -- VPS_Anchor: above | below | inside | left | right | hidden
  align   = "center",          -- VPS_Align:  left | center | right      (left/right anchors: top | middle | bottom)
  size    = 10,                -- font size px, 6..20 (SetFont, never SetTextHeight — stretched text is blurry)
  color   = "stock",           -- VPS_ColorMode: stock | white | difficulty | class | custom ; customColor = {r,g,b}
}
```

**Defaults** (order matters — see stacking):

| # | id | format | anchor | align | size | color |
|---|---|---|---|---|---|---|
| 1 | `name` | `[name]` | above | center | 10 | stock |
| 2 | `level` | `[level]` | inside | right | 9 | difficulty |
| 3 | `health` | `[hp]` | hidden | right | 9 | white |
| 4 | `healthpct` | `[hp%]` | hidden | right | 9 | white |

**Layout engine (Skin.lua).** Six anchor **slots** on the health bar: `above`, `below`, `inside` are horizontal rows
spanning the bar; `left`, `right` are vertical columns beside it (outside the outline + 4px). Within a slot, elements
are grouped by `align`; a group is laid as a **flow**: the first element in list order takes the edge, the next is
anchored to its free side with a 4px gap (`inside`+`right`: `68%` then `709K` to its left — exactly screenshot 2).
`center` groups are centred as a chain (first element centred, others hang off it alternately right/left — rare in
practice; documented so it is deterministic). `left`/`right` slots lay elements vertically by `align` = top/middle/
bottom with the same flow rule. Row height = max font size in that row; `above`/`below` sit 2px off the bar.

All FontStrings are **ours** (`uf.vpsText[id]`), parented to the health bar. The **stock** `uf.name` and the stock
health texts (`healthBar.Text/LeftText/RightText`) and stock level regions are **alpha-zeroed** (R2) while the
addon is active. Rationale: on Era 1.15.9 the stock name is a *restricted region* (BUG, debugged 2026-11-22):
`GetPoint/GetWidth/GetEffectiveScale` raise `Can't measure restricted regions`, so it cannot participate in a flow
layout that needs widths. Our own strings can be measured freely.

**Format tokens** (`VPS.Format.Expand(format, unit) -> string`), every unit read through `Plain()`:

| token | value | Era | Forever |
|---|---|---|---|
| `[name]` | `Client.UnitDisplayName(unit)` — see "Unit names" below | ✓ (`UnitName`, one name) | `"First Surname"` like stock; secret for hostiles in combat/instances → **element shows the first-name secret via `SetText(secret)`** only when the format is exactly `[name]`; in any other format the token expands to `""` |
| `[level]` | `UnitLevel`, `-1` → `??` | ✓ | ✓ (verify) |
| `[hp]` | `UnitHealth` abbreviated (`709K`) | ✓ | secret → `""` |
| `[hp%]` | `floor(hp/hpmax*100).."%"` | ✓ | secret → `""` |
| `[hpmax]` | `UnitHealthMax` abbreviated | ✓ | secret → `""` |
| `[class]` | `rare` / `elite` / `rare elite` / `boss` / `""` | ✓ | ✓ |
| `[class+]` | `r` / `+` / `r+` / `??` / `""` (compact suffix) | ✓ | ✓ |
| `[creature]` | `UnitCreatureType` | ✓ | ✓ (verify) |
| `\|cAARRGGBB` … `\|r` | colour codes typed by the player pass through unchanged | ✓ | ✓ |

An element whose expanded string is `""` is hidden for that pass and takes no room in the flow. On Forever this
means a custom `[hp] / [hpmax]` element is blank in restricted content — accepted **[D]**; the tooltip on the
format box says so.

**Health updates (Era only).** `UNIT_HEALTH` for `nameplateN` units re-expands only the elements whose format
contains an `[hp…]` token (`VPS.Format.UsesHealth(format)` cached per element). On Forever `HasSecretValues()`
skips the registration entirely (R5). No `UNIT_HEALTH_FREQUENT`, no timers (R4).

### Unit names — match the stock plate exactly **[D 2026-11-23]**

Forever characters (players AND mobs) have a first name and a surname; the stock plate shows both. Until this change
VPS read `UnitName(unit)` and kept only the first return, so every Forever plate showed the first name only.
Workspace rule (`PROJECT_STRUCTURE.md` "CHARACTERS HAVE TWO NAMES"): `UnitName` is never called at a use site —
only inside a flavour file. The use sites are `Format.lua` (`[name]` resolver) and `Skin.lua` (bare-`[name]`
pass-through); both go through one new interface method.

**What the stock plate does** (`_ref\blizzard\forever\nameplates\CompactUnitFrame.lua:843`,
`Blizzard_NamePlateUnitFrame.lua:630`, `_ref\blizzard\forever\UnitFrame.Mainline.lua:1085`,
`_ref\blizzard\forever\Camelot_NameUtil.lua`):

```lua
local showFullName = frame.optionTable.updateNameUsesGetUnitName   -- true for enemy + friendly plate option sets
                     and not frame.hideRealmName                      -- true only for friendly PLAYERS when
                                                                       -- CVar nameplateShowFriendlyRealmName is off
local name = GetUnitName(frame.unit, showFullName)                    -- UnitName -> name, server; Camelot: server = surname
```

**Interface** (`Client.INTERFACE`, both flavours):

| method | Era (`Client_ClassicEra.lua`) | Forever (`Client_Forever.lua`) |
|---|---|---|
| `UnitDisplayName(unit)` → string \| secret \| nil | `(UnitName(unit))` — one name | `first, second = UnitName(unit)`; if `Plain(first)` or `Plain(second)` is nil (secret) → return `first` **unjoined** (display-only pass-through, never compared); else → `GetUnitName(unit, Client.UnitShowsFullName(unit))` — the very function the stock plate calls, so separator / realm-label rules are Blizzard's, not ours |
| `UnitShowsFullName(unit)` → boolean | `false` | `not (Plain(UnitIsFriend("player", unit)) == true and Plain(UnitIsPlayer(unit)) == true and not GetCVarBool("nameplateShowFriendlyRealmName"))` — mirrors `UpdateNameRealmDisplay`; a secret reaction/player flag counts as "show full" (hostiles are the secret ones and hostiles always show full) |

**Use sites:**

- `Format.lua` `[name]` resolver: `local v = Plain(Client.UnitDisplayName(unit)); return v or ""`.
- `Skin.lua` bare-`[name]`: `text = Client.UnitDisplayName(unit); if text == nil then text = "" end` — a secret goes
  straight to `SetText` exactly as today; the only change is that a plain name is now the full name.

**CVar mirror (R1-safe).** We read `nameplateShowFriendlyRealmName`, never write it. When the player toggles it,
stock runs `CompactUnitFrame_UpdateName` on every plate via its CVar callback; our existing `hooksecurefunc` on that
function (`Core.lua:301`) already re-runs `ApplyTexts`, so no new event registration is needed.

**Non-goals.** No `[firstname]` / `[surname]` tokens, no option to hide surnames: the plate shows what Blizzard
shows, per owner. Era behaviour is unchanged.

**Verification (Forever, owner):**

- [ ] `/dump UnitName("target")` on a mob → two returns `"First", "Surname"` (records the Camelot shape here: ________)
- [ ] `/dump GetUnitName("target", true)` → the string the stock plate shows (separator seen: ________)
- [ ] Mob plate with VPS on shows the same string as with VPS off (`/vps` → disable via stand-down or `/reload` without the addon)
- [ ] Friendly player plate in bar mode: surname follows `nameplateShowFriendlyRealmName`; toggling the CVar updates
      live without `/reload`
- [ ] Hostile in an instance / in combat (secret name): plate still shows a name, no Lua errors (`/vps status` error count 0)
- [ ] Era: unchanged (`Kuro`, one name)

Milestone: part of **M4 — Forever verification pass**.

**Colour modes.** `stock` = copy the stock region's current vertex colour at each update (name: reaction/tap colour
from the alpha-zeroed `uf.name`; health: white). `difficulty` = `Client.DifficultyColor(playerLevel, unitLevel)` —
**the only mode offered for `level`** (R3). `class` = `RAID_CLASS_COLORS` for players, else white. `custom` = the
swatch.

**R3 under this model.** `level` cannot be `hidden`: its anchor dropdown omits that entry. Every other element may.

### Options page: the element grid (M2)

One **dense table** in the Text section, one row per element in `db.elements` order:

```
 ▲▼  Name          [above  ▾]  [center ▾]  [10 ▾]  [stock      ▾] ■
 ▲▼  Level         [inside ▾]  [right  ▾]  [ 9 ▾]  [difficulty  ]
 ▲▼  Health        [hidden ▾]  [right  ▾]  [ 9 ▾]  [white      ▾] ■
 ▲▼  Health %      [hidden ▾]  [right  ▾]  [ 9 ▾]  [white      ▾] ■
 ▲▼  My elite tag  [inside ▾]  [left   ▾]  [ 8 ▾]  [custom     ▾] ■   [×]

 Create custom element
   Name   [________________]
   Format [________________________________]   tokens: [name] [level] [hp] [hp%] [hpmax] [class] [class+] [creature]
   [ Add ]
```

- Columns: reorder arrows (▲▼ move the row one step; order = stacking order within a slot), label, anchor dropdown,
  align dropdown, size dropdown (6..20), colour dropdown + swatch button (enabled only for `custom`), delete `×`
  (custom rows only). Cells are `UIDropDownMenuTemplate` buttons sized to the column; no sliders in the grid.
- Custom rows have an editable label (click to edit) and show their format string in the tooltip.
- **Create custom element**: label + format `InputBoxTemplate`, Add appends `{ id = "c"..nextId, anchor = "inside",
  align = "left", size = 9, color = "white" }` and re-renders the grid. Empty label or format → chat hint, nothing added.
- Every change bumps the style version (`VPS.RestyleAll()`).

### Bar styles — Classic Clean retired for now **[D 2026-11-23]**

Only the flat style ships. `barStyle` and `borderDarken` are removed from the DB (migration: drop the keys). The
stock backing+border atlas and the non-target darkening are alpha-zeroed unconditionally; our backing, 1px outline
and target border always draw. "Themes" (squared / rounded / stock art) return later as a single `theme` key once the
layout work is settled. The level number is no longer a Style-section toggle: it is the `level` row of the grid.

### Era 1.15.9 restricted regions — hard rule **[D]**

The stock `uf.name` FontString (and possibly other stock plate regions) is **restricted for addon code** on Era:
measurement calls (`GetPoint`, `GetWidth`, `GetStringWidth`, `GetEffectiveScale`, `GetRect`) raise
`Can't measure restricted regions`, and anything that measures internally (`PixelUtil.SetPoint`, `PixelUtil.SetSize`)
silently fails. Writes (`SetPoint`, `SetAlpha`, `SetFont`, `SetJustifyH`, `SetVertexColor`) are allowed.
**Consequence:** never measure a stock plate region; never pass one to `PixelUtil`; only ever measure our own
`uf.vps*` regions. Record in `_EXTERNAL_APIS\wow_nameplate_unitframe_regions.md`.

### Threat level: classification modes + danger emphasis (M3)

| Mode | Elite | Rare | Boss / skull |
|---|---|---|---|
| Stock icon (default) | stock dragon, re-anchored | stock silver dragon | stock skull |
| Text | `12+` | `12r` / `12r+` | `??` or skull glyph |
| Frame | gold outer outline | silver outer outline | red outer outline |
| Icon + Frame | both | both | both |

Danger emphasis: level ≥ player level + `dangerThreshold` (default 3), or skull → larger red level text on a dark chip.
No off switch for either (R3).

### Aggro indicator (M6 — last)

Modes Off / Subtle (outline recolour) / Calm (soft edge glow) / Loud (spiked glow); states "aggro on me" / "also warn
when close". **Era:** `UNIT_THREAT_LIST_UPDATE` + `UnitThreatSituation("player", unit)` through `Plain()`.
**Forever [D]:** no threat reads; the stock `AggroHighlight` region is restyled (texture, size, alpha) to the chosen
mode and the client decides when it shows; unexpressible modes fall back to the nearest and the tooltip says so.

### Danger Highlight scope (M2e) **[D 2026-11-24]**

The over-level cues are a *character's* risk posture (a Hardcore alt wants +2 / skulls at +3; a main does not), so the
player chooses **where the danger settings live**. Everything else in the DB stays account-wide as today.

**Sections.** The old *Target Highlight* section splits in two:

| Section | Keys | Scope |
|---|---|---|
| **Selected Target Highlight** | `targetColor`, `targetThickness` | account-wide (unchanged) |
| **Danger Highlight** | `overLevelMode`, `overLevelThreshold`, `skullAtLevelsAbove` — the `VPS_DangerSettings` record | chosen by `dangerScope` |

**The switch** (`db.dangerScope`, itself always account-wide — it decides where to look), shown as three radio buttons at
the top of the Danger Highlight section, no "(default)" wording in the UI:

```
 Danger highlight settings apply:   (•) To all characters   ( ) Per Edit Mode layout   ( ) To this character only
```

| `dangerScope` | record read/written | key |
|---|---|---|
| `"global"` (default) | `db.danger` | — |
| `"layout"` | `db.dangerByLayout[layoutName]` | the game's **active Edit Mode layout name**, via a copy of VQT's `Core\LayoutProfile.lua` (merged list from `EditModeManagerFrame.layoutInfo`, presets first; `EDIT_MODE_LAYOUTS_UPDATED` read next frame; create = copy of the active record, rename moves it, delete drops it). Both clients have Edit Mode (`_EXTERNAL_APIS\wow_edit_mode_layouts_api.md`). |
| `"character"` | `db.dangerByChar[guid]` | `UnitGUID("player")` — never a name (workspace rule) |

**Resolution.** One accessor, used at every read site (`Skin.IsOverLevel`, `ApplyOverLevel`, `VPS.SkullCount`, Options):

```lua
function VPS.Danger()           -- -> VPS_DangerSettings (live table; Options writes into it)
  local d = VPS.db
  if d.dangerScope == "character" then return Bucket(d.dangerByChar, VPS.Client.PlayerKey())
  elseif d.dangerScope == "layout" then return Bucket(d.dangerByLayout, VPS.LayoutProfile.Name())
  else return d.danger end
end
-- Bucket(t, key): t[key] or a fresh DeepCopy of d.danger (the global record) stored under key.
```

- **Seeding [D 3]:** a bucket that does not exist yet is created as a copy of the *global* record at first access, so
  switching scope never visibly changes anything until the player edits. Switching back to global shows the global
  record again; the other buckets are kept (nothing is deleted by flipping the switch).
- **Migration (DB v4 → v5):** the three flat keys move into `db.danger = { overLevelMode, overLevelThreshold,
  skullAtLevelsAbove }`; the flat keys are removed. `CopyDefaults` fills `danger` from `VPS.DEFAULTS.danger`.
- Layout name before Edit Mode reports it (a moment after `PLAYER_LOGIN`): the placeholder `"Default"` is used, and
  `LayoutProfile.OnChanged` triggers `VPS.RestyleAll()` so plates re-read the right bucket as soon as the real name
  arrives — same for a layout switch in the game's dropdown.
- `/vps status` appends `danger: <scope> (<key>)`.

**Non-goals [D]:** no scope switch for any other section (bar, text grid, target border stay account-wide); no
import/export; no per-spec buckets.

**Saved variables (added):**

```lua
  Version = 5,
  dangerScope = "global",                          -- VPS_DangerScope: global | layout | character (always account-wide)
  danger = { overLevelMode = "animatedRed", overLevelThreshold = 2, skullAtLevelsAbove = 10 },   -- VPS_DangerSettings
  dangerByLayout = { [layoutName] = VPS_DangerSettings },   -- Edit Mode layout name
  dangerByChar   = { [guid] = VPS_DangerSettings },         -- UnitGUID("player")
```

**Open question:** should the *rest* of VPS (bar/text/target) also become per-Edit-Mode-layout like VelocityQuestTracker?
Not in this milestone; if yes, it is its own milestone with a whole-DB `profiles[layoutName]` move.

## Settings panel

**[D] Stock vertical layout is NOT used.** The page is a **canvas category in the GotJunk style**
(`Settings.RegisterCanvasLayoutCategory(frame, "VelocityPlateStyle")` + `RegisterAddOnCategory`; fallback
`InterfaceOptions_AddCategory`): a `UIPanelScrollFrameTemplate` scroll with a 620px content frame, title +
description, bordered `Section(header)` boxes using `UI-Tooltip-Background/Border`, `InterfaceOptionsCheckButtonTemplate`
checkboxes, `OptionsSliderTemplate` sliders with the label above-left, `UIDropDownMenuTemplate` dropdowns, and each
widget carrying an `Update()` called from the frame's `OnShow`. Copy the helper shapes (`Place`, `Check`, `Slider`,
`Section`) from `GotJunk\GotJunk.lua:847–921`; do not share code across repos.

Side effects: BUG 13 (shared-list taint) does not apply to canvas pages, and the `RegisterProxySetting` taint question
from the draft is moot. Opened by `/vps` (no args) and `/velocityplatestyle`.

Sections, in order:

1. **Style** — bar texture, bar height, backing darkness
2. **Target** — border colour (`ColorPickerFrame`), thickness
3. **Text** (M2) — the element grid + "Create custom element" box (see "Options page: the element grid")
4. **Threat level** (M3) — classification mode, danger threshold
5. **Aggro** (M6) — mode, states
6. **Blizzard nameplate settings** (M5) — CVar mirror, header line stating these are Blizzard's own settings;
   controls shown only when `C_CVar.GetCVarInfo(name)` is non-nil; disabled between `PLAYER_REGEN_DISABLED/ENABLED`;
   refreshed on `CVAR_UPDATE`. Candidate CVars: `nameplateShowAll`, `nameplateShowEnemies`, `nameplateShowFriends`,
   `nameplateShowEnemyMinions/Pets/Guardians/Totems`, `nameplateMotion`, `nameplateMaxDistance`, plus the 1.15.9
   size/style CVars (names from M0 source).

If R7 stood down, a red notice naming the other addon sits at the top of the page.

**Visual texture picker (M2).** M1 ships a plain `UIDropDownMenuTemplate` list of texture names. M2 replaces it: the
button shows the current texture name over a strip of that texture; the list draws every row with its own texture as
the row background, outlined white name, checkmark on the current pick; hover = live preview on visible plates,
close without click = restore. Built with `MenuUtil.CreateContextMenu` + `root:SetScrollMode` if available on both
clients (confirm in M0), else an addon-built scrolling list frame with the same row look. The same component serves
the font dropdowns (each row in its own font).

## Saved variables

```lua
-- ## SavedVariables: VelocityPlateStyleDB   (account-wide; no profiles, no per-character data — nothing is keyed by character)
VelocityPlateStyleDB = {
  Version = 2,                                      -- 1 -> 2: drop barStyle, borderDarken, showLevel; add elements
  barTexture = "VPS:Flat", barHeight = 12, backingAlpha = 0.6,
  targetColor = { 1, 1, 1, 1 }, targetThickness = 2,
  -- M2: ordered list of VPS_TextElement (see "Text elements"); order = stacking order within an anchor slot
  elements = {
    { id = "name",      label = "Name",     format = "[name]",  anchor = "above",  align = "center", size = 10, color = "stock" },
    { id = "level",     label = "Level",    format = "[level]", anchor = "inside", align = "right",  size = 9,  color = "difficulty" },
    { id = "health",    label = "Health",   format = "[hp]",    anchor = "hidden", align = "right",  size = 9,  color = "white" },
    { id = "healthpct", label = "Health %", format = "[hp%]",   anchor = "hidden", align = "right",  size = 9,  color = "white" },
    -- custom rows: { id = "c3", label = "...", format = "...", anchor, align, size, color = "custom", customColor = {r,g,b} }
  },
  nextCustomId = 1,
  overLevelMode = "animatedRed", overLevelThreshold = 2, skullAtLevelsAbove = 10,   -- M2c / M2d (see milestones)
  -- M3
  classificationMode = "icon", dangerThreshold = 3,
  -- M6
  aggroMode = "off", aggroStates = "me",
}
```

## Slash `/vps`

`(none)` / `options` open the page · `status` prints client flavour, style version, stand-down state, LSM presence ·
`reset` restores defaults and restyles.

## Compatibility (M7)

Test targets: Questie quest icons, raid target markers, stock cast bar, stock aura row, Details/threat-number
decorators. Policy, not detection: our added textures sit below the bar's ARTWORK layer; bar height moves only
things anchored to the health bar (desired).

## Out of scope

Plate visibility rules, name-only modes, per-NPC styles, aura/debuff rows, cast bar restyling, threat numbers,
totem/execute indicators, class icons, profiles/import/export, **Edit Mode integration [D — not needed]**, friendly-plate
special handling beyond leaving them stock.

## Open questions

- **Region names per client** (M0). Including whether Era 1.15.9 exposes `LevelFrame.levelText` or draws the level
  elsewhere, and whether the Midnight-style plate has a separate `border` frame vs texture.
- **Stock restyle functions** (M0): exact list of `CompactUnitFrame_*` / `NamePlate*` functions that reset texture,
  border, and level on Era vs Forever.
- **`MenuUtil` scroll mode + per-element initializers** on Era 1.15.9 and Forever (M0/M2) — decides the picker fallback.
- **Forever: is `UnitLevel`/`UnitClassification` of a hostile plate unit ever secret?** If yes, the M1 level colouring
  degrades to stock on Forever; `Plain()` handles it either way. Add to the BUG 12 M0 dump checklist:
  `/dump issecretvalue(UnitLevel("nameplate1"))`, `issecretvalue(UnitClassification("nameplate1"))`.
- **Mirror CVar list** post-1.15.9 (M5).
- **Sample plate preview inside the options page** — later, if live preview on real plates proves insufficient.

## Alternatives considered

- Full plate replacement — owns visibility/click/health; conflicts with R1/R2; most constrained under secret values.
- Configuring Threat Plates / Plater / Platynator / BetterBlizzPlates — none is single-purpose + native settings +
  Era & Forever at once.
- CVars only — no flat texture, backing, target border, or threat-level modes.
- Embedding LibSharedMedia — kept dependency-free; LSM used opportunistically.
- Stock vertical-layout Settings page — rejected **[D]** in favour of the workspace's GotJunk canvas style (also avoids BUG 13).