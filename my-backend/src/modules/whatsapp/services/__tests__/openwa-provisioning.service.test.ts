// ============================================================================
// WhatsApp Module — OpenWaProvisioningService Unit Tests (Task 4)
// ============================================================================
// Verifies the save -> verify/activate -> delete lifecycle, including real
// (mocked) HTTP calls against OpenWA's session and webhook endpoints, and
// the secret-store / session-registry / status-record write paths.
// ============================================================================

const mockStoreSecret = jest.fn();
const mockGetSecret = jest.fn();
const mockDeleteSecret = jest.fn();

jest.mock('../../../../services/secrets-manager.service', () => ({
  storeSecret: (...args: unknown[]) => mockStoreSecret(...args),
  getSecret: (...args: unknown[]) => mockGetSecret(...args),
  deleteSecret: (...args: unknown[]) => mockDeleteSecret(...args),
}));

const mockRegisterBusinessSession = jest.fn();
const mockDeregisterBusinessSession = jest.fn();

jest.mock('../openwa-session-registry.service', () => ({
  registerBusinessSession: (...args: unknown[]) => mockRegisterBusinessSession(...args),
  deregisterBusinessSession: (...args: unknown[]) => mockDeregisterBusinessSession(...args),
}));

import { OpenWaProvisioningService, buildWebhookCallbackUrl } from '../openwa-provisioning.service';
import { OpenWaProvisioningRepository } from '../../repositories/openwa-provisioning.repository';
import { AppError, NotFoundError } from '../../../../utils/errors';
import type { SaveProvisioningConfigInput } from '../../schemas/provisioning.schema';

const TENANT_ID = 'tenant-1';
const BUSINESS_ID = 'biz-1';

const SAVE_INPUT: SaveProvisioningConfigInput = {
  baseUrl: 'https://openwa.example.com',
  apiKey: 'openwa-api-key',
  sessionId: 'session-abc',
  webhookSecret: 'a-very-long-webhook-secret-value',
  displayName: 'Main Store WhatsApp',
};

function makeRepoMock() {
  return {
    get: jest.fn(),
    upsert: jest.fn(),
    update: jest.fn(),
    remove: jest.fn(),
  } as unknown as jest.Mocked<OpenWaProvisioningRepository>;
}

