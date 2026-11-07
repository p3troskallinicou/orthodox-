import { writeFileSync } from "node:fs";

const year = 2026;
const entries = new Map();

function add(date, title, services = {}, extra = {}) {
  const previous = entries.get(date) ?? {
    date,
    title,
    vespers: false,
    orthros: false,
    divine_liturgy: false,
    office_basis: "typikon_2026"
  };
  entries.set(date, { ...previous, ...services, ...extra, title: title || previous.title });
}

// The public celebration index is deliberately not a list of all 365 daily
// offices. Sundays are generated; feasts and special Lenten/Paschal days are
// reviewed against the annual Typikon and added explicitly below.
for (let d = new Date(Date.UTC(year, 0, 1)); d.getUTCFullYear() === year; d.setUTCDate(d.getUTCDate() + 1)) {
  if (d.getUTCDay() === 0) {
    add(d.toISOString().slice(0, 10), "Κυριακή", {
      vespers: true, orthros: true, divine_liturgy: true
    }, { liturgy_kind: "chrysostom", office_basis: "sunday" });
  }
}

const all = { vespers: true, orthros: true, divine_liturgy: true };
const offices = { vespers: true, orthros: true, divine_liturgy: false };
const fixed = [
  ["2026-01-01", "Περιτομὴ τοῦ Κυρίου — Μέγας Βασίλειος", "basil"],
  ["2026-01-05", "Παραμονὴ Θεοφανείων", "basil"],
  ["2026-01-06", "Τὰ Ἅγια Θεοφάνεια", "chrysostom"],
  ["2026-02-02", "Ὑπαπαντὴ τοῦ Κυρίου", "chrysostom"],
  ["2026-03-25", "Εὐαγγελισμὸς τῆς Θεοτόκου", "chrysostom"],
  ["2026-06-24", "Γενέθλιον τοῦ Τιμίου Προδρόμου", "chrysostom"],
  ["2026-06-29", "Ἅγιοι Πρωτοκορυφαῖοι Ἀπόστολοι Πέτρος καὶ Παῦλος", "chrysostom"],
  ["2026-08-06", "Μεταμόρφωσις τοῦ Σωτῆρος", "chrysostom"],
  ["2026-08-15", "Κοίμησις τῆς Θεοτόκου", "chrysostom"],
  ["2026-09-08", "Γενέσιον τῆς Θεοτόκου", "chrysostom"],
  ["2026-09-14", "Ὕψωσις τοῦ Τιμίου Σταυροῦ", "chrysostom"],
  ["2026-11-21", "Εἴσοδος τῆς Θεοτόκου", "chrysostom"],
  ["2026-12-24", "Παραμονὴ Χριστουγέννων", "basil"],
  ["2026-12-25", "Ἡ Γέννησις τοῦ Χριστοῦ", "chrysostom"]
];
for (const [date, title, kind] of fixed) add(date, title, all, { liturgy_kind: kind, office_basis: "fixed_feast" });

for (const [date, title, kind = "chrysostom"] of [
  ["2026-02-14", "Ψυχοσάββατον πρὸ τῆς Ἀπόκρεω"],
  ["2026-02-21", "Ψυχοσάββατον πρὸ τῆς Τυρινῆς"],
  ["2026-04-04", "Σάββατον τοῦ Λαζάρου"],
  ["2026-04-06", "Μεγάλη Δευτέρα", "presanctified"],
  ["2026-04-07", "Μεγάλη Τρίτη", "presanctified"],
  ["2026-04-08", "Μεγάλη Τετάρτη", "presanctified"],
  ["2026-04-09", "Μεγάλη Πέμπτη", "basil"],
  ["2026-04-11", "Μέγα Σάββατον", "basil"],
  ["2026-04-13", "Δευτέρα τῆς Διακαινησίμου"],
  ["2026-04-17", "Παρασκευὴ τῆς Διακαινησίμου — Ζωοδόχος Πηγή"],
  ["2026-05-06", "Μεσοπεντηκοστή"],
  ["2026-05-21", "Ἀνάληψις τοῦ Κυρίου"],
  ["2026-05-30", "Ψυχοσάββατον πρὸ τῆς Πεντηκοστῆς"],
  ["2026-06-01", "Δευτέρα τοῦ Ἁγίου Πνεύματος"]
]) add(date, title, all, { liturgy_kind: kind, office_basis: "movable_feast" });

add("2026-04-10", "Μεγάλη Παρασκευή", offices, { office_basis: "holy_week" });

for (const date of [
  "2026-02-24", "2026-02-25", "2026-02-27", "2026-03-04", "2026-03-06",
  "2026-03-09", "2026-03-11", "2026-03-13", "2026-03-18", "2026-03-20",
  "2026-03-27", "2026-04-01", "2026-04-03"
]) {
  add(date, "Θεία Λειτουργία τῶν Προηγιασμένων Τιμίων Δώρων", {
    vespers: true, orthros: true, divine_liturgy: true
  }, { liturgy_kind: "presanctified", office_basis: "great_lent" });
}

const document = {
  schema_version: 1,
  year,
  jurisdiction: "Ἐκκλησία τῆς Κύπρου",
  status: "reviewed_annual_index",
  generated_at: "2026-08-14",
  sources: [
    "https://churchofcyprus.org.cy/all/διακονια/χρησιμες-πληροφοριες/τυπική-διάταξη/έτους-2026",
    "https://www.ec-patr.net/typikon/TYPIKO_2/2026/"
  ],
  note: "Κατάλογος προβλεπόμενων τελέσεων· όχι ωρολόγιο συγκεκριμένου ναού.",
  entries: [...entries.values()].sort((a, b) => a.date.localeCompare(b.date))
};

writeFileSync(new URL("../Klimax/LiturgicalData/typikon-services-2026.json", import.meta.url),
  `${JSON.stringify(document, null, 2)}\n`);
