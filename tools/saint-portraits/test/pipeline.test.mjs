import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const actualRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../../..");
const fixtureRoot = fs.mkdtempSync(path.join(os.tmpdir(), "klimax-saint-pipeline-"));
process.env.KLIMAX_REPO_ROOT = fixtureRoot;
process.env.SAINT_PIPELINE_TEST_MODE = "1";

function writeJson(relativePath, value) {
  const target = path.join(fixtureRoot, relativePath);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, `${JSON.stringify(value, null, 2)}\n`);
}

function copy(relativeSource, relativeDestination) {
  const destination = path.join(fixtureRoot, relativeDestination);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(path.join(actualRoot, relativeSource), destination);
}

for (const filename of [
  "saint-portrait-style.v1.json",
  "saint-portrait-pricing.v1.json",
  "saint-portrait-master-references.v1.json"
]) {
  copy(`config/${filename}`, `config/${filename}`);
}
const portraitSource = "Klimax/Assets.xcassets/petros.imageset/petros.png";
copy(portraitSource, portraitSource);
copy("Klimax/Assets.xcassets/petros.imageset/Contents.json", "Klimax/Assets.xcassets/petros.imageset/Contents.json");
copy(portraitSource, "sources/agios-test.png");
copy(portraitSource, "sources/aspect-fit-source.png");
const aspectFitFixture = spawnSync(
  "/usr/bin/sips",
  ["-z", "1536", "1024", path.join(fixtureRoot, "sources/aspect-fit-source.png")],
  { encoding: "utf8" }
);
assert.equal(aspectFitFixture.status, 0, aspectFitFixture.stderr);
writeJson("Klimax/saints.json", {
  schemaVersion: 1,
  language: "grc-polytonic",
  ranks: [{
    id: "apostoloi",
    titleGreek: "Ἀπόστολοι",
    titleEnglish: "Apostles",
    saints: [
      {
        id: "petros",
        name: "Ἀπόστολος Πέτρος",
        icon: "petros",
        rankTitle: "Ἀπόστολος",
        bio: ["Verified repository biography."],
        source: "Fixture",
        sourceUrl: "https://example.invalid/petros"
      },
      {
        id: "agios-test",
        name: "Ἅγιος Δοκιμή",
        rankTitle: "Ἀπόστολος",
        bio: ["Verified repository biography."],
        source: "Fixture",
        sourceUrl: "https://example.invalid/test"
      },
      {
        id: "missing",
        name: "Ἅγιος Χωρὶς Στοιχεῖα"
      }
    ]
  }]
});
writeJson("data/saint-portraits/metadata-overrides.v1.json", {
  schemaVersion: 1,
  records: {
    "agios-test": {
      identitySourceImagePath: "sources/agios-test.png",
      identitySourcePageUrl: "https://example.invalid/source-page",
      identitySourceDirectAssetUrl: "https://example.invalid/source.png",
      identitySourceCreator: "Fixture creator",
      identitySourceLicence: "Fixture licence",
      identitySourceInstitution: "Fixture institution",
      identitySourceAccessedAt: "2026-07-29",
      identitySourceChecksumSha256: "fixture-checksum",
      sourceLicenceOrRightsNotes: "Test fixture copied from an existing repository-owned completed portrait.",
      metadataSourceUrls: ["https://example.invalid/metadata"],
      metadataUncertaintyNotes: ["Fixture uncertainty."],
      traditionalPhysicalDescription: "Verified fixture description.",
      approximateAgeCategory: "adult",
      clothing: ["apostolic robe"],
      religiousRoleOrCategory: "apostle",
      identifyingObjectsOrSymbols: ["scroll"],
      requiredVisualAttributes: ["single saint", "scroll"],
      prohibitedOrUncertainAttributes: ["do not invent additional objects"]
    }
  }
});
writeJson("config/saint-portrait-priorities.v1.json", {
  schemaVersion: 1,
  records: {
    "agios-test": {
      priority: 10,
      group: "pilot",
      reason: "Fixture priority"
    }
  }
});

