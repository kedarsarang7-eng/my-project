-- ============================================================================
-- STAFF ONBOARDING — Secure Invitation & Linking for Multi-Tenant DukanX
-- ============================================================================
-- Supports the Petrol Pump Staff App (and future staff apps for any business type).
-- Ensures a staff member is linked to the correct BusinessID and OwnerID
-- so that data (meter readings, payments, etc.) never leaks between tenants.
-- ============================================================================

-- 1. Staff Invitations table — tracks every invite code the Owner generates
CREATE TABLE IF NOT EXISTS staff_invitations (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id                UUID NOT NULL REFERENCES staff_members(id) ON DELETE CASCADE,
    business_id             TEXT NOT NULL,               -- tenant_id / shop_id
    owner_id                TEXT NOT NULL,               -- Owner's Cognito sub
    linking_code            TEXT NOT NULL UNIQUE,         -- Human-friendly: DX-9988
    status                  TEXT NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending', 'active', 'expired', 'revoked')),
    expiry_date             TIMESTAMPTZ NOT NULL,
    claimed_by_cognito_sub  TEXT,                         -- Staff's Cognito UUID once claimed
    claimed_at              TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_staff_invitations_code ON staff_invitations(linking_code);
CREATE INDEX IF NOT EXISTS idx_staff_invitations_business ON staff_invitations(business_id);
CREATE INDEX IF NOT EXISTS idx_staff_invitations_staff ON staff_invitations(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_invitations_status ON staff_invitations(status);

-- 2. Add owner_id to staff_members (Owner's Cognito sub who owns this business)
--    created_by already exists but is nullable; owner_id is explicit & required for new rows.
ALTER TABLE staff_members ADD COLUMN IF NOT EXISTS owner_id TEXT;

-- 3. Meter readings table — sample tenant-scoped transaction table
--    Demonstrates how ALL future feature tables must include business_id + owner_id
CREATE TABLE IF NOT EXISTS meter_readings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id     TEXT NOT NULL,                       -- tenant_id (strict isolation)
    owner_id        TEXT NOT NULL,                       -- Owner's Cognito sub
    staff_id        UUID NOT NULL REFERENCES staff_members(id),
    nozzle_id       TEXT NOT NULL,
    reading_type    TEXT NOT NULL CHECK (reading_type IN ('opening', 'closing')),
    reading_value   NUMERIC(12, 2) NOT NULL,
    shift_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    shift_number    INTEGER NOT NULL DEFAULT 1,
    photo_url       TEXT,                                -- Optional evidence photo
    latitude        DOUBLE PRECISION,
    longitude       DOUBLE PRECISION,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_meter_readings_business ON meter_readings(business_id);
CREATE INDEX IF NOT EXISTS idx_meter_readings_staff ON meter_readings(staff_id);
CREATE INDEX IF NOT EXISTS idx_meter_readings_shift ON meter_readings(business_id, shift_date, shift_number);

-- 4. RLS Policies — strict tenant isolation
ALTER TABLE staff_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE meter_readings ENABLE ROW LEVEL SECURITY;

CREATE POLICY staff_invitations_tenant_isolation ON staff_invitations
    USING (business_id = current_setting('app.tenant_id', TRUE));

CREATE POLICY meter_readings_tenant_isolation ON meter_readings
    USING (business_id = current_setting('app.tenant_id', TRUE));

-- 5. Helper function: Generate a unique DX-XXXX linking code
CREATE OR REPLACE FUNCTION generate_linking_code()
RETURNS TEXT AS $$
DECLARE
    code TEXT;
    exists_flag BOOLEAN;
BEGIN
    LOOP
        -- Generate DX- prefix + 4-digit random number
        code := 'DX-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
        -- Check uniqueness among active invites
        SELECT EXISTS(
            SELECT 1 FROM staff_invitations
            WHERE linking_code = code AND status = 'pending'
        ) INTO exists_flag;
        EXIT WHEN NOT exists_flag;
    END LOOP;
    RETURN code;
END;
$$ LANGUAGE plpgsql;

-- 6. Auto-expire stale invitations (can be called by a cron or on-demand)
CREATE OR REPLACE FUNCTION expire_stale_invitations()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    UPDATE staff_invitations
    SET status = 'expired', updated_at = NOW()
    WHERE status = 'pending' AND expiry_date < NOW();
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;
