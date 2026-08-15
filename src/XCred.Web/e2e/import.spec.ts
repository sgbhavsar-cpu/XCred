import { test, expect } from '@playwright/test';
import { ADMIN_USERNAME, LOGIN_PASSWORD, MASTER_PASSWORD, login, goToNewCredentialForm, fieldInput } from './helpers';

test.describe('Import', () => {
  test('CSV import maps columns, previews, and creates real decryptable credentials', async ({ page }) => {
    await login(page);

    const seed = Date.now().toString().slice(-6);
    const csvName = `CsvImportTest ${seed}`;
    const csv =
      'Name,URL,Username,Password,Notes\n' +
      `${csvName},https://example.com/csv,csvuser,CsvSecret#789,imported via csv\n`;

    await page.getByRole('link', { name: 'Settings' }).click();
    await page.getByRole('button', { name: 'Import', exact: true }).click();
    await page.locator('input[accept*="csv"]').setInputFiles({
      name: 'test-import.csv',
      mimeType: 'text/csv',
      buffer: Buffer.from(csv),
    });

    // .last() — the tab's own card heading ("Import from CSV") and the modal's heading
    // (same text) are both mounted simultaneously; the modal's is added later in the DOM.
    await expect(page.getByRole('heading', { name: 'Import from CSV' }).last()).toBeVisible({ timeout: 5_000 });
    // Standard header names auto-map — confirm the preview actually shows the real row
    // before committing to anything.
    await expect(page.getByText(csvName)).toBeVisible();
    await expect(page.getByText('••••••••')).toBeVisible();

    await page.getByRole('button', { name: /Import 1 row/ }).click();
    // exact:true — the success toast's text ("CSV import complete — check…") is a
    // case-insensitive substring match for "Import Complete" too, by Playwright's default.
    await expect(page.getByText('Import Complete', { exact: true })).toBeVisible({ timeout: 15_000 });
    await expect(page.locator('text=/Created:\\s*1/')).toBeVisible();
    await page.getByRole('button', { name: 'Done' }).click();

    await page.getByRole('link', { name: 'Credentials', exact: true }).click();
    await page.locator('input[placeholder*="Search"]').fill(csvName);
    await page.getByText(csvName, { exact: true }).click();
    await expect(page).toHaveURL(/\/credentials\/[0-9a-fA-F-]+$/, { timeout: 10_000 });
    await expect(page.getByText('csvuser')).toBeVisible({ timeout: 5_000 });
    await expect(page.getByText('imported via csv')).toBeVisible();
  });

  test('Plain JSON re-import decrypts and recreates a credential from this app\'s own plaintext export', async ({ page, request }) => {
    // A fresh throwaway account rather than the shared admin one — export/import both walk
    // EVERY credential in the vault sequentially (each its own RSA-OAEP + AES-GCM operation,
    // plus a network round-trip for import), and the admin account accumulates more
    // credentials every time this whole e2e suite (or any manual/agent session) runs. An
    // isolated account keeps this test's runtime tied to what IT creates, not the project's
    // entire test history.
    const seed = Date.now().toString().slice(-6);
    const newUsername = `jsonimport_${seed}`;
    await page.goto('/register');
    await page.locator('input[name="username"]').fill(newUsername);
    await page.locator('input[name="email"]').fill(`${newUsername}@example.com`);
    await page.locator('input[name="password"]').fill(LOGIN_PASSWORD);
    await page.locator('input[name="confirmPassword"]').fill(LOGIN_PASSWORD);
    await page.locator('input[name="masterPassword"]').fill(MASTER_PASSWORD);
    await page.locator('input[name="confirmMasterPassword"]').fill(MASTER_PASSWORD);
    await page.locator('input[name="acknowledgeNoRecovery"]').check();
    await page.getByRole('button', { name: 'Create Account' }).click();
    await expect(page).toHaveURL(/\/login/, { timeout: 15_000 });

    const adminLogin = await request.post('/api/auth/login', { data: { username: ADMIN_USERNAME, password: LOGIN_PASSWORD } });
    const adminToken = (await adminLogin.json()).data.accessToken;
    const pending = await request.get('/api/admin/users?pendingOnly=true', { headers: { Authorization: `Bearer ${adminToken}` } });
    const pendingUser = (await pending.json()).data.find((u: any) => u.username === newUsername);
    await request.post(`/api/admin/users/${pendingUser.id}/approve`, { headers: { Authorization: `Bearer ${adminToken}` } });

    await page.locator('input[name="username"]').fill(newUsername);
    await page.locator('input[name="password"]').fill(LOGIN_PASSWORD);
    await page.locator('input[name="masterPassword"]').fill(MASTER_PASSWORD);
    await page.getByRole('button', { name: 'Sign In' }).click();
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 15_000 });

    const credName = `JsonReimportTest ${seed}`;
    await goToNewCredentialForm(page);
    await page.locator('button[data-type="WebsiteLogin"]').click();
    await page.locator('[data-field="name"] input').fill(credName);
    await fieldInput(page, 'url').fill('https://example.com/json-reimport');
    await fieldInput(page, 'username').fill('jsonreimportuser');
    await fieldInput(page, 'password').fill('JsonReimportSecret#321');
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    await page.getByRole('link', { name: 'Settings' }).click();
    await page.getByRole('button', { name: 'Backup & Restore' }).click();
    page.once('dialog', (dialog) => dialog.accept());
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.getByRole('button', { name: 'Export All as Plain JSON' }).click(),
    ]);
    const plainJsonPath = await download.path();

    await page.getByRole('button', { name: 'Import', exact: true }).click();
    page.once('dialog', (dialog) => dialog.accept());
    await page.locator('input[accept=".json"]').setInputFiles(plainJsonPath!);

    await expect(page.getByText('Import Complete')).toBeVisible({ timeout: 15_000 });
    await expect(page.locator('text=/Created:\\s*[1-9]/')).toBeVisible();

    await page.getByRole('link', { name: 'Credentials', exact: true }).click();
    await page.locator('input[placeholder*="Search"]').fill(credName);
    await page.getByText(credName, { exact: true }).first().click();
    await expect(page).toHaveURL(/\/credentials\/[0-9a-fA-F-]+$/, { timeout: 10_000 });
    await expect(page.getByText('jsonreimportuser')).toBeVisible({ timeout: 5_000 });
  });
});
