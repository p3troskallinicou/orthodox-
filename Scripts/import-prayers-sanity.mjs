#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectId = process.env.SANITY_PROJECT_ID ?? "uqaka7yh";
const dataset = process.env.SANITY_DATASET ?? "production";
const apiVersion = process.env.SANITY_API_VERSION ?? "v2021-06-07";
const token = process.env.SANITY_TOKEN;

if (!token) {
  console.error("Missing SANITY_TOKEN.");
  process.exit(1);
}

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const prayersPath = path.join(root, "Klimax", "prayers.json");
const data = JSON.parse(await readFile(prayersPath, "utf8"));

const mutations = data.categories.map((category, index) => ({
  createOrReplace: {
    _id: `prayerCategory.${category.id}`,
    _type: "prayerCategory",
    categoryId: category.id,
    titleGreek: category.titleGreek,
    titleEnglish: category.titleEnglish,
    subtitle: category.subtitle,
    order: index,
    prayers: category.prayers
  }
}));

const url = `https://${projectId}.api.sanity.io/${apiVersion}/data/mutate/${dataset}`;
const response = await fetch(url, {
  method: "POST",
  headers: {
    "content-type": "application/json",
    authorization: `Bearer ${token}`
  },
  body: JSON.stringify({ mutations })
});

if (!response.ok) {
  const body = await response.text();
  console.error(`Sanity import failed: ${response.status}`);
  console.error(body);
  process.exit(1);
}

console.log(`Imported ${data.categories.length} prayer categories to Sanity.`);
