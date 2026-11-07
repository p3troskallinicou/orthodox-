#!/usr/bin/env python3
"""Deterministically extract the approved 1856 base-liturgies PDF.

No network access, alternate source, text correction, or model transcription is
performed by this script. If the approved source PDF is absent, it fails clearly.
"""

from __future__ import annotations

import argparse
import datetime as dt
import importlib.util
import json
import re
import shutil
import subprocess
import sys
import tempfile
import unicodedata
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PDF = ROOT / "data/sources/liturgical/BK_TH5_1856_theiai_leitourgiai.pdf"
OUTPUT = ROOT / "data/liturgical/base-liturgies"
RAW = OUTPUT / "raw"
APP_OUTPUT = ROOT / "Klimax/LiturgicalData/BaseLiturgies"
PDFKIT_HELPER = Path(__file__).with_name("pdfkit-extract.swift")

HANDLE_URL = "https://olympias.lib.uoi.gr/jspui/handle/123456789/7217"
DIRECT_URL = "https://olympias.lib.uoi.gr/jspui/bitstream/123456789/7217/1/BK.%CE%985.pdf"
SOURCE_TITLE = (
    "Αι Θείαι Λειτουργίαι των εν Αγίοις Πατέρων ημών Ιωάννου του "
    "Χρυσοστόμου και Βασιλείου του Μεγάλου, συν τη των προηγιασμένων "
    "Γρηγορίου του Διαλόγου"
)

PLACEHOLDERS = {
    "apostle": "{{APOSTLE}}",
    "gospel": "{{GOSPEL}}",
    "troparia": "{{TROPARIA}}",
    "kontakia": "{{KONTAKIA}}",
    "commemorations": "{{COMMEMORATIONS}}",
}


@dataclass(frozen=True)
class LiturgySpec:
    id: str
    title: str
    start: int
    end: int
    sections: tuple[tuple[str, str, str, int, int], ...]
    dynamic_readings: bool


SPECS = (
    LiturgySpec("chrysostom", "Θεία Λειτουργία Ιωάννου τοῦ Χρυσοστόμου", 12, 29, (
        ("opening", "Ἔναρξη καὶ Μεγάλη Συναπτή", "opening", 12, 12),
        ("antiphons", "Ἀντίφωνα", "antiphons", 13, 13),
        ("entrance-trisagion", "Μικρὰ Εἴσοδος καὶ Τρισάγιος Ὕμνος", "little_entrance", 14, 14),
        ("readings", "Ἀναγνώσματα", "readings", 15, 15),
        ("catechumens-faithful", "Ἐκτενὴς Ἱκεσία καὶ Εὐχαὶ Πιστῶν", "other", 16, 17),
        ("cherubic-great-entrance", "Χερουβικὸς Ὕμνος καὶ Μεγάλη Εἴσοδος", "cherubic_hymn", 18, 19),
        ("anaphora", "Ἀναφορά", "anaphora", 20, 24),
        ("lords-prayer-communion", "Κυριακὴ Προσευχὴ καὶ Θεία Κοινωνία", "communion", 25, 26),
        ("thanksgiving-dismissal", "Εὐχαριστία καὶ Ἀπόλυσις", "thanksgiving", 27, 29),
    ), True),
    LiturgySpec("basil", "Θεία Λειτουργία Βασιλείου τοῦ Μεγάλου", 30, 51, (
        ("opening", "Ἔναρξη καὶ Μεγάλη Συναπτή", "opening", 30, 30),
        ("antiphons", "Ἀντίφωνα", "antiphons", 31, 31),
        ("entrance-trisagion", "Μικρὰ Εἴσοδος καὶ Τρισάγιος Ὕμνος", "little_entrance", 32, 32),
        ("readings", "Ἀναγνώσματα", "readings", 33, 33),
        ("catechumens-faithful", "Ἐκτενὴς Ἱκεσία καὶ Εὐχαὶ Πιστῶν", "other", 34, 36),
        ("cherubic-great-entrance", "Χερουβικὸς Ὕμνος καὶ Μεγάλη Εἴσοδος", "cherubic_hymn", 37, 38),
        ("anaphora", "Ἀναφορά", "anaphora", 39, 47),
        ("lords-prayer-communion", "Κυριακὴ Προσευχὴ καὶ Θεία Κοινωνία", "communion", 48, 49),
        ("thanksgiving-dismissal", "Εὐχαριστία καὶ Ἀπόλυσις", "thanksgiving", 50, 51),
    ), True),
    LiturgySpec("presanctified", "Θεία Λειτουργία τῶν Προηγιασμένων Δώρων", 52, 62, (
        ("opening", "Ἔναρξη", "opening", 52, 52),
        ("antiphons-readings", "Ἀντίφωνα καὶ Ἀναγνώσματα", "readings", 53, 54),
        ("litanies-faithful", "Ἐκτενὴς Ἱκεσία καὶ Εὐχαὶ Πιστῶν", "other", 55, 58),
        ("great-entrance", "Μεγάλη Εἴσοδος", "great_entrance", 59, 59),
        ("communion", "Θεία Κοινωνία", "communion", 60, 60),
        ("thanksgiving-dismissal", "Εὐχαριστία καὶ Ἀπόλυσις", "thanksgiving", 61, 62),
    ), False),
)


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFC", text.replace("\r\n", "\n").replace("\r", "\n"))
    lines = [re.sub(r"[ \t]+$", "", line) for line in text.split("\n")]
    return re.sub(r"\n{4,}", "\n\n\n", "\n".join(lines)).strip()


