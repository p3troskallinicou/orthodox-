#!/usr/bin/env python3
"""Attach canonical speaker identities to the bundled Athos TV catalogue."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOGUE = ROOT / "Klimax" / "athos_tv_page.json"
ATHANASIOS = "Μητροπολίτης Λεμεσού Αθανάσιος"

EXPLICIT_VIDEO_SPEAKERS = {
    "hXTyXDkazLg": ["Αρχιμανδρίτης Βασίλειος Γοντικάκης"],
    "ShS8CYTHAqY": ["Γέροντας Εφραίμ Βατοπαιδινός"],
    "jPD75m5XNjY": ["Γέροντας Εφραίμ Βατοπαιδινός"],
    "VD6xT9sUKd0": ["Γέροντας Εφραίμ Βατοπαιδινός"],
    "8C2oksaFguk": ["Γέροντας Ιωσήφ Βατοπαιδινός"],
    "8caY7KoZeZY": ["Γέροντας Ιωσήφ Βατοπαιδινός"],
    "vC-i2UKoW_s": ["Γέροντας Ιωσήφ Βατοπαιδινός"],
    "BS8OumLw0Dw": ["Γέροντας Ιωσήφ Βατοπαιδινός"],
    "x_iSbpLkLUs": ["Γέροντας Ιωσήφ Βατοπαιδινός"],
    "dkOtO3_k1BM": ["Γέροντας Ιωσήφ Βατοπαιδινός"],
    "SHINhgSDdcs": ["Γέροντας Ιωσήφ Βατοπαιδινός"],
    "j6sE1ohBcvU": ["Γέροντας Ιωσήφ Βατοπαιδινός"],
    "C5yVVk5JzVw": ["Γέροντας Ιωσήφ Βατοπαιδινός"],
    "0RJXWNC1dQ8": ["Γέροντας Ιωσήφ Βατοπαιδινός"],
    "q2NkIaECTuo": ["Γέροντας Ιωσήφ Βατοπαιδινός"],
    "PfBfxgVQLxs": ["Γέροντας Ιωσήφ Βατοπαιδινός"],
}

EXPLICIT_PHRASES = (
    "Μητροπολίτης Λεμεσού Αθανάσιος",
    "Μητροπολίτης Λεμεσού κ.κ. Αθανάσιος",
    "Μητροπολίτη Λεμεσού Αθανάσιο",
    "Μητροπολίτου Λεμεσού Αθανασίου",
)

CANONICAL_ROWS = {
    "Κηρυγματα Μητροπολιτου Λεμεσου Αθανασιου",
}


def main() -> None:
    page = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    identified_ids = {
        video_id
        for row in page["rows"]
        if row["title"] in CANONICAL_ROWS
        for video_id in row["videoIds"]
    }

    for video_id, video in page["videos"].items():
        searchable = f"{video.get('title', '')}\n{video.get('description', '')}".casefold()
        is_explicit = any(phrase.casefold() in searchable for phrase in EXPLICIT_PHRASES)
        speakers = []
        if video_id in identified_ids or is_explicit:
            speakers.append(ATHANASIOS)
        speakers.extend(EXPLICIT_VIDEO_SPEAKERS.get(video_id, []))
        speakers = list(dict.fromkeys(speakers))
        if speakers:
            video["speakers"] = speakers
        else:
            video.pop("speakers", None)

    CATALOGUE.write_text(
        json.dumps(page, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    tagged = sum(bool(video.get("speakers")) for video in page["videos"].values())
    identities = {
        speaker
        for video in page["videos"].values()
        for speaker in video.get("speakers", [])
    }
    print(f"Tagged {tagged} Athos TV videos across {len(identities)} canonical speaker profiles.")


if __name__ == "__main__":
    main()
