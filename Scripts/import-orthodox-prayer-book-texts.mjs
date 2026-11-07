#!/usr/bin/env node

import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const prayersPath = path.join(root, "Klimax", "prayers.json");
const data = JSON.parse(await readFile(prayersPath, "utf8"));

// These modern or unattributed works are deliberately not redistributed until
// explicit republication rights can be documented.
const excludedForRightsReview = new Set([
  "orthodox-prayer-book-paraklesis-agiou-demetriou",
  "orthodox-prayer-book-paraklesis-agiou-partheniou",
  "orthodox-prayer-book-xairetistirioi-oikoi-panagias-gorgoipikoou",
]);

// The separate "Stases" page duplicates the Akathist already stored once in
// the Salutations collection.
const excludedAsDuplicates = new Set([
  "orthodox-prayer-book-staseis-xairetismwn",
]);

const requiredSalutationServices = [
  {
    id: "orthodox-prayer-book-xairetismoi-1",
    titleGreek: "Ἀκολουθία τῶν Α΄ Χαιρετισμῶν",
    titleEnglish: "Service of the First Salutations",
    attribution: null,
    rubric: "Πλῆρες λειτουργικὸ κείμενο",
    status: "external",
    source: "Προσευχητάριον τοῦ Ὀρθοδόξου Χριστιανοῦ · παλαιὸ λειτουργικὸ κείμενο",
    sourceUrl: "https://orthodox-prayer-book.org/el/xairetismoi-1/",
    body: [],
  },
  {
    id: "orthodox-prayer-book-xairetismoi-2",
    titleGreek: "Ἀκολουθία τῶν Β΄ Χαιρετισμῶν",
    titleEnglish: "Service of the Second Salutations",
    attribution: null,
    rubric: "Πλῆρες λειτουργικὸ κείμενο",
    status: "external",
    source: "Προσευχητάριον τοῦ Ὀρθοδόξου Χριστιανοῦ · παλαιὸ λειτουργικὸ κείμενο",
    sourceUrl: "https://orthodox-prayer-book.org/el/xairetismoi-2/",
    body: [],
  },
  {
    id: "orthodox-prayer-book-xairetismoi-3",
    titleGreek: "Ἀκολουθία τῶν Γ΄ Χαιρετισμῶν",
    titleEnglish: "Service of the Third Salutations",
    attribution: null,
    rubric: "Πλῆρες λειτουργικὸ κείμενο",
    status: "external",
    source: "Προσευχητάριον τοῦ Ὀρθοδόξου Χριστιανοῦ · παλαιὸ λειτουργικὸ κείμενο",
    sourceUrl: "https://orthodox-prayer-book.org/el/xairetismoi-3/",
    body: [],
  },
  {
    id: "orthodox-prayer-book-xairetismoi-4",
    titleGreek: "Ἀκολουθία τῶν Δ΄ Χαιρετισμῶν",
    titleEnglish: "Service of the Fourth Salutations",
    attribution: null,
    rubric: "Πλῆρες λειτουργικὸ κείμενο",
    status: "external",
    source: "Προσευχητάριον τοῦ Ὀρθοδόξου Χριστιανοῦ · παλαιὸ λειτουργικὸ κείμενο",
    sourceUrl: "https://orthodox-prayer-book.org/el/xairetismoi-4/",
    body: [],
  },
];

const suppressedIDs = new Set([
  ...excludedForRightsReview,
  ...excludedAsDuplicates,
]);

const speakerPattern = /^(?:@r:)?\s*(?:Ὁ\s+)?(Ἱερε(?:ὺς|ύς|ῦς)|Ιερε(?:ὺς|ύς|ῦς)|Διάκονος|Χορός|Λαός|Ἀναγνώστης|Αναγνώστης|Ψάλτης|Ἱεροψάλτης|Ιεροψάλτης)\s*[:：]\s*(.+)$/u;
const responsePattern = /^(?:Ἀμ[ήή]ν|Αμήν|Κ[ύύ]ριε,?\s*ἐλ[έέ]ησον|Καὶ τῷ πνεύματί σου|Σοὶ,? Κύριε|Παράσχου,? Κύριε|Ἔχομεν πρὸς τὸν Κύριον|Ἄξιον καὶ δίκαιον)/u;
const shortHeadingPattern = /^(?:ΣΤΑΣΙΣ|ΣΤΑΣΗ|ΜΕΣΗ|ΨΑΛΜΟΣ|ΕΥΧΗ|Τρισ[άά]γιον|Τὸ Πιστε[ύύ]ω|Το Πιστε[ύύ]ω|Τροπ[άά]ρια|Καν[ὼώ]ν|Εὐαγγ[έέ]λιον|ΑΠΟΔΕΙΠΝΟΝ|ΒΑΣΙΛΕΩΣ)/iu;

