-- ============================================================================
-- Function: apply_rls_to_all_tables
-- Purpose: 
-- 1. Auto-Discovery: Finds all tables in 'public' schema with 'tenant_id' column.
-- 2. Enable RLS: Executes ALTER TABLE ... ENABLE ROW LEVEL SECURITY.
-- 3. Dynamic Policy: Drops old policy provided by variable `policy_name` & creates a new one.
-- 4. Isolation Logic: Uses `current_setting('app.current_tenant')` to match `tenant_id`.
-- 5. Idempotency: Safe to run repeatedly.
-- 6. Exclusion List: Accepts an array of table names to skip.
-- ============================================================================

CREATE OR REPLACE FUNCTION apply_rls_to_all_tables(
    exclude_tables TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS TABLE (
    schema_name TEXT,
    table_name TEXT,
    status TEXT
) AS $$
DECLARE
    r RECORD;
    policy_name TEXT := 'tenant_isolation_policy';
    sql_cmd TEXT;
BEGIN
    -- Iterate over every table in the public schema that has a 'tenant_id' column.
    FOR r IN
        SELECT c.table_schema, c.table_name
        FROM information_schema.columns c
        WHERE c.column_name = 'tenant_id'
          AND c.table_schema = 'public' 
          -- Exclude tables from the input list (e.g., global config tables)
          AND c.table_name <> ALL(exclude_tables)
    LOOP
        -- 1. Enable Row Level Security (Idempotent: safe to run if already enabled)
        EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY;', r.table_schema, r.table_name);
        -- 1b. FORCE Row Level Security (Owner is also subject to RLS)
        EXECUTE format('ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY;', r.table_schema, r.table_name);

        -- 2. Drop existing policy to allow updates (Idempotent)
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I;', policy_name, r.table_schema, r.table_name);

        -- 3. Create the new policy
        -- We use `current_setting('app.current_tenant', true)`:
        -- - The second argument `true` ensures it returns NULL instead of error if not set.
        -- - We cast to UUID to match the column type (assuming tenant_id is UUID).
        sql_cmd := format(
            'CREATE POLICY %I ON %I.%I ' ||
            'USING (tenant_id = current_setting(''app.current_tenant'', true)::uuid) ' ||
            'WITH CHECK (tenant_id = current_setting(''app.current_tenant'', true)::uuid);',
            policy_name, r.table_schema, r.table_name
        );
        
        EXECUTE sql_cmd;

        -- Return the result for this table
        schema_name := r.table_schema;
        table_name := r.table_name;
        status := 'RLS Enabled & Policy Applied';
        RETURN NEXT;
    END LOOP;

    -- Handle case where no tables were found (optional, but good for feedback)
    IF NOT FOUND THEN
        schema_name := 'public';
        table_name := 'none';
        status := 'No tables found with tenant_id column';
        RETURN NEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Usage Examples:
-- ============================================================================

-- 1. Apply to all tables (no exclusions)
-- SELECT * FROM apply_rls_to_all_tables();

-- 2. Apply to all tables EXCEPT 'global_settings' and 'users' (if they have tenant_id but need different logic)
-- SELECT * FROM apply_rls_to_all_tables(ARRAY['global_settings', 'users']);

-- ============================================================================
-- How to trigger automatically:
-- ============================================================================
-- You can run this function as part of your migration scripts or CI/CD pipeline.
-- Whenever you add a new table with `tenant_id`, just run:
-- SELECT * FROM apply_rls_to_all_tables();
-- It will re-apply/ensure policies on all tables, including the new one.
