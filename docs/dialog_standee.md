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
    "default": "res://img/tachie/lyra/lyra_default.png"
  },
  "busts": {
    "default": "res://img/tachie/lyra/lyra_default.png"
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
## 圖片引用與表情差分

角色立繪圖片統一在 `data/characters.json` 裡設定。對話 JSON 不直接寫圖片路徑，而是寫角色與表情名稱，讓同一個角色可以共用預設位置、比例和差分管理。

### characters.json 圖片設定

每個角色可以有兩組圖片表：

```json
{
  "Lyra": {
    "display_name": "Lyra",
    "dialog_standee": {
      "position": "center",
      "bottom_ratio": -1.0,
      "height_ratio": 2.0,
      "scale": 1.0
    },
    "busts": {
      "default": "res://img/tachie/lyra/lyra_default.png",
      "smile": "res://img/tachie/lyra/lyra_smile.png",
      "sad": "res://img/tachie/lyra/lyra_sad.png"
    },
    "portraits": {
      "default": "res://img/tachie/lyra/lyra_default.png"
    }
  }
}
```

- `busts`: 對話立繪優先使用這組。適合放 1024x1536 這類全身/半身圖。
- `portraits`: 備用圖片組。若 `busts` 找不到指定表情，會 fallback 到這組。
- `default`: 必填建議。當指定的表情不存在時會退回 `default`。
- 表情 key 可以自由命名，例如 `smile`, `angry`, `surprised`, `cry`, `serious`。

目前讀圖順序是：

1. `busts[expression]`
2. `busts.default`
3. `portraits[expression]`
4. `portraits.default`

### 單人對話換表情

對話行使用 `expression` 指定差分：

```json
{
  "speaker": "Lyra",
  "expression": "smile",
  "text": "……"
}
```

如果 `Lyra` 的 `busts.smile` 存在，就會顯示那張圖；不存在時會自動退回 `default`。

### 單行覆蓋立繪位置

單人對話可以用 `standee` 暫時覆蓋角色預設位置：

```json
{
  "speaker": "Lyra",
  "expression": "sad",
  "text": "……",
  "standee": {
    "position": "left",
    "x_offset_ratio": 0.04,
    "bottom_ratio": -0.85,
    "height_ratio": 1.9
  }
}
```

這只影響該行，不會改 `characters.json` 的角色預設。

### 多人同時入鏡

使用 `standees` 可以讓多個角色同時顯示。正在說話的角色會自動使用較高的 `z_index`。

```json
{
  "speaker": "Lyra",
  "expression": "serious",
  "text": "我們得出去看看。",
  "standees": [
    {
      "character": "Lyra",
      "expression": "serious",
      "position": "left",
      "x_offset_ratio": 0.03
    },
    {
      "character": "Lumi",
      "expression": "surprised",
      "position": "right",
      "x_offset_ratio": -0.04
    }
  ]
}
```

`standees` 裡每個項目都可以直接寫 layout 參數，也可以用 `layout` 包起來：

```json
{
  "character": "Lumi",
  "expression": "smile",
  "layout": {
    "position": "right",
    "bottom_ratio": 0.2,
    "height_ratio": 0.86
  }
}
```

### 演出用 z 軸調整

預設說話者會在非說話者前面。如果某一行需要特別壓前或壓後，可以用 `z_offset`：

```json
{
  "character": "Lyra",
  "expression": "angry",
  "position": "center",
  "z_offset": 2
}
```

`z_offset` 是加在系統預設 z 值上的微調。一般不用寫，只有特殊演出需要。

### 建議命名

差分圖建議用角色名加表情：

```text
res://img/tachie/lyra/lyra_default.png
res://img/tachie/lyra/lyra_smile.png
res://img/tachie/lyra/lyra_sad.png
res://img/tachie/lyra/lyra_surprised.png
res://img/tachie/lumi/lumi_default.png
res://img/tachie/lumi/lumi_angry.png
```

對話 JSON 只引用表情 key，不引用檔名：

```json
{
  "speaker": "Lumi",
  "expression": "angry",
  "text": "你又在看那本啊？"
}
```
## Dialogue Choices

World dialogue entries can show temporary choices with a `choices` array. Use this for lightweight dialogue branches, or add save fields only when the choice needs to matter later.

```json
{
  "speaker": "Lumi",
  "text": "你笑什麼啦。",
  "choices": [
    {
      "id": "happy_ending",
      "text": "因為這是 Happy Ending",
      "text_key": "sunken_city_lyra_room.opening_after_storybook.005.choice.happy_ending.text",
      "response": {
        "speaker": "Lumi",
        "text": "喔？你現在會說這種話了喔。"
      }
    }
  ]
}
```

Choice fields:

- `text` / `text_key`: button label.
- `response`: one response entry, or an array of entries, inserted after the current line.
- `flag` or `set_flag`: optional SaveManager flag to store.
- `flag_value`: optional flag value, defaults to `true`.
- `story_key` and `story_value`: optional story value to store.
- `next_dialogue`: optional dialogue id to jump to.
- `next_index`: optional index within the active dialogue to jump to.
