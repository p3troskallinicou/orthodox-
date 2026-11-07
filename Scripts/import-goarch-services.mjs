#!/usr/bin/env node

import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const prayersPath = path.join(root, "Klimax", "prayers.json");
const data = JSON.parse(await readFile(prayersPath, "utf8"));
const publicDomainSourceUrl = "https://commons.wikimedia.org/wiki/File:Euchologion_To_Mega-_t%C4%93s_kata_Anatolas_Orthodox_Katholik%C4%93s_Ekkl%C4%93sias_periechon_tas_t%C5%8Dn_hepta_mystiri%C5%8Dn_akolouthias(1862).pdf";
const publicDomainHorologionSourceUrl = "https://commons.wikimedia.org/wiki/File:%CE%A9%CF%81%CE%BF%CE%BB%CF%8C%CE%B3%CE%B9%CE%BF%CE%BD_%CF%84%CE%BF_%CE%9C%CE%AD%CE%B3%CE%B1_%CE%A0%CE%B5%CF%81%CE%B9%CE%AD%CF%87%CE%BF%CE%BD_%CE%AC%CF%80%CE%B1%CF%83%CE%B1%CE%BD_%CF%84%CE%B7%CE%BD_%CE%B1%CE%BD%CE%AE%CE%BA%CE%BF%CF%85%CF%83%CE%B1%CE%BD_%CE%B1%CF%85%CF%84%CF%8E_%CE%91%CE%BA%CE%BF%CE%BB%CE%BF%CF%85%CE%B8%CE%AF%CE%B1%CE%BD_%CF%85%CF%80%CF%8C_%CE%92%CE%B1%CF%81%CE%B8%CE%BF%CE%BB%CE%BF%CE%BC%CE%B1%CE%AF%CE%BF%CF%85_%CE%9A%CE%BF%CF%85%CF%84%CE%BB%CE%BF%CF%85%CE%BC%CE%BF%CF%85%CF%83%CE%B9%CE%B1%CE%BD%CE%BF%CF%8D_(1851).pdf";

const services = [
  {
    id: "goarch-baptism",
    titleGreek: "Ἀκολουθία τοῦ Ἁγίου Βαπτίσματος",
    titleEnglish: "Service of Holy Baptism",
    sourceTitle: "ΑΚΟΛΟΥΘΙΑ ΤΟΥ ΑΓΙΟΥ ΒΑΠΤΙΣΜΑΤΟΣ",
    sourceUrl: "https://digitalchantstand.goarch.org/goa/dcs/h/b/eu/baptism/gr-en/index.html",
    minimumParagraphs: 180,
  },
  {
    id: "goarch-unction",
    titleGreek: "Ἀκολουθία τοῦ Θείου Εὐχελαίου",
    titleEnglish: "Service of Holy Unction",
    sourceTitle: "ΑΚΟΛΟΥΘΙΑ ΤΟΥ ΑΓΙΟΥ ΕΛΑΙΟΥ",
    sourceUrl: "https://digitalchantstand.goarch.org/goa/dcs/h/b/eu/unction/gr-en/index.html",
    minimumParagraphs: 300,
  },
  {
    id: "goarch-funeral",
    titleGreek: "Νεκρώσιμος Ἀκολουθία",
    titleEnglish: "Funeral Service",
    sourceTitle: "ΑΚΟΛΟΥΘΙΑ ΝΕΚΡΩΣΙΜΟΣ",
    sourceUrl: "https://digitalchantstand.goarch.org/goa/dcs/h/b/eu/funeral/gr-en/index.html",
    minimumParagraphs: 100,
  },
];

