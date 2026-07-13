import { test, expect } from '@playwright/test';
import { login, fillTypeFields, goToNewCredentialForm, goToCredentialGroups } from './helpers';
import { CREDENTIAL_FIELDS } from '../src/lib/vault';

test.describe('Credential Groups', () => {
  test.beforeEach(async ({ page }) => { await login(page); });

  test('bundles debit cards, netbanking login, and mobile banking PIN under one Bank credential group', async ({ page }) => {
    const seed = Date.now();
    const groupName = `E2E Bank ${seed}`;

    // 1. Create the credential group
    await goToCredentialGroups(page);
    await page.getByRole('button', { name: 'New Group' }).click();
    await page.locator('input[placeholder*="HDFC Bank"]').fill(groupName);
    await page.getByRole('button', { name: 'Create', exact: true }).click();
    await expect(page.getByText(groupName)).toBeVisible();

    await page.getByText(groupName).click();
    await expect(page).toHaveURL(/\/credential-groups\/[0-9a-fA-F-]+$/, { timeout: 10_000 });
    const groupId = page.url().split('/').pop()!;

    // 2. Create 4 member credentials of different types, each assigned to the group at creation time
    const members = [
      { type: 'CreditCard', name: `${groupName} - Debit Card 1` },
      { type: 'CreditCard', name: `${groupName} - Debit Card 2` },
      { type: 'WebsiteLogin', name: `${groupName} - Netbanking` },
      { type: 'MobileBankingPin', name: `${groupName} - Mobile PIN` },
    ];

    for (const member of members) {
      await goToNewCredentialForm(page);
      await page.locator(`button[data-type="${member.type}"]`).click();
      await page.locator('[data-field="name"] input').fill(member.name);
      await fillTypeFields(page, CREDENTIAL_FIELDS[member.type], `${seed}`);

      await page.locator('[data-field="credentialGroupId"] select').selectOption(groupId);
      await page.getByRole('button', { name: 'Save Credential' }).click();
      await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });
    }

    // 3. Verify all four show up inside the group, and nowhere confused with the group itself
    await goToCredentialGroups(page);
    await page.getByText(groupName).click();
    await expect(page).toHaveURL(/\/credential-groups\/[0-9a-fA-F-]+$/);
    await expect(page.getByText('4 credentials')).toBeVisible();
    for (const member of members) {
      await expect(page.getByText(member.name)).toBeVisible();
    }

    // 4. Verify the reverse link: opening a member credential shows the Credential Group badge
    // (member.name embeds groupName as a substring, so target the group-link button specifically
    // rather than getByText(groupName), which would also match the credential's own heading)
    await page.getByText(members[0].name).click();
    await expect(page).toHaveURL(/\/credentials\/[0-9a-fA-F-]+$/);
    await expect(page.getByText('Credential Group:')).toBeVisible();
    await expect(page.getByRole('button', { name: groupName, exact: true })).toBeVisible();
  });
});
