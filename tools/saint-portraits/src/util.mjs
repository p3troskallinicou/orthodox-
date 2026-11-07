import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

export const ROOT = process.env.KLIMAX_REPO_ROOT
  ? path.resolve(process.env.KLIMAX_REPO_ROOT)
  : path.resolve(path.dirname(new URL(import.meta.url).pathname), "../../..");

export function resolveRoot(relativePath) {
  return path.resolve(ROOT, relativePath);
}

export function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(resolveRoot(relativePath), "utf8"));
}

export function readJsonAbsolute(absolutePath) {
  return JSON.parse(fs.readFileSync(absolutePath, "utf8"));
}

export function atomicWriteJson(relativePath, value) {
  const target = resolveRoot(relativePath);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  const temporary = `${target}.${process.pid}.${crypto.randomUUID()}.tmp`;
  fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(temporary, target);
}

export function atomicWriteBuffer(absolutePath, buffer) {
  fs.mkdirSync(path.dirname(absolutePath), { recursive: true });
  const temporary = `${absolutePath}.${process.pid}.${crypto.randomUUID()}.tmp`;
  fs.writeFileSync(temporary, buffer, { mode: 0o600 });
  fs.renameSync(temporary, absolutePath);
}

export function sha256File(absolutePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(absolutePath)).digest("hex");
}

export function slugify(value) {
  const transliterated = value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/ς/g, "σ")
    .replace(/[^a-z0-9\u0370-\u03ff]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return transliterated || crypto.createHash("sha1").update(value).digest("hex").slice(0, 12);
}

export function isoNow() {
  return new Date().toISOString();
}

export function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function parseArgs(argv) {
  const args = { _: [] };
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith("--")) {
      args._.push(token);
      continue;
    }
    const [rawKey, inline] = token.slice(2).split("=", 2);
    const key = rawKey.replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
    if (inline !== undefined) {
      args[key] = inline;
    } else if (argv[index + 1] && !argv[index + 1].startsWith("--")) {
      args[key] = argv[index + 1];
      index += 1;
    } else {
      args[key] = true;
    }
  }
  return args;
}

export function numberArg(value, name, { integer = false, minimum = 0 } = {}) {
  if (value === undefined || value === false) return undefined;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < minimum || (integer && !Number.isInteger(parsed))) {
    throw new Error(`--${name} must be ${integer ? "a whole number" : "a number"} of at least ${minimum}.`);
  }
  return parsed;
}

export function ensureWithinRoot(absolutePath) {
  const resolved = path.resolve(absolutePath);
  if (resolved !== ROOT && !resolved.startsWith(`${ROOT}${path.sep}`)) {
    throw new Error(`Path escapes repository root: ${absolutePath}`);
  }
  return resolved;
}

export function withFileLock(lockName, callback) {
  const lockDir = resolveRoot("data/saint-portraits/locks");
  fs.mkdirSync(lockDir, { recursive: true });
  const lockPath = path.join(lockDir, `${slugify(lockName)}.lock`);
  let descriptor;
  try {
    descriptor = fs.openSync(lockPath, "wx", 0o600);
    fs.writeFileSync(descriptor, JSON.stringify({ pid: process.pid, acquiredAt: isoNow() }));
  } catch (error) {
    if (error.code === "EEXIST") throw new Error(`Record is already locked: ${lockName}`);
    throw error;
  }
  try {
    return callback();
  } finally {
    if (descriptor !== undefined) fs.closeSync(descriptor);
    fs.rmSync(lockPath, { force: true });
  }
}

export async function withFileLockAsync(lockName, callback) {
  const lockDir = resolveRoot("data/saint-portraits/locks");
  fs.mkdirSync(lockDir, { recursive: true });
  const lockPath = path.join(lockDir, `${slugify(lockName)}.lock`);
  let descriptor;
  try {
    descriptor = fs.openSync(lockPath, "wx", 0o600);
    fs.writeFileSync(descriptor, JSON.stringify({ pid: process.pid, acquiredAt: isoNow() }));
  } catch (error) {
    if (error.code === "EEXIST") throw new Error(`Record is already locked: ${lockName}`);
    throw error;
  }
  try {
    return await callback();
  } finally {
    if (descriptor !== undefined) fs.closeSync(descriptor);
    fs.rmSync(lockPath, { force: true });
  }
}

export function roundMoney(value) {
  return Math.round((value + Number.EPSILON) * 1000000) / 1000000;
}
