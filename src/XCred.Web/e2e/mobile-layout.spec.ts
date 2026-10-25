import { test, expect, type Page } from '@playwright/test';
import { choose, registerAndLoginFreshUser, goToNewCredentialForm, fillTypeFields, login } from './helpers';
import { CREDENTIAL_FIELDS } from '../src/lib/vault';
import fs from 'node:fs';

// Phone-width layout guard: every page and dialog must fit the viewport — no sideways page scroll and
// nothing poking past the screen edge (tables inside their own horizontal scroller are exempt).
// Set AUDIT_OUT=<dir> to also save a screenshot of each screen for eyeballing; AUDIT_W for another width.
const OUT = process.env.AUDIT_OUT;
const W = Number(process.env.AUDIT_W ?? 375);
if (OUT) fs.mkdirSync(OUT, { recursive: true });

async function nav(page: Page, path: string) {
  await page.evaluate(p => { history.pushState({}, '', p); window.dispatchEvent(new PopStateEvent('popstate')); }, path);
  await page.waitForTimeout(900);
}

/** Reports page-level horizontal overflow and visible elements poking outside the viewport. */
async function audit(page: Page, label: string) {
  await page.waitForTimeout(250);
  const issues = await page.evaluate(() => {
    const vw = document.documentElement.clientWidth;
    const out: string[] = [];
    if (document.documentElement.scrollWidth > vw + 1) out.push(`PAGE scrollWidth ${document.documentElement.scrollWidth} > ${vw}`);
    const main = document.querySelector('main');
    if (main && main.scrollWidth > main.clientWidth + 1) out.push(`MAIN scrolls horizontally: ${main.scrollWidth} > ${main.clientWidth}`);
    const describe = (el: Element) => {
      const c = typeof (el as HTMLElement).className === 'string' ? (el as HTMLElement).className.slice(0, 60) : '';
      const t = (el.textContent ?? '').trim().replace(/\s+/g, ' ').slice(0, 40);
      return `<${el.tagName.toLowerCase()} class="${c}"> "${t}"`;
    };
    // Is the element inside a scroll container that legitimately clips (overflow-x auto/scroll/hidden)?
    const scrolled = (el: Element) => {
      for (let p = el.parentElement; p && p !== document.body; p = p.parentElement) {
        const o = getComputedStyle(p).overflowX;
        if ((o === 'auto' || o === 'scroll') && p.scrollWidth > p.clientWidth) return true;
        if (getComputedStyle(p).position === 'fixed' && p.tagName === 'ASIDE') return true;
      }
      return false;
    };
    const seen = new Set<Element>();
    for (const el of Array.from(document.querySelectorAll('body *'))) {
      const cs = getComputedStyle(el);
      if (cs.visibility === 'hidden' || cs.display === 'none') continue;
      const r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) continue;
      if (el.closest('aside')) continue;
      if (r.right > vw + 1 || r.left < -1) {
        if (scrolled(el)) continue;
        // report only the outermost offender
        let parent = el.parentElement, dup = false;
        while (parent) { if (seen.has(parent)) { dup = true; break; } parent = parent.parentElement; }
        if (!dup) { seen.add(el); out.push(`OFFSCREEN x ${Math.round(r.left)}..${Math.round(r.right)} (vw ${vw}) ${describe(el)}`); }
      }
      // text clipped by its own box (single-line truncation is OK: class contains truncate)
      if ((el as HTMLElement).scrollWidth > (el as HTMLElement).clientWidth + 2 && cs.overflowX === 'hidden'
          && !(cs.textOverflow === 'ellipsis') && el.children.length === 0 && (el.textContent ?? '').trim()) {
        out.push(`CLIPPED text ${describe(el)}`);
      }
    }
    return out;
  });
  if (OUT) await page.screenshot({ path: `${OUT}/${label}.png`, fullPage: false });
  expect(issues, `layout problems on "${label}" at ${W}px`).toEqual([]);
}

async function mk(page: Page, type: string, name: string, extra: (p: Page) => Promise<void> = async () => {}) {
  await goToNewCredentialForm(page);
  await page.locator(`button[data-type="${type}"]`).click();
  await page.locator('[data-field="name"] input').fill(name);
  await fillTypeFields(page, CREDENTIAL_FIELDS[type], name.slice(-6));
  await extra(page);
  await page.getByRole('button', { name: 'Save Credential' }).click();
  await expect(page).toHaveURL(/\/credentials$/, { timeout: 10_000 });
}

