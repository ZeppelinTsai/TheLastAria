# The Last Aria - AGENT.md

## Project Overview

The Last Aria is a narrative-driven indie RPG built with Godot 4.6.

Core focus:

- Emotional storytelling
- Exploration
- Dialogue
- Environmental atmosphere
- Multiple endings

NOT focused on:

- Complex combat systems
- Character builds
- Grinding
- Large inventories

When uncertain, prioritize story and presentation over mechanics.

---

## Technical Stack

Engine:

Godot 4.6.2 Stable

Language:

GDScript

Target Platforms:

- Windows
- Steam
- Future Mobile (Android/iOS)

---

## Core Design Principles

### 1. Story First

Always preserve:

- Orion's story
- Lyra's emotional journey
- Lumi's sacrifice
- Artemis' hidden truth

Do not introduce systems that distract from narrative pacing.

### 2. Simplicity Over Complexity

Prefer:

- Area2D triggers
- Dialogue
- Scene transitions
- Small focused scripts

Avoid:

- Massive quest systems
- RPG stat trees
- Overengineered architecture
- Large hidden frameworks

## AI-Friendly Development

Project is designed for AI-assisted development.

Prefer:

- Small focused scripts
- Modular scenes
- Clear node names
- Export variables
- Explicit data flow
- Simple validation commands

Avoid:

- Huge 2000-line scripts
- Hidden dependencies
- Hardcoded scene paths
- Complex implicit node assumptions

---

### Environment First

Before changing story, scenes, or gameplay:

Validate:

- File encoding
- JSON parsing
- Scene loading
- Existing generated assets

Prefer:

Environment issue
→ Encoding
→ Validation
→ Data
→ Logic

Avoid:

Logic rewrite
→ Data rewrite
→ Environment check

## Type Safety Rules

These rules reduce GDScript parse errors and improve AI-generated code reliability.

### GDScript

Avoid:

```gdscript
var speed := 1.0
var pos := Vector2.ZERO
var mat := material
```

Prefer:

```gdscript
var speed: float = 1.0
var pos: Vector2 = Vector2.ZERO
var mat: ShaderMaterial = material
```

Rules:

- Explicit types are preferred.
- Avoid `:=` in exported variables, scene state, shader parameters, or values crossing node boundaries.
- Allow `:=` only for local immutable values where type is obvious.
- Never rely on Variant inference for scene logic.
- Functions should specify return types whenever possible.
- Avoid multiline assignment immediately after `=`.
- Prefer intermediate variables over deeply nested expressions.
- Prefer `clamp` / `lerp` over version-sensitive alternatives unless the project explicitly supports them.
- Do not report completion until Godot validation passes.

GOOD:

```gdscript
var depth: float = clamp(value, 0.0, 1.0)

mat.set_shader_parameter(
    "depth",
    depth
)
```

BAD:

```gdscript
var depth := clampf(
    value,
    0,
    1
)

mat.set_shader_parameter(
    "depth",
    clampf(
        value,
        0,
        1
    )
)
```

### Python

Avoid:

```python
x = []
data = {}
speed = None
```

Prefer:

```python
x: list[str] = []
data: dict[str, str] = {}
speed: float | None = None
```

Rules:

- Prefer pydantic/dataclass over nested dict.
- Prefer explicit return type.
- Prefer pathlib.Path.
- Avoid implicit mutation.
- Use UTF-8 explicitly when reading files.

GOOD:

```python
from pathlib import Path

def load_text(path: Path) -> str:
    return path.read_text(
        encoding="utf-8"
    )
```

BAD:

```python
f = open(path)

text = f.read()
```

---

## Scene Architecture

World scenes should inherit from:

```text
world_base.gd
```

World scenes should only contain:

- Background
- WalkableArea
- EventRoot
- Local events
- Dialogue path

Shared systems belong in:

```text
world_base.gd
```

Do not hardcode large story content into `.gd` files.

---

## Walkable Area System

Project uses:

```text
Area2D
└ CollisionPolygon2D
```

representing walkable space.

DO NOT build TileMap-based collision systems.

DO NOT replace walkable-area navigation with tile navigation.

Future navigation should be based on:

```text
NavigationRegion2D
NavigationAgent2D
```

only if pathfinding becomes necessary.

---

## Map Creation Pipeline

Each map should contain:

1. Base Background
2. Atmosphere Layers
3. Walkable Area
4. Event Layer
5. Dialogue JSON

Each new map must also create:

```text
data/maps/<map_id>.json
```

Map JSON is the preferred source for:

- Story and dialogue references
- Event data
- Music context
- Background paths
- Walkable polygon coordinates

Godot scenes are the current player/runtime layer: they display and execute map data, while JSON remains the real content source.

### Standard New Map Workflow

Use the map template generator from the project root:

```powershell
python tools/create_map_template.py --map-id <map_id> --map-name "<map name>" --background "res://path/to/background.png"
```

The generator creates:

- `data/maps/<map_id>.json`
- `data/dialogues/<map_id>.json`
- `scenes/world/<map_id>.tscn`
- `scripts/world/<map_id>.gd`

Never overwrite existing map files.

After generation:

1. Fill in `walkable_polygons` and events in `data/maps/<map_id>.json`.
2. Tune the Godot scene only as the player/runtime layer.

AI-generated maps should support layer separation.

Examples:

```text
skyisland_main.png
skyisland_clouds.png
skyisland_fog.png
skyisland_particles.png
```

Animation should be implemented in Godot.

Avoid video backgrounds whenever possible.

