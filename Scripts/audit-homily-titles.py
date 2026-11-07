#!/usr/bin/env python3

"""Audit the visible homily titles against the original MP3 catalogue names.

This tool is deliberately read-only unless --write is supplied.  It treats the
catalogue code, audio path, speaker metadata, and duration as immutable.
"""

import argparse
import collections
import difflib
import json
import re
import unicodedata
from pathlib import Path


GREEK_TO_LATIN = str.maketrans({
    "Α": "A", "Β": "B", "Γ": "G", "Δ": "D", "Ε": "E", "Ζ": "Z",
    "Η": "H", "Θ": "TH", "Ι": "I", "Κ": "K", "Λ": "L", "Μ": "M",
    "Ν": "N", "Ξ": "KS", "Ο": "O", "Π": "P", "Ρ": "R", "Σ": "S",
    "Τ": "T", "Υ": "Y", "Φ": "F", "Χ": "X", "Ψ": "PS", "Ω": "O",
})

GREEK_CHARS = r"\u0370-\u03FF\u1F00-\u1FFF"
WORD_RE = re.compile(rf"[A-Za-z8][A-Za-z0-9]*|[{GREEK_CHARS}]+|[0-9]+", re.UNICODE)
GREEK_WORD_RE = re.compile(rf"^[{GREEK_CHARS}]+$", re.UNICODE)

LOWERCASE_TITLE_WORDS = {
    "αι", "αλλά", "από", "για", "δε", "διά", "εις", "εκ", "εν", "επί", "ή", "η",
    "θα", "και", "κατά", "μα", "με", "μέσα", "μη", "να", "οι", "ο", "όπως", "όταν",
    "παρά", "περί", "προς", "σε", "στη", "στην", "στις", "στο", "στον", "τα", "τη",
    "την", "της", "τι", "το", "τον", "του", "τους", "των", "ως",
}
LOWERCASE_TITLE_KEYS = {
    "αι", "αλλα", "απο", "για", "δε", "δια", "εισ", "εκ", "εν", "επι", "η",
    "θα", "και", "κατα", "μα", "με", "μεσα", "μη", "να", "οι", "ο", "οπωσ", "οταν",
    "παρα", "περι", "προσ", "σε", "στη", "στην", "στισ", "στο", "στον", "τα", "τη",
    "την", "τησ", "τι", "το", "τον", "του", "τουσ", "των", "ωσ",
}

