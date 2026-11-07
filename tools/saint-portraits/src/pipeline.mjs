import fs from "node:fs";
import path from "node:path";
import {
  atomicWriteBuffer,
  atomicWriteJson,
  isoNow,
  readJson,
  resolveRoot,
  sha256File
} from "./util.mjs";
import { validateCandidateImage } from "./image-analysis.mjs";
import { buildGenerationRequest } from "./prompt.mjs";
import { actualCostFromUsage, buildCostReport, estimateRequestCost } from "./costs.mjs";
import {
  createAttempt,
  projectCostSummary,
  selectRecords,
  updateAttempt
} from "./queue.mjs";
import { withRetry } from "./providers.mjs";

function filtersFromOptions(options, defaultStatus = "ready") {
  return {
    saintId: options.saintId,
    slug: options.slug,
    category: options.category,
    status: options.retryFailed ? undefined : options.status ?? defaultStatus,
    retryFailed: options.retryFailed,
    includeProtected: false
  };
}

export function planGeneration(options = {}) {
  if (!Number.isInteger(options.limit) || options.limit < 1) {
    throw new Error("An explicit positive whole-number --limit is required.");
  }
  const pricing = readJson("config/saint-portrait-pricing.v1.json");
  const hardCeiling = options.maxApiCost ?? pricing.controls.defaultHardCeilingUsd;
  if (!(hardCeiling > 0)) throw new Error("A positive hard API spending ceiling is required.");
  const selected = selectRecords(filtersFromOptions(options))
    .slice(0, options.limit);
  const skipped = [];
  const requests = [];
  for (const item of selected) {
    try {
      requests.push({ record: item.record, request: buildGenerationRequest(item.record, {
        reviewerInstructions: options.reviewerNotes
      }) });
    } catch (error) {
      skipped.push({ saintId: item.record.saintId, reason: error.message });
    }
  }
  const costReport = buildCostReport(requests.map((entry) => entry.request), {
    batch: options.batch,
    maxApiCost: hardCeiling
  });
  const withinCeiling = requests.slice(0, costReport.plannedCount);
  const cumulative = projectCostSummary();
  return {
    mode: options.batch ? "batch" : "synchronous",
    dryRun: !options.execute,
    explicitLimit: options.limit,
    hardCeilingUsd: hardCeiling,
    selectedCount: selected.length,
    requests: withinCeiling,
    skipped,
    costReport,
    cumulativeProjectCost: cumulative,
    warning: withinCeiling.some(({ record }) => record.attemptCount >= pricing.controls.rejectionCostWarningAttempts)
      ? "Some selected saints already have repeated attempts. Review rejection notes before spending again."
      : null
  };
}

function knownChecksums() {
  const checksums = new Set();
  const inventoryPath = resolveRoot("data/saint-portraits/completed-inventory.v1.json");
  if (fs.existsSync(inventoryPath)) {
    for (const entry of readJson("data/saint-portraits/completed-inventory.v1.json").completed) {
      checksums.add(entry.analysis.checksum);
    }
  }
  const manifestPath = resolveRoot("data/saint-portraits/manifest.v1.json");
  if (fs.existsSync(manifestPath)) {
    for (const record of readJson("data/saint-portraits/manifest.v1.json").records) {
      for (const attempt of record.attempts ?? []) {
        if (attempt.candidateChecksum) checksums.add(attempt.candidateChecksum);
      }
    }
  }
  return checksums;
}

