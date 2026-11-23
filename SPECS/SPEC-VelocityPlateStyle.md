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

- [ ] **M0 — Research (Researching phase, before any code).** Fetch `Blizzard_NamePlates` + `CompactUnitFrame.lua` (+ `NamePlates.xml`)
      for the `classic_era` and Forever/Camelot source branches into `_ref\blizzard\classic_era\nameplates\` and
      `_ref\blizzard\forever\nameplates\`; write `AddonManagement\_EXTERNAL_APIS\wow_nameplate_unitframe_regions.md`
      with the confirmed region names per client (the ClientMap table below) and the list of stock functions that
      re-apply colour/size. Confirm in game with `/fstack` on Era.
- [ ] **M1 — Era bring-up: scaffold + settings + basic visual config + level in bar.** Three TOCs, `Client\` layout,
      Core plate lifecycle, Classic Clean + Modern Square, bar texture (built-ins + opportunistic LSM, **text dropdown
      first**), bar height, backing alpha, border darkness, target border, level number with difficulty colour and stock
      classification icon re-anchored, GotJunk-style canvas options page, R7 stand-down. **No threat/aggro features.**
- [ ] **M2 — Text controls + visual texture picker.** Name / level / health-text font, size, outline, colour mode;
      the per-row-textured picker for textures and fonts; health text (Era: computed; Forever: restyle only).
- [ ] **M3 — Threat level (classification) modes + danger emphasis.** Text / Frame / Icon+Frame modes, danger threshold.
- [ ] **M4 — Forever client file + verification pass** on 1.60.1 (R5 path throughout).
- [ ] **M5 — Blizzard-settings mirror section** (CVar-bound controls, per-client CVar list).
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

### Text (M2)

| Element | Controls |
|---|---|
| Name | font, size, outline (none / thin / thick), colour mode (stock / white / custom) |
| Level | font, size, outline (colour is difficulty-driven) |
| Health text | mode (none / percent / current), font, size, outline |

Health text: **Era** computes from `UnitHealth`/`UnitHealthMax` on `UNIT_HEALTH` for plate units (both values
`Plain()`-ed). **Forever**: `HasSecretValues()` → mode list collapses to what the stock plate's own health text
supports and only its font is restyled; the dropdown tooltip says why.

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

1. **Style** — bar style, bar texture, bar height, border darkness (Classic Clean), backing alpha (Modern Square)
2. **Target** — border colour (`ColorPickerFrame`), thickness
3. **Threat level** (M3) — classification mode, danger threshold
4. **Text** (M2) — name / level / health text
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
  Version = 1,
  barStyle = "modern", barTexture = "VPS:Flat", barHeight = 12, borderDarken = 0.6, backingAlpha = 0.6,
  targetColor = { 1, 1, 1, 1 }, targetThickness = 2,
  -- M2
  name  = { font = "VPS:Friz", size = 10, outline = "thin", colorMode = "stock", color = { 1, 1, 1 } },
  level = { font = "VPS:Friz", size = 9,  outline = "thin" },
  health = { mode = "none", font = "VPS:Friz", size = 9, outline = "thin" },
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