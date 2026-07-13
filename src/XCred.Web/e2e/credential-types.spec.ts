import { test, expect } from '@playwright/test';
import { login, fieldLocator, fillTypeFields, goToNewCredentialForm } from './helpers';
import { CREDENTIAL_FIELDS, CREDENTIAL_TYPES } from '../src/lib/vault';

test.describe('Credential types — create and round-trip decrypt every type', () => {
  test.beforeEach(async ({ page }) => { await login(page); });

  for (const type of CREDENTIAL_TYPES) {
    test(`create and verify a ${type} credential`, async ({ page }) => {
      const seed = `${type}${Date.now()}`;
      const name = `E2E ${seed}`;
      const fields = CREDENTIAL_FIELDS[type];

      await goToNewCredentialForm(page);
      await page.locator(`button[data-type="${type}"]`).click();
      await page.locator('[data-field="name"] input').fill(name);

      const expected = await fillTypeFields(page, fields, seed);

      for (const field of fields) {
        if (field.type !== 'list') continue;
        const container = fieldLocator(page, field.key);
        await container.getByRole('button', { name: /Add/ }).click();
        const value = `10.0.0.${Math.floor(Math.random() * 250) + 1}`;
        await container.locator('input').first().fill(value);
        expected[field.key] = value;
      }

      await page.getByRole('button', { name: 'Save Credential' }).click();
      await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

      await page.locator('input[placeholder*="Search"]').fill(name);
      await page.getByText(name, { exact: true }).click();
      await expect(page).toHaveURL(/\/credentials\/[0-9a-fA-F-]+$/);

      await expect(page.locator('[data-field="name"]')).toHaveText(name);

      for (const field of fields) {
        const row = fieldLocator(page, field.key);
        await expect(row).toBeVisible();
        if (field.type === 'password') {
          await row.locator('button').first().click(); // reveal
        }
        await expect(row).toContainText(expected[field.key]);
      }
    });
  }
});
