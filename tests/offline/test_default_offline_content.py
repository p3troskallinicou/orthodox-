import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "Klimax"


def load_json(name: str):
    return json.loads((APP / name).read_text(encoding="utf-8"))


class DefaultOfflineContentTests(unittest.TestCase):
    def test_every_prayer_is_bundled_and_readable(self):
        prayers = [
            prayer
            for category in load_json("prayers.json")["categories"]
            for prayer in category["prayers"]
        ]
        self.assertGreaterEqual(len(prayers), 64)
        self.assertTrue(all(prayer.get("status") == "complete" for prayer in prayers))
        self.assertTrue(all(prayer.get("body") for prayer in prayers))

    def test_complete_scripture_is_bundled(self):
        bible = load_json("scripture.json")
        books = [
            book
            for testament in bible["testaments"]
            for book in testament["books"]
        ]
        verses = [
            verse
            for book in books
            for chapter in book["chapters"]
            for verse in chapter["verses"]
        ]
        self.assertEqual(len(books), 79)
        self.assertGreaterEqual(len(verses), 36_000)

    def test_gerontikon_and_saints_are_bundled(self):
        stories = load_json("pateric-stories.json")["stories"]
        self.assertGreaterEqual(len(stories), 614)
        self.assertTrue(all(story.get("text") and story.get("meaning") for story in stories))

        saints = [
            saint
            for rank in load_json("saints.json")["ranks"]
            for saint in rank["saints"]
        ]
        self.assertGreaterEqual(len(saints), 924)
        self.assertTrue(all(saint.get("bio") for saint in saints))
        self.assertTrue(all((saint.get("apolytikion") or {}).get("textEl") for saint in saints))

    def test_offline_files_are_app_resources(self):
        project = (ROOT / "Klimax.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
        resources = [
            "prayers.json in Resources",
            "scripture.json in Resources",
            "saints.json in Resources",
            "pateric-stories.json in Resources",
            "sunday-offices-2026.json in Resources",
            "typikon-services-2026.json in Resources",
            "chrysostom.el.json in Resources",
            "basil.el.json in Resources",
            "presanctified.el.json in Resources",
        ]
        self.assertTrue(all(resource in project for resource in resources))


if __name__ == "__main__":
    unittest.main()
