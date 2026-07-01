-- ============================================================================
-- Migration 005: Linking Tokens Table
-- ============================================================================
-- Stores QR linking tokens in PostgreSQL instead of in-memory Map.
-- Tokens are short-lived (default 7 days) and auto-cleaned.
-- No RLS — tokens span tenants (vendor generates, customer consumes).
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS linking_tokens (
    token       VARCHAR(64) PRIMARY KEY,
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    created_by  VARCHAR(100) NOT NULL,  -- Cognito sub of vendor who generated
    expires_at  TIMESTAMPTZ NOT NULL,
    max_uses    INTEGER,                -- NULL = unlimited
    used_count  INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_linking_tokens_tenant ON linking_tokens(tenant_id);
CREATE INDEX IF NOT EXISTS idx_linking_tokens_expiry ON linking_tokens(expires_at);

INSERT INTO schema_migrations (version, name)
VALUES (5, '005_linking_tokens.sql')
ON CONFLICT (version) DO NOTHING;

COMMIT;
