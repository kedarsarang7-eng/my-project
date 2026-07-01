// ============================================================================
// Socket Gateway — WebSocket service equivalent (Socket.io on loopback)
// ============================================================================
// Requirement 4.3: the Local_Backend provides the local equivalent of the AWS
// WebSocket service by serving the SAME real-time event contracts through a
// Socket.io server bound to the loopback interface.
//
// This scaffold wires the Socket.io server onto the shared HTTP server and
// mirrors the AWS event surface: clients send subscribe/unsubscribe/ping/
// presence actions (WSClientMessage) and receive WSEvent payloads keyed by
// WSEventName. Real broadcasting/fan-out (DynamoDB/EventBridge equivalents)
// arrives with the Local_Queue and service wiring in later tasks; here the
// gateway is a contract-accurate stub that acknowledges the documented client
// actions and exposes a typed `broadcast` for those tasks to call.
// ============================================================================

import { Server as HttpServer } from 'http';
import { Server as IOServer, Socket } from 'socket.io';
import { SOCKET_IO_PATH } from '../config/constants';
import { WSClientMessage, WSEvent, WSEventName } from '../contracts/websocket.contract';
import { logger } from '../utils/logger';

export class SocketGateway {
    private readonly io: IOServer;

    constructor(httpServer: HttpServer) {
        // Bound to the same loopback HTTP server; never opens a new interface.
        this.io = new IOServer(httpServer, {
            path: SOCKET_IO_PATH,
            // Loopback-only deployment: the desktop app is the only origin.
            cors: { origin: false },
            serveClient: false,
        });

        this.registerConnectionHandlers();
    }

    private registerConnectionHandlers(): void {
        this.io.on('connection', (socket: Socket) => {
            logger.info('Local_Backend socket connected', { socketId: socket.id });

            // Mirror the AWS client message actions (WSClientMessage).
            socket.on('client_message', (message: WSClientMessage) => {
                this.handleClientMessage(socket, message);
            });

            socket.on('disconnect', (reason: string) => {
                logger.info('Local_Backend socket disconnected', { socketId: socket.id, reason });
            });
        });
    }

    private handleClientMessage(socket: Socket, message: WSClientMessage): void {
        switch (message?.action) {
            case 'subscribe':
                (message.events ?? []).forEach((event: WSEventName) => socket.join(event));
                socket.emit('subscribed', { events: message.events ?? [] });
                break;
            case 'unsubscribe':
                (message.events ?? []).forEach((event: WSEventName) => socket.leave(event));
                socket.emit('unsubscribed', { events: message.events ?? [] });
                break;
            case 'ping':
                socket.emit('pong', { timestamp: new Date().toISOString() });
                break;
            case 'presence':
                socket.emit('presence_ack', { status: message.status ?? 'online' });
                break;
            default:
                logger.warn('Unknown socket client action', { action: message?.action });
        }
    }

    /**
     * Broadcast a real-time event to subscribed clients. Later tasks (queue +
     * service wiring) call this to fan out domain events; it already produces
     * the AWS-identical WSEvent payload shape.
     */
    broadcast(event: WSEventName, businessId: string, data: Record<string, unknown>): void {
        const payload: WSEvent = {
            event,
            businessId,
            timestamp: new Date().toISOString(),
            data,
        };
        this.io.to(event).emit(event, payload);
    }

    async close(): Promise<void> {
        await this.io.close();
    }
}
