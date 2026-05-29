import { test, expect, type Page } from '@playwright/test';

/**
 * Smoke Tests — verify every public route loads without crashing.
 *
 * Flutter Web uses hash routing, so all routes are under /#/<path>.
 * The PWA is a customer-facing ordering app; most routes work without
 * backend data but may show "error" states (expected without API).
 * We verify Flutter itself initializes and the route resolves.
 */

const FLUTTER_LOAD_TIMEOUT = 20_000;

/** Wait for Flutter engine to finish loading */
async function waitForFlutterReady(page: Page) {
  // Flutter renders into a <flt-glass-pane> or a shadow DOM host.
  // The simplest signal is that main.dart.js has executed and the
  // initial "loading" indicator is replaced by actual content.
  await page.waitForFunction(
    () => {
      // Flutter 3.x renders into shadow DOM under <flutter-view> or <flt-glass-pane>
      const glassPane = document.querySelector('flt-glass-pane') ||
                        document.querySelector('flutter-view');
      return glassPane !== null;
    },
    { timeout: FLUTTER_LOAD_TIMEOUT }
  );
  // Give Flutter a moment to settle after glass pane appears
  await page.waitForTimeout(2000);
}

// ── Public routes that should render without crashing ────────────────────────

const PUBLIC_ROUTES = [
  { path: '/',       name: 'Landing / QR Scan' },
  { path: '/login',  name: 'Login' },
  { path: '/signup', name: 'Sign Up' },
];

for (const route of PUBLIC_ROUTES) {
  test(`Smoke: ${route.name} (${route.path}) loads`, async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    const response = await page.goto(`/#${route.path}`);
    expect(response?.status()).toBe(200);

    await waitForFlutterReady(page);

    // Flutter should have rendered — check that the glass pane exists
    const hasGlassPane = await page.evaluate(() => {
      return !!(document.querySelector('flt-glass-pane') ||
                document.querySelector('flutter-view'));
    });
    expect(hasGlassPane).toBe(true);

    // Filter out expected Flutter/service-worker console noise
    const realErrors = consoleErrors.filter(msg =>
      !msg.includes('service-worker') &&
      !msg.includes('Failed to register') &&
      !msg.includes('Manifest') &&
      !msg.includes('favicon') &&
      !msg.includes('flutter_service_worker')
    );

    // Log but don't fail on console errors from Flutter framework internals
    if (realErrors.length > 0) {
      console.warn(`Console errors on ${route.path}:`, realErrors);
    }
  });
}

// ── Network: no 4xx/5xx on static asset loads ──────────────────────────────

test('Smoke: no 4xx/5xx on static assets for landing page', async ({ page }) => {
  const failedRequests: { url: string; status: number }[] = [];

  page.on('response', response => {
    const url = response.url();
    const status = response.status();
    // Only check static asset requests to our server
    if (url.startsWith('http://localhost') && status >= 400) {
      failedRequests.push({ url, status });
    }
  });

  await page.goto('/#/');
  await waitForFlutterReady(page);

  // Filter out expected failures (API calls that will fail without backend)
  const assetFailures = failedRequests.filter(r =>
    !r.url.includes('/api/') &&
    !r.url.includes('execute-api') &&
    !r.url.includes('cognito')
  );

  expect(assetFailures).toEqual([]);
});
