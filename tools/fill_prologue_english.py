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

PROLOGUE_PATH = Path("data/dialogues/prologue.json")
LOCALIZATION_PATH = Path("data/localization/dialogues/prologue.json")

EN_TRANSLATIONS: dict[str, str] = {
    "prologue.prelude_opening.001.stagedir.text": "Black screen.",
    "prologue.prelude_opening.002.stagedir.text": "The crackle of an old phonograph from long, long ago.",
    "prologue.prelude_opening.003.stagedir.text": "The crackle fades into the sound of waves.",
    "prologue.prelude_opening.004.stagedir.text": "A fairy tale book opens on its own.",
    "prologue.prelude_opening.005.stagedir.text": "Ink spreads across the page, drawing a little mermaid princess, a witch, a human prince, and foam upon the sea.",
    "prologue.prelude_opening.006.stagedir.text": "The book's illustration gently drifts into motion.",
    "prologue.prelude_opening.007.narration.text": "Long ago...",
    "prologue.prelude_opening.008.narration.text": "There was a mermaid princess who could never become human.",
    "prologue.prelude_opening.009.stagedir.text": "A small mermaid swims toward the light on the sea's surface.",
    "prologue.prelude_opening.010.narration.text": "She fell in love with the light.",
    "prologue.prelude_opening.011.stagedir.text": "A storm. A ship breaks apart. A human falls into the sea.",
    "prologue.prelude_opening.012.narration.text": "And then, she fell in love with the person who came from that light.",
    "prologue.prelude_opening.013.stagedir.text": "The mermaid carries the human to shore.",
    "prologue.prelude_opening.014.narration.text": "She wanted to stay by his side.",
    "prologue.prelude_opening.015.stagedir.text": "The witch's shadow rises from the deep sea.",
    "prologue.prelude_opening.016.narration.text": "So she gave up her voice.",
    "prologue.prelude_opening.017.stagedir.text": "Dawn. The mermaid wakes on the shore.",
    "prologue.prelude_opening.018.narration.text": "But...",
    "prologue.prelude_opening.019.stagedir.text": "A human girl stands beside the prince.",
    "prologue.prelude_opening.020.narration.text": "Her wish was never granted.",
    "prologue.prelude_opening.021.stagedir.text": "The book's pages turn. The mermaid becomes foam and vanishes into the morning sea.",
    "prologue.prelude_opening.022.stagedir.text": "Atlantis. A glowing city beneath the sea. Vast transparent pipes carry blue light, and schools of fish drift overhead.",
    "prologue.prelude_opening.023.stagedir.text": "Lyra closes the fairy tale book. Lumi floats beside her.",
    "prologue.prelude_opening.024.lumi.text": "Reading that book again?",
    "prologue.prelude_opening.025.stagedir.text": "Lyra nods.",
    "prologue.prelude_opening.026.lumi.text": "Don't you ever get tired of it?",
    "prologue.prelude_opening.027.stagedir.text": "Lyra hugs the book and looks toward the distant surface.",
    "prologue.prelude_opening.028.lumi.text": "I still don't understand.",
    "prologue.prelude_opening.029.lumi.text": "She turns into foam at the end. How is that a Happy Ending?",
    "prologue.prelude_opening.030.stagedir.text": "Lyra thinks for a moment, then smiles softly. She does not answer.",
    "prologue.prelude_opening.031.stagedir.text": "A low rumble.",
    "prologue.prelude_opening.032.sfx.text": "Distant impact.",
    "prologue.prelude_opening.033.stagedir.text": "The entire underwater city shakes. Pipes tremble. Blue light flickers.",
    "prologue.prelude_opening.034.lumi.text": "An earthquake?!",
    "prologue.prelude_opening.035.lumi.text": "Hurry, let's go outside and check!",
    "prologue.prelude_opening.036.stagedir.text": "The fairy tale book slips from Lyra's hands. It falls open to the page where the mermaid becomes foam.",
    "prologue.tutorial.001.system.text": "Move with the arrow keys.",
    "prologue.tutorial.002.system.text": "Press Enter to talk or interact.",
    "prologue.tutorial.003.system.text": "Press Esc to open the menu.",
    "prologue.tutorial.004.system.text": "Talk to Lumi, then head toward the source of the tremor.",
    "prologue.lumi_intro.001.lumi.text": "Lyra, you saw that light too, right?",
    "prologue.lumi_intro.002.lumi.text": "I have a very bad feeling about this.",
    "prologue.lumi_intro.003.lumi.text": "The crash site should be near the ruins in the upper right.",
    "prologue.lumi_intro.004.lumi.text": "Let's go. I'll follow you.",
    "prologue.orion_first_seen.001.stagedir.text": "A broken object has fallen into the ruins, trailing a faint light.",
    "prologue.orion_first_seen.002.lumi.text": "What... is this thing?",
    "prologue.orion_first_seen.003.stagedir.text": "Lyra approaches. She finds a person in a damaged space suit, floating in the water.",
    "prologue.orion_first_seen.004.stagedir.text": "Lyra touches him carefully.",
    "prologue.orion_first_seen.005.sfx.text": "Weak heartbeat.",
    "prologue.orion_first_seen.006.lumi.text": "He's alive?!",
    "prologue.orion_first_seen.007.stagedir.text": "The man suddenly grabs Lyra's hand.",
    "prologue.orion_first_seen.008.orion.text": "...don't... open the door...",
    "prologue.orion_first_seen.009.stagedir.text": "His hand falls limp.",
    "prologue.orion_first_seen.010.lumi.text": "What do we do...?",
    "prologue.orion_first_seen.011.stagedir.text": "Lyra looks at him. She has already made her choice.",
    "prologue.orion_rescue.001.stagedir.text": "Lyra pulls Orion and heads toward the surface.",
    "prologue.orion_rescue.002.stagedir.text": "The player drags Orion forward. His body is heavy; drifting wreckage blocks the path, and the sea currents are unstable.",
    "prologue.orion_rescue.003.orion.text": "...water...?",
    "prologue.orion_rescue.004.orion.text": "...so cold...",
    "prologue.orion_rescue.005.stagedir.text": "His consciousness fades in and out. Lyra keeps pulling him forward.",
    "prologue.orion_rescue.006.stagedir.text": "The surface. Dusk after the storm.",
    "prologue.orion_rescue.007.lumi.text": "Lyra...?",
    "prologue.orion_rescue.008.lumi.text": "This is bad! His life signs are dropping!",
    "prologue.orion_rescue.009.stagedir.text": "Lyra looks back toward the island. For the first time, she hesitates. Then she turns and swims back to the sea below.",
    "prologue.orion_rescue.010.stagedir.text": "The observatory. The witch's chamber, sealed in blue light. Ancient instruments are still running.",
    "prologue.orion_rescue.011.stagedir.text": "The witch stares at the sleeping Orion through a crystal lens.",
    "prologue.orion_rescue.012.witch.text": "A human. So he really did return.",
    "prologue.orion_rescue.013.lumi.text": "You know what he is?!",
    "prologue.orion_rescue.014.witch.text": "Yes.",
    "prologue.orion_rescue.015.lumi.text": "Then save him!",
    "prologue.orion_rescue.016.witch.text": "Not as he is.",
    "prologue.orion_rescue.017.stagedir.text": "Lyra flinches.",
    "prologue.orion_rescue.018.witch.text": "His body can no longer survive underwater.",
    "prologue.orion_rescue.019.witch.text": "If you want him to live, he must be returned to the surface.",
    "prologue.orion_rescue.020.stagedir.text": "Lyra does not look away.",
    "prologue.orion_rescue.021.stagedir.text": "The witch takes out a small vial.",
    "prologue.orion_rescue.022.witch.text": "This medicine will give you a body that can move on land. But it is not meant for you, and it will hurt.",
    "prologue.orion_rescue.023.witch.text": "Your voice will be unstable. You may never return to the form you know.",
    "prologue.orion_rescue.024.lumi.text": "...Lyra?",
    "prologue.orion_rescue.025.witch.text": "And this is only a temporary answer.",
    "prologue.orion_rescue.026.lumi.text": "Wait... isn't there another way?",
    "prologue.orion_rescue.027.witch.text": "No.",
    "prologue.orion_rescue.028.witch.text": "Or rather, none that can save him in time.",
    "prologue.orion_rescue.029.stagedir.text": "Lyra reaches out.",
    "prologue.orion_rescue.030.stagedir.text": "The witch opens a small teleportation gate. Light gathers beneath Lyra's feet.",
    "prologue.orion_rescue.031.witch.text": "The medicine will change you the moment you reach the surface.",
    "prologue.orion_rescue.032.lumi.text": "Temporarily...?",
    "prologue.orion_rescue.033.stagedir.text": "Lyra does not hesitate.",
    "prologue.orion_rescue.034.stagedir.text": "Before entering the teleportation circle, Lyra turns back toward the city beneath the sea.",
    "prologue.orion_rescue.035.stagedir.text": "Her home is glowing. Far away, quiet, and impossible to return to.",
    "prologue.orion_rescue.036.witch.text": "Lyra.",
    "prologue.orion_rescue.037.stagedir.text": "The witch pauses.",
    "prologue.orion_rescue.038.witch.text": "Do not mistake sacrifice for happiness.",
    "prologue.orion_rescue.039.stagedir.text": "The teleportation light vanishes. A storm-battered island. Lyra drinks the medicine at once.",
    "prologue.orion_rescue.040.stagedir.text": "Her tail splits into legs. Pain cuts through her body. She cannot scream.",
    "prologue.orion_rescue.041.stagedir.text": "Orion lies beside her, pale and barely breathing.",
    "prologue.orion_rescue.042.stagedir.text": "In the storm, Lyra drags him toward the lighthouse.",
    "prologue.orion_rescue.043.orion.text": "...you're... still alive...?",
    "prologue.orion_rescue.044.stagedir.text": "Lyra looks at him.",
    "prologue.orion_rescue.045.stagedir.text": "Morning. The sound of waves. Lyra slowly wakes.",
    "prologue.orion_rescue.046.stagedir.text": "A coral emergency pod glows faintly beside her. Orion is still breathing.",
    "prologue.orion_rescue.047.stagedir.text": "The fairy tale is over. But Lyra's story has only just begun.",
}


def make_key(dialogue_id: str, index: int, speaker: str) -> str:
    return f"prologue.{dialogue_id}.{index:03d}.{speaker.lower()}.text"


def main() -> int:
    prologue = json.loads(PROLOGUE_PATH.read_text(encoding="utf-8"))
    localization = json.loads(LOCALIZATION_PATH.read_text(encoding="utf-8"))

    for locale in LOCALES:
        localization.setdefault(locale, {})

    for dialogue_id, entries in prologue.items():
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

    PROLOGUE_PATH.write_text(
        json.dumps(prologue, ensure_ascii=False, indent="\t") + "\n",
        encoding="utf-8",
    )
    LOCALIZATION_PATH.write_text(
        json.dumps(localization, ensure_ascii=False, indent="\t") + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
