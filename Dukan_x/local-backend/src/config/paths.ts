// ============================================================================
// Paths — OS-specific DukanX data directory resolution
// ============================================================================
// The offline service equivalents (S3 → Object_Store, SQS/SNS → Local_Queue)
// persist under a single "DukanX data directory" (Req 4.5 / 4.6). This module
// is the one place that resolves that location, so every local store agrees on
// where data lives.
//
// Resolution order:
//   1. DUKANX_DATA_DIR environment override — the Backend_Supervisor passes the
//      app's resolved data directory when it spawns this process, keeping the
//      packaged backend free of hard-coded user paths.
//   2. OS-specific application-data location (mirrors the Local_License_File
//      placement documented in the design).
//
// No secrets live here (Req 17.1) — only filesystem locations.
// ============================================================================

import os from 'os';
import path from 'path';

/** Application data folder name, shared across OS-specific roots. */
const APP_DIR_NAME = 'DukanX';

/**
 * Resolve the root DukanX data directory for the current machine.
 *
 * Honours the `DUKANX_DATA_DIR` override first; otherwise falls back to the
 * OS-specific application-data location:
 *   - Windows: `%APPDATA%/DukanX`
 *   - macOS:   `~/Library/Application Support/DukanX`
 *   - Linux:   `$XDG_DATA_HOME/DukanX` (fallback `~/.local/share/DukanX`)
 */
export function resolveDataDir(): string {
    const override = process.env.DUKANX_DATA_DIR;
    if (override && override.trim().length > 0) {
        return override;
    }

    const home = os.homedir();
    switch (process.platform) {
        case 'win32': {
            const appData = process.env.APPDATA ?? path.join(home, 'AppData', 'Roaming');
            return path.join(appData, APP_DIR_NAME);
        }
        case 'darwin':
            return path.join(home, 'Library', 'Application Support', APP_DIR_NAME);
        default: {
            const xdg = process.env.XDG_DATA_HOME ?? path.join(home, '.local', 'share');
            return path.join(xdg, APP_DIR_NAME);
        }
    }
}

/**
 * Resolve the on-disk path of the Local_Queue SQLite database file
 * (`<dataDir>/queue/local-queue.db`). The Local_Queue ensures the parent
 * directory exists before opening the database.
 */
export function resolveQueueDbPath(): string {
    return path.join(resolveDataDir(), 'queue', 'local-queue.db');
}
