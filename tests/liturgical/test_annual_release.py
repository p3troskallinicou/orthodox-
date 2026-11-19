"""Negative publication tests: never turn absent evidence into verified content."""
import csv
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts/liturgical"))
from liturgical_release_gate import audit, template, year_sundays, official_pdf
from publish_reviewed_year import compile_year


class AnnualReleaseTests(unittest.TestCase):
    def test_supplied_year_remains_partial(self):
        report = audit(2026, ROOT / "Klimax")
        self.assertFalse(report["release_allowed"])
        self.assertEqual(report["source_checked"], 46)
        self.assertEqual(report["pending"], 5)
        self.assertEqual(report["announced_previous_week_only"], 1)

    def test_missing_future_years_are_blocked(self):
        for year in [2027, 2028, 2030]:
            report = audit(year, ROOT / "Klimax")
            self.assertFalse(report["release_allowed"])
            self.assertEqual(report["pending"], len(list(year_sundays(year))))

    def test_empty_template_never_overwrites_published_data(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            csv_file = root / "review.csv"
            template(2027, csv_file)
            output = root / "kanonion-2027.json"
            output.write_text("existing data")
            with self.assertRaises(ValueError):
                compile_year(2027, csv_file, output)
            self.assertEqual(output.read_text(), "existing data")
            with csv_file.open(encoding="utf-8-sig") as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual(len(rows), 52)
            self.assertTrue(all(not row["gospel_ref"] for row in rows))

    def test_calendar_handles_53_sundays(self):
        self.assertEqual(len(list(year_sundays(2028))), 53)

    def test_source_urls_must_be_official_pdfs(self):
        self.assertTrue(official_pdf("https://apostoliki-diakonia.gr/wp-content/data/fk/2026/34-2026(3821).pdf"))
        for bad in ["https://apostoliki-diakonia.gr.attacker.test/a.pdf", "http://apostoliki-diakonia.gr/a.pdf", "https://apostoliki-diakonia.gr/", ""]:
            self.assertFalse(official_pdf(bad))

    def test_status_alone_is_not_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "LiturgicalData").mkdir()
            rows = json.loads((ROOT / "Klimax/LiturgicalData/kanonion-2026.json").read_text())
            for row in rows:
                row["readings_verification_status"] = "checked_primary_sunday_sheet"
                row["readings_source_organisation"] = ""
                row["readings_review_date"] = "invalid"
            (root / "LiturgicalData/kanonion-2026.json").write_text(json.dumps(rows))
            self.assertFalse(audit(2026, root)["release_allowed"])


if __name__ == "__main__":
    unittest.main()
