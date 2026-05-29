/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const childProcess = require('child_process');

const backendRoot = path.resolve(__dirname, '..');
const openapiPath = path.resolve(backendRoot, '..', 'docs', 'openapi.yaml');
const syncScriptPath = path.join(backendRoot, 'scripts', 'sync-openapi.js');

function hash(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

function run() {
  const before = fs.existsSync(openapiPath) ? fs.readFileSync(openapiPath, 'utf8') : '';
  const beforeHash = hash(before);

  childProcess.execFileSync(process.execPath, [syncScriptPath], {
    cwd: backendRoot,
    stdio: 'inherit',
  });

  const after = fs.readFileSync(openapiPath, 'utf8');
  const afterHash = hash(after);

  if (beforeHash !== afterHash) {
    console.error('OpenAPI drift detected. Run: npm run openapi:sync');
    process.exit(1);
  }

  console.log('OpenAPI drift check passed.');
}

run();
