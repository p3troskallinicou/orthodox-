from __future__ import annotations

import json
import re
import unittest
import unicodedata
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "data/liturgical/base-liturgies"
APP_BASE = ROOT / "Klimax/LiturgicalData/BaseLiturgies"
REQUIRED_SECTION_KEYS = {
    "id", "title_el", "role", "text_el", "source_pages", "extraction_confidence"
}
APP_SWIFT = ROOT / "Klimax/LiturgicalServices.swift"
APP_VIEW = ROOT / "Klimax/LiturgicalServiceView.swift"
APOSTLE_OVERRIDES = ROOT / "Klimax/LiturgicalData/apostle-date-overrides.json"
SUNDAY_READINGS = ROOT / "Klimax/LiturgicalData/sunday-gospels.json"
KANONION_2026 = ROOT / "Klimax/LiturgicalData/kanonion-2026.json"


class BaseLiturgySchemaTests(unittest.TestCase):
    def load(self, name: str) -> dict:
        return json.loads((BASE / f"{name}.el.json").read_text(encoding="utf-8"))

    def test_schema_and_approved_source(self) -> None:
        for name in ("chrysostom", "basil", "presanctified"):
            payload = self.load(name)
            self.assertEqual(payload["id"], name)
            self.assertEqual(payload["language"], "el")
            self.assertEqual(payload["source_status"], "approved_openbook_source")
            self.assertTrue(payload["source"]["source_page_url"].startswith("https://www.openbook.gr/"))
            self.assertTrue(payload["sections"])
            self.assertIn("placeholders", payload)
            self.assertIn("warnings", payload)
            for section in payload["sections"]:
                self.assertTrue(REQUIRED_SECTION_KEYS.issubset(section))
                self.assertIn(section["extraction_confidence"], ("high", "medium", "low"))
                self.assertTrue(section["source_pages"])
                self.assertTrue(section["blocks"])
                for block in section["blocks"]:
                    self.assertTrue({"id", "speaker", "kind", "text_el"}.issubset(block))

    def test_dynamic_reading_placeholders(self) -> None:
        for name in ("chrysostom", "basil"):
            readings = [s for s in self.load(name)["sections"] if s["role"] == "readings"]
            self.assertTrue(readings)
            self.assertIn("{{APOSTLE}}", readings[0]["text_el"])
            self.assertIn("{{GOSPEL}}", readings[0]["text_el"])

    def test_presanctified_is_not_claimed_as_sunday_liturgy(self) -> None:
        payload = self.load("presanctified")
        warnings = " ".join(payload["warnings"]).lower()
        self.assertIn("κυριακάτικη", warnings)

    def test_chrysostom_does_not_include_modern_translation_column(self) -> None:
        text = " ".join(section["text_el"] for section in self.load("chrysostom")["sections"]).casefold()
        for modern_fragment in ("παρακαλέσουμε", "μπορούμε", "τώρα καὶ πάντα", "ψυχῶν μας"):
            self.assertNotIn(modern_fragment.casefold(), text)

    def test_assembler_uses_internal_scripture_provider(self) -> None:
        swift = APP_SWIFT.read_text(encoding="utf-8")
        self.assertIn("ScripturePassageResolver.text", swift)
        self.assertIn("bible: Bible?", swift)
        self.assertNotIn("URLSession", swift)
        self.assertIn("base.placeholders.apostle, with: apostleBlock", swift)

    def test_local_inline_placeholders_are_never_shown_as_raw_tokens(self) -> None:
        swift = APP_SWIFT.read_text(encoding="utf-8")
        self.assertIn('base.placeholders.hierarch, with: "(δεῖνος)"', swift)
        self.assertIn('base.placeholders.commemorations, with: "(δεῖνος)"', swift)
        self.assertIn(
            'with: "(μνημονεύει ἐνταῦθα ὅσα ὀνόματα θέλει κεκοιμημένων)"',
            swift,
        )

    def test_ecclesiastical_titles_keep_requested_capitalization(self) -> None:
        for root in (BASE, APP_BASE):
            for name in ("chrysostom", "basil"):
                text = (root / f"{name}.el.json").read_text(encoding="utf-8")
                for lowercase in (
                    "παναγίας", "δεσποίνης", "δεσποῖνις", "μαρίας",
                    "θεοτόκου", "θεοτόκον", "προφήτου", "προδρόμου", "βαπτιστοῦ",
                ):
                    self.assertNotIn(lowercase, text, (root, name, lowercase))

    def test_july_5_2026_apostle_override_does_not_change_gospel(self) -> None:
        overrides = json.loads(APOSTLE_OVERRIDES.read_text(encoding="utf-8"))
        july_fifth = next(item for item in overrides if item["date_new_calendar"] == "07-05")
        self.assertEqual(july_fifth["apostle"]["book"], "galatians")
        self.assertEqual(july_fifth["apostle"]["ref"], "5:22-6:2")
        self.assertEqual(july_fifth["apostle"]["display_el"], "Γαλ. 5:22–6:2")

        sundays = json.loads(SUNDAY_READINGS.read_text(encoding="utf-8"))
        fifth_matthew = next(item for item in sundays if item["id"] == "matthew_05")
        self.assertEqual(fifth_matthew["divine_liturgy_gospel"]["ref"], "8:28-9:1")

        swift = APP_SWIFT.read_text(encoding="utf-8")
        self.assertIn("SundayResolver.apostle", swift)
        self.assertIn("Asia/Nicosia", swift)

    def test_2026_kanonion_covers_every_sunday_exactly_once(self) -> None:
        import datetime

        entries = json.loads(KANONION_2026.read_text(encoding="utf-8"))
        dates = [item["date"] for item in entries]
        expected = []
        day = datetime.date(2026, 1, 1)
        while day.year == 2026:
            if day.weekday() == 6:
                expected.append(day.isoformat())
            day += datetime.timedelta(days=1)

        self.assertEqual(len(entries), 52)
        self.assertEqual(len(dates), len(set(dates)))
        self.assertEqual(set(dates), set(expected))
        for item in entries:
            self.assertTrue(item["apostle"]["book"])
            self.assertTrue(item["apostle"]["ref"])
            self.assertTrue(item["gospel"]["book"])
            self.assertTrue(item["gospel"]["ref"])
            self.assertTrue(item["gospel"]["display_el"])
            self.assertTrue(item["echos"] is None or 1 <= item["echos"] <= 8)
            self.assertTrue(item["eothinon"] is None or 1 <= item["eothinon"] <= 11)

    def test_annual_precedence_drives_all_date_sensitive_readings(self) -> None:
        entries = json.loads(KANONION_2026.read_text(encoding="utf-8"))
        today = next(item for item in entries if item["date"] == "2026-07-05")
        self.assertEqual(today["echos"], 4)
        self.assertEqual(today["eothinon"], 5)
        self.assertEqual(today["apostle"]["ref"], "5:22-6:2")
        self.assertEqual(today["gospel"]["ref"], "8:28-9:1")

        cross_book = next(item for item in entries if item["date"] == "2026-12-13")
        self.assertEqual(cross_book["gospel"]["ref"], "14:16-24")
        self.assertEqual(cross_book["additional_gospels"][0]["ref"], "22:14")

        swift = APP_SWIFT.read_text(encoding="utf-8")
        self.assertIn('decode("kanonion-2026"', swift)
        self.assertIn("yearlyEntry(for: date", swift)
        self.assertIn("annual?.additionalGospels", swift)

        project = (ROOT / "Klimax.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
        self.assertIn("kanonion-2026.json in Resources", project)

    def test_liturgy_search_is_inline_and_navigates_each_match(self) -> None:
        swift = APP_VIEW.read_text(encoding="utf-8")
        self.assertIn("inlineSearchBar", swift)
        self.assertIn("currentMatchIndex", swift)
        self.assertIn("moveMatch(by: -1)", swift)
        self.assertIn("moveMatch(by: 1)", swift)
        self.assertIn("proxy.scrollTo(result.id", swift)
        self.assertIn("searchMatchAnchor", swift)
        self.assertIn("glassCircleFallback(shape: Capsule(), interactive: false)", swift)
        self.assertNotIn("ServiceSearchSheet", swift)
        self.assertNotIn(".sheet(isPresented:", swift)

    def test_page_continuation_keeps_priest_typography(self) -> None:
        payload = self.load("chrysostom")
        matching = [
            block
            for section in payload["sections"]
            for block in section["blocks"]
            if "πρόσωπόν σου ἀπ᾿ ἐμοῦ" in block["text_el"]
        ]
        self.assertEqual(len(matching), 1)
        self.assertEqual(matching[0]["speaker"], "Ἱερεύς")
        self.assertEqual(matching[0]["kind"], "spoken")

    def test_sections_do_not_repeat_their_own_heading(self) -> None:
        def key(text: str) -> str:
            folded = unicodedata.normalize("NFD", text.casefold())
            folded = "".join(char for char in folded if not unicodedata.combining(char))
            words = re.findall(r"[α-ω]+", folded)
            return "".join(word for word in words if word not in {"η", "ο", "το", "και"})

        for name in ("chrysostom", "basil", "presanctified"):
            for section in self.load(name)["sections"]:
                duplicates = [
                    block for block in section["blocks"]
                    if block["speaker"] is None and block["kind"] == "rubric"
                    and key(block["text_el"]) == key(section["title_el"])
                ]
                self.assertFalse(duplicates, (name, section["id"]))

    def test_continuation_text_is_not_rendered_as_rubric(self) -> None:
        for name in ("chrysostom", "basil", "presanctified"):
            for section in self.load(name)["sections"]:
                for block in section["blocks"]:
                    text = block["text_el"].lstrip()
                    if block["kind"] == "rubric" and text:
                        self.assertFalse(text[0].islower(), (name, section["id"], text[:80]))

    def test_same_speaker_is_not_repeated_for_one_continuous_turn(self) -> None:
        for name in ("chrysostom", "basil", "presanctified"):
            for section in self.load(name)["sections"]:
                blocks = section["blocks"]
                for previous, current in zip(blocks, blocks[1:]):
                    repeated = (
                        previous["kind"] == current["kind"] == "spoken"
                        and previous["speaker"] is not None
                        and previous["speaker"] == current["speaker"]
                    )
                    self.assertFalse(repeated, (name, section["id"], current["speaker"]))

    def test_antiphon_rubrics_are_not_spoken_by_the_choir(self) -> None:
        payload = self.load("chrysostom")
        blocks = [block for section in payload["sections"] for block in section["blocks"]]
        rubric_phrases = ("Εὐχὴ Ἀντιφώνου", "Ἀντίφωνον καὶ ἐφύμνιον")
        self.assertTrue(any(
            block["kind"] == "rubric" and any(phrase in block["text_el"] for phrase in rubric_phrases)
            for block in blocks
        ))
        for block in blocks:
            if block["kind"] == "spoken":
                self.assertFalse(any(phrase in block["text_el"] for phrase in rubric_phrases))

    def test_canonical_and_app_copies_match(self) -> None:
        for name in ("chrysostom", "basil", "presanctified"):
            self.assertEqual(
                (BASE / f"{name}.el.json").read_bytes(),
                (APP_BASE / f"{name}.el.json").read_bytes(),
            )

    def test_no_typescript_file_hardcodes_liturgy(self) -> None:
        for path in ROOT.rglob("*.ts"):
            if "tests" in path.parts:
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            self.assertNotIn("Η ΘΕΙΑ ΛΕΙΤΟΥΡΓΙΑ", text.upper(), path)


if __name__ == "__main__":
    unittest.main()