function canonicalSpeaker(speaker) {
  if (/^(?:Ἱερε|Ιερε)/u.test(speaker)) return "Ἱερεύς";
  if (/^(?:Ἀναγ|Αναγ)/u.test(speaker)) return "Ἀναγνώστης";
  if (/Ψάλ|ροψάλ/u.test(speaker)) return "Χορός";
  return speaker;
}

function normalizeBody(body) {
  const normalized = [];
  for (const rawLine of body) {
    const line = rawLine
      .replaceAll("µ", "μ")
      .replaceAll("¨Υ", "Ὕ");
    if (line.startsWith("@s:")) {
      normalized.push(line);
      continue;
    }

    const spoken = line.match(speakerPattern);
    if (spoken) {
      normalized.push(`@s:${canonicalSpeaker(spoken[1])}|${spoken[2].trim()}`);
      continue;
    }

    const previous = normalized.at(-1);
    if (previous?.startsWith("@s:Ἱερεύς|") && responsePattern.test(line)) {
      normalized.push(`@s:Χορός|${line}`);
      continue;
    }

    if (!line.startsWith("@") && line.length < 140 &&
        (shortHeadingPattern.test(line) || isAllUpperText(line))) {
      normalized.push(`@h:${line}`);
      continue;
    }

    normalized.push(line);
  }
  return normalized;
}

function wordKey(word) {
  return word
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLocaleLowerCase("el-GR")
    .replaceAll("ς", "σ");
}

function lettersIn(value) {
  return value.match(/\p{L}/gu) ?? [];
}

function isAllUpperWord(word, minimumLetters = 2) {
  const letters = lettersIn(word);
  return letters.length >= minimumLetters
    && letters.every((letter) => letter !== letter.toLocaleLowerCase("el-GR"));
}

function isAllUpperText(value) {
  const letters = lettersIn(value);
  return letters.length >= 3
    && letters.every((letter) => letter !== letter.toLocaleLowerCase("el-GR"));
}

const capitalizationOverrides = new Map([
  ["ΕΙ", "εἰ"],
  ["ΟΝ", "ὃν"],
  ["ΣΟΙ", "σοὶ"],
  ["ΥΠΟΜΕΝΩΝ", "ὑπομένων"],
  ["ΕΞΗΡΕΥΞΑΤΟ", "ἐξηρεύξατο"],
  ["ΠΡΟΣΕΧΕΤΕ", "προσέχετε"],
  ["ΕΠΑΙΝΕΙ", "ἐπαίνει"],
  ["ΕΞΟΔOY", "ἐξόδῳ"],
]);

function buildAccentLexicon() {
  const counts = new Map();
  for (const prayer of data.categories.flatMap((category) => category.prayers)) {
    for (const line of prayer.body) {
      for (const match of line.matchAll(/[\p{L}\p{M}]+/gu)) {
        const word = match[0];
        if (isAllUpperWord(word, 1)) continue;
        const key = wordKey(word);
        const spellings = counts.get(key) ?? new Map();
        spellings.set(word, (spellings.get(word) ?? 0) + 1);
        counts.set(key, spellings);
      }
    }
  }

  return new Map([...counts].map(([key, spellings]) => [
    key,
    [...spellings].sort((left, right) => right[1] - left[1])[0][0],
  ]));
}

const accentLexicon = buildAccentLexicon();

function capitalized(word) {
  const characters = [...word.toLocaleLowerCase("el-GR").normalize("NFD")];
  if (!characters.length) return word;
  characters[0] = characters[0].toLocaleUpperCase("el-GR");
  return characters.join("").normalize("NFC");
}

function normalizedUpperWord(word, isFirstWord) {
  const preferred = capitalizationOverrides.get(word)
    ?? accentLexicon.get(wordKey(word))
    ?? word.toLocaleLowerCase("el-GR");
  return isFirstWord ? capitalized(preferred) : preferred;
}

function isGreekNumeral(word, followingCharacter) {
  return lettersIn(word).length <= 3 && ["'", "’", "΄", "ʹ"].includes(followingCharacter);
}

