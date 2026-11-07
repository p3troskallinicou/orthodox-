# Klimax saint portrait pipeline

## Safety warning

> Codex should build and maintain this pipeline, but real portrait generation should be launched manually from a normal terminal. Do not ask Codex to generate the complete collection through Codex image generation.

The pipeline never runs from the iOS application. Every generation command is a dry run unless `--execute` is present. An authorised execution also requires an explicit `--limit`, a hard local cost ceiling, and terminal confirmation. Existing, approved, and published portraits are protected.

## Repository discovery

Klimax is a SwiftUI iOS application. Saint content follows the app’s existing Sanity, cache, and bundled fallback pattern.

| Purpose | Repository path |
| --- | --- |
| Bundled saint records | `Klimax/saints.json` |
| Swift model and Sanity query | `Klimax/SaintsCatalog.swift` |
| Published image assets | `Klimax/Assets.xcassets/<asset>.imageset` |
| Portrait pipeline | `tools/saint-portraits` |
| Editable configuration | `config/saint-portrait-*.v1.json` |
| Persistent manifest and queue | `data/saint-portraits` |

The repository currently contains 891 saint records, not approximately 950. Fifteen records have completed PNG portraits. All fifteen are male Apostles, so they establish the shared rendering language but do not establish female, monastic, hierarch, martyr, royal, or other category specific identity conventions.

Completed files are 1024 pixels high and 685 to 768 pixels wide. Fourteen are close to a 3 to 4 portrait ratio. The deterministic inventory records format, dimensions, checksum, edge colour, edge variance, dominant colours, transparency sampling, and an approximate non-background bounding box.

## Architecture

The command line application has separable layers:

1. `repository.mjs` discovers saints and completed assets, inventories images, selects references, and builds the manifest.
2. `prompt.mjs` distinguishes the saint identity source from the application style references and resolves a complete versioned prompt.
3. `costs.mjs` reads versioned pricing and produces per-request, per-run, and cumulative estimates.
4. `queue.mjs` maintains persistent states, attempt histories, record locks, duplicate prevention, restart safety, and approved image protection.
5. `providers.mjs` defines provider interfaces, the guarded official OpenAI SDK implementation, retries, mock providers, and Batch submission.
6. `pipeline.mjs` plans runs, enforces ceilings, executes synchronous requests, performs deterministic QA, and prepares Batch JSONL.
7. `review-server.mjs` serves a local human review interface. It cannot start generation.
8. `publish.mjs` converts only approved candidates, updates `saints.json`, creates the asset set, archives the previous state, and supports rollback.

The optional `openai` dependency is dynamically loaded only after an explicitly authorised execution. Tests set `SAINT_PIPELINE_TEST_MODE=1`; selecting a live provider in that environment fails immediately.

## Master style references

Run:

```bash
npm run saints:inventory
```

This performs deterministic analysis and writes:

* `data/saint-portraits/completed-inventory.v1.json`
* `config/saint-portrait-master-references.v1.json`

The selected set contains at most 12 existing files. It references assets in place and never duplicates or modifies them. Selection uses deterministic farthest point sampling across dimensions, edge colour, dominant colour, and approximate subject bounds. The current selected IDs are:

`petros`, `simon-zilotis`, `filippos`, `ioudas-thaddaios`, `matthaios`, `iakovos-zevedaiou`, `andreas`, `matthias`, `iakovos-alfaiou`, `paulos`, `thomas`, and `ioannis-theologos`.

All 12 selected references were visually inspected. Together they establish a warm ochre gold field, calm bust crop, complete thin outlined halo, icon inspired planar modelling, restrained vestment colours, quiet illumination, and no scenery or typography. The inventory marks painted lettering and hard borders in individual source files as accidental defects that must not be reproduced.

## Editable style configuration

`config/saint-portrait-style.v1.json` is the source of truth. It contains both measurable QA targets and the generation instruction. Editing it does not require an app build.

The Image API canvas is 1024 by 1536 because it is an API supported portrait size. Publishing converts the reviewed image to the app’s 768 by 1024 PNG format with a centered crop. Review the crop before approval.

## Saint metadata and source rights

Run:

```bash
npm run saints:manifest
```

The command builds one manifest record and one queue record for every bundled saint. Existing portraits become protected published records.

Metadata that is not in the repository is never inferred. Add reviewed fields to:

`data/saint-portraits/metadata-overrides.v1.json`

Each production candidate needs:

* A reviewed local identity image path
* Source licence or rights notes
* Traditional physical description
* Approximate age category
* Clothing
* Religious role or category
* Required visual attributes
* Any identifying objects
* Prohibited or uncertain attributes

