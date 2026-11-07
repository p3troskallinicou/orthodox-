import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import {
  atomicWriteJson,
  isoNow,
  readJson,
  resolveRoot,
  sha256File,
  withFileLock
} from "./util.mjs";
import { repositoryPaths } from "./repository.mjs";
import { transitionRecord } from "./queue.mjs";

function findSaintRecord(data, saintId) {
  for (const rank of data.ranks) {
    const saint = rank.saints.find((entry) => entry.id === saintId);
    if (saint) return saint;
  }
  return null;
}

export function deterministicAssetName(record) {
  return `saint-${record.slug}`;
}

function runSips(args) {
  const result = spawnSync("/usr/bin/sips", args, { encoding: "utf8" });
  if (result.status !== 0) throw new Error(`Image conversion failed: ${result.stderr || result.stdout}`);
}

function imageDimensions(sourcePath) {
  const result = spawnSync(
    "/usr/bin/sips",
    ["-g", "pixelWidth", "-g", "pixelHeight", sourcePath],
    { encoding: "utf8" }
  );
  if (result.status !== 0) {
    throw new Error(`Could not read image dimensions: ${result.stderr || result.stdout}`);
  }
  const width = Number(result.stdout.match(/pixelWidth:\s*(\d+)/)?.[1]);
  const height = Number(result.stdout.match(/pixelHeight:\s*(\d+)/)?.[1]);
  if (!width || !height) throw new Error(`Invalid image dimensions: ${sourcePath}`);
  return { width, height };
}

export function convertForApplication(sourcePath, destinationPath, style = readJson("config/saint-portrait-style.v1.json")) {
  const target = style.applicationAsset;
  fs.mkdirSync(path.dirname(destinationPath), { recursive: true });
  const finalTemporary = `${destinationPath}.${process.pid}.final.png`;
  const source = imageDimensions(sourcePath);
  const sourceRatio = source.width / source.height;
  const targetRatio = target.width / target.height;

  // The application asset dimensions are a bounding box, not a crop box.
  // Keeping the approved composition intact is essential because a centered
  // crop can remove the top of a halo even when the source passed review.
  if (sourceRatio < targetRatio) {
    const resizedWidth = Math.max(1, Math.round(target.height * sourceRatio));
    runSips(["-z", String(target.height), String(resizedWidth), sourcePath, "--out", finalTemporary]);
  } else {
    const resizedHeight = Math.max(1, Math.round(target.width / sourceRatio));
    runSips(["-z", String(resizedHeight), String(target.width), sourcePath, "--out", finalTemporary]);
  }
  fs.renameSync(finalTemporary, destinationPath);
}

function contentsJson(filename) {
  return {
    images: [
      { filename, idiom: "universal", scale: "1x" },
      { idiom: "universal", scale: "2x" },
      { idiom: "universal", scale: "3x" }
    ],
    info: { author: "xcode", version: 1 }
  };
}

export function publishApproved(saintId, {
  replaceApproved = false,
  converter = convertForApplication
} = {}) {
  return withFileLock(`publish-${saintId}`, () => {
    const manifest = readJson(repositoryPaths.manifest);
    const record = manifest.records.find((entry) => entry.saintId === saintId);
    if (!record) throw new Error(`Unknown saint ID: ${saintId}`);
    if (record.queueStatus !== "approved" || record.reviewerStatus !== "approved" || !record.approvedAssetPath) {
      throw new Error("Only a human-approved candidate may be published.");
    }
    const saintsData = readJson(repositoryPaths.saints);
    const saint = findSaintRecord(saintsData, saintId);
    if (!saint) throw new Error(`Saint application record was not found: ${saintId}`);
    if (saint.icon && !replaceApproved) {
      throw new Error(`Existing portrait ${saint.icon} is protected. Use an explicit replacement action after review.`);
    }
    const source = resolveRoot(record.approvedAssetPath);
    if (!fs.existsSync(source)) throw new Error("Approved candidate file is missing.");
    const assetName = deterministicAssetName(record);
    const imagesetRelative = `${repositoryPaths.assets}/${assetName}.imageset`;
    const imagesetAbsolute = resolveRoot(imagesetRelative);
    if (fs.existsSync(imagesetAbsolute) && !replaceApproved) {
      throw new Error(`Destination asset already exists: ${imagesetRelative}`);
    }
    const publicationId = `${saintId}-${Date.now()}`;
    const archiveRelative = `data/saint-portraits/archive/${publicationId}`;
    const archiveAbsolute = resolveRoot(archiveRelative);
    fs.mkdirSync(archiveAbsolute, { recursive: true });
    fs.copyFileSync(resolveRoot(repositoryPaths.saints), path.join(archiveAbsolute, "saints.before.json"));
    fs.copyFileSync(source, path.join(archiveAbsolute, "approved-original.png"));
    if (fs.existsSync(imagesetAbsolute)) {
      fs.cpSync(imagesetAbsolute, path.join(archiveAbsolute, "previous.imageset"), { recursive: true });
    }
    const staging = `${imagesetAbsolute}.${process.pid}.staging`;
    fs.mkdirSync(staging, { recursive: true });
    const filename = `${assetName}.png`;
    converter(source, path.join(staging, filename));
    fs.writeFileSync(path.join(staging, "Contents.json"), `${JSON.stringify(contentsJson(filename), null, 2)}\n`);
    if (fs.existsSync(imagesetAbsolute)) fs.rmSync(imagesetAbsolute, { recursive: true, force: true });
    fs.renameSync(staging, imagesetAbsolute);
    const previousIcon = saint.icon ?? null;
    saint.icon = assetName;
    atomicWriteJson(repositoryPaths.saints, saintsData);
    const checksum = sha256File(path.join(imagesetAbsolute, filename));
    const journal = {
      schemaVersion: 1,
      publicationId,
      publishedAt: isoNow(),
      saintId,
      assetName,
      imagesetPath: imagesetRelative,
      archivePath: archiveRelative,
      previousIcon,
      checksum,
      styleVersion: record.styleVersion,
      rolledBackAt: null
    };
    atomicWriteJson(`${archiveRelative}/publication.json`, journal);
    transitionRecord(saintId, "published", {
      reason: "approved-asset-published",
      explicitReplacement: true,
      patch: {
        portraitStatus: "published",
        completedPortraitPath: `${imagesetRelative}/${filename}`,
        publishedChecksum: checksum,
        publicationId
      }
    });
    return journal;
  });
}

export function rollbackPublication(publicationId) {
  const relative = `data/saint-portraits/archive/${publicationId}`;
  const journalPath = `${relative}/publication.json`;
  if (!fs.existsSync(resolveRoot(journalPath))) throw new Error(`Publication journal not found: ${publicationId}`);
  const journal = readJson(journalPath);
  if (journal.rolledBackAt) throw new Error("Publication was already rolled back.");
  return withFileLock(`rollback-${journal.saintId}`, () => {
    const imageset = resolveRoot(journal.imagesetPath);
    const previous = resolveRoot(`${relative}/previous.imageset`);
    if (fs.existsSync(imageset)) fs.rmSync(imageset, { recursive: true, force: true });
    if (fs.existsSync(previous)) fs.cpSync(previous, imageset, { recursive: true });
    fs.copyFileSync(resolveRoot(`${relative}/saints.before.json`), resolveRoot(repositoryPaths.saints));
    journal.rolledBackAt = isoNow();
    atomicWriteJson(journalPath, journal);
    transitionRecord(journal.saintId, "approved", {
      reason: "publication-rolled-back",
      explicitReplacement: true,
      patch: { portraitStatus: "approved", publicationId: null }
    });
    return journal;
  });
}
