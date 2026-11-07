#!/usr/bin/env node

import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const calendarPath = path.join(root, "Klimax", "LiturgicalData", "kanonion-2026.json");
const outputPath = path.join(root, "Klimax", "LiturgicalData", "sunday-offices-2026.json");
const sundayCalendar = JSON.parse(await readFile(calendarPath, "utf8"));
const sundayByDate = new Map(sundayCalendar.map((entry) => [entry.date, entry]));

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
  return value.normalize("NFD").replace(/\p{M}/gu, "")
    .toLocaleLowerCase("el-GR").replaceAll("ς", "σ")
    .replace(/[^\p{L}\p{N}]+/gu, " ").trim();
}

function speakerFrom(label) {
  const key = searchKey(label);
  if (key.startsWith("ιερευσ")) return "Ἱερεύς";
  if (key.startsWith("αρχιερευσ") || key.startsWith("επισκοποσ")) return "Ἀρχιερεύς";
  if (key.startsWith("διακονοσ")) return "Διάκονος";
  if (key.startsWith("χοροσ") || key.startsWith("ψαλτησ")
      || key.includes("χοροσ") || key === "κληροσ" || key === "κληροσ και λαοσ") return "Χορός";
  if (key.startsWith("λαοσ")) return "Λαός";
  if (key.startsWith("αναγνωστησ")) return "Ἀναγνώστης";
  return null;
}

function withoutResponseParentheses(value) {
  const trimmed = value.trim();
  const wrapped = trimmed.match(/^\(\s*([\s\S]*?)\s*\)$/u);
  return (wrapped?.[1] ?? trimmed).trim();
}

function normalizedHeading(text) {
  const prayerHeading = text.match(/^ΕΥΧΗ\s+(.+)$/u);
  if (prayerHeading) return normalizedHeading(`Εὐχὴ ${prayerHeading[1]}`);
  const letters = [...text].filter((character) => /\p{L}/u.test(character));
  if (letters.length >= 4 && letters.every((character) => character === character.toLocaleUpperCase("el-GR"))) {
    const lower = text.toLocaleLowerCase("el-GR");
    return lower.charAt(0).toLocaleUpperCase("el-GR") + lower.slice(1);
  }
  return text;
}

