// ============================================================================
// Local_Backend Constants
// ============================================================================
// Central, non-secret runtime constants for the packaged offline backend.
// No keys or secrets live here (Req 17.1) — those are derived at runtime by
// the Dart Security_Layer and supplied via environment when the supervisor
// spawns this process.
// ============================================================================

import { homedir } from 'os';
import { join } from 'path';

/**
 * Loopback_Address — the ONLY interface the Local_Backend binds to.
 * Requirements 3.4 / 4.2 / 4.3 / 17.6: the offline backend must never be
 * reachable from any non-local interface.
 */
export const LOOPBACK_HOST = '127.0.0.1';
export const LOOPBACK_PORT = 8765;
export const LOOPBACK_ADDRESS = `${LOOPBACK_HOST}:${LOOPBACK_PORT}`;
export const LOOPBACK_BASE_URI = `http://${LOOPBACK_ADDRESS}`;

/**
 * Service identity reported by /health and the Socket.io handshake, so the
 * Backend_Supervisor and Mode_Manager can positively identify this process.
 */
export const SERVICE_NAME = 'dukanx-local-backend';
export const SERVICE_VERSION = '1.0.0';

/**
 * Socket.io path. Mirrors a dedicated namespace so the loopback real-time
 * channel is distinct from the REST surface.
 */
export const SOCKET_IO_PATH = '/socket.io';

// ============================================================================
// DukanX Data Directory (OS-specific secure location)
// ============================================================================
// The packaged offline stack persists all local data under a single, app-owned
// DukanX data directory. The location mirrors the design's OS-specific secure
// locations (Req 5.7 / 20.4) used elsewhere by the license file, so every
// local-equivalent store (S3 → Object_Store, SQS/SNS → Local_Queue, etc.)
// lives under one predictable root.
//
//   Windows: %APPDATA%/DukanX
//   macOS:   ~/Library/Application Support/DukanX
//   Linux:   $XDG_DATA_HOME/DukanX  (fallback ~/.local/share/DukanX)
//
// The supervisor may override the root via the DUKANX_DATA_DIR environment
// variable (e.g. for tests or a custom install location); when set it always
// takes precedence.
// ============================================================================

export const DUKANX_APP_DIR_NAME = 'DukanX';

/** Environment override for the DukanX data directory root. */
export const DATA_DIR_ENV_VAR = 'DUKANX_DATA_DIR';

/**
 * Resolve the absolute path to the DukanX data directory for the current OS.
 * Honors the DUKANX_DATA_DIR override when present.
 */
export function resolveDukanxDataDir(): string {
    const override = process.env[DATA_DIR_ENV_VAR];
    if (override && override.trim().length > 0) {
        return override;
    }

    const home = homedir();
    switch (process.platform) {
        case 'win32':
            return join(process.env.APPDATA ?? join(home, 'AppData', 'Roaming'), DUKANX_APP_DIR_NAME);
        case 'darwin':
            return join(home, 'Library', 'Application Support', DUKANX_APP_DIR_NAME);
        default:
            return join(
                process.env.XDG_DATA_HOME ?? join(home, '.local', 'share'),
                DUKANX_APP_DIR_NAME,
            );
    }
}

/**
 * Subdirectory under the DukanX data dir that holds the S3-equivalent
 * Object_Store's content-addressed binary objects.
 */
export const OBJECT_STORE_DIR_NAME = 'objects';