WORD_OVERRIDES = {
    "H": "Η", "O": "Ο", "OI": "Οι", "TO": "Το", "TA": "Τα", "TH": "Τη",
    "THN": "Την", "THS": "Της", "TOY": "Του", "TOYS": "Τους", "KAI": "Και",
    "ME": "Με", "MESA": "Μέσα", "STH": "Στη", "STHN": "Στην", "STO": "Στο",
    "STON": "Στον", "STIS": "Στις", "PROS": "Προς", "APO": "Από", "GIA": "Για",
    "ENA": "Ένα", "MIA": "Μία", "PERI": "Περί", "OS": "Ως", "NA": "Να",
    "MH": "Μη", "MAS": "Μας", "SAS": "Σας", "MOY": "Μου",
    "BIA": "Βία", "IERAPOSTOLH": "Ιεραποστολή", "ANOTEROTHTA": "Ανωτερότητα",
    "IEROTHTA": "Ιερότητα", "TIMIOTHTA": "Τιμιότητα", "TIMIOS": "Τίμιος",
    "KATANYKSH": "Κατάνυξη", "PARAKLHSH": "Παράκληση", "PARAMYTHIAS": "Παραμυθίας",
    "PROYPOTHESEIS": "Προϋποθέσεις", "ANTHROPO": "Άνθρωπο", "ANHROPO": "Άνθρωπο",
    "ANAZHTONTAS": "Αναζητώντας", "PROORISMOS": "Προορισμός", "NEOYS": "Νέους",
    "TROPOS": "Τρόπος", "DYNAMIS": "Δύναμις", "PSALMOS": "Ψαλμός",
    "SYNEPEIES": "Συνέπειες", "KOINOTHTA": "Κοινότητα", "PAROYSIAS": "Παρουσίας",
    "ANTHROPOI": "Άνθρωποι", "SYNERGIA": "Συνεργασία", "IEROS": "Ιερός",
    "ERGAZOMENOI": "Εργαζόμενοι", "NEARON": "Νεαρών", "ZEYGARION": "Ζευγαριών",
    "EFHBIA": "Εφηβεία", "FILOTHEITIS": "Φιλοθεΐτης", "SWSTH": "Σωστή",
    "ANTHRWPOY": "Ανθρώπου", "SYGNWMHS": "Συγγνώμης", "DIAKRISEWS": "Διακρίσεως",
    "AYTOGNWSIA": "Αυτογνωσία", "TAPEINWSH": "Ταπείνωση", "PROSWPO": "Πρόσωπο",
    "STAYRWSHS": "Σταύρωσης", "ANTHRWPINOY": "Ανθρώπινου", "AIWNIOTHTA": "Αιωνιότητα",
    "YMNEITE": "Υμνείτε", "AIS8HSH": "Αίσθηση", "AYTAPATH": "Αυταπάτη",
    "EKFOVISMOS": "Εκφοβισμός", "BYLLING": "Bullying", "LANITEIOY": "Λανιτείου",
    "PAVLOY": "Παύλου", "PRAEIA": "Πραεία", "SYGKATABATIKOTHTA": "Συγκαταβατικότητα",
    "DINONTE": "Δίνονται", "ORTHODOXIAS": "Ορθοδοξίας", "ORTODOXIAS": "Ορθοδοξίας",
    "ANEXMALOTISTOS": "Ανεξαχμαλώτιστος", "METANSARKOSH": "Μετενσάρκωση",
    "ANATROPI": "Ανατροπή", "KOSMIKIS": "Κοσμικής", "LOGIKIS": "Λογικής",
    "STEREH": "Στερεή", "PENTHOYNTES": "Πενθούντες", "ENTHYMOY": "Ενθυμού",
    "GINONTE": "Γίνονται", "MPORSTA": "Μπροστά", "ANEF": "Άνευ",
    "EYTHINH": "Ευθύνη", "XILIASTES": "Χιλιαστές", "PALAIOHMEROLOGITES": "Παλαιοημερολογίτες",
    "GRHGOREITE": "Γρηγορείτε", "MATHITON": "Μαθητών", "SYNAISTHISH": "Συναίσθηση",
    "APELEYTHEROMENOI": "Απελευθερωμένοι", "THNAGAPH": "την Αγάπη",
    "POIMAINOI": "Ποιμαίνει", "KATABASIA": "Καταβασία", "PATHI": "Πάθη",
    "MITROPOLITIS": "Μητροπολίτης", "ERMINEIA": "Ερμηνεία",
    "AIS8HSH": "Αίσθηση",
    "LATHI": "Λάθη",
    "AGIOTHTA": "Αγιότητα", "OPOY": "Όπου", "8HSAUROS": "Θησαυρός",
}

