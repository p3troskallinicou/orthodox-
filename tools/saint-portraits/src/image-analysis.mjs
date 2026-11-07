import fs from "node:fs";
import zlib from "node:zlib";
import { sha256File } from "./util.mjs";

const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

function paeth(a, b, c) {
  const p = a + b - c;
  const pa = Math.abs(p - a);
  const pb = Math.abs(p - b);
  const pc = Math.abs(p - c);
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

function decodePng(buffer) {
  if (!buffer.subarray(0, 8).equals(PNG_SIGNATURE)) throw new Error("Not a PNG file.");
  let offset = 8;
  let width;
  let height;
  let bitDepth;
  let colorType;
  const idat = [];
  while (offset + 12 <= buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.toString("ascii", offset + 4, offset + 8);
    const data = buffer.subarray(offset + 8, offset + 8 + length);
    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
    } else if (type === "IDAT") {
      idat.push(data);
    } else if (type === "IEND") {
      break;
    }
    offset += 12 + length;
  }
  if (!width || !height || bitDepth !== 8 || ![0, 2, 4, 6].includes(colorType)) {
    throw new Error("Unsupported PNG layout. Only non-indexed 8-bit PNG files are supported.");
  }
  const channels = { 0: 1, 2: 3, 4: 2, 6: 4 }[colorType];
  const stride = width * channels;
  const inflated = zlib.inflateSync(Buffer.concat(idat));
  const pixels = Buffer.alloc(width * height * 4);
  let inputOffset = 0;
  let previous = Buffer.alloc(stride);
  for (let y = 0; y < height; y += 1) {
    const filter = inflated[inputOffset++];
    const raw = inflated.subarray(inputOffset, inputOffset + stride);
    inputOffset += stride;
    const current = Buffer.alloc(stride);
    for (let x = 0; x < stride; x += 1) {
      const left = x >= channels ? current[x - channels] : 0;
      const up = previous[x] ?? 0;
      const upperLeft = x >= channels ? previous[x - channels] : 0;
      if (filter === 0) current[x] = raw[x];
      else if (filter === 1) current[x] = (raw[x] + left) & 255;
      else if (filter === 2) current[x] = (raw[x] + up) & 255;
      else if (filter === 3) current[x] = (raw[x] + Math.floor((left + up) / 2)) & 255;
      else if (filter === 4) current[x] = (raw[x] + paeth(left, up, upperLeft)) & 255;
      else throw new Error(`Unsupported PNG filter ${filter}.`);
    }
    for (let x = 0; x < width; x += 1) {
      const source = x * channels;
      const destination = (y * width + x) * 4;
      if (colorType === 0 || colorType === 4) {
        pixels[destination] = current[source];
        pixels[destination + 1] = current[source];
        pixels[destination + 2] = current[source];
        pixels[destination + 3] = colorType === 4 ? current[source + 1] : 255;
      } else {
        pixels[destination] = current[source];
        pixels[destination + 1] = current[source + 1];
        pixels[destination + 2] = current[source + 2];
        pixels[destination + 3] = colorType === 6 ? current[source + 3] : 255;
      }
    }
    previous = current;
  }
  return { width, height, pixels, hasAlphaChannel: colorType === 4 || colorType === 6 };
}

function decodeJpegDimensions(buffer) {
  if (buffer[0] !== 0xff || buffer[1] !== 0xd8) throw new Error("Not a JPEG file.");
  let offset = 2;
  while (offset < buffer.length) {
    if (buffer[offset] !== 0xff) {
      offset += 1;
      continue;
    }
    const marker = buffer[offset + 1];
    const length = buffer.readUInt16BE(offset + 2);
    if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker)) {
      return { width: buffer.readUInt16BE(offset + 7), height: buffer.readUInt16BE(offset + 5) };
    }
    offset += 2 + length;
  }
  throw new Error("JPEG dimensions were not found.");
}

function rgbDistance(a, b) {
  return Math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2);
}

