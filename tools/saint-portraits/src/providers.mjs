import fs from "node:fs";
import path from "node:path";
import { resolveRoot, sleep } from "./util.mjs";

export class ImageProvider {
  async generate() {
    throw new Error("ImageProvider.generate must be implemented.");
  }
}

function liveProviderGuard({ injectedClient = false } = {}) {
  if ((process.env.SAINT_PIPELINE_TEST_MODE === "1" || process.env.NODE_ENV === "test") && !injectedClient) {
    throw new Error("Live provider selection is forbidden while tests are running.");
  }
}

function classifyProviderError(error) {
  const status = error?.status ?? error?.response?.status;
  const code = error?.code;
  const retryable = status === 408 || status === 409 || status === 429 || status >= 500 ||
    ["ECONNRESET", "ETIMEDOUT", "EAI_AGAIN"].includes(code);
  return {
    retryable,
    status: status ?? null,
    code: code ?? null,
    message: error?.message ?? String(error)
  };
}

export function referenceMimeType(filePath) {
  switch (path.extname(filePath).toLowerCase()) {
    case ".jpg":
    case ".jpeg":
      return "image/jpeg";
    case ".png":
      return "image/png";
    case ".webp":
      return "image/webp";
    default:
      throw new Error(`Unsupported reference format: ${filePath}`);
  }
}

export async function withRetry(operation, {
  retries = 2,
  baseDelayMs = 750,
  random = Math.random,
  wait = sleep,
  onRetry = () => {}
} = {}) {
  let attempt = 0;
  while (true) {
    try {
      return await operation(attempt);
    } catch (error) {
      const classified = classifyProviderError(error);
      if (!classified.retryable || attempt >= retries) {
        error.providerClassification = classified;
        throw error;
      }
      const delay = Math.round(baseDelayMs * 2 ** attempt * (0.75 + random() * 0.5));
      onRetry({ attempt: attempt + 1, delay, error: classified });
      await wait(delay);
      attempt += 1;
    }
  }
}

export class OpenAIImageProvider extends ImageProvider {
  constructor({ apiKey = process.env.OPENAI_API_KEY, client = null, toFile = null } = {}) {
    super();
    liveProviderGuard({ injectedClient: Boolean(client) });
    if (!apiKey && !client) throw new Error("OPENAI_API_KEY is required only for an explicitly authorised execution.");
    this.apiKey = apiKey;
    this.client = client;
    this.toFile = toFile;
  }

  async getClient() {
    if (this.client) return this.client;
    let module;
    try {
      module = await import("openai");
    } catch {
      throw new Error("The optional `openai` package is not installed. Run `npm install` before an authorised production request.");
    }
    this.client = new module.default({ apiKey: this.apiKey });
    return this.client;
  }

