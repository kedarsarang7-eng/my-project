# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: e2e\navigation.spec.ts >> Navigation — Sequential Route Changes >> can navigate between multiple routes
- Location: tests\e2e\navigation.spec.ts:67:7

# Error details

```
Test timeout of 30000ms exceeded.
```

```
Error: page.waitForFunction: Test timeout of 30000ms exceeded.
```

# Test source

```ts
  1  | import { test, expect, type Page } from '@playwright/test';
  2  | 
  3  | /**
  4  |  * Navigation Tests — verify that hash-based routing works correctly
  5  |  * for all defined routes and that Flutter handles route changes.
  6  |  */
  7  | 
  8  | const FLUTTER_LOAD_TIMEOUT = 20_000;
  9  | 
  10 | async function waitForFlutterReady(page: Page) {
> 11 |   await page.waitForFunction(
     |              ^ Error: page.waitForFunction: Test timeout of 30000ms exceeded.
  12 |     () => !!(document.querySelector('flt-glass-pane') || document.querySelector('flutter-view')),
  13 |     { timeout: FLUTTER_LOAD_TIMEOUT }
  14 |   );
  15 |   await page.waitForTimeout(2000);
  16 | }
  17 | 
  18 | // All routes defined in the Flutter app's router
  19 | const ALL_ROUTES = [
  20 |   { path: '/',       name: 'Landing',       needsExtra: false },
  21 |   { path: '/login',  name: 'Login',         needsExtra: false },
  22 |   { path: '/signup', name: 'Sign Up',       needsExtra: false },
  23 |   { path: '/verify', name: 'Verification',  needsExtra: false },
  24 |   { path: '/menu',   name: 'Menu',          needsExtra: true },
  25 |   { path: '/bag',    name: 'Order Bag',     needsExtra: true },
  26 |   { path: '/payment',name: 'Payment',       needsExtra: true },
  27 |   { path: '/track',  name: 'Order Tracking',needsExtra: true },
  28 |   { path: '/bill',   name: 'Live Bill',     needsExtra: true },
  29 | ];
  30 | 
  31 | test.describe('Navigation — Route Loading', () => {
  32 |   for (const route of ALL_ROUTES) {
  33 |     test(`Route ${route.path} (${route.name}) loads without crash`, async ({ page }) => {
  34 |       // Navigate using hash routing
  35 |       const response = await page.goto(`/#${route.path}`);
  36 | 
  37 |       // HTTP response should be 200 (static server returns the index.html)
  38 |       expect(response?.status()).toBe(200);
  39 | 
  40 |       // Wait for Flutter to initialize
  41 |       await waitForFlutterReady(page);
  42 | 
  43 |       // Verify Flutter rendered
  44 |       const rendered = await page.evaluate(() => {
  45 |         return !!(document.querySelector('flt-glass-pane') || document.querySelector('flutter-view'));
  46 |       });
  47 |       expect(rendered).toBe(true);
  48 |     });
  49 |   }
  50 | });
  51 | 
  52 | test.describe('Navigation — QR Parameters', () => {
  53 |   test('Landing page accepts QR query parameters', async ({ page }) => {
  54 |     // Simulate a QR scan with vendor and table IDs
  55 |     await page.goto('/?v=test-vendor-123&t=table-5#/');
  56 |     await waitForFlutterReady(page);
  57 | 
  58 |     // Flutter should have parsed the query parameters
  59 |     const rendered = await page.evaluate(() => {
  60 |       return !!(document.querySelector('flt-glass-pane') || document.querySelector('flutter-view'));
  61 |     });
  62 |     expect(rendered).toBe(true);
  63 |   });
  64 | });
  65 | 
  66 | test.describe('Navigation — Sequential Route Changes', () => {
  67 |   test('can navigate between multiple routes', async ({ page }) => {
  68 |     // Start at landing
  69 |     await page.goto('/#/');
  70 |     await waitForFlutterReady(page);
  71 | 
  72 |     // Go to login
  73 |     await page.goto('/#/login');
  74 |     await page.waitForTimeout(1500);
  75 |     expect(page.url()).toContain('#/login');
  76 | 
  77 |     // Go to signup
  78 |     await page.goto('/#/signup');
  79 |     await page.waitForTimeout(1500);
  80 |     expect(page.url()).toContain('#/signup');
  81 | 
  82 |     // Go back to landing
  83 |     await page.goto('/#/');
  84 |     await page.waitForTimeout(1500);
  85 |     // URL should contain the base or #/
  86 |     const url = page.url();
  87 |     expect(url.includes('#/') || url.endsWith('/')).toBe(true);
  88 |   });
  89 | });
  90 | 
```