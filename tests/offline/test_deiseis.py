import json
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
DEISEIS_PATH = ROOT / "Klimax" / "deiseis_kosmou.json"
PRAYERS_PATH = ROOT / "Klimax" / "prayers.json"
PROJECT_PATH = ROOT / "Klimax.xcodeproj" / "project.pbxproj"


class DeiseisCorpusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.deiseis = json.loads(DEISEIS_PATH.read_text(encoding="utf-8"))
        cls.prayers = json.loads(PRAYERS_PATH.read_text(encoding="utf-8"))

    def test_supported_schema_is_complete(self):
        self.assertEqual(self.deiseis["_type"], "prayerSection")
        self.assertEqual(
            {block["type"] for block in self.deiseis["blocks"]},
            {"rubric", "petitionSet", "prayer"},
        )
        self.assertEqual(
            set(self.deiseis["name_formulas"]),
            {"zontes", "astheneis", "odoiporountes", "kekoimimenoi"},
        )
        for formula in self.deiseis["name_formulas"].values():
            self.assertTrue(formula["label"])
            self.assertTrue(formula["prefix"])
            self.assertTrue(formula["singular_prefix"])

    def test_prayer_blocks_have_text_or_items(self):
        for block in self.deiseis["blocks"]:
            if block["type"] == "prayer":
                self.assertNotEqual(bool(block.get("text")), bool(block.get("items")))
        petition_sets = [block for block in self.deiseis["blocks"] if block["type"] == "petitionSet"]
        self.assertTrue(petition_sets)
        for block in petition_sets:
            self.assertTrue(block["response"])
            self.assertTrue(block["items"])
            self.assertTrue(all("response" not in item for item in block["items"]))

    def test_placements_resolve_through_prayer_anchor_metadata(self):
        all_prayers = [
            prayer
            for category in self.prayers["categories"]
            for prayer in category["prayers"]
        ]
        for placement in self.deiseis["placements"]:
            matches = [
                prayer
                for prayer in all_prayers
                if placement["anchor_after"] in prayer.get("anchors", {})
                and placement["anchor_before"] in prayer.get("anchors", {})
            ]
            self.assertEqual(len(matches), 1, placement["service"])
            prayer = matches[0]
            after = prayer["anchors"][placement["anchor_after"]]
            before = prayer["anchors"][placement["anchor_before"]]
            self.assertGreater(before, after)
            self.assertLess(before, len(prayer["body"]))

    def test_json_is_bundled(self):
        project = PROJECT_PATH.read_text(encoding="utf-8")
        self.assertIn("deiseis_kosmou.json in Resources", project)


if __name__ == "__main__":
    unittest.main()
