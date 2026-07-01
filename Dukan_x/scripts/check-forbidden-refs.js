#!/usr/bin/env node
// ============================================================================
// Deployment Safety Script — Forbidden Reference Scanner
// ============================================================================
// Scans the codebase for references to localhost, 127.0.0.1, and other
// development-only patterns that must not exist in production builds.
//
// Usage:
//   node scripts/check-forbidden-refs.js
//
// Exit codes:
//   0 — No violations found
//   1 — Violations detected (build should fail)
// ============================================================================

const fs = require('fs');
const path = require('path');

// ── Configuration ───────────────────────────────────────────────────────────

const ROOT = path.resolve(__dirname, '..');

const SCAN_DIRS = [
    'my-backend/src',
    'sls/app-backend/src',
    'sls/backend/src',
    'lib',
    'scripts',
];

const SCAN_EXTENSIONS = new Set([
    '.ts', '.js', '.dart', '.json', '.env', '.yaml', '.yml',
]);

const EXCLUDED_DIRS = new Set([
    'node_modules', 'dist', 'build', '.serverless', 'coverage',
    '.dart_tool', '.git', '.venv', '__pycache__',
]);

const EXCLUDED_FILES = new Set([
    'check-forbidden-refs.js', // this script itself
]);

// Patterns to scan for (case-insensitive)
const FORBIDDEN_PATTERNS = [
    { regex: /localhost/i, label: 'localhost' },
    { regex: /127\.0\.0\.1/i, label: '127.0.0.1' },
    { regex: /http:\/\/dev\b/i, label: 'http://dev' },
];

// Lines matching these patterns are whitelisted (e.g. comments about what NOT to do)
const WHITELIST_PATTERNS = [
    /\/\/.*do\s+not/i,
    /\/\/.*never\s+allow/i,
    /\/\/.*forbidden/i,
    /\/\/.*override.*locally.*with/i,
    /\/\/.*example/i,
    /\/\*.*\*\//,       // inline block comments
    /^\s*#/,            // comment lines in .env/.yaml
    /^\s*\/\//,         // comment-only lines in .ts/.js/.dart
    /dart-define/i,     // Flutter dart-define documentation
    /Platform\.localHostname/i,  // Dart API for device hostname (NOT a URL)
    /sourceIp.*127\.0\.0\.1/i,   // Synthetic event adapter fallback (test/mock)
    /NODE_ENV\s*===\s*'production'/i,  // Production guard patterns (localhost is dev-only fallback)
    /\.test\./i,        // Test files (fixtures use localhost for mocking)
    /^\s*[?:]\s*.*localhost/i,  // Ternary dev-only fallback branch (guarded by NODE_ENV check)
];

// ── Scanner ─────────────────────────────────────────────────────────────────

let violations = [];

function scanFile(filePath) {
    const ext = path.extname(filePath);
    if (!SCAN_EXTENSIONS.has(ext)) return;

    const basename = path.basename(filePath);
    if (EXCLUDED_FILES.has(basename)) return;

    let content;
    try {
        content = fs.readFileSync(filePath, 'utf-8');
    } catch (e) {
        return; // Skip unreadable files
    }

    const lines = content.split('\n');
    lines.forEach((line, index) => {
        // Skip whitelisted lines
        if (WHITELIST_PATTERNS.some(wp => wp.test(line))) return;

        for (const pattern of FORBIDDEN_PATTERNS) {
            if (pattern.regex.test(line)) {
                violations.push({
                    file: path.relative(ROOT, filePath),
                    line: index + 1,
                    pattern: pattern.label,
                    content: line.trim().substring(0, 120),
                });
            }
        }
    });
}

function scanDirectory(dirPath) {
    let entries;
    try {
        entries = fs.readdirSync(dirPath, { withFileTypes: true });
    } catch (e) {
        return;
    }

    for (const entry of entries) {
        if (EXCLUDED_DIRS.has(entry.name)) continue;

        const fullPath = path.join(dirPath, entry.name);
        if (entry.isDirectory()) {
            scanDirectory(fullPath);
        } else if (entry.isFile()) {
            scanFile(fullPath);
        }
    }
}

// ── Main ────────────────────────────────────────────────────────────────────

console.log('🔍 Scanning for forbidden references...\n');

for (const dir of SCAN_DIRS) {
    const fullDir = path.join(ROOT, dir);
    if (fs.existsSync(fullDir)) {
        scanDirectory(fullDir);
    }
}

if (violations.length === 0) {
    console.log('✅ No forbidden references found. Safe to deploy.\n');
    process.exit(0);
} else {
    console.error(`❌ Found ${violations.length} forbidden reference(s):\n`);
    violations.forEach((v, i) => {
        console.error(`  ${i + 1}. [${v.pattern}] ${v.file}:${v.line}`);
        console.error(`     ${v.content}\n`);
    });
    console.error('⛔ Build blocked. Fix the above references before deploying.\n');
    process.exit(1);
}
