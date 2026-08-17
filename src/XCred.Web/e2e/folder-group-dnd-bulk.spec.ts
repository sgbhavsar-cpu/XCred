import { test, expect } from '@playwright/test';
import { registerAndLoginFreshUser, dragCredentialOnto, goToNewCredentialForm, fillTypeFields } from './helpers';
import { CREDENTIAL_FIELDS } from '../src/lib/vault';

async function createSecureNote(page: import('@playwright/test').Page, name: string, seed: string) {
  await goToNewCredentialForm(page);
  await page.locator('button[data-type="SecureNote"]').click();
  await page.locator('[data-field="name"] input').fill(name);
  await fillTypeFields(page, CREDENTIAL_FIELDS.SecureNote, seed);
  await page.getByRole('button', { name: 'Save Credential' }).click();
  await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });
}

test.describe('Folder/group drag-and-drop and multi-select bulk edit', () => {
  test('Folders page shows an Unassigned section, and dragging a credential onto a folder moves it', async ({ page, request }) => {
    await registerAndLoginFreshUser(page, request, 'dndfolder');
    const seed = Date.now();
    const folderName = `E2E DnD Folder ${seed}`;
    const credName = `E2E DnD Cred ${seed}`;

    await createSecureNote(page, credName, `${seed}`);

    await page.getByRole('link', { name: 'Folders', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Folders', exact: true })).toBeVisible();
    await page.getByRole('button', { name: 'New Folder' }).click();
    await page.getByPlaceholder('Folder name').fill(folderName);
    await page.getByRole('button', { name: 'Create', exact: true }).click();
    await expect(page.getByText(folderName)).toBeVisible();

    // The credential starts unassigned — confirm the new "Unassigned" section actually shows it.
    await expect(page.getByText('Unassigned', { exact: true })).toBeVisible();
    await expect(page.getByTestId('credential-row').filter({ hasText: credName })).toBeVisible();

    const folderRow = page.locator('div.cursor-pointer', { hasText: folderName });
    await dragCredentialOnto(page, credName, folderRow);
    await expect(page.getByText('Moved to folder.')).toBeVisible({ timeout: 10_000 });

    // Expand the folder and confirm the credential actually landed inside it.
    const refreshedFolderRow = page.locator('div.cursor-pointer', { hasText: folderName }).filter({ hasText: '1 credential' });
    await expect(refreshedFolderRow).toBeVisible({ timeout: 10_000 });
    await refreshedFolderRow.click();
    await expect(page.getByTestId('credential-row').filter({ hasText: credName })).toBeVisible();
  });

  test('dragging a credential from Ungrouped onto a credential group moves it into the group', async ({ page, request }) => {
    await registerAndLoginFreshUser(page, request, 'dndgroup');
    const seed = Date.now();
    const groupName = `E2E DnD Group ${seed}`;
    const credName = `E2E DnD GroupCred ${seed}`;

    await createSecureNote(page, credName, `${seed}`);

    await page.getByRole('button', { name: 'New Credential Group' }).click();
    await page.locator('input[placeholder*="HDFC Bank"]').fill(groupName);
    await page.getByRole('button', { name: 'Create', exact: true }).click();
    await expect(page.getByText(groupName)).toBeVisible();

    await expect(page.getByText('Ungrouped', { exact: true })).toBeVisible();
    await expect(page.getByTestId('credential-row').filter({ hasText: credName })).toBeVisible();

    const groupRow = page.locator('div.cursor-pointer', { hasText: groupName });
    await dragCredentialOnto(page, credName, groupRow);
    await expect(page.getByText('Moved to credential group.')).toBeVisible({ timeout: 10_000 });

    const refreshedGroupRow = page.locator('div.cursor-pointer', { hasText: groupName }).filter({ hasText: '1 credential' });
    await expect(refreshedGroupRow).toBeVisible({ timeout: 10_000 });
    await refreshedGroupRow.click();
    await expect(page.getByTestId('credential-row').filter({ hasText: credName })).toBeVisible();
  });

  test('multi-select two credentials and bulk-assign folder + credential group in one action', async ({ page, request }) => {
    test.setTimeout(60_000); // 2 credential creates + folder + group + 2 page round-trips to verify
    await registerAndLoginFreshUser(page, request, 'bulkedit');
    const seed = Date.now();
    const folderName = `E2E Bulk Folder ${seed}`;
    const groupName = `E2E Bulk Group ${seed}`;
    const cred1 = `E2E Bulk Cred A ${seed}`;
    const cred2 = `E2E Bulk Cred B ${seed}`;

    await createSecureNote(page, cred1, `${seed}a`);
    await createSecureNote(page, cred2, `${seed}b`);

    // Set up the target folder and group first.
    await page.getByRole('link', { name: 'Folders', exact: true }).click();
    await page.getByRole('button', { name: 'New Folder' }).click();
    await page.getByPlaceholder('Folder name').fill(folderName);
    await page.getByRole('button', { name: 'Create', exact: true }).click();
    await expect(page.getByText(folderName)).toBeVisible();

    await page.getByRole('link', { name: 'Credentials', exact: true }).click();
    await page.getByRole('button', { name: 'New Credential Group' }).click();
    await page.locator('input[placeholder*="HDFC Bank"]').fill(groupName);
    await page.getByRole('button', { name: 'Create', exact: true }).click();
    await expect(page.getByText(groupName)).toBeVisible();

    // Select both credentials (both currently ungrouped) via their row checkboxes.
    const row1 = page.getByTestId('credential-row').filter({ hasText: cred1 });
    const row2 = page.getByTestId('credential-row').filter({ hasText: cred2 });
    await row1.locator('input[type="checkbox"]').check();
    await row2.locator('input[type="checkbox"]').check();
    await expect(page.getByText('2 selected')).toBeVisible();

    await page.getByRole('button', { name: 'Bulk Edit' }).click();
    await expect(page.getByText('Bulk edit 2 credentials')).toBeVisible();
    const modalSelects = page.getByTestId('bulk-edit-modal').getByRole('combobox');
    await modalSelects.nth(0).selectOption({ label: folderName }); // Folder selector
    await modalSelects.nth(1).selectOption({ label: groupName }); // Credential Group selector
    await page.getByRole('button', { name: 'Apply' }).click();
    await expect(page.getByText('Updated 2 credentials.')).toBeVisible({ timeout: 10_000 });

    // Verify both credentials now show up under the target group (Credentials page), and
    // independently under the target folder (Folders page) — proving both fields were set.
    const refreshedGroupRow = page.locator('div.cursor-pointer', { hasText: groupName }).filter({ hasText: '2 credentials' });
    await expect(refreshedGroupRow).toBeVisible({ timeout: 10_000 });
    await refreshedGroupRow.click();
    await expect(page.getByTestId('credential-row').filter({ hasText: cred1 })).toBeVisible();
    await expect(page.getByTestId('credential-row').filter({ hasText: cred2 })).toBeVisible();

    await page.getByRole('link', { name: 'Folders', exact: true }).click();
    const refreshedFolderRow = page.locator('div.cursor-pointer', { hasText: folderName }).filter({ hasText: '2 credentials' });
    await expect(refreshedFolderRow).toBeVisible({ timeout: 10_000 });
    await refreshedFolderRow.click();
    await expect(page.getByTestId('credential-row').filter({ hasText: cred1 })).toBeVisible();
    await expect(page.getByTestId('credential-row').filter({ hasText: cred2 })).toBeVisible();
  });
});
