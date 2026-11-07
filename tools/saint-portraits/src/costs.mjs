import { readJson, roundMoney } from "./util.mjs";

export function estimateRequestCost(request, { batch = false, pricing = readJson("config/saint-portrait-pricing.v1.json") } = {}) {
  const estimates = pricing.estimation;
  const referenceCount = 1 + request.styleReferences.length;
  const textTokens = Math.ceil(request.prompt.length / estimates.textCharactersPerToken);
  const imageInputTokens = referenceCount * estimates.estimatedInputImageTokensEach;
  const outputTokens = estimates.estimatedOutputTokensByQuality[request.output.quality];
  if (!outputTokens) throw new Error(`No output token estimate for quality ${request.output.quality}.`);
  const base =
    (textTokens / 1_000_000) * pricing.perMillionTokens.textInput +
    (imageInputTokens / 1_000_000) * pricing.perMillionTokens.imageInput +
    (outputTokens / 1_000_000) * pricing.perMillionTokens.imageOutput;
  const discount = batch ? estimates.batchDiscountMultiplier : 1;
  return {
    pricingVersion: pricing.pricingVersion,
    lastVerifiedAt: pricing.lastVerifiedAt,
    mode: batch ? "batch" : "synchronous",
    referenceImageCount: referenceCount,
    estimatedTextInputTokens: textTokens,
    estimatedImageInputTokens: imageInputTokens,
    estimatedImageOutputTokens: outputTokens,
    safetyMultiplier: estimates.safetyMultiplier,
    discountMultiplier: discount,
    estimatedUsd: roundMoney(base * estimates.safetyMultiplier * discount)
  };
}

export function buildCostReport(requests, { batch = false, maxApiCost } = {}) {
  const pricing = readJson("config/saint-portrait-pricing.v1.json");
  const items = [];
  let total = 0;
  for (const request of requests) {
    const estimate = estimateRequestCost(request, { batch, pricing });
    if (maxApiCost !== undefined && total + estimate.estimatedUsd > maxApiCost + Number.EPSILON) break;
    total += estimate.estimatedUsd;
    items.push({ saintId: request.saintId, ...estimate });
  }
  return {
    pricingVersion: pricing.pricingVersion,
    pricingLastVerifiedAt: pricing.lastVerifiedAt,
    requestedCount: requests.length,
    plannedCount: items.length,
    stoppedByCeiling: items.length < requests.length,
    estimatedTotalUsd: roundMoney(total),
    hardCeilingUsd: maxApiCost,
    dimensions: requests[0]?.output ? `${requests[0].output.width}x${requests[0].output.height}` : null,
    quality: requests[0]?.output?.quality ?? null,
    outputsPerRequest: 1,
    items
  };
}

export function actualCostFromUsage(usage, pricing = readJson("config/saint-portrait-pricing.v1.json")) {
  if (!usage) return null;
  const imageInput = usage.input_tokens_details?.image_tokens ?? 0;
  const textInput = usage.input_tokens_details?.text_tokens ?? Math.max(0, (usage.input_tokens ?? 0) - imageInput);
  const output = usage.output_tokens ?? 0;
  return roundMoney(
    (imageInput / 1_000_000) * pricing.perMillionTokens.imageInput +
    (textInput / 1_000_000) * pricing.perMillionTokens.textInput +
    (output / 1_000_000) * pricing.perMillionTokens.imageOutput
  );
}
