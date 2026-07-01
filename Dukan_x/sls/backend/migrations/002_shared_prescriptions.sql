-- ============================================================================
-- Migration 002: Shared Prescriptions Table
-- ============================================================================
-- Bridges Clinic (Doctor) and Pharmacy (Chemist) businesses.
-- Doctor uploads prescription → Pharmacy scans QR (rxId) → fetches → bills.
-- ============================================================================

CREATE TABLE IF NOT EXISTS shared_prescriptions (
    rx_id           VARCHAR(30) PRIMARY KEY,          -- e.g. 'RX-1707820000-A3F2'
    clinic_shop_id  VARCHAR(100) NOT NULL,             -- clinic's owner/shop ID
    doctor_id       VARCHAR(100) NOT NULL,
    doctor_name     VARCHAR(200) NOT NULL,
    clinic_name     VARCHAR(200) NOT NULL DEFAULT 'Clinic',
    patient_name    VARCHAR(200) NOT NULL,
    patient_phone   VARCHAR(20),
    prescription_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    advice          TEXT,
    items           JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of medicine items
    status          VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending | dispensed | expired
    fulfilled_by    VARCHAR(100),                       -- pharmacy shop ID
    fulfilled_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for pharmacy lookup by rxId (primary key covers this)
-- Index for clinic to list their prescriptions
CREATE INDEX IF NOT EXISTS idx_shared_rx_clinic ON shared_prescriptions(clinic_shop_id, created_at DESC);

-- Index for status filtering
CREATE INDEX IF NOT EXISTS idx_shared_rx_status ON shared_prescriptions(status);

-- Index for patient phone lookup
CREATE INDEX IF NOT EXISTS idx_shared_rx_patient_phone ON shared_prescriptions(patient_phone) WHERE patient_phone IS NOT NULL;