FULL_TITLE_OVERRIDES = {
    "A00921": "Γέροντας Εφραίμ Φιλοθεΐτης",
    "A00918": "Κίνδυνοι από τον Τεχνικό Πολιτισμό",
    "A01063_1": "Η Ουσία της Ιεράς Εξομολογήσεως",
    "A01063_2": "Η Ουσία της Ιεράς Εξομολογήσεως",
    "A02070_1": "Χριστιανά τα τέλη της ζωής ημών",
    "A02070_2": "Χριστιανά τα τέλη της ζωής ημών",
    "A01118_1": "Ορθοδοξία: Εκκλησία ή Θρησκεία;",
    "A03263": "Σχολικός Εκφοβισμός (Bullying)",
    "A03265": "Η Σημασία του Προσώπου στην Ορθόδοξη Εκκλησία",
    "A03271": "Η Συζυγική και Γονεϊκή Σχέση μέσα στην Ορθόδοξη Παράδοση",
    "A03274": "Άγιον Όρος, το Περιβόλι της Παναγίας",
    "A03287": "Να μην Κρίνουμε τους Άλλους αλλά τον Εαυτό μας",
    "A05381": "Ο Ταπεινός Άνθρωπος Αναπαύει τον Αδελφό του",
    "A05389": "Η Αλήθεια της Ορθοδοξίας",
    "A05396": "Γ΄ Νηστειών: Η Πηγή της Ταπεινοφροσύνης",
    "A05416": "Πάντα ἰσχύω ἐν τῷ ἐνδυναμοῦντί με Χριστῷ",
    "A05417": "Ομιλία Β΄ Κατανυκτικού Εσπερινού: Ερμηνεία της Κλίμακος",
    "A05418": "Ομιλία Γ΄ Κατανυκτικού Εσπερινού: Ερμηνεία της Κλίμακος",
    "A05419": "Ομιλία Δ΄ Κατανυκτικού Εσπερινού: Ερμηνεία της Κλίμακος",
    "A05420": "Ομιλία Ε΄ Κατανυκτικού Εσπερινού: Ερμηνεία της Κλίμακος",
    "A05421": "Ομιλία ΣΤ΄ Κατανυκτικού Εσπερινού: Ερμηνεία της Κλίμακος",
    "A05801": "Κήρυγμα Κυριακής ΙΖ΄ Ματθαίου: Η Χαναναία",
    "A05802": "Κήρυγμα Κυριακής των 318 Πατέρων της Α΄ Οικουμενικής Συνόδου",
    "A05803": "Κήρυγμα Κυριακής Γ΄ Λουκά",
    "A05804": "Κήρυγμα Κυριακής Ζ΄ Λουκά",
    "A05805": "Ο Γλυκύτατος Άγιος Νεκτάριος",
    "A05806": "Άρατε τον Ζυγόν μου εφ’ Υμάς",
    "A05807": "Κήρυγμα Κυριακής ΙΓ΄ Λουκά",
    "A05808": "Πραγματική μας Ανάγκη ο Χριστός!",
    "A05809": "Κήρυγμα Κυριακής Ι΄ Λουκά",
    "A05810": "Θεραπεία Ψυχής και Σώματος",
    "A05811": "Να Γίνουμε Εκλεκτοί του Θεού",
    "A05812": "Μεθ’ Ημών ο Θεός",
    "A05813": "Βάση της Ζωής μας η Άκρα Ταπείνωση",
    "A05814": "Ο Πιστός Θεράπων του Χριστού",
    "A05815": "Μετανοείτε, Ήγγικεν γαρ η Βασιλεία των Ουρανών",
    "A05816": "Η Ευγνωμοσύνη Αναβλύζει μέσα από την Ταπεινή Καρδία",
    "A05817": "Να Ζητούμε Πρώτα τη Βασιλεία του Θεού",
    "A05818": "Οι Εντολές του Χριστού: Θεραπευτική Αγωγή",
    "A05819": "Πρέπει να Αισθανόμαστε τον Πόνο της Χαναναίας",
    "A05820": "Εκ των Καρπών Αυτών Επιγνώσεσθε Αυτούς",
    "A05821": "Να Γίνει ο Χριστός ο Σκοπός της Ζωής μας",
    "A05822": "Ο Θρίαμβος της Ορθοδόξου Πίστεως",
    "A05823": "Σκοπός της Ζωής μας Είναι η κατά Χάριν Θέωσις",
    "A05824": "Όπλον Ειρήνης, Αήττητον Τρόπαιον",
    "A05825": "Η Λογική του Ευαγγελίου, μία Ανατροπή της Κοσμικής Λογικής",
    "A05314": "Ευχή Κεφαλοκλισίας",
    "A05382": "Παρηγοριά στους Πονεμένους",
    "A06297": "Η Σκλαβιά που Φέρνουν τα Πάθη",
    "A06298": "Θέλω να Αλλάξω Ζωή αλλά δεν Βλέπω Αποτέλεσμα",
    "A06316": "Η Ελευθερία του Ανθρώπου",
    "A06319": "Πνευματική Αντιμετώπιση των Δυσκολιών",
    "A09182": "Η Αποτομή της Κεφαλής του Τιμίου Προδρόμου",
    "A08013_3": "Διά τον Θάνατον του Ηγουμένου της Ιεράς Μονής Ξηροποτάμου",
    "A09199": "Κυριακή της Σταυροπροσκυνήσεως (Γ΄ Νηστειών)",
    "A19003": "Η Συμβολή του Αγίου Όρους στον Γέροντα Κυπριανό Σταυροβουνιώτη",
    "A19005": "Περί Κατακρίσεως",
    "A19008": "Κιβωτός της Σωτηρίας",
}

