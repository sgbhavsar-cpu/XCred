import { defineConfig, devices } from '@playwright/test';

// Points at the Dockerized API+SPA stack (docker-compose.yml) so the API and SPA share one
// origin — no dev-proxy or CORS involved, matching how the app is actually served in production.
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 30_000,
  globalSetup: './e2e/global-setup.ts',
  reporter: [['html', { open: 'never', outputFolder: 'playwright-report' }], ['list']],
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:18080',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});
