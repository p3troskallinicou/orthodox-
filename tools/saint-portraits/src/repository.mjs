import fs from "node:fs";
import path from "node:path";
import { analyzeImage } from "./image-analysis.mjs";
import {
  ROOT,
  atomicWriteJson,
  isoNow,
  readJson,
  resolveRoot,
  slugify
} from "./util.mjs";

const SAINTS_PATH = "Klimax/saints.json";
const ASSET_ROOT = "Klimax/Assets.xcassets";
const INVENTORY_PATH = "data/saint-portraits/completed-inventory.v1.json";
const REFERENCES_PATH = "config/saint-portrait-master-references.v1.json";
const MANIFEST_PATH = "data/saint-portraits/manifest.v1.json";
const QUEUE_PATH = "data/saint-portraits/queue.v1.json";
const OVERRIDES_PATH = "data/saint-portraits/metadata-overrides.v1.json";
const PRIORITIES_PATH = "config/saint-portrait-priorities.v1.json";

export function discoverSaints() {
  const data = readJson(SAINTS_PATH);
  const seen = new Set();
  const saints = [];
  for (const rank of data.ranks) {
    for (const saint of rank.saints) {
      if (!saint.id || !saint.name) throw new Error(`Invalid saint record in rank ${rank.id}.`);
      if (seen.has(saint.id)) throw new Error(`Duplicate saint ID: ${saint.id}`);
      seen.add(saint.id);
      saints.push({
        ...saint,
        rank: {
          id: rank.id,
          titleGreek: rank.titleGreek,
          titleEnglish: rank.titleEnglish ?? null
        }
      });
    }
  }
  return { source: SAINTS_PATH, schemaVersion: data.schemaVersion ?? 1, saints };
}

function assetFileForName(assetName) {
  if (!assetName) return null;
  const imagesetRelative = `${ASSET_ROOT}/${assetName}.imageset`;
  const imagesetAbsolute = resolveRoot(imagesetRelative);
  const contentsPath = path.join(imagesetAbsolute, "Contents.json");
  if (!fs.existsSync(contentsPath)) return null;
  const contents = JSON.parse(fs.readFileSync(contentsPath, "utf8"));
  const filename = contents.images?.find((entry) => entry.filename)?.filename;
  if (!filename) return null;
  const fileAbsolute = path.join(imagesetAbsolute, filename);
  if (!fs.existsSync(fileAbsolute)) return null;
  return {
    assetName,
    imagesetPath: imagesetRelative,
    imagePath: path.relative(ROOT, fileAbsolute)
  };
}

export function discoverCompletedPortraits() {
  const { saints } = discoverSaints();
  return saints
    .map((saint) => ({ saint, asset: assetFileForName(saint.icon) }))
    .filter((entry) => entry.asset);
}

function featureVector(entry) {
  const color = entry.analysis.edgeBackgroundRgb ?? [0, 0, 0];
  const bounds = entry.analysis.subjectBounds ?? { x: 0, y: 0, width: 1, height: 1 };
  const dominant = entry.analysis.dominantColors?.[1]?.rgb ?? color;
  return [
    entry.analysis.aspectRatio * 100,
    color[0] / 3,
    color[1] / 3,
    color[2] / 3,
    dominant[0] / 4,
    dominant[1] / 4,
    dominant[2] / 4,
    bounds.x * 100,
    bounds.y * 100,
    bounds.width * 100,
    bounds.height * 100
  ];
}

function vectorDistance(left, right) {
  return Math.sqrt(left.reduce((sum, value, index) => sum + (value - right[index]) ** 2, 0));
}

