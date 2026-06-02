from __future__ import annotations

import json
from pathlib import Path


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

DIALOGUE_PATH = Path("data/dialogues/sunken_city_lyra_room.json")
LOCALIZATION_PATH = Path("data/localization/dialogues/sunken_city_lyra_room.json")

EN_TRANSLATIONS: dict[str, str] = {
    "sunken_city_lyra_room.opening_after_storybook.001.lumi.text": "You're reading that book again?",
    "sunken_city_lyra_room.opening_after_storybook.002.stagedir.text": "Lyra gently closes the book.",
    "sunken_city_lyra_room.opening_after_storybook.003.lumi.text": "She turns into foam at the end. Why is that still a Happy Ending?",
    "sunken_city_lyra_room.opening_after_storybook.004.stagedir.text": "Lyra does not answer. She only smiles faintly.",
    "sunken_city_lyra_room.opening_after_storybook.005.lumi.text": "What are you smiling about?",
    "sunken_city_lyra_room.opening_after_storybook.006.lumi.text": "Fine, fine. You always make that face after reading it anyway.",
    "sunken_city_lyra_room.opening_after_storybook.007.lumi.text": "Huh?",
    "sunken_city_lyra_room.opening_after_storybook.008.lumi.text": "An earthquake? Quick, we need to go outside and look!",
    "sunken_city_lyra_room.movement_tutorial_after_storybook.001.system.text": "Controls: move with WASD or the arrow keys. You can also left-click the ground to move.",
    "sunken_city_lyra_room.movement_tutorial_after_storybook.002.system.text": "Approaching interactive places will trigger dialogue. During dialogue, press Enter or left-click to continue.",
    "sunken_city_lyra_room.storybook_after_reading.001.lumi.text": "You're reading that book again?",
    "sunken_city_lyra_room.storybook_after_reading.002.lumi.text": "She turns into foam at the end. Why is that still a Happy Ending?",
    "sunken_city_lyra_room.storybook_after_reading.003.lyra.text": "...",
    "sunken_city_lyra_room.storybook_after_reading.004.lumi.text": "What are you smiling about?",
    "sunken_city_lyra_room.storybook_after_reading_again.001.lumi.text": "You've read that page enough times to recite it by heart, haven't you?",
    "sunken_city_lyra_room.storybook_after_reading_again.002.lyra.text": "...",
    "sunken_city_lyra_room.storybook_after_reading_again.003.lumi.text": "All right, I know you like it.",
    "sunken_city_lyra_room.storybook_after_reading_quiet.001.lumi.text": "That book is old, but every time you read it, you go so quiet.",
    "sunken_city_lyra_room.window.001.lumi.text": "The light in the water outside is very calm today.",
    "sunken_city_lyra_room.window_lights.001.lumi.text": "The lights in the distance look a little dimmer than usual.",
    "sunken_city_lyra_room.window_surface.001.lumi.text": "Are you thinking about the world above the sea again?",
    "sunken_city_lyra_room.bookshelf.001.lumi.text": "These are all books you've read over and over.",
    "sunken_city_lyra_room.bookshelf_notes.001.lumi.text": "Your notes are tucked between the pages. Your handwriting is still tiny.",
    "sunken_city_lyra_room.bookshelf_old_story.001.lumi.text": "Fairy tales, history books, and a pile of books that look really difficult.",
    "sunken_city_lyra_room.bed.001.lumi.text": "This isn't the time to go back to sleep, is it?",
    "sunken_city_lyra_room.bed_blanket.001.lumi.text": "The blanket is folded neatly. That's rare.",
    "sunken_city_lyra_room.bed_morning.001.lumi.text": "If you lie back down, I'm going to wake you up."
}


def make_key(dialogue_id: str, index: int, speaker: str) -> str:
    return f"sunken_city_lyra_room.{dialogue_id}.{index:03d}.{speaker.lower()}.text"


def main() -> int:
    dialogue_data = json.loads(DIALOGUE_PATH.read_text(encoding="utf-8"))
    localization = json.loads(LOCALIZATION_PATH.read_text(encoding="utf-8"))

    for locale in LOCALES:
        localization.setdefault(locale, {})

    for dialogue_id, entries in dialogue_data.items():
        if not isinstance(entries, list):
            continue
        for index, entry in enumerate(entries, 1):
            if not isinstance(entry, dict):
                continue
            speaker = str(entry.get("speaker", "text")).strip() or "text"
            key = make_key(dialogue_id, index, speaker)
            entry["text_key"] = key
            source_text = str(entry.get("text", ""))
            if source_text and not localization["zh_TW"].get(key):
                localization["zh_TW"][key] = source_text
            localization["en"][key] = EN_TRANSLATIONS.get(key, localization["en"].get(key, ""))
            for locale in LOCALES:
                localization[locale].setdefault(key, "")

    DIALOGUE_PATH.write_text(
        json.dumps(dialogue_data, ensure_ascii=False, indent="\t") + "\n",
        encoding="utf-8",
    )
    LOCALIZATION_PATH.write_text(
        json.dumps(localization, ensure_ascii=False, indent="\t") + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
