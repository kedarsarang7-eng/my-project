// ============================================================================
// seed-data.ts — Pre-test data population seeder
// ============================================================================
//
// phase5-load-plan.md §6.3 — Data Seeding
//
// Before each test run:
//   1. Create 10,000 user records with roles distributed per §3.3
//   2. Assign randomized UserPreference records (quiet hours, mute targets,
//      per-category channels)
//   3. Pre-populate 100 notifications per user to simulate realistic
//      history-query load
//
// Role distribution (§6.3):
//   5% admin, 15% cashier, 10% accountant, 5% delivery_agent, 10% vendor,
//   20% customer, 5% chef, 5% kitchen_staff, 5% school_admin, 10% teacher,
//   5% student, 5% parent
//
// Usage:
//   npx ts-node --transpile-only \
//     my-backend/tests/notifications/load/seed-data.ts \
//     --run-id=<RUN_ID> \
//     --users=10000 \
//     --notifications-per-user=100 \
//     --endpoint=https://api.staging.uns.example.com \
//     --dry-run
//
// Environment variables:
//   SEED_ENDPOINT    — API base URL (default: http://localhost:3000)
//   SEED_AUTH_TOKEN  — Bearer token for API auth
//   SEED_RUN_ID     — Run ID for namespacing (default: generated)
//   SEED_DRY_RUN    — If 'true', only prints what would be created
// ============================================================================

import * as crypto from 'crypto';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type RoleId =
    | 'admin'
    | 'cashier'
    | 'accountant'
    | 'delivery_agent'
    | 'vendor'
    | 'customer'
    | 'chef'
    | 'kitchen_staff'
    | 'school_admin'
    | 'teacher'
    | 'student'
    | 'parent';

type Channel = 'in_app' | 'push' | 'sms' | 'email' | 'webhook';

type Priority = 'critical' | 'high' | 'normal' | 'low';

type Category =
    | 'billing'
    | 'orders'
    | 'payments'
    | 'inventory'
    | 'users'
    | 'system'
    | 'delivery'
    | 'reports';

interface UserSeed {
    user_id: string;
    role: RoleId;
    tenant_id: string;
    preferences: UserPreferenceSeed;
}

interface UserPreferenceSeed {
    per_category_channels: Partial<Record<Category, Channel[]>>;
    per_event_channels: Record<string, Channel[]>;
    quiet_hours_start: string | null;
    quiet_hours_end: string | null;
    quiet_hours_timezone: string | null;
    mute_targets: string[];
}

interface NotificationSeed {
    notification_id: string;
    event_name: string;
    category: Category;
    priority: Priority;
    actor_id: string;
    target_id: string;
    recipient_user_id: string;
    status: 'delivered' | 'read';
    created_at: string;
    payload: Record<string, unknown>;
}

interface SeedConfig {
    runId: string;
    endpoint: string;
    authToken: string;
    totalUsers: number;
    notificationsPerUser: number;
    dryRun: boolean;
    batchSize: number;
    concurrency: number;
}

// ---------------------------------------------------------------------------
// Constants — role distribution per §6.3
// ---------------------------------------------------------------------------

const ROLE_DISTRIBUTION: Record<RoleId, number> = {
    admin: 5,
    cashier: 15,
    accountant: 10,
    delivery_agent: 5,
    vendor: 10,
    customer: 20,
    chef: 5,
    kitchen_staff: 5,
    school_admin: 5,
    teacher: 10,
    student: 5,
    parent: 5,
};

const ROLE_DEFAULT_CHANNELS: Record<RoleId, Channel[]> = {
    admin: ['in_app', 'push', 'email'],
    cashier: ['in_app', 'push'],
    accountant: ['in_app', 'email'],
    delivery_agent: ['in_app', 'push', 'sms'],
    vendor: ['in_app', 'email'],
    customer: ['in_app', 'email', 'sms'],
    chef: ['in_app'],
    kitchen_staff: ['in_app'],
    school_admin: ['in_app', 'email'],
    teacher: ['in_app', 'email'],
    student: ['in_app', 'push'],
    parent: ['in_app', 'push', 'sms'],
};

const CATEGORIES: Category[] = [
    'billing', 'orders', 'payments', 'inventory',
    'users', 'system', 'delivery', 'reports',
];