export function selectRepresentativeReferences(inventory, maximum = 12) {
  const candidates = [...inventory.completed].sort((left, right) => left.saintId.localeCompare(right.saintId));
  if (candidates.length <= maximum) return candidates;
  const selected = [candidates.find((entry) => entry.saintId === "petros") ?? candidates[0]];
  while (selected.length < maximum) {
    let best;
    let bestDistance = -1;
    for (const candidate of candidates) {
      if (selected.some((entry) => entry.saintId === candidate.saintId)) continue;
      const distance = Math.min(...selected.map((entry) =>
        vectorDistance(featureVector(candidate), featureVector(entry))
      ));
      if (distance > bestDistance || (distance === bestDistance && candidate.saintId < best.saintId)) {
        best = candidate;
        bestDistance = distance;
      }
    }
    selected.push(best);
  }
  return selected;
}

export function buildCompletedInventory({ write = true } = {}) {
  const completed = discoverCompletedPortraits().map(({ saint, asset }) => ({
    saintId: saint.id,
    canonicalName: saint.name,
    nameEnglish: saint.nameEnglish ?? null,
    rankId: saint.rank.id,
    rankTitle: saint.rank.titleGreek,
    role: saint.rankTitle ?? null,
    imagePath: asset.imagePath,
    imagesetPath: asset.imagesetPath,
    analysis: analyzeImage(resolveRoot(asset.imagePath))
  }));
  const groups = Object.values(completed.reduce((result, entry) => {
    const key = `${entry.analysis.format}:${entry.analysis.width}x${entry.analysis.height}`;
    result[key] ??= { key, format: entry.analysis.format, width: entry.analysis.width, height: entry.analysis.height, count: 0, saintIds: [] };
    result[key].count += 1;
    result[key].saintIds.push(entry.saintId);
    return result;
  }, {}));
  const inventory = {
    schemaVersion: 1,
    generatedAt: isoNow(),
    sourceSaintsPath: SAINTS_PATH,
    totalCompleted: completed.length,
    groups,
    completed
  };
  const selected = selectRepresentativeReferences(inventory, 12);
  const visualInspectionNotes = {
    "ioudas-thaddaios": "Strong frontal composition and garment rendering. Painted lettering and the hard outer border are source defects and must not be reproduced.",
    matthaios: "Strong elder facial treatment and green garment variation. Painted writing inside the open book is a source defect and must not be reproduced.",
    "ioannis-theologos": "Useful elder facial treatment and book attribute. Painted writing inside the book is a source defect and must not be reproduced.",
    "simon-zilotis": "Useful blue and gold garment treatment. Painted lettering and the hard outer border are source defects and must not be reproduced."
  };
  const references = {
    schemaVersion: 1,
    referenceSetVersion: "saint-master-references.v1",
    generatedAt: isoNow(),
    maximumReferencesPerRequest: 3,
    selectionMethod: "Deterministic farthest point sampling over dimensions, edge colour, dominant colour, and subject bounds, followed by human visual inspection.",
    limitations: [
      "All completed repository portraits currently depict male Apostles.",
      "The set cannot yet establish female, monastic, hierarch, martyr, or royal category variants.",
      "Those categories must remain metadata review items until approved references exist."
    ],
    references: selected.map((entry, index) => ({
      id: `master-${String(index + 1).padStart(2, "0")}-${entry.saintId}`,
      saintId: entry.saintId,
      canonicalName: entry.canonicalName,
      imagePath: entry.imagePath,
      categories: ["male", "apostle", entry.role ?? "role-unspecified", "bust", "outlined-halo"],
      visuallyInspected: true,
      visualInspectionNotes: visualInspectionNotes[entry.saintId] ??
        "Visually inspected. Use the iconographic composition, restrained modelling, gold field, halo treatment, and garment language only.",
      checksum: entry.analysis.checksum
    }))
  };
  if (write) {
    atomicWriteJson(INVENTORY_PATH, inventory);
    atomicWriteJson(REFERENCES_PATH, references);
  }
  return { inventory, references };
}