const repository = await import("../src/repository.mjs");
const promptModule = await import("../src/prompt.mjs");
const pipeline = await import("../src/pipeline.mjs");
const providers = await import("../src/providers.mjs");
const queue = await import("../src/queue.mjs");
const imageAnalysis = await import("../src/image-analysis.mjs");
const publish = await import("../src/publish.mjs");
const reviewServer = await import("../src/review-server.mjs");
const util = await import("../src/util.mjs");

test("saint portrait pipeline", async (t) => {
  await t.test("repository saint and completed-image discovery", () => {
    const discovery = repository.discoverSaints();
    assert.equal(discovery.saints.length, 3);
    const completed = repository.discoverCompletedPortraits();
    assert.deepEqual(completed.map((entry) => entry.saint.id), ["petros"]);
  });

  await t.test("inventory and representative style-reference selection", () => {
    const { inventory, references } = repository.buildCompletedInventory();
    assert.equal(inventory.totalCompleted, 1);
    assert.equal(references.references.length, 1);
    assert.equal(references.references[0].saintId, "petros");
    assert.ok(references.references[0].checksum);
  });

  await t.test("style configuration and manifest validation", () => {
    const style = util.readJson("config/saint-portrait-style.v1.json");
    assert.equal(style.styleVersion, "saint-portrait-style.v1");
    assert.equal(style.generationCanvas.format, "png");
    const { manifest, queue: builtQueue } = repository.buildManifest();
    assert.equal(manifest.recordCount, 3);
    assert.equal(manifest.records.find((entry) => entry.saintId === "petros").queueStatus, "published");
    const readyRecord = manifest.records.find((entry) => entry.saintId === "agios-test");
    assert.equal(readyRecord.queueStatus, "ready");
    assert.equal(readyRecord.identitySourceCreator, "Fixture creator");
    assert.equal(readyRecord.identitySourceLicence, "Fixture licence");
    assert.equal(readyRecord.generationPriority, 10);
    assert.equal(readyRecord.generationPriorityGroup, "pilot");
    assert.deepEqual(readyRecord.metadataSourceUrls, ["https://example.invalid/metadata"]);
    assert.equal(manifest.records.find((entry) => entry.saintId === "missing").queueStatus, "missing-metadata");
    assert.equal(builtQueue.records.length, 3);
  });

  await t.test("generation selection respects configured priority", () => {
    const selected = queue.selectRecords({ includeProtected: true });
    const testIndex = selected.findIndex((entry) => entry.record.saintId === "agios-test");
    const missingIndex = selected.findIndex((entry) => entry.record.saintId === "missing");
    assert.ok(testIndex < missingIndex);
  });

  await t.test("prompt construction labels identity and style reference roles", () => {
    const record = util.readJson(repository.repositoryPaths.manifest).records.find((entry) => entry.saintId === "agios-test");
    const request = promptModule.buildGenerationRequest(record);
    assert.match(request.prompt, /Identity reference image 1 establishes/);
    assert.match(request.prompt, /Completed application portrait references/);
    assert.match(request.prompt, /writing; labels; captions; watermarks/);
    assert.equal(request.styleReferences.length, 1);
    assert.equal(request.identityReference.creator, "Fixture creator");
    assert.equal(request.identityReference.licence, "Fixture licence");
  });

  await t.test("dry run does not select a live provider", () => {
    const result = spawnSync(process.execPath, [
      path.join(actualRoot, "tools/saint-portraits/cli.mjs"),
      "generate", "--limit", "1", "--saint-id", "agios-test"
    ], {
      cwd: actualRoot,
      env: { ...process.env, OPENAI_API_KEY: "must-not-be-used" },
      encoding: "utf8"
    });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /DRY RUN, no API contact/);
    assert.match(result.stdout, /no API request was made/);
  });

  await t.test("execution refuses to run without an explicit limit", () => {
    const result = spawnSync(process.execPath, [
      path.join(actualRoot, "tools/saint-portraits/cli.mjs"),
      "generate", "--execute", "--saint-id", "agios-test"
    ], {
      cwd: actualRoot,
      env: process.env,
      encoding: "utf8"
    });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /explicit positive whole-number --limit is required/);
  });

  await t.test("hard spending ceiling prevents queuing", () => {
    const plan = pipeline.planGeneration({
      limit: 1,
      saintId: "agios-test",
      execute: false,
      maxApiCost: 0.000001
    });
    assert.equal(plan.costReport.plannedCount, 0);
    assert.equal(plan.costReport.stoppedByCeiling, true);
  });

  await t.test("Batch preparation is local, bounded, and uses the configured image model", () => {
    const plan = pipeline.planGeneration({
      limit: 1,
      saintId: "agios-test",
      execute: false,
      batch: true,
      maxApiCost: 1
    });
    const prepared = pipeline.prepareBatch(plan);
    assert.equal(prepared.requestCount, 1);
    const line = JSON.parse(fs.readFileSync(prepared.absolutePath, "utf8").trim());
    assert.equal(line.url, "/v1/responses");
    assert.equal(line.body.tools[0].model, "gpt-image-2");
    assert.equal(line.body.tools[0].action, "edit");
  });

  await t.test("review server is local-only infrastructure with no generation route", () => {
    const server = reviewServer.createReviewServer();
    assert.equal(server.listening, false);
    assert.equal(server.listenerCount("request"), 1);
    const source = fs.readFileSync(path.join(actualRoot, "tools/saint-portraits/src/review-server.mjs"), "utf8");
    assert.doesNotMatch(source, /pathname\s*===\s*["']\/api\/generate/);
  });

  await t.test("test safeguard rejects a live provider", () => {
    assert.throws(() => new providers.OpenAIImageProvider({ apiKey: "not-real" }), /forbidden while tests/);
  });

  await t.test("reference uploads declare an API-supported MIME type", () => {
    assert.equal(providers.referenceMimeType("identity.jpg"), "image/jpeg");
    assert.equal(providers.referenceMimeType("identity.JPEG"), "image/jpeg");
    assert.equal(providers.referenceMimeType("style.png"), "image/png");
    assert.equal(providers.referenceMimeType("style.webp"), "image/webp");
    assert.throws(() => providers.referenceMimeType("reference.gif"), /Unsupported reference format/);
  });

  await t.test("mocked successful generation persists and routes to review", async () => {
    const plan = pipeline.planGeneration({
      limit: 1,
      saintId: "agios-test",
      execute: true,
      maxApiCost: 1
    });
    const fixtureBuffer = fs.readFileSync(path.join(fixtureRoot, portraitSource));
    const provider = new providers.MockImageProvider({ buffer: fixtureBuffer });
    const report = await pipeline.executeGeneration(plan, provider, { retries: 0 });
    assert.equal(provider.calls.length, 1);
    assert.equal(report.results.length, 1);
    assert.equal(report.results[0].status, "qa-review");
    assert.ok(fs.existsSync(report.results[0].candidatePath));
  });

  await t.test("malformed API response is rejected", async () => {
    const record = util.readJson(repository.repositoryPaths.manifest).records.find((entry) => entry.saintId === "agios-test");
    const request = promptModule.buildGenerationRequest(record);
    const provider = new providers.OpenAIImageProvider({
      client: { images: { edit: async () => ({ data: [{}] }) } },
      toFile: async () => ({ mockedUpload: true })
    });
    await assert.rejects(() => provider.generate(request), /missing base64 candidate/);
  });

  await t.test("rate limits retry and permanent errors do not", async () => {
    let rateCalls = 0;
    const value = await providers.withRetry(async () => {
      rateCalls += 1;
      if (rateCalls === 1) throw Object.assign(new Error("rate"), { status: 429 });
      return "ok";
    }, { retries: 2, wait: async () => {}, random: () => 0 });
    assert.equal(value, "ok");
    assert.equal(rateCalls, 2);
    let permanentCalls = 0;
    await assert.rejects(() => providers.withRetry(async () => {
      permanentCalls += 1;
      throw Object.assign(new Error("bad request"), { status: 400 });
    }, { retries: 2, wait: async () => {} }), /bad request/);
    assert.equal(permanentCalls, 1);
  });

  await t.test("queue restart, duplicate prevention, and failure selection", async () => {
    queue.transitionRecord("agios-test", "ready", { reason: "test-reset" });
    const record = util.readJson(repository.repositoryPaths.manifest).records.find((entry) => entry.saintId === "agios-test");
    const request = promptModule.buildGenerationRequest(record);
    const estimate = { estimatedUsd: 0.1 };
    const attempt = await queue.createAttempt(record, request, estimate, "synchronous");
    await assert.rejects(() => queue.createAttempt(record, request, estimate, "synchronous"), /Duplicate active request/);
    await queue.updateAttempt(record.saintId, attempt.id, { error: { message: "fixture" } }, "failed");
    const failures = queue.selectRecords({ retryFailed: true });
    assert.equal(failures.some((entry) => entry.record.saintId === "agios-test"), true);
  });

  await t.test("QA schema and deterministic filename", () => {
    const style = util.readJson("config/saint-portrait-style.v1.json");
    const qa = imageAnalysis.validateCandidateImage(
      path.join(fixtureRoot, portraitSource),
      style,
      new Set(),
      new Set()
    );
    assert.equal(qa.schemaVersion, 1);
    assert.ok(["passed", "review"].includes(qa.status));
    assert.ok(qa.checks.some((entry) => entry.id === "dimensions"));
    const record = util.readJson(repository.repositoryPaths.manifest).records.find((entry) => entry.saintId === "agios-test");
    assert.equal(publish.deterministicAssetName(record), "saint-agios-test");
  });

  await t.test("application conversion preserves the complete source aspect ratio", () => {
    const source = path.join(fixtureRoot, "sources/aspect-fit-source.png");
    const destination = path.join(fixtureRoot, "converted/aspect-fit-output.png");
    publish.convertForApplication(source, destination);
    const analysis = imageAnalysis.analyzeImage(destination);
    assert.equal(analysis.width, 683);
    assert.equal(analysis.height, 1024);
    assert.ok(Math.abs(analysis.aspectRatio - (2 / 3)) < 0.001);
  });

  await t.test("approved image protection, publishing, and rollback", () => {
    const manifest = util.readJson(repository.repositoryPaths.manifest);
    const record = manifest.records.find((entry) => entry.saintId === "agios-test");
    const candidate = record.attempts.find((entry) => entry.candidatePath)?.candidatePath;
    assert.ok(candidate);
    queue.transitionRecord("agios-test", "approved", {
      reason: "fixture-approval",
      patch: {
        reviewerStatus: "approved",
        approvedAssetPath: candidate,
        approvedTimestamp: new Date().toISOString(),
        portraitStatus: "approved"
      }
    });
    assert.throws(() => queue.transitionRecord("agios-test", "ready"), /Protected portrait/);
    const journal = publish.publishApproved("agios-test", {
      converter: (source, destination) => fs.copyFileSync(source, destination)
    });
    const saintsAfter = util.readJson(repository.repositoryPaths.saints);
    assert.equal(saintsAfter.ranks[0].saints.find((entry) => entry.id === "agios-test").icon, "saint-agios-test");
    publish.rollbackPublication(journal.publicationId);
    const saintsRestored = util.readJson(repository.repositoryPaths.saints);
    assert.equal(saintsRestored.ranks[0].saints.find((entry) => entry.id === "agios-test").icon, undefined);
  });
});
