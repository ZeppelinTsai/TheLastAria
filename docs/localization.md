# Localization Pipeline

## Purpose

This project keeps story text in content JSON and translated text in localization JSON. Runtime scripts should ask `LocalizationManager` for the final display text instead of reading raw `text` fields directly.

## Runtime Text Flow

Use:

```gdscript
LocalizationManager.get_entry_text(entry)
```

For storybook-style entries that may still use `left_text`:

```gdscript
LocalizationManager.get_entry_text(entry, ["text", "left_text"])
```

Resolution order:

1. Read `entry["text_key"]`.
2. Look up the current locale through `LocalizationManager.tr_text(text_key)`.
3. If the locale has no non-empty translation, fall back to source fields such as `text` or `left_text`.
4. If no source field exists, return an empty string.

This prevents untranslated locales from showing blank story text.

## Content Format

Preferred dialogue/storybook entry:

```json
{
	"speaker": "lyra",
	"text_key": "prologue.lyra.001.text",
	"text": "Fallback source text"
}
```

Translation files live under:

```text
data/localization/dialogues/
data/localization/scripts/
```

Each file should keep all supported locale buckets:

```json
{
	"en": {},
	"ja": {},
	"zh_TW": {},
	"zh_CN": {},
	"ko": {},
	"fr": {},
	"de": {},
	"es": {}
}
```

## Key Extraction

Manual extraction:

```powershell
python tools/extract_localization_keys.py --files data/dialogues/prelude_storybook.json
```

Current prologue English bootstrap:

```powershell
python tools/fill_prologue_english.py
```

This keeps `data/dialogues/prologue.json` entries wired with `text_key` and fills the curated English strings in `data/localization/dialogues/prologue.json`.

Current Lyra room English bootstrap:

```powershell
python tools/fill_lyra_room_english.py
```

This keeps `data/dialogues/sunken_city_lyra_room.json` entries wired with `text_key` and fills the curated English strings in `data/localization/dialogues/sunken_city_lyra_room.json`.

Post-commit hook installation:

```powershell
powershell -ExecutionPolicy Bypass .\tools\install_localization_hook.ps1
```

The hook scans files changed in the commit and writes scaffold translation keys after the commit completes. Since post-commit changes are not part of the commit that triggered them, review and commit generated localization files separately when needed.

## Current Runtime Readers

These scripts should use `LocalizationManager.get_entry_text()`:

```text
scripts/world/world_base.gd
scripts/world/prelude_storybook.gd
scenes/main.gd
```

Avoid direct runtime reads like:

```gdscript
full_text = str(entry.get("text", ""))
```

Use:

```gdscript
full_text = LocalizationManager.get_entry_text(entry)
```

## Validation

After changing localization scripts or content:

```powershell
.\check_godot.bat
powershell -ExecutionPolicy Bypass .\tools\validate.ps1
```
