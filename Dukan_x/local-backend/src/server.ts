// ============================================================================
// Server — packaged Local_Backend entry point
// ============================================================================
// Requirements 3.1 / 3.4 / 4.2 / 4.3:
//   - Packaged Node.js/Express server (started by the Backend_Supervisor).
//   - Binds ONLY to the Loopback_Address 127.0.0.1:8765 (never 0.0.0.0).
//   - Serves the AWS REST contracts (Express) and real-time contracts (Socket.io)
//     on the same loopback HTTP server.
//
// The Backend_Supervisor (task 2.2) spawns this process, polls GET /health,
// and requests graceful shutdown on exit; the SIGTERM/SIGINT handlers below
// support that lifecycle.
// ============================================================================

import { createServer, Server as HttpServer } from 'http';
import { buildApp } from './app';
import { SocketGateway } from './realtime/socket-gateway';
import { LOOPBACK_HOST, LOOPBACK_PORT, LOOPBACK_BASE_URI } from './config/constants';
import { logger } from './utils/logger';

let httpServer: HttpServer | null = null;
let gateway: SocketGateway | null = null;

export function startServer(): Promise<HttpServer> {
    const app = buildApp();
    httpServer = createServer(app);

    // WebSocket equivalent shares the loopback HTTP server (Req 4.3).
    gateway = new SocketGateway(httpServer);

    return new Promise((resolve, reject) => {
        const server = httpServer as HttpServer;
        server.once('error', reject);
        // Bind explicitly to the loopback host — NEVER a public interface (Req 3.4/17.6).
        server.listen(LOOPBACK_PORT, LOOPBACK_HOST, () => {
            logger.info('Local_Backend listening', { address: LOOPBACK_BASE_URI });
            logger.info('Health endpoint ready', { url: `${LOOPBACK_BASE_URI}/health` });
            resolve(server);
        });
    });
}

export async function stopServer(): Promise<void> {
    if (gateway) {
        await gateway.close();
        gateway = null;
    }
    if (httpServer) {
        const server = httpServer;
        await new Promise<void>((resolve) => server.close(() => resolve()));
        httpServer = null;
    }
}

function gracefulShutdown(signal: string): void {
    logger.info('Local_Backend shutdown requested', { signal });
    stopServer()
        .then(() => process.exit(0))
        .catch((err: Error) => {
            logger.error('Local_Backend shutdown error', { error: err.message });
            process.exit(1);
        });
    // Force-exit safety net mirrors the supervisor's 5s force-terminate window.
    setTimeout(() => process.exit(1), 5000).unref();
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Start only when invoked directly (not when imported by tests).
if (require.main === module) {
    startServer().catch((err: Error) => {
        logger.error('Local_Backend failed to start', { error: err.message });
        process.exit(1);
    });
}
