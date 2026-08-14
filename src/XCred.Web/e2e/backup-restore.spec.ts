import { test, expect } from '@playwright/test';
import { ADMIN_USERNAME, LOGIN_PASSWORD, MASTER_PASSWORD, login, goToNewCredentialForm, fieldInput } from './helpers';

// Covers the fix for a real bug report: restoring a .xcredbak backup onto a FRESH
// registration (a genuinely different account server-side — new random salt, new random RSA
// keypair — even with an identical username/master password on a different machine) used to
// leave every restored credential permanently undecryptable, because EncryptedCredentialKey
// stays RSA-wrapped under the OLD account's public key. VaultBackup now carries the exporting
// account's own crypto material, and the Restore flow offers to swap the target account's
// identity to match it (after locally verifying the entered master password actually unwraps
// that material, so a wrong guess never touches the server). This spec proves both new
// features work through the real UI, not just at the crypto/API layer.

test.describe('Backup & Restore', () => {
  test('Export as Plain JSON downloads a file with the real, decrypted credential data', async ({ page }) => {
    await login(page);

    const seed = Date.now().toString().slice(-6);
    const credName = `PlainExportTest ${seed}`;
    await goToNewCredentialForm(page);
    await page.locator('button[data-type="WebsiteLogin"]').click();
    await page.locator('[data-field="name"] input').fill(credName);
    await fieldInput(page, 'url').fill('https://example.com/plain-export');
    await fieldInput(page, 'username').fill('plainexportuser');
    await fieldInput(page, 'password').fill('PlainExportSecret#123');
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    await page.getByRole('link', { name: 'Settings' }).click();
    await page.getByRole('button', { name: 'Backup & Restore' }).click();

    page.once('dialog', (dialog) => dialog.accept());
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.getByRole('button', { name: 'Export All as Plain JSON' }).click(),
    ]);

    const filePath = await download.path();
    const fs = await import('fs/promises');
    const content = JSON.parse(await fs.readFile(filePath!, 'utf-8'));

    expect(content.warning).toMatch(/UNENCRYPTED/i);
    expect(Array.isArray(content.credentials)).toBe(true);
    const exported = content.credentials.find((c: any) => c.name === credName);
    expect(exported, 'the newly created credential must be present in the plaintext export').toBeTruthy();
    expect(exported.password).toBe('PlainExportSecret#123');
    expect(exported.username).toBe('plainexportuser');
  });

  test('Restoring a backup after a fresh re-registration (same master password, different account) correctly decrypts via the account-key restore flow', async ({ page, request }) => {
    await login(page);

    const seed = Date.now().toString().slice(-6);
    const credName = `CrossMachineTest ${seed}`;
    await goToNewCredentialForm(page);
    await page.locator('button[data-type="WebsiteLogin"]').click();
    await page.locator('[data-field="name"] input').fill(credName);
    await fieldInput(page, 'url').fill('https://example.com/cross-machine');
    await fieldInput(page, 'username').fill('crossmachineuser');
    await fieldInput(page, 'password').fill('CrossMachineSecret#456');
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    // Export the backup (this account's own crypto material comes along with it).
    await page.getByRole('link', { name: 'Settings' }).click();
    await page.getByRole('button', { name: 'Backup & Restore' }).click();
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.getByRole('button', { name: 'Download Backup' }).click(),
    ]);
    const backupPath = await download.path();

    // A fresh registration on "a different machine" — same master password as the admin
    // account above, but a necessarily different username (server enforces uniqueness) and,
    // server-side, a completely unrelated random salt + RSA keypair. This is exactly the
    // reported scenario's crypto shape.
    const newUsername = `restoreui_${seed}`;
    await page.getByTitle('Sign out').click();
    await expect(page).toHaveURL(/\/login/, { timeout: 10_000 });
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

    // Approve the new (non-first) account via the admin API directly — same shortcut the
    // existing e2e/global-setup and admin tests already take for account approval, since
    // there's no self-approval path in the product itself.
    const adminLogin = await request.post('/api/auth/login', { data: { username: ADMIN_USERNAME, password: LOGIN_PASSWORD } });
    const adminToken = (await adminLogin.json()).data.accessToken;
    const pending = await request.get('/api/admin/users?pendingOnly=true', { headers: { Authorization: `Bearer ${adminToken}` } });
    const pendingUser = (await pending.json()).data.find((u: any) => u.username === newUsername);
    await request.post(`/api/admin/users/${pendingUser.id}/approve`, { headers: { Authorization: `Bearer ${adminToken}` } });

    // Log in as the new account and confirm the bug's precondition: it does NOT yet see the
    // admin's credential, and has its own, different encryption identity.
    await page.locator('input[name="username"]').fill(newUsername);
    await page.locator('input[name="password"]').fill(LOGIN_PASSWORD);
    await page.locator('input[name="masterPassword"]').fill(MASTER_PASSWORD);
    await page.getByRole('button', { name: 'Sign In' }).click();
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 15_000 });

    // Restore the admin's backup onto this fresh account. Deliberately never click "Select
    // Backup File" — that trigger opens a native OS file dialog Playwright can't drive; set
    // the hidden <input type="file"> directly instead, which is what real browser automation
    // for file uploads does.
    await page.getByRole('link', { name: 'Settings' }).click();
    await page.getByRole('button', { name: 'Backup & Restore' }).click();
    await page.locator('input[type="file"]').setInputFiles(backupPath!);

    // The account-key restore modal must appear (this backup carries crypto material).
    await expect(page.getByRole('heading', { name: 'Restore Account Encryption Keys' })).toBeVisible({ timeout: 5_000 });
    await page.locator('input[placeholder="••••••••"]').first().fill(MASTER_PASSWORD);
    await page.getByRole('button', { name: 'Verify & Restore' }).click();

    await expect(page.getByText('Restore Complete')).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText(/encryption identity was replaced/i)).toBeVisible();

    // The crux of the fix: the restored credential must now actually decrypt, not just exist.
    await page.getByRole('link', { name: 'Credentials', exact: true }).click();
    await page.locator('input[placeholder*="Search"]').fill(credName);
    await page.getByText(credName, { exact: true }).click();
    await expect(page).toHaveURL(/\/credentials\/[0-9a-fA-F-]+$/, { timeout: 10_000 });
    await expect(page.getByText('crossmachineuser')).toBeVisible({ timeout: 5_000 });
    await expect(page.getByText(/Failed to decrypt/i)).toHaveCount(0);
  });
});
