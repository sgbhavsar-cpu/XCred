import { credentialTypeLabel, formatDate } from './utils';

// Minimal RFC4180-ish CSV parser — no external dependency needed for what credential
// exports (Chrome/Firefox/Bitwarden/LastPass/1Password, or someone's own spreadsheet)
// actually produce: quoted fields, commas/newlines inside quotes, doubled `""` as an
// escaped quote. Handles both CRLF and bare LF line endings.
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let inQuotes = false;
  // Normalize CRLF up front so the state machine only has to think about \n.
  const src = text.replace(/\r\n/g, '\n');

  for (let i = 0; i < src.length; i++) {
    const c = src[i];

    if (inQuotes) {
      if (c === '"') {
        if (src[i + 1] === '"') { field += '"'; i++; }
        else { inQuotes = false; }
      } else {
        field += c;
      }
      continue;
    }

    if (c === '"') { inQuotes = true; continue; }
    if (c === ',') { row.push(field); field = ''; continue; }
    if (c === '\n') {
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
      continue;
    }
    if (c === '\r') continue; // stray CR (bare \r line endings) — drop
    field += c;
  }

  // Final field/row (files without a trailing newline).
  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }

  // Drop fully-blank trailing rows (common with a trailing newline).
  while (rows.length > 0 && rows[rows.length - 1].every(c => c.trim() === '')) rows.pop();

  return rows;
}

export interface CsvColumnMapping {
  name: number | null;
  url: number | null;
  username: number | null;
  password: number | null;
  notes: number | null;
}

const HEADER_ALIASES: Record<keyof CsvColumnMapping, string[]> = {
  name: ['name', 'title', 'site', 'label', 'account', 'item name'],
  url: ['url', 'website', 'site url', 'login_uri', 'link', 'web site'],
  username: ['username', 'user', 'login', 'email', 'login_username', 'user name'],
  password: ['password', 'pass', 'login_password'],
  notes: ['notes', 'note', 'comment', 'comments', 'extra'],
};

/** Best-effort guess at which CSV column is which — the user confirms/adjusts before import. */
export function guessColumnMapping(headers: string[]): CsvColumnMapping {
  const normalized = headers.map(h => h.trim().toLowerCase());
  const find = (aliases: string[]) => {
    const idx = normalized.findIndex(h => aliases.includes(h));
    return idx === -1 ? null : idx;
  };
  return {
    name: find(HEADER_ALIASES.name),
    url: find(HEADER_ALIASES.url),
    username: find(HEADER_ALIASES.username),
    password: find(HEADER_ALIASES.password),
    notes: find(HEADER_ALIASES.notes),
  };
}

function csvEscape(value: string): string {
  return /[",\n]/.test(value) ? `"${value.replace(/"/g, '""')}"` : value;
}

/** Inverse of parseCsv — RFC4180-ish, CRLF row endings. */
export function rowsToCsv(headers: string[], rows: string[][]): string {
  return [headers, ...rows].map(r => r.map(csvEscape).join(',')).join('\r\n');
}

export function downloadCsv(filename: string, csv: string): void {
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

/** Shared by the Credentials/Folders/Tags toolbar export button — a metadata/audit summary,
 *  not a secrets dump: actual password *values* are never included (only whether one's set),
 *  since this is a plain-text file that ends up sitting unencrypted on disk. Someone who
 *  genuinely wants every decrypted field belongs at Settings' "Export All as Plain JSON"
 *  instead, which already carries that warning. */
export function buildCredentialsCsv(
  items: Array<{ id: string; type: string; expiryDate: string | null; updatedAt: string; tags: Array<{ name: string }> }>,
  decrypted: Map<string, { name: string; username?: string; hasPassword: boolean }>,
): string {
  const rows = items.map(c => {
    const d = decrypted.get(c.id);
    return [
      d?.name ?? credentialTypeLabel(c.type),
      credentialTypeLabel(c.type),
      d?.username ?? '',
      c.tags.map(t => t.name).join('; '),
      d?.hasPassword === false ? 'No' : 'Yes',
      c.expiryDate ? formatDate(c.expiryDate) : '',
      formatDate(c.updatedAt),
    ];
  });
  return rowsToCsv(['Name', 'Type', 'Username', 'Tags', 'Has Password', 'Expiry Date', 'Last Updated'], rows);
}
