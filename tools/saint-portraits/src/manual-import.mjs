import fs from "node:fs";
import path from "node:path";
import { validateCandidateImage } from "./image-analysis.mjs";
import { publishApproved } from "./publish.mjs";
import { createAttempt, transitionRecord, updateAttempt } from "./queue.mjs";
import { repositoryPaths } from "./repository.mjs";
import {
  isoNow,
  readJson,
  resolveRoot,
  sha256File
} from "./util.mjs";

function candidateRequest(record, candidatePath, style) {
  return {
    model: "chatgpt-plus-manual",
    prompt: "Human generated candidate imported from ChatGPT Plus after visual review.",
    promptVersion: "manual-import.v1",
    styleVersion: style.styleVersion,
    identityReference: record.identitySourceImagePath
      ? { path: record.identitySourceImagePath }
      : null,
    styleReferences: [],
    output: {
      path: candidatePath,
      width: style.generationCanvas.width,
      height: style.generationCanvas.height,
      format: style.generationCanvas.format,
      quality: style.generationCanvas.quality
    }
  };
}

export async function importApprovedManualCandidate(saintId, candidatePath, {
  publish = true
} = {}) {
  const relativeCandidatePath = path.relative(
    resolveRoot("."),
    resolveRoot(candidatePath)
  );
  const absoluteCandidatePath = resolveRoot(relativeCandidatePath);
  if (!fs.existsSync(absoluteCandidatePath)) {
    throw new Error(`Manual candidate is missing: ${relativeCandidatePath}`);
  }

  const manifest = readJson(repositoryPaths.manifest);
  const record = manifest.records.find((entry) => entry.saintId === saintId);
  if (!record) throw new Error(`Unknown saint ID: ${saintId}`);
  if (record.queueStatus === "published") {
    return { saintId, status: "already-published", journal: null };
  }
  if (record.queueStatus === "approved") {
    const journal = publish ? publishApproved(saintId) : null;
    return { saintId, status: publish ? "published" : "approved", journal };
  }
  if (!["ready", "human-review", "qa-review", "generated"].includes(record.queueStatus)) {
    throw new Error(`Manual import is not allowed from status ${record.queueStatus}: ${saintId}`);
  }

  const style = readJson("config/saint-portrait-style.v1.json");
  const completedInventory = readJson(repositoryPaths.inventory);
  const knownChecksums = new Set(
    completedInventory.completed.map((entry) => entry.analysis.checksum)
  );
  const sourceChecksums = new Set(
    manifest.records
      .map((entry) => entry.identitySourceChecksumSha256)
      .filter(Boolean)
  );
  const qa = validateCandidateImage(
    absoluteCandidatePath,
    style,
    knownChecksums,
    sourceChecksums
  );
  const request = candidateRequest(record, relativeCandidatePath, style);
  const estimate = {
    currency: "USD",
    estimatedUsd: 0,
    source: "ChatGPT Plus manual generation"
  };
  const attempt = await createAttempt(record, request, estimate, "manual");
  await updateAttempt(saintId, attempt.id, {
    candidatePath: relativeCandidatePath,
    candidateChecksum: sha256File(absoluteCandidatePath),
    qa,
    actualUsage: { imagesRequested: 0, source: "manual-import" },
    actualCostUsd: 0,
    reason: "manual-candidate-reviewed"
  }, "human-review");
  transitionRecord(saintId, "approved", {
    reason: "human-approved-manual-candidate",
    attemptId: attempt.id,
    patch: {
      portraitStatus: "approved",
      qaStatus: qa.status,
      reviewerStatus: "approved",
      reviewerNotes: [
        "Approved by the project owner after reviewing the ChatGPT Plus portrait batch."
      ],
      approvedAssetPath: relativeCandidatePath,
      approvedTimestamp: isoNow()
    }
  });
  const journal = publish ? publishApproved(saintId) : null;
  return { saintId, status: publish ? "published" : "approved", qa, journal };
}
