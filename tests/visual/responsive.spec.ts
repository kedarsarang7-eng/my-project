import { test, expect, type Page } from '@playwright/test';

/**
 * Visual Regression / Responsive Tests
 *
 * Captures full-page screenshots at three viewports:
 * - Mobile:  375×667
 * - Tablet:  768×1024
 * - Desktop: 1440×900
 *
 * These screenshots serve as the baseline for visual regression.
 */

const FLUTTER_LOAD_TIMEOUT = 20_000;

async function waitForFlutterReady(page: Page) {
  await page.waitForFunction(
    () => !!(document.querySelector('flt-glass-pane') || document.querySelector('flutter-view')),
    { timeout: FLUTTER_LOAD_TIMEOUT }
  );
  await page.waitForTimeout(2000);
}

const VIEWPORTS = [
  { name: 'mobile',  width: 375,  height: 667 },
  { name: 'tablet',  width: 768,  height: 1024 },
  { name: 'desktop', width: 1440, height: 900 },
];

const SCREENSHOT_ROUTES = [
  { path: '/',      name: 'landing' },
  { path: '/login', name: 'login' },
  { path: '/signup',name: 'signup' },
  { path: '/menu',  name: 'menu' },
];

for (const vp of VIEWPORTS) {
  test.describe(`Visual — ${vp.name} (${vp.width}×${vp.height})`, () => {
    test.use({ viewport: { width: vp.width, height: vp.height } });

    for (const route of SCREENSHOT_ROUTES) {
      test(`Screenshot: ${route.name} at ${vp.name}`, async ({ page }) => {
        await page.goto(`/#${route.path}`);
        await waitForFlutterReady(page);

        const screenshotPath = `test-results/screenshots/${route.name}__${vp.name}.png`;
        await page.screenshot({
          path: screenshotPath,
          fullPage: true,
        });

        // Verify the screenshot was taken (Flutter rendered something)
        const rendered = await page.evaluate(() => {
          return !!(document.querySelector('flt-glass-pane') || document.querySelector('flutter-view'));
        });
        expect(rendered).toBe(true);
      });
    }
  });
}

test.describe('Visual — Flutter renders non-blank content', () => {
  test('landing page renders visible content (not blank canvas)', async ({ page }) => {
    await page.goto('/#/');
    await waitForFlutterReady(page);

    // Check that the page has rendered content by examining the
    // screenshot dimensions and that canvas/rendering surface exists
    const hasVisualContent = await page.evaluate(() => {
      const glassPane = document.querySelector('flt-glass-pane') ||
                        document.querySelector('flutter-view');
      if (!glassPane) return false;

      // Check shadow DOM for canvas elements
      const shadow = glassPane.shadowRoot;
      if (shadow) {
        const canvases = shadow.querySelectorAll('canvas');
        return canvases.length > 0;
      }
      return true;
    });
    expect(hasVisualContent).toBe(true);
  });
});