  async generate(request) {
    if (request.model !== "gpt-image-2") throw new Error("Production saint portraits must use gpt-image-2.");
    if (request.candidates !== 1) throw new Error("Exactly one candidate is permitted per request.");
    if (!request.identityReference.path) {
      throw new Error("Production execution requires a reviewed local identity source image.");
    }
    const allPaths = [
      request.identityReference.path,
      ...request.styleReferences.map((reference) => reference.imagePath)
    ];
    for (const relativePath of allPaths) {
      const absolutePath = resolveRoot(relativePath);
      if (!fs.existsSync(absolutePath) || !fs.statSync(absolutePath).isFile()) {
        throw new Error(`Reference image is missing: ${relativePath}`);
      }
      if (![".png", ".jpg", ".jpeg", ".webp"].includes(path.extname(absolutePath).toLowerCase())) {
        throw new Error(`Unsupported reference format: ${relativePath}`);
      }
    }
    const openai = await this.getClient();
    const sdk = this.toFile ? null : await import("openai");
    const toFile = this.toFile ?? sdk.toFile;
    const image = await Promise.all(allPaths.map(async (relativePath) =>
      toFile(
        fs.createReadStream(resolveRoot(relativePath)),
        path.basename(relativePath),
        { type: referenceMimeType(relativePath) }
      )
    ));
    const response = await openai.images.edit({
      model: request.model,
      image,
      prompt: request.prompt,
      n: 1,
      size: `${request.output.width}x${request.output.height}`,
      quality: request.output.quality,
      output_format: request.output.format,
      background: request.output.background
    });
    const item = response?.data?.[0];
    if (!item?.b64_json || typeof item.b64_json !== "string") {
      throw Object.assign(new Error("Malformed OpenAI image response: missing base64 candidate."), { permanent: true });
    }
    let buffer;
    try {
      buffer = Buffer.from(item.b64_json, "base64");
    } catch {
      throw Object.assign(new Error("Malformed OpenAI image response: invalid base64 candidate."), { permanent: true });
    }
    if (buffer.length < 8 || !buffer.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) {
      throw Object.assign(new Error("OpenAI image response was not a valid PNG."), { permanent: true });
    }
    return {
      buffer,
      mimeType: "image/png",
      requestId: response?._request_id ?? response?.id ?? null,
      usage: response?.usage ?? null,
      rawMetadata: {
        created: response?.created ?? null,
        model: request.model,
        revisedPrompt: item.revised_prompt ?? null
      }
    };
  }
}

export class MockImageProvider extends ImageProvider {
  constructor({ buffer, response = {}, failures = [] } = {}) {
    super();
    this.buffer = buffer;
    this.response = response;
    this.failures = [...failures];
    this.calls = [];
  }

  async generate(request) {
    this.calls.push(request);
    if (this.failures.length) throw this.failures.shift();
    if (!this.buffer) throw new Error("Mock provider has no fixture buffer.");
    return {
      buffer: this.buffer,
      mimeType: "image/png",
      requestId: this.response.requestId ?? "mock-request-id",
      usage: this.response.usage ?? {
        input_tokens: 100,
        input_tokens_details: { text_tokens: 40, image_tokens: 60 },
        output_tokens: 200,
        total_tokens: 300
      },
      rawMetadata: { mock: true }
    };
  }
}

export class VisionQAProvider {
  async evaluate() {
    throw new Error("VisionQAProvider.evaluate must be implemented.");
  }
}

export class MockVisionQAProvider extends VisionQAProvider {
  constructor(result = null) {
    super();
    this.result = result ?? {
      schemaVersion: 1,
      exactlyOnePrincipalSaint: true,
      expectedCropAndComposition: true,
      backgroundConsistent: true,
      haloConsistent: true,
      visibleText: false,
      watermark: false,
      border: false,
      expectedClothing: true,
      requiredAttributesPresent: true,
      duplicateObjects: false,
      anatomicalDefects: false,
      styleSimilarity: 0.9,
      confidence: 0.9,
      reasonsForReview: []
    };
  }

  async evaluate() {
    return this.result;
  }
}

export async function submitPreparedBatch(jsonlPath, { apiKey = process.env.OPENAI_API_KEY, client = null } = {}) {
  liveProviderGuard({ injectedClient: Boolean(client) });
  if (!apiKey && !client) throw new Error("OPENAI_API_KEY is required for explicit Batch submission.");
  let openai = client;
  let sdk;
  if (!openai) {
    try {
      sdk = await import("openai");
    } catch {
      throw new Error("The optional `openai` package is not installed. Run `npm install` before Batch submission.");
    }
    openai = new sdk.default({ apiKey });
  } else {
    sdk = await import("openai").catch(() => null);
  }
  if (!sdk?.toFile) throw new Error("The official OpenAI SDK is required for Batch submission.");
  const uploaded = await openai.files.create({
    file: await sdk.toFile(fs.createReadStream(jsonlPath), path.basename(jsonlPath)),
    purpose: "batch"
  });
  return openai.batches.create({
    input_file_id: uploaded.id,
    endpoint: "/v1/responses",
    completion_window: "24h",
    metadata: { pipeline: "klimax-saint-portraits" }
  });
}