const SAMPLE_EVENTS: Record<Category, string[]> = {
    billing: ['billing.invoice.created', 'billing.invoice.finalized', 'billing.school_fee.assigned'],
    orders: ['orders.restaurant_kot.created', 'orders.service_job.status_changed'],
    payments: ['payment.invoice.received', 'payment.gateway.success', 'payment.refund.processed'],
    inventory: ['inventory.stock.changed', 'inventory.stock.low'],
    users: ['users.school_announcement.published', 'users.school_attendance.marked'],
    system: ['system.security_access.unauthorized_attempt', 'system.health.degraded'],
    delivery: ['delivery.location.updated', 'delivery.restaurant.dispatched'],
    reports: ['reports.pump_sale.recorded'],
};

// ---------------------------------------------------------------------------
// Deterministic PRNG (seeded for reproducibility)
// ---------------------------------------------------------------------------

class SeededRandom {
    private state: number;

    constructor(seed: string) {
        this.state = this.hashToInt(seed);
    }

    next(): number {
        this.state = (this.state * 1664525 + 1013904223) | 0;
        return ((this.state >>> 0) % 0xffffffff) / 0xffffffff;
    }

    pick<T>(arr: T[]): T {
        return arr[Math.floor(this.next() * arr.length)];
    }

    weightedPick<T extends string>(weights: Record<T, number>): T {
        const entries = Object.entries(weights) as Array<[T, number]>;
        const total = entries.reduce((sum, [, w]) => sum + (w as number), 0);
        const target = this.next() * total;
        let acc = 0;
        for (const [value, weight] of entries) {
            acc += weight as number;
            if (target < acc) return value;
        }
        return entries[entries.length - 1][0];
    }

    private hashToInt(input: string): number {
        let hash = 0x811c9dc5;
        for (let i = 0; i < input.length; i++) {
            hash ^= input.charCodeAt(i);
            hash = Math.imul(hash, 0x01000193);
        }
        return hash >>> 0;
    }
}

// ---------------------------------------------------------------------------
// User generation
// ---------------------------------------------------------------------------

function generateUsers(config: SeedConfig, rng: SeededRandom): UserSeed[] {
    const users: UserSeed[] = [];
    const tenantCount = 50; // §3.3 — 50 tenants

    for (let i = 0; i < config.totalUsers; i++) {
        const role = rng.weightedPick(ROLE_DISTRIBUTION);
        const tenantIdx = Math.floor(i / (config.totalUsers / tenantCount));
        const tenantId = `loadtest-${config.runId}-tenant-${String(tenantIdx).padStart(3, '0')}`;
        const userId = `loadtest-${config.runId}-user-${String(i).padStart(5, '0')}`;

        const preferences = generatePreferences(role, rng);

        users.push({
            user_id: userId,
            role,
            tenant_id: tenantId,
            preferences,
        });
    }

    return users;
}

function generatePreferences(role: RoleId, rng: SeededRandom): UserPreferenceSeed {
    const defaultChannels = ROLE_DEFAULT_CHANNELS[role];

    // 60% use defaults, 25% have category overrides, 10% have quiet hours, 5% have mutes
    const prefType = rng.next();

    const perCategoryChannels: Partial<Record<Category, Channel[]>> = {};
    const perEventChannels: Record<string, Channel[]> = {};
    let quietStart: string | null = null;
    let quietEnd: string | null = null;
    let quietTz: string | null = null;
    let muteTargets: string[] = [];

    if (prefType > 0.60 && prefType <= 0.85) {
        // Category overrides — override 1-3 categories
        const overrideCount = Math.floor(rng.next() * 3) + 1;
        for (let i = 0; i < overrideCount; i++) {
            const cat = rng.pick(CATEGORIES);
            // Subset of default channels
            const subset = defaultChannels.filter(() => rng.next() > 0.3);
            perCategoryChannels[cat] = subset.length > 0 ? subset : ['in_app'];
        }
    } else if (prefType > 0.85 && prefType <= 0.95) {
        // Quiet hours + event overrides
        quietStart = '22:00';
        quietEnd = '07:00';
        quietTz = 'Asia/Kolkata';

        // Override 1-2 specific events
        const eventOverrideCount = Math.floor(rng.next() * 2) + 1;
        for (let i = 0; i < eventOverrideCount; i++) {
            const cat = rng.pick(CATEGORIES);
            const event = rng.pick(SAMPLE_EVENTS[cat]);
            perEventChannels[event] = ['in_app']; // Restrict to in_app only during quiet hours
        }
    } else if (prefType > 0.95) {
        // Mute targets
        const muteCount = Math.floor(rng.next() * 3) + 1;
        for (let i = 0; i < muteCount; i++) {
            const cat = rng.pick(CATEGORIES);
            const event = rng.pick(SAMPLE_EVENTS[cat]);
            muteTargets.push(event);
        }
        muteTargets = [...new Set(muteTargets)]; // Deduplicate
    }

    return {
        per_category_channels: perCategoryChannels,
        per_event_channels: perEventChannels,
        quiet_hours_start: quietStart,
        quiet_hours_end: quietEnd,
        quiet_hours_timezone: quietTz,
        mute_targets: muteTargets,
    };
}

