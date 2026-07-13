import { test, expect } from '@playwright/test';
import { ADMIN_USERNAME, LOGIN_PASSWORD, login } from './helpers';

test.describe('Registration & login', () => {
  test('logs in with the two-secret model (login password + master password) and lands on the dashboard as Admin', async ({ page }) => {
    await login(page);
    await expect(page.getByTestId('current-username')).toHaveText(ADMIN_USERNAME);
    await expect(page.getByTestId('current-role')).toHaveText('Admin');
  });

  test('correct login password but wrong master password is rejected client-side (cannot decrypt vault)', async ({ page }) => {
    await page.goto('/login');
    await page.locator('input[name="username"]').fill(ADMIN_USERNAME);
    await page.locator('input[name="password"]').fill(LOGIN_PASSWORD);
    await page.locator('input[name="masterPassword"]').fill('TotallyWrongMasterPassword!!');
    await page.getByRole('button', { name: 'Sign In' }).click();

    // Should NOT reach the dashboard — private key decryption fails client-side.
    await expect(page).toHaveURL(/\/login/, { timeout: 8_000 });
    await expect(page.getByText(/Login failed/i)).toBeVisible();
  });

  test('wrong login password is rejected by the server', async ({ page }) => {
    await page.goto('/login');
    await page.locator('input[name="username"]').fill(ADMIN_USERNAME);
    await page.locator('input[name="password"]').fill('WrongLoginPassword123!');
    await page.locator('input[name="masterPassword"]').fill('WhateverMasterPassword1!');
    await page.getByRole('button', { name: 'Sign In' }).click();

    await expect(page).toHaveURL(/\/login/, { timeout: 8_000 });
    await expect(page.getByText(/Invalid username or password/i)).toBeVisible();
  });
});
