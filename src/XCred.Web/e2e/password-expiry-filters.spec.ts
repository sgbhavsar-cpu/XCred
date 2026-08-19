import { test, expect } from '@playwright/test';
import {
  registerAndLoginFreshUser, goToCredentials, goToNewCredentialForm, fillTypeFields, fieldLocator,
} from './helpers';
import { CREDENTIAL_FIELDS } from '../src/lib/vault';

test.describe('Missing-password / expired filters and CSV export', () => {
  test('Credentials page: toggle filters narrow the list, and CSV export downloads the filtered rows', async ({ page, request }) => {
    const seed = Date.now().toString().slice(-6);
    await registerAndLoginFreshUser(page, request, 'pwfilter');

    const withPassword = `PwFilter WithPassword ${seed}`;
    const noPassword = `PwFilter NoPassword ${seed}`;
    const expired = `PwFilter Expired ${seed}`;
    const notExpired = `PwFilter NotExpired ${seed}`;

    // WithPassword — a normal WebsiteLogin, every field (incl. password) filled in.
    await goToNewCredentialForm(page);
    await page.locator('button[data-type="WebsiteLogin"]').click();
    await fieldLocator(page, 'name').locator('input').fill(withPassword);
    await fillTypeFields(page, CREDENTIAL_FIELDS.WebsiteLogin, seed);
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    // NoPassword — Generic type, only Name filled; its password field exists but is left empty.
    await goToNewCredentialForm(page);
    await page.locator('button[data-type="Generic"]').click();
    await fieldLocator(page, 'name').locator('input').fill(noPassword);
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    // Expired — WebsiteLogin with an expiry date in the past.
    await goToNewCredentialForm(page);
    await page.locator('button[data-type="WebsiteLogin"]').click();
    await fieldLocator(page, 'name').locator('input').fill(expired);
    await fillTypeFields(page, CREDENTIAL_FIELDS.WebsiteLogin, seed);
    await page.locator('input[type="date"]').fill('2020-01-01');
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    // NotExpired — WebsiteLogin with an expiry date far in the future.
    await goToNewCredentialForm(page);
    await page.locator('button[data-type="WebsiteLogin"]').click();
    await fieldLocator(page, 'name').locator('input').fill(notExpired);
    await fillTypeFields(page, CREDENTIAL_FIELDS.WebsiteLogin, seed);
    await page.locator('input[type="date"]').fill('2099-01-01');
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    await goToCredentials(page);
    await page.locator('input[placeholder*="Search by name"]').fill(seed);
    await expect(page.getByText(withPassword)).toBeVisible();
    await expect(page.getByText(noPassword)).toBeVisible();
    await expect(page.getByText(expired)).toBeVisible();
    await expect(page.getByText(notExpired)).toBeVisible();

    // --- "No password configured" toggle ---
    const noPasswordToggle = page.getByTitle('Show only credentials missing a password');
    await noPasswordToggle.click();
    await expect(page.getByText(noPassword)).toBeVisible();
    await expect(page.getByText(withPassword)).not.toBeVisible();
    await expect(page.getByText(expired)).not.toBeVisible();
    await expect(page.getByText(notExpired)).not.toBeVisible();
    await noPasswordToggle.click(); // toggle back off

    // --- "Expired" toggle ---
    const expiredToggle = page.getByTitle('Show only expired credentials');
    await expiredToggle.click();
    await expect(page.getByText(expired)).toBeVisible();
    await expect(page.getByText(notExpired)).not.toBeVisible();
    await expect(page.getByText(withPassword)).not.toBeVisible();
    await expect(page.getByText(noPassword)).not.toBeVisible();

    // --- CSV export of the currently-filtered (expired-only) list ---
    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.getByTitle('Export filtered list to CSV').click(),
    ]);
    expect(download.suggestedFilename()).toMatch(/^xcred-credentials-\d{4}-\d{2}-\d{2}\.csv$/);
    const csvPath = await download.path();
    const fs = await import('fs');
    const csv = fs.readFileSync(csvPath!, 'utf-8');
    expect(csv).toContain('Name,Type,Username,Tags,Has Password,Expiry Date,Last Updated');
    expect(csv).toContain(expired);
    expect(csv).not.toContain(notExpired);
    expect(csv).not.toContain(withPassword);
    expect(csv).not.toContain(noPassword);
    // Never leak an actual password value into the export — only "Yes"/"No" for whether one's set.
    expect(csv).not.toMatch(/S3cret!/);
  });

  test('Folders and Tags pages: same two toggle buttons work there too', async ({ page, request }) => {
    const seed = Date.now().toString().slice(-6);
    await registerAndLoginFreshUser(page, request, 'pwfilter2');

    const noPassword = `PwFilter2 NoPassword ${seed}`;
    const withPassword = `PwFilter2 WithPassword ${seed}`;

    await goToNewCredentialForm(page);
    await page.locator('button[data-type="Generic"]').click();
    await fieldLocator(page, 'name').locator('input').fill(noPassword);
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    await goToNewCredentialForm(page);
    await page.locator('button[data-type="WebsiteLogin"]').click();
    await fieldLocator(page, 'name').locator('input').fill(withPassword);
    await fillTypeFields(page, CREDENTIAL_FIELDS.WebsiteLogin, seed);
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    // Folders page
    await page.getByRole('link', { name: 'Folders', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Folders', exact: true })).toBeVisible();
    await expect(page.getByText(noPassword)).toBeVisible();
    await expect(page.getByText(withPassword)).toBeVisible();
    await page.getByTitle('Show only credentials missing a password').click();
    await expect(page.getByText(noPassword)).toBeVisible();
    await expect(page.getByText(withPassword)).not.toBeVisible();

    // Tags page
    await page.getByRole('link', { name: 'Tags', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Tags', exact: true })).toBeVisible();
    await expect(page.getByText(noPassword)).toBeVisible();
    await expect(page.getByText(withPassword)).toBeVisible();
    await page.getByTitle('Show only credentials missing a password').click();
    await expect(page.getByText(noPassword)).toBeVisible();
    await expect(page.getByText(withPassword)).not.toBeVisible();
  });
});
