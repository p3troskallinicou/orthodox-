from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "data/sources/liturgical/openbook"
BASE = ROOT / "data/liturgical/base-liturgies"
SCRIPT = ROOT / "scripts/liturgical/import-openbook-liturgies.py"


class BaseLiturgyExtractionTests(unittest.TestCase):
    def test_source_and_generated_artifacts_exist(self) -> None:
        for name in ("chrysostom", "basil", "presanctified"):
            self.assertTrue((SOURCE_DIR / f"{name}.pdf").is_file())
        for path in (
            BASE / "chrysostom.el.json",
            BASE / "basil.el.json",
            BASE / "presanctified.el.json",
        ):
            self.assertTrue(path.is_file(), path)
            self.assertGreater(path.stat().st_size, 0, path)

    def test_importer_and_pdfkit_helper_exist(self) -> None:
        self.assertTrue(SCRIPT.is_file())
        self.assertTrue((SCRIPT.parent / "pdfkit-extract.swift").is_file())


if __name__ == "__main__":
    unittest.main()