describe('OpenWaProvisioningService', () => {
  let repo: jest.Mocked<OpenWaProvisioningRepository>;
  let service: OpenWaProvisioningService;
  let fetchMock: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
    mockStoreSecret.mockResolvedValue(undefined);
    mockDeleteSecret.mockResolvedValue(undefined);
    repo = makeRepoMock();
    service = new OpenWaProvisioningService(repo);
    fetchMock = jest.fn();
    (global as unknown as { fetch: jest.Mock }).fetch = fetchMock;
  });

  // ── saveConfig ─────────────────────────────────────────────────────────────

  describe('saveConfig', () => {
    it('stores credentials in the secret store, registers the session mapping, and writes a pending_verification status record', async () => {
      repo.get.mockResolvedValueOnce(null);
      repo.upsert.mockImplementationOnce(async (_t, _b, data) => ({
        id: data.id,
        businessId: BUSINESS_ID,
        tenantId: TENANT_ID,
        sessionId: data.sessionId,
        baseUrl: data.baseUrl,
        status: data.status,
        displayName: data.displayName,
        webhookId: data.webhookId,
        lastError: data.lastError,
        verifiedAt: data.verifiedAt,
        createdAt: '2024-01-01T00:00:00.000Z',
        updatedAt: '2024-01-01T00:00:00.000Z',
      }));

      const result = await service.saveConfig(TENANT_ID, BUSINESS_ID, SAVE_INPUT);

      expect(mockStoreSecret).toHaveBeenCalledWith(
        TENANT_ID,
        'openwa_credentials',
        JSON.stringify({
          baseUrl: SAVE_INPUT.baseUrl,
          apiKey: SAVE_INPUT.apiKey,
          sessionId: SAVE_INPUT.sessionId,
          webhookSecret: SAVE_INPUT.webhookSecret,
        }),
      );
      expect(mockRegisterBusinessSession).toHaveBeenCalledWith(TENANT_ID, BUSINESS_ID, SAVE_INPUT.sessionId);
      expect(repo.upsert).toHaveBeenCalledWith(
        TENANT_ID,
        BUSINESS_ID,
        expect.objectContaining({ status: 'pending_verification', sessionId: SAVE_INPUT.sessionId }),
      );
      expect(result.status).toBe('pending_verification');
    });

    it('normalizes a trailing slash on baseUrl before storing', async () => {
      repo.get.mockResolvedValueOnce(null);
      repo.upsert.mockImplementationOnce(async (_t, _b, data) => ({
        ...data,
        businessId: BUSINESS_ID,
        tenantId: TENANT_ID,
        createdAt: 'now',
        updatedAt: 'now',
      }));

      await service.saveConfig(TENANT_ID, BUSINESS_ID, {
        ...SAVE_INPUT,
        baseUrl: 'https://openwa.example.com/',
      });

      const storedJson = JSON.parse(mockStoreSecret.mock.calls[0][2] as string);
      expect(storedJson.baseUrl).toBe('https://openwa.example.com');
    });

    it('reuses the existing record id when re-saving (credential rotation)', async () => {
      repo.get.mockResolvedValueOnce({
        id: 'existing-id',
        businessId: BUSINESS_ID,
        tenantId: TENANT_ID,
        sessionId: 'old-session',
        baseUrl: 'https://old.example.com',
        status: 'active',
        createdAt: 'now',
        updatedAt: 'now',
      });
      repo.upsert.mockImplementationOnce(async (_t, _b, data) => ({
        ...data,
        businessId: BUSINESS_ID,
        tenantId: TENANT_ID,
        createdAt: 'now',
        updatedAt: 'now',
      }));

      await service.saveConfig(TENANT_ID, BUSINESS_ID, SAVE_INPUT);

      expect(repo.upsert).toHaveBeenCalledWith(
        TENANT_ID,
        BUSINESS_ID,
        expect.objectContaining({ id: 'existing-id' }),
      );
    });
  });

  // ── verifyAndActivate ──────────────────────────────────────────────────────

  describe('verifyAndActivate', () => {
    const EXISTING = {
      id: 'cfg-1',
      businessId: BUSINESS_ID,
      tenantId: TENANT_ID,
      sessionId: SAVE_INPUT.sessionId,
      baseUrl: SAVE_INPUT.baseUrl,
      status: 'pending_verification' as const,
      createdAt: 'now',
      updatedAt: 'now',
    };

    beforeEach(() => {
      mockGetSecret.mockResolvedValue(
        JSON.stringify({
          baseUrl: SAVE_INPUT.baseUrl,
          apiKey: SAVE_INPUT.apiKey,
          sessionId: SAVE_INPUT.sessionId,
          webhookSecret: SAVE_INPUT.webhookSecret,
        }),
      );
    });

    it('throws NotFoundError when no config has been saved', async () => {
      repo.get.mockResolvedValueOnce(null);
      await expect(
        service.verifyAndActivate(TENANT_ID, BUSINESS_ID, 'https://backend.example.com/whatsapp/webhook'),
      ).rejects.toBeInstanceOf(NotFoundError);
    });

    it('calls GET /api/sessions/:sessionId then POST /api/sessions/:sessionId/webhooks, and activates on success', async () => {
      repo.get.mockResolvedValueOnce(EXISTING);
      repo.update.mockImplementationOnce(async (_t, _b, fields) => ({
        ...EXISTING,
        ...fields,
      }));

      fetchMock
        .mockResolvedValueOnce({ ok: true, status: 200, json: async () => ({ id: SAVE_INPUT.sessionId }) })
        .mockResolvedValueOnce({ ok: true, status: 201, json: async () => ({ id: 'webhook-123' }) });

      const result = await service.verifyAndActivate(
        TENANT_ID,
        BUSINESS_ID,
        'https://backend.example.com/whatsapp/webhook',
      );

      expect(fetchMock).toHaveBeenNthCalledWith(
        1,
        `${SAVE_INPUT.baseUrl}/api/sessions/${SAVE_INPUT.sessionId}`,
        expect.objectContaining({
          method: 'GET',
          headers: expect.objectContaining({ 'X-API-Key': SAVE_INPUT.apiKey }),
        }),
      );
      expect(fetchMock).toHaveBeenNthCalledWith(
        2,
        `${SAVE_INPUT.baseUrl}/api/sessions/${SAVE_INPUT.sessionId}/webhooks`,
        expect.objectContaining({
          method: 'POST',
          headers: expect.objectContaining({ 'X-API-Key': SAVE_INPUT.apiKey }),
          body: JSON.stringify({
            url: 'https://backend.example.com/whatsapp/webhook',
            events: ['message.ack', 'message.failed'],
            secret: SAVE_INPUT.webhookSecret,
          }),
        }),
      );
      expect(repo.update).toHaveBeenCalledWith(
        TENANT_ID,
        BUSINESS_ID,
        expect.objectContaining({ status: 'active', webhookId: 'webhook-123' }),
      );
      expect(result.status).toBe('active');
    });

    it('marks status failed and throws when the session check fails', async () => {
      repo.get.mockResolvedValueOnce(EXISTING);
      repo.update.mockResolvedValueOnce({ ...EXISTING, status: 'failed' });

      fetchMock.mockResolvedValueOnce({ ok: false, status: 401, json: async () => ({}) });

      await expect(
        service.verifyAndActivate(TENANT_ID, BUSINESS_ID, 'https://backend.example.com/whatsapp/webhook'),
      ).rejects.toBeInstanceOf(AppError);

      expect(repo.update).toHaveBeenCalledWith(
        TENANT_ID,
        BUSINESS_ID,
        expect.objectContaining({ status: 'failed' }),
      );
      // Webhook registration must never be attempted when the session check failed.
      expect(fetchMock).toHaveBeenCalledTimes(1);
    });

    it('marks status failed and throws when webhook registration fails', async () => {
      repo.get.mockResolvedValueOnce(EXISTING);
      repo.update.mockResolvedValueOnce({ ...EXISTING, status: 'failed' });

      fetchMock
        .mockResolvedValueOnce({ ok: true, status: 200, json: async () => ({ id: SAVE_INPUT.sessionId }) })
        .mockResolvedValueOnce({ ok: false, status: 500, json: async () => ({}) });

      await expect(
        service.verifyAndActivate(TENANT_ID, BUSINESS_ID, 'https://backend.example.com/whatsapp/webhook'),
      ).rejects.toBeInstanceOf(AppError);

      expect(repo.update).toHaveBeenCalledWith(
        TENANT_ID,
        BUSINESS_ID,
        expect.objectContaining({ status: 'failed' }),
      );
    });

    it('deletes a previously registered webhook before re-registering (idempotent re-verification)', async () => {
      repo.get.mockResolvedValueOnce({ ...EXISTING, webhookId: 'old-webhook-id' });
      repo.update.mockImplementationOnce(async (_t, _b, fields) => ({
        ...EXISTING,
        ...fields,
      }));

      fetchMock
        .mockResolvedValueOnce({ ok: true, status: 200, json: async () => ({}) }) // session check
        .mockResolvedValueOnce({ ok: true, status: 204, json: async () => ({}) }) // delete old webhook
        .mockResolvedValueOnce({ ok: true, status: 201, json: async () => ({ id: 'new-webhook-id' }) }); // register new

      await service.verifyAndActivate(TENANT_ID, BUSINESS_ID, 'https://backend.example.com/whatsapp/webhook');

      expect(fetchMock).toHaveBeenNthCalledWith(
        2,
        `${SAVE_INPUT.baseUrl}/api/sessions/${SAVE_INPUT.sessionId}/webhooks/old-webhook-id`,
        expect.objectContaining({ method: 'DELETE' }),
      );
    });
  });

  // ── deleteConfig ───────────────────────────────────────────────────────────

  describe('deleteConfig', () => {
    it('throws NotFoundError when no config exists', async () => {
      repo.get.mockResolvedValueOnce(null);
      await expect(service.deleteConfig(TENANT_ID, BUSINESS_ID)).rejects.toBeInstanceOf(NotFoundError);
    });

    it('deletes the remote webhook, the secret, the session mapping, and the status record', async () => {
      repo.get.mockResolvedValueOnce({
        id: 'cfg-1',
        businessId: BUSINESS_ID,
        tenantId: TENANT_ID,
        sessionId: SAVE_INPUT.sessionId,
        baseUrl: SAVE_INPUT.baseUrl,
        status: 'active',
        webhookId: 'webhook-123',
        createdAt: 'now',
        updatedAt: 'now',
      });
      mockGetSecret.mockResolvedValueOnce(
        JSON.stringify({
          baseUrl: SAVE_INPUT.baseUrl,
          apiKey: SAVE_INPUT.apiKey,
          sessionId: SAVE_INPUT.sessionId,
          webhookSecret: SAVE_INPUT.webhookSecret,
        }),
      );
      fetchMock.mockResolvedValueOnce({ ok: true, status: 204, json: async () => ({}) });

      await service.deleteConfig(TENANT_ID, BUSINESS_ID);

      expect(fetchMock).toHaveBeenCalledWith(
        `${SAVE_INPUT.baseUrl}/api/sessions/${SAVE_INPUT.sessionId}/webhooks/webhook-123`,
        expect.objectContaining({ method: 'DELETE' }),
      );
      expect(mockDeleteSecret).toHaveBeenCalledWith(TENANT_ID, 'openwa_credentials');
      expect(mockDeregisterBusinessSession).toHaveBeenCalledWith(SAVE_INPUT.sessionId);
      expect(repo.remove).toHaveBeenCalledWith(TENANT_ID, BUSINESS_ID);
    });

    it('still cleans up local state when the remote webhook delete fails', async () => {
      repo.get.mockResolvedValueOnce({
        id: 'cfg-1',
        businessId: BUSINESS_ID,
        tenantId: TENANT_ID,
        sessionId: SAVE_INPUT.sessionId,
        baseUrl: SAVE_INPUT.baseUrl,
        status: 'active',
        webhookId: 'webhook-123',
        createdAt: 'now',
        updatedAt: 'now',
      });
      mockGetSecret.mockRejectedValueOnce(new Error('secret store unavailable'));

      await service.deleteConfig(TENANT_ID, BUSINESS_ID);

      expect(mockDeleteSecret).toHaveBeenCalledWith(TENANT_ID, 'openwa_credentials');
      expect(mockDeregisterBusinessSession).toHaveBeenCalledWith(SAVE_INPUT.sessionId);
      expect(repo.remove).toHaveBeenCalledWith(TENANT_ID, BUSINESS_ID);
    });
  });
});

// ── buildWebhookCallbackUrl ────────────────────────────────────────────────────

describe('buildWebhookCallbackUrl', () => {
  it('builds the URL from the API Gateway domain when available', () => {
    expect(buildWebhookCallbackUrl('api.example.com', '$default')).toBe(
      'https://api.example.com/whatsapp/webhook',
    );
  });

  it('appends a non-default stage as a path segment', () => {
    expect(buildWebhookCallbackUrl('api.example.com', 'prod')).toBe(
      'https://api.example.com/prod/whatsapp/webhook',
    );
  });
});