def extract_fitz(pdf: Path) -> list[str] | None:
    if importlib.util.find_spec("fitz") is None:
        return None
    import fitz  # type: ignore
    with fitz.open(pdf) as document:
        return [page.get_text("text") for page in document]


def extract_pdfplumber(pdf: Path) -> list[str] | None:
    if importlib.util.find_spec("pdfplumber") is None:
        return None
    import pdfplumber  # type: ignore
    with pdfplumber.open(pdf) as document:
        return [(page.extract_text() or "") for page in document.pages]


def extract_pdftotext(pdf: Path) -> list[str] | None:
    executable = shutil.which("pdftotext")
    if executable is None:
        return None
    with tempfile.TemporaryDirectory(prefix="klimax-pdftotext-") as directory:
        target = Path(directory) / "full.txt"
        subprocess.run([executable, "-layout", str(pdf), str(target)], check=True)
        text = target.read_text(encoding="utf-8", errors="replace")
    # Form feed is pdftotext's deterministic page boundary.
    return text.split("\f")[:-1] if text.endswith("\f") else text.split("\f")


def extract_pdfkit(pdf: Path) -> list[str] | None:
    swift = shutil.which("swift")
    if swift is None or not PDFKIT_HELPER.exists():
        return None
    with tempfile.TemporaryDirectory(prefix="klimax-pdfkit-") as directory:
        pages_dir = Path(directory) / "pages"
        cache = Path(tempfile.gettempdir()) / "klimax-liturgical-swift-cache"
        cache.mkdir(parents=True, exist_ok=True)
        subprocess.run([
            swift, "-module-cache-path", str(cache), str(PDFKIT_HELPER),
            str(pdf), str(pages_dir),
        ], check=True)
        files = sorted(pages_dir.glob("*.txt"))
        return [file.read_text(encoding="utf-8") for file in files]


def usable(pages: list[str] | None) -> bool:
    if not pages or len(pages) < 60:
        return False
    nonempty = sum(bool(page.strip()) for page in pages)
    greek = sum(1 for page in pages if re.search(r"[Α-ωἂ-῾]", page))
    return nonempty >= len(pages) * 0.75 and greek >= len(pages) * 0.65


def extract_pages(pdf: Path) -> tuple[list[str], str, list[str]]:
    attempts: list[str] = []
    for name, extractor in (
        ("PyMuPDF/fitz embedded text", extract_fitz),
        ("pdfplumber embedded text", extract_pdfplumber),
        ("pdftotext embedded text", extract_pdftotext),
        ("macOS PDFKit embedded text", extract_pdfkit),
    ):
        try:
            pages = extractor(pdf)
            attempts.append(f"{name}: {'available' if pages is not None else 'unavailable'}")
            if usable(pages):
                return pages or [], name, attempts
            if pages is not None:
                attempts[-1] += ", output failed usability threshold"
        except Exception as error:  # recorded and followed by the next approved local method
            attempts.append(f"{name}: failed ({type(error).__name__}: {error})")
    raise RuntimeError("No available deterministic extractor produced usable embedded text; local Greek OCR tooling is required.")


