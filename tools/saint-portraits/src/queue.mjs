import crypto from "node:crypto";
import fs from "node:fs";
import {
  atomicWriteJson,
  isoNow,
  readJson,
  resolveRoot,
  withFileLock,
  withFileLockAsync
} from "./util.mjs";
import { repositoryPaths } from "./repository.mjs";

export const QUEUE_STATES = new Set([
  "missing-source",
  "missing-metadata",
  "ready",
  "queued",
  "submitted",
  "processing",
  "generated",
  "qa-review",
  "human-review",
  "approved",
  "rejected",
  "failed",
  "published"
]);

function loadStores() {
  if (!fs.existsSync(resolveRoot(repositoryPaths.manifest))) {
    throw new Error("Manifest is missing. Run npm run saints:manifest first.");
  }
  return {
    manifest: readJson(repositoryPaths.manifest),
    queue: readJson(repositoryPaths.queue)
  };
}

function saveStores(manifest, queue) {
  atomicWriteJson(repositoryPaths.manifest, manifest);
  atomicWriteJson(repositoryPaths.queue, queue);
}

function assertState(status) {
  if (!QUEUE_STATES.has(status)) throw new Error(`Invalid queue status: ${status}`);
}

export function selectRecords(filters = {}) {
  const { manifest, queue } = loadStores();
  const queueById = new Map(queue.records.map((record) => [record.saintId, record]));
  return manifest.records.filter((record) => {
    const queueRecord = queueById.get(record.saintId);
    if (!queueRecord) return false;
    if (filters.saintId && record.saintId !== filters.saintId) return false;
    if (filters.slug && record.slug !== filters.slug) return false;
    if (filters.category && record.rankId !== filters.category) return false;
    if (filters.status && queueRecord.status !== filters.status) return false;
    if (filters.retryFailed && queueRecord.status !== "failed") return false;
    if (!filters.includeProtected && ["approved", "published"].includes(queueRecord.status)) return false;
    return true;
  })
    .sort((left, right) =>
      (left.generationPriority ?? 1000) - (right.generationPriority ?? 1000) ||
      left.saintId.localeCompare(right.saintId)
    )
    .map((record) => ({ record, queue: queueById.get(record.saintId) }));
}

export function transitionRecord(saintId, status, details = {}) {
  assertState(status);
  return withFileLock(saintId, () => {
    const { manifest, queue } = loadStores();
    const record = manifest.records.find((entry) => entry.saintId === saintId);
    const queueRecord = queue.records.find((entry) => entry.saintId === saintId);
    if (!record || !queueRecord) throw new Error(`Unknown saint ID: ${saintId}`);
    if (["approved", "published"].includes(queueRecord.status) && status !== queueRecord.status && !details.explicitReplacement) {
      throw new Error(`Protected portrait cannot transition from ${queueRecord.status} without explicit replacement.`);
    }
    const historyEntry = {
      at: isoNow(),
      from: queueRecord.status,
      to: status,
      reason: details.reason ?? null,
      attemptId: details.attemptId ?? null
    };
    queueRecord.status = status;
    queueRecord.activeAttemptId = details.activeAttemptId ?? queueRecord.activeAttemptId;
    queueRecord.history.push(historyEntry);
    record.queueStatus = status;
    record.latestAttemptStatus = details.latestAttemptStatus ?? status;
    if (details.latestError !== undefined) record.latestError = details.latestError;
    if (details.patch) Object.assign(record, details.patch);
    record.updatedAt = isoNow();
    queue.updatedAt = isoNow();
    saveStores(manifest, queue);
    return { record, queueRecord };
  });
}