function summarizePixels({ width, height, pixels }) {
  const edgeSamples = [];
  const edgeStep = Math.max(1, Math.floor(Math.min(width, height) / 80));
  for (let x = 0; x < width; x += edgeStep) {
    for (const y of [0, Math.min(3, height - 1), height - 1]) {
      const index = (y * width + x) * 4;
      edgeSamples.push([pixels[index], pixels[index + 1], pixels[index + 2]]);
    }
  }
  for (let y = 0; y < height; y += edgeStep) {
    for (const x of [0, Math.min(3, width - 1), width - 1]) {
      const index = (y * width + x) * 4;
      edgeSamples.push([pixels[index], pixels[index + 1], pixels[index + 2]]);
    }
  }
  const mean = [0, 1, 2].map((channel) =>
    Math.round(edgeSamples.reduce((sum, sample) => sum + sample[channel], 0) / edgeSamples.length)
  );
  const variance = [0, 1, 2].map((channel) =>
    edgeSamples.reduce((sum, sample) => sum + (sample[channel] - mean[channel]) ** 2, 0) / edgeSamples.length
  );
  const standardDeviation = Math.sqrt(variance.reduce((sum, value) => sum + value, 0) / 3);

  const buckets = new Map();
  let transparentPixels = 0;
  let minX = width;
  let maxX = -1;
  let minY = height;
  let maxY = -1;
  const sampleStep = Math.max(1, Math.floor(Math.sqrt((width * height) / 120000)));
  for (let y = 0; y < height; y += sampleStep) {
    for (let x = 0; x < width; x += sampleStep) {
      const index = (y * width + x) * 4;
      const rgb = [pixels[index], pixels[index + 1], pixels[index + 2]];
      const alpha = pixels[index + 3];
      if (alpha < 250) transparentPixels += 1;
      const key = rgb.map((value) => Math.floor(value / 32) * 32).join(",");
      buckets.set(key, (buckets.get(key) ?? 0) + 1);
      if (alpha > 16 && rgbDistance(rgb, mean) > 62) {
        minX = Math.min(minX, x);
        maxX = Math.max(maxX, x);
        minY = Math.min(minY, y);
        maxY = Math.max(maxY, y);
      }
    }
  }
  const dominantColors = [...buckets.entries()]
    .sort((left, right) => right[1] - left[1])
    .slice(0, 8)
    .map(([rgb, count]) => ({ rgb: rgb.split(",").map(Number), sampleCount: count }));
  const subjectBounds = maxX >= 0
    ? {
        x: minX / width,
        y: minY / height,
        width: (maxX - minX + sampleStep) / width,
        height: (maxY - minY + sampleStep) / height
      }
    : null;
  return {
    edgeBackgroundRgb: mean,
    edgeBackgroundStandardDeviation: Math.round(standardDeviation * 100) / 100,
    dominantColors,
    subjectBounds,
    sampledTransparentFraction: transparentPixels / Math.ceil(width / sampleStep) / Math.ceil(height / sampleStep)
  };
}

export function analyzeImage(absolutePath) {
  const buffer = fs.readFileSync(absolutePath);
  const extension = absolutePath.toLowerCase().split(".").pop();
  if (extension === "png") {
    const decoded = decodePng(buffer);
    return {
      format: "png",
      width: decoded.width,
      height: decoded.height,
      aspectRatio: decoded.width / decoded.height,
      bytes: buffer.length,
      checksum: sha256File(absolutePath),
      hasAlphaChannel: decoded.hasAlphaChannel,
      ...summarizePixels(decoded)
    };
  }
  if (extension === "jpg" || extension === "jpeg") {
    const dimensions = decodeJpegDimensions(buffer);
    return {
      format: "jpeg",
      ...dimensions,
      aspectRatio: dimensions.width / dimensions.height,
      bytes: buffer.length,
      checksum: sha256File(absolutePath),
      hasAlphaChannel: false,
      deterministicPixelAnalysis: "unavailable-without-decoding"
    };
  }
  throw new Error(`Unsupported image format: ${extension}`);
}

export function validateCandidateImage(absolutePath, style, knownChecksums = new Set(), sourceChecksums = new Set()) {
  const analysis = analyzeImage(absolutePath);
  const canvas = style.generationCanvas;
  const targets = style.measurableTargets;
  const checks = [];
  const check = (id, passed, detail) => checks.push({ id, passed, detail });
  check("dimensions", analysis.width === canvas.width && analysis.height === canvas.height,
    `${analysis.width}x${analysis.height}, expected ${canvas.width}x${canvas.height}`);
  check("aspect-ratio", Math.abs(analysis.aspectRatio - canvas.aspectRatio) < 0.002,
    `${analysis.aspectRatio.toFixed(6)}, expected ${canvas.aspectRatio}`);
  check("format", analysis.format === canvas.format, `${analysis.format}, expected ${canvas.format}`);
  check("file-size", analysis.bytes >= targets.minimumFileBytes && analysis.bytes <= targets.maximumFileBytes,
    `${analysis.bytes} bytes`);
  if (analysis.edgeBackgroundRgb) {
    check("edge-background", rgbDistance(analysis.edgeBackgroundRgb, targets.edgeBackgroundRgb) <= targets.edgeBackgroundTolerance,
      `edge ${analysis.edgeBackgroundRgb.join(",")}`);
    check("edge-variance", analysis.edgeBackgroundStandardDeviation <= targets.maximumEdgeBackgroundStandardDeviation,
      `standard deviation ${analysis.edgeBackgroundStandardDeviation}`);
  }
  check("transparency", targets.allowTransparency || analysis.sampledTransparentFraction === 0,
    `sampled transparent fraction ${analysis.sampledTransparentFraction ?? 0}`);
  if (analysis.subjectBounds) {
    const right = analysis.subjectBounds.x + analysis.subjectBounds.width;
    check("subject-edge-clearance",
      analysis.subjectBounds.x >= targets.minimumSubjectEdgeClearanceFraction &&
      right <= 1 - targets.minimumSubjectEdgeClearanceFraction,
      JSON.stringify(analysis.subjectBounds));
  }
  check("duplicate-output", !knownChecksums.has(analysis.checksum), analysis.checksum);
  check("source-duplicate", !sourceChecksums.has(analysis.checksum), analysis.checksum);
  return {
    schemaVersion: 1,
    status: checks.every((entry) => entry.passed) ? "passed" : "review",
    checks,
    analysis
  };
}
