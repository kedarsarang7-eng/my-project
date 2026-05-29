// ============================================================================
// AWS X-RAY TRACING - Distributed tracing for Lambda functions
// ============================================================================

import AWSXRay from 'aws-xray-sdk-core';
import { captureAWSv3Client } from 'aws-xray-sdk-core';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';
import { S3Client } from '@aws-sdk/client-s3';
import { SNSClient } from '@aws-sdk/client-sns';
import { SQSClient } from '@aws-sdk/client-sqs';

// Capture AWS SDK clients for automatic tracing
const dynamoClient = captureAWSv3Client(new DynamoDBClient({}));
export const docClient = DynamoDBDocumentClient.from(dynamoClient);

const s3Client = captureAWSv3Client(new S3Client({}));
const snsClient = captureAWSv3Client(new SNSClient({}));
const sqsClient = captureAWSv3Client(new SQSClient({}));

/**
 * Trace wrapper for Lambda handlers with X-Ray
 */
export function withTracing(handlerName, handler) {
  return async (event, context) => {
    // Get current segment from Lambda runtime
    const segment = AWSXRay.getSegment();
    
    if (segment) {
      // Add handler name as annotation
      segment.addAnnotation('handler', handlerName);
      segment.addAnnotation('requestId', context.requestId);
      
      // Add tenant info if available
      if (event.headers?.['x-tenant-id'] || event.headers?.['X-Tenant-ID']) {
        segment.addAnnotation('tenantId', 
          event.headers['x-tenant-id'] || event.headers['X-Tenant-ID']
        );
      }
      
      // Create subsegment for handler
      const subsegment = segment.addNewSubsegment(`lambda:${handlerName}`);
      AWSXRay.setSegment(subsegment);
      
      try {
        // Add metadata
        subsegment.addMetadata('event', JSON.stringify(event), 'request');
        subsegment.addMetadata('lambdaContext', JSON.stringify({
          functionName: context.functionName,
          memoryLimitInMB: context.memoryLimitInMB,
          invokedFunctionArn: context.invokedFunctionArn,
          awsRequestId: context.awsRequestId,
        }), 'context');
        
        const result = await handler(event, context);
        
        // Add success metadata
        subsegment.addMetadata('statusCode', result.statusCode, 'response');
        subsegment.addAnnotation('success', true);
        
        subsegment.close();
        AWSXRay.setSegment(segment);
        
        return result;
        
      } catch (error) {
        // Add error info
        subsegment.addError(error);
        subsegment.addAnnotation('success', false);
        subsegment.addAnnotation('errorType', error.name);
        subsegment.addAnnotation('errorMessage', error.message);
        
        subsegment.close();
        AWSXRay.setSegment(segment);
        
        throw error;
      }
    }
    
    // No segment available (shouldn't happen in Lambda), run handler normally
    return handler(event, context);
  };
}

/**
 * Create custom subsegment for traced operations
 */
export async function traceSegment(name, operation, metadata = {}) {
  const parentSegment = AWSXRay.getSegment();
  
  if (!parentSegment) {
    // No tracing available, just run operation
    return operation();
  }
  
  const subsegment = parentSegment.addNewSubsegment(name);
  
  // Add metadata
  for (const [key, value] of Object.entries(metadata)) {
    subsegment.addMetadata(key, value);
  }
  
  try {
    const result = await operation();
    subsegment.close();
    return result;
  } catch (error) {
    subsegment.addError(error);
    subsegment.close();
    throw error;
  }
}

/**
 * Trace DynamoDB operation
 */
export async function traceDynamoDB(operation, tableName, operationType) {
  return traceSegment(
    `DynamoDB:${operationType}`,
    operation,
    { tableName, operationType }
  );
}

/**
 * Trace external API call
 */
export async function traceExternalAPI(operation, serviceName, endpoint) {
  return traceSegment(
    `ExternalAPI:${serviceName}`,
    operation,
    { serviceName, endpoint }
  );
}

/**
 * Add annotation to current segment
 */
export function addAnnotation(key, value) {
  const segment = AWSXRay.getSegment();
  if (segment) {
    segment.addAnnotation(key, value);
  }
}

/**
 * Add metadata to current segment
 */
export function addMetadata(key, value, namespace = 'custom') {
  const segment = AWSXRay.getSegment();
  if (segment) {
    segment.addMetadata(key, value, namespace);
  }
}
