/**
 * Fixture: WebSocket handler with lifecycle routes and dotted events.
 *
 * Exercises the code scanner's WebSocket detection (Requirement 1.5): the
 * `$connect` / `$disconnect` / `$default` lifecycle routes and dotted event
 * names within a WebSocket source file. The `.ws.` in the filename marks this
 * as a WebSocket file so event-name extraction applies.
 */
const noop = (): void => undefined;

const routes: Record<string, () => void> = {
  '$connect': noop,
  '$disconnect': noop,
  '$default': noop,
};

function broadcast(): void {
  emit('inventory.stock.updated', {});
  emit('inventory.item.created', {});
}

declare function emit(event: string, payload: unknown): void;

export { routes, broadcast };
