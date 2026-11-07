#!/usr/bin/env python3

import argparse
import csv
import io
import json
import os
import re
import statistics
import subprocess
import tempfile
import unicodedata
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pypdfium2 as pdfium
import numpy as np


ARCHIVE_TITLE = "Αρχείο ομιλιών 1850–2022"

TOPIC_RULES = [
    ("Βυζαντινὴ μουσικὴ & ψαλμωδία", [
        "βυζαντινη μουσικη", "χορωδια", "ψαλμωδια", "υμνωδια", "κρατημα", "δοξαστικο",
    ]),
    ("Ἀκολουθίες & λατρεία", [
        "ακολουθια", "αποδειπνο", "χαιρετισμοι", "μεταληψεωσ",
    ]),
    ("Ἑρμηνεία τῆς Ἀποκαλύψεως", [
        "αποκαλυψη", "αποκαλυψεωσ", "επτα σφραγ", "επτα εκκλησι",
    ]),
    ("Οἱ Δέκα Ἐντολές", [
        "δεκα εντολ", "δεκαλογ", "ου φονευσεισ", "ου μοιχευσεισ", "ου κλεψεισ",
        "ου ψευδομαρτυρησεισ", "τιμα τον πατερα", "κυριον τον θεον σου προσκυνησεισ",
    ]),
    ("Οἱ Μακαρισμοί", ["μακαρισμ", "μακαριοι οι"]),
    ("Νέοι & παιδεία", [
        "νεανικ", "νεοι", "νεουσ", "νεολαι", "σχολειο", "σχολικο", "παιδεια", "αγωγη",
        "εκπαιδευ", "κατηχητικ", "φοιτητ",
    ]),
    ("Γάμος & οἰκογένεια", [
        "γαμο", "συζυγ", "οικογεν", "γονει", "παιδι", "τεκν", "διαζυγ", "μητροτητα",
        "πατροτητα", "εφηβ", "σχολικο", "παντρευ", "ανατροφη", "ζευγαρ",
    ]),
    ("Σύγχρονος κόσμος & κοινωνία", [
        "συγχρονοσ κοσμοσ", "κοινωνικο προβλημα", "κοινωνικη ζωη", "τεχνολογ", "διαδικτυ", "τηλεορα", "ναρκωτικ",
        "ομοφυλο", "εκφοβισ", "πολιτισμ", "παγκοσμιοποι", "νεολαι", "οικολογ",
        "οικονομικ", "εργασια", "επιστημ", "ψυχολογ", "ευρωπ", "πολιτικ",
    ]),
    ("Παναγία, Ἅγιοι & βίοι", [
        "παναγι", "θεοτοκ", "αγιοσ", "αγια ", "οσιοσ", "οσια ", "μαρτυρ", "νεομαρτυρ",
        "αποστολο", "προφητ", "γεροντα", "αγιορει", "βατοπαιδ", "ιωσηφ", "παισιο",
        "πορφυριο", "αρσενιο", "νεκταριο", "χρυσοστομ", "βασιλειο", "σεραφειμ",
    ]),
    ("Δεσποτικὲς ἑορτὲς & Τριῴδιο", [
        "χριστουγεν", "θεοφαν", "υπαπαντ", "μεταμορφω", "ανασταση", "πασχα", "σταυρω", "ευαγγελισμοσ",
        "σταυροσ", "κυριακη των βαιων", "μεγαλη εβδομαδα", "μεγαλη δευτερα",
        "μεγαλη τριτη", "μεγαλη τεταρτη", "μεγαλη πεμπτη", "μεγαλη παρασκευη",
        "μεγαλο σαββατο", "πεντηκοστ", "αναληψη", "τριωδιο", "αποκρε", "διακαινησιμου",
    ]),
    ("Μυστήρια & Ἐκκλησία", [
        "εκκλησι", "θεια λειτουργ", "ευχαριστι", "μεταληψη", "βαπτισ", "χρισμα",
        "εξομολογ", "ιερωσυ", "ευχελαιο", "μυστηρι", "ναοσ του θεου", "λατρεια",
        "μοναχισμ", "μοναχικ", "επισκοπ", "ιερεα", "πνευματικοσ πατερασ",
    ]),
    ("Ὀρθόδοξη πίστη & ὁμολογία", [
        "ορθοδοξ", "ορθοδoξ", "ομολογια πιστεωσ", "αιρεσ", "ιεραποστολ", "θρησκεια",
        "χιλιαστ", "προτεσταν", "μαρτυρασ του ιεχωβα", "διαθρησκ",
    ]),
    ("Ἁγία Γραφὴ & ἑρμηνεία", [
        "αγια γραφη", "παλαια διαθηκη", "καινη διαθηκη", "ευαγγελιο", "ευαγγελικη περικοπη", "παραβολ",
        "ψαλμο", "κατα ματθ", "κατα μαρκ", "κατα λουκ", "κατα ιωαν", "αποστολικη περικοπη",
    ]),
    ("Προσευχή", [
        "προσευχ", "κυριε ιησου χριστε", "ευχη του ιησου", "νοερα ευχη", "αδιαλειπτη ευχη",
    ]),
    ("Νηστεία & πνευματικὴ ἄσκηση", [
        "νηστεια", "νηστειων", "τεσσαρακοστ", "πνευματικη ασκηση", "ασκητικ", "εγκρατεια",
        "πνευματικη παλαιστρα",
    ]),
    ("Πνευματικὸς πόλεμος", [
        "πνευματικοσ πολεμοσ", "πειρασμ", "διαβολο", "δαιμον", "πονηρο", "εχθρο",
        "πνευματικη μαχη", "οπλα του χριστιανου",
    ]),
    ("Πάθη & λογισμοί", [
        "λογισμ", "παθη", "κατακρι", "κενοδοξ", "φιλαυτ", "υπερηφαν", "θυμο", "οργη",
        "ζηλια", "φθονο", "φιλαργυρ", "σαρκικ", "ακηδια", "γαστριμαργ", "κακολογ",
    ]),
    ("Μετάνοια, πένθος & ταπείνωση", [
        "μετανοι", "ταπειν", "πενθοσ", "δακρυ", "αμαρτι", "αμαρτωλ", "συντριβ",
        "αυτομεμψ", "μεταμελ", "επιστροφη στον θεο",
    ]),
    ("Αὐτογνωσία", [
        "αυτογνω", "γνωθι σαυτον", "εαυτο", "εσωτερικοσ κοσμοσ", "προσωπικοτητα",
    ]),
    ("Διάκριση & πνευματικὴ σοφία", [
        "διακριση", "σοφια", "συνεση", "συνειδηση", "φρονημα", "πνευματικη γνωσι",
    ]),
    ("Ἀρετὲς & καρποὶ τοῦ Πνεύματος", [
        "αρετ", "αγαπη", "χαρα", "ειρηνη", "μακροθυμ", "πραοτητα", "εγκρατεια",
        "ελεημοσ", "συγχωρ", "ευγνωμοσ", "ανεξικακ", "φιλοξεν", "διακονια",
    ]),
    ("Θλίψεις & δοκιμασίες", [
        "θλιψ", "δοκιμασ", "πονο", "ασθεν", "θανατο", "πενθοσ", "απελπισ", "δυσκολ",
        "υπομον", "φοβο", "αγχοσ", "μοναξι", "αδικια",
    ]),
    ("Θάνατος & αἰώνια ζωή", [
        "θανατο", "κεκοιμη", "μνημοσυν", "αιωνια ζωη", "δευτερα παρουσια", "τελη τησ ζωησ",
        "εκδημια", "μετα θανατον", "εσχατεσ ημερεσ", "τελωνια",
    ]),
    ("Πίστη & σχέση μὲ τὸν Θεό", [
        "πιστη", "σχεση με τον θεο", "σχεση του ανθρωπου με τον θεο", "παρουσια του θεου",
        "θελημα του θεου", "προνοια του θεου", "εμπιστοσυνη", "ενωση μασ με τον θεο",
        "πορεια προσ τον θεο", "κοινωνια με το θεο",
    ]),
    ("Θεία χάρις & πνευματικὰ χαρίσματα", [
        "θεια χαρη", "θειασ χαρη", "θεια χαρισ", "χαριτοσ", "πνευματικα χαρισματα",
        "χαρισματα του αγιου πνευματοσ", "ενεργειεσ τησ θειασ",
    ]),
    ("Ἐρωτήσεις & πνευματικοὶ διάλογοι", [
        "απαντησεισ σε ερωτηματα", "απαντησεισ σε ερωτησεισ", "ερωτησεισ και απαντησεισ",
        "συζητηση", "πνευματικοι διαλογοι",
    ]),
    ("Θεολογία & ἀνθρωπολογία", [
        "τριαδ", "αγιο πνευμα", "θεολογ", "θεοσ", "χριστοσ", "ενανθρωπ", "θειa χαρη",
        "χαρισ του θεου", "ανθρωποσ", "ψυχη", "αιωνια ζωη", "σωτηρια",
    ]),
]


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("pdf", type=Path)
    parser.add_argument("audio_directory", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--audio-base-url", default="")
    return parser.parse_args()


def audio_files(directory):
    return sorted(
        (path for path in directory.iterdir() if path.is_file() and path.suffix.lower() == ".mp3"),
        key=lambda path: path.name.casefold(),
    )


def normalized_code_token(value):
    value = value.upper().strip("|[](){}.,:;'`\"")
    value = value.translate(str.maketrans({"Α": "A", "А": "A", "4": "A", "Ο": "0", "О": "0", "O": "0", "Ι": "1", "І": "1", "I": "1", "Q": "0"}))
    return value


def is_code_word(word):
    token = normalized_code_token(word["text"])
    return re.fullmatch(r"A\d{5,6}", token) is not None


def merged_centers(values, tolerance=17):
    clusters = []
    for value in sorted(values):
        if not clusters or value - statistics.mean(clusters[-1]) > tolerance:
            clusters.append([value])
        else:
            clusters[-1].append(value)
    return [statistics.mean(cluster) for cluster in clusters]


def fill_missing_centers(centers):
    if len(centers) < 3:
        return centers
    gaps = [right - left for left, right in zip(centers, centers[1:])]
    typical = statistics.median(gaps)
    completed = [centers[0]]
    for left, right in zip(centers, centers[1:]):
        gap = right - left
        pieces = max(1, round(gap / typical)) if gap > typical * 1.78 else 1
        completed.extend(left + (gap * part / pieces) for part in range(1, pieces + 1))
    return completed


def tesseract_words(image_path):
    result = subprocess.run(
        ["tesseract", str(image_path), "stdout", "-l", "ell+eng", "--psm", "11", "tsv"],
        check=True,
        capture_output=True,
        text=True,
    )
    words = []
    for row in csv.DictReader(io.StringIO(result.stdout), delimiter="\t"):
        text = (row.get("text") or "").strip()
        if row.get("level") != "5" or not text:
            continue
        try:
            left = int(row["left"])
            top = int(row["top"])
            width = int(row["width"])
            height = int(row["height"])
            confidence = float(row["conf"])
        except (TypeError, ValueError):
            continue
        words.append({
            "text": text,
            "left": left,
            "top": top,
            "width": width,
            "height": height,
            "cx": left + width / 2,
            "cy": top + height / 2,
            "confidence": confidence,
        })
    return words


def tesseract_row(image_path):
    result = subprocess.run(
        ["tesseract", str(image_path), "stdout", "-l", "ell+eng", "--psm", "6"],
        check=True,
        capture_output=True,
        text=True,
    )
    value = clean_ocr(result.stdout)
    value = re.sub(r"^\s*(?:[AΑ4][O0\d]{3,7}|\d{1,6})\s*[|\[\]]*\s*", "", value)
    value = re.sub(r"^[=<>«»|\[\](){}.,:;΄'`~\s]+", "", value)
    value = re.sub(r"^[a-zα-ωά-ώ]{1,2}\s+(?=[Α-ΩΆΈΉΊΌΎΏ])", "", value)
    return value.strip()


def grid_line_centers(image):
    grayscale = np.asarray(image.convert("L"))
    height, width = grayscale.shape
    left = int(width * 0.12)
    right = int(width * 0.91)
    dark = grayscale[:, left:right] < 180
    window = max(320, int(width * 0.20))
    score = np.zeros(height)
    for y in range(3, height - 3):
        vertically_joined = np.any(dark[y - 3:y + 4], axis=0).astype(np.int16)
        cumulative = np.concatenate(([0], np.cumsum(vertically_joined)))
        score[y] = np.max(cumulative[window:] - cumulative[:-window])

    candidates = np.where(score > window * 0.88)[0]
    groups = []
    for y in candidates:
        if not groups or y - groups[-1][-1] > 15:
            groups.append([int(y)])
        else:
            groups[-1].append(int(y))
    centers = [max(group, key=lambda y: score[y]) for group in groups]
    centers = [center for center in centers if height * 0.05 < center < height * 0.93]

    sequences = []
    for center in centers:
        # A wrapped description can make a legitimate catalogue row much taller
        # than its neighbours (page 8 has a 137 px row). Keep those grid lines in
        # the same table sequence while still rejecting page furniture.
        if not sequences or center - sequences[-1][-1] > 180:
            sequences.append([center])
        else:
            sequences[-1].append(center)
    if not sequences:
        raise ValueError("Could not identify table grid")
    return max(sequences, key=len)


def line_text(words):
    if not words:
        return ""
    line_groups = []
    for word in sorted(words, key=lambda item: (item["cy"], item["left"])):
        candidate = next((line for line in line_groups if abs(statistics.mean(item["cy"] for item in line) - word["cy"]) < 13), None)
        if candidate is None:
            line_groups.append([word])
        else:
            candidate.append(word)
    line_groups.sort(key=lambda line: statistics.mean(item["cy"] for item in line))
    text = " ".join(
        " ".join(item["text"] for item in sorted(line, key=lambda item: item["left"]))
        for line in line_groups
    )
    return clean_ocr(text)


def clean_ocr(value):
    replacements = {
        "µ": "μ",
        "ı": "ι",
        "|H ": "Η ",
        "[H ": "Η ",
        "'H ": "Η ",
        "᾿H ": "Η ",
        "H ": "Η ",
        "᾿Η": "Η",
        "᾿Ο": "Ο",
        ")Η": "Η",
        "=Η": "Η",
        "ΆΈ": "Έ",
        "|O ": "Ο ",
        "[O ": "Ο ",
        "|To ": "Το ",
        "[To ": "Το ",
    }
    for old, new in replacements.items():
        value = value.replace(old, new)
    value = re.sub(r"\s+", " ", value)
    return value.strip(" |[]")


def page_rows(page, page_index, temporary_directory):
    scale = 300 / 72
    image = page.render(scale=scale).to_pil().convert("RGB")
    image_path = Path(temporary_directory) / f"page-{page_index + 1:02}.png"
    image.save(image_path)
    width, height = image.size
    grid_lines = grid_line_centers(image)
    # The scan's first page has a faint bottom rule that disappears during
    # thresholding. Its final catalogue row is otherwise lost, shifting every
    # subsequent title by one file.
    if page_index == 0 and len(grid_lines) == 50:
        grid_lines.append(grid_lines[-1] + int(statistics.median(
            gap for gap in (right - left for left, right in zip(grid_lines, grid_lines[1:]))
            if gap < 70
        )))
    header_line_index = 2 if page_index == 0 else 1
    row_boundaries = grid_lines[header_line_index:]
    if len(row_boundaries) < 2:
        raise ValueError(f"Could not identify rows on PDF page {page_index + 1}")
    row_paths = []
    for row_index, (lower, upper) in enumerate(zip(row_boundaries, row_boundaries[1:])):
        row_path = Path(temporary_directory) / f"page-{page_index + 1:02}-row-{row_index + 1:02}.png"
        image.crop((
            int(width * 0.255),
            max(0, lower + 1),
            int(width * 0.92),
            min(height, upper - 1),
        )).save(row_path)
        row_paths.append(row_path)
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(tesseract_row, row_paths))
    for row_path in row_paths:
        row_path.unlink(missing_ok=True)
    image_path.unlink(missing_ok=True)
    return results