function normalizeAllUpperLine(text) {
  let wordIndex = 0;
  return text.replace(/[\p{L}\p{M}]+/gu, (word, offset, source) => {
    const followingCharacter = source[offset + word.length] ?? "";
    if (isGreekNumeral(word, followingCharacter)) return word;
    const normalized = normalizedUpperWord(word, wordIndex === 0);
    wordIndex += 1;
    return normalized;
  });
}

function normalizeLeadingUppercaseWords(text) {
  let cursor = 0;
  let wordIndex = 0;
  let output = "";

  for (const match of text.matchAll(/[\p{L}\p{M}]+/gu)) {
    const between = text.slice(cursor, match.index);
    if (wordIndex === 0 && match.index !== 0) break;
    if (wordIndex > 0 && !/^[\s,;··]*$/u.test(between)) break;

    const word = match[0];
    const followingCharacter = text[match.index + word.length] ?? "";
    if (!isAllUpperWord(word, 1) || isGreekNumeral(word, followingCharacter)) break;

    output += between + normalizedUpperWord(word, wordIndex === 0);
    cursor = match.index + word.length;
    wordIndex += 1;
  }

  return wordIndex > 0 ? output + text.slice(cursor) : text;
}

function normalizeKnownFirstWord(text) {
  const match = text.match(/^[\p{L}\p{M}]+/u);
  if (!match) return text;
  const word = match[0];
  const uppercaseKey = word.toLocaleUpperCase("el-GR");
  const preferred = capitalizationOverrides.get(uppercaseKey)
    ?? accentLexicon.get(wordKey(word));
  if (!preferred) return text;
  return capitalized(preferred) + text.slice(word.length);
}

function normalizeCapitalization(prayer, body) {
  return body.map((line, index) => {
    let prefix = "";
    let text = line;

    if (line.startsWith("@s:")) {
      const separator = line.indexOf("|");
      if (separator < 0) return line;
      prefix = line.slice(0, separator + 1);
      text = line.slice(separator + 1);
    } else if (/^@[hmr]:/u.test(line)) {
      prefix = line.slice(0, 3);
      text = line.slice(3);
    }

    let normalizedText = isAllUpperText(text)
      ? normalizeAllUpperLine(text)
      : normalizeLeadingUppercaseWords(text);

    if (prefix === "@h:") {
      const colonIndex = normalizedText.indexOf(":");
      if (colonIndex >= 0) {
        const headingLead = normalizedText.slice(0, colonIndex + 1);
        const headingTail = normalizedText.slice(colonIndex + 1);
        if (isAllUpperText(headingTail)) {
          normalizedText = `${headingLead}${normalizeAllUpperLine(headingTail)}`;
        }
      }
    }

    const followsPsalmHeading = prayer.id.startsWith("orthodox-prayer-book-psaltirion-")
      && body[index - 1]?.startsWith("@h:Ψαλ");
    if (prefix === "@h:" || followsPsalmHeading) {
      normalizedText = normalizeKnownFirstWord(normalizedText);
    }

    return prefix + normalizedText;
  });
}

let removedForRightsReview = 0;
let removedAsDuplicates = 0;
let updatedMetadata = false;

const salutationsCategory = data.categories.find((category) => category.id === "theotokos");
if (!salutationsCategory) {
  throw new Error("Missing theotokos category for the Salutations services");
}
for (const service of requiredSalutationServices) {
  const existingService = salutationsCategory.prayers.find((prayer) => prayer.id === service.id);
  if (!existingService) {
    salutationsCategory.prayers.push(service);
    updatedMetadata = true;
  } else if (existingService.body.slice(0, 8).some((line) => /Χαιρετισμων/iu.test(line))) {
    // Re-import older copies that accidentally retained the page navigation.
    existingService.body = [];
    existingService.status = "external";
    updatedMetadata = true;
  }
}