FUNCTION_KEYS = {
    "H", "O", "OI", "TO", "TA", "TH", "THN", "THS", "TOY", "TOYS", "TON",
    "KAI", "ME", "MESA", "STH", "STHN", "STO", "STON", "STIS", "PROS", "APO",
    "GIA", "ENA", "MIA", "PERI", "OS", "NA", "MH", "MAS", "SAS", "MOY",
}


def without_accents(value):
    value = unicodedata.normalize("NFD", value)
    return "".join(character for character in value if unicodedata.category(character) != "Mn")


def latin_key(value):
    value = without_accents(value).upper()
    value = value.translate(GREEK_TO_LATIN)
    value = value.replace("U", "Y").replace("W", "O").replace("8", "TH")
    return re.sub(r"[^A-Z0-9]", "", value)


def words(value):
    return WORD_RE.findall(value)


def clean_search_title(value):
    value = value.strip()
    # MP3 names use a spaced dash before speaker and recording metadata.
    value = re.split(r"\s*-\s*(?=(?:ATHAN|GERONT|MITROP|P\.?\s|DR\.?\s|HSYX|IEROS|"
                     r"EKDHL|ENORIA|I\s+M\s|OMILIA|ΟΜΙΛΙΑ|PAN[ /]?MIO|\d))", value, maxsplit=1, flags=re.IGNORECASE)[0]
    value = re.sub(r"^(?:\d{1,2}[A-Z]{3}(?:19|20)\d{2})\s+", "", value, flags=re.IGNORECASE)
    value = re.sub(r"\s+ΟΜΙΛΙΑ\b.*$", "", value, flags=re.IGNORECASE)
    value = re.split(
        r"\s+(?=(?:ELLADA|HELLAS|LEMESOS|SAITTAS|ENORIA|EKDHL|IEROS\s+(?:NAOS|HSYX)|"
        r"HSYXASTHRIO|IERO|DALI|LADA|BIRMINGHAM)\b)",
        value,
        maxsplit=1,
        flags=re.IGNORECASE,
    )[0]
    value = re.sub(r"\s+\S*(?:19|20)\d{2}\S*.*$", "", value)
    value = re.sub(r"(?:\s+|_)(?:\d{1,2}[-_/]){1,2}\d{2,4}.*$", "", value)
    return value.strip(" .,_;:-")


def clean_visible_title(value):
    value = value.strip()
    value = re.split(
        r"\s*[-–]\s*(?=(?:π[.,]?|Δρ[.]?|Γέρων|Γέροντας|Μητροπολίτης|"
        r"Αρχιμανδρίτης|ABa|A[st]?av|Athanas))",
        value,
        maxsplit=1,
        flags=re.IGNORECASE,
    )[0]
    value = re.sub(r"\s+(?:\d{1,2}[/_-]){1,2}\d{2,4}.*$", "", value)
    return value.strip(" .,_;:!|[]{}()΄᾿'")


def build_lexicon(items):
    candidates = collections.defaultdict(collections.Counter)
    for item in items:
        search_keys = {latin_key(word) for word in words(clean_search_title(item["searchTerms"]))}
        for word in words(clean_visible_title(item["title"])):
            if not GREEK_WORD_RE.fullmatch(word):
                continue
            key = latin_key(word)
            if len(key) >= 2 and key in search_keys:
                candidates[key][word] += 1
    return {
        key: counts.most_common(1)[0][0]
        for key, counts in candidates.items()
    }


def repository_lexicon(root, items):
    candidates = collections.defaultdict(collections.Counter)
    for key, value in build_lexicon(items).items():
        candidates[key][value] += 40
    for path in root.rglob("*"):
        if path.suffix.lower() not in {".json", ".swift", ".md", ".txt"}:
            continue
        if path.name == "homily-archive.json" or any(part.startswith(".") for part in path.parts):
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for word in WORD_RE.findall(content):
            if GREEK_WORD_RE.fullmatch(word) and len(word) > 1:
                candidates[latin_key(word)][word] += 1
    for key, value in WORD_OVERRIDES.items():
        candidates[latin_key(key)][value] += 1000
    return candidates


def normalized_current(value):
    replacements = {
        " pe ": " με ", " tov ": " τον ", " tou ": " του ", " tne ": " της ",
        " tnv ": " την ", " thn ": " την ", " ths ": " της ", " kat ": " και ",
        " twv ": " των ", " oto ": " στο ", " otn ": " στη ", " pac ": " μας ",
        " and ": " από ", " mpos ": " προς ", " mpoc ": " προς ",
    }
    value = f" {clean_visible_title(value)} "
    for old, new in replacements.items():
        value = re.sub(re.escape(old), new, value, flags=re.IGNORECASE)
    return value.strip()


