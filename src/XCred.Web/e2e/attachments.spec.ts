import { test, expect } from '@playwright/test';
import fs from 'fs';
import path from 'path';
import os from 'os';
import { login, fillTypeFields, goToNewCredentialForm } from './helpers';
import { CREDENTIAL_FIELDS } from '../src/lib/vault';

test.describe('Attachments', () => {
  test.beforeEach(async ({ page }) => { await login(page); });

  test('uploaded file shows its real name and downloads with the original name/content intact', async ({ page }) => {
    const seed = Date.now();
    const name = `E2E Attachment Test ${seed}`;
    const fileName = `xcred-e2e-${seed}.txt`;
    const fileContent = `XCred attachment round-trip test ${seed}\nSecond line.`;
    const filePath = path.join(os.tmpdir(), fileName);
    fs.writeFileSync(filePath, fileContent, 'utf-8');

    await goToNewCredentialForm(page);
    await page.locator('button[data-type="SecureNote"]').click();
    await page.locator('[data-field="name"] input').fill(name);
    await fillTypeFields(page, CREDENTIAL_FIELDS.SecureNote, `${seed}`);
    await page.getByRole('button', { name: 'Save Credential' }).click();
    await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });

    await page.locator('input[placeholder*="Search"]').fill(name);
    await page.getByText(name, { exact: true }).click();
    await expect(page).toHaveURL(/\/credentials\/[0-9a-fA-F-]+$/);

    // Upload — the file input is hidden behind the "Add File" button; setInputFiles works directly on it.
    await page.locator('input[type="file"]').setInputFiles(filePath);
    await expect(page.getByText(`"${fileName}" uploaded and encrypted.`)).toBeVisible({ timeout: 10_000 });

    // Bug fix check #1: the attachment row must show the real decrypted filename, not "Encrypted file".
    const attachmentName = page.getByTestId('attachment-name');
    await expect(attachmentName).toHaveText(fileName, { timeout: 10_000 });
    await expect(attachmentName).not.toHaveText('Encrypted file');

    // Bug fix check #2: downloading must preserve the original filename/extension and content byte-for-byte.
    const downloadPromise = page.waitForEvent('download');
    await page.getByTitle('Download').click();
    const download = await downloadPromise;

    expect(download.suggestedFilename()).toBe(fileName);
    const downloadedPath = await download.path();
    expect(downloadedPath).not.toBeNull();
    const downloadedContent = fs.readFileSync(downloadedPath!, 'utf-8');
    expect(downloadedContent).toBe(fileContent);

    fs.unlinkSync(filePath);
  });
});