An external URL is provenance metadata, not permission to scrape it. Downloading and rights verification happen outside this tool. A missing identity image or rights note remains in review and cannot execute.

After editing metadata, rebuild the manifest. Existing attempt history and reviewer fields are preserved.

## Installation and API project setup

Node 20 or later is recommended. From the repository root:

```bash
npm install
```

Create a dedicated OpenAI API project, set its platform budget and alerts, and export the key only in the terminal session used for the deliberate run:

```bash
export OPENAI_API_KEY="..."
```

The software never prints the key. Do not store it in the repository, an Xcode setting, app bundle, JSON file, or command history.

## Pricing and local cost ceilings

Pricing lives in `config/saint-portrait-pricing.v1.json`, not application logic. It records `lastVerifiedAt` and the official pricing source. Before every production run, verify the current [OpenAI image generation pricing](https://developers.openai.com/api/docs/pricing#image-generation) and update the configuration if necessary.

Estimates include text input, all identity and style image inputs, image output, a safety multiplier, and the configured Batch discount. They are deliberately conservative estimates, not invoices. Actual token usage and cost are stored separately when the API returns usage.

Every plan shows:

* Number of references per request
* Dimensions and quality
* Candidate count
* Estimated run cost
* Hard local ceiling
* Cumulative recorded estimate and actual cost

Use `--max-api-cost` on every deliberate run. The planner stops adding requests before the ceiling is crossed. A platform project budget remains the independent final safeguard.

## Dry run

No OpenAI client is created:

```bash
npm run saints:generate -- --dry-run --limit 10 --max-api-cost 1
```

Filters are available:

```bash
--saint-id ID
--slug SLUG
--status STATUS
--category RANK_ID
--retry-failed
```

## Exactly one pilot

Only after metadata, source rights, prompt, selected references, and estimate have been reviewed:

```bash
npm run saints:generate -- --execute --limit 1 --saint-id SAINT_ID --max-api-cost 1
```

The command prints the exact planned spend and requires an exact confirmation phrase. It generates one candidate and stops. It never continues into a larger run.

## Five image pilot

A deliberate noninteractive confirmation is mandatory above the one image interactive pilot:

```bash
npm run saints:generate -- --execute --limit 5 --max-api-cost 5 --confirm-spend
```

Concurrency defaults to one and is capped at four:

```bash
--concurrency 2
```

Retryable rate limit and server errors use bounded exponential backoff with jitter. Permanent validation and permission errors are not retried.

## Batch mode

Prepare and inspect a Batch JSONL file without uploading or submitting it:

```bash
npm run saints:batch -- --dry-run --limit 100 --max-api-cost 25
```

Prepared files are ignored by Git because they contain embedded source image data. Review the adjacent plan file and the cost report. Explicit submission is a separate command:

```bash
npm run saints:batch -- --execute --limit 100 --max-api-cost 25 --confirm-spend
```

Batch execution uploads the reviewed JSONL with the official SDK and records submitted attempts. It does not trigger a synchronous run and does not automatically continue into another batch.

## Human review

Start the local interface:

```bash
npm run saints:review
```

Open `http://127.0.0.1:4178`. The page shows identity source, candidate, selected style references, verified metadata, prompt and style versions, QA results, cost, and previous attempts.

Actions include approval, rejection, regeneration with required notes, metadata correction, and source rejection. Automated QA never publishes. The page has no generation endpoint.

## QA

Deterministic QA checks:

* PNG validity, dimensions, aspect ratio, and file size
* Edge background colour and variance
* Unexpected transparency
* Approximate subject edge clearance
* Duplicate output checksum
* Exact source image duplication

An optional vision QA provider interface evaluates composition, background, halo, text, watermark, border, clothing, attributes, duplicate objects, anatomy, and style similarity. It is mocked in tests and cannot publish.

## Publishing and rollback

Publish one human-approved candidate:

```bash
npm run saints:publish -- --saint-id SAINT_ID
```

Publishing creates `saint-<slug>.imageset`, writes a deterministic PNG, updates the bundled saint record atomically, stores checksum and style version, and archives the original candidate and previous state.

Existing portraits are protected. Replacing one requires an explicit reviewed replacement action and:

```bash
--replace-approved
```

Rollback with the publication ID printed by the publish command:

```bash
npm run saints:rollback -- --publication-id PUBLICATION_ID
```

## Tests

All tests use copied repository fixtures, mocks, and injected fake clients:

```bash
npm run test:saint-portraits
```

No test generates an image or contacts OpenAI. Coverage includes discovery, inventory, selection, configuration, manifest validation, prompt roles, dry-run safety, limit and ceiling refusal, mocked generation, malformed responses, retry behaviour, queue restart, duplicate prevention, protected images, deterministic naming, QA, publishing, and rollback.
