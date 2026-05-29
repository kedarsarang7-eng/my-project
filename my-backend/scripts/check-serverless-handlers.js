/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');

const backendRoot = path.resolve(__dirname, '..');
const serverlessPath = path.join(backendRoot, 'serverless.yml');
const handlersDir = path.join(backendRoot, 'src', 'handlers');

function extractHandlers(serverlessText) {
  const matches = [...serverlessText.matchAll(/handler:\s+dist\/handlers\/([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_]+)/g)];
  return matches.map((m) => ({ fileBase: m[1], exportName: m[2] }));
}

function hasExport(source, exportName) {
  const patterns = [
    new RegExp(`export\\s+const\\s+${exportName}(?:\\s*:[^=]+)?\\s*=`, 'm'),
    new RegExp(`export\\s+async\\s+function\\s+${exportName}\\s*\\(`, 'm'),
    new RegExp(`export\\s+function\\s+${exportName}\\s*\\(`, 'm'),
  ];
  return patterns.some((p) => p.test(source));
}

function run() {
  const serverlessText = fs.readFileSync(serverlessPath, 'utf8');
  const handlers = extractHandlers(serverlessText);
  const problems = [];

  for (const h of handlers) {
    const srcPath = path.join(handlersDir, `${h.fileBase}.ts`);
    if (!fs.existsSync(srcPath)) {
      problems.push(`Missing handler file: src/handlers/${h.fileBase}.ts (for export ${h.exportName})`);
      continue;
    }
    const source = fs.readFileSync(srcPath, 'utf8');
    if (!hasExport(source, h.exportName)) {
      problems.push(`Missing export: ${h.exportName} in src/handlers/${h.fileBase}.ts`);
    }
  }

  if (problems.length > 0) {
    console.error('Serverless handler contract check failed:');
    for (const p of problems) console.error(`- ${p}`);
    process.exit(1);
  }

  console.log(`Serverless handler contract check passed (${handlers.length} handler mappings).`);
}

run();