test('phone layout: every page and dialog fits the screen', async ({ page, request }) => {
  test.setTimeout(240_000);
  await page.setViewportSize({ width: 1280, height: 800 }); // seed at desktop size: helpers click the sidebar
  const recipient = await registerAndLoginFreshUser(page, request, 'mobrecv');
  await registerAndLoginFreshUser(page, request, 'mobuser');
  const seed = Date.now();

  // data: folder > subfolder, group, tag-less creds with long names
  await nav(page, '/folders');
  await page.getByRole('button', { name: 'New Folder', exact: true }).click();
  await page.getByPlaceholder('Folder name').fill('Operations and Compliance Documents');
  await page.getByRole('button', { name: 'Create', exact: true }).click();
  await expect(page.getByPlaceholder('Folder name')).toBeHidden();
  await nav(page, '/credentials');
  await page.getByRole('button', { name: 'New Credential Group' }).click();
  await page.locator('input[placeholder*="HDFC Bank"]').fill('A Very Long Credential Group Name For Banking');
  await page.getByRole('button', { name: 'Create', exact: true }).click();
  await page.waitForTimeout(600);

  await mk(page, 'WebsiteLogin', `Corporate Banking Portal Login For Treasury ${seed}`, async p => {
    await choose(p, p.locator('[data-field="folderId"]').getByRole('combobox'), /Operations/);
    await choose(p, p.locator('[data-field="credentialGroupId"]').getByRole('combobox'), /A Very Long/);
  });
  await mk(page, 'LegalCertificate', `ISO 27001 Information Security Certificate ${seed}`);
  await mk(page, 'WindowsServer', `Production Domain Controller ${seed}`);

  await page.setViewportSize({ width: W, height: 812 });
  // share one credential so the shared icon + dialog exist
  await nav(page, '/credentials');
  await page.getByTestId('credential-row').first().locator('input[type="checkbox"]').check();
  await audit(page, '01-credentials-selected');
  await page.getByRole('button', { name: 'Share', exact: true }).click();
  await audit(page, '02-bulk-share-modal');
  const modal = page.getByTestId('bulk-share-modal');
  await modal.getByRole('combobox').click();
  await audit(page, '03-dropdown-open-in-modal');
  await page.getByRole('option', { name: new RegExp(recipient) }).click();
  await modal.getByRole('button', { name: 'Share', exact: true }).click();
  await page.waitForTimeout(1500);

  await nav(page, '/credentials');
  await audit(page, '04-credentials-list');
  const icon = page.getByTestId('shared-icon').first();
  if (await icon.count()) { await icon.click(); await audit(page, '05-shares-dialog'); await page.keyboard.press('Escape'); await page.mouse.click(5, 5); }
  await page.getByTitle('Grid view').click();
  await audit(page, '06-credentials-grid');
  await page.getByTitle('List view').click();

  await page.getByTestId('credential-row').first().locator('input[type="checkbox"]').check();
  await page.getByRole('button', { name: 'Bulk Edit' }).click();
  await audit(page, '07-bulk-edit-modal');
  await page.getByTestId('bulk-edit-modal').getByTitle('Create a new folder').click();
  await audit(page, '08-quick-create-folder');
  await page.getByTestId('quick-create-modal').getByRole('button', { name: 'Cancel' }).click();
  await page.getByTestId('bulk-edit-modal').getByRole('button', { name: 'Cancel' }).click();
  await page.getByTitle('Clear selection').click();

  await nav(page, '/credentials/new');
  await audit(page, '09-form-new');
  await page.locator('button[data-type="WindowsServer"]').click();
  await audit(page, '10-form-windows-server');
  await page.locator('button[data-type="LegalCertificate"]').click();
  await page.waitForTimeout(300);
  await audit(page, '11-form-legal-certificate');
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.locator('main').evaluate(m => m.scrollTo(0, m.scrollHeight));
  await audit(page, '12-form-bottom');

  await nav(page, '/credentials');
  await page.getByTestId('credential-row').first().click();
  await page.waitForTimeout(900);
  await audit(page, '13-detail');
  await page.locator('main').evaluate(m => m.scrollTo(0, m.scrollHeight));
  await audit(page, '14-detail-bottom');

  await nav(page, '/folders');
  await page.locator('div.cursor-pointer', { hasText: 'Operations and Compliance' }).first().click();
  await audit(page, '15-folders');
  await page.getByTitle('Grid view').click();
  await audit(page, '16-folders-grid');
  await page.getByTitle('List view').click();
  await nav(page, '/groups'); await audit(page, '17-teams');
  await nav(page, '/tags'); await audit(page, '18-tags');
  await nav(page, '/shares'); await audit(page, '19-shared-with-me');
  await page.getByRole('button', { name: /Shared By Me/ }).click(); await audit(page, '20-shared-by-me');
  await nav(page, '/dashboard'); await audit(page, '21-dashboard');
  await nav(page, '/settings'); await audit(page, '22-settings');
  for (const [i, tab] of ['Security', 'Notifications', 'Backup', 'Import', 'Master'].entries()) {
    const b = page.getByRole('button', { name: new RegExp(tab, 'i') }).first();
    if (await b.count()) { await b.click(); await audit(page, `23-settings-${i}-${tab}`); }
  }
  // sidebar drawer
  await page.getByLabel('Open menu').click(); await audit(page, '24-drawer');
});

test('phone layout: admin pages fit the screen', async ({ page }) => {
  await page.setViewportSize({ width: W, height: 812 });
  await login(page);
  await nav(page, '/admin'); await audit(page, '30-admin');
  for (const [i, tab] of ['Users', 'Settings', 'Audit', 'Backup', 'System'].entries()) {
    const b = page.getByRole('button', { name: new RegExp(tab, 'i') }).first();
    if (await b.count()) { await b.click(); await audit(page, `31-admin-${i}-${tab}`); }
  }
});
