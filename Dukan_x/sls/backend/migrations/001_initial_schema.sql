-- ============================================
-- SLS Database Schema - Next-Generation Software Licensing System
-- PostgreSQL 15+
-- ============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. ADMINS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS admins (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    username        VARCHAR(255) UNIQUE,              -- Added for flexibility
    password_hash   VARCHAR(255) NOT NULL,           -- bcrypt hashed
    display_name    VARCHAR(100) NOT NULL,
    role            VARCHAR(20) NOT NULL DEFAULT 'admin',  -- superadmin | admin
    is_active       BOOLEAN DEFAULT TRUE,
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 2. RESELLERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS resellers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    company_name    VARCHAR(200) NOT NULL,
    display_name    VARCHAR(100) NOT NULL,
    
    -- Credit System
    total_credits   INTEGER NOT NULL DEFAULT 0,      -- total keys they can generate
    used_credits    INTEGER NOT NULL DEFAULT 0,      -- keys already generated
    
    -- Restrictions
    allowed_tiers   TEXT[] DEFAULT ARRAY['basic'],   -- which tiers they can issue
    max_trial_days  INTEGER DEFAULT 7,               -- max trial duration they can set
    
    is_active       BOOLEAN DEFAULT TRUE,
    created_by      UUID REFERENCES admins(id),
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 3. LICENSES TABLE (Core)
-- ============================================
CREATE TABLE IF NOT EXISTS licenses (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Key Data
    license_key     VARCHAR(29) UNIQUE NOT NULL,     -- XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
    key_hash        VARCHAR(64) NOT NULL,            -- SHA-256 for fast indexed lookup
    
    -- Status & Type
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'suspended', 'banned', 'expired', 'revoked', 'blocked', 'trial')),
    license_type    VARCHAR(20) NOT NULL
                    CHECK (license_type IN ('trial', 'standard', 'lifetime')),
    tier            VARCHAR(20) NOT NULL DEFAULT 'basic'
                    CHECK (tier IN ('basic', 'pro', 'enterprise')),
    
    -- Feature Flags (the "Feature Flag Licensing" requirement)
    feature_flags   JSONB NOT NULL DEFAULT '{}',
    is_pump_module_enabled BOOLEAN DEFAULT FALSE,    -- Pump Module Flag
    
    -- Concurrency Control (Floating Licenses)
    max_devices     INTEGER NOT NULL DEFAULT 1,      -- max simultaneous devices
    
    -- Geo-Fencing
    allowed_countries TEXT[] DEFAULT '{}',            -- empty = all countries allowed
    
    -- Duration & Expiry
    starts_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ,                     -- NULL = lifetime
    trial_days      INTEGER,                         -- for trial licenses
    
    -- Ownership
    issued_to_email VARCHAR(255),
    issued_to_name  VARCHAR(200),
    issued_by       UUID REFERENCES admins(id),
    reseller_id     UUID REFERENCES resellers(id),   -- NULL if issued by admin directly
    
    -- Metadata
    notes           TEXT,
    metadata        JSONB DEFAULT '{}',              -- extensible metadata
    last_sync_at    TIMESTAMPTZ,                     -- Pump sync timestamp
    
    -- Soft Delete
    is_deleted      BOOLEAN DEFAULT FALSE,
    deleted_at      TIMESTAMPTZ,
    
    -- Timestamps
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 4. HWID BINDINGS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS hwid_bindings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_id      UUID NOT NULL REFERENCES licenses(id) ON DELETE CASCADE,
    
    -- Hardware Fingerprint
    hwid_hash       VARCHAR(128) NOT NULL,           -- SHA-256 of composite HWID
    motherboard_id  VARCHAR(255),                    -- raw motherboard serial (encrypted)
    disk_serial     VARCHAR(255),                    -- raw disk serial (encrypted)
    mac_address     VARCHAR(255),                    -- raw MAC (encrypted)
    
    -- Device Info
    device_name     VARCHAR(200),
    os_info         VARCHAR(200),
    
    is_active       BOOLEAN DEFAULT TRUE,
    bound_at        TIMESTAMPTZ DEFAULT NOW(),
    last_seen_at    TIMESTAMPTZ DEFAULT NOW(),
    
    -- Prevent duplicate HWID for same license
    UNIQUE (license_id, hwid_hash)
);

-- ============================================
-- 5. ACTIVE SESSIONS TABLE (Floating License Tracking)
-- ============================================
CREATE TABLE IF NOT EXISTS active_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_id      UUID NOT NULL REFERENCES licenses(id) ON DELETE CASCADE,
    hwid_binding_id UUID REFERENCES hwid_bindings(id) ON DELETE SET NULL,
    
    session_token   VARCHAR(128) UNIQUE NOT NULL,
    ip_address      INET,
    country_code    VARCHAR(2),
    
    last_heartbeat  TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL,            -- session auto-expires
    
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 6. PUMP DAILY READINGS (New Module)
-- ============================================
CREATE TABLE IF NOT EXISTS pump_daily_readings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Context
    license_key     VARCHAR(29) NOT NULL REFERENCES licenses(license_key) ON DELETE CASCADE,
    
    -- Readings
    pump_no         INTEGER,
    nozzle_id       VARCHAR(50),
    
    opening_reading DECIMAL(15, 2) NOT NULL DEFAULT 0,
    closing_reading DECIMAL(15, 2) NOT NULL DEFAULT 0,
    total_sale_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    
    -- Shift Info
    shift_id        VARCHAR(100),
    staff_id        VARCHAR(100),
    
    -- Timestamps
    sync_timestamp  TIMESTAMPTZ DEFAULT NOW(),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 7. ACCESS LOGS TABLE (Audit Trail)