---

## Dialogue System

Dialogue content must remain in JSON files.

Scenes should reference:

```gdscript
@export var dialogue_path: String
```

Never hardcode dialogue into scene scripts.

### Localization Key Pipeline

UI and future dialogue localization use:

```text
autoload/LocalizationManager.gd
data/localization/ui_text.json
data/localization/dialogues/*.json
data/localization/scripts/*.json
```

For future dialogue, prefer stable text keys instead of raw translated text in runtime scripts.

Preferred dialogue entry:

```json
{
  "speaker": "lyra",
  "text_key": "prologue.lyra.001.text",
  "text": "Fallback source text"
}
```

`text` may remain as a fallback while content is being migrated.

To extract localization key scaffolds from changed dialogue/script files manually:

```powershell
python tools/extract_localization_keys.py --files data/dialogues/prologue.json
```

Curated English bootstrap helpers currently include `tools/fill_prologue_english.py` and `tools/fill_lyra_room_english.py`.

To install the local post-commit hook:

```powershell
powershell -ExecutionPolicy Bypass .\tools\install_localization_hook.ps1
```

After installation, each commit scans files changed in that commit. If changed files include `data/dialogues/*.json` or story-facing `.gd` text assignments, generated key files are written under:

```text
data/localization/dialogues/
data/localization/scripts/
```

The post-commit hook updates files after the commit. Review and commit generated localization files in a follow-up commit when needed.

The extractor preserves existing non-empty translations and fills only missing keys. It stores original extracted source text in `zh_TW` by default and leaves English/Japanese/other language values empty for translators.

Dialogue standee placement, multi-character staging, per-line overrides, and debug controls are documented in:

```text
docs/dialog_standee.md
```

Localization flow and `text_key` runtime rules are documented in:

```text
docs/localization.md
```

Image asset folder conventions are documented in:

```text
docs/asset_organization.md
```

---

## Event Design

Events should use:

```text
Area2D triggers
```

Avoid complex event managers unless necessary.

Preferred structure:

```text
EventRoot
├── MemoryTrigger
├── LumiTrigger
└── BossTrigger
```

---

## Save System

Always use existing `SaveManager`.

Do not create alternative save systems.

Do not break compatibility with existing save data.

---

## Audio

Use `MusicManager`.

Avoid scene-specific audio implementations.

Music should be context driven.

Example:

```gdscript
MusicManager.play_context("skyisland")
```

---

## Validation Workflow

```text
# Validation Workflow
├── AI Validation Rules
├── Godot Validation
└── Web Export
```

### AI Validation Rules

Before reporting completion:

1. Save files.
2. Run validation.
3. Fix all syntax errors.
4. Re-run validation.
5. Confirm validation passes.

### Encoding Validation

Before modifying JSON / dialogue / localization files:

1. Read text using UTF-8 explicitly.
2. Validate JSON parse before editing.
3. Never assume corrupted text means corrupted data.
4. Distinguish encoding failure from content failure.

PowerShell:

```powershell
Get-Content <file> -Raw -Encoding UTF8 | ConvertFrom-Json
```

Python:

```python
from pathlib import Path

text = Path(path).read_text(
    encoding="utf-8"
)
```

If validation fails:

- DO NOT regenerate content.
- DO NOT rewrite files.
- Fix encoding or parser issues first.
- Prefer environment fixes before content changes.

Required command on Windows:

```powershell
powershell -ExecutionPolicy Bypass .\tools\validate.ps1
```

Common failure order:

- Encoding
- Parsing
- Data
- Logic

Never reverse this order.

### Godot Validation

After modifying Godot scripts, scenes, shaders, or project code, always run the platform-appropriate validation script:

Windows:

```powershell
check_godot.bat
```

Linux/macOS:

```bash
bash check_godot.sh
```

### Web Export

After modifying export settings or CI, always run the platform-appropriate Web export script:

Windows:

```powershell
export_web.bat
```

Linux/macOS:

```bash
bash export_web.sh
```

Do not manually commit Web build output unless the workflow explicitly requires it.

Do not add a backend or database.

The Last Aria is currently a pure static Web playable demo.

---

## Architecture Change Policy

When introducing any structural or rendering changes, update AGENT.md.

Structural changes include:

- New shaders
- New rendering passes
- New atmosphere systems
- New scene layers
- New singleton/autoload
- New validation scripts
- New map pipeline rules
- New particle systems
- Changes to save/load flow
- Changes to scene hierarchy
- Changes to asset naming conventions

Parameter-only tuning does NOT require AGENT updates unless it changes design intent.

Examples:

NO update required:

- Light intensity 1.2 → 1.4
- Bubble count 20 → 40
- Camera smoothing 3 → 4

Update required:

- Add LightRays shader
- Add WaterDistortion pass
- Introduce Front/Mid/Back map layering
- Add Scene Validation pipeline
- Introduce Map JSON ownership

Required documentation:

1. Purpose
2. Affected files
3. Migration impact
4. Validation command
5. Rollback method

Never report completion if architecture changed but AGENT.md was not updated.

## Development Priority

Priority order:

1. Story
2. Events
3. Atmosphere
4. Visual Presentation
5. Gameplay Systems

Never sacrifice narrative quality to add unnecessary mechanics.

---

## Current Goal

Build a playable vertical slice:

```text
Prelude
→ Beach Island
→ Lighthouse
→ First Orion Interaction
```

before expanding the rest of the game.

If there is a conflict between adding a new system and finishing a playable scene, always choose the playable scene.
