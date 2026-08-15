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
