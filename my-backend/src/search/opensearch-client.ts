/**
 * OpenSearch Client Factory
 * 
 * Creates and configures OpenSearch client with AWS SigV4 signing.
 * Supports both OpenSearch Service and OpenSearch Serverless.
 * 
 * @author DukanX Engineering
 */

import { Client } from '@opensearch-project/opensearch';
import { AwsSigv4Signer } from '@opensearch-project/opensearch/aws';
import { defaultProvider } from '@aws-sdk/credential-provider-node';
import { config } from '../config/environment';

// Environment-based configuration
const OPENSEARCH_ENDPOINT = config.search.opensearchEndpoint || '';
const AWS_REGION = config.aws.region;

/**
 * Create OpenSearch client with AWS authentication
 */
export function createOpenSearchClient(): Client {
  if (!OPENSEARCH_ENDPOINT) {
    throw new Error('OPENSEARCH_ENDPOINT environment variable is required');
  }

  return new Client({
    ...AwsSigv4Signer({
      region: AWS_REGION,
      service: 'es', // 'es' for OpenSearch Service, 'aoss' for Serverless
      getCredentials: () => {
        const credentialsProvider = defaultProvider();
        return credentialsProvider();
      },
    }),
    node: OPENSEARCH_ENDPOINT,
  });
}

// Singleton client instance
let clientInstance: Client | null = null;

/**
 * Get or create OpenSearch client (singleton pattern)
 */
export function getOpenSearchClient(): Client {
  if (!clientInstance) {
    clientInstance = createOpenSearchClient();
  }
  return clientInstance;
}

/**
 * Reset client instance (useful for testing)
 */
export function resetOpenSearchClient(): void {
  clientInstance = null;
}

/**
 * Check if OpenSearch is configured
 */
export function isOpenSearchConfigured(): boolean {
  return !!OPENSEARCH_ENDPOINT;
}
