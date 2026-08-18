import { test, expect } from '@playwright/test';
import { registerAndLoginFreshUser, goToNewCredentialForm, fillTypeFields } from './helpers';
import { CREDENTIAL_FIELDS } from '../src/lib/vault';

test.describe('Credential row actions — Edit, Duplicate, Copy Password', () => {
  test('Edit button opens the credential directly in edit mode, pre-filled', async ({ page, request }) => {
    await registerAndLoginFreshUser(page, request, 'rowedit');
    const seed = Date.now();
    const name = `E2E RowEdit ${seed}`;

    await goToNewCredentialForm(page);
    await page.locator('button[data-type="WebsiteLogin"]').click();
    await page.locator('[data-field="name"] input').fill(name);
    await page.locator('[data-field="url"] input').fill('https://example.com');
    await page.locator('[data-field="username"] input').fill('rowuser');
    await page.locator('[data-field="password"] input').fill('RowEditPass#1');
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    const row = page.getByTestId('credential-row').filter({ hasText: name });
    await row.getByTitle('Edit').click();
    await expect(page).toHaveURL(/\/credentials\/[0-9a-fA-F-]+\/edit$/, { timeout: 10_000 });
    await expect(page.getByRole('heading', { name: 'Edit Credential' })).toBeVisible();
    await expect(page.locator('[data-field="name"] input')).toHaveValue(name);
    await expect(page.locator('[data-field="username"] input')).toHaveValue('rowuser');
  });

  test('Duplicate button creates a copy named "... (Copy)" and opens it in edit mode', async ({ page, request }) => {
    await registerAndLoginFreshUser(page, request, 'rowdup');
    const seed = Date.now();
    const name = `E2E RowDup ${seed}`;

    await goToNewCredentialForm(page);
    await page.locator('button[data-type="SecureNote"]').click();
    await page.locator('[data-field="name"] input').fill(name);
    await fillTypeFields(page, CREDENTIAL_FIELDS.SecureNote, `${seed}`);
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    const row = page.getByTestId('credential-row').filter({ hasText: name });
    await row.getByTitle('Duplicate').click();
    await expect(page.getByText('Credential duplicated.')).toBeVisible({ timeout: 10_000 });
    await expect(page).toHaveURL(/\/credentials\/[0-9a-fA-F-]+\/edit$/, { timeout: 10_000 });
    await expect(page.locator('[data-field="name"] input')).toHaveValue(`${name} (Copy)`);

    // Original still exists untouched alongside the new duplicate.
    await page.getByRole('button', { name: 'Cancel' }).click();
    await expect(page.getByTestId('credential-row').filter({ hasText: name, hasNotText: '(Copy)' })).toBeVisible();
    await expect(page.getByTestId('credential-row').filter({ hasText: `${name} (Copy)` })).toBeVisible();
  });

  test('Copy Password button copies the password field to the clipboard, and only shows up for types that have one', async ({ page, context, request }) => {
    await context.grantPermissions(['clipboard-read', 'clipboard-write']);
    await registerAndLoginFreshUser(page, request, 'rowcopy');
    const seed = Date.now();
    const loginName = `E2E RowCopyLogin ${seed}`;
    const noteName = `E2E RowCopyNote ${seed}`;
    const password = 'CopyMe#Secret1';

    await goToNewCredentialForm(page);
    await page.locator('button[data-type="WebsiteLogin"]').click();
    await page.locator('[data-field="name"] input').fill(loginName);
    await page.locator('[data-field="url"] input').fill('https://example.com');
    await page.locator('[data-field="username"] input').fill('copyuser');
    await page.locator('[data-field="password"] input').fill(password);
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    await goToNewCredentialForm(page);
    await page.locator('button[data-type="SecureNote"]').click();
    await page.locator('[data-field="name"] input').fill(noteName);
    await fillTypeFields(page, CREDENTIAL_FIELDS.SecureNote, `${seed}`);
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    // WebsiteLogin has a password field — the button shows and copying works.
    const loginRow = page.getByTestId('credential-row').filter({ hasText: loginName });
    await expect(loginRow.getByTitle('Copy password')).toBeVisible();
    await loginRow.getByTitle('Copy password').click();
    await expect(page.getByText('Password copied to clipboard.')).toBeVisible({ timeout: 10_000 });
    const clipboardText = await page.evaluate(() => navigator.clipboard.readText());
    expect(clipboardText).toBe(password);

    // SecureNote has no password-type field at all — the button must not render.
    const noteRow = page.getByTestId('credential-row').filter({ hasText: noteName });
    await expect(noteRow.getByTitle('Copy password')).not.toBeVisible();
  });
});
