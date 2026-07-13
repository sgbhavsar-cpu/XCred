import { test, expect } from '@playwright/test';
import { login, fillTypeFields } from './helpers';
import { CREDENTIAL_FIELDS } from '../src/lib/vault';

test.describe('Folders and Tags — tree view with inline credential expansion', () => {
  test.beforeEach(async ({ page }) => { await login(page); });

  test('adding a credential from a folder row returns to the Folders page, and the credential appears expanded under it', async ({ page }) => {
    const seed = Date.now();
    const folderName = `E2E Folder ${seed}`;
    const credName = `E2E Folder Cred ${seed}`;

    await page.getByRole('link', { name: 'Folders', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Folders', exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'New Folder' }).click();
    await page.getByPlaceholder('Folder name').fill(folderName);
    await page.getByRole('button', { name: 'Create', exact: true }).click();
    await expect(page.getByText(folderName)).toBeVisible();

    const folderRow = page.locator('div.cursor-pointer', { hasText: folderName });
    await folderRow.getByTitle('Add credential to this folder').click();

    // Regression check: must land on the credential form, pre-selecting this folder — not a blank one
    await expect(page.getByRole('heading', { name: 'Add Credential' })).toBeVisible();
    await expect(page.locator('[data-field="folderId"] select')).toHaveValue(/.+/);

    await page.locator('button[data-type="SecureNote"]').click();
    await page.locator('[data-field="name"] input').fill(credName);
    await fillTypeFields(page, CREDENTIAL_FIELDS.SecureNote, `${seed}`);
    await page.getByRole('button', { name: 'Save Credential' }).click();

    // The bug being fixed: this must return to /folders, not /credentials
    await expect(page).toHaveURL(/\/folders$/, { timeout: 10_000 });

    const refreshedFolderRow = page.locator('div.cursor-pointer', { hasText: folderName }).filter({ hasText: '1 credential' });
    await refreshedFolderRow.click();
    await expect(page.getByText(credName)).toBeVisible();
  });

  test('adding a credential from a tag row returns to the Tags page, and the credential appears expanded under it', async ({ page }) => {
    const seed = Date.now();
    const tagName = `E2ETag${seed}`;
    const credName = `E2E Tag Cred ${seed}`;

    await page.getByRole('link', { name: 'Tags', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Tags', exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'New Tag' }).click();
    await page.getByPlaceholder('Tag name…').fill(tagName);
    await page.getByTitle('Create tag').click();

    // The tag name legitimately renders twice (label + colored pill preview) — .first() is enough.
    await expect(page.getByText(tagName, { exact: true }).first()).toBeVisible();

    const tagRow = page.locator('div.cursor-pointer', { hasText: tagName });
    await tagRow.getByTitle('Add credential with this tag').click();

    await expect(page.getByRole('heading', { name: 'Add Credential' })).toBeVisible();

    await page.locator('button[data-type="SecureNote"]').click();
    await page.locator('[data-field="name"] input').fill(credName);
    await fillTypeFields(page, CREDENTIAL_FIELDS.SecureNote, `${seed}`);
    await page.getByRole('button', { name: 'Save Credential' }).click();

    // The bug being fixed: this must return to /tags, not /credentials
    await expect(page).toHaveURL(/\/tags$/, { timeout: 10_000 });

    const refreshedTagRow = page.locator('div.cursor-pointer', { hasText: tagName }).filter({ hasText: '1 credential' });
    await refreshedTagRow.click();
    await expect(page.getByText(credName)).toBeVisible();
  });
});
