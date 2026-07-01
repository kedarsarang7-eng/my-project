// ============================================
// Input Validation Schemas — Zod
// ============================================

import { z } from 'zod';

// ---- Auth ----

export const loginSchema = z.object({
    email: z.string().email('Invalid email address'),
    password: z.string().min(8, 'Password must be at least 8 characters'),
});

// ---- License Creation ----

export const createLicenseSchema = z.object({
    license_type: z.enum(['trial', 'standard', 'lifetime']),
    tier: z.enum(['basic', 'pro', 'enterprise']).default('basic'),
    feature_flags: z.record(z.union([z.boolean(), z.number(), z.string()])).optional().default({}),
    max_devices: z.number().int().min(1).max(1000).optional().default(1),
    allowed_countries: z.array(z.string().length(2)).optional().default([]),
    expires_at: z.string().datetime().optional(),
    trial_days: z.number().int().min(1).max(365).optional(),
    issued_to_email: z.string().email().optional(),
    issued_to_name: z.string().max(200).optional(),
    notes: z.string().max(1000).optional(),
});

// ---- License Update ----

export const updateLicenseSchema = z.object({
    status: z.enum(['active', 'suspended', 'banned', 'expired', 'revoked']).optional(),
    tier: z.enum(['basic', 'pro', 'enterprise']).optional(),
    feature_flags: z.record(z.union([z.boolean(), z.number(), z.string()])).optional(),
    max_devices: z.number().int().min(1).max(1000).optional(),
    allowed_countries: z.array(z.string().length(2)).optional(),
    expires_at: z.string().datetime().nullable().optional(),
    issued_to_email: z.string().email().optional(),
    issued_to_name: z.string().max(200).optional(),
    notes: z.string().max(1000).optional(),
}).refine(data => Object.keys(data).length > 0, {
    message: 'At least one field must be provided for update',
});

// ---- Validation Request (Client-Facing) ----

export const validateSchema = z.object({
    license_key: z.string()
        .regex(/^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$/,
            'Invalid license key format. Expected: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX'),
    hwid: z.string().min(16).max(256),
    device_name: z.string().max(200).optional(),
    os_info: z.string().max(200).optional(),
});

// ---- Reseller Creation ----

export const createResellerSchema = z.object({
    email: z.string().email(),
    password: z.string().min(8).max(128),
    company_name: z.string().min(2).max(200),
    display_name: z.string().min(2).max(100),
    total_credits: z.number().int().min(0).max(100000),
    allowed_tiers: z.array(z.enum(['basic', 'pro', 'enterprise'])).min(1),
    max_trial_days: z.number().int().min(1).max(365).optional().default(7),
});

// ---- Reseller Generate Key ----

export const resellerGenerateSchema = z.object({
    license_type: z.enum(['trial', 'standard', 'lifetime']),
    tier: z.enum(['basic', 'pro', 'enterprise']),
    feature_flags: z.record(z.union([z.boolean(), z.number(), z.string()])).optional().default({}),
    max_devices: z.number().int().min(1).max(100).optional().default(1),
    expires_at: z.string().datetime().optional(),
    trial_days: z.number().int().min(1).max(365).optional(),
    issued_to_email: z.string().email().optional(),
    issued_to_name: z.string().max(200).optional(),
});

// ---- Offline Activation ----

export const offlineSignSchema = z.object({
    license_key: z.string()
        .regex(/^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$/,
            'Invalid license key format'),
    hwid: z.string().min(16).max(256),
    nonce: z.string().min(16).max(64),
    device_name: z.string().max(200).optional(),
});

// ---- Pagination ----

export const paginationSchema = z.object({
    page: z.coerce.number().int().min(1).optional().default(1),
    limit: z.coerce.number().int().min(1).max(100).optional().default(25),
    sort_by: z.string().optional().default('created_at'),
    sort_order: z.enum(['asc', 'desc']).optional().default('desc'),
    search: z.string().max(100).optional(),
    status: z.enum(['active', 'suspended', 'banned', 'expired', 'revoked']).optional(),
    tier: z.enum(['basic', 'pro', 'enterprise']).optional(),
    license_type: z.enum(['trial', 'standard', 'lifetime']).optional(),
});

// ---- Helper: Validate and parse request body ----

export function validateBody<T>(schema: z.ZodSchema<T>, body: unknown): T {
    return schema.parse(body);
}
