import { Page, expect } from '@playwright/test';
import type { FieldDef } from '../src/lib/vault';

export const ADMIN_USERNAME = 'xcred_admin';
export const ADMIN_EMAIL = 'admin@xcred.test';
export const LOGIN_PASSWORD = 'LoginPassword#2026';
export const MASTER_PASSWORD = 'Admin@#1234%^&*()';

export async function login(page: Page) {
  await page.goto('/login');
  await page.locator('input[name="username"]').fill(ADMIN_USERNAME);
  await page.locator('input[name="password"]').fill(LOGIN_PASSWORD);
  await page.locator('input[name="masterPassword"]').fill(MASTER_PASSWORD);
  await page.getByRole('button', { name: 'Sign In' }).click();
  await expect(page).toHaveURL(/\/dashboard/, { timeout: 15_000 });
}

/** Idempotent: registers the fixed test admin account only if it doesn't already exist. */
export async function ensureAccountExists(page: Page) {
  await page.goto('/login');
  await page.locator('input[name="username"]').fill(ADMIN_USERNAME);
  await page.locator('input[name="password"]').fill(LOGIN_PASSWORD);
  await page.locator('input[name="masterPassword"]').fill(MASTER_PASSWORD);
  await page.getByRole('button', { name: 'Sign In' }).click();

  const loggedIn = await page.waitForURL(/\/dashboard/, { timeout: 8_000 }).then(() => true).catch(() => false);
  if (loggedIn) return;

  await page.goto('/register');
  await page.locator('input[name="username"]').fill(ADMIN_USERNAME);
  await page.locator('input[name="email"]').fill(ADMIN_EMAIL);
  await page.locator('input[name="password"]').fill(LOGIN_PASSWORD);
  await page.locator('input[name="confirmPassword"]').fill(LOGIN_PASSWORD);
  await page.locator('input[name="masterPassword"]').fill(MASTER_PASSWORD);
  await page.locator('input[name="confirmMasterPassword"]').fill(MASTER_PASSWORD);
  await page.locator('input[name="acknowledgeNoRecovery"]').check();
  await page.getByRole('button', { name: 'Create Account' }).click();
  await expect(page).toHaveURL(/\/login/, { timeout: 15_000 });
}

// The decrypted private key lives only in memory (never persisted, by design — see
// docs/requirements.md §3.5). A full page navigation (page.goto) reloads the SPA and wipes it,
// bouncing back to /login. So all in-app navigation after login must go through real
// clicks on the persistent sidebar (React Router client-side transitions), never page.goto.
export async function goToCredentials(page: Page) {
  await page.getByRole('link', { name: 'Credentials', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Credentials', exact: true })).toBeVisible();
}

export async function goToNewCredentialForm(page: Page) {
  await goToCredentials(page);
  // exact:true — the page also has a per-group "Add credential to this group" button, whose
  // accessible name contains "Add credential" as a case-insensitive substring and would
  // otherwise ambiguously match too once any credential group exists.
  await page.getByRole('button', { name: 'Add Credential', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Add Credential' })).toBeVisible();
}

export function fieldLocator(page: Page, key: string) {
  return page.locator(`[data-field="${key}"]`);
}

export function fieldInput(page: Page, key: string) {
  return fieldLocator(page, key).locator('input, textarea, select');
}

export function sampleValueFor(field: FieldDef, seed: string): string {
  switch (field.type) {
    case 'url': return `https://example.com/${seed}`;
    case 'select': return field.options?.[0] ?? '';
    case 'textarea': return `Sample content for ${field.label} ${seed}`;
    case 'password': return `S3cret!${seed}Aa`;
    default: return `${field.label}-${seed}`;
  }
}

/** Fills every non-list type-specific field on the (already-open) credential form with sample data. */
export async function fillTypeFields(page: Page, fields: FieldDef[], seed: string) {
  const values: Record<string, string> = {};
  for (const field of fields) {
    if (field.type === 'list') continue;
    const value = sampleValueFor(field, seed);
    const input = fieldInput(page, field.key);
    if (field.type === 'select') {
      await input.selectOption(value);
    } else {
      await input.fill(value);
    }
    values[field.key] = value;
  }
  return values;
}
