/**
 * Deduplication, source merging, and source attribution (Requirements 1.7, 1.8).
 *
 * Source scanners (task 4.2) emit `RawEndpoint` records — one per
 * (identity, source) sighting. This module folds those raw sightings into the
 * deduplicated `InventoryEntry[]`: endpoints sharing one identity collapse into
 * a single entry whose `sources` list is the de-duplicated union of every
 * contributing source (Requirement 1.8). Each retained entry is classified
 * into exactly one `Domain` (Requirement 1.6) and carries at least one
 * source reference (Requirement 1.7).
 *
 * Ordering of the returned entries is intentionally left to the caller
 * (task 4.3 owns deterministic sorting); these functions only guarantee
 * correct grouping, merging, and classification.
 */
import type { EndpointIdentity, InventoryEntry, SourceRef } from '../types';
import { classifyDomain } from './classification';
import { computeEndpointId } from './identity';

/**
 * A single endpoint sighting produced by a source scanner before
 * deduplication. The same logical endpoint may appear as many `RawEndpoint`
 * records, each attributing a different source.
 */
export interface RawEndpoint {
  identity: EndpointIdentity;
  /** The source this sighting was discovered from. */
  source: SourceRef;
}

/**
 * Build the deduplicated, classified, source-attributed inventory entries from
 * raw endpoint sightings.
 *
 * Identical identities (after normalization, via {@link computeEndpointId})
 * merge into one entry; their sources are unioned with duplicates removed.
 */
export function buildInventoryEntries(rawEndpoints: RawEndpoint[]): InventoryEntry[] {
  // First pass: group sightings by stable id, unioning their sources. The
  // identity of the first sighting per id is retained as the canonical one.
  const grouped = new Map<string, { identity: EndpointIdentity; sources: SourceRef[] }>();

  for (const raw of rawEndpoints) {
    const id = computeEndpointId(raw.identity);
    const existing = grouped.get(id);

    if (existing) {
      mergeSource(existing.sources, raw.source);
    } else {
      grouped.set(id, { identity: raw.identity, sources: [raw.source] });
    }
  }

  // Second pass: classify each entry against its full, merged source set so the
  // assigned domain does not depend on which sighting was encountered first.
  const entries: InventoryEntry[] = [];
  for (const [id, group] of grouped) {
    entries.push({
      id,
      identity: group.identity,
      domain: classifyDomain(group.identity, group.sources),
      sources: group.sources,
    });
  }

  return entries;
}

/**
 * Add a source to an entry's source list unless an identical source is already
 * present, keeping the union free of exact duplicates (Requirement 1.8).
 */
function mergeSource(sources: SourceRef[], candidate: SourceRef): void {
  const alreadyPresent = sources.some((existing) => sameSource(existing, candidate));
  if (!alreadyPresent) {
    sources.push(candidate);
  }
}

/** Two source references are equal when all of their fields match. */
function sameSource(a: SourceRef, b: SourceRef): boolean {
  return (
    a.filePath === b.filePath &&
    a.artifactType === b.artifactType &&
    (a.locator ?? '') === (b.locator ?? '')
  );
}
