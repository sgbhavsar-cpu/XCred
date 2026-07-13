import { chromium, FullConfig } from '@playwright/test';
import { ensureAccountExists } from './helpers';

// Runs once before the whole suite: guarantees the fixed test admin account exists
// (registers it — becoming the auto-approved first-user admin on a fresh DB — or
// confirms it already logs in, so re-running the suite against a warm container is safe).
export default async function globalSetup(config: FullConfig) {
  const baseURL = config.projects[0].use.baseURL as string;
  const browser = await chromium.launch();
  const page = await browser.newPage({ baseURL });
  try {
    await ensureAccountExists(page);
  } finally {
    await browser.close();
  }
}