def original_page_number(pdf_index):
    if pdf_index <= 18:
        return (pdf_index * 2) + 1
    if pdf_index == 19:
        return 38
    return 78 - (2 * (pdf_index + 1))


def folded(value):
    value = unicodedata.normalize("NFD", value.casefold())
    return "".join(character for character in value if unicodedata.category(character) != "Mn")


def topic_for(title, filename, code):
    # These closing rows are complete services and chant recordings. The source
    # catalog codes are more reliable here than OCR text, which may also mention
    # Vespers or a Vigil inside the title of an ordinary homily.
    if code in {"A91634", "A91635", "A91636"}:
        return "Ἀκολουθίες & λατρεία"
    if code.startswith(("A920", "A989")) or code in {
        "A91637", "A91638", "A91639", "A91640", "A91641", "A91642", "A91643",
    }:
        return "Βυζαντινὴ μουσικὴ & ψαλμωδία"

    key = folded(f"{title} {filename}").replace("ς", "σ")
    ranked = []
    for order, (topic, keywords) in enumerate(TOPIC_RULES):
        matches = []
        for keyword in keywords:
            normalized = folded(keyword).replace("ς", "σ")
            if normalized in key:
                matches.append(normalized)
        if matches:
            # More specific phrases and multiple independent matches should win;
            # rule order is the deterministic tie breaker.
            score = sum(10 + min(len(match), 40) for match in set(matches))
            ranked.append((score, -order, topic))
    if ranked:
        return max(ranked)[2]
    return "Πνευματικὴ ζωὴ & ἀγώνας"