def greek_subword(word, wanted_key):
    if not GREEK_WORD_RE.fullmatch(word):
        return None
    folded = without_accents(word).upper()
    starts = []
    built = ""
    for character in folded:
        starts.append(len(built))
        built += character.translate(GREEK_TO_LATIN)
    starts.append(len(built))
    index = built.find(wanted_key)
    if index < 0:
        return None
    try:
        start = starts.index(index)
        end = starts.index(index + len(wanted_key))
    except ValueError:
        return None
    return word[start:end]


def preferred_word(key, candidates):
    if key in candidates:
        return candidates[key].most_common(1)[0][0]
    close = difflib.get_close_matches(key, candidates.keys(), n=1, cutoff=0.91)
    if close:
        return candidates[close[0]].most_common(1)[0][0]
    return None


def forced_word(key):
    if key in FUNCTION_KEYS:
        return None
    for raw_key, value in WORD_OVERRIDES.items():
        if latin_key(raw_key) == key:
            return value
    return None


def monotonic_text(value):
    accent_marks = {"\u0300", "\u0301", "\u0342"}
    output = []
    index = 0
    decomposed = unicodedata.normalize("NFD", value)
    while index < len(decomposed):
        character = decomposed[index]
        if unicodedata.combining(character):
            index += 1
            continue
        marks = []
        cursor = index + 1
        while cursor < len(decomposed) and unicodedata.combining(decomposed[cursor]):
            marks.append(decomposed[cursor])
            cursor += 1
        output.append(character)
        if any(mark in accent_marks for mark in marks):
            output.append("\u0301")
        if "\u0308" in marks:
            output.append("\u0308")
        index = cursor
    value = unicodedata.normalize("NFC", "".join(output))
    no_accent = {
        "ό": "ο", "ή": "η", "οί": "οι", "τό": "το", "τά": "τα", "τή": "τη",
        "τήν": "την", "τής": "της", "τόν": "τον", "τού": "του", "τούς": "τους",
        "τών": "των", "μέ": "με", "σέ": "σε", "γιά": "για", "ώς": "ως",
        "φώς": "φως",
    }
    canonical = {"όι": "οι", "οί": "οι"}
    normalized = []
    for word in value.split(" "):
        plain = word.strip(".,:;!?()[]{}\"'«»").casefold()
        replacement = canonical.get(plain) or no_accent.get(plain)
        if replacement:
            start = word.find(next(character for character in word if character.isalpha()))
            end = start + len(word.strip(".,:;!?()[]{}\"'«»"))
            core = replacement.capitalize() if word[start:start + 1].isupper() else replacement
            word = word[:start] + core + word[end:]
        normalized.append(word)
    return " ".join(normalized)


def source_tokens(value):
    tokens = [
        token for token in words(clean_search_title(value))
        if not ({character for character in token if character.isdigit()} - {"8"})
    ]
    while tokens and re.fullmatch(r"(?:[A-E]\d+|KEF\d+|ST\d+|STIX\d+)", tokens[-1], re.I):
        tokens.pop()
    return tokens


class CurrentCursor:
    def __init__(self, current_words):
        self.words = current_words
        self.index = 0
        self.offset = 0

    def take(self, key):
        for index in range(self.index, min(len(self.words), self.index + 6)):
            word = self.words[index]
            if not GREEK_WORD_RE.fullmatch(word):
                continue
            folded = without_accents(word).upper()
            pieces = [character.translate(GREEK_TO_LATIN) for character in folded]
            built = "".join(pieces)
            start_offset = self.offset if index == self.index else 0
            start_key = len("".join(pieces[:start_offset]))
            found = start_key if built.startswith(key, start_key) else -1
            if found < 0 and self.index == 0 and index == 0 and len(built) - len(key) <= 2:
                found = built.find(key, start_key)
            if found < 0:
                continue
            boundaries = [0]
            for piece in pieces:
                boundaries.append(boundaries[-1] + len(piece))
            if found not in boundaries or found + len(key) not in boundaries:
                continue
            start = boundaries.index(found)
            end = boundaries.index(found + len(key))
            self.index = index
            self.offset = end
            if self.offset >= len(word):
                self.index += 1
                self.offset = 0
            return word[start:end]
        return None


