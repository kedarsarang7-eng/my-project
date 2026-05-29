import { test, expect, type Page } from '@playwright/test';

/**
 * Navigation Tests — verify that hash-based routing works correctly
 * for all defined routes and that Flutter handles route changes.
 */

const FLUTTER_LOAD_TIMEOUT = 20_000;

async function waitForFlutterReady(page: Page) {
  await page.waitForFunction(
    () => !!(document.querySelector('flt-glass-pane') || document.querySelector('flutter-view')),
    { timeout: FLUTTER_LOAD_TIMEOUT }
  );
  await page.waitForTimeout(2000);
}

// All routes defined in the Flutter app's router
const ALL_ROUTES = [
  { path: '/',       name: 'Landing',       needsExtra: false },
  { path: '/login',  name: 'Login',         needsExtra: false },
  { path: '/signup', name: 'Sign Up',       needsExtra: false },
  { path: '/verify', name: 'Verification',  needsExtra: false },
  { path: '/menu',   name: 'Menu',          needsExtra: true },
  { path: '/bag',    name: 'Order Bag',     needsExtra: true },
  { path: '/payment',name: 'Payment',       needsExtra: true },
  { path: '/track',  name: 'Order Tracking',needsExtra: true },
  { path: '/bill',   name: 'Live Bill',     needsExtra: true },
];

test.describe('Navigation — Route Loading', () => {
  for (const route of ALL_ROUTES) {
    test(`Route ${route.path} (${route.name}) loads without crash`, async ({ page }) => {
      // Navigate using hash routing
      const response = await page.goto(`/#${route.path}`);

      // HTTP response should be 200 (static server returns the index.html)
      expect(response?.status()).toBe(200);

      // Wait for Flutter to initialize
      await waitForFlutterReady(page);

      // Verify Flutter rendered
      const rendered = await page.evaluate(() => {
        return !!(document.querySelector('flt-glass-pane') || document.querySelector('flutter-view'));
      });
      expect(rendered).toBe(true);
    });
  }
});

test.describe('Navigation — QR Parameters', () => {
  test('Landing page accepts QR query parameters', async ({ page }) => {
    // Simulate a QR scan with vendor and table IDs
    await page.goto('/?v=test-vendor-123&t=table-5#/');
    await waitForFlutterReady(page);

    // Flutter should have parsed the query parameters
    const rendered = await page.evaluate(() => {
      return !!(document.querySelector('flt-glass-pane') || document.querySelector('flutter-view'));
    });
    expect(rendered).toBe(true);
  });
});

test.describe('Navigation — Sequential Route Changes', () => {
  test('can navigate between multiple routes', async ({ page }) => {
    // Start at landing
    await page.goto('/#/');
    await waitForFlutterReady(page);

    // Go to login
    await page.goto('/#/login');
    await page.waitForTimeout(1500);
    expect(page.url()).toContain('#/login');

    // Go to signup
    await page.goto('/#/signup');
    await page.waitForTimeout(1500);
    expect(page.url()).toContain('#/signup');

    // Go back to landing
    await page.goto('/#/');
    await page.waitForTimeout(1500);
    // URL should contain the base or #/
    const url = page.url();
    expect(url.includes('#/') || url.endsWith('/')).toBe(true);
  });
});
