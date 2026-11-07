import { atomicWriteJson, readJson } from "./util.mjs";
import { repositoryPaths } from "./repository.mjs";

export function mergeSaintCatalogAdditions(additionsPath) {
  const catalog = readJson(repositoryPaths.saints);
  const additions = readJson(additionsPath);
  const rankById = new Map(catalog.ranks.map((rank) => [rank.id, rank]));
  const existingIds = new Set(
    catalog.ranks.flatMap((rank) => rank.saints.map((saint) => saint.id))
  );
  const added = [];
  const skipped = [];

  for (const entry of additions.records) {
    if (existingIds.has(entry.saint.id)) {
      skipped.push(entry.saint.id);
      continue;
    }
    const rank = rankById.get(entry.rankId);
    if (!rank) throw new Error(`Unknown saint rank: ${entry.rankId}`);
    rank.saints.push(entry.saint);
    existingIds.add(entry.saint.id);
    added.push(entry.saint.id);
  }

  atomicWriteJson(repositoryPaths.saints, catalog);
  return { added, skipped };
}
