# Velocity Plate Style

Restyles **Blizzard's own nameplates** - flat bar, crisp 1px outline, level number inside the bar,
a clear target border - and does nothing else. Which plates appear, how far away, how big, how they
stack: all of that stays with the game's own Options > Nameplates.

**Classic Era / Hardcore and WoW Forever**, from one codebase.

## What it changes

- **Modern Square** (default): Blizzard's rounded bar art is replaced with a flat fill, a 1px black
  outline and a dark backing so the bar edge and the missing health stay readable. The unit level sits
  inside the bar at the right, coloured by difficulty (grey / green / yellow / orange / red; `??` for skull).
- **Classic Clean**: Blizzard's own bar art and proportions, with the border darkened so the edge reads.
- **Target border** in a colour and thickness of your choice; Blizzard's own target highlight is
  switched off while it is on.
- **Bar texture**: Flat, Soft, or Blizzard's own. If another addon has loaded LibSharedMedia, its
  statusbar textures are offered too (not required, not bundled).
- **Bar height** slider.

## What it never does

- Never shows, hides, moves or resizes a plate. Never touches a CVar on its own. Nothing runs on a
  timer; it reacts to plates appearing, your target changing and your settings changing.
- Leaves Questie icons, raid markers, cast bars and auras exactly where they are - they draw on top.
- Stands down, with one chat line, if a plate-replacement addon (Threat Plates, Plater, Kui, NeatPlates,
  Platynator, ElvUI nameplates...) is running.

## Options

`/vps` opens the page (Options > AddOns > Velocity Plate Style). `/vps status` prints the client, style and
plate count; `/vps reset` restores defaults. Settings are account-wide.

## Roadmap

Text controls (name / level / health text font, size, outline), a visual texture picker, elite / rare /
boss representation modes, a mirror of the game's own nameplate settings, and an aggro cue. See
`SPECS/SPEC-VelocityPlateStyle.md`.

## Licence

MIT.