def page_stats(number: int, text: str) -> dict:
    chars = [char for char in text if not char.isspace()]
    non_ascii = sum(ord(char) > 127 for char in chars) / max(1, len(chars))
    contains_greek = bool(re.search(r"[Α-ωἂ-῾]", text))
    odd = sum(not (char.isalnum() or char.isspace() or char in ".,;·:'’‘\"!?—–-()[]{}*/+«»") for char in text)
    spaced_caps = len(re.findall(r"(?:\b[Α-ΩA-Z0-9]\s+){5,}", text))
    suspected = (odd / max(1, len(chars)) > 0.035) or spaced_caps > 1 or "�" in text
    notes = []
    if not text.strip(): notes.append("No embedded text extracted")
    if spaced_caps > 1: notes.append("Repeated spaced-capital sequences typical of OCR/layout noise")
    if "�" in text: notes.append("Unicode replacement character present")
    return {
        "page": number,
        "char_count": len(text),
        "non_ascii_ratio": round(non_ascii, 4),
        "contains_greek": contains_greek,
        "suspected_ocr_noise": suspected,
        "notes": notes,
    }


def assert_boundaries(pages: list[str]) -> None:
    signatures = {
        12: ("Η ΘΕΙΑ ΛΕΙΤΟΥΡΓΙΑ", "Χ Ρ Υ"),
        30: ("Η ΘΕΙΑ ΛΕΙΤΟΥΡΓΙΑ", "ΒΑΣΙΛΕΙΟΥ ΤΟΥ ΜΕΓΑΛΟΥ"),
        52: ("Η ΘΕΙΑ ΛΕΙΤΟΥΡΓΙΑ", "ΠΡΟΗΓΙΑΣΜΕΝΩΝ"),
        63: ("ΕΙΣΟΔΙΚ",),
    }
    for page, needles in signatures.items():
        folded = unicodedata.normalize("NFC", pages[page - 1]).upper()
        if not all(needle in folded for needle in needles):
            raise RuntimeError(f"Boundary signature mismatch on source page {page}: {needles}")


def page_block(pages: list[str], start: int, end: int) -> str:
    return normalize("\n\n".join(pages[number - 1] for number in range(start, end + 1)))


def source_metadata(method: str) -> dict:
    return {
        "title": SOURCE_TITLE,
        "repository": "Repository of UOI Olympias",
        "institution": "Πανεπιστήμιο Ιωαννίνων",
        "publisher": "Εκ του Τυπογραφείου Ν. Αγγελίδου",
        "year": 1856,
        "source_file": DEFAULT_PDF.name,
        "source_url": HANDLE_URL,
        "direct_pdf_url": DIRECT_URL,
        "extraction_method": method,
        "extraction_date": dt.date.today().isoformat(),
    }


def build_json(spec: LiturgySpec, pages: list[str], method: str) -> dict:
    sections = []
    for section_id, title, role, start, end in spec.sections:
        text = page_block(pages, start, end)
        if role == "readings" and spec.dynamic_readings:
            text = f"{text}\n\n{{{{APOSTLE}}}}\n\n{{{{GOSPEL}}}}"
        sections.append({
            "id": section_id,
            "title_el": title,
            "role": role,
            "text_el": text,
            "source_pages": list(range(start, end + 1)),
            "extraction_confidence": "medium",
            "notes": ["Embedded ABBYY OCR preserved without silent textual correction."],
        })
    warnings = [
        "The approved PDF contains an embedded ABBYY OCR layer with visible recognition noise.",
        "No wording, spelling, accents, or uncertain OCR fragments were silently corrected.",
    ]
    if spec.id == "presanctified":
        warnings.append("Presanctified is not a normal Sunday Divine Liturgy and is not selected by the Sunday resolver.")
    return {
        "id": spec.id,
        "title_el": spec.title,
        "language": "el",
        "source_status": "project_approved_public_domain_source",
        "source": source_metadata(method),
        "sections": sections,
        "placeholders": PLACEHOLDERS,
        "warnings": warnings,
    }


