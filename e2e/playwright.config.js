// @ts-check
const { defineConfig, devices } = require('@playwright/test');

/**
 * Konfigurasi audit E2E KasirGo.
 *
 * Uji berjalan melawan URL live (default) atau base URL lokal via env:
 *   E2E_BASE_URL=https://ikhlassabar2021-create.github.io/kasirgo/
 *   E2E_ADMIN_URL=https://ikhlassabar2021-create.github.io/kasirgo/admin/
 *
 * Kredensial (opsional, untuk uji login nyata):
 *   E2E_OWNER_EMAIL / E2E_OWNER_PASSWORD
 *   E2E_ADMIN_EMAIL / E2E_ADMIN_PASSWORD
 *
 * Jalankan: npx playwright test --config=e2e/playwright.config.js
 */
module.exports = defineConfig({
  testDir: __dirname,
  timeout: 90_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  retries: 1,
  reporter: [['list']],
  use: {
    baseURL: process.env.E2E_BASE_URL ||
      'https://ikhlassabar2021-create.github.io/kasirgo/',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    viewport: { width: 1280, height: 900 },
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});
