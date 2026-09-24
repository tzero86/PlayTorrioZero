# ZPlay brand marks

Three candidate directions for the ZPlay logo. Each direction ships a **mark**
(icon, 1:1), a **horizontal lockup** (mark + "ZPlay" wordmark) and a
**monochrome** lockup for one-colour use on dark or light surfaces.

```
assets/branding/
├── orbital/  mark.svg  lockup.svg  mono.svg
├── signal/   mark.svg  lockup.svg  mono.svg
└── prism/    mark.svg  lockup.svg  mono.svg
```

Every file is hand-authored SVG paths and shapes: no `<image>`, no raster data,
no web fonts, no external references and no `width`/`height` attributes (only
`viewBox`), so they scale from a 16px favicon to a store banner and can be
re-tinted from the host.

The accent is settled (Signal Teal, below); the *mark* is not. These are three
considered directions to choose between, not one idea in three costumes: a
tilted orbit around the play glyph, the Z drawn as a signal trace, and the play
glyph split into three streams.

---

## The accent is a parameter, not part of the mark

Every shape is painted with `currentColor` except **one** element per direction,
which carries the accent as a literal hex. The colour layer is the app's chosen
accent:

| token | value |
| --- | --- |
| accent | `#2FD0C0` (Signal Teal) |
| hover / pressed | `#5ADFD2` / `#22B3A5` |
| neutral base | `#0A0D12` (cool near-black slate) |

The accent is cool teal, i.e. the **cyan/green** sector: against the app's eight
presets it is a close sibling of `emerald` and `sapphire` and a deliberate cool
counterpoint to the six warm or violet ones (`amethyst`, `cyberpunk`, `sunset`,
`amber`, `vampire`, `barbie`). That spread is exactly why each direction keeps
the accent on one element only — the identity has to survive all eight presets,
and the neutral silhouette has to survive a preset being changed underneath it.

**Re-tinting.** The accent is a single hex per file; find-and-replace it (or set
it from the app) and the mark follows. Within a direction it is always the same
idea — the orbit ring for `orbital`, the signal trace for `signal`, the middle
slice for `prism` — so re-tinting changes one part while the neutral silhouette
stays intact.