function parseGreekColumn(html) {
  const body = [];
  let currentSpeaker = null;
  const leftCells = [...html.matchAll(/<td\s+class=['"]leftCell['"][^>]*>([\s\S]*?)<\/td>/gi)];

  for (const cell of leftCells) {
    const paragraphs = [...cell[1].matchAll(/<p\s+class=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/p>/gi)];
    for (const paragraph of paragraphs) {
      const kind = paragraph[1].toLowerCase();
      const text = visibleText(paragraph[2]).replace(/\bN(?=ʹ)/gu, "Ν");
      if (!text) continue;
      if (/[A-Za-z]{4}/u.test(text) && !/[\u0370-\u03ff\u1f00-\u1fff]/u.test(text)) continue;

      if (["servicesourcestitle", "servicesources", "servicesourcessection", "source", "source0"]
          .includes(kind) || /^(?:b|e)(?:r|m)c_/u.test(kind) || /^bkmrk/u.test(kind)) {
        continue;
      }

      // Some service pages expose actor changes as plain/rubric paragraphs.
      // Treat a standalone role label as state, never as visible prayer text.
      const standaloneRole = /^(?:ΑΡΧΙ)?ΙΕΡΕΥΣ|^ΔΙΑΚΟΝΟΣ|^ΑΝΑΓΝΩΣΤΗΣ|^(?:ΔΕΞΙΟΣ |ΑΡΙΣΤΕΡΟΣ )?ΧΟΡΟΣ|^ΚΛΗΡΟΣ(?: ΚΑΙ ΛΑΟΣ)?/u.test(text)
        ? speakerFrom(text)
        : null;
      if (standaloneRole && !text.includes(":")) {
        currentSpeaker = standaloneRole;
        continue;
      }

      if (kind === "dialogwithactor") {
        const match = text.match(/^([^:：]+)[:：]\s*(.*)$/u);
        const speaker = match ? speakerFrom(match[1]) : null;
        const dialogue = withoutResponseParentheses(match?.[2] ?? "");
        if (speaker && dialogue) body.push(`@s:${speaker}|${dialogue}`);
        else body.push(text);
        currentSpeaker = null;
        continue;
      }

      if (kind === "designation" || kind === "chapverse") {
        currentSpeaker = null;
        body.push(`@h:${normalizedHeading(text)}`);
        continue;
      }
      if (kind === "mode") {
        currentSpeaker = null;
        body.push(`@m:${text}`);
        continue;
      }
      if (["rubric", "mixed", "break"].includes(kind)) {
        currentSpeaker = null;
        if (/^_+$/u.test(text) || ["ορθροσ", "εσπερινοσ"].includes(searchKey(text))) continue;
        body.push(`@r:${normalizedHeading(text)}`);
        continue;
      }
      if (kind === "actor") {
        const match = text.match(/^([^:：]+)[:：]?\s*(.*)$/u);
        const speaker = match ? speakerFrom(match[1]) : null;
        currentSpeaker = speaker;
        const dialogue = withoutResponseParentheses(match?.[2] ?? "");
        if (speaker && dialogue) body.push(`@s:${speaker}|${dialogue}`);
        else if (!speaker) body.push(`@r:${text}`);
        continue;
      }
      if (kind === "inaudible") {
        body.push(currentSpeaker ? `@s:${currentSpeaker}|${text}` : `@r:${text}`);
        continue;
      }

      const isContent = [
        "dialog", "dialogzero", "prayer", "prayerzero", "reading", "readingzero",
        "hymn", "chant", "verse", "greekmelody",
      ].includes(kind);
      if (!isContent) {
        const heading = normalizedHeading(text);
        body.push(heading === text ? text : `@h:${heading}`);
      } else if (/^\(\s*(?:Ἀμ[ήή]ν|Κ[ύύ]ριε,?\s*ἐλ[έέ]ησον|Σο[ίί],?\s*Κ[ύύ]ριε)/u.test(text)
          || (currentSpeaker === "Ἱερεύς" && /^(?:Ἀμ[ήή]ν|Κ[ύύ]ριε,?\s*ἐλ[έέ]ησον)/u.test(text))) {
        body.push(`@s:Χορός|${withoutResponseParentheses(text)}`);
      } else if (currentSpeaker) {
        body.push(`@s:${currentSpeaker}|${withoutResponseParentheses(text)}`);
      } else if (["hymn", "chant", "verse", "greekmelody"].includes(kind)) {
        body.push(`@s:Χορός|${withoutResponseParentheses(text)}`);
      } else {
        body.push(text);
      }
    }
  }
  return body;
}

async function fetchText(url) {
  const response = await fetch(url, {
    headers: { "user-agent": "Klimax liturgical corpus importer/1.0" },
    signal: AbortSignal.timeout(90_000),
  });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}: ${url}`);
  return response.text();
}

async function fetchFirst(urls) {
  let lastError;
  for (const url of urls) {
    try { return await fetchText(url); }
    catch (error) { lastError = error; }
  }
  throw lastError;
}

function allDates(year) {
  const dates = [];
  const date = new Date(`${year}-01-01T12:00:00Z`);
  while (date.getUTCFullYear() === year) {
    dates.push(date.toISOString().slice(0, 10));
    date.setUTCDate(date.getUTCDate() + 1);
  }
  return dates;
}

function servicesFromIndex(html) {
  const services = [];
  let title = "";
  const pattern = /<span class='index-service-day'>([^<]+)<\/span>|href="(h\/s\/\d{4}\/\d{2}\/\d{2}\/([^/]+)\/gr-en\/index\.html)"/g;
  for (const match of html.matchAll(pattern)) {
    if (match[1]) title = decodeEntities(match[1]).trim();
    else services.push({ title, code: match[3], path: match[2] });
  }
  return services;
}

async function dailyIndex(dateString) {
  const compact = dateString.replaceAll("-", "");
  const html = await fetchText(`https://digitalchantstand.goarch.org/goa/dcs/indexes/${compact}.html`);
  return servicesFromIndex(html);
}

function chooseService(services, priorities) {
  for (const code of priorities) {
    const service = services.find((candidate) => candidate.code === code);
    if (service) return service;
  }
  return null;
}

function previousDay(dateString) {
  const date = new Date(`${dateString}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() - 1);
  return date.toISOString().slice(0, 10);
}

function dcsUrl(dateString, code) {
  return `https://digitalchantstand.goarch.org/goa/dcs/h/s/${dateString.replaceAll("-", "/")}/${code}/gr-en/index.html`;
}

async function importEntry(date) {
  const previousDate = previousDay(date);
  const [todayServices, previousServices] = await Promise.all([
    dailyIndex(date), date === "2026-01-01" ? Promise.resolve([]) : dailyIndex(previousDate),
  ]);
  let vespersService = chooseService(todayServices,
    ["vl2", "vl", "pl1", "ve2", "ve", "co7"]);
  let orthrosService = chooseService(todayServices, ["em3", "em", "ma3", "ma"]);
  let orthrosServiceDate = date;
  if (!orthrosService) {
    orthrosService = chooseService(previousServices, ["em3", "em"]);
    orthrosServiceDate = previousDate;
  }
  if (!vespersService && date === "2026-12-31") {
    vespersService = { code: "ordinary", title: "Vespers — fixed core", path: null };
  }
  if (!vespersService || !orthrosService) {
    throw new Error(`${date}: service mapping missing (vespers ${vespersService?.code ?? "—"}, orthros ${orthrosService?.code ?? "—"})`);
  }

  const [orthrosHTML, vespersHTML] = await Promise.all([
    fetchText(`https://digitalchantstand.goarch.org/goa/dcs/${orthrosService.path}`),
    vespersService.path
      ? fetchText(`https://digitalchantstand.goarch.org/goa/dcs/${vespersService.path}`)
      : Promise.resolve(null),
  ]);
  const variableOrthros = parseGreekColumn(orthrosHTML);
  const containsFixedOpening = variableOrthros.slice(0, 140).some((line) => {
    const key = searchKey(line);
    return key.includes("αρχη του ορθρου") || key.includes("ο εξαψαλμοσ");
  });
  const orthros = containsFixedOpening ? variableOrthros : [...fixedOrthros, ...variableOrthros];
  const vespers = vespersHTML ? parseGreekColumn(vespersHTML) : fixedVespers;
  if (orthros.length < 100 || vespers.length < (vespersService.code === "ordinary" ? 35 : 150)) {
    throw new Error(`${date}: incomplete extraction (vespers ${vespers.length}, orthros ${orthros.length})`);
  }
  for (const [name, body] of [["vespers", vespers], ["orthros", orthros]]) {
    if (body.some((line) => /^@s:[^|]+\|\s*\(/u.test(line) && /\)\s*$/u.test(line))) {
      throw new Error(`${date}: parenthesized ${name} response remained`);
    }
    const englishLeak = body.find((line) => /\b(?:PRIEST|CHOIR|READER|THE SERVICE OF)\b/i.test(line));
    if (englishLeak) {
      throw new Error(`${date}: English content leaked into ${name}: ${englishLeak}`);
    }
  }
  const calendarEntry = sundayByDate.get(date);
  return {
    date,
    echos: calendarEntry?.echos ?? null,
    eothinon: calendarEntry?.eothinon ?? null,
    vespers: { code: vespersService.code, source_date: date, title: vespersService.title, body: vespers },
    orthros: { code: orthrosService.code, source_date: orthrosServiceDate, title: orthrosService.title, body: orthros },
  };
}

const concurrency = 6;
const [fixedOrthros, fixedVespers] = (await Promise.all([
  fetchText("https://digitalchantstand.goarch.org/goa/dcs/h/b/matinsordinary/normal/gr-en/index.html"),
  fetchText("https://digitalchantstand.goarch.org/goa/dcs/h/b/vespersordinary/normal/gr-en/index.html"),
])).map(parseGreekColumn);
if (fixedOrthros.length < 120) throw new Error(`Incomplete fixed Orthros: ${fixedOrthros.length}`);
if (fixedVespers.length < 35) throw new Error(`Incomplete fixed Vespers: ${fixedVespers.length}`);
const dates = allDates(2026);
const entries = new Array(dates.length);
let cursor = 0;
async function worker() {
  while (true) {
    const index = cursor++;
    if (index >= dates.length) return;
    entries[index] = await importEntry(dates[index]);
    console.log(`[${index + 1}/${dates.length}] ${dates[index]}: `
      + `${entries[index].vespers.body.length} / ${entries[index].orthros.body.length}`);
  }
}
await Promise.all(Array.from({ length: concurrency }, worker));

// Store each distinct paragraph once. The fixed liturgical core repeats daily,
// so this keeps the complete offline year compact without losing any text.
const strings = [];
const stringIDs = new Map();
function intern(value) {
  if (!stringIDs.has(value)) {
    stringIDs.set(value, strings.length);
    strings.push(value);
  }
  return stringIDs.get(value);
}
for (const entry of entries) {
  entry.vespers.body = entry.vespers.body.map(intern);
  entry.orthros.body = entry.orthros.body.map(intern);
}

const output = {
  schema_version: 2,
  year: 2026,
  jurisdiction: "Τάξις Μεγάλης τοῦ Χριστοῦ Ἐκκλησίας",
  basis: [
    "Ὡρολόγιον τὸ Μέγα, Βενετία 1851 (δημόσιος τομέας)",
    "Παρακλητικὴ ἤτοι Ὀκτώηχος ἡ Μεγάλη, 1858 (δημόσιος τομέας)",
    "Παλαιὲς ἐκδόσεις Μηναίων, Τριῳδίου καὶ Πεντηκοσταρίου (δημόσιος τομέας)",
  ],
  verification: [
    "Τυπικὸν τῆς Μεγάλης τοῦ Χριστοῦ Ἐκκλησίας 2026",
    "GOARCH Digital Chant Stand — Greek service order",
  ],
  strings,
  entries,
};
await writeFile(outputPath, `${JSON.stringify(output, null, 2)}\n`, "utf8");
console.log(`Wrote ${entries.length} assembled daily offices and ${strings.length} unique paragraphs to ${outputPath}`);