def proposed_title(item, candidates):
    if item["catalogCode"] in FULL_TITLE_OVERRIDES:
        return FULL_TITLE_OVERRIDES[item["catalogCode"]], []
    search_tokens = source_tokens(item["searchTerms"])
    current = normalized_current(item["title"])
    current_words = words(current)
    cursor = CurrentCursor(current_words)
    if not search_tokens:
        return current, []
    result = []
    unresolved = []
    for token in search_tokens:
        key = latin_key(token)
        forced = forced_word(key)
        word = forced or cursor.take(key) or preferred_word(key, candidates)
        if word is None:
            unresolved.append(key)
            word = token
        result.append(word)
    for index, word in enumerate(result):
        plain = without_accents(word).casefold().replace("ς", "σ")
        if index and plain in LOWERCASE_TITLE_KEYS:
            result[index] = word[:1].lower() + word[1:]
        elif index == 0 and word:
            result[index] = word[:1].upper() + word[1:]
    return monotonic_text(" ".join(result)), unresolved


def title_score(value):
    score = 0
    score += 4 * len(re.findall(r"[Α-ωΆ-ώ]", value))
    score -= 10 * len(re.findall(r"[A-Za-zА-Яа-я0-9]", value))
    score -= 8 * len(re.findall(r"(?:\b(?:pe|tov|tou|tne|kat|and|oto)\b)", value, re.I))
    score -= 20 if re.search(r"(?:Παν/|Μητροπολίτ|\d{1,2}/\d{1,2})", value) else 0
    return score


def report(items, root):
    lexicon = build_lexicon(items)
    candidates = repository_lexicon(root, items)
    missing = collections.Counter()
    suspect = []
    proposed_changes = []
    unresolved_proposals = collections.Counter()
    for item in items:
        search = clean_search_title(item["searchTerms"])
        current = clean_visible_title(item["title"])
        current_keys = {latin_key(word) for word in words(current) if GREEK_WORD_RE.fullmatch(word)}
        for word in words(search):
            key = latin_key(word)
            if key and key not in lexicon and key not in current_keys:
                missing[key] += 1
        if (
            re.search(r"[A-Za-zА-Яа-я0-9]", current)
            or re.search(r"\b(?:pe|tov|tou|tne|kat|and|oto)\b", current, re.I)
            or re.search(r"(?:Παν/|Μητροπολίτ|\d{1,2}/\d{1,2})", current)
            or re.search(r"\S[Α-ΩΆΈΉΊΌΎΏ]", current)
        ):
            suspect.append((item["episodeNumber"], item["catalogCode"], current, search))

        proposed, unresolved = proposed_title(item, candidates)
        unresolved_proposals.update(unresolved)
        if proposed != item["title"]:
            proposed_changes.append((item["episodeNumber"], item["catalogCode"], item["title"], proposed))

    print(f"items={len(items)} lexicon={len(lexicon)} suspect={len(suspect)} missing={len(missing)}")
    print("\nMost frequent words not yet recoverable from a clean Greek occurrence:")
    for key, count in missing.most_common(120):
        print(f"{count:4} {key}")
    print("\nFirst suspect titles:")
    for number, code, current, search in suspect[:250]:
        print(f"{number:4} {code:10} | {current} | {search}")
    print(f"\nproposed_changes={len(proposed_changes)} unresolved={sum(unresolved_proposals.values())} ({len(unresolved_proposals)} unique)")
    for key, count in unresolved_proposals.most_common(200):
        print(f"UNRESOLVED {count:4} {key}")
    print("\nFirst proposed changes:")
    for number, code, old, new in proposed_changes[:250]:
        print(f"{number:4} {code:10} | {old} => {new}")
    return proposed_changes, unresolved_proposals


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("catalog", type=Path)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    data = json.loads(args.catalog.read_text(encoding="utf-8"))
    project_root = Path(__file__).resolve().parents[1]
    changes, unresolved = report(data["items"], project_root)
    if args.write:
        if unresolved:
            raise SystemExit("Refusing to write while unresolved source words remain.")
        by_number = {number: new for number, _, _, new in changes}
        for item in data["items"]:
            if item["episodeNumber"] in by_number:
                item["title"] = by_number[item["episodeNumber"]]
        args.catalog.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
