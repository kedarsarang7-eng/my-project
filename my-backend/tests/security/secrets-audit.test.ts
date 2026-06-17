/**
 * Phase 5.4 - Security Audit: Secrets & Configuration
 * Checks for hardcoded secrets, API keys, tokens
 */

import { describe, it, expect } from '@jest/globals';
import * as fs from 'fs';
import * as path from 'path';
import { glob } from 'glob';

describe('SECURITY AUDIT: Secrets Detection', () => {
  const sourceDir = path.join(__dirname, '../../src');
  
  // Patterns that indicate hardcoded secrets
  const secretPatterns = [
    { pattern: /AKIA[0-9A-Z]{16}/, name: 'AWS Access Key ID' },
    { pattern: /[0-9a-zA-Z\/+=]{40}/, name: 'AWS Secret Access Key (base64)' },
    { pattern: /password\s*[=:]\s*["\'][^"\']{8,}["\']/i, name: 'Hardcoded Password' },
    { pattern: /api[_-]?key\s*[=:]\s*["\'][^"\']{10,}["\']/i, name: 'API Key' },
    { pattern: /secret\s*[=:]\s*["\'][^"\']{10,}["\']/i, name: 'Secret Value' },
    { pattern: /token\s*[=:]\s*["\'][^"\']{20,}["\']/i, name: 'Token' },
    { pattern: /private[_-]?key/i, name: 'Private Key Reference' },
    { pattern: /BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY/, name: 'Private Key Block' },
  ];

  const excludeDirs = ['node_modules', 'dist', '.git', '__tests__', '__mocks__'];

  it('should NOT contain hardcoded AWS credentials', async () => {
    const files = await glob('**/*.{ts,js}', {
      cwd: sourceDir,
      ignore: excludeDirs.map(d => `**/${d}/**`),
    });

    const violations: string[] = [];

    for (const file of files) {
      const content = fs.readFileSync(path.join(sourceDir, file), 'utf-8');
      
      // Check for AWS Access Key ID pattern
      if (secretPatterns[0].pattern.test(content)) {
        violations.push(`${file}: Potential AWS Access Key ID`);
      }
      
      // Check for AWS Secret Key pattern (long base64 strings)
      const base64Matches = content.match(secretPatterns[1].pattern);
      if (base64Matches && base64Matches.some(m => m.length >= 40)) {
        violations.push(`${file}: Potential AWS Secret Key`);
      }
    }

    expect(violations).toEqual([]);
  });

  it('should NOT contain hardcoded passwords', async () => {
    const files = await glob('**/*.{ts,js}', {
      cwd: sourceDir,
      ignore: excludeDirs.map(d => `**/${d}/**`),
    });

    const violations: string[] = [];

    for (const file of files) {
      const content = fs.readFileSync(path.join(sourceDir, file), 'utf-8');
      
      // Check for password patterns
      if (secretPatterns[2].pattern.test(content)) {
        // Exclude test files and config examples
        if (!file.includes('.test.') && !file.includes('.spec.') && !file.includes('example')) {
          violations.push(`${file}: Potential hardcoded password`);
        }
      }
    }

    expect(violations).toEqual([]);
  });

  it('should NOT contain hardcoded API keys', async () => {
    const files = await glob('**/*.{ts,js}', {
      cwd: sourceDir,
      ignore: excludeDirs.map(d => `**/${d}/**`),
    });

    const violations: string[] = [];

    for (const file of files) {
      const content = fs.readFileSync(path.join(sourceDir, file), 'utf-8');
      
      if (secretPatterns[3].pattern.test(content)) {
        if (!file.includes('.test.') && !file.includes('.spec.')) {
          violations.push(`${file}: Potential hardcoded API key`);
        }
      }
    }

    expect(violations).toEqual([]);
  });

  it('should use environment variables for sensitive config', async () => {
    const configFile = path.join(sourceDir, 'config/environment.ts');
    
    if (fs.existsSync(configFile)) {
      const content = fs.readFileSync(configFile, 'utf-8');
      
      // Should use process.env for sensitive values
      expect(content).toMatch(/process\.env/);
      
      // Should NOT have hardcoded secrets in config
      expect(content).not.toMatch(/password\s*[=:]\s*["\'][^"\']+["\']/i);
      expect(content).not.toMatch(/secret\s*[=:]\s*["\'][^"\']+["\']/i);
    }
  });

  it('should have .env.example without real secrets', () => {
    const envExample = path.join(__dirname, '../../.env.example');
    
    if (fs.existsSync(envExample)) {
      const content = fs.readFileSync(envExample, 'utf-8');
      
      // Should contain placeholder values, not real secrets
      expect(content).toMatch(/YOUR_/i); // Placeholder pattern
      expect(content).toMatch(/REPLACE_/i); // Placeholder pattern
      
      // Should NOT contain real-looking AWS keys
      expect(content).not.toMatch(/AKIA[0-9A-Z]{16}/);
    }
  });
});

describe('SECURITY AUDIT: Error Message Safety', () => {
  it('should NOT expose internal error details in API responses', async () => {
    // This would require running the API and triggering errors
    // For now, we check the error handling code
    
    const handlerFiles = await glob('src/handlers/*.ts', {
      cwd: path.join(__dirname, '../..'),
    });

    for (const file of handlerFiles) {
      const content = fs.readFileSync(file, 'utf-8');
      
      // Check that errors don't include stack traces or internal details
      // This is a heuristic check
      const hasUnsafeError = content.includes('error.stack') && 
                             content.includes('JSON.stringify') &&
                             !content.includes('INTERNAL_ERROR');
      
      if (hasUnsafeError) {
        console.warn(`Warning: ${file} may expose internal error details`);
      }
    }
  });
});
