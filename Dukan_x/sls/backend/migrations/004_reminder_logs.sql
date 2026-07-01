-- ============================================
-- Migration 004: Reminder Logs + Customer Reminder Fields
-- ============================================
-- Adds:
-- 1. reminder_logs table for tracking all sent reminders
-- 2. last_reminder_sent_at and is_auto_reminder_enabled columns to customers
-- ============================================

-- 1. Reminder Logs Table
CREATE TABLE IF NOT EXISTS reminder_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id     TEXT NOT NULL,
    vendor_id       TEXT NOT NULL,
    reminder_type   TEXT NOT NULL DEFAULT 'MANUAL',  -- MANUAL | AUTO
    outstanding_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    status          TEXT NOT NULL DEFAULT 'SENT',     -- SENT | DELIVERED | FAILED
    error_message   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reminder_logs_customer
    ON reminder_logs(customer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reminder_logs_vendor
    ON reminder_logs(vendor_id, created_at DESC);

-- 2. Add reminder columns to customers table (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'customers' AND column_name = 'last_reminder_sent_at'
    ) THEN
        ALTER TABLE customers ADD COLUMN last_reminder_sent_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'customers' AND column_name = 'is_auto_reminder_enabled'
    ) THEN
        ALTER TABLE customers ADD COLUMN is_auto_reminder_enabled BOOLEAN NOT NULL DEFAULT false;
    END IF;
END $$;

-- 3. RLS Policy for reminder_logs (tenant isolation)
ALTER TABLE reminder_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY reminder_logs_tenant_isolation ON reminder_logs
    USING (vendor_id = current_setting('app.tenant_id', true))
    WITH CHECK (vendor_id = current_setting('app.tenant_id', true));