def report(pages: list[str], method: str, attempts: list[str], stats: list[dict]) -> str:
    noisy = [str(item["page"]) for item in stats if item["suspected_ocr_noise"]]
    return f"""# Base liturgy extraction report

## Source metadata

- Title: {SOURCE_TITLE}
- Repository: Repository of UOI Olympias, Πανεπιστήμιο Ιωαννίνων
- Publisher: Εκ του Τυπογραφείου Ν. Αγγελίδου
- Year: 1856
- Local source: `data/sources/liturgical/{DEFAULT_PDF.name}`
- Stable handle: {HANDLE_URL}
- Extraction date: {dt.date.today().isoformat()}

## Extraction

The PDF has {len(pages)} pages and contains an embedded text layer produced by ABBYY FineReader 12. The selected deterministic method was **{method}**. No new OCR was run because the installed Apple Vision recognizer reports English only; no local Greek-capable Tesseract or OCRmyPDF installation was available.

Attempts, in required order:

{chr(10).join(f'- {item}' for item in attempts)}

All {len(pages)} pages were extracted into `full-extraction.raw.txt` in page order. Pages flagged by the deterministic noise heuristic: {', '.join(noisy) if noisy else 'none'}.

## Detected ranges

| Liturgy | PDF pages | Boundary confidence |
|---|---:|---|
| Chrysostom | 12–29 | high; explicit opening heading and next-liturgy heading |
| Basil | 30–51 | high; explicit opening heading and next-liturgy heading |
| Presanctified | 52–62 | high; explicit opening heading and page 63 begins non-liturgy appendices |

The preliminary common material on pages 4–11 and appendices beginning on page 63 are preserved in the full extraction but are not silently assigned to one of the three base liturgies.

## OCR and uncertainty

The embedded OCR visibly contains recognition and layout errors (for example spaced headings, confused Greek/Latin glyphs, and punctuation noise). The pipeline does not guess corrections, modernize spelling, remove abbreviations, or convert polytonic Greek. Since the embedded PDF text API exposes no per-word OCR confidence, it would be misleading to invent word-level confidence values. Accordingly, there are no `[UNCERTAIN_TEXT]` markers in this run; affected pages are instead flagged in `page-map.json`, every JSON section is marked `medium`, and the original extracted fragments remain unchanged.

There are no `[UNCERTAIN_BOUNDARY]` markers: all three boundaries matched source headings. If a future source revision fails those signatures, extraction stops instead of guessing.

## Dynamic readings

`{{{{APOSTLE}}}}` and `{{{{GOSPEL}}}}` were inserted in the readings sections for Chrysostom and Basil. The source rubric around the readings was preserved. They were not forced into Presanctified, whose readings structure is retained from the source.

## Source isolation

No external textual source was used. In particular, no text was fetched or copied from DCS/GOARCH, Apostoliki Diakonia, GOA Canada, parish sites, blogs, PDFs, or websites. Only the approved local 1856 PDF supplied liturgical text.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf", type=Path, default=DEFAULT_PDF)
    args = parser.parse_args()
    pdf = args.pdf.resolve()
    if not pdf.exists():
        print(f"ERROR: approved source PDF is missing: {pdf}\nDownload only: {DIRECT_URL}", file=sys.stderr)
        return 2

    try:
        pages, method, attempts = extract_pages(pdf)
        assert_boundaries(pages)
    except Exception as error:
        OUTPUT.mkdir(parents=True, exist_ok=True)
        (OUTPUT / "extraction-report.md").write_text(
            f"# Base liturgy extraction report\n\nExtraction stopped: {error}\n\n"
            "No alternate source and no model-generated text were used.\n", encoding="utf-8")
        print(f"ERROR: {error}", file=sys.stderr)
        return 3

    RAW.mkdir(parents=True, exist_ok=True)
    APP_OUTPUT.mkdir(parents=True, exist_ok=True)
    full = "\n".join(f"--- PAGE {number:03d} ---\n{page.rstrip()}" for number, page in enumerate(pages, 1)) + "\n"
    (RAW / "full-extraction.raw.txt").write_text(unicodedata.normalize("NFC", full), encoding="utf-8")
    stats = [page_stats(number, text) for number, text in enumerate(pages, 1)]
    (RAW / "page-map.json").write_text(json.dumps(stats, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    for spec in SPECS:
        raw = "\n".join(
            f"--- PAGE {number:03d} ---\n{pages[number - 1].rstrip()}"
            for number in range(spec.start, spec.end + 1)
        ) + "\n"
        (RAW / f"{spec.id}.raw.txt").write_text(unicodedata.normalize("NFC", raw), encoding="utf-8")
        payload = build_json(spec, pages, method)
        encoded = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
        (OUTPUT / f"{spec.id}.el.json").write_text(encoded, encoding="utf-8")
        (APP_OUTPUT / f"{spec.id}.el.json").write_text(encoded, encoding="utf-8")

    (OUTPUT / "extraction-report.md").write_text(report(pages, method, attempts, stats), encoding="utf-8")
    print(f"Extracted {len(pages)} pages via {method}; generated three liturgy datasets.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