const horologionServices = [
  {
    id: "goarch-vespers-ordinary",
    titleGreek: "Ἑσπερινός",
    titleEnglish: "Vespers — Fixed and Variable Parts",
    sourceTitle: "ΑΚΟΛΟΥΘΙΑ ΤΟΥ ΕΣΠΕΡΙΝΟΥ",
    sourceUrl: "https://digitalchantstand.goarch.org/goa/dcs/h/b/vespersordinary/normal/gr-en/index.html",
    bundledSource: "Ὡρολόγιον τὸ Μέγα, 1851 · δημόσιος τομέας · διασταύρωση GOARCH Digital Chant Stand",
    bundledSourceUrl: publicDomainHorologionSourceUrl,
    minimumParagraphs: 40,
    framework: [
      "@h:Μεταβαλλόμενον μέρος — Κάθισμα Ψαλτηρίου",
      "@r:Μετὰ τὴ Μεγάλη Συναπτὴ ἀναγινώσκεται τὸ Κάθισμα τοῦ Ψαλτηρίου ποὺ ὁρίζει τὸ Τυπικὸν γιὰ τὴν ἡμέρα.",
      "@h:Σταθερὸ μέρος — Κύριε, ἐκέκραξα",
      "@r:Ψάλλονται οἱ καθορισμένοι στίχοι τῶν Ψαλμῶν 140, 141, 129 καὶ 116.",
      "Κύριε, ἐκέκραξα πρὸς σέ, εἰσάκουσόν μου· εἰσάκουσόν μου, Κύριε. Κύριε, ἐκέκραξα πρὸς σέ, εἰσάκουσόν μου· πρόσχες τῇ φωνῇ τῆς δεήσεώς μου, ἐν τῷ κεκραγέναι με πρὸς σέ· εἰσάκουσόν μου, Κύριε.",
      "Κατευθυνθήτω ἡ προσευχή μου ὡς θυμίαμα ἐνώπιόν σου, ἔπαρσις τῶν χειρῶν μου θυσία ἑσπερινή· εἰσάκουσόν μου, Κύριε.",
      "@h:Μεταβαλλόμενον μέρος — Στιχηρὰ",
      "@r:Τὰ στιχηρὰ προσόμοια, τὰ ἀναστάσιμα, τὰ τοῦ Ἁγίου ἢ τῆς ἑορτῆς καὶ τὸ θεοτοκίον λαμβάνονται ἀπὸ τὴν Παρακλητική, τὸ Μηναῖον, τὸ Τριῴδιον ἢ τὸ Πεντηκοστάριον, ὅπως ὁρίζει τὸ Τυπικόν.",
      "@h:Σταθερὸ μέρος — Εἴσοδος καὶ Φῶς ἱλαρόν",
      "@r:Ὅταν ὁρίζεται εἴσοδος, γίνεται μετὰ τοῦ θυμιατοῦ· ἡ ἐπιφώνηση εἶναι «Σοφία· ὀρθοί».",
      "@s:Χορός|Φῶς ἱλαρὸν ἁγίας δόξης, ἀθανάτου Πατρός, οὐρανίου, ἁγίου, μάκαρος, Ἰησοῦ Χριστέ· ἐλθόντες ἐπὶ τὴν ἡλίου δύσιν, ἰδόντες φῶς ἑσπερινόν, ὑμνοῦμεν Πατέρα, Υἱὸν καὶ Ἅγιον Πνεῦμα, Θεόν. Ἄξιόν σε ἐν πᾶσι καιροῖς ὑμνεῖσθαι φωναῖς αἰσίαις, Υἱὲ Θεοῦ, ζωὴν ὁ διδούς· διὸ ὁ κόσμος σὲ δοξάζει.",
      "@h:Μεταβαλλόμενον μέρος — Προκείμενον καὶ Ἀναγνώσματα",
      "@r:Λέγεται τὸ προκείμενον τῆς ἡμέρας. Τὰ παλαιοδιαθηκικὰ ἀναγνώσματα προστίθενται μόνον ὅταν προβλέπονται γιὰ τὴν ἑορτή.",
      "@h:Σταθερὸ μέρος — Καταξίωσον, Κύριε",
      "@s:Ἀναγνώστης|Καταξίωσον, Κύριε, ἐν τῇ ἑσπέρᾳ ταύτῃ ἀναμαρτήτους φυλαχθῆναι ἡμᾶς. Εὐλογητὸς εἶ, Κύριε, ὁ Θεὸς τῶν Πατέρων ἡμῶν, καὶ αἰνετὸν καὶ δεδοξασμένον τὸ ὄνομά σου εἰς τοὺς αἰῶνας. Ἀμήν. Γένοιτο, Κύριε, τὸ ἔλεός σου ἐφ’ ἡμᾶς, καθάπερ ἠλπίσαμεν ἐπὶ σέ. Εὐλογητὸς εἶ, Κύριε, δίδαξόν με τὰ δικαιώματά σου. Εὐλογητὸς εἶ, Δέσποτα, συνέτισόν με τὰ δικαιώματά σου. Εὐλογητὸς εἶ, Ἅγιε, φώτισόν με τοῖς δικαιώμασί σου. Κύριε, τὸ ἔλεός σου εἰς τὸν αἰῶνα, τὰ ἔργα τῶν χειρῶν σου μὴ παρίδῃς. Σοὶ πρέπει αἶνος, σοὶ πρέπει ὕμνος, σοὶ δόξα πρέπει, τῷ Πατρὶ καὶ τῷ Υἱῷ καὶ τῷ Ἁγίῳ Πνεύματι, νῦν καὶ ἀεὶ καὶ εἰς τοὺς αἰῶνας τῶν αἰώνων. Ἀμήν.",
      "@h:Σταθερὸ μέρος — Πληρωτικὰ καὶ κεφαλοκλισία",
      "@r:Ἀκολουθοῦν ἡ πληρωτικὴ δέηση, ἡ εὐχὴ τῆς κεφαλοκλισίας καὶ, ὅταν ὁρίζεται, ἡ Λιτή.",
      "@h:Μεταβαλλόμενον μέρος — Ἀπόστιχα",
      "@r:Τὰ ἀπόστιχα καὶ τὸ θεοτοκίον λαμβάνονται ἀπὸ τὸ λειτουργικὸ βιβλίο τῆς ἡμέρας.",
      "@h:Σταθερὸ μέρος — Νῦν ἀπολύεις καὶ Τρισάγιον",
      "@s:Ἀναγνώστης|Νῦν ἀπολύεις τὸν δοῦλόν σου, Δέσποτα, κατὰ τὸ ῥῆμά σου ἐν εἰρήνῃ, ὅτι εἶδον οἱ ὀφθαλμοί μου τὸ σωτήριόν σου, ὃ ἡτοίμασας κατὰ πρόσωπον πάντων τῶν λαῶν· φῶς εἰς ἀποκάλυψιν ἐθνῶν καὶ δόξαν λαοῦ σου Ἰσραήλ.",
      "@r:Ἀκολουθοῦν τὸ Τρισάγιον, τὸ «Παναγία Τριάς», τὸ «Πάτερ ἡμῶν» καὶ ἡ ἐκφώνηση τοῦ ἱερέως.",
      "@h:Μεταβαλλόμενον μέρος — Ἀπολυτίκια",
      "@r:Ψάλλονται τὰ ἀπολυτίκια καὶ τὸ θεοτοκίον ποὺ ὁρίζει τὸ Τυπικόν.",
      "@h:Σταθερὸ μέρος — Ἀπόλυσις",
      "@r:Μετὰ τὴν ἀπόλυση τοῦ ἱερέως ὁ χορὸς εὔχεται «Τὸν Δεσπότην καὶ Ἀρχιερέα ἡμῶν…» ὅπου συνηθίζεται.",
    ],
  },
  {
    id: "goarch-matins-ordinary",
    titleGreek: "Ὄρθρος",
    titleEnglish: "Matins — Fixed and Variable Parts",
    sourceTitle: "ΑΚΟΛΟΥΘΙΑ ΤΟΥ ΟΡΘΡΟΥ",
    sourceUrl: "https://digitalchantstand.goarch.org/goa/dcs/h/b/matinsordinary/normal/gr-en/index.html",
    bundledSource: "Ὡρολόγιον τὸ Μέγα, 1851 · δημόσιος τομέας · διασταύρωση GOARCH Digital Chant Stand",
    bundledSourceUrl: publicDomainHorologionSourceUrl,
    minimumParagraphs: 140,
    framework: [
      "@h:Μεταβαλλόμενον μέρος — Θεὸς Κύριος ἢ Ἀλληλούϊα",
      "@r:Μετὰ τὸ Ἑξάψαλμο καὶ τὴ Μεγάλη Συναπτὴ ψάλλεται «Θεὸς Κύριος» μὲ τὰ ἀπολυτίκια τῆς ἡμέρας· στὶς ἡμέρες ποὺ ὁρίζει τὸ Τυπικὸν ψάλλεται «Ἀλληλούϊα».",
      "@h:Μεταβαλλόμενον μέρος — Καθίσματα Ψαλτηρίου",
      "@r:Ἀναγινώσκονται τὰ Καθίσματα τοῦ Ψαλτηρίου καὶ ψάλλονται τὰ καθίσματα τροπάρια ἀπὸ τὴν Παρακλητική, τὸ Μηναῖον, τὸ Τριῴδιον ἢ τὸ Πεντηκοστάριον.",
      "@h:Μεταβαλλόμενον μέρος — Πολυέλεος καὶ Εὐλογητάρια",
      "@r:Ὁ Πολυέλεος, ὁ Ἄμωμος, τὰ Ἀναστάσιμα Εὐλογητάρια ἢ οἱ ἐκλογὲς ψάλλονται μόνον ὅπως προβλέπει ἡ τάξη τῆς Κυριακῆς ἢ τῆς ἑορτῆς.",
      "@h:Μεταβαλλόμενον μέρος — Ἀναβαθμοί, Προκείμενον καὶ Ἑωθινὸ Εὐαγγέλιον",
      "@r:Ὁ ἦχος καθορίζει τοὺς Ἀναβαθμούς. Τὸ προκείμενον καὶ τὸ Εὐαγγέλιον λαμβάνονται ἀπὸ τὴν ἀκολουθία τῆς ἡμέρας.",
      "@h:Σταθερὸ μέρος — Ψαλμὸς Ν΄ (50)",
      "Ἐλέησόν με, ὁ Θεός, κατὰ τὸ μέγα ἔλεός σου, καὶ κατὰ τὸ πλῆθος τῶν οἰκτιρμῶν σου ἐξάλειψον τὸ ἀνόμημά μου.",
      "@r:Ὁ Ψαλμὸς Ν΄ διαβάζεται ὁλόκληρος. Τὰ τροπάρια ποὺ τὸν πλαισιώνουν μεταβάλλονται κατὰ τὴν Κυριακή, τὴν ἑορτὴ καὶ τὴ λειτουργικὴ περίοδο.",
      "@h:Μεταβαλλόμενον μέρος — Κανών",
      "@r:Οἱ ᾠδές, τὰ τροπάρια, τὰ καθίσματα, τὸ κοντάκιον, ὁ οἶκος, τὸ συναξάριον καὶ οἱ καταβασίες λαμβάνονται ἀπὸ τὰ βιβλία τῆς ἡμέρας. Ἡ Τιμιωτέρα ψάλλεται ὅταν δὲν καταλιμπάνεται.",
      "@h:Μεταβαλλόμενον μέρος — Ἐξαποστειλάρια",
      "@r:Ψάλλονται τὸ ἑωθινὸ ἐξαποστειλάριον, τὸ τοῦ Ἁγίου ἢ τῆς ἑορτῆς καὶ τὸ θεοτοκίον, σύμφωνα μὲ τὸ Τυπικόν.",
      "@h:Σταθερὸ μέρος — Αἶνοι",
      "@r:Ψάλλονται οἱ Ψαλμοὶ 148, 149 καὶ 150. Στοὺς τελευταίους στίχους παρεμβάλλονται τὰ μεταβαλλόμενα στιχηρὰ τῶν Αἴνων.",
      "@h:Μεταβαλλόμενον μέρος — Στιχηρὰ Αἴνων καὶ Δοξαστικόν",
      "@r:Τὰ στιχηρὰ, τὸ δοξαστικὸν καὶ τὸ θεοτοκίον λαμβάνονται ἀπὸ τὴν Παρακλητική καὶ τὸ βιβλίο τῆς περιόδου ἢ τῆς ἑορτῆς.",
      "@h:Σταθερὸ μέρος — Δοξολογία",
      "@r:Ἀνάλογα μὲ τὴν τάξη τῆς ἡμέρας ψάλλεται ἡ Μεγάλη Δοξολογία ἢ διαβάζεται ἡ μικρὰ δοξολογία.",
      "@s:Χορός|Δόξα σοι τῷ δείξαντι τὸ φῶς. Δόξα ἐν ὑψίστοις Θεῷ, καὶ ἐπὶ γῆς εἰρήνη, ἐν ἀνθρώποις εὐδοκία.",
      "@h:Μεταβαλλόμενον μέρος — Τροπάριον μετὰ τὴ Δοξολογία",
      "@r:Τὸ τροπάριον μεταβάλλεται ἀνάλογα μὲ τὴν Κυριακή, τὸν ἦχο ἢ τὴν ἑορτή.",
      "@h:Σταθερὸ μέρος — Συναπτὲς καὶ Ἀπόλυσις",
      "@r:Ἀκολουθοῦν οἱ αἰτήσεις, ἡ ἐκφώνηση, ἡ ἀπόλυση καὶ ἡ εὐχὴ ὑπὲρ τοῦ Ἀρχιεπισκόπου, ὅπως ὁρίζει ἡ τοπικὴ τάξη.",
    ],
  },
];