-- ============================================
CREATE TABLE IF NOT EXISTS access_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_id      UUID REFERENCES licenses(id) ON DELETE SET NULL,
    
    -- Request Info
    action          VARCHAR(50) NOT NULL,            -- validate | activate | heartbeat | offline_activate
    ip_address      INET,
    country_code    VARCHAR(2),
    user_agent      TEXT,
    
    -- HWID at time of request
    hwid_hash       VARCHAR(128),
    
    -- Result
    success         BOOLEAN NOT NULL,
    failure_reason  VARCHAR(200),                    -- expired | suspended | hwid_mismatch | geo_blocked | device_limit
    
    -- Response payload (for debugging)
    response_data   JSONB DEFAULT '{}',
    
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 8. OFFLINE ACTIVATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS offline_activations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_id      UUID NOT NULL REFERENCES licenses(id) ON DELETE CASCADE,
    
    -- Request Data
    request_nonce   VARCHAR(64) UNIQUE NOT NULL,
    request_hwid    VARCHAR(128) NOT NULL,
    request_data    JSONB NOT NULL,                  -- full request payload
    
    -- Signed Response
    signed_payload  TEXT,                            -- RSA-signed license file content
    signature       TEXT,                            -- detached RSA signature
    
    -- Status
    status          VARCHAR(20) DEFAULT 'pending'
                    CHECK (status IN ('pending', 'signed', 'revoked')),
    
    signed_by       UUID REFERENCES admins(id),
    signed_at       TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ,                     -- offline license expiry
    
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 9. INDEXES for Performance
-- ============================================

-- Licenses
CREATE INDEX IF NOT EXISTS idx_licenses_key_hash ON licenses(key_hash);
CREATE INDEX IF NOT EXISTS idx_licenses_status ON licenses(status);
CREATE INDEX IF NOT EXISTS idx_licenses_tier ON licenses(tier);
CREATE INDEX IF NOT EXISTS idx_licenses_expires_at ON licenses(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_licenses_reseller_id ON licenses(reseller_id) WHERE reseller_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_licenses_is_deleted ON licenses(is_deleted) WHERE is_deleted = FALSE;

-- HWID Bindings
CREATE INDEX IF NOT EXISTS idx_hwid_license_id ON hwid_bindings(license_id);
CREATE INDEX IF NOT EXISTS idx_hwid_hash ON hwid_bindings(hwid_hash);

-- Active Sessions
CREATE INDEX IF NOT EXISTS idx_sessions_license_id ON active_sessions(license_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON active_sessions(expires_at);

-- Pump Readings
CREATE INDEX IF NOT EXISTS idx_pump_readings_license_key ON pump_daily_readings(license_key);
CREATE INDEX IF NOT EXISTS idx_pump_readings_sync_time ON pump_daily_readings(sync_timestamp);

-- Access Logs (partitioning candidate for production)
CREATE INDEX IF NOT EXISTS idx_access_logs_license_id ON access_logs(license_id);
CREATE INDEX IF NOT EXISTS idx_access_logs_created_at ON access_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_access_logs_ip ON access_logs(ip_address);
CREATE INDEX IF NOT EXISTS idx_access_logs_action ON access_logs(action);

-- Offline Activations
CREATE INDEX IF NOT EXISTS idx_offline_license_id ON offline_activations(license_id);
CREATE INDEX IF NOT EXISTS idx_offline_nonce ON offline_activations(request_nonce);

-- ============================================
-- TRIGGER: Auto-update updated_at
-- ============================================
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at_admins ON admins;
CREATE TRIGGER set_updated_at_admins
    BEFORE UPDATE ON admins
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_resellers ON resellers;
CREATE TRIGGER set_updated_at_resellers
    BEFORE UPDATE ON resellers
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

DROP TRIGGER IF EXISTS set_updated_at_licenses ON licenses;
CREATE TRIGGER set_updated_at_licenses
    BEFORE UPDATE ON licenses
    FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ============================================
-- SEED: Default Admin Account
-- Password: 'ChangeThisPassword!' (bcrypt hashed)
-- ============================================
INSERT INTO admins (email, password_hash, display_name, role)
VALUES (
    'admin@sls.local',
    '$2a$12$LJ3m4ys3Rz0GWwKnUzTmTeYVLHxqCh1P0aUMxB4FvGkRmE2J/KOZO',
    'System Administrator',
    'superadmin'
) ON CONFLICT (email) DO NOTHING;
