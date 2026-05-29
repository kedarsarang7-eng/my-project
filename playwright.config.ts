import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration for DukanX Restaurant PWA E2E testing.
 * Targets the Flutter Web build served via a static HTTP server.
 *
 * See https://playwright.dev/docs/test-configuration
 */
export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 1,
  workers: process.env.CI ? 1 : undefined,

  reporter: [
    ['list'],
    ['html', { open: 'never' }],
  ],

  use: {
    baseURL: 'http://localhost:4173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    // ── Desktop browsers ──────────────────────────────────────────────
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },

    // ── Responsive viewports ──────────────────────────────────────────
    {
      name: 'mobile-chrome',
      use: {
        ...devices['Pixel 5'],          // 393×851  — close to 375×667
      },
    },
    {
      name: 'tablet-chrome',
      use: {
        viewport: { width: 768, height: 1024 },
        userAgent: devices['Desktop Chrome'].userAgent,
      },
    },
  ],

  /* Start a static file server for the Flutter web build */
  webServer: {
    command: 'npx serve dukan_restro_pwa/build/web -l 4173 --no-clipboard',
    url: 'http://localhost:4173',
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
