#!/usr/bin/env node
import readline from "node:readline/promises";
import process from "node:process";
import {
  atomicWriteJson,
  numberArg,
  parseArgs,
  readJson
} from "./src/util.mjs";
import {
  buildCompletedInventory,
  buildManifest,
  repositoryPaths
} from "./src/repository.mjs";
import {
  executeGeneration,
  planGeneration,
  prepareBatch
} from "./src/pipeline.mjs";
import {
  OpenAIImageProvider,
  submitPreparedBatch
} from "./src/providers.mjs";
import { createAttempt, updateAttempt } from "./src/queue.mjs";
import { estimateRequestCost } from "./src/costs.mjs";
import { startReviewServer } from "./src/review-server.mjs";
import {
  publishApproved,
  rollbackPublication
} from "./src/publish.mjs";
import { importApprovedManualCandidate } from "./src/manual-import.mjs";
import { mergeSaintCatalogAdditions } from "./src/catalog-additions.mjs";

function usage() {
  console.log(`Klimax saint portrait pipeline

Commands:
  inventory   Inspect completed repository portraits and select master references
  manifest    Rebuild the resumable saint manifest and queue
  generate    Plan by default; use --execute and an explicit --limit to spend
  batch       Prepare JSONL by default; use --execute and --confirm-spend to submit
  review      Start the local human review interface
  import-manual  Import one owner-approved local candidate with --candidate-path
  merge-catalog  Add curated saints from --additions-path without duplicates
  publish     Publish one approved saint with --saint-id
  rollback    Restore one publication with --publication-id

Common filters:
  --saint-id ID  --slug SLUG  --status STATUS  --category RANK

Safety:
  Real requests require --execute and --limit. More than one synchronous image
  also requires --confirm-spend. No command reads or prints OPENAI_API_KEY unless
  an explicitly authorised execution constructs the live provider.`);
}

function optionsFromArgs(args, { batch = false } = {}) {
  return {
    execute: args.execute === true,
    batch,
    limit: numberArg(args.limit, "limit", { integer: true, minimum: 1 }),
    maxApiCost: numberArg(args.maxApiCost, "max-api-cost", { minimum: 0.000001 }),
    concurrency: numberArg(args.concurrency, "concurrency", { integer: true, minimum: 1 }) ?? 1,
    saintId: args.saintId,
    slug: args.slug,
    category: args.category,
    status: args.status,
    retryFailed: args.retryFailed === true,
    reviewerNotes: args.reviewerNotes
  };
}

function printPlan(plan) {
  const report = plan.costReport;
  console.log("");
  console.log(`Mode: ${plan.mode}`);
  console.log(`Execution: ${plan.dryRun ? "DRY RUN, no API contact" : "AUTHORISED EXECUTION REQUESTED"}`);
  console.log(`Explicit limit: ${plan.explicitLimit}`);
  console.log(`Ready and selected: ${plan.selectedCount}`);
  console.log(`Planned requests after validation and ceiling: ${report.plannedCount}`);
  console.log(`Outputs: ${report.plannedCount}, exactly one candidate per request`);
  console.log(`Dimensions and quality: ${report.dimensions ?? "n/a"}, ${report.quality ?? "n/a"}`);
  console.log(`Hard local ceiling: $${Number(plan.hardCeilingUsd).toFixed(4)}`);
  console.log(`Estimated run cost: $${report.estimatedTotalUsd.toFixed(4)} USD`);
  console.log(`Pricing: ${report.pricingVersion}, verified ${report.pricingLastVerifiedAt}`);
  for (const item of report.items) {
    console.log(`  ${item.saintId}: ${item.referenceImageCount} input references, ~$${item.estimatedUsd.toFixed(4)}`);
  }
  for (const skipped of plan.skipped) {
    console.log(`  skipped ${skipped.saintId}: ${skipped.reason}`);
  }
  if (report.stoppedByCeiling) console.log("The hard ceiling stopped additional requests from being planned.");
  if (plan.warning) console.log(`WARNING: ${plan.warning}`);
  console.log(`Cumulative recorded project cost: estimated $${plan.cumulativeProjectCost.estimatedUsd.toFixed(4)}, actual $${plan.cumulativeProjectCost.actualUsd.toFixed(4)}`);
  console.log("");
}

async function confirmSpend(plan, confirmedNonInteractive) {
  if (confirmedNonInteractive) return;
  if (plan.costReport.plannedCount > 1) {
    throw new Error("Interactive execution is limited to one pilot image. Use --confirm-spend for a deliberate larger run.");
  }
  if (!process.stdin.isTTY) {
    throw new Error("Non-interactive execution requires --confirm-spend.");
  }
  const phrase = `SPEND $${plan.costReport.estimatedTotalUsd.toFixed(4)} FOR ${plan.costReport.plannedCount}`;
  const terminal = readline.createInterface({ input: process.stdin, output: process.stdout });
  const answer = await terminal.question(`Type exactly "${phrase}" to authorise this spend: `);
  terminal.close();
  if (answer !== phrase) throw new Error("Spend confirmation did not match. No request was sent.");
}

