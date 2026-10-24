import { useMemo } from 'react';
import { CREDENTIAL_FIELDS } from './vault';
import { readAccounts } from './accounts';
import { credentialTypeLabel } from './utils';
import type { CredentialListItem, DecryptedCredentialMeta } from '@/hooks/useDecryptedCredentials';

// Search model (see the spec agreed for the credentials search box):
//  - substring ("contains") match, case-insensitive, never "starts with"
//  - the query is split on whitespace; a credential matches when ANY word is found, in any field, in
//    any order ("Sachin Office" = contains 'sachin' OR contains 'office')
//  - results rank by how many of the words matched (then by how many matched in the name)
//  - never searches secrets: password-type fields, fields flagged noSearch (card numbers, private
//    keys, recovery codes, …), hidden custom fields and the password of every account row
// Credential data is end-to-end encrypted, so this runs in the browser over the decrypted vault.

const SEP = '\u0001'; // joins fields so a word can't match across two neighbouring values

export interface SearchEntry { hay: string; name: string }
export type SearchIndex = Map<string, SearchEntry>;

export function tokenize(query: string): string[] {
  return Array.from(new Set(query.toLowerCase().split(/\s+/).filter(Boolean)));
}

function listItems(raw: string | undefined): string[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.map(String) : [raw];
  } catch {
    return [raw];
  }
}

/** Lowercased searchable text for one credential. Exported for tests/diagnostics. */
export function buildSearchEntry(
  item: Pick<CredentialListItem, 'type' | 'tags'>,
  meta: DecryptedCredentialMeta | undefined,
): SearchEntry {
  const fields = meta?.fields;
  const parts: string[] = [meta?.name ?? '', credentialTypeLabel(item.type)];

  if (fields) {
    for (const def of CREDENTIAL_FIELDS[item.type] ?? []) {
      if (def.type === 'password' || def.noSearch) continue;
      if (def.type === 'accounts') {
        for (const a of readAccounts(fields)) parts.push(a.label, a.username);
      } else if (def.type === 'list') {
        parts.push(...listItems(fields[def.key]));
      } else {
        parts.push(fields[def.key] ?? '');
      }
    }
    parts.push(fields.notes ?? '');
    try {
      const custom = JSON.parse(fields.customFields ?? '[]');
      if (Array.isArray(custom)) {
        for (const cf of custom) {
          if (cf?.fieldType === 'password') continue;
          parts.push(String(cf?.label ?? ''), String(cf?.value ?? ''));
        }
      }
    } catch { /* malformed custom fields: just skip them */ }
  }
  parts.push(...item.tags.map(t => t.name));

  return { hay: parts.join(SEP).toLowerCase(), name: (meta?.name ?? '').toLowerCase() };
}

export function buildSearchIndex(
  credentials: CredentialListItem[],
  decrypted: Map<string, DecryptedCredentialMeta>,
): SearchIndex {
  const index: SearchIndex = new Map();
  for (const c of credentials) index.set(c.id, buildSearchEntry(c, decrypted.get(c.id)));
  return index;
}

/** Rank score (0 = no match): matched words dominate, name hits break ties. */
export function scoreEntry(entry: SearchEntry, tokens: string[]): number {
  let matched = 0;
  let inName = 0;
  for (const t of tokens) {
    if (entry.hay.includes(t)) {
      matched++;
      if (entry.name.includes(t)) inName++;
    }
  }
  return matched === 0 ? 0 : matched * 100 + inName;
}

/** True when any word is contained in the name (used for folder and credential-group names). */
export function nameMatches(name: string, tokens: string[]): boolean {
  if (tokens.length === 0) return false;
  const n = name.toLowerCase();
  return tokens.some(t => n.includes(t));
}

export interface CredentialSearch {
  /** The query has at least one word. */
  active: boolean;
  tokens: string[];
  /** id -> rank score for credentials whose own fields match. Empty when the search is inactive. */
  scores: Map<string, number>;
}

/** Index rebuilds only when the vault changes; each keystroke is just a pass over cached strings,
 *  which keeps results instantaneous without a debounce. */
export function useCredentialSearch(
  credentials: CredentialListItem[],
  decrypted: Map<string, DecryptedCredentialMeta>,
  query: string,
): CredentialSearch {
  const index = useMemo(() => buildSearchIndex(credentials, decrypted), [credentials, decrypted]);
  return useMemo(() => {
    const tokens = tokenize(query);
    const scores = new Map<string, number>();
    if (tokens.length > 0) {
      for (const [id, entry] of index) {
        const s = scoreEntry(entry, tokens);
        if (s > 0) scores.set(id, s);
      }
    }
    return { active: tokens.length > 0, tokens, scores };
  }, [index, query]);
}