// ---------------------------------------------------------------------------
// Notification generation — 100 per user for realistic history load
// ---------------------------------------------------------------------------

function generateNotifications(
    user: UserSeed,
    count: number,
    rng: SeededRandom,
    config: SeedConfig,
): NotificationSeed[] {
    const notifications: NotificationSeed[] = [];
    const now = Date.now();

    for (let i = 0; i < count; i++) {
        const category = rng.pick(CATEGORIES);
        const eventName = rng.pick(SAMPLE_EVENTS[category]);
        const priority = rng.weightedPick({
            critical: 2,
            high: 18,
            normal: 60,
            low: 20,
        } as Record<Priority, number>);

        // Spread notifications over the past 7 days (within replay window)
        const ageMs = Math.floor(rng.next() * 7 * 24 * 60 * 60 * 1000);
        const createdAt = new Date(now - ageMs).toISOString();

        // 70% delivered, 30% read
        const status: 'delivered' | 'read' = rng.next() < 0.7 ? 'delivered' : 'read';

        notifications.push({
            notification_id: `loadtest-${config.runId}-notif-${user.user_id}-${String(i).padStart(3, '0')}`,
            event_name: eventName,
            category,
            priority,
            actor_id: `loadtest-${config.runId}-actor-${Math.floor(rng.next() * 100)}`,
            target_id: `loadtest-${config.runId}-target-${Math.floor(rng.next() * 500)}`,
            recipient_user_id: user.user_id,
            status,
            created_at: createdAt,
            payload: {
                message: `Seed notification ${i} for ${user.role}`,
                category,
                seeded: true,
            },
        });
    }

    return notifications;
}

// ---------------------------------------------------------------------------
// API interaction — batch creation
// ---------------------------------------------------------------------------

async function createUsersBatch(
    users: UserSeed[],
    config: SeedConfig,
): Promise<{ created: number; failed: number }> {
    if (config.dryRun) {
        return { created: users.length, failed: 0 };
    }

    let created = 0;
    let failed = 0;

    const response = await fetch(`${config.endpoint}/admin/seed/users`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${config.authToken}`,
        },
        body: JSON.stringify({ users }),
    });

    if (response.ok) {
        created = users.length;
    } else {
        // Fall back to individual creation
        for (const user of users) {
            try {
                const res = await fetch(`${config.endpoint}/admin/seed/users`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${config.authToken}`,
                    },
                    body: JSON.stringify({ users: [user] }),
                });
                if (res.ok) created++;
                else failed++;
            } catch {
                failed++;
            }
        }
    }

    return { created, failed };
}

