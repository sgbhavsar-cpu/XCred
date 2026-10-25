import { test, expect, type Page } from '@playwright/test';
import { choose, registerAndLoginFreshUser, goToNewCredentialForm, fillTypeFields, goToCredentials, LOGIN_PASSWORD } from './helpers';
import { CREDENTIAL_FIELDS } from '../src/lib/vault';

async function createNote(page: Page, name: string, opts: { folder?: string; group?: string } = {}) {
  await goToNewCredentialForm(page);
  await page.locator('button[data-type="SecureNote"]').click();
  await page.locator('[data-field="name"] input').fill(name);
  await fillTypeFields(page, CREDENTIAL_FIELDS.SecureNote, name);
  if (opts.folder) await choose(page, page.locator('[data-field="folderId"]').getByRole('combobox'), opts.folder);
  if (opts.group) await choose(page, page.locator('[data-field="credentialGroupId"]').getByRole('combobox'), new RegExp(opts.group));
  await page.getByRole('button', { name: 'Save Credential' }).click();
  await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });
}

async function newFolder(page: Page, name: string, parent?: string) {
  await page.getByRole('button', { name: 'New Folder', exact: true }).click();
  await page.getByPlaceholder('Folder name').fill(name);
  if (parent) await choose(page, page.getByRole('combobox', { name: 'Parent folder' }), parent);
  await page.getByRole('button', { name: 'Create', exact: true }).click();
  await expect(page.getByPlaceholder('Folder name')).toBeHidden();
}

test.describe('Share a whole folder / credential group; manage shares from the row icon', () => {
  test('folder share covers its subtree, rows get a shared icon, dialog edits and stops sharing', async ({ page, request }) => {
    const recipient = await registerAndLoginFreshUser(page, request, 'treerecv');
    const sender = await registerAndLoginFreshUser(page, request, 'treesend');
    const seed = Date.now();
    const root = `Root${seed}`.slice(0, 18), sub = `Sub${seed}`.slice(0, 18);
    const inRoot = `E2E InRoot ${seed}`, inSub = `E2E InSub ${seed}`, outside = `E2E Outside ${seed}`;

    await page.getByRole('link', { name: 'Folders', exact: true }).click();
    await newFolder(page, root);
    await newFolder(page, sub, root);
    await createNote(page, inRoot, { folder: root });
    await createNote(page, inSub, { folder: `${root} / ${sub}` });
    await createNote(page, outside);

    // Share the root folder → both credentials in its tree (root + subfolder) are shared; "outside" is not.
    await page.getByRole('link', { name: 'Folders', exact: true }).click();
    await page.locator('div.cursor-pointer', { hasText: root }).first().getByTestId('share-folder').click();
    const modal = page.getByTestId('bulk-share-modal');
    await expect(modal).toContainText(`Share 2 credentials from ${root}`);
    await choose(page, modal.getByRole('combobox'), new RegExp(`^${recipient} \\(`));
    await modal.getByRole('button', { name: 'Share', exact: true }).click();
    await expect(page.getByText(new RegExp(`Shared 2 credentials from ${root} with ${recipient}`))).toBeVisible({ timeout: 15_000 });

    // Sharing again must not create duplicates (server refreshes the existing share).
    const login = await request.post('/api/auth/login', { data: { username: sender, password: LOGIN_PASSWORD } });
    const token = (await login.json()).data.accessToken;
    const mine = async () => ((await (await request.get('/api/shares/shared-by-me', { headers: { Authorization: `Bearer ${token}` } })).json()).data as Array<{ id: string; expiresAt: string | null; untilChanged: boolean; sharedWithUsername: string }>);
    expect(await mine()).toHaveLength(2);

    // Credentials page: shared icon on the two, none on the third.
    await goToCredentials(page);
    const rowOf = (n: string) => page.getByTestId('credential-row').filter({ hasText: n });
    await expect(rowOf(inRoot).getByTestId('shared-icon')).toBeVisible();
    await expect(rowOf(inSub).getByTestId('shared-icon')).toBeVisible();
    await expect(rowOf(outside).getByTestId('shared-icon')).toHaveCount(0);

    // Dialog: lists the user; edit end date + flag, save.
    await rowOf(inRoot).getByTestId('shared-icon').click();
    const dlg = page.getByTestId('credential-shares-dialog');
    await expect(dlg.getByTestId('share-row')).toHaveCount(1);
    await expect(dlg).toContainText(recipient);
    await expect(dlg.getByRole('button', { name: 'Save' })).toBeDisabled();
    await dlg.getByLabel('Access end date').fill('2031-05-17');
    await dlg.getByLabel('Revoke on change').check();
    await dlg.getByRole('button', { name: 'Save' }).click();
    await expect(page.getByText('Share updated.')).toBeVisible();
    const updated = (await mine()).filter(s => s.untilChanged);
    expect(updated).toHaveLength(1);
    expect(updated[0].expiresAt).toContain('2031-05-17');

    // Stop sharing immediately → icon disappears for that credential only.
    page.once('dialog', d => d.accept());
    await dlg.getByRole('button', { name: 'Stop sharing', exact: true }).click();
    await expect(dlg).toBeHidden();
    await expect(rowOf(inRoot).getByTestId('shared-icon')).toHaveCount(0);
    await expect(rowOf(inSub).getByTestId('shared-icon')).toBeVisible();
    expect(await mine()).toHaveLength(1);
  });

  test('credential group share button shares its members', async ({ page, request }) => {
    const recipient = await registerAndLoginFreshUser(page, request, 'grprecv');
    await registerAndLoginFreshUser(page, request, 'grpsend');
    const seed = Date.now();
    const group = `Grp ${seed}`, member = `E2E GrpMember ${seed}`;

    await goToCredentials(page);
    await page.getByRole('button', { name: 'New Credential Group' }).click();
    await page.locator('input[placeholder*="HDFC Bank"]').fill(group);
    await page.getByRole('button', { name: 'Create', exact: true }).click();
    await expect(page.getByText(group)).toBeVisible();
    await createNote(page, member, { group });

    await page.locator('div.cursor-pointer', { hasText: group }).first().getByTestId('share-group').click();
    const modal = page.getByTestId('bulk-share-modal');
    await expect(modal).toContainText(`Share 1 credential from ${group}`);
    await choose(page, modal.getByRole('combobox'), new RegExp(`^${recipient} \\(`));
    await modal.getByRole('button', { name: 'Share', exact: true }).click();
    await expect(page.getByText(new RegExp(`Shared 1 credential from ${group} with ${recipient}`))).toBeVisible({ timeout: 15_000 });

    await page.locator('div.cursor-pointer', { hasText: group }).first().click(); // expand
    await expect(page.getByTestId('credential-row').filter({ hasText: member }).getByTestId('shared-icon')).toBeVisible();
  });
});
