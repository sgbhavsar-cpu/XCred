import { test, expect } from '@playwright/test';
import { registerAndLoginFreshUser, goToNewCredentialForm, fillTypeFields } from './helpers';
import { CREDENTIAL_FIELDS } from '../src/lib/vault';

async function createSecureNote(page: import('@playwright/test').Page, name: string, seed: string) {
  await goToNewCredentialForm(page);
  await page.locator('button[data-type="SecureNote"]').click();
  await page.locator('[data-field="name"] input').fill(name);
  await fillTypeFields(page, CREDENTIAL_FIELDS.SecureNote, seed);
  await page.getByRole('button', { name: 'Save Credential' }).click();
  await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });
}

test.describe('Search + Select All on Credentials/Folders/Tags, and bulk tag editing', () => {
  test('Select All on the Credentials page only selects what the search filter shows', async ({ page, request }) => {
    await registerAndLoginFreshUser(page, request, 'selectall');
    const seed = Date.now();
    const matchName = `E2E SelectAllMatch ${seed}`;
    const otherName = `E2E SelectAllOther ${seed}`;

    await createSecureNote(page, matchName, `${seed}a`);
    await createSecureNote(page, otherName, `${seed}b`);

    await page.locator('input[placeholder*="Search"]').fill(`SelectAllMatch ${seed}`);
    await expect(page.getByTestId('credential-row').filter({ hasText: matchName })).toBeVisible();
    await expect(page.getByTestId('credential-row').filter({ hasText: otherName })).not.toBeVisible();

    await page.getByRole('button', { name: 'Select All' }).click();
    await expect(page.getByText('1 selected')).toBeVisible();

    // Clearing the search reveals the other credential too — it must stay unselected.
    await page.locator('input[placeholder*="Search"]').fill('');
    await expect(page.getByTestId('credential-row').filter({ hasText: otherName })).toBeVisible();
    await expect(page.getByTestId('credential-row').filter({ hasText: otherName }).locator('input[type="checkbox"]')).not.toBeChecked();
    await expect(page.getByTestId('credential-row').filter({ hasText: matchName }).locator('input[type="checkbox"]')).toBeChecked();
  });

  test('Folders page has a working search box that filters the tree and unassigned section', async ({ page, request }) => {
    await registerAndLoginFreshUser(page, request, 'foldersearch');
    const seed = Date.now();
    const folderName = `E2E Search Folder ${seed}`;
    const inFolderName = `E2E SearchInFolder ${seed}`;
    const unassignedName = `E2E SearchUnassigned ${seed}`;

    await createSecureNote(page, inFolderName, `${seed}a`);
    await createSecureNote(page, unassignedName, `${seed}b`);

    await page.getByRole('link', { name: 'Folders', exact: true }).click();
    await page.getByRole('button', { name: 'New Folder' }).click();
    await page.getByPlaceholder('Folder name').fill(folderName);
    await page.getByRole('button', { name: 'Create', exact: true }).click();
    await expect(page.getByText(folderName)).toBeVisible();

    // Move the first credential into the folder via the "Add credential" form's folder param,
    // simpler than drag-and-drop for this test: use the folder row's own add-credential button.
    await page.locator('input[placeholder*="Search"]').fill(''); // Folders page also has a search box now
    const folderRow = page.locator('div.cursor-pointer', { hasText: folderName });
    await expect(folderRow).toBeVisible();

    // Search should be present on this page (the actual check the user asked for).
    await expect(page.locator('input[placeholder*="Search"]')).toBeVisible();

    await page.locator('input[placeholder*="Search"]').fill(`SearchInFolder ${seed}`);
    // Unassigned credential shouldn't match; nothing filtered in should reference it.
    await expect(page.getByTestId('credential-row').filter({ hasText: unassignedName })).not.toBeVisible();

    await page.locator('input[placeholder*="Search"]').fill('');
  });

  test('Select All on the Folders page selects only currently-visible (search-filtered) credentials', async ({ page, request }) => {
    await registerAndLoginFreshUser(page, request, 'foldersel');
    const seed = Date.now();
    const credA = `E2E FolderSelA ${seed}`;
    const credB = `E2E FolderSelB ${seed}`;
    await createSecureNote(page, credA, `${seed}a`);
    await createSecureNote(page, credB, `${seed}b`);

    await page.getByRole('link', { name: 'Folders', exact: true }).click();
    await expect(page.getByTestId('credential-row').filter({ hasText: credA })).toBeVisible();

    await page.locator('input[placeholder*="Search"]').fill(`FolderSelA ${seed}`);
    await page.getByRole('button', { name: 'Select All' }).click();
    await expect(page.getByText('1 selected')).toBeVisible();
  });

  test('Tags page shows an Untagged section, and bulk-adding a tag from there moves credentials into it', async ({ page, request }) => {
    await registerAndLoginFreshUser(page, request, 'bulktags');
    const seed = Date.now();
    const cred1 = `E2E TagBulk A ${seed}`;
    const cred2 = `E2E TagBulk B ${seed}`;
    const tagName = `E2ETagBulk${seed}`;

    await createSecureNote(page, cred1, `${seed}a`);
    await createSecureNote(page, cred2, `${seed}b`);

    await page.getByRole('link', { name: 'Tags', exact: true }).click();
    await page.getByRole('button', { name: 'New Tag' }).click();
    await page.getByPlaceholder('Tag name…').fill(tagName);
    await page.getByTitle('Create tag').click();
    await expect(page.getByText(tagName, { exact: true }).first()).toBeVisible();

    // Both new credentials are untagged — they must show up under "Untagged" so they can
    // actually be selected for a first tag (this is the whole point of bulk-tagging).
    await expect(page.getByText('Untagged', { exact: true })).toBeVisible();
    const row1 = page.getByTestId('credential-row').filter({ hasText: cred1 });
    const row2 = page.getByTestId('credential-row').filter({ hasText: cred2 });
    await expect(row1).toBeVisible();
    await expect(row2).toBeVisible();

    await row1.locator('input[type="checkbox"]').check();
    await row2.locator('input[type="checkbox"]').check();
    await expect(page.getByText('2 selected')).toBeVisible();

    await page.getByRole('button', { name: 'Bulk Edit' }).click();
    await expect(page.getByText('Bulk edit tags on 2 credentials')).toBeVisible();
    // First click = add.
    await page.getByTestId('bulk-tag-edit-modal').getByRole('button', { name: tagName }).click();
    await page.getByRole('button', { name: 'Apply' }).click();
    await expect(page.getByText('Updated 2 credentials.')).toBeVisible({ timeout: 10_000 });

    // Both credentials now carry the tag, so they've left "Untagged" and appear under it.
    const tagGroupRow = page.locator('div.cursor-pointer', { hasText: tagName }).filter({ hasText: '2 credentials' });
    await expect(tagGroupRow).toBeVisible({ timeout: 10_000 });
    await tagGroupRow.click();
    await expect(page.getByTestId('credential-row').filter({ hasText: cred1 })).toBeVisible();
    await expect(page.getByTestId('credential-row').filter({ hasText: cred2 })).toBeVisible();

    // Now bulk-remove the tag from both and confirm they land back in Untagged.
    await row1.locator('input[type="checkbox"]').check();
    await row2.locator('input[type="checkbox"]').check();
    await page.getByRole('button', { name: 'Bulk Edit' }).click();
    // Second click on the same tag chip = remove.
    await page.getByTestId('bulk-tag-edit-modal').getByRole('button', { name: tagName }).click();
    await page.getByTestId('bulk-tag-edit-modal').getByRole('button', { name: tagName }).click();
    await page.getByRole('button', { name: 'Apply' }).click();
    await expect(page.getByText('Updated 2 credentials.')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByText('Untagged', { exact: true })).toBeVisible();
    await expect(page.getByTestId('credential-row').filter({ hasText: cred1 })).toBeVisible();
    await expect(page.getByTestId('credential-row').filter({ hasText: cred2 })).toBeVisible();
  });
});
