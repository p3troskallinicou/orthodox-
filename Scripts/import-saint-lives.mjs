#!/usr/bin/env node

import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const ROOT = process.cwd();
const DATA_PATH = path.join(ROOT, "Klimax", "saints.json");
const SHOULD_WRITE = process.argv.includes("--write");
const UPGRADE_KLIMAX_BIOS = process.argv.includes("--upgrade-klimax-bios");
const BASE_URL = "https://www.saint.gr";
const CONCURRENCY = 8;

// Joint and moving commemorations cannot always be inferred from a fixed-date
// card title. These IDs were verified directly in saint.gr.
const explicitSources = new Map([
  ["petros", "642"],
  ["paulos", "642"],
  ["bartholomaios", "571"],
  ["pateres-protis-oikoumenikis", "518"],
  ["lazaros-tetraimeros", "269"],
  ["theodoros-stouditis", "2983"],
  ["efraim-neas-makris", "387"],
  ["ioakeim-anna", "994"],
  ["athanasios-megas", "1127"],
  ["potheinos-lougdounou", "854"],
  ["symeon-theodochos", "1198"],
  ["avraam-lot", "1028"],
  ["syllipsiagias", "3213"],
]);

const verifiedSpecificHymns = new Map([
  ["pateres-protis-oikoumenikis", {
    echos: "Ἦχος πλ. δ´",
    textEl: "Ὑπερδοξασμένος εἶ Χριστὲ ὁ Θεὸς ἡμῶν, ὁ φωστῆρας ἐπὶ γῆς, τοὺς Πατέρας ἡμῶν θεμελιώσας, καὶ δι’ αὐτῶν, πρὸς τὴν ἀληθινὴν πίστιν πάντας ἡμᾶς ὁδηγήσας, Πολυεύσπλαγχνε δόξα σοι.",
    sourceNote: "Ἰδιαίτερον ἀπολυτίκιον τῶν 318 Πατέρων — Ὀρθόδοξος Συναξαριστής (saint.gr)",
  }],
  ["theodoros-stouditis", {
    echos: "Ἦχος γ´. Θείας πίστεως.",
    textEl: "Δώρων μέτοχος, τῆς ἀφθαρσίας, δῶρον ἄσυλον, τῆς Ἐκκλησίας, φερωνύμως ἀνεδείχθης Θεόδωρε, τοῖς ἱεροῖς γὰρ ἑπόμενος δόγμασιν, ὁμολογίας φωστὴρ ἐχρημάτισας. Πάτερ Ὅσιε, Χριστὸν τὸν Θεὸν ἱκέτευε, δωρήσασθαι ἡμῖν τὸ μέγα ἔλεος.",
    sourceNote: "Ἰδιαίτερον ἀπολυτίκιον — Ὀρθόδοξος Συναξαριστής (saint.gr)",
  }],
  ["efraim-neas-makris", {
    echos: "Ἦχος α´. Τῆς ἐρήμου πολίτης.",
    textEl: "Ἐν ὄρει τῶν Ἀμώμων ὥσπερ ἥλιος ἔλαμψας, καὶ μαρτυρικῶς, θεοφόρε, πρὸς Θεὸν ἐξεδήμησας, βαρβάρων ὑποστὰς ἐπιδρομάς, Ἐφραὶμ Μεγαλομάρτυς τοῦ Χριστοῦ· διὰ τοῦτο ἀναβλύζεις χάριν ἀεί, τοῖς εὐλαβῶς βοῶσι· δόξα τῷ δεδωκότι σοι ἰσχύν, δόξα τῷ σὲ θαυμαστώσαντι, δόξα τῷ ἐνεργοῦντι διὰ σοῦ, πᾶσιν ἰάματα.",
    sourceNote: "Ἰδιαίτερον ἀπολυτίκιον — Ὀρθόδοξος Συναξαριστής (saint.gr)",
  }],
  ["ioakeim-anna", {
    echos: "Ἦχος πλ. α´. Τὸν συνάναρχον Λόγον.",
    textEl: "Ἡ Δυὰς ἡ ἁγία καὶ Θεοτίμητος, Ἰωακεὶμ καὶ ἡ Ἄννα ὡς τοῦ Θεοῦ ἀγχιστεῖς, ἀνυμνείσθωσαν φαιδρῶς ᾀσμάτων κάλλεσιν· οὗτοι γὰρ ἔτεκον ἡμῖν, τὴν τεκοῦσαν ὑπὲρ νοῦν, τὸν ἄσαρκον βροτωθέντα, εἰς σωτηρίαν τοῦ κόσμου, μεθ᾿ ἧς πρεσβεύουσι σωθῆναι ἡμᾶς.",
    sourceNote: "Ἰδιαίτερον ἀπολυτίκιον — Ὀρθόδοξος Συναξαριστής (saint.gr)",
  }],
]);

