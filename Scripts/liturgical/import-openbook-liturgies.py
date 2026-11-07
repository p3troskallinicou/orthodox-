#!/usr/bin/env python3
"""Import the three approved OpenBook Divine Liturgy PDFs into app JSON."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
import unicodedata
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "data/sources/liturgical/openbook"
CANONICAL_DIR = ROOT / "data/liturgical/base-liturgies"
APP_DIR = ROOT / "Klimax/LiturgicalData/BaseLiturgies"
PDFKIT = Path(__file__).with_name("pdfkit-extract.swift")

PLACEHOLDERS = {
    "apostle": "{{APOSTLE}}",
    "gospel": "{{GOSPEL}}",
    "troparia": "{{TROPARIA}}",
    "kontakia": "{{KONTAKIA}}",
    "commemorations": "{{COMMEMORATIONS}}",
}

SPEAKER_PATTERNS = (
    (r"(?:Ὁ|Ο)?\s*(?:Ἱερεὺς|Ἱερεύς|Ιερεύς|ΙΕΡΕΥΣ)", "Ἱερεύς"),
    (r"(?:Ὁ|Ο)?\s*(?:Διάκονος|ΔΙΑΚΟΝΟΣ)", "Διάκονος"),
    (r"(?:Ὁ|Ο)?\s*(?:Χορὸς|Χορός|ΧΟΡΟΣ)", "Χορός"),
    (r"(?:Ὁ|Ο)?\s*(?:Ψάλτης|ΨΑΛΤΗΣ)", "Ψάλτης"),
    (r"(?:Ὁ|Ο)?\s*(?:Λαός|ΛΑΟΣ)", "Λαός"),
    (r"(?:Ὁ|Ο)?\s*(?:Ἀναγνώστης|Αναγνώστης|ΑΝΑΓΝΩΣΤΗΣ)", "Ἀναγνώστης"),
)
SPEAKER_RE = re.compile(
    r"^\s*(" + "|".join(f"(?P<s{i}>{pattern})" for i, (pattern, _) in enumerate(SPEAKER_PATTERNS)) + r")\s*[:,.]?\s*(.*)$",
    re.IGNORECASE,
)

HEADING_MARKERS = (
    "ΕΙΡΗΝΙΚΑ", "Η ΜΙΚΡΑ ΕΙΣΟΔΟΣ", "Ο ΤΡΙΣΑΓΙΟΣ ΥΜΝΟΣ", "ΑΝΑΓΝΩΣΜΑΤΑ",
    "ΕΚΤΕΝΗΣ ΔΕΗΣΙΣ", "ΔΕΗΣΙΣ ΥΠΕΡ ΤΩΝ ΚΑΤΗΧΟΥΜΕΝΩΝ",
    "Η ΛΕΙΤΟΥΡΓΙΑ ΤΩΝ ΠΙΣΤΩΝ", "Η ΜΕΓΑΛΗ ΕΙΣΟΔΟΣ",
    "Η ΣΥΝΑΠΤΗ ΤΩΝ ΤΙΜΙΩΝ ΔΩΡΩΝ", "Η ΑΓΙΑ ΑΝΑΦΟΡΑ",
    "ΔΙΠΤΥΧΑ ΚΑΙ ΔΕΗΣΕΙΣ", "ΥΨΩΣΙΣ ΚΑΙ ΜΕΛΙΣΜΟΣ", "ΘΕΙΑ ΚΟΙΝΩΝΙΑ",
    "ΚΟΙΝΩΝΙΑ ΤΩΝ ΠΙΣΤΩΝ", "ΕΥΧΑΡΙΣΤΙΑ-ΑΠΟΛΥΣΙΣ",
    "Τὸ Σύμβολον τῆς Πίστεως", "Ἡ Κυριακὴ Προσευχὴ", "Εὐχὴ ", "ΕΥΧΗ ",
)


@dataclass(frozen=True)
class SectionSpec:
    id: str
    title: str
    role: str
    pages: tuple[int, ...]
    placeholders: bool = False


@dataclass(frozen=True)
class SourceSpec:
    id: str
    title: str
    page_url: str
    pdf_url: str
    left_column: bool
    first_page: int
    sections: tuple[SectionSpec, ...]


SOURCES = (
    SourceSpec(
        "chrysostom", "Θεία Λειτουργία Ιωάννου τοῦ Χρυσοστόμου",
        "https://www.openbook.gr/theia-leitoyrgia-iwannou-chrysostomou/",
        "https://bit.ly/2M2oCIn", True, 3,
        (
            SectionSpec("opening", "Ἔναρξις", "opening", (3,)),
            SectionSpec("great-litany-antiphons", "Εἰρηνικὰ καὶ Ἀντίφωνα", "great_litany", (4, 5, 6)),
            SectionSpec("little-entrance", "Μικρὰ Εἴσοδος", "little_entrance", (7,)),
            SectionSpec("trisagion-readings", "Τρισάγιον καὶ Ἀναγνώσματα", "readings", (8,), True),
            SectionSpec("litanies", "Ἐκτενὴς Δέησις καὶ Κατηχούμενοι", "other", (9, 10, 11, 12)),
            SectionSpec("cherubic-great-entrance", "Χερουβικὸν καὶ Μεγάλη Εἴσοδος", "cherubic_hymn", (13, 14)),
            SectionSpec("gifts-creed", "Συναπτὴ τῶν Τιμίων Δώρων καὶ Σύμβολον", "creed", (15, 16, 17)),
            SectionSpec("anaphora", "Ἁγία Ἀναφορά", "anaphora", (18, 19, 20, 21, 22)),
            SectionSpec("lords-prayer", "Κυριακὴ Προσευχή", "lords_prayer", (23,)),
            SectionSpec("communion", "Θεία Κοινωνία", "communion", (24, 25, 26)),
            SectionSpec("thanksgiving-dismissal", "Εὐχαριστία καὶ Ἀπόλυσις", "thanksgiving", (27, 28, 29)),
        ),
    ),
    SourceSpec(
        "basil", "Θεία Λειτουργία Βασιλείου τοῦ Μεγάλου",
        "https://www.openbook.gr/theia-leitoyrgia-tou-megalou-vasileiou/",
        "https://bit.ly/2Ks3V3Q", False, 1,
        (
            SectionSpec("opening-antiphons", "Ἔναρξις καὶ Ἀντίφωνα", "opening", (1, 2, 3)),
            SectionSpec("little-entrance", "Μικρὰ Εἴσοδος", "little_entrance", (4,)),
            SectionSpec("trisagion-readings", "Τρισάγιον καὶ Ἀναγνώσματα", "readings", (5, 6), True),
            SectionSpec("litanies", "Ἐκτενὴς Δέησις καὶ Κατηχούμενοι", "other", (7, 8)),
            SectionSpec("cherubic-great-entrance", "Χερουβικὸν καὶ Μεγάλη Εἴσοδος", "cherubic_hymn", (9, 10)),
            SectionSpec("creed", "Σύμβολον τῆς Πίστεως", "creed", (11,)),
            SectionSpec("anaphora", "Ἁγία Ἀναφορά", "anaphora", (12, 13, 14, 15, 16, 17, 18)),
            SectionSpec("lords-prayer-communion", "Κυριακὴ Προσευχὴ καὶ Θεία Κοινωνία", "communion", (19, 20, 21)),
            SectionSpec("thanksgiving-dismissal", "Εὐχαριστία καὶ Ἀπόλυσις", "thanksgiving", (22,)),
        ),
    ),
    SourceSpec(
        "presanctified", "Θεία Λειτουργία τῶν Προηγιασμένων Δώρων",
        "https://www.openbook.gr/theia-leitoyrgia-twn-proigiasmenwn-dwrwn/",
        "https://bit.ly/2vizRD0", False, 1,
        (
            SectionSpec("opening", "Ἔναρξις καὶ Προοιμιακός", "opening", (1, 2)),
            SectionSpec("antiphons", "Καθίσματα καὶ Ἀντίφωνα", "antiphons", (3, 4, 5, 6, 7, 8)),
            SectionSpec("entrance-readings", "Εἴσοδος καὶ Ἀναγνώσματα", "readings", (9, 10, 11, 12)),
            SectionSpec("catechumens", "Κατηχούμενοι καὶ Πιστοί", "other", (13, 14)),
            SectionSpec("great-entrance", "Μεγάλη Εἴσοδος", "great_entrance", (15, 16)),
            SectionSpec("communion", "Θεία Κοινωνία", "communion", (17, 18, 19)),
            SectionSpec("thanksgiving-dismissal", "Εὐχαριστία καὶ Ἀπόλυσις", "thanksgiving", (20, 21, 22)),
        ),
    ),
)


def extract_pages(spec: SourceSpec) -> list[str]:
    source = SOURCE_DIR / f"{spec.id}.pdf"
    if not source.exists():
        raise SystemExit(f"Missing approved OpenBook PDF: {source}")
    swift = shutil.which("swift")
    if swift is None:
        raise SystemExit("Swift/PDFKit is required for deterministic PDF extraction")
    with tempfile.TemporaryDirectory(prefix=f"klimax-openbook-{spec.id}-") as directory:
        command = [swift, "-module-cache-path", "/tmp/klimax-liturgical-swift-cache", str(PDFKIT), str(source), directory]
        if spec.left_column:
            command.append("--left-column")
        subprocess.run(command, check=True)
        pages = [path.read_text(encoding="utf-8") for path in sorted(Path(directory).glob("*.txt"))]
    if not pages:
        raise SystemExit(f"No text extracted from {source}")
    return pages


def clean_page(text: str, page: int, spec: SourceSpec) -> str:
    text = unicodedata.normalize("NFC", text.replace("\r", ""))
    lines = [line.strip() for line in text.splitlines()]
    if spec.id == "chrysostom" and page == 3:
        # Discard cover/byline text and begin at the first original liturgy heading.
        index = next((i for i, line in enumerate(lines) if "ΛΕΙΤΟΥΡΓΙΑ ΤΩΝ ΚΑΤΗΧΟΥΜΕΝΩΝ" in line), 0)
        heading = "Η ΛΕΙΤΟΥΡΓΙΑ ΤΩΝ ΚΑΤΗΧΟΥΜΕΝΩΝ"
        lines = [lines[index][lines[index].find(heading):]] + lines[index + 1:]
    cleaned: list[str] = []
    for line in lines:
        if not line or re.fullmatch(r"\d+", line):
            continue
        line = re.sub(rf"^{page}(?=[Α-ωἈ-῾])", "", line)
        cleaned.append(line)
    return "\n".join(cleaned)


def is_heading(line: str) -> bool:
    letters = [char for char in line if char.isalpha()]
    return 4 <= len(letters) <= 80 and sum(char.isupper() for char in letters) / len(letters) >= 0.80


def normalize_prose(parts: list[str]) -> str:
    text = " ".join(part.strip() for part in parts if part.strip())
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"\s+([᾿’])", r"\1", text)
    return unicodedata.normalize("NFC", text).strip()


def starts_page_rubric(line: str) -> bool:
    folded = unicodedata.normalize("NFC", line).casefold().replace("ς", "σ")
    return folded.startswith((
        "οι ιερ", "οἱ ἱερ", "είτα ", "εἶτα ", "ψαλλομένου ",
        "ενώ ψάλλ", "ἐνῶ ψάλλ", "και ψάλλεται", "καὶ ψάλλεται",
        "μεθ' ό ", "μεθ᾿ ὃ ", "ενταύθα ", "ἐνταῦθα ",
        "και τουσ επομεν", "και τουσ επόμεν", "καὶ τοὺσ ἐπομέν",
    ))


def implied_page_speaker(line: str) -> str | None:
    folded = unicodedata.normalize("NFC", line).casefold()
    if folded.startswith(("ὑπὲρ ", "υπέρ ", "του κυρίου δεηθ", "τοῦ κυρίου δεηθ")):
        return "Διάκονος"
    if folded.startswith(("κύριε, ἐλέησον", "κύριε ελέησον", "ἀμήν", "αμήν", "σοί, κύριε", "σοι κύριε")):
        return "Χορός"
    return None


def heading_key(text: str) -> str:
    folded = unicodedata.normalize("NFD", text.casefold())
    folded = "".join(char for char in folded if not unicodedata.combining(char))
    words = re.findall(r"[α-ω]+", folded)
    return "".join(word for word in words if word not in {"η", "ο", "το", "και"})


def is_matching_heading(block: dict, title: str) -> bool:
    return (
        block["speaker"] is None
        and block["kind"] == "rubric"
        and heading_key(block["text_el"]) == heading_key(title)
    )


INLINE_RUBRIC_RE = re.compile(
    r"("
    r"Εὐχὴ\s+Ἀντιφώνου\s+[ΑΒΓ][´΄´']?"
    r"|[ΑΒΓ][´΄´']?\s+Ἀντίφωνον\s+καὶ\s+ἐφύμνιον"
    r"|Ὁ\s+Χερουβικὸς\s+ὕμνος"
    r"|Εὐχὴ\s+Χερουβικοῦ\s+ὕμνου"
    r")"
)


def split_inline_rubrics(blocks: list[dict]) -> list[dict]:
    output: list[dict] = []
    for block in blocks:
        parts = [part.strip() for part in INLINE_RUBRIC_RE.split(block["text_el"]) if part.strip()]
        if len(parts) == 1:
            output.append(block)
            continue
        for index, part in enumerate(parts):
            if INLINE_RUBRIC_RE.fullmatch(part):
                output.append({
                    "id": f"{block['id']}-rubric-{index}",
                    "speaker": None,
                    "kind": "rubric",
                    "text_el": part,
                })
            else:
                output.append({
                    "id": f"{block['id']}-text-{index}",
                    "speaker": block["speaker"],
                    "kind": block["kind"],
                    "text_el": part,
                })
    return output


def repair_section_boundaries(sections: list[dict]) -> None:
    """Keep page-based source splits from interrupting sentences/prayers."""
    for index, section in enumerate(sections):
        blocks = section["blocks"]
        matching = next((i for i, block in enumerate(blocks)
                         if is_matching_heading(block, section["title_el"])), None)
        if matching is not None:
            if index > 0 and matching > 0:
                # Text before the source's own heading belongs before the new
                # UI section title, even when the PDF placed it on this page.
                sections[index - 1]["blocks"].extend(blocks[:matching])
            section["blocks"] = blocks[matching + 1:]
            blocks = section["blocks"]

        if index == 0 or not blocks or not sections[index - 1]["blocks"]:
            continue
        previous = sections[index - 1]["blocks"][-1]
        first = blocks[0]
        incomplete = not previous["text_el"].rstrip().endswith((".", "·", ";", ":", "!", "?", "…"))
        if (incomplete and previous["kind"] != "placeholder" and first["kind"] != "placeholder"
                and previous["speaker"] is not None and first["speaker"] == previous["speaker"]):
            previous["text_el"] = normalize_prose([previous["text_el"], first["text_el"]])
            section["blocks"] = blocks[1:]

    # Section titles are already rendered by SwiftUI; remove any remaining
    # exact source duplicates wherever they occur in the block stream.
    for section in sections:
        without_duplicates = [
            block for block in section["blocks"]
            if not is_matching_heading(block, section["title_el"])
        ]
        merged: list[dict] = []
        for block in split_inline_rubrics(without_duplicates):
            if (merged and block["kind"] == "spoken" and merged[-1]["kind"] == "spoken"
                    and block["speaker"] is not None and block["speaker"] == merged[-1]["speaker"]):
                # Page/section extraction may split one uninterrupted speech
                # into two blocks. Merge it so the UI prints the speaker once.
                merged[-1]["text_el"] = normalize_prose([
                    merged[-1]["text_el"], block["text_el"]
                ])
            else:
                merged.append(block)
        section["blocks"] = merged
        section["text_el"] = "\n\n".join(
            f"{block['speaker']}\n{block['text_el']}" if block["speaker"] else block["text_el"]
            for block in section["blocks"]
        )


def parse_blocks(
    texts: list[str], section_id: str,
    initial_speaker: str | None = None, initial_kind: str = "rubric",
) -> tuple[list[dict], str | None, str]:
    blocks: list[dict] = []
    speaker = initial_speaker
    kind = initial_kind
    buffer: list[str] = []

    def flush() -> None:
        nonlocal buffer
        value = normalize_prose(buffer)
        if value:
            blocks.append({
                "id": f"{section_id}-block-{len(blocks) + 1}",
                "speaker": speaker,
                "kind": kind,
                "text_el": value,
            })
        buffer = []

    for page_text in texts:
        expanded = page_text
        for marker in HEADING_MARKERS:
            expanded = expanded.replace(marker, "\n" + marker)
        page_lines = [part.strip() for part in expanded.splitlines() if part.strip()]
        for line_index, line in enumerate(page_lines):
            matched = SPEAKER_RE.match(line)
            if matched:
                flush()
                for index, (_, canonical) in enumerate(SPEAKER_PATTERNS):
                    if matched.group(f"s{index}") is not None:
                        speaker = canonical
                        break
                kind = "spoken"
                remainder = matched.group(matched.re.groups).strip()
                if remainder:
                    buffer.append(remainder)
                continue
            if line_index == 0 and (inferred := implied_page_speaker(line)) is not None:
                flush()
                speaker = inferred
                kind = "spoken"
                buffer.append(line)
                continue
            if line_index == 0 and starts_page_rubric(line):
                flush()
                speaker = None
                kind = "rubric"
                buffer.append(line)
                continue
            if line.casefold().startswith(("εὐχὴ ", "ευχή ", "ευχη ")):
                flush()
                speaker = None
                kind = "rubric"
                buffer.append(line)
                flush()
                # The prayer immediately following an "Εὐχή ..." heading is
                # a priestly prayer unless the source supplies another label.
                speaker = "Ἱερεύς"
                kind = "spoken"
                continue
            if line.upper().startswith("ΨΑΛΜΟΣ ") or "ΠΡΟΟΙΜΙΑΚΟΣ ΨΑΛΜΟΣ" in line.upper():
                flush()
                speaker = None
                kind = "rubric"
                buffer.append(line)
                flush()
                speaker = "Ἀναγνώστης"
                kind = "spoken"
                continue
            if is_heading(line):
                flush()
                speaker = None
                kind = "rubric"
                buffer.append(line)
                flush()
                continue
            buffer.append(line)
        flush()
        # A PDF page break is not a liturgical/speaker boundary. Keep the
        # current speaker so a prayer continuing on the next page retains the
        # same typography in the app.
    flush()
    return blocks, speaker, kind


def add_reading_placeholders(blocks: list[dict], section_id: str) -> None:
    blocks.extend((
        {"id": f"{section_id}-apostle", "speaker": "Ἀναγνώστης", "kind": "placeholder", "text_el": "{{APOSTLE}}"},
        {"id": f"{section_id}-gospel", "speaker": "Διάκονος", "kind": "placeholder", "text_el": "{{GOSPEL}}"},
    ))


def build(spec: SourceSpec, pages: list[str]) -> dict:
    cleaned = {page: clean_page(pages[page - 1], page, spec) for page in range(1, len(pages) + 1)}
    sections = []
    current_speaker: str | None = None
    current_kind = "rubric"
    for section in spec.sections:
        blocks, current_speaker, current_kind = parse_blocks(
            [cleaned[page] for page in section.pages], section.id,
            initial_speaker=current_speaker, initial_kind=current_kind,
        )
        if section.placeholders:
            add_reading_placeholders(blocks, section.id)
        text = "\n\n".join(
            f"{block['speaker']}\n{block['text_el']}" if block["speaker"] else block["text_el"]
            for block in blocks
        )
        sections.append({
            "id": section.id,
            "title_el": section.title,
            "role": section.role,
            "blocks": blocks,
            "text_el": text,
            "source_pages": list(section.pages),
            "extraction_confidence": "high",
            "notes": [],
        })
    repair_section_boundaries(sections)
    warnings = []
    if spec.id == "presanctified":
        warnings.append("Η Προηγιασμένη δεν χρησιμοποιείται ως κυριακάτικη Θεία Λειτουργία.")
    return {
        "id": spec.id,
        "title_el": spec.title,
        "language": "el",
        "source_status": "approved_openbook_source",
        "source": {
            "source_page_url": spec.page_url,
            "source_pdf_url": spec.pdf_url,
            "label": "OpenBook / IMKS digital source",
            "extraction_method": "macOS PDFKit embedded text" + ("; original left column only" if spec.left_column else ""),
        },
        "sections": sections,
        "placeholders": PLACEHOLDERS,
        "warnings": warnings,
    }


def main() -> int:
    CANONICAL_DIR.mkdir(parents=True, exist_ok=True)
    APP_DIR.mkdir(parents=True, exist_ok=True)
    for spec in SOURCES:
        payload = build(spec, extract_pages(spec))
        encoded = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
        (CANONICAL_DIR / f"{spec.id}.el.json").write_text(encoded, encoding="utf-8")
        (APP_DIR / f"{spec.id}.el.json").write_text(encoded, encoding="utf-8")
        print(f"{spec.id}: {len(payload['sections'])} sections, {sum(len(s['blocks']) for s in payload['sections'])} blocks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