for (const category of data.categories) {
  const previousIDs = new Set(category.prayers.map((prayer) => prayer.id));
  category.prayers = category.prayers.filter(
    (prayer) => !suppressedIDs.has(prayer.id),
  );
  const removedRights = [...excludedForRightsReview].filter((id) => previousIDs.has(id)).length;
  const removedDuplicates = [...excludedAsDuplicates].filter((id) => previousIDs.has(id)).length;
  removedForRightsReview += removedRights;
  removedAsDuplicates += removedDuplicates;
  if (removedRights > 0 || removedDuplicates > 0) {
    updatedMetadata = true;
  }

  for (const prayer of category.prayers) {
    if (prayer.attribution === "orthodox-prayer-book.org") {
      prayer.attribution = null;
      updatedMetadata = true;
    }
    const normalizedBody = normalizeCapitalization(prayer, normalizeBody(prayer.body));
    if (normalizedBody.some((line, index) => line !== prayer.body[index])) {
      prayer.body = normalizedBody;
      updatedMetadata = true;
    }
  }

  if (category.id === "akolouthiai") {
    const subtitle = "Μικρὸν καὶ Μέγα Ἀπόδειπνον";
    if (category.subtitle !== subtitle) updatedMetadata = true;
    category.subtitle = subtitle;
  }
  if (category.id === "theotokos") {
    const subtitle = "Α΄–Δ΄ Χαιρετισμοὶ καὶ Ἀκάθιστος Ὕμνος";
    if (category.subtitle !== subtitle) updatedMetadata = true;
    category.subtitle = subtitle;
  }
  if (category.id === "psaltirion") {
    const subtitle = "Κ΄ Καθίσματα · Κείμενον τῶν Ἑβδομήκοντα (Ο΄)";
    if (category.subtitle !== subtitle) updatedMetadata = true;
    category.subtitle = subtitle;
  }
}

const targets = data.categories
  .flatMap((category) => category.prayers)
  .filter((prayer) => prayer.status === "external" && prayer.sourceUrl);

if (targets.length === 0) {
  if (removedForRightsReview > 0 || updatedMetadata) {
    await writeFile(prayersPath, `${JSON.stringify(data, null, 2)}\n`, "utf8");
  }
  console.log(
    `No external prayer texts remain to import. Corpus metadata and liturgical styling are current.`,
  );
  process.exit(0);
}

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

function searchKey(value) {
  return value
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLocaleLowerCase("el-GR")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
}

function visibleLines(html) {
  const body = html.match(/<body\b[^>]*>([\s\S]*?)<\/body>/i)?.[1] ?? html;
  const withoutHiddenPayloads = body
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, "")
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, "")
    .replace(/<svg\b[^>]*>[\s\S]*?<\/svg>/gi, "")
    .replace(/<noscript\b[^>]*>[\s\S]*?<\/noscript>/gi, "");
  const withBreaks = withoutHiddenPayloads
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(?:h[1-6]|p|div|li|section|article|main|header|footer|nav)>/gi, "\n")
    .replace(/<(?:h[1-6]|p|div|li|section|article|main|header|footer|nav)\b[^>]*>/gi, "\n");
  const text = decodeEntities(withBreaks.replace(/<[^>]+>/g, " "));
  return text
    .split(/\r?\n/)
    .map((line) => line.replace(/\s+/g, " ").trim())
    .filter(Boolean);
}