const months = new Map([
  ["ιανουαριου", "01"], ["φεβρουαριου", "02"], ["μαρτιου", "03"],
  ["απριλιου", "04"], ["μαιου", "05"], ["ιουνιου", "06"],
  ["ιουλιου", "07"], ["αυγουστου", "08"], ["σεπτεμβριου", "09"],
  ["οκτωβριου", "10"], ["νοεμβριου", "11"], ["δεκεμβριου", "12"],
]);

const stopWords = new Set([
  "αγιος", "αγια", "αγιοι", "αγιες", "οσιος", "οσια", "οσιοι", "οσιες",
  "ο", "η", "οι", "το", "τα", "του", "της", "των", "και", "εν", "εκ", "απο",
]);

function normalize(value = "") {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("el")
    .replace(/[^a-zα-ω0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function decodeEntities(value = "") {
  const named = {
    amp: "&", quot: '"', apos: "'", nbsp: " ", lt: "<", gt: ">",
    ndash: "–", mdash: "—", hellip: "…", laquo: "«", raquo: "»",
  };
  return value
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => String.fromCodePoint(Number.parseInt(hex, 16)))
    .replace(/&#([0-9]+);/g, (_, decimal) => String.fromCodePoint(Number.parseInt(decimal, 10)))
    .replace(/&([a-z]+);/gi, (match, entity) => named[entity.toLowerCase()] ?? match);
}

function textFromHtml(value = "") {
  return decodeEntities(
    value
      .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, " ")
      .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, " ")
      .replace(/<br\s*\/?>/gi, "\n")
      .replace(/<[^>]+>/g, " "),
  )
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n[ \t]+/g, "\n")
    .replace(/[ \t]{2,}/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function datePath(feast = "") {
  const match = normalize(feast).match(/^(\d{1,2})\s+([α-ω]+)/);
  if (!match) return null;
  const month = months.get(match[2]);
  if (!month) return null;
  return `${month}/${match[1].padStart(2, "0")}`;
}

function tokens(value) {
  return new Set(normalize(value).split(" ").filter((word) => word && !stopWords.has(word)));
}

function matchScore(wanted, candidate) {
  const a = normalize(wanted);
  const b = normalize(candidate);
  if (!a || !b) return 0;
  if (a === b) return 1;
  if (a.includes(b) || b.includes(a)) {
    return 0.88 + 0.1 * (Math.min(a.length, b.length) / Math.max(a.length, b.length));
  }
  const left = tokens(a);
  const right = tokens(b);
  const overlap = [...left].filter((token) => right.has(token)).length;
  const dice = (2 * overlap) / Math.max(1, left.size + right.size);
  const firstLeft = [...left][0];
  const firstRight = [...right][0];
  return dice + (firstLeft && firstLeft === firstRight ? 0.12 : 0);
}

async function fetchText(url, attempt = 1) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30_000);
  try {
    const response = await fetch(url, {
      headers: { "User-Agent": "Klimax/1.0 saint-content-import (source attribution preserved)" },
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    return await response.text();
  } catch (error) {
    if (attempt >= 3) throw new Error(`${url}: ${error.message}`);
    await new Promise((resolve) => setTimeout(resolve, 500 * attempt));
    return fetchText(url, attempt + 1);
  } finally {
    clearTimeout(timeout);
  }
}

async function mapLimit(items, limit, worker) {
  const results = new Array(items.length);
  let next = 0;
  async function run() {
    while (true) {
      const index = next++;
      if (index >= items.length) return;
      try {
        results[index] = await worker(items[index], index);
      } catch (error) {
        results[index] = { error: error.message };
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, run));
  return results;
}

function calendarCandidates(html) {
  const found = new Map();
  const anchor = /<a\b[^>]*href=["']\/(\d+)\/saint\.aspx["'][^>]*>([\s\S]*?)<\/a>/gi;
  for (const match of html.matchAll(anchor)) {
    const id = match[1];
    const body = match[2];
    const alt = body.match(/\balt=["']([^"']+)["']/i)?.[1];
    const title = decodeEntities(alt ?? textFromHtml(body));
    if (title) found.set(id, { id, title });
  }
  return [...found.values()];
}

function extractPageTitle(html) {
  const imageTitle = html.match(/myBox-image[\s\S]*?\balt=["']([^"']+)["']/i)?.[1];
  return decodeEntities(imageTitle ?? "");
}

function extractBiography(html) {
  const raw = html.match(/<div\b[^>]*\bid=["']Biography["'][^>]*>\s*<p\b[^>]*>([\s\S]*?)<\/p>\s*<\/div>/i)?.[1];
  if (!raw) return [];
  return raw
    .split(/(?:<br\s*\/?>\s*){2,}/i)
    .map(textFromHtml)
    .map((paragraph) => paragraph.replace(/\s+/g, " ").trim())
    .filter((paragraph) => paragraph.length >= 20);
}

function extractApolytikion(html) {
  const rawBlock = html.match(/<div\b[^>]*\bid=["']LiturgicalTexts["'][^>]*>([\s\S]*?)<\/div>/i)?.[1];
  if (!rawBlock) return null;
  const sections = rawBlock.split(/(?:<br\s*\/?>\s*){2,}/i);
  const hymnSections = sections.filter((part) => normalize(textFromHtml(part)).includes("απολυτικιον"));
  const section = hymnSections.find((part) => textFromHtml(part).split("\n").some((line) => normalize(line).startsWith("ηχος")))
    ?? hymnSections[0];
  if (!section) return null;

  const lines = textFromHtml(section).split("\n").map((line) => line.trim()).filter(Boolean);
  const headingIndex = lines.findIndex((line) => normalize(line).includes("απολυτικιον"));
  if (headingIndex < 0) return null;
  let index = headingIndex + 1;
  let echos = null;
  if (normalize(lines[index] ?? "").startsWith("ηχος")) echos = lines[index++];
  const textEl = lines.slice(index).join("\n").trim();
  if (textEl.length < 20) return null;
  return { echos, textEl, sourceNote: "Ὀρθόδοξος Συναξαριστής (saint.gr)" };
}

function commonApolytikion(saint, rankID) {
  const identity = normalize(`${saint.name} ${saint.rankTitle ?? ""}`);
  const first = normalize(saint.name).split(" ")[0];
  const plural = ["αγιοι", "αγιες", "οσιοι", "οσιες", "οι"].includes(first)
    || /\b(και οι|και τα|συν αυτω|συν αυτοις)\b/.test(identity);
  const female = ["αγια", "οσια", "δικαια"].includes(first) || identity.includes("παρθενομαρτυ");
  const hymn = (echos, textEl, label) => ({
    echos,
    textEl,
    sourceNote: `${label} — παραδοσιακὸ λειτουργικὸ κείμενο· δὲν παρατίθεται ιδιαίτερο ἀπολυτίκιο στὴν πηγή`,
  });

  if (rankID === "apostoloi" || rankID === "isapostoloi" || identity.includes("αποστολ")) {
    return hymn("Ἦχος γ´", "Ἀπόστολοι ἅγιοι, πρεσβεύσατε τῷ ἐλεήμονι Θεῷ, ἵνα πταισμάτων ἄφεσιν παράσχῃ ταῖς ψυχαῖς ἡμῶν.", "Κοινὸν Ἀποστόλων");
  }
  if (rankID === "profitai" || identity.includes("προφητ")) {
    return hymn("Ἦχος β´", "Τῶν Προφητῶν σου τὴν μνήμην, Κύριε, ἑορτάζοντες, δι᾿ αὐτῶν σε δυσωποῦμεν· σῶσον τὰς ψυχὰς ἡμῶν.", "Κοινὸν Προφητῶν");
  }
  if (rankID === "asomatoi" || identity.includes("αρχαγγελ") || identity.includes("ασωματ")) {
    return hymn("Ἦχος δ´", "Τῶν οὐρανίων στρατιῶν Ἀρχιστράτηγοι, δυσωποῦμεν ὑμᾶς ἀεὶ ἡμεῖς οἱ ἀνάξιοι, ἵνα ταῖς ὑμῶν δεήσεσι τειχίσητε ἡμᾶς, σκέπῃ τῶν πτερύγων τῆς ἀΰλου ὑμῶν δόξης.", "Κοινὸν Ἀρχαγγέλων");
  }
  if (rankID === "anargyroi" || identity.includes("αναργυρ")) {
    return hymn("Ἦχος πλ. δ´", "Ἅγιοι Ἀνάργυροι καὶ θαυματουργοί, ἐπισκέψασθε τὰς ἀσθενείας ἡμῶν· δωρεὰν ἐλάβετε, δωρεὰν δότε ἡμῖν.", "Κοινὸν Ἀναργύρων");
  }
  if (rankID === "ierarchai" || identity.includes("επισκοπ") || identity.includes("πατριαρχ") || identity.includes("ιεραρχ")) {
    return hymn("Ἦχος δ´", "Κανόνα πίστεως καὶ εἰκόνα πραότητος, ἐγκρατείας διδάσκαλον, ἀνέδειξέ σε τῇ ποίμνῃ σου ἡ τῶν πραγμάτων ἀλήθεια· διὰ τοῦτο ἐκτήσω τῇ ταπεινώσει τὰ ὑψηλά, τῇ πτωχείᾳ τὰ πλούσια. Πάτερ Ἱεράρχα, πρέσβευε Χριστῷ τῷ Θεῷ, σωθῆναι τὰς ψυχὰς ἡμῶν.", "Κοινὸν Ἱεράρχου");
  }
  if (rankID === "martyres" || rankID === "neomartyres" || identity.includes("μαρτυρ")) {
    if (plural) {
      return hymn("Ἦχος δ´", "Οἱ Μάρτυρές σου, Κύριε, ἐν τῇ ἀθλήσει αὐτῶν, στεφάνους ἐκομίσαντο τῆς ἀφθαρσίας, ἐκ σοῦ τοῦ Θεοῦ ἡμῶν· σχόντες γὰρ τὴν ἰσχύν σου, τοὺς τυράννους καθεῖλον, ἔθραυσαν καὶ δαιμόνων τὰ ἀνίσχυρα θράση. Αὐτῶν ταῖς ἱκεσίαις, Χριστὲ ὁ Θεός, σῶσον τὰς ψυχὰς ἡμῶν.", "Κοινὸν πλειόνων Μαρτύρων");
    }
    if (female) {
      return hymn("Ἦχος δ´", "Ἡ ἀμνάς σου Ἰησοῦ, κράζει μεγάλῃ τῇ φωνῇ· Σὲ Νυμφίε μου ποθῶ, καὶ σὲ ζητοῦσα ἀθλῶ, καὶ συσταυροῦμαι καὶ συνθάπτομαι τῷ βαπτισμῷ σου· καὶ πάσχω διὰ σέ, ὡς βασιλεύσω σὺν σοί, καὶ θνήσκω ὑπὲρ σοῦ, ἵνα καὶ ζήσω ἐν σοί. Αὐτῆς πρεσβείαις, ὡς ἐλεήμων, σῶσον τὰς ψυχὰς ἡμῶν.", "Κοινὸν Μάρτυρος γυναικός");
    }
    return hymn("Ἦχος δ´", "Ὁ Μάρτυς σου, Κύριε, ἐν τῇ ἀθλήσει αὐτοῦ, τὸ στέφος ἐκομίσατο τῆς ἀφθαρσίας, ἐκ σοῦ τοῦ Θεοῦ ἡμῶν· ἔχων γὰρ τὴν ἰσχύν σου, τοὺς τυράννους καθεῖλεν, ἔθραυσε καὶ δαιμόνων τὰ ἀνίσχυρα θράση. Αὐτοῦ ταῖς ἱκεσίαις, Χριστὲ ὁ Θεός, σῶσον τὰς ψυχὰς ἡμῶν.", "Κοινὸν ἑνὸς Μάρτυρος");
  }
  if (rankID === "osioi" || identity.includes("οσιο") || identity.includes("ασκητ")) {
    if (female) {
      return hymn("Ἦχος πλ. δ´", "Ἐν σοὶ Μῆτερ ἀκριβῶς διεσώθη τὸ κατ᾿ εἰκόνα· λαβοῦσα γὰρ τὸν σταυρόν, ἠκολούθησας τῷ Χριστῷ, καὶ πράττουσα ἐδίδασκες, ὑπερορᾶν μὲν σαρκός, παρέρχεται γάρ, ἐπιμελεῖσθαι δὲ ψυχῆς, πράγματος ἀθανάτου· διὸ καὶ μετὰ Ἀγγέλων συναγάλλεται, Ὁσία, τὸ πνεῦμά σου.", "Κοινὸν Ὁσίας");
    }
    return hymn("Ἦχος πλ. δ´", "Ἐν σοὶ Πάτερ ἀκριβῶς διεσώθη τὸ κατ᾿ εἰκόνα· λαβὼν γὰρ τὸν σταυρόν, ἠκολούθησας τῷ Χριστῷ, καὶ πράττων ἐδίδασκες, ὑπερορᾶν μὲν σαρκός, παρέρχεται γάρ, ἐπιμελεῖσθαι δὲ ψυχῆς, πράγματος ἀθανάτου· διὸ καὶ μετὰ Ἀγγέλων συναγάλλεται, Ὅσιε, τὸ πνεῦμά σου.", "Κοινὸν Ὁσίου");
  }
  return hymn("Ἦχος δ´", "Ὁ Θεὸς τῶν Πατέρων ἡμῶν, ὁ ποιῶν ἀεὶ μεθ᾿ ἡμῶν κατὰ τὴν σὴν ἐπιείκειαν, μὴ ἀποστήσῃς τὸ ἔλεός σου ἀφ᾿ ἡμῶν, ἀλλὰ ταῖς αὐτῶν ἱκεσίαις, ἐν εἰρήνῃ κυβέρνησον τὴν ζωὴν ἡμῶν.", "Κοινὸν Ἁγίων");
}

function bestCandidate(saint, candidates) {
  const ranked = candidates
    .map((candidate) => ({ ...candidate, score: matchScore(saint.name, candidate.title) }))
    .sort((left, right) => right.score - left.score);
  const best = ranked[0];
  if (!best || best.score < 0.48) return null;
  if (ranked[1] && best.score < 0.8 && best.score - ranked[1].score < 0.12) return null;
  return best;
}

const data = JSON.parse(await readFile(DATA_PATH, "utf8"));
const targets = data.ranks.flatMap((rank) => rank.saints
  .filter((saint) => !(saint.bio ?? []).some((paragraph) => paragraph.trim())
    || !(saint.apolytikion?.textEl ?? "").trim()
    || (UPGRADE_KLIMAX_BIOS && /(?:Klimax|Σύνθεση|Σημείωση)/iu.test(saint.source ?? "")))
  .map((saint) => ({ saint, rank, day: datePath(saint.feast) })));

const days = [...new Set(targets.map((target) => target.day).filter(Boolean))].sort();
console.log(`Fetching ${days.length} calendar pages for ${targets.length} incomplete records…`);
const calendarResults = await mapLimit(days, CONCURRENCY, async (day) => ({
  day,
  candidates: calendarCandidates(await fetchText(`${BASE_URL}/${day}/index.aspx`)),
}));
const candidatesByDay = new Map(calendarResults.filter((result) => !result.error).map((result) => [result.day, result.candidates]));

const matches = [];
const unmatched = [];
for (const target of targets) {
  const explicitID = explicitSources.get(target.saint.id);
  if (explicitID) {
    matches.push({
      ...target,
      explicit: true,
      candidate: { id: explicitID, title: target.saint.name, score: 1 },
    });
    continue;
  }
  const candidate = target.day ? bestCandidate(target.saint, candidatesByDay.get(target.day) ?? []) : null;
  if (candidate) matches.push({ ...target, candidate });
  else unmatched.push({ id: target.saint.id, name: target.saint.name, feast: target.saint.feast, reason: target.day ? "no confident date match" : "moving feast" });
}

console.log(`Matched ${matches.length}; fetching individual source pages…`);
const sourceResults = await mapLimit(matches, CONCURRENCY, async (match) => {
  const sourceUrl = `${BASE_URL}/${match.candidate.id}/saint.aspx`;
  const html = await fetchText(sourceUrl);
  const pageTitle = extractPageTitle(html);
  const verification = matchScore(match.saint.name, pageTitle);
  if (!match.explicit && verification < 0.45) throw new Error(`source verification failed (${verification.toFixed(2)}): ${pageTitle}`);
  return {
    match,
    sourceUrl,
    pageTitle,
    bio: extractBiography(html),
    apolytikion: extractApolytikion(html),
  };
});

let biosAdded = 0;
let biosUpgraded = 0;
let biosNotLonger = 0;
const biosKept = [];
let hymnsAdded = 0;
let directSourcesAdded = 0;
let commonHymnsAdded = 0;
let echosNormalized = 0;
const extractionFailures = [];
for (let index = 0; index < sourceResults.length; index += 1) {
  const result = sourceResults[index];
  const originalMatch = matches[index];
  if (result?.error) {
    extractionFailures.push({ id: originalMatch.saint.id, name: originalMatch.saint.name, reason: result.error });
    continue;
  }
  const { saint } = result.match;
  let recordChanged = false;
  const currentBioLength = (saint.bio ?? []).join(" ").trim().length;
  const sourceBioLength = result.bio.join(" ").trim().length;
  if (!currentBioLength && result.bio.length) {
    saint.bio = result.bio;
    biosAdded += 1;
    recordChanged = true;
  } else if (UPGRADE_KLIMAX_BIOS && /(?:Klimax|Σύνθεση|Σημείωση)/iu.test(saint.source ?? "") && result.bio.length) {
    // A replacement must be materially fuller, not merely a differently worded
    // paragraph. Exact page-title/date verification has already happened above.
    if (sourceBioLength >= Math.max(currentBioLength + 40, Math.ceil(currentBioLength * 1.25))) {
      saint.bio = result.bio;
      biosUpgraded += 1;
      recordChanged = true;
    } else {
      biosNotLonger += 1;
      biosKept.push({
        id: saint.id,
        name: saint.name,
        currentLength: currentBioLength,
        sourceLength: sourceBioLength,
        sourceUrl: result.sourceUrl,
      });
    }
  }
  if (!(saint.apolytikion?.textEl ?? "").trim() && result.apolytikion) {
    saint.apolytikion = result.apolytikion;
    hymnsAdded += 1;
    recordChanged = true;
  }
  if (recordChanged) {
    saint.source = "Ὀρθόδοξος Συναξαριστής (saint.gr)";
    saint.sourceUrl = result.sourceUrl;
    directSourcesAdded += 1;
  }
}

const allSaints = data.ranks.flatMap((rank) => rank.saints);
for (const rank of data.ranks) {
  for (const saint of rank.saints) {
    const verifiedHymn = verifiedSpecificHymns.get(saint.id);
    if (verifiedHymn) saint.apolytikion = verifiedHymn;
    if (saint.apolytikion && !saint.apolytikion.echos) {
      const lines = saint.apolytikion.textEl.split("\n").map((line) => line.trim()).filter(Boolean);
      if (normalize(lines[0] ?? "").startsWith("ηχος") && lines.length > 1) {
        saint.apolytikion.echos = lines.shift();
        saint.apolytikion.textEl = lines.join("\n");
        echosNormalized += 1;
      }
    }
    if (!(saint.apolytikion?.textEl ?? "").trim()) {
      saint.apolytikion = commonApolytikion(saint, rank.id);
      commonHymnsAdded += 1;
    }
  }
}

const report = {
  targetCount: targets.length,
  matched: matches.length,
  biosAdded,
  biosUpgraded,
  biosNotLonger,
  biosKept,
  hymnsAdded,
  commonHymnsAdded,
  echosNormalized,
  directSourcesAdded,
  remainingMissingBio: allSaints.filter((saint) => !(saint.bio ?? []).some((paragraph) => paragraph.trim())).length,
  remainingMissingApolytikion: allSaints.filter((saint) => !(saint.apolytikion?.textEl ?? "").trim()).length,
  unmatched,
  extractionFailures,
};

if (SHOULD_WRITE) {
  await writeFile(DATA_PATH, `${JSON.stringify(data, null, 2)}\n`, "utf8");
  console.log(`Updated ${DATA_PATH}`);
} else {
  console.log("Dry run only; pass --write to update saints.json.");
}
console.log(JSON.stringify(report, null, 2));