def speaker_source(description):
    marker = re.compile(
        r"\s*[-–]\s*(?=(?:π[\.,]?|Π[\.,]?|p\.|Δρ\.?|Γέρων|Γέροντας|Μητροπολίτης|Ἀρχιμανδρίτης|"
        r"Αρχιμανδρίτης|[Α-ΩΆΈΉΊΌΎΏ][Α-ωΆ-ώ.]+\s+[Α-ΩΆΈΉΊΌΎΏ][Α-ωΆ-ώ.]+))",
        flags=re.IGNORECASE,
    )
    matches = list(marker.finditer(description))
    return description[matches[-1].end():] if matches else description


def standard_speakers(description, filename):
    source = speaker_source(description)
    key = folded(source).replace("ς", "σ")
    if "μαντζαρ" in key and "εφραιμ" in key:
        return ["Γέροντας Εφραίμ Βατοπαιδινός", "Γεώργιος Μαντζαρίδης"]
    speaker = standard_speaker(source, filename)
    return [speaker] if speaker else []


def standard_speaker(source, filename):
    key = folded(source).replace("ς", "σ")
    if "παπαζαχ" in key or "papazax" in key:
        return "Γεώργιος Παπαζάχος"
    if "ρακοβαλ" in key or "rakobal" in key:
        return "Αθανάσιος Ρακοβαλής"
    if "νικοσ νικολαιδ" in key or "nikos nikolaid" in key:
        return "Νίκος Νικολαΐδης"
    if "μητροπολιτησ σισ" in key or "mit sis" in key:
        return "Μητροπολίτης Σισανίου και Σιατίστης Παύλος"
    if "παυλ" in key and any(token in key for token in ("σισ", "σιατ", "(m. σ", "(μ. σ", "sic", "star", "etc", "fic", "τισ")):
        return "Μητροπολίτης Σισανίου και Σιατίστης Παύλος"
    if "ζαχαρια" in key:
        return "π. Ζαχαρίας"
    if "μαντζαρ" in key:
        return "Γεώργιος Μαντζαρίδης"
    if "εφραιμ" in key and "βατοπαιδ" in key and "αθανασι" not in key:
        return "Γέροντας Εφραίμ Βατοπαιδινός"
    if ("εφραιμ" in key or "εοραιμ" in key) and ("φιλο" in key or "ιλοθε" in key or "ιλοβε" in key or "filoth" in key):
        return "Γέροντας Εφραίμ Φιλοθεΐτης"
    if filename.upper().startswith("A19") and "εφραιμ" in key:
        return "Γέροντας Εφραίμ Βατοπαιδινός"
    if ("μωυσ" in key or "μωησ" in key) and ("αγιορει" in key or "ανιορει" in key):
        return "Μοναχός Μωυσής Αγιορείτης"
    if "νικολαο" in key and ("μεσογ" in key or "μεσοναι" in key or "mecovat" in key):
        return "Μητροπολίτης Μεσογαίας και Λαυρεωτικής Νικόλαος"
    if "πλακιδα" in key:
        return "Αρχιμανδρίτης Πλακίδας Ντεσέιγ"
    if "ιωσηφ" in key and "βατοπαι" in key:
        return "Γέροντας Ιωσήφ Βατοπαιδινός"
    if "ιωσηφ" in key and "διονυσ" in key:
        return "π. Ιωσήφ Διονυσιάτης"
    if "βασιλειο" in key and "γοντικ" in key:
        return "Αρχιμανδρίτης Βασίλειος Γοντικάκης"
    if "αιμιλιαν" in key and "σιμων" in key:
        return "Γέροντας Αιμιλιανός Σιμωνοπετρίτης"
    if "κλεαν" in key and "παντελ" in key:
        return "π. Κλεάνθους Παντελής"
    if "μαυρομαγ" in key:
        return "Νίκος Μαυρομάγουλος"
    if "σαββασ αλεξανδρ" in key:
        return "Σάββας Αλεξάνδρου"
    if "επιφανιο" in key:
        return "π. Επιφάνιος"
    if "σεραφειμ" in key:
        return "π. Σεραφείμ"
    if "ιουστινο" in key:
        return "π. Ιουστίνος"
    if "φιλοθεο" in key and "μαχαιρ" in key:
        return "π. Φιλόθεος Μαχαιριώτης"
    if "φιλοθεο" in key and "γρηγορ" in key:
        return "π. Φιλόθεος Γρηγοριάτης"
    if (
        "αθανασι" in key
        or "αβανασι" in key
        or "athanasios" in key
        or "mit lemesou" in key
        or re.search(r"a[^\s,]{0,3}(?:av|ba)[^\s,]{2,9}", key)
        or re.search(r"\([mμ][._ ]*[aλl]\.?\)", key)
    ):
        return "Μητροπολίτης Λεμεσού Αθανάσιος"

    match = re.search(
        r"^\s*((?:π\.|Δρ\.|Γέρων|Γέροντας|Μητροπολίτης|Ἀρχιμανδρίτης|Αρχιμανδρίτης)[^,]{2,80})",
        source,
        flags=re.IGNORECASE,
    )
    if match:
        return match.group(1).strip()
    plain_name = re.search(
        r"^\s*([Α-ΩΆΈΉΊΌΎΏ][Α-ωΆ-ώ.]+(?:\s+[Α-ΩΆΈΉΊΌΎΏ][Α-ωΆ-ώ.]+){1,3})(?:\s*\([^)]*\))?\s*,",
        source,
    )
    return plain_name.group(1).strip() if plain_name else None


