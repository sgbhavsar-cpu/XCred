import { test, expect, type Page } from '@playwright/test';
import { registerAndLoginFreshUser, goToCredentials, goToNewCredentialForm, fillTypeFields } from './helpers';
import { CREDENTIAL_FIELDS } from '../src/lib/vault';

async function createNote(page: Page, name: string) {
  await goToNewCredentialForm(page);
  await page.locator('button[data-type="SecureNote"]').click();
  await page.locator('[data-field="name"] input').fill(name);
  await fillTypeFields(page, CREDENTIAL_FIELDS.SecureNote, name);
  await page.getByRole('button', { name: 'Save Credential' }).click();
  await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });
}

test.describe('General UX: search clear, shared dropdown, quick-create "+", selection mode', () => {
  test('search box has an X that clears it; Escape clears too', async ({ page, request }) => {
    await registerAndLoginFreshUser(page, request, 'uxsearch');
    await goToCredentials(page);
    const box = page.getByPlaceholder(/Search name, IP/);
    await expect(page.getByTitle('Clear search')).toHaveCount(0);
    await box.fill('something');
    await page.getByTitle('Clear search').click();
    await expect(box).toHaveValue('');
    await expect(box).toBeFocused();
    await box.fill('again');
    await box.press('Escape');
    await expect(box).toHaveValue('');
  });

  test('dropdown: search appears past 5 items, list is capped at ~6 rows and scrolls; + creates a folder inline', async ({ page, request }) => {
    await registerAndLoginFreshUser(page, request, 'uxselect');
    await goToNewCredentialForm(page);

    // Credential-type filter lives on the list page; the form's Folder dropdown has only 1 option → no search box.
    const folder = page.locator('[data-field="folderId"]');
    await folder.getByRole('combobox').click();
    await expect(page.getByRole('listbox')).toBeVisible();
    await expect(page.getByPlaceholder('Search…')).toHaveCount(0);
    await page.keyboard.press('Escape');

    // "+" → create a folder without leaving the form; it gets selected.
    const name = `Inline ${Date.now()}`.slice(0, 24);
    await page.locator('[data-field="name"] input').fill('keep me');
    await folder.getByTitle('Create a new folder').click();
    const modal = page.getByTestId('quick-create-modal');
    await modal.getByLabel('Folder name').fill(name);
    await modal.getByRole('button', { name: 'Create', exact: true }).click();
    await expect(modal).toBeHidden();
    await expect(folder.getByRole('combobox')).toContainText(name);
    await expect(page.locator('[data-field="name"] input')).toHaveValue('keep me'); // editor state untouched

    // Credential-type dropdown on the list page has 21 options → search + capped height.
    await goToCredentials(page);
    const type = page.getByRole('combobox', { name: 'Filter by type' });
    await type.click();
    const list = page.getByRole('listbox');
    const search = page.getByPlaceholder('Search…');
    await expect(search).toBeVisible();
    const h = (await list.boundingBox())!.height;
    expect(h).toBeLessThanOrEqual(6 * 36 + 8 + 1);
    await search.fill('wifi');
    await expect(list.getByRole('option')).toHaveCount(1);
    await list.getByRole('option').click();
    await expect(type).toContainText('Wi-Fi');
  });

  test('once something is selected a row click toggles it instead of opening; grid has checkboxes', async ({ page, request }) => {
    await registerAndLoginFreshUser(page, request, 'uxselmode');
    const a = `E2E SelA ${Date.now()}`, b = `E2E SelB ${Date.now()}`;
    await createNote(page, a);
    await createNote(page, b);
    await goToCredentials(page);

    const rowA = page.getByTestId('credential-row').filter({ hasText: a });
    const rowB = page.getByTestId('credential-row').filter({ hasText: b });
    await rowA.locator('input[type="checkbox"]').check();
    await expect(rowA).toHaveAttribute('data-selected', 'true');

    await rowB.click(); // selection active → selects B, does not navigate
    await expect(page).toHaveURL(/\/credentials$/);
    await expect(page.getByText('2 selected')).toBeVisible();
    await rowA.click(); // deselects A
    await expect(page.getByText('1 selected')).toBeVisible();
    await rowB.click(); // last one deselected
    await expect(page.getByText(/selected$/)).toHaveCount(0);

    await rowB.click(); // nothing selected → opens as before
    await expect(page).toHaveURL(/\/credentials\/[0-9a-f-]+$/);
    await page.goBack();

    // Grid view: checkbox column, click-to-toggle, highlighted rows.
    await page.getByTitle(/grid/i).first().click();
    const gridRowA = page.getByTestId('credential-grid-row').filter({ hasText: a });
    await gridRowA.getByRole('checkbox').check();
    await expect(gridRowA).toHaveAttribute('data-selected', 'true');
    await page.getByTestId('credential-grid-row').filter({ hasText: b }).click();
    await expect(page).toHaveURL(/\/credentials$/);
    await expect(page.getByText('2 selected')).toBeVisible();
    await page.getByRole('checkbox', { name: 'Select all rows' }).uncheck();
    await expect(page.getByText(/selected$/)).toHaveCount(0);
  });
});