export async function executeGeneration(plan, provider, {
  concurrency = 1,
  retries = 2,
  visionQAProvider = null,
  onProgress = () => {}
} = {}) {
  if (plan.dryRun) throw new Error("Dry-run plans cannot execute.");
  if (!provider) throw new Error("An explicit image provider is required.");
  const boundedConcurrency = Math.max(1, Math.min(Number(concurrency) || 1, 4));
  const pending = [...plan.requests];
  const results = [];
  const workers = Array.from({ length: boundedConcurrency }, async () => {
    while (pending.length) {
      const { record, request } = pending.shift();
      const estimate = estimateRequestCost(request);
      const attempt = await createAttempt(record, request, estimate, "synchronous");
      onProgress({ saintId: record.saintId, status: "processing", attemptId: attempt.id });
      try {
        const response = await withRetry(() => provider.generate(request), {
          retries,
          onRetry: (event) => onProgress({ saintId: record.saintId, status: "retry", ...event })
        });
        const attemptDir = resolveRoot(`data/saint-portraits/attempts/${attempt.id}`);
        const candidatePath = path.join(attemptDir, "candidate.png");
        atomicWriteBuffer(candidatePath, response.buffer);
        const checksum = sha256File(candidatePath);
        const sourceChecksums = new Set();
        for (const source of [request.identityReference.path, ...request.styleReferences.map((entry) => entry.imagePath)].filter(Boolean)) {
          sourceChecksums.add(sha256File(resolveRoot(source)));
        }
        const deterministicQA = validateCandidateImage(
          candidatePath,
          readJson("config/saint-portrait-style.v1.json"),
          knownChecksums(),
          sourceChecksums
        );
        const visionQA = visionQAProvider ? await visionQAProvider.evaluate({
          record,
          request,
          candidatePath,
          deterministicQA
        }) : null;
        const needsQAReview = deterministicQA.status !== "passed" ||
          (visionQA && (visionQA.confidence < 0.8 || visionQA.reasonsForReview?.length));
        const nextStatus = needsQAReview ? "qa-review" : "human-review";
        const actualCostUsd = actualCostFromUsage(response.usage);
        await updateAttempt(record.saintId, attempt.id, {
          apiRequestId: response.requestId,
          candidatePath: path.relative(resolveRoot("."), candidatePath),
          candidateChecksum: checksum,
          actualUsage: response.usage,
          actualCostUsd,
          providerMetadata: response.rawMetadata,
          qa: { deterministic: deterministicQA, vision: visionQA }
        }, nextStatus);
        const result = { saintId: record.saintId, attemptId: attempt.id, status: nextStatus, candidatePath, actualCostUsd };
        results.push(result);
        onProgress(result);
      } catch (error) {
        const serialized = {
          message: error.message,
          status: error.providerClassification?.status ?? null,
          code: error.providerClassification?.code ?? null,
          retryable: error.providerClassification?.retryable ?? false
        };
        await updateAttempt(record.saintId, attempt.id, { error: serialized }, "failed");
        const result = { saintId: record.saintId, attemptId: attempt.id, status: "failed", error: serialized };
        results.push(result);
        onProgress(result);
      }
    }
  });
  await Promise.all(workers);
  const report = {
    schemaVersion: 1,
    runAt: isoNow(),
    mode: "synchronous",
    plannedCost: plan.costReport,
    results
  };
  atomicWriteJson(`data/saint-portraits/run-reports/${Date.now()}-sync.json`, report);
  return report;
}

function fileDataUrl(relativePath) {
  const absolutePath = resolveRoot(relativePath);
  const extension = path.extname(absolutePath).toLowerCase();
  const mime = extension === ".webp" ? "image/webp" : extension === ".jpg" || extension === ".jpeg" ? "image/jpeg" : "image/png";
  return `data:${mime};base64,${fs.readFileSync(absolutePath).toString("base64")}`;
}

function batchLine(record, request) {
  if (!request.identityReference.path) throw new Error(`Batch preparation requires a local identity source for ${record.saintId}.`);
  const content = [
    { type: "input_text", text: request.prompt },
    { type: "input_text", text: "IDENTITY REFERENCE IMAGE 1" },
    { type: "input_image", image_url: fileDataUrl(request.identityReference.path), detail: "high" }
  ];
  request.styleReferences.forEach((reference, index) => {
    content.push({ type: "input_text", text: `COMPLETED APPLICATION STYLE REFERENCE IMAGE ${index + 2}: ${reference.id}` });
    content.push({ type: "input_image", image_url: fileDataUrl(reference.imagePath), detail: "high" });
  });
  return {
    custom_id: `saint-${record.saintId}`,
    method: "POST",
    url: "/v1/responses",
    body: {
      model: request.output.batchOrchestrationModel,
      input: [{ role: "user", content }],
      tools: [{
        type: "image_generation",
        model: request.model,
        action: "edit",
        size: `${request.output.width}x${request.output.height}`,
        quality: request.output.quality,
        output_format: request.output.format,
        background: request.output.background
      }],
      tool_choice: { type: "image_generation" }
    }
  };
}

export function prepareBatch(plan) {
  const id = `${new Date().toISOString().replace(/[:.]/g, "-")}-saints`;
  const relativePath = `data/saint-portraits/batch/${id}.jsonl`;
  const absolutePath = resolveRoot(relativePath);
  fs.mkdirSync(path.dirname(absolutePath), { recursive: true });
  const lines = plan.requests.map(({ record, request }) => JSON.stringify(batchLine(record, request)));
  const temporary = `${absolutePath}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, `${lines.join("\n")}${lines.length ? "\n" : ""}`, { mode: 0o600 });
  fs.renameSync(temporary, absolutePath);
  atomicWriteJson(`data/saint-portraits/batch/${id}.plan.json`, {
    schemaVersion: 1,
    preparedAt: isoNow(),
    submitted: false,
    jsonlPath: relativePath,
    costReport: plan.costReport,
    saints: plan.requests.map(({ record }) => record.saintId)
  });
  return { id, relativePath, absolutePath, requestCount: lines.length };
}
