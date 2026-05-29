// ============================================================================
// DynamoDB Error Handling Utilities
// ============================================================================
// Standardized error handling for DynamoDB operations across all Lambda functions.
// Converts DynamoDB-specific errors to HTTP status codes and user-facing messages.
// ============================================================================

import { logger } from './logger';
import { AppError } from './errors';

export class DynamoDBOperationError extends AppError {
  constructor(
    operation: string,
    cause: string,
    statusCode = 500,
    code = 'DDB_OPERATION_ERROR'
  ) {
    super(`DynamoDB ${operation} failed: ${cause}`, statusCode, code);
  }
}

/**
 * Wrapper for DynamoDB operations with automatic error handling.
 * Converts ConditionalCheckFailedException → 409 Conflict
 * Converts ValidationException → 400 Bad Request
 * Logs all other errors to CloudWatch
 *
 * Usage:
 *   const result = await safeDynamoDbOperation(
 *     'adjustStock',
 *     () => inventory.adjustStock(tenantId, data),
 *     { tenantId, productId: data.productId }
 *   );
 */
export async function safeDynamoDbOperation<T>(
  operationName: string,
  operation: () => Promise<T>,
  context?: Record<string, unknown>
): Promise<T> {
  try {
    return await operation();
  } catch (err: any) {
    const errorName = err.name || 'UnknownError';
    const errorMessage = err.message || String(err);

    logger.error(`DynamoDB operation failed: ${operationName}`, {
      errorName,
      errorMessage,
      context,
    });

    // Handle specific DynamoDB errors
    if (errorName === 'ConditionalCheckFailedException') {
      // 409 Conflict — condition expression failed (e.g., stock insufficient)
      throw new DynamoDBOperationError(
        operationName,
        'Conditional check failed (likely insufficient inventory)',
        409,
        'CONDITIONAL_CHECK_FAILED'
      );
    }

    if (errorName === 'ValidationException') {
      // 400 Bad Request — invalid request format
      throw new DynamoDBOperationError(
        operationName,
        `Invalid request: ${errorMessage}`,
        400,
        'VALIDATION_ERROR'
      );
    }

    if (errorName === 'ResourceNotFoundException') {
      // 404 Not Found — table/index doesn't exist
      throw new DynamoDBOperationError(
        operationName,
        'Table or index not found',
        404,
        'NOT_FOUND'
      );
    }

    if (errorName === 'ProvisionedThroughputExceededException') {
      // 429 Too Many Requests — throttling
      throw new DynamoDBOperationError(
        operationName,
        'DynamoDB throttled',
        429,
        'THROTTLED'
      );
    }

    if (errorName === 'TransactionCanceledException') {
      // Analyze which transaction items failed
      const reasons = (err as any).CancelledTransactionReasons || [];
      const failedReasons = reasons
        .map((r: any, i: number) => {
          const code = r?.Code || 'Unknown';
          const message = r?.Message || '';
          return `Item ${i}: ${code}${message ? ` (${message})` : ''}`;
        })
        .join('; ');

      throw new DynamoDBOperationError(
        operationName,
        `Transaction cancelled: ${failedReasons}`,
        409,
        'TRANSACTION_CANCELLED'
      );
    }

    if (errorName === 'ItemCollectionSizeLimitExceededException') {
      // 400 — Item collection too large (usually for GSI writes)
      throw new DynamoDBOperationError(
        operationName,
        'Item collection size limit exceeded (GSI partition too large)',
        400,
        'ITEM_COLLECTION_SIZE_LIMIT'
      );
    }

    // 500 Internal Server Error — unexpected error
    throw new DynamoDBOperationError(
      operationName,
      errorMessage,
      500,
      'INTERNAL_ERROR'
    );
  }
}

/**
 * Safe wrapper specifically for conditional write operations.
 * Handles ConditionalCheckFailedException with detailed error context.
 */
export async function safeConditionalWrite<T>(
  operationName: string,
  operation: () => Promise<T>,
  failureMessage: string,
  context?: Record<string, unknown>
): Promise<T> {
  try {
    return await operation();
  } catch (err: any) {
    if (err.name === 'ConditionalCheckFailedException') {
      logger.warn(`Conditional check failed: ${operationName}`, { context });
      throw new DynamoDBOperationError(
        operationName,
        failureMessage,
        409,
        'CONDITIONAL_CHECK_FAILED'
      );
    }
    // Re-throw other errors to be handled by caller
    throw err;
  }
}