function decodeEntities(value) {
  const named = new Map([
    ["amp", "&"], ["lt", "<"], ["gt", ">"], ["quot", "\""],
    ["apos", "'"], ["nbsp", " "], ["hellip", "…"], ["middot", "·"],
    ["ndash", "–"], ["mdash", "—"], ["lsquo", "‘"], ["rsquo", "’"],
    ["ldquo", "“"], ["rdquo", "”"],
  ]);
  return value.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (match, entity) => {
    if (entity.startsWith("#x")) return String.fromCodePoint(Number.parseInt(entity.slice(2), 16));
    if (entity.startsWith("#")) return String.fromCodePoint(Number.parseInt(entity.slice(1), 10));
    return named.get(entity.toLowerCase()) ?? match;
  });
}

function visibleText(html) {
  return decodeEntities(html
    .replace(/<a\b[^>]*>[\s\S]*?<\/a>/gi, " ")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<[^>]+>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
}

function searchKey(value) {
  return value
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLocaleLowerCase("el-GR")
    .replaceAll("ς", "σ")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
}

const headingCorrections = new Map([
  ["ΤΑΞΙΣ ΓΙΝΟΜΕΝΗ ΠΡΟ ΤΟΥ ΑΓΙΟΥ ΒΑΠΤΙΣΜΑΤΟΣ", "Τάξις γινομένη πρὸ τοῦ Ἁγίου Βαπτίσματος"],
  ["ΑΦΟΡΚΙΣΜΟΣ Αʹ", "Ἀφορκισμὸς Α΄"],
  ["ΑΦΟΡΚΙΣΜΟΣ Βʹ", "Ἀφορκισμὸς Β΄"],
  ["ΑΦΟΡΚΙΣΜΟΣ Γʹ", "Ἀφορκισμὸς Γ΄"],
  ["ΨΑΛΜΟΣ Nʹ (50)", "Ψαλμὸς Ν΄ (50)"],
  ["ΕΥΧΗ ΤΗΣ ΑΠΟΛΥΣΕΩΣ", "Εὐχὴ τῆς ἀπολύσεως"],
  ["ΕΥΧΗ ΕΙΣ ΤΡΙΧΟΚΟΥΡΙΑΝ", "Εὐχὴ εἰς τριχοκουρίαν"],
  ["Η ΘΕΙΑ ΚΟΙΝΩΝΙΑ", "Ἡ Θεία Κοινωνία"],
  ["ΣΤΑΣΙΣ ΔΕΥΤΕΡΑ", "Στάσις Δευτέρα"],
  ["ΣΤΑΣΙΣ ΤΡΙΤΗ", "Στάσις Τρίτη"],
].map(([key, value]) => [searchKey(key), value]));

function speakerFrom(label) {
  const key = searchKey(label);
  if (key.startsWith("ιερευσ")) return "Ἱερεύς";
  if (key.startsWith("διακονοσ")) return "Διάκονος";
  if (key.startsWith("χοροσ")) return "Χορός";
  if (key.startsWith("λαοσ")) return "Λαός";
  if (key.startsWith("αναγνωστησ")) return "Ἀναγνώστης";
  if (key.includes("υποψηφιοσ") || key.includes("αναδοχοσ")) return "Ὑποψήφιος / Ἀνάδοχος";
  return null;
}

function spokenText(value) {
  const trimmed = value.trim();
  const wrapped = trimmed.match(/^\(\s*([\s\S]*?)\s*\)$/u);
  return (wrapped?.[1] ?? trimmed).trim();
}

function parseGreekColumn(html, service) {
  const body = [];
  const unknownActors = new Set();
  let currentSpeaker = null;
  const leftCells = [...html.matchAll(/<td\s+class=['"]leftCell['"][^>]*>([\s\S]*?)<\/td>/gi)];

  for (const cell of leftCells) {
    const paragraphs = [...cell[1].matchAll(/<p\s+class=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/p>/gi)];
    for (const paragraph of paragraphs) {
      const kind = paragraph[1].toLowerCase();
      const text = visibleText(paragraph[2]);
      if (!text) continue;

      if (["servicesourcestitle", "servicesources", "bmc_collapse", "emc_collapse", "bkmrk01"].includes(kind)) {
        continue;
      }

      if (kind === "dialogwithactor") {
        const actorMatch = text.match(/^([^:：]+)[:：]\s*(.*)$/u);
        const speaker = actorMatch ? speakerFrom(actorMatch[1]) : null;
        const dialogue = spokenText(actorMatch?.[2] ?? "");
        if (speaker && dialogue) body.push(`@s:${speaker}|${dialogue}`);
        else body.push(text);
        currentSpeaker = null;
        continue;
      }

      if (kind === "designation") {
        currentSpeaker = null;
        if (searchKey(text) !== searchKey(service.sourceTitle)) {
          const prayerHeading = text.match(/^ΕΥΧΗ\s+(.+)$/u);
          const normalizedHeading = prayerHeading
            ? `Εὐχὴ ${prayerHeading[1]}`
            : (headingCorrections.get(searchKey(text)) ?? text);
          body.push(`@h:${normalizedHeading}`);
        }
        continue;
      }
      if (kind === "mode") {
        currentSpeaker = null;
        body.push(`@m:${text}`);
        continue;
      }
      if (["rubric", "mixed", "inaudible", "break"].includes(kind)) {
        currentSpeaker = null;
        if (/Εὐχολόγιον ἔχει ὡς ἔναρξιν/u.test(text)) continue;
        if (text === "_" || searchKey(text) === searchKey(service.sourceTitle)
            || searchKey(text) === "εσπερινοσ") continue;
        body.push(`@r:${text}`);
        continue;
      }
      if (kind === "chapverse") {
        body.push(`@h:${text}`);
        continue;
      }
      if (kind === "actor") {
        const actorMatch = text.match(/^([^:：]+)[:：]?\s*(.*)$/u);
        const speaker = actorMatch ? speakerFrom(actorMatch[1]) : null;
        if (!speaker) {
          unknownActors.add(text);
          currentSpeaker = null;
          body.push(`@r:${text}`);
          continue;
        }
        currentSpeaker = speaker;
        const dialogue = spokenText(actorMatch[2]);
        if (dialogue) body.push(`@s:${speaker}|${dialogue}`);
        continue;
      }

      const isContent = [
        "dialog", "dialogzero", "prayer", "prayerzero", "reading", "readingzero",
        "hymn", "chant", "verse", "greekmelody",
      ].includes(kind);
      if (!isContent) {
        body.push(text);
      } else if (/^\(\s*(?:Ἀμ[ήή]ν|Κ[ύύ]ριε,?\s*ἐλ[έέ]ησον|Σο[ίί],?\s*Κ[ύύ]ριε)/u.test(text)
          || (currentSpeaker === "Ἱερεύς" && /^(?:Ἀμ[ήή]ν|Κ[ύύ]ριε,?\s*ἐλ[έέ]ησον)/u.test(text))) {
        body.push(`@s:Χορός|${spokenText(text)}`);
      } else if (currentSpeaker) {
        body.push(`@s:${currentSpeaker}|${spokenText(text)}`);
      } else if (["hymn", "chant", "verse", "greekmelody"].includes(kind)) {
        body.push(`@s:Χορός|${spokenText(text)}`);
      } else {
        body.push(text);
      }
    }
  }

  if (unknownActors.size) {
    console.warn(`${service.id}: unrecognized actor labels: ${[...unknownActors].join(" | ")}`);
  }
  return body;
}

async function fetchText(url) {
  const response = await fetch(url, {
    headers: { "user-agent": "Klimax liturgical corpus importer/1.0" },
    signal: AbortSignal.timeout(60_000),
  });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  return response.text();
}

const imported = [];
async function importService(service, framework = []) {
  const html = await fetchText(service.sourceUrl);
  const extracted = parseGreekColumn(html, service);
  const body = framework.length ? [
      "@h:Σταθερὸ μέρος — Ἀρχὴ τῆς ἀκολουθίας",
      "@r:Τὰ σταθερὰ λειτουργικὰ κείμενα παρατίθενται κανονικά. Τὰ σημεῖα ποὺ ἀλλάζουν ἀνάλογα μὲ τὴν ἡμέρα, τὸν ἦχο καὶ τὴν περίοδο σημειώνονται ρητὰ ὡς μεταβαλλόμενα.",
      ...extracted,
      ...framework,
    ] : extracted;
  if (body.length < service.minimumParagraphs) {
    throw new Error(`${service.id}: extracted only ${body.length} paragraphs`);
  }
  if (!body.some((line) => line.startsWith("@s:Ἱερεύς|"))) {
    throw new Error(`${service.id}: no priest parts were recognized`);
  }
  if (body.some((line) => /\b(?:PRIEST|CHOIR|READER|THE SERVICE OF)\b/i.test(line))) {
    throw new Error(`${service.id}: English parallel-column content leaked into the Greek text`);
  }

  const result = {
    id: service.id,
    titleGreek: service.titleGreek,
    titleEnglish: service.titleEnglish,
    attribution: null,
    rubric: "Πλῆρες λειτουργικὸ κείμενο",
    status: "complete",
    source: service.bundledSource
      ?? "Μέγα Εὐχολόγιον, Βενετία 1862 · δημόσιος τομέας · διασταύρωση GOARCH Digital Chant Stand",
    sourceUrl: service.bundledSourceUrl ?? publicDomainSourceUrl,
    body,
  };
  console.log(`${service.id}: ${body.length} Greek paragraphs`);
  return result;
}

for (const service of services) {
  imported.push(await importService(service));
}

const category = {
  id: "mystiria",
  titleGreek: "Μυστήρια καὶ Ἱερὲς Ἀκολουθίες",
  titleEnglish: "Sacraments and Sacred Services",
  subtitle: "Βάπτισμα · Θεῖον Εὐχέλαιον · Νεκρώσιμος Ἀκολουθία",
  prayers: imported,
};
const existingIndex = data.categories.findIndex((item) => item.id === category.id);
if (existingIndex >= 0) {
  data.categories[existingIndex] = category;
} else {
  const psalterIndex = data.categories.findIndex((item) => item.id === "psaltirion");
  data.categories.splice(psalterIndex >= 0 ? psalterIndex : data.categories.length, 0, category);
}

const importedHorologion = [];
for (const service of horologionServices) {
  importedHorologion.push(await importService(service, service.framework));
}
const horologionIndex = data.categories.findIndex((item) => item.id === "orologion");
if (horologionIndex < 0) throw new Error("The orologion category is missing");
const replacedHorologionIDs = new Set(importedHorologion.map((item) => item.id));
const existingHorologion = data.categories[horologionIndex];
data.categories[horologionIndex] = {
  ...existingHorologion,
  subtitle: "Ἑσπερινός · Ὄρθρος · Μεσονυκτικὰ καὶ Ὧρες",
  prayers: [
    ...importedHorologion,
    ...existingHorologion.prayers.filter((item) => !replacedHorologionIDs.has(item.id)),
  ],
};

await writeFile(prayersPath, `${JSON.stringify(data, null, 2)}\n`, "utf8");
console.log(`Imported ${imported.length + importedHorologion.length} complete services into ${prayersPath}`);
