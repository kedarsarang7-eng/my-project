/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');

const backendRoot = path.resolve(__dirname, '..');
const serverlessPath = path.join(backendRoot, 'serverless.yml');
const outputPath = path.resolve(backendRoot, '..', 'docs', 'openapi.yaml');

function parseRoutes(serverlessText) {
  const lines = serverlessText.split(/\r?\n/);
  const routes = [];
  let currentFunction = null;
  let currentPath = null;
  let currentMethod = null;
  let currentDescription = null;

  for (const line of lines) {
    const functionMatch = line.match(/^  ([A-Za-z0-9_-]+):\s*$/);
    if (functionMatch) {
      currentFunction = functionMatch[1];
      currentPath = null;
      currentMethod = null;
      currentDescription = null;
      continue;
    }

    if (!currentFunction) continue;

    const pathMatch = line.match(/^\s+path:\s+(.+)\s*$/);
    if (pathMatch) {
      currentPath = pathMatch[1].trim();
      continue;
    }

    const methodMatch = line.match(/^\s+method:\s+([A-Za-z]+)\s*$/);
    if (methodMatch) {
      currentMethod = methodMatch[1].toLowerCase();
      continue;
    }

    const descriptionMatch = line.match(/^\s+description:\s+(.+)\s*$/);
    if (descriptionMatch) {
      currentDescription = descriptionMatch[1].trim();
      if (currentPath && currentMethod) {
        routes.push({
          functionName: currentFunction,
          path: currentPath,
          method: currentMethod,
          description: currentDescription,
        });
        currentPath = null;
        currentMethod = null;
      }
    }
  }

  return routes;
}

function toOpenApiYaml(routes) {
  const byPath = new Map();
  for (const route of routes) {
    if (!byPath.has(route.path)) byPath.set(route.path, []);
    byPath.get(route.path).push(route);
  }

  const sortedPaths = [...byPath.keys()].sort();
  const lines = [
    'openapi: 3.0.3',
    'info:',
    '  title: DukanX Backend API',
    '  version: 1.0.0',
    '  description: Auto-generated from serverless.yml. Do not hand-edit.',
    'paths:',
  ];

  for (const apiPath of sortedPaths) {
    lines.push(`  ${apiPath}:`);
    const methods = byPath.get(apiPath).sort((a, b) => a.method.localeCompare(b.method));
    for (const route of methods) {
      lines.push(`    ${route.method}:`);
      lines.push(`      operationId: ${route.functionName}`);
      lines.push(`      summary: ${(route.description || 'No summary').replace(/"/g, "'")}`);
      lines.push('      responses:');
      lines.push("        '200':");
      lines.push('          description: Success');
    }
  }

  return `${lines.join('\n')}\n`;
}

function run() {
  const serverlessText = fs.readFileSync(serverlessPath, 'utf8');
  const routes = parseRoutes(serverlessText);
  const content = toOpenApiYaml(routes);
  fs.writeFileSync(outputPath, content, 'utf8');
  console.log(`OpenAPI synced: ${routes.length} routes -> ${outputPath}`);
}

run();