**`currentColor` in practice.** With the SVG inlined (or in a Flutter widget that
sets a colour) the neutral parts follow the surrounding `color` — a near-white on
the dark base and near-black on a light surface; the exact neutral ink is the
app's to choose, and the only value fixed here is the accent. Loaded through
`<img src>` or `background-image` there is no inherited colour and
`currentColor` falls back to black, so those call sites must recolour the asset
(Flutter: `flutter_svg`'s `ColorMapper`, or bake a white variant). The `mono.svg`
files use `currentColor` for *everything* — no accent hex at all — which makes
them the right asset for stamps, watermarks and Android's themed/monochrome icon
layer.

---

## 1. `orbital` — everything orbits the player

**Concept.** A single elliptical orbit, tilted 40° into the picture plane, with
the play core held still at its centre. The ring is the catalogue — films, TV,
anime, manga, audiobooks, music and live channels — travelling around one
playback point. The ring never touches the core: it clears it by ~10 units, so
the two shapes stay separate at every size and in a single colour.

**Why it fits a media client.** Streaming clients are aggregators; the promise is
"all of it, one player". The orbit says *breadth* while the play core says
*playback*, and the tilt keeps it from reading as a plain record button. It is
also the most "app-like" of the three: the ring against a dark surface has the
same presence as the launcher art it will replace.

**At 16px.** Ink is 105.3 × 100.5 of a 128 box (82% wide), the ring stroke is 16
units (2px at 16px) and the core is 42 units (5.3px). At 16px it reads as a
tilted ring with a play inside; it is the least crisp of the three at that size
because it is the only direction made of two separate objects plus negative
space. Treat 24px as its comfortable floor.

**Colour.** Wants the accent on the **ring** and the neutral on the play core:
the ring is the abstract part, the core is the constant. On the dark base:
`#2FD0C0` ring, near-white core. Mono: both in `currentColor`, still fully
legible, because no shape relies on colour to separate it from another.

**Geometry.** `128×128`. Ring: one `<ellipse rx=50 ry=36>` rotated `-40°`,
`stroke-width=16`, no fill. Core: filled triangle + `stroke-linejoin="round"`
(`stroke-width=16`) to round its corners. Core nudged 1.5 units right of
geometric centre to correct the play glyph's left-heavy mass.

---

## 2. `signal` — the Z as a broadcast waveform

**Concept.** No play glyph at all. The "Z" of ZPlay is drawn as a square-wave
trace: an uncompromising rectangle for the top rail and the bottom rail, and a
three-step signal between them, in the accent. The letterform is the waveform and
the waveform is the letterform; the accent is the signal travelling through the
mark.

**Why it fits a media client.** Media is a signal — encoded, transmitted,
decoded — and the Z is the only asset the brand already owns. It is the most
*ownable* of the three: a competitor can draw a ring with a play, but this Z is
ours, and it ties the mark to the wordmark instead of competing with it (the mark
is the "live" version of the lockup's first letter).

**At 16px.** This is the strongest direction at the smallest sizes, and the
reason is structural: it has no interior negative space and no second object. The
strokes are 16 units wide (2px at 16px, well above the ~1.4px where hairlines
start to grey out) and the staircase rungs close up into a clean diagonal, so the
mark degrades to "a bold Z" — the shape it is — instead of to a smudge. It is
also the only direction whose ink (88 units, 69%) sits essentially inside the
outer 66% icon safe zone with no rescaling.

**Colour.** Wants the accent on the **trace** and the neutral on the two rails.
That puts the colour on the moving part and the fastening on the still part, and
because the trace's round terminals sit exactly on the rails' rounded ends, the
joint is invisible whatever the two colours are. On the dark base: `#2FD0C0`
trace, near-white rails.

**Geometry.** `128×128`. Square ink, 88 × 88, centred (margins 20). Stroke 16,
`stroke-linecap="round"` (the round ends are what makes the trace and the rails
fuse seamlessly at the corners), `stroke-linejoin="miter"` so the steps are crisp
and digital rather than soft. Rungs at y 52 and 76, x 76 and 52.

---

## 3. `prism` — one glyph, three streams

**Concept.** The play glyph sliced into three and sliding apart along the beam:
the slices are equal in area, separated by two clean vertical cuts, and each one
shifts a little further than the last. The middle slice — the refracted ray —
carries the accent. It is the only direction that starts from the shape the app
uses today and deconstructs it, which makes it the most explicit "this replaces
the placeholder" statement.

**Why it fits a media client.** One source, many tracks: a single library
resolving into multiple streams, formats and qualities. The three slices also
echo plural playback (multi-audio, multi-subtitle, picture-in-picture) without
needing a caption.

**At 16px.** Equal-area slicing is what makes this work small: because each slice
carries a third of the ink, no slice becomes a hairline, and the 6-unit gaps
between them collapse to zero at 16px so the mark degrades gracefully into a
solid play triangle — losing its distinctive detail last, not first. At 128px and
up the cuts and the 6/12-unit slide resolve.

**Colour.** Wants the accent on the **middle slice** and the neutral on the outer
two. The outer slices keep the overall triangular silhouette reading as one
object, while the accent reads as the one ray being pulled out. On the dark base:
`#2FD0C0` middle slice, near-white outer slices.

**Geometry.** `128×128`. Filled polygons, sharp corners (a prism should look cut,
not moulded). Base edge x=20, tip x=104, height 88. Cuts at 0.1835 and 0.4226 of
the width — the positions that split a triangle into equal areas — then the
slices slide 6 and 12 units along the beam. Ink 98 × 88, centre nudged 4 units
right of geometric centre so the right-pointing mass looks centred.

---

## Recommendation: `signal`

Pick the monogram.

1. **It survives 16px best**, and 16px is not the corner case here — it is the
   Windows taskbar, the macOS Dock, the favicon and the Android TV launcher
   browse row. `signal` is the only direction with no interior negative space, so
   it is the only one that cannot turn to mush: the staircase closes into a
   diagonal, the rails stay solid, and what is left is a bold Z. `prism` is a
   close second and degrades into a clean triangle; `orbital` is last, because a
   ring plus a core plus the gap between them is three things to resolve in
   sixteen pixels.
2. **It is the most ownable.** A tilted ring with a play inside is a crowded
   idea; so is a sliced play button. The Z is ours, and the mark reinforces the
   wordmark rather than duplicating it.
3. **It is the best citizen in the ecosystem.** Its ink is 88/128 (69%), so it
   nearly fits Android's adaptive-icon safe zone before any rescaling, it holds
   up as a single-colour favicon, and it is the direction that loses least when
   the accent is stripped out entirely for the mono variant.
4. **It fits the accent.** Teal on a cool near-black base is a signal colour;
   `signal` is where that meaning lands literally rather than decoratively.

`orbital` is the strongest of the three as an *app icon with a dark plate behind
it* — it has the most presence at launcher sizes and is the most immediately
"media app". If the launcher art matters more than the favicon, choose `orbital`
and accept `signal`'s silhouette as the small-size fallback. `prism` is the
safest if the priority is staying close to the play-button convention that users
already recognise.

### Icon sizing (applies to all three)

Each mark is drawn to fill roughly 80% of its square, which is the right weight
for a favicon, a taskbar icon or artwork that sits directly on a surface. Android
adaptive icons have a stricter budget: the safe zone is a 66dp circle inside the
108dp foreground layer, i.e. the ink must not exceed 61% of that canvas. So for
adaptive icons, place the mark at:

| direction | mark ink fills | render at (of the 108dp foreground) |
| --- | --- | --- |
| `signal` | 69% | **89%** |
| `prism` | 77% | **80%** |
| `orbital` | 82% | **74%** |

The same numbers apply to any circular crop (TV launcher, avatar-style
placeholders). Re-exporting at those scales, rather than redrawing, is
sufficient — all three marks are strokes and fills with no hairline detail.

---

## Construction notes

- **Canvas.** Marks are `viewBox="0 0 128 128"`; lockups are
  `viewBox="0 0 540 176"`. No intrinsic size, no background, no padding baked
  into the geometry beyond the optical margins described above.
- **Wordmark.** Drawn without a typeface: monoline geometric letterforms on a
  cap height of 100, x-height 70, stroke 15, round terminals. `Z` and `y` are
  56 wide, `P` 58.75, `l` 15, `a` 61 (its bowl is an ellipse tangent to a
  straight right stem); letter gaps are 20/18/26/24, tuned per pair rather than
  set uniformly. The wordmark's own `Z` is deliberately the plain, static Z while
  `signal`'s mark is the stepped one: the mark is the live signal, the wordmark
  is the name.
- **Lockup fit.** The mark is scaled so its ink is 114–118 units tall (roughly
  1.15× cap height), vertically centred on the cap-height band, with a 34-unit
  gap to the wordmark. The `y` descender is allowed to hang below the baseline;
  the canvas is centred on the whole ink box, so nothing clips.
- **Optical centring.** `prism` is nudged 4 units right and `orbital`'s core 1.5
  units right, because a right-pointing triangle carries its mass on its left.
  `signal` is symmetric under 180° rotation and needs no nudge.
- **Not wired into the app.** These files live outside the Flutter asset
  pipeline; `pubspec.yaml` does not declare `assets/branding/`. Wiring them up
  (and generating `icon.png` from the chosen direction) is a separate change.