function extractedBody(prayer, html) {
  let lines = visibleLines(html);
  const titleKey = searchKey(prayer.titleGreek);
  const titleIndexes = lines
    .map((line, index) => searchKey(line) === titleKey ? index : -1)
    .filter((index) => index >= 0);
  if (titleIndexes.length) {
    lines = lines.slice(titleIndexes[Math.min(1, titleIndexes.length - 1)] + 1);
  }

  const footerIndex = lines.findIndex((line) =>
    line.includes("orthodox-holy-scripture.org") ||
    line.includes("orthodoxprayerbookorg at gmail.com")
  );
  if (footerIndex >= 0) lines = lines.slice(0, footerIndex);

  lines = lines.filter((line) =>
    !["Προηγούμενο", "Επόμενο", "Προηγούμενο Επόμενο", "\\"].includes(line)
  );

  const navigationLabels = new Set([
    "Μικρόν Απόδειπνον", "Μέγα Απόδειπνον", "Στάσεις Χαιρετισμών",
    "Α΄ ΧΑΙΡΕΤΙΣΜΩΝ", "Β΄ ΧΑΙΡΕΤΙΣΜΩΝ", "Γ' ΧΑΙΡΕΤΙΣΜΩΝ",
    "Δ' ΧΑΙΡΕΤΙΣΜΩΝ", "ΑΚΑΘΙΣΤΟΣ ΥΜΝΟΣ", "ΕΙΣ ΤΟ ΑΠΟΔΕΙΠΝΟΝ",
    "ΤΗ ΕΠΑΥΡΙΟΝ", "ΕΥΧΑΡΙΣΤΙΑ ΜΕΤΑ ΤΗ ΘΕΙΑ ΜΕΤΑΛΗΨΗ",
  ].map(searchKey));
  while (navigationLabels.has(searchKey(lines[0] ?? ""))) lines.shift();

  if (prayer.id === "orthodox-prayer-book-paraklesis-agiou-partheniou") {
    const serviceStart = lines.findIndex((line) => /^Ἱερε[ὺύ]ς:/u.test(line));
    if (serviceStart >= 0) lines = lines.slice(serviceStart);
  }

  if (prayer.id.startsWith("orthodox-prayer-book-psaltirion-")) {
    const firstPsalm = lines.findIndex((line) => /^Ψαλμ[ὸό]ς\s/u.test(line));
    if (firstPsalm >= 0) lines = lines.slice(firstPsalm);
  }

  const headingPatterns = [
    /^Ψαλμ[ὸό]ς\s/u, /^ΚΑΘΙΣΜΑ\s/u, /^Κάθισμα\s/u, /^Στάσις\s/u,
    /^ᾨδ[ὴή]\s/u, /^Ωδή\s/u, /^Κοντ[άά]κιον/u, /^Οἶκος\s/u,
    /^Θεοτοκ[ίί]ον/u, /^Ἀπολυτ[ίί]κιον/u, /^Απολυτ[ίί]κιον/u,
    /^Εὐχ[ὴή]/u, /^Ευχ[ήὴ]/u, /^Ἑσπέρας/u, /^Πρωΐ/u,
  ];
  const modePattern = /^(?:Ἦχος|Ήχος|Αὐτ[όό]μελον)/u;
  const rubricPattern = /^(?:Ἱερε[ὺύ]ς|Ιερε[ύὺ]ς|Διάκονος|Χορός|Στίχ(?:ος)?|Εἶτα|Είτα|Καὶ εὐθὺς|Καί ευθύς)/u;

  return normalizeCapitalization(prayer, normalizeBody(lines.map((rawLine) => {
    const line = rawLine
      .replaceAll("¨„δῃ", "ᾅδῃ")
      .replaceAll("μιμνῃ£σκῃ", "μιμνῄσκῃ")
      .replaceAll("κατῃ£σχυνας", "κατῄσχυνας");
    if (headingPatterns.some((pattern) => pattern.test(line)) && line.length < 140) return `@h:${line}`;
    if (modePattern.test(line) && line.length < 140) return `@m:${line}`;
    if (rubricPattern.test(line) && line.length < 220) return `@r:${line}`;
    return line;
  })));
}

async function fetchWithRetry(url, attempts = 3) {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await fetch(url, {
        headers: { "user-agent": "Klimax prayer corpus importer/1.0" },
        signal: AbortSignal.timeout(45_000),
      });
      if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
      return await response.text();
    } catch (error) {
      lastError = error;
      if (attempt < attempts) await new Promise((resolve) => setTimeout(resolve, attempt * 750));
    }
  }
  throw lastError;
}

let nextIndex = 0;
const failures = [];
async function worker() {
  while (true) {
    const index = nextIndex;
    nextIndex += 1;
    if (index >= targets.length) return;
    const prayer = targets[index];
    try {
      const html = await fetchWithRetry(prayer.sourceUrl);
      const body = extractedBody(prayer, html);
      if (body.length < 5) throw new Error(`only ${body.length} extracted paragraphs`);
      prayer.body = body;
      prayer.status = "complete";
      prayer.rubric = prayer.id.includes("psaltirion-")
        ? "Κείμενον τῶν Ἑβδομήκοντα (Ο΄)"
        : "Πλῆρες λειτουργικὸ κείμενο";
      prayer.source = prayer.id.includes("psaltirion-")
        ? "Ψαλτήριον τῶν Ἑβδομήκοντα (Ο΄) · δημόσιος τομέας · διασταύρωση Brenton 1851 / eBible.org"
        : "Προσευχητάριον τοῦ Ὀρθοδόξου Χριστιανοῦ · παλαιὸ λειτουργικὸ κείμενο";
      console.log(`[${index + 1}/${targets.length}] ${prayer.id}: ${body.length} paragraphs`);
    } catch (error) {
      failures.push(`${prayer.id}: ${error.message}`);
      console.error(`[${index + 1}/${targets.length}] FAILED ${prayer.id}: ${error.message}`);
    }
  }
}

await Promise.all(Array.from({ length: 4 }, () => worker()));

if (failures.length) {
  console.error(`\nImport failed for ${failures.length} texts:\n${failures.join("\n")}`);
  process.exit(1);
}

await writeFile(prayersPath, `${JSON.stringify(data, null, 2)}\n`, "utf8");
console.log(
  `\nImported ${targets.length} complete offline texts into ${prayersPath}; ` +
  `removed ${removedForRightsReview} text(s) pending rights review and ` +
  `${removedAsDuplicates} duplicate text(s).`,
);
