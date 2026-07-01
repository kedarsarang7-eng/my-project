/**
 * GraphQL scanner (task 4.2, Requirement 1.4).
 *
 * Identifies GraphQL queries, mutations, and subscriptions from GraphQL source
 * text. Two shapes are recognized:
 *
 * 1. Schema definitions — the root `Query`, `Mutation`, and `Subscription`
 *    object types (and `extend type` extensions of them); each field on those
 *    types is one operation an API client can invoke.
 * 2. Operation documents — named `query`/`mutation`/`subscription` operations
 *    written against the schema.
 *
 * Parsing uses the `graphql` library. A parse failure throws so the surrounding
 * orchestrator (task 4.3) can record it as a per-file `StageIssue` and continue.
 */
import { parse, Kind } from 'graphql';
import type {
  DefinitionNode,
  OperationDefinitionNode,
  OperationTypeNode,
} from 'graphql';
import type { EndpointKind, SourceRef } from '../../types';
import type { RawEndpoint } from '../dedup';
import { dedupeWithinSource, graphqlEndpoint } from './scan-utils';

/** Map a GraphQL operation type to the corresponding endpoint kind. */
const KIND_BY_OPERATION: Record<string, Extract<EndpointKind, `graphql-${string}`>> = {
  query: 'graphql-query',
  mutation: 'graphql-mutation',
  subscription: 'graphql-subscription',
};

/** Root object type names that contribute callable operations. */
const ROOT_TYPE_KIND: Record<string, Extract<EndpointKind, `graphql-${string}`>> = {
  Query: 'graphql-query',
  Mutation: 'graphql-mutation',
  Subscription: 'graphql-subscription',
};

/**
 * Extract GraphQL endpoints from a block of GraphQL source text. The `source`
 * describes where the text came from (a `.graphql` file or an inline `gql`
 * template literal) so each sighting is attributed correctly.
 *
 * Throws if the text is not valid GraphQL.
 */
export function scanGraphqlSource(content: string, source: SourceRef): RawEndpoint[] {
  const trimmed = content.trim();
  if (trimmed === '') {
    return [];
  }

  const document = parse(trimmed);
  const raw: RawEndpoint[] = [];

  for (const definition of document.definitions) {
    collectFromDefinition(definition, source, raw);
  }

  return dedupeWithinSource(raw);
}

/** Dispatch a single GraphQL definition to the matching collector. */
function collectFromDefinition(
  definition: DefinitionNode,
  source: SourceRef,
  out: RawEndpoint[],
): void {
  // Root type definitions and extensions: each field is an operation.
  if (
    definition.kind === Kind.OBJECT_TYPE_DEFINITION ||
    definition.kind === Kind.OBJECT_TYPE_EXTENSION
  ) {
    const endpointKind = ROOT_TYPE_KIND[definition.name.value];
    if (endpointKind && definition.fields) {
      for (const field of definition.fields) {
        out.push(graphqlEndpoint(endpointKind, field.name.value, source));
      }
    }
    return;
  }

  // Named operation documents: the operation itself is the endpoint.
  if (definition.kind === Kind.OPERATION_DEFINITION) {
    const endpointKind = KIND_BY_OPERATION[definition.operation as OperationTypeNode];
    if (!endpointKind) {
      return;
    }
    const name = definition.name?.value ?? firstFieldName(definition);
    if (name) {
      out.push(graphqlEndpoint(endpointKind, name, source));
    }
  }
}

/** Fall back to the first selected field name for anonymous operations. */
function firstFieldName(definition: OperationDefinitionNode): string | undefined {
  for (const selection of definition.selectionSet.selections) {
    if (selection.kind === Kind.FIELD) {
      return selection.name.value;
    }
  }
  return undefined;
}
