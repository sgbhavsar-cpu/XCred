import { test, expect, type Page } from '@playwright/test';
import { choose, registerAndLoginFreshUser, goToCredentials, goToNewCredentialForm, fillTypeFields, ADMIN_USERNAME, LOGIN_PASSWORD } from './helpers';
import { CREDENTIAL_FIELDS } from '../src/lib/vault';

async function createNote(page: Page, name: string, notes: string) {
  await goToNewCredentialForm(page);
  await page.locator('button[data-type="SecureNote"]').click();
  await page.locator('[data-field="name"] input').fill(name);
  await fillTypeFields(page, CREDENTIAL_FIELDS.SecureNote, name);
  await page.getByPlaceholder('Additional notes…').fill(notes);
  await page.getByRole('button', { name: 'Save Credential' }).click();
  await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });
}

async function selectRows(page: Page, names: string[]) {
  for (const n of names) {
    await page.getByTestId('credential-row').filter({ hasText: n }).locator('input[type="checkbox"]').check();
  }
  await expect(page.getByText(`${names.length} selected`)).toBeVisible();
}

test.describe('Bulk actions: edit (notes, custom fields, expiry, tags), delete, export, share', () => {
  test('bulk edit applies notes, custom field, expiry and a tag to every selected credential', async ({ page, request }) => {
    await registerAndLoginFreshUser(page, request, 'bulkedit');
    const seed = Date.now();
    const a = `E2E BulkA ${seed}`, b = `E2E BulkB ${seed}`, tagName = `bulktag${seed}`.slice(0, 20);

    await page.getByRole('link', { name: 'Tags', exact: true }).click();
    await page.getByRole('button', { name: 'New Tag' }).click();
    await page.getByPlaceholder('Tag name…').fill(tagName);
    await page.getByTitle('Create tag').click();
    await expect(page.getByText(tagName, { exact: true }).first()).toBeVisible();

    await createNote(page, a, 'first note');
    await createNote(page, b, '');
    await selectRows(page, [a, b]);

    await page.getByRole('button', { name: 'Bulk Edit' }).click();
    const modal = page.getByTestId('bulk-edit-modal');
    await modal.getByRole('button', { name: tagName }).click(); // add tag
    await choose(page, modal.getByRole('combobox', { name: 'Expiry change' }), 'Set to a date');
    await modal.getByLabel('Expiry date').fill('2031-05-17');
    await choose(page, modal.getByRole('combobox', { name: 'Notes change' }), 'Add to the end');
    await modal.locator('textarea').fill('Reviewed in bulk');
    await modal.getByRole('button', { name: 'Add change' }).click();
    await modal.getByLabel('Custom field label').fill('Owner');
    await modal.getByLabel('Custom field value').fill('IT Team');
    await modal.getByRole('button', { name: 'Apply' }).click();
    await expect(page.getByText('Updated 2 credentials.')).toBeVisible({ timeout: 15_000 });

    // A: existing note kept, new line appended. B: had no note, so just the new text.
    await page.getByTestId('credential-row').filter({ hasText: a }).click();
    await expect(page.getByText(/first note\s*Reviewed in bulk/)).toBeVisible();
    await expect(page.getByText('Owner', { exact: true })).toBeVisible();
    await expect(page.getByText('IT Team')).toBeVisible();
    await expect(page.getByText('May 17, 2031')).toBeVisible();
    await expect(page.getByText(tagName, { exact: true })).toBeVisible();

    await page.goBack();
    await page.getByTestId('credential-row').filter({ hasText: b }).click();
    await expect(page.getByText('Reviewed in bulk')).toBeVisible();
    await expect(page.getByText('IT Team')).toBeVisible();
  });

  test('bulk export downloads only the selected rows, and bulk delete removes them', async ({ page, request }) => {
    await registerAndLoginFreshUser(page, request, 'bulkdel');
    const seed = Date.now();
    const a = `E2E DelA ${seed}`, b = `E2E DelB ${seed}`, keep = `E2E Keep ${seed}`;
    for (const n of [a, b, keep]) await createNote(page, n, '');

    await selectRows(page, [a, b]);
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.getByRole('button', { name: 'Export CSV' }).first().click(),
    ]);
    expect(download.suggestedFilename()).toMatch(/^xcred-selected-/);
    const csv = (await (await download.createReadStream()).toArray()).join('');
    expect(csv).toContain(a);
    expect(csv).toContain(b);
    expect(csv).not.toContain(keep);

    page.once('dialog', d => d.accept());
    await page.locator('div.sticky').getByRole('button', { name: 'Delete', exact: true }).click();
    await expect(page.getByText('Deleted 2 credentials.')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByTestId('credential-row').filter({ hasText: a })).toHaveCount(0);
    await expect(page.getByTestId('credential-row').filter({ hasText: b })).toHaveCount(0);
    await expect(page.getByTestId('credential-row').filter({ hasText: keep })).toBeVisible();
  });

  test('bulk share shares every selected credential with the chosen user', async ({ page, request }) => {
    const recipient = await registerAndLoginFreshUser(page, request, 'sharerecv');
    const sender = await registerAndLoginFreshUser(page, request, 'sharesend');
    const seed = Date.now();
    const a = `E2E ShareA ${seed}`, b = `E2E ShareB ${seed}`;
    await goToCredentials(page);
    await createNote(page, a, '');
    await createNote(page, b, '');
    await selectRows(page, [a, b]);

    await page.getByRole('button', { name: 'Share', exact: true }).click();
    const modal = page.getByTestId('bulk-share-modal');
    await choose(page, modal.getByRole('combobox'), new RegExp(`^${recipient} \\(`));
    await modal.getByRole('button', { name: 'Share', exact: true }).click();
    await expect(page.getByText(new RegExp(`Shared 2 credentials with ${recipient}`))).toBeVisible({ timeout: 15_000 });

    const login = await request.post('/api/auth/login', { data: { username: sender, password: LOGIN_PASSWORD } });
    const token = (await login.json()).data.accessToken;
    const shared = await request.get('/api/shares/shared-by-me', { headers: { Authorization: `Bearer ${token}` } });
    expect((await shared.json()).data.filter((s: any) => s.sharedWithUsername === recipient)).toHaveLength(2);
    expect(ADMIN_USERNAME).toBeTruthy();
  });
});
