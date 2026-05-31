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

# Technical Stack

Engine:

Godot 4.6.2 Stable

Language:

GDScript

Target Platforms:

- Windows
- Steam
- Future Mobile (Android/iOS)

---

# Core Design Principles

## 1. Story First

Always preserve:

- Orion's story
- Lyra's emotional journey
- Lumi's sacrifice
- Artemis' hidden truth

Do not introduce systems that distract from narrative pacing.

---

## 2. Simplicity Over Complexity

Prefer:

Simple event systems

instead of

Complex gameplay frameworks

Example:

GOOD

- Area2D trigger
- Dialogue
- Scene transition

BAD

- Massive quest system
- RPG stat trees
- Overengineered architecture

---

## 3. AI-Friendly Development

Project is designed for AI-assisted development.

Prefer:

- Small focused scripts
- Modular scenes
- Clear node names
- Export variables

Avoid:

- Huge 2000-line scripts
- Hidden dependencies
- Hardcoded scene paths

---

# Scene Architecture

World scenes should inherit from:

world_base.gd

World scenes should only contain:

- Background
- WalkableArea
- EventRoot
- Local events
- Dialogue path

Shared systems belong in:

world_base.gd

---

# Walkable Area System

Project uses:

Area2D
└ CollisionPolygon2D

representing walkable space.

DO NOT build TileMap-based collision systems.

DO NOT replace walkable-area navigation with tile navigation.

Future navigation should be based on:

NavigationRegion2D
NavigationAgent2D

if pathfinding becomes necessary.

---

# Map Creation Pipeline

Each map should contain:

1. Base Background
2. Atmosphere Layers
3. Walkable Area
4. Event Layer
5. Dialogue JSON

Each new map must also create:

data/maps/<map_id>.json

Map JSON is the preferred source for:

- Story and dialogue references
- Event data
- Music context
- Background paths
- Walkable polygon coordinates

Godot scenes should be treated as the current player/runtime layer: they display and execute map data, while JSON remains the real content source. Do not hardcode large story content into .gd files.

AI-generated maps should follow:

Background only

- Layer separation

Examples:

skyisland_main.png
skyisland_clouds.png
skyisland_fog.png
skyisland_particles.png

Animation should be implemented in Godot.

Avoid video backgrounds whenever possible.

---

# Dialogue System

Dialogue content must remain in JSON files.

Scenes should reference:

@export var dialogue_path

Never hardcode dialogue into scene scripts.

---

# Event Design

Events should use:

Area2D

Triggers.

Avoid complex event managers unless necessary.

Preferred structure:

EventRoot
├ MemoryTrigger
├ LumiTrigger
├ BossTrigger

---

# Save System

Always use existing SaveManager.

Do not create alternative save systems.

Do not break compatibility with existing save data.

---

# Audio

Use MusicManager.

Avoid scene-specific audio implementations.

Music should be context driven.

Example:

MusicManager.play_context("skyisland")

---

# Validation Workflow

After modifying code:

1. Save files
2. Run:

check_godot.bat

3. Fix all errors before continuing

Do not consider a task complete if Godot headless validation fails.

After modifying Godot scripts, scenes, or project code, always run:

check_godot.bat

After modifying export settings or CI, always run:

export_web.bat

Do not manually commit Web build output unless the workflow explicitly requires it.

Do not add a backend or database. The Last Aria is currently a pure static Web playable demo.

---

# Development Priority

Priority order:

1. Story
2. Events
3. Atmosphere
4. Visual Presentation
5. Gameplay Systems

Never sacrifice narrative quality to add unnecessary mechanics.

---

# Current Goal

Build a playable vertical slice:

Prelude
→ Beach Island
→ Lighthouse
→ First Orion Interaction

before expanding the rest of the game.

If there is a conflict between adding a new system and finishing a playable scene,
always choose the playable scene.