async function runGenerate(args) {
  const options = optionsFromArgs(args);
  const plan = planGeneration(options);
  printPlan(plan);
  if (!options.execute) {
    console.log("Dry run complete. No OpenAI client was created and no API request was made.");
    return;
  }
  if (!options.limit) throw new Error("Execution requires an explicit --limit.");
  if (!plan.costReport.plannedCount) throw new Error("There are no reviewed, ready records within the selected limit and ceiling.");
  await confirmSpend(plan, args.confirmSpend === true);
  const provider = new OpenAIImageProvider();
  const report = await executeGeneration(plan, provider, {
    concurrency: options.concurrency,
    retries: readJson("config/saint-portrait-pricing.v1.json").controls.maximumAutomaticRetries,
    onProgress: (event) => console.log(`${event.saintId}: ${event.status}`)
  });
  console.log(`Run completed with ${report.results.length} result(s). Human review is still required.`);
}

async function runBatch(args) {
  const options = optionsFromArgs(args, { batch: true });
  const plan = planGeneration(options);
  printPlan(plan);
  const prepared = prepareBatch(plan);
  console.log(`Prepared ${prepared.requestCount} request(s) at ${prepared.relativePath}.`);
  if (!options.execute) {
    console.log("Batch preparation complete. It was not uploaded or submitted.");
    return;
  }
  if (!options.limit) throw new Error("Batch submission requires an explicit --limit.");
  if (args.confirmSpend !== true) throw new Error("Batch submission requires --confirm-spend.");
  if (!prepared.requestCount) throw new Error("There are no reviewed, ready records to submit.");
  await confirmSpend(plan, true);
  const batch = await submitPreparedBatch(prepared.absolutePath);
  for (const { record, request } of plan.requests) {
    const attempt = await createAttempt(record, request, estimateRequestCost(request, { batch: true }), "batch");
    await updateAttempt(record.saintId, attempt.id, { apiRequestId: batch.id }, "submitted");
  }
  const planPath = `data/saint-portraits/batch/${prepared.id}.plan.json`;
  const batchPlan = readJson(planPath);
  batchPlan.submitted = true;
  batchPlan.batchId = batch.id;
  batchPlan.submittedAt = new Date().toISOString();
  atomicWriteJson(planPath, batchPlan);
  console.log(`Submitted Batch job ${batch.id}. No follow-on generation will start automatically.`);
}

async function main() {
  const [command, ...rest] = process.argv.slice(2);
  const args = parseArgs(rest);
  if (!command || command === "help" || args.help) {
    usage();
    return;
  }
  if (command === "inventory") {
    const { inventory, references } = buildCompletedInventory();
    console.log(`Inventoried ${inventory.totalCompleted} completed portraits.`);
    console.log(`Selected ${references.references.length} master references: ${references.references.map((entry) => entry.saintId).join(", ")}`);
    return;
  }
  if (command === "manifest") {
    const { manifest, queue } = buildManifest();
    const counts = queue.records.reduce((result, record) => {
      result[record.status] = (result[record.status] ?? 0) + 1;
      return result;
    }, {});
    console.log(`Prepared ${manifest.recordCount} manifest records.`);
    console.log(JSON.stringify(counts, null, 2));
    return;
  }
  if (command === "generate") return runGenerate(args);
  if (command === "batch") return runBatch(args);
  if (command === "review") {
    const port = numberArg(args.port, "port", { integer: true, minimum: 1 }) ?? 4178;
    const server = await startReviewServer({ port });
    console.log(`Review interface: http://127.0.0.1:${port}`);
    console.log("Generation cannot be started from this page.");
    process.on("SIGINT", () => server.close(() => process.exit(0)));
    return;
  }
  if (command === "import-manual") {
    if (!args.saintId) throw new Error("--saint-id is required.");
    if (!args.candidatePath) throw new Error("--candidate-path is required.");
    if (args.confirmHumanApproval !== true) {
      throw new Error("Manual import requires --confirm-human-approval.");
    }
    const result = await importApprovedManualCandidate(args.saintId, args.candidatePath);
    console.log(`${result.saintId}: ${result.status}`);
    return;
  }
  if (command === "merge-catalog") {
    if (!args.additionsPath) throw new Error("--additions-path is required.");
    const result = mergeSaintCatalogAdditions(args.additionsPath);
    console.log(`Added ${result.added.length} saint(s); skipped ${result.skipped.length} existing saint(s).`);
    return;
  }
  if (command === "publish") {
    if (!args.saintId) throw new Error("--saint-id is required.");
    const journal = publishApproved(args.saintId, { replaceApproved: args.replaceApproved === true });
    console.log(`Published ${journal.saintId} as ${journal.assetName}. Publication ID: ${journal.publicationId}`);
    return;
  }
  if (command === "rollback") {
    if (!args.publicationId) throw new Error("--publication-id is required.");
    const journal = rollbackPublication(args.publicationId);
    console.log(`Rolled back publication ${journal.publicationId}.`);
    return;
  }
  throw new Error(`Unknown command: ${command}`);
}

main().catch((error) => {
  console.error(`ERROR: ${error.message}`);
  process.exitCode = 1;
});
