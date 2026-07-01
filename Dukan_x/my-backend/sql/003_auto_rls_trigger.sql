-- ============================================================================
-- Event Trigger: auto_enable_rls
-- ============================================================================
-- Automatically enables RLS on any new table created in the 'public' schema
-- if it contains a 'tenant_id' column.
-- ============================================================================

-- Function to check the new table and apply RLS
CREATE OR REPLACE FUNCTION public.handle_new_table_rls()
RETURNS event_trigger AS $$
DECLARE
    obj record;
    has_tenant_id boolean;
BEGIN
    -- Iterate over the objects created by the DDL command
    FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands() WHERE command_tag = 'CREATE TABLE'
    LOOP
        -- Check if table is in public schema
        IF obj.schema_name = 'public' THEN
            -- Check if the table has a tenant_id column
            -- Note: We have to query the system catalogs dynamically
            EXECUTE format(
                'SELECT EXISTS (
                    SELECT 1 FROM information_schema.columns 
                    WHERE table_schema = %L AND table_name = %L AND column_name = ''tenant_id''
                )',
                obj.schema_name, obj.object_identity
            ) INTO has_tenant_id;

            IF has_tenant_id THEN
                -- Apply RLS using our existing function (or direct commands)
                -- Warning: running ALTER TABLE inside an event trigger can be tricky.
                -- However, since this is 'ddl_command_end', the table exists.
                
                -- We'll just call our main function to handle it.
                -- It scans all tables, which is fine, or we could target just this one if we refactored.
                -- For simplicity and robustness, we re-run the idempotency script.
                -- Optimization: In a high-traffic DDL env, this might be slow, but for typical apps it's fine.
                PERFORM public.apply_rls_to_all_tables();
                
                RAISE NOTICE 'Auto-enabled RLS for table: %', obj.object_identity;
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create the event trigger
DROP EVENT TRIGGER IF EXISTS trg_auto_enable_rls;

CREATE EVENT TRIGGER trg_auto_enable_rls
ON ddl_command_end
WHEN TAG IN ('CREATE TABLE')
EXECUTE FUNCTION public.handle_new_table_rls();
