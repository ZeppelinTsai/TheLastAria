from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any


LOCALES: tuple[str, ...] = (
    "en",
    "ja",
    "zh_TW",
    "zh_CN",
    "ko",
    "fr",
    "de",
    "es",
)

TEXT_FIELDS: set[str] = {
    "text",
    "left_text",
    "right_text",
    "label",
    "prompt",
}

OUTPUT_ROOT = Path("data/localization/dialogues")
SCRIPT_OUTPUT_ROOT = Path("data/localization/scripts")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract stable localization keys from changed story files."
    )
    parser.add_argument(
        "--changed",
        default="HEAD",
        help="Commit-ish to inspect with git diff-tree. Defaults to HEAD.",
    )
    parser.add_argument(
        "--files",
        nargs="*",
        default=None,
        help="Explicit files to scan instead of git changed files.",
    )
    parser.add_argument(
        "--stage",
        action="store_true",
        help="Stage generated localization files after writing them.",
    )
    args = parser.parse_args()

    paths = args.files if args.files is not None else get_changed_files(args.changed)
    generated: list[Path] = []

    for raw_path in paths:
        path = Path(raw_path)
        if not path.exists():
            continue
        if is_dialogue_json(path):
            output_path = extract_dialogue_json(path)
            if output_path is not None:
                generated.append(output_path)
        elif is_story_script(path):
            output_path = extract_story_script(path)
            if output_path is not None:
                generated.append(output_path)

    if args.stage and generated:
        subprocess.run(
            ["git", "add", *[str(path) for path in generated]],
            check=False,
        )

    if generated:
        print("Localization key extraction updated:")
        for path in generated:
            print(f"  {path.as_posix()}")
    else:
        print("Localization key extraction found no story text changes.")

    return 0


def get_changed_files(commitish: str) -> list[str]:
    result = subprocess.run(
        [
            "git",
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "-r",
            commitish,
        ],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.returncode != 0:
        return []
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def is_dialogue_json(path: Path) -> bool:
    return path.suffix == ".json" and path.as_posix().startswith("data/dialogues/")


def is_story_script(path: Path) -> bool:
    path_text = path.as_posix()
    return path.suffix == ".gd" and (
        path_text.startswith("scripts/world/")
        or path_text.startswith("scenes/")
        or path_text.startswith("autoload/")
    )


def extract_dialogue_json(path: Path) -> Path | None:
    data = json.loads(path.read_text(encoding="utf-8"))
    entries: list[tuple[str, str]] = []
    namespace = slug(path.stem)
    walk_json(data, [namespace], entries)
    if not entries:
        return None

    output_path = OUTPUT_ROOT / f"{path.stem}.json"
    translations = load_translation_file(output_path)
    for locale in LOCALES:
        translations.setdefault(locale, {})

    source_locale = "zh_TW"
    for key, text in entries:
        for locale in LOCALES:
            translations[locale].setdefault(key, "")
        if translations[source_locale].get(key, "") == "":
            translations[source_locale][key] = text

    write_translation_file(output_path, translations)
    return output_path


def walk_json(value: Any, path_parts: list[str], entries: list[tuple[str, str]]) -> None:
    if isinstance(value, dict):
        identity = first_present_string(value, ("id", "dialogue_id", "speaker", "scene"))
        next_parts = path_parts
        if identity:
            next_parts = [*path_parts, slug(identity)]

        for field, field_value in value.items():
            if field in TEXT_FIELDS and isinstance(field_value, str):
                text = field_value.strip()
                if text:
                    key = ".".join([*next_parts, slug(field)])
                    entries.append((dedupe_key(key, entries), text))
            elif field in ("choices", "options") and isinstance(field_value, list):
                walk_json(field_value, [*next_parts, slug(field)], entries)
            elif isinstance(field_value, (dict, list)):
                walk_json(field_value, [*next_parts, slug(field)], entries)
    elif isinstance(value, list):
        for index, item in enumerate(value, 1):
            walk_json(item, [*path_parts, f"{index:03d}"], entries)


def extract_story_script(path: Path) -> Path | None:
    text = path.read_text(encoding="utf-8")
    string_pattern = re.compile(r"\.text\s*=\s*\"((?:\\.|[^\"])*)\"")
    entries: list[tuple[str, str]] = []
    namespace = slug(path.with_suffix("").as_posix())
    for index, match in enumerate(string_pattern.finditer(text), 1):
        value = bytes(match.group(1), "utf-8").decode("unicode_escape").strip()
        if is_translatable_script_string(value):
            key = f"{namespace}.{index:03d}.text"
            entries.append((key, value))
    if not entries:
        return None

    output_path = SCRIPT_OUTPUT_ROOT / f"{path.stem}.json"
    translations = load_translation_file(output_path)
    for locale in LOCALES:
        translations.setdefault(locale, {})
    for key, value in entries:
        for locale in LOCALES:
            translations[locale].setdefault(key, "")
        if translations["zh_TW"].get(key, "") == "":
            translations["zh_TW"][key] = value

    write_translation_file(output_path, translations)
    return output_path


def is_translatable_script_string(value: str) -> bool:
    if value == "":
        return False
    if value.startswith(("res://", "uid://")):
        return False
    if "%" in value and len(value) <= 12:
        return False
    return contains_cjk(value) or len(value) >= 16


def load_translation_file(path: Path) -> dict[str, dict[str, str]]:
    if not path.exists():
        return {locale: {} for locale in LOCALES}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        return {locale: {} for locale in LOCALES}
    loaded: dict[str, dict[str, str]] = {}
    for locale in LOCALES:
        locale_data = data.get(locale, {})
        loaded[locale] = locale_data if isinstance(locale_data, dict) else {}
    return loaded


def write_translation_file(path: Path, data: dict[str, dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
        encoding="utf-8",
    )


def first_present_string(data: dict[str, Any], keys: tuple[str, ...]) -> str:
    for key in keys:
        value = data.get(key, "")
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def slug(value: str) -> str:
    value = value.strip().replace("\\", "/")
    value = re.sub(r"[^A-Za-z0-9_/\-]+", "_", value)
    value = value.replace("/", ".").replace("-", "_")
    value = re.sub(r"_+", "_", value)
    value = re.sub(r"\.+", ".", value)
    return value.strip("._").lower() or "text"


def dedupe_key(base_key: str, entries: list[tuple[str, str]]) -> str:
    existing = {key for key, _text in entries}
    if base_key not in existing:
        return base_key
    index = 2
    while f"{base_key}_{index}" in existing:
        index += 1
    return f"{base_key}_{index}"


def contains_cjk(value: str) -> bool:
    return any(
        "\u3040" <= char <= "\u30ff"
        or "\u3400" <= char <= "\u9fff"
        or "\uf900" <= char <= "\ufaff"
        for char in value
    )


if __name__ == "__main__":
    raise SystemExit(main())
