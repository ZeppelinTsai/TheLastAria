# Dialog Standee Parameters

This file documents character standee parameters used by dialogue scenes.

Runtime scripts:

- `scripts/world/world_base.gd`
- `scenes/main.gd`
- `autoload/CharacterVisualManager.gd`

Character defaults live in:

- `data/characters.json`

Per-line overrides live in dialogue JSON entries:

- `data/dialogues/*.json`

---

## Character Defaults

Example:

```json
"Lyra": {
  "display_name": "Lyra",
  "dialog_standee": {
    "position": "center",
    "x_offset_ratio": 0.0,
    "bottom_ratio": -0.65,
    "height_ratio": 2.0,
    "scale": 1.0
  },
  "portraits": {
    "default": "res://img/lyra.png"
  },
  "busts": {
    "default": "res://img/lyra.png"
  }
}
```

`busts` is preferred for dialogue standees. If no bust exists, the system falls back to `portraits`.

---

## Position

Use `position` for the common left / center / right placements.

```json
"position": "left"
"position": "center"
"position": "right"
```

Meaning:

- `left`: image left edge aligns to the preview/window left edge.
- `center`: image center aligns to the preview/window center.
- `right`: image right edge aligns to the preview/window right edge.

If `position` is set, it takes priority over `x_ratio` and `x`.

---

## Horizontal Fine Tuning

Use these after `position`.

```json
"x_offset_ratio": -0.08
"x_offset": 24
```

- `x_offset_ratio`: shifts by a percentage of preview/window width.
  - `-0.08` means move left by 8% of width.
  - `0.05` means move right by 5% of width.
- `x_offset`: shifts by pixels.

Prefer `x_offset_ratio` for fullscreen and small-screen compatibility.

Legacy fields:

```json
"x_ratio": 0.5
"x": 100
```

- `x_ratio`: old proportional left-edge placement.
- `x`: old pixel left-edge placement.
- These are fallback fields when `position` is not set.

---

## Vertical Placement

```json
"bottom_ratio": -0.65
"bottom": -500
```

- `bottom_ratio`: vertical offset based on preview/window height.
  - Positive values move the standee up.
  - Negative values move the standee down and hide more of it below the dialogue box.
- `bottom`: old pixel fallback.

Prefer `bottom_ratio` for fullscreen and small-screen compatibility.

---

## Size

```json
"height_ratio": 1.8
"scale": 1.0
```

- `height_ratio`: standee height as a percentage of preview/window height.
  - `1.0` means one full screen height.
  - `1.8` means 180% of screen height.
- `scale`: extra multiplier. Usually leave this at `1.0`.

Prefer changing `height_ratio` before `scale`.

---

## Layering

Speaking characters automatically render above non-speaking characters.

Default z-index behavior:

- Speaking character: `-1`
- Non-speaking character: `-3`

Use `z_offset` for special staging:

```json
"z_offset": 2
```

This adds to the automatic z-index.

---

## Per-Line Speaker Override

Use `standee` on a dialogue line to override only the speaking character for that line.

```json
{
  "speaker": "Lyra",
  "text": "等等……",
  "standee": {
    "position": "center",
    "x_offset_ratio": -0.08,
    "bottom_ratio": -0.7,
    "height_ratio": 1.9
  }
}
```

This merges with the character default from `data/characters.json`.

---

## Multiple Characters On Screen

Use `standees` for staged dialogue with multiple visible characters.

```json
{
  "speaker": "Lyra",
  "text": "你也看到了嗎？",
  "standees": [
    {
      "character": "Lyra",
      "position": "left",
      "x_offset_ratio": 0.04,
      "height_ratio": 1.8
    },
    {
      "character": "Lumi",
      "position": "right",
      "height_ratio": 0.86
    }
  ]
}
```

If the speaking character is not included in `standees`, the runtime adds that character automatically.

---

## Debug Controls

During play:

- `F3`: toggle dialogue standee debug overlay.
- `Tab`: while debug overlay is visible, toggle the small-screen preview area.

The debug overlay shows:

- speaker / expression
- texture path and texture size
- standee rect position and size
- parent / z-index / child index
- layout parameters

Use the small-screen preview before finalizing `position`, `x_offset_ratio`, `bottom_ratio`, and `height_ratio`.