async function createNotificationsBatch(
    notifications: NotificationSeed[],
    config: SeedConfig,
): Promise<{ created: number; failed: number }> {
    if (config.dryRun) {
        return { created: notifications.length, failed: 0 };
    }

    let created = 0;
    let failed = 0;

    const response = await fetch(`${config.endpoint}/admin/seed/notifications`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${config.authToken}`,
        },
        body: JSON.stringify({ notifications }),
    });

    if (response.ok) {
        const result = await response.json() as { created?: number };
        created = result.created ?? notifications.length;
    } else {
        failed = notifications.length;
    }

    return { created, failed };
}

// ---------------------------------------------------------------------------
// Orchestrator — runs the full seeding pipeline
// ---------------------------------------------------------------------------

export interface SeedResult {
    runId: string;
    usersCreated: number;
    usersFailed: number;
    notificationsCreated: number;
    notificationsFailed: number;
    durationMs: number;
    dryRun: boolean;
}

export async function seedData(config: SeedConfig): Promise<SeedResult> {
    const startTime = Date.now();
    const rng = new SeededRandom(`${config.runId}:seed`);

    console.log(`[seed-data] Starting data seeding...`);
    console.log(`[seed-data] RUN_ID: ${config.runId}`);
    console.log(`[seed-data] Users: ${config.totalUsers}`);
    console.log(`[seed-data] Notifications per user: ${config.notificationsPerUser}`);
    console.log(`[seed-data] Endpoint: ${config.endpoint}`);
    console.log(`[seed-data] Dry run: ${config.dryRun}`);

    // Step 1: Generate and create users
    console.log(`[seed-data] Step 1/3: Generating ${config.totalUsers} users...`);
    const users = generateUsers(config, rng);

    let usersCreated = 0;
    let usersFailed = 0;

    for (let i = 0; i < users.length; i += config.batchSize) {
        const batch = users.slice(i, i + config.batchSize);
        const result = await createUsersBatch(batch, config);
        usersCreated += result.created;
        usersFailed += result.failed;

        if ((i + config.batchSize) % 1000 === 0 || i + config.batchSize >= users.length) {
            console.log(`[seed-data]   Users: ${usersCreated}/${config.totalUsers} created`);
        }
    }

    // Step 2: Generate and create preferences (included in user creation)
    console.log(`[seed-data] Step 2/3: User preferences included in user records ✓`);

    // Step 3: Generate and create notifications
    console.log(`[seed-data] Step 3/3: Generating notifications (${config.notificationsPerUser} per user)...`);
    const totalNotifications = config.totalUsers * config.notificationsPerUser;
    console.log(`[seed-data]   Total notifications to create: ${totalNotifications.toLocaleString()}`);

    let notificationsCreated = 0;
    let notificationsFailed = 0;

    // Process users in chunks to manage memory
    const userChunkSize = config.concurrency;
    for (let u = 0; u < users.length; u += userChunkSize) {
        const userChunk = users.slice(u, u + userChunkSize);

        const promises = userChunk.map(async (user) => {
            const notifications = generateNotifications(
                user,
                config.notificationsPerUser,
                new SeededRandom(`${config.runId}:notif:${user.user_id}`),
                config,
            );

            // Batch notifications in groups
            for (let n = 0; n < notifications.length; n += config.batchSize) {
                const batch = notifications.slice(n, n + config.batchSize);
                const result = await createNotificationsBatch(batch, config);
                notificationsCreated += result.created;
                notificationsFailed += result.failed;
            }
        });

        await Promise.all(promises);

        if ((u + userChunkSize) % 500 === 0 || u + userChunkSize >= users.length) {
            const pct = Math.round(((u + userChunkSize) / users.length) * 100);
            console.log(`[seed-data]   Notifications: ${pct}% complete (${notificationsCreated.toLocaleString()} created)`);
        }
    }

    const durationMs = Date.now() - startTime;

    const result: SeedResult = {
        runId: config.runId,
        usersCreated,
        usersFailed,
        notificationsCreated,
        notificationsFailed,
        durationMs,
        dryRun: config.dryRun,
    };

    console.log(`[seed-data] Seeding complete in ${(durationMs / 1000).toFixed(1)}s`);
    console.log(`[seed-data] Users: ${usersCreated} created, ${usersFailed} failed`);
    console.log(`[seed-data] Notifications: ${notificationsCreated.toLocaleString()} created, ${notificationsFailed.toLocaleString()} failed`);

    return result;
}

// ---------------------------------------------------------------------------
// CLI entry point
// ---------------------------------------------------------------------------

function parseArgs(): SeedConfig {
    const args = process.argv.slice(2);
    const flags: Record<string, string> = {};

    for (const arg of args) {
        const match = arg.match(/^--([^=]+)=(.+)$/);
        if (match) {
            flags[match[1]] = match[2];
        } else if (arg === '--dry-run') {
            flags['dry-run'] = 'true';
        }
    }

    return {
        runId: flags['run-id'] || process.env.SEED_RUN_ID || `seed-${Date.now()}`,
        endpoint: flags['endpoint'] || process.env.SEED_ENDPOINT || 'http://localhost:3000',
        authToken: flags['auth-token'] || process.env.SEED_AUTH_TOKEN || 'seed-token',
        totalUsers: parseInt(flags['users'] || '10000', 10),
        notificationsPerUser: parseInt(flags['notifications-per-user'] || '100', 10),
        dryRun: flags['dry-run'] === 'true' || process.env.SEED_DRY_RUN === 'true',
        batchSize: parseInt(flags['batch-size'] || '50', 10),
        concurrency: parseInt(flags['concurrency'] || '10', 10),
    };
}

// Run when executed directly
if (require.main === module) {
    const config = parseArgs();
    seedData(config)
        .then((result) => {
            console.log(`\n[seed-data] Result: ${JSON.stringify(result, null, 2)}`);
            process.exit(result.usersFailed > 0 || result.notificationsFailed > 0 ? 1 : 0);
        })
        .catch((err) => {
            console.error(`[seed-data] Fatal error: ${err.message}`);
            process.exit(1);
        });
}