def greek_title(description):
    speaker_marker = re.search(
        r"\s*[-–]\s*(?=(?:π\.|Δρ\.|Γέρων|Γέροντας|Μητροπολίτης|Ἀρχιμανδρίτης|Αρχιμανδρίτης))",
        description,
        flags=re.IGNORECASE,
    )
    value = description[:speaker_marker.start()] if speaker_marker else description
    value = value.split(" - ", 1)[0].strip(" ,.;|[]()")
    greek_letters = len(re.findall(r"[Α-ωΆ-ώ]", value))
    suspicious = len(re.findall(r"[А-Яа-я]", value))
    return value if greek_letters >= 4 and suspicious <= max(2, greek_letters // 5) else None


def filename_title(path):
    stem = path.stem
    stem = re.sub(r"^A\d{5}(?:_\d+)?\s*", "", stem, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", stem).strip()


def catalog_code(path):
    match = re.match(r"(A\d{5}(?:_\d+)?)", path.name, flags=re.IGNORECASE)
    return match.group(1).upper() if match else path.stem


def duration(path):
    result = subprocess.run(["afinfo", str(path)], capture_output=True, text=True)
    match = re.search(r"estimated duration:\s*([0-9.]+) sec", result.stdout)
    return round(float(match.group(1))) if match else None


def main():
    args = arguments()
    files = audio_files(args.audio_directory)
    if len(files) != 1850:
        raise SystemExit(f"Expected 1850 MP3 files, found {len(files)}")

    pages = []
    pdf = pdfium.PdfDocument(args.pdf)
    with tempfile.TemporaryDirectory(prefix="klimax-homily-ocr-") as temporary_directory:
        for page_index in range(len(pdf)):
            rows = page_rows(pdf[page_index], page_index, temporary_directory)
            pages.append((original_page_number(page_index), rows))
            print(f"[{page_index + 1}/{len(pdf)}] source page {original_page_number(page_index)}: {len(rows)} rows")

    ordered_descriptions = [description for _, rows in sorted(pages) for description in rows]
    if len(ordered_descriptions) != len(files):
        counts = {page: len(rows) for page, rows in pages}
        raise ValueError(f"OCR row mismatch; expected={len(files)} found={len(ordered_descriptions)} page_counts={counts}")

    with ThreadPoolExecutor(max_workers=12) as pool:
        durations = list(pool.map(duration, files))

    items = []
    for number, (path, seconds) in enumerate(zip(files, durations), start=1):
        description = ordered_descriptions[number - 1]
        fallback_title = filename_title(path)
        title = greek_title(description) or fallback_title
        speakers = standard_speakers(description, path.name)
        speaker = " & ".join(speakers) if speakers else None
        topic = topic_for(title, fallback_title, catalog_code(path))
        items.append({
            "_id": f"archive-{number:04d}-{catalog_code(path).lower().replace('_', '-')}",
            "title": title,
            "episodeNumber": number,
            "audioPath": path.name,
            "durationSeconds": seconds,
            "topic": topic,
            "seriesTitle": speaker or ARCHIVE_TITLE,
            "mediaType": "audio",
            "catalogCode": catalog_code(path),
            "speaker": speaker,
            "speakers": speakers,
            "catalogDescription": description,
            "searchTerms": fallback_title,
        })

    payload = {
        "version": 1,
        "title": ARCHIVE_TITLE,
        "audioBaseURL": args.audio_base_url or None,
        "count": len(items),
        "items": items,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(items)} entries to {args.output}")


if __name__ == "__main__":
    main()
