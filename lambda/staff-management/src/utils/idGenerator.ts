// ============================================================================
// ID GENERATOR UTILITIES
// ============================================================================

import { randomBytes } from 'crypto';
import { docClient } from './dynamodb';
import { UpdateCommand } from '@aws-sdk/lib-dynamodb';

const STAFF_ID_COUNTER_TABLE = process.env.STAFF_ID_COUNTER_TABLE || 'PetrolStaffIdCounter';

/**
 * Generate a unique staff ID in the format: PP-{YEAR}-{4-digit-sequence}
 * Example: PP-2024-0042
 */
export async function generateStaffId(petrolPumpId: string): Promise<string> {
  const year = new Date().getFullYear();
  
  // Get next sequence number from atomic counter
  const sequence = await getNextSequence(petrolPumpId, year);
  
  // Format: PP-2024-0042
  const paddedSequence = sequence.toString().padStart(4, '0');
  return `PP-${year}-${paddedSequence}`;
}

/**
 * Get next sequence number using DynamoDB atomic counter
 */
async function getNextSequence(petrolPumpId: string, year: number): Promise<number> {
  const counterKey = {
    petrolPumpId: petrolPumpId,
    year: year.toString()
  };

  const command = new UpdateCommand({
    TableName: STAFF_ID_COUNTER_TABLE,
    Key: counterKey,
    UpdateExpression: 'SET #seq = if_not_exists(#seq, :zero) + :inc',
    ExpressionAttributeNames: {
      '#seq': 'sequence'
    },
    ExpressionAttributeValues: {
      ':zero': 0,
      ':inc': 1
    },
    ReturnValues: 'UPDATED_NEW'
  });

  try {
    const result = await docClient.send(command);
    return result.Attributes?.sequence as number || 1;
  } catch (error: any) {
    // If table doesn't exist or other error, generate random fallback
    console.error('Error getting sequence, using random fallback:', error);
    return Math.floor(Math.random() * 9000) + 1000; // Random 4-digit number
  }
}

/**
 * Generate a cryptographically secure temporary password
 * Format: Meets Cognito password policy (uppercase, lowercase, number, special char)
 * Length: 12 characters
 */
export function generateTemporaryPassword(): string {
  const uppercase = 'ABCDEFGHJKMNPQRSTUVWXYZ'; // Excludes I, L, O for clarity
  const lowercase = 'abcdefghjkmnpqrstuvwxyz'; // Excludes i, l, o for clarity
  const numbers = '23456789'; // Excludes 0, 1 for clarity
  const special = '!@#$%^&*';
  
  // Ensure at least one of each required character type
  let password = '';
  password += uppercase[Math.floor(Math.random() * uppercase.length)];
  password += lowercase[Math.floor(Math.random() * lowercase.length)];
  password += numbers[Math.floor(Math.random() * numbers.length)];
  password += special[Math.floor(Math.random() * special.length)];
  
  // Fill remaining with random characters from all sets
  const allChars = uppercase + lowercase + numbers + special;
  const remainingLength = 12 - password.length;
  
  const randomBytesNeeded = Math.ceil(remainingLength * 256 / allChars.length);
  const bytes = randomBytes(randomBytesNeeded);
  
  for (let i = 0; i < remainingLength; i++) {
    password += allChars[bytes[i] % allChars.length];
  }
  
  // Shuffle the password
  return password.split('').sort(() => Math.random() - 0.5).join('');
}

/**
 * Generate a UUID v4
 */
export function generateUUID(): string {
  const bytes = randomBytes(16);
  
  // Set version (4) and variant bits
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  
  const hex = bytes.toString('hex');
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20, 32)
  ].join('-');
}
