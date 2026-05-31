#!/usr/bin/env python3
"""Create a new JSON-first world map scaffold for The Last Aria."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_SCENE = REPO_ROOT / "scenes" / "world" / "act2_skyisland.tscn"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create data, dialogue, scene, and script files for a new map."
    )
    parser.add_argument("--map-id", required=True, help="Map id, e.g. act3_forbidden_lab.")
    parser.add_argument("--map-name", required=True, help="Display name for the map.")
    parser.add_argument("--background", required=True, help="res:// background path.")
    parser.add_argument("--music-context", default="overworld", help="MusicManager context.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and print planned files without writing anything.",
    )
    return parser.parse_args()


def validate_map_id(map_id: str) -> None:
    if not re.fullmatch(r"[a-z0-9_]+", map_id):
        raise ValueError("map-id must contain only lowercase letters, numbers, and underscores.")


def target_paths(map_id: str) -> dict[str, Path]:
    return {
        "map": REPO_ROOT / "data" / "maps" / f"{map_id}.json",
        "dialogue": REPO_ROOT / "data" / "dialogues" / f"{map_id}.json",
        "scene": REPO_ROOT / "scenes" / "world" / f"{map_id}.tscn",
        "script": REPO_ROOT / "scripts" / "world" / f"{map_id}.gd",
    }


def ensure_safe_to_write(paths: dict[str, Path]) -> None:
    existing = [path for path in paths.values() if path.exists()]
    if existing:
        joined = "\n".join(f"  - {path.relative_to(REPO_ROOT)}" for path in existing)
        raise FileExistsError(f"Refusing to overwrite existing files:\n{joined}")


def make_map_json(args: argparse.Namespace) -> str:
    map_data = {
        "id": args.map_id,
        "name": args.map_name,
        "player_spawn": [0, 0],
        "background": args.background,
        "dialogue_path": f"res://data/dialogues/{args.map_id}.json",
        "music_context": args.music_context,
        "walkable_polygons": [],
        "events": [],
    }
    return json.dumps(map_data, ensure_ascii=False, indent=2) + "\n"


def make_dialogue_json() -> str:
    dialogue_data = {
        "intro": [
            {
                "speaker": "Lyra",
                "text": "...",
            }
        ]
    }
    return json.dumps(dialogue_data, ensure_ascii=False, indent=2) + "\n"


def make_script(map_id: str) -> str:
    return f'''extends "res://scripts/world/world_base.gd"

@export var map_data_path := "res://data/maps/{map_id}.json"

var map_data: Dictionary = {{}}
var music_context := "overworld"

func on_world_ready() -> void:
\tmap_data = MapDataLoader.load_map_data(map_data_path)
\t_apply_map_data(map_data)
\tWalkableAreaSpawner.spawn_walkable_area(self, map_data)
\tEventSpawner.spawn_events(map_data, get_node_or_null("EventRoot"))
\tMusicManager.play_context(music_context)

func _apply_map_data(data: Dictionary) -> void:
\tif data.is_empty():
\t\treturn

\tvar map_dialogue_path := str(data.get("dialogue_path", "")).strip_edges()
\tif map_dialogue_path != "":
\t\tvar previous_dialogue_path := dialogue_path
\t\tdialogue_path = map_dialogue_path
\t\tif previous_dialogue_path != dialogue_path or dialogue_sets.is_empty():
\t\t\tload_dialogue_sets()
\telse:
\t\tpush_warning("Map data missing dialogue_path: %s" % map_data_path)

\tvar map_music_context := str(data.get("music_context", "")).strip_edges()
\tif map_music_context != "":
\t\tmusic_context = map_music_context
\telse:
\t\tpush_warning("Map data missing music_context: %s" % map_data_path)
'''


def make_scene(map_id: str) -> str:
    if not TEMPLATE_SCENE.exists():
        raise FileNotFoundError(f"Template scene not found: {TEMPLATE_SCENE}")

    scene = TEMPLATE_SCENE.read_text(encoding="utf-8")
    scene = re.sub(r'uid="[^"]+"\s+', "", scene, count=1)
    scene = re.sub(
        r'(\[ext_resource type="Script" [^\]]*path=")res://scripts/world/act2_skyisland\.gd(")',
        rf"\1res://scripts/world/{map_id}.gd\2",
        scene,
        count=1,
    )
    scene = re.sub(
        r'dialogue_path = "res://data/dialogues/[^"]+\.json"',
        f'dialogue_path = "res://data/dialogues/{map_id}.json"',
        scene,
        count=1,
    )

    map_data_line = f'map_data_path = "res://data/maps/{map_id}.json"'
    if re.search(r'^map_data_path = ', scene, flags=re.MULTILINE):
        scene = re.sub(r'^map_data_path = ".*"$', map_data_line, scene, count=1, flags=re.MULTILINE)
    else:
        scene = re.sub(
            rf'(dialogue_path = "res://data/dialogues/{map_id}\.json"\n)',
            rf"\1{map_data_line}\n",
            scene,
            count=1,
        )

    return scene


def build_outputs(args: argparse.Namespace) -> dict[Path, str]:
    paths = target_paths(args.map_id)
    return {
        paths["map"]: make_map_json(args),
        paths["dialogue"]: make_dialogue_json(),
        paths["script"]: make_script(args.map_id),
        paths["scene"]: make_scene(args.map_id),
    }


def write_outputs(outputs: dict[Path, str]) -> None:
    for path, content in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8", newline="\n")


def main() -> int:
    args = parse_args()
    try:
        validate_map_id(args.map_id)
        paths = target_paths(args.map_id)
        ensure_safe_to_write(paths)
        outputs = build_outputs(args)
    except (FileExistsError, FileNotFoundError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    print("Map template files:")
    for path in outputs:
        print(f"  - {path.relative_to(REPO_ROOT)}")

    if args.dry_run:
        print("Dry run only; no files written.")
        return 0

    write_outputs(outputs)
    print("Created map template.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
