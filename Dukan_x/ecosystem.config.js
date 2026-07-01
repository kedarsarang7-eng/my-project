// ============================================================================
// PM2 Ecosystem Configuration — DukanX EC2 Deployment
// ============================================================================
// Manages both Express backends on a single EC2 t2.micro instance.
//
// Usage:
//   pm2 start ecosystem.config.js           # Start all
//   pm2 start ecosystem.config.js --only sls-backend
//   pm2 restart all                         # Restart all
//   pm2 logs                                # View logs
//   pm2 monit                               # Live monitoring
//   pm2 save && pm2 startup                 # Auto-start on reboot
//
// NOTE: my-backend runs on Lambda (not EC2), so it's NOT included here.
// ============================================================================

module.exports = {
    apps: [
        // ── Admin Backend (Port 4000) ──────────────────────────────────────
        {
            name: 'sls-backend',
            cwd: './sls/backend',
            script: 'dist/app.js',
            instances: 1,                    // t2.micro has 1 vCPU — keep at 1
            exec_mode: 'fork',               // fork mode for single instance
            autorestart: true,
            watch: false,                    // disable in production
            max_memory_restart: '400M',      // t2.micro has 1GB RAM total
            env: {
                NODE_ENV: 'production',
                PORT: 4000,
            },
            // Logging
            log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
            error_file: '/var/log/pm2/sls-backend-error.log',
            out_file: '/var/log/pm2/sls-backend-out.log',
            merge_logs: true,
            // Graceful shutdown
            kill_timeout: 5000,              // 5s for graceful shutdown
            listen_timeout: 10000,           // 10s to wait for app ready
            // Health check
            max_restarts: 10,
            min_uptime: '10s',
        },

        // ── App Backend (Port 5000) ───────────────────────────────────────
        {
            name: 'app-backend',
            cwd: './sls/app-backend',
            script: 'dist/app.js',
            instances: 1,
            exec_mode: 'fork',
            autorestart: true,
            watch: false,
            max_memory_restart: '400M',
            env: {
                NODE_ENV: 'production',
                APP_BACKEND_PORT: 5000,
            },
            // Logging
            log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
            error_file: '/var/log/pm2/app-backend-error.log',
            out_file: '/var/log/pm2/app-backend-out.log',
            merge_logs: true,
            // Graceful shutdown
            kill_timeout: 5000,
            listen_timeout: 10000,
            // Health check
            max_restarts: 10,
            min_uptime: '10s',
        },

        // ── My Backend (Port 8000) — Lambda handlers via Express adapter ──
        {
            name: 'my-backend',
            cwd: './my-backend',
            script: 'dist/server.js',
            instances: 1,
            exec_mode: 'fork',
            autorestart: true,
            watch: false,
            max_memory_restart: '300M',
            env: {
                NODE_ENV: 'production',
                MY_BACKEND_PORT: 8000,
            },
            // Logging
            log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
            error_file: '/var/log/pm2/my-backend-error.log',
            out_file: '/var/log/pm2/my-backend-out.log',
            merge_logs: true,
            // Graceful shutdown
            kill_timeout: 5000,
            listen_timeout: 10000,
            // Health check
            max_restarts: 10,
            min_uptime: '10s',
        },
    ],
};