function inferredMetadataReviewReasons(saint, override) {
  const reasons = [];
  if (!saint.bio?.length && !override.traditionalPhysicalDescription) {
    reasons.push("missing-traditional-description");
  }
  if (!saint.rankTitle) reasons.push("missing-role");
  if (!override.approximateAgeCategory) reasons.push("age-category-unverified");
  if (!override.clothing?.length) reasons.push("clothing-unverified");
  if (!override.requiredVisualAttributes?.length) reasons.push("visual-attributes-unverified");
  return reasons;
}

function sourceReviewReasons(override) {
  const reasons = [];
  if (!override.identitySourceImagePath && !override.identitySourceImageUrl) reasons.push("missing-identity-source");
  if (!override.sourceLicenceOrRightsNotes) reasons.push("missing-source-rights");
  return reasons;
}

export function buildManifest({ write = true, preserveExisting = true } = {}) {
  const { saints } = discoverSaints();
  const completedById = new Map(discoverCompletedPortraits().map((entry) => [entry.saint.id, entry]));
  const overrides = readJson(OVERRIDES_PATH).records ?? {};
  const priorities = fs.existsSync(resolveRoot(PRIORITIES_PATH))
    ? readJson(PRIORITIES_PATH).records ?? {}
    : {};
  const existing = preserveExisting && fs.existsSync(resolveRoot(MANIFEST_PATH))
    ? readJson(MANIFEST_PATH)
    : { records: [] };
  const existingById = new Map((existing.records ?? []).map((record) => [record.saintId, record]));
  const records = saints.map((saint) => {
    const override = overrides[saint.id] ?? {};
    const priority = priorities[saint.id] ?? {};
    const prior = existingById.get(saint.id) ?? {};
    const completed = completedById.get(saint.id);
    const metadataReasons = inferredMetadataReviewReasons(saint, override);
    const sourceReasons = sourceReviewReasons(override);
    let portraitStatus = "missing";
    let queueStatus = metadataReasons.length ? "missing-metadata" : sourceReasons.length ? "missing-source" : "ready";
    if (completed) {
      portraitStatus = "existing-protected";
      queueStatus = "published";
    } else if (prior.reviewerStatus === "approved" && prior.approvedAssetPath) {
      portraitStatus = "approved";
      queueStatus = prior.portraitStatus === "published" ? "published" : "approved";
    }
    return {
      schemaVersion: 1,
      saintId: saint.id,
      canonicalName: saint.name,
      nameEnglish: saint.nameEnglish ?? null,
      slug: override.slug ?? slugify(saint.id),
      existingApplicationRecordId: saint.id,
      rankId: saint.rank.id,
      rankTitle: saint.rank.titleGreek,
      feast: saint.feast ?? null,
      generationPriority: priority.priority ?? 1000,
      generationPriorityGroup: priority.group ?? "standard",
      generationPriorityReason: priority.reason ?? null,
      portraitStatus,
      queueStatus,
      completedPortraitPath: completed?.asset.imagePath ?? prior.completedPortraitPath ?? null,
      identitySourceImagePath: override.identitySourceImagePath ?? prior.identitySourceImagePath ?? null,
      identitySourceImageUrl: override.identitySourceImageUrl ?? prior.identitySourceImageUrl ?? null,
      identitySourcePageUrl: override.identitySourcePageUrl ?? prior.identitySourcePageUrl ?? null,
      identitySourceDirectAssetUrl: override.identitySourceDirectAssetUrl ?? prior.identitySourceDirectAssetUrl ?? null,
      identitySourceCreator: override.identitySourceCreator ?? prior.identitySourceCreator ?? null,
      identitySourceLicence: override.identitySourceLicence ?? prior.identitySourceLicence ?? null,
      identitySourceInstitution: override.identitySourceInstitution ?? prior.identitySourceInstitution ?? null,
      identitySourceAccessedAt: override.identitySourceAccessedAt ?? prior.identitySourceAccessedAt ?? null,
      identitySourceChecksumSha256: override.identitySourceChecksumSha256 ?? prior.identitySourceChecksumSha256 ?? null,
      sourceLicenceOrRightsNotes: override.sourceLicenceOrRightsNotes ?? prior.sourceLicenceOrRightsNotes ?? null,
      metadataSourceUrls: override.metadataSourceUrls ?? prior.metadataSourceUrls ?? [],
      metadataUncertaintyNotes: override.metadataUncertaintyNotes ?? prior.metadataUncertaintyNotes ?? [],
      traditionalPhysicalDescription: override.traditionalPhysicalDescription ?? null,
      approximateAgeCategory: override.approximateAgeCategory ?? null,
      clothing: override.clothing ?? [],
      religiousRoleOrCategory: override.religiousRoleOrCategory ?? saint.rankTitle ?? saint.rank.titleGreek,
      identifyingObjectsOrSymbols: override.identifyingObjectsOrSymbols ?? [],
      requiredVisualAttributes: override.requiredVisualAttributes ?? [],
      prohibitedOrUncertainAttributes: override.prohibitedOrUncertainAttributes ?? [],
      repositoryBio: saint.bio ?? [],
      repositorySource: saint.source ?? null,
      repositorySourceUrl: saint.sourceUrl ?? null,
      metadataReviewReasons: completed ? [] : metadataReasons,
      sourceReviewReasons: completed ? [] : sourceReasons,
      generationPromptVersion: prior.generationPromptVersion ?? "saint-prompt.v1",
      styleVersion: "saint-portrait-style.v1",
      selectedStyleReferenceIds: prior.selectedStyleReferenceIds ?? [],
      generationMode: prior.generationMode ?? null,
      attemptCount: prior.attemptCount ?? 0,
      latestAttemptStatus: prior.latestAttemptStatus ?? null,
      latestError: prior.latestError ?? null,
      apiRequestId: prior.apiRequestId ?? null,
      estimatedApiCostUsd: prior.estimatedApiCostUsd ?? 0,
      actualUsageMetadata: prior.actualUsageMetadata ?? null,
      qaStatus: prior.qaStatus ?? null,
      reviewerStatus: prior.reviewerStatus ?? null,
      reviewerNotes: prior.reviewerNotes ?? [],
      approvedAssetPath: prior.approvedAssetPath ?? null,
      approvedTimestamp: prior.approvedTimestamp ?? null,
      publishedChecksum: prior.publishedChecksum ?? (completed ? completed.asset.imagePath && analyzeImage(resolveRoot(completed.asset.imagePath)).checksum : null),
      attempts: prior.attempts ?? [],
      updatedAt: isoNow()
    };
  });
  const manifest = {
    schemaVersion: 1,
    generatedAt: isoNow(),
    source: SAINTS_PATH,
    recordCount: records.length,
    records
  };
  const previousQueue = fs.existsSync(resolveRoot(QUEUE_PATH)) ? readJson(QUEUE_PATH) : { records: [] };
  const queueById = new Map((previousQueue.records ?? []).map((entry) => [entry.saintId, entry]));
  const queue = {
    schemaVersion: 1,
    updatedAt: isoNow(),
    records: records.map((record) => ({
      saintId: record.saintId,
      slug: record.slug,
      category: record.rankId,
      status: record.queueStatus,
      activeAttemptId: queueById.get(record.saintId)?.activeAttemptId ?? null,
      history: queueById.get(record.saintId)?.history ?? []
    }))
  };
  if (write) {
    atomicWriteJson(MANIFEST_PATH, manifest);
    atomicWriteJson(QUEUE_PATH, queue);
  }
  return { manifest, queue };
}

export const repositoryPaths = {
  saints: SAINTS_PATH,
  assets: ASSET_ROOT,
  inventory: INVENTORY_PATH,
  references: REFERENCES_PATH,
  manifest: MANIFEST_PATH,
  queue: QUEUE_PATH,
  overrides: OVERRIDES_PATH,
  priorities: PRIORITIES_PATH
};
