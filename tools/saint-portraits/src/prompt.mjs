import fs from "node:fs";
import { readJson, resolveRoot } from "./util.mjs";

function normalizedTerms(record) {
  return new Set([
    record.rankId,
    record.religiousRoleOrCategory,
    record.approximateAgeCategory,
    ...(record.clothing ?? []),
    ...(record.identifyingObjectsOrSymbols ?? [])
  ].filter(Boolean).flatMap((value) => String(value).toLowerCase().split(/\W+/)));
}

export function selectStyleReferences(record, masterSet, maximum = 3) {
  const terms = normalizedTerms(record);
  return masterSet.references
    .map((reference) => {
      const overlap = reference.categories.reduce((score, category) =>
        score + (terms.has(String(category).toLowerCase()) ? 2 : 0), 0);
      const stableTieBreaker = reference.saintId === "petros" ? 0.25 : 0;
      return { reference, score: overlap + stableTieBreaker };
    })
    .sort((left, right) => right.score - left.score || left.reference.id.localeCompare(right.reference.id))
    .slice(0, Math.min(maximum, 3))
    .map(({ reference }) => reference);
}

function section(label, values) {
  const resolved = Array.isArray(values) ? values.filter(Boolean).join("; ") : values;
  return resolved ? `${label}: ${resolved}` : `${label}: not verified; do not invent.`;
}

export function buildPrompt(record, style, references, reviewerInstructions = null) {
  if (!record.identitySourceImagePath && !record.identitySourceImageUrl) {
    throw new Error(`${record.saintId} has no reviewed identity source.`);
  }
  if (record.metadataReviewReasons?.length) {
    throw new Error(`${record.saintId} requires metadata review: ${record.metadataReviewReasons.join(", ")}`);
  }
  const instruction = style.instruction;
  const prompt = [
    `PROMPT VERSION: ${record.generationPromptVersion}`,
    `STYLE VERSION: ${style.styleVersion}`,
    "",
    "REFERENCE ROLES",
    "Identity reference image 1 establishes this saint's approved traditional identity, approximate age, face, clothing, and identifying attributes. Preserve only verified identity information.",
    `Completed application portrait references 2 through ${references.length + 1} establish the required Klimax rendering style, background, crop, lighting, halo, colour restraint, and degree of detail. They do not establish this saint's identity.`,
    "Create a new original rendering. Do not copy accidental defects, writing, watermarks, borders, background scenery, or unrelated attributes from any reference.",
    "",
    "SAINT METADATA",
    section("Canonical name", record.canonicalName),
    section("Traditional physical description", record.traditionalPhysicalDescription),
    section("Approximate age category", record.approximateAgeCategory),
    section("Religious role or category", record.religiousRoleOrCategory),
    section("Clothing", record.clothing),
    section("Identifying objects or symbols", record.identifyingObjectsOrSymbols),
    section("Required visual attributes", record.requiredVisualAttributes),
    section("Prohibited or uncertain attributes", record.prohibitedOrUncertainAttributes),
    "",
    "LOCKED APPLICATION STYLE",
    section("Composition", instruction.composition),
    section("Crop", instruction.crop),
    section("Background", instruction.background),
    section("Lighting", instruction.lighting),
    section("Rendering technique", instruction.renderingTechnique),
    section("Level of detail", instruction.levelOfDetail),
    section("Facial treatment", instruction.facialTreatment),
    section("Clothing treatment", instruction.clothingTreatment),
    section("Halo treatment", instruction.haloTreatment),
    section("Colour restraint", instruction.colourRestraint),
    section("Perspective", instruction.perspective),
    "",
    "ABSOLUTE PROHIBITIONS",
    instruction.prohibitedElements.join("; "),
    "",
    `OUTPUT: exactly one ${style.generationCanvas.width} by ${style.generationCanvas.height} ${style.generationCanvas.format.toUpperCase()} candidate, ${style.generationCanvas.background} background, no text.`
  ];
  if (reviewerInstructions) {
    prompt.push("", "REVIEWER INSTRUCTIONS FOR THIS REGENERATION", reviewerInstructions);
  }
  return prompt.join("\n");
}

export function buildGenerationRequest(record, { reviewerInstructions = null } = {}) {
  const style = readJson("config/saint-portrait-style.v1.json");
  const masterSet = readJson("config/saint-portrait-master-references.v1.json");
  const references = selectStyleReferences(record, masterSet, masterSet.maximumReferencesPerRequest);
  if (!references.length) throw new Error("No approved master style references are configured.");
  const identityPath = record.identitySourceImagePath ? resolveRoot(record.identitySourceImagePath) : null;
  if (identityPath && !fs.existsSync(identityPath)) {
    throw new Error(`Identity source does not exist: ${record.identitySourceImagePath}`);
  }
  for (const reference of references) {
    if (!fs.existsSync(resolveRoot(reference.imagePath))) {
      throw new Error(`Style reference does not exist: ${reference.imagePath}`);
    }
  }
  return {
    saintId: record.saintId,
    slug: record.slug,
    model: "gpt-image-2",
    prompt: buildPrompt(record, style, references, reviewerInstructions),
    promptVersion: record.generationPromptVersion,
    styleVersion: style.styleVersion,
    identityReference: {
      path: record.identitySourceImagePath,
      url: record.identitySourceImageUrl,
      pageUrl: record.identitySourcePageUrl,
      directAssetUrl: record.identitySourceDirectAssetUrl,
      creator: record.identitySourceCreator,
      licence: record.identitySourceLicence,
      institution: record.identitySourceInstitution,
      accessedAt: record.identitySourceAccessedAt,
      checksumSha256: record.identitySourceChecksumSha256,
      licenceOrRightsNotes: record.sourceLicenceOrRightsNotes
    },
    styleReferences: references,
    output: style.generationCanvas,
    candidates: 1
  };
}