export async function createAttempt(record, request, estimate, operation) {
  return withFileLockAsync(record.saintId, async () => {
    const { manifest, queue } = loadStores();
    const target = manifest.records.find((entry) => entry.saintId === record.saintId);
    const queueRecord = queue.records.find((entry) => entry.saintId === record.saintId);
    if (!target || !queueRecord) throw new Error(`Unknown saint ID: ${record.saintId}`);
    if (["approved", "published"].includes(queueRecord.status)) {
      throw new Error(`Portrait is protected: ${record.saintId}`);
    }
    if (queueRecord.activeAttemptId && ["queued", "submitted", "processing"].includes(queueRecord.status)) {
      throw new Error(`Duplicate active request prevented for ${record.saintId}.`);
    }
    const attemptId = `${record.saintId}-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
    const attempt = {
      id: attemptId,
      createdAt: isoNow(),
      mode: operation,
      status: operation === "batch" ? "queued" : "processing",
      request: {
        model: request.model,
        prompt: request.prompt,
        promptVersion: request.promptVersion,
        styleVersion: request.styleVersion,
        identityReference: request.identityReference,
        styleReferences: request.styleReferences,
        output: request.output,
        candidates: 1
      },
      estimatedCost: estimate,
      actualUsage: null,
      actualCostUsd: null,
      apiRequestId: null,
      candidatePath: null,
      candidateChecksum: null,
      qa: null,
      error: null,
      reviewerNotes: []
    };
    target.attemptCount += 1;
    target.selectedStyleReferenceIds = request.styleReferences.map((entry) => entry.id);
    target.generationMode = operation;
    target.estimatedApiCostUsd += estimate.estimatedUsd;
    target.latestAttemptStatus = attempt.status;
    target.latestError = null;
    target.attempts.push(attempt);
    target.updatedAt = isoNow();
    queueRecord.activeAttemptId = attemptId;
    queueRecord.status = attempt.status;
    queueRecord.history.push({ at: isoNow(), from: target.queueStatus, to: attempt.status, reason: "attempt-created", attemptId });
    target.queueStatus = attempt.status;
    queue.updatedAt = isoNow();
    saveStores(manifest, queue);
    return attempt;
  });
}

export async function updateAttempt(saintId, attemptId, patch, nextStatus) {
  return withFileLockAsync(saintId, async () => {
    const { manifest, queue } = loadStores();
    const record = manifest.records.find((entry) => entry.saintId === saintId);
    const queueRecord = queue.records.find((entry) => entry.saintId === saintId);
    const attempt = record?.attempts.find((entry) => entry.id === attemptId);
    if (!record || !queueRecord || !attempt) throw new Error(`Attempt not found: ${attemptId}`);
    Object.assign(attempt, patch, { updatedAt: isoNow() });
    if (nextStatus) {
      assertState(nextStatus);
      const previous = queueRecord.status;
      attempt.status = nextStatus;
      record.latestAttemptStatus = nextStatus;
      record.queueStatus = nextStatus;
      queueRecord.status = nextStatus;
      if (!["queued", "submitted", "processing"].includes(nextStatus)) queueRecord.activeAttemptId = null;
      queueRecord.history.push({ at: isoNow(), from: previous, to: nextStatus, reason: patch.reason ?? null, attemptId });
    }
    if (patch.error) record.latestError = patch.error.message ?? String(patch.error);
    if (patch.apiRequestId) record.apiRequestId = patch.apiRequestId;
    if (patch.actualUsage) record.actualUsageMetadata = patch.actualUsage;
    record.updatedAt = isoNow();
    queue.updatedAt = isoNow();
    saveStores(manifest, queue);
    return { record, attempt };
  });
}

export function projectCostSummary() {
  const { manifest } = loadStores();
  let estimated = 0;
  let actual = 0;
  let attempts = 0;
  for (const record of manifest.records) {
    for (const attempt of record.attempts) {
      attempts += 1;
      estimated += attempt.estimatedCost?.estimatedUsd ?? 0;
      actual += attempt.actualCostUsd ?? 0;
    }
  }
  return { attempts, estimatedUsd: estimated, actualUsd: actual };
}
