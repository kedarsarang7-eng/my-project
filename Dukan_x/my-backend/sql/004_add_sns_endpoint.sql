-- ============================================================================
-- Migration: 004_add_sns_endpoint
-- Description: Add sns_endpoint_arn to users table for push notifications
-- ============================================================================

BEGIN;

ALTER TABLE users ADD COLUMN IF NOT EXISTS sns_endpoint_arn VARCHAR(255);

-- Index for faster lookups (optional but good practice)
CREATE INDEX IF NOT EXISTS idx_users_sns_endpoint ON users(sns_endpoint_arn);

INSERT INTO schema_migrations (version, name)
VALUES (4, '004_add_sns_endpoint.sql')
ON CONFLICT (version) DO NOTHING;

COMMIT;
