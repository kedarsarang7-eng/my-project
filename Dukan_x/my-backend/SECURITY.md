# Security Architecture & Best Practices

## 1. Multi-Tenancy Architecture
We use a **Shared Database, Shared Schema** approach with **Row-Level Security (RLS)**.

- **Tenant Identification**: Every request must carry a valid Cognito JWT.
- **Tenant Context**: The `custom:tenant_id` claim from the JWT is extracted by middleware.
- **Data Isolation**: PostgreSQL RLS policies automatically filter all queries by `app.tenant_id`.

## 2. Secure Development Guidelines

### A. How to Add a New API Endpoint
**NEVER** manually extract the tenant ID. Always use the `authorizedHandler` wrapper.

**✅ DO THIS:**
```typescript
import { authorizedHandler } from '../middleware/handler-wrapper';

export const myHandler = authorizedHandler(
    [UserRole.ADMIN], // Allowed Roles
    async (event, context, auth) => {
        // Safe! Tenant context is already set in DB.
        const result = await db.query('SELECT * FROM my_table'); 
        return response.success(result.rows);
    }
);
```

**❌ DO NOT DO THIS:**
```typescript
export async function myHandler(event) {
    // 💀 DANGEROUS: Forgot to verify auth & set tenant context!
    // This query will return empty results (if RLS is on) or ALL data (if RLS is off)!
    const result = await db.query('SELECT * FROM my_table'); 
}
```

### B. How to Add a New Table
Every new table **MUST** have a `tenant_id` column and RLS enabled.

1. **Create Table**:
   ```sql
   CREATE TABLE my_new_table (
       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
       tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
       ...
   );
   ```

2. **Enable RLS**:
   ```sql
   ALTER TABLE my_new_table ENABLE ROW LEVEL SECURITY;
   ```

3. **Add Policy**:
   ```sql
   CREATE POLICY tenant_isolation_my_new_table ON my_new_table
   USING (tenant_id = current_setting('app.tenant_id', true)::UUID)
   WITH CHECK (tenant_id = current_setting('app.tenant_id', true)::UUID);
   ```

## 3. Verification
Run the verification script to ensure RLS is working correctly:
```bash
npx ts-node scripts/verify-tenancy.ts
```

## 4. S3 Storage Security
Files are stored in S3 with the following key structure:
`tenants/{tenant_id}/{section}/{filename}`

- **Uploads**: Use `StorageService.getUploadUrl()` to generate a pre-signed URL.
- **Downloads**: Use `StorageService.getDownloadUrl()` to generate a pre-signed URL.
- **Access Control**: The Lambda IAM role allows access to the bucket, but users/browsers NEVER get direct access. They only get short-lived (15 min) signed URLs.
