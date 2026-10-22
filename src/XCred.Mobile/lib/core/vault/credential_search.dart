// Ported from src/XCred.Web/src/lib/search.ts — keep in sync. Search model:
//  - substring ("contains") match, case-insensitive, never "starts with"
//  - the query is split on whitespace; a credential matches when ANY word is found, in any
//    field, in any order ("Sachin Office" = contains 'sachin' OR contains 'office')
//  - results rank by how many words matched (then by how many matched in the name)
//  - never searches secrets: password-type fields, fields flagged noSearch (card numbers,
//    private keys, recovery codes, …), hidden custom fields and every account row's password
// Credential data is end-to-end encrypted, so this runs on the device over decrypted data.
import 'dart:convert';

import 'accounts.dart';
import 'credential_fields.dart';
import 'credential_type_meta.dart';

const String _sep = '\u0001'; // stops a word matching across two neighbouring values

class SearchEntry {
  final String hay;
  final String name;
  const SearchEntry(this.hay, this.name);
}

List<String> tokenizeQuery(String query) => query
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty)
    .toSet()
    .toList();

List<String> _listItems(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final parsed = jsonDecode(raw);
    return parsed is List ? parsed.map((e) => e.toString()).toList() : [raw];
  } catch (_) {
    return [raw];
  }
}

/// Lowercased searchable text for one credential.
SearchEntry buildSearchEntry({
  required String type,
  required String name,
  required Iterable<String> tagNames,
  required Map<String, dynamic>? fields,
}) {
  final parts = <String>[name, credentialTypeLabel(type)];
  if (fields != null) {
    for (final def in kCredentialFields[type] ?? const <FieldDef>[]) {
      if (def.type == 'password' || def.noSearch) continue;
      if (def.type == 'accounts') {
        for (final a in readAccounts(fields)) {
          parts
            ..add(a.label)
            ..add(a.username);
        }
      } else if (def.type == 'list') {
        parts.addAll(_listItems(fields[def.key]?.toString()));
      } else {
        parts.add((fields[def.key] ?? '').toString());
      }
    }
    parts.add((fields['notes'] ?? '').toString());
    try {
      final custom = jsonDecode((fields['customFields'] ?? '[]').toString());
      if (custom is List) {
        for (final cf in custom) {
          if (cf is! Map || cf['fieldType'] == 'password') continue;
          parts
            ..add((cf['label'] ?? '').toString())
            ..add((cf['value'] ?? '').toString());
        }
      }
    } catch (_) {
      // malformed custom fields: skip them
    }
  }
  parts.addAll(tagNames);
  return SearchEntry(parts.join(_sep).toLowerCase(), name.toLowerCase());
}

/// Rank score (0 = no match): matched words dominate, name hits break ties.
int scoreSearchText(String hay, String name, List<String> tokens) {
  var matched = 0;
  var inName = 0;
  for (final t in tokens) {
    if (hay.contains(t)) {
      matched++;
      if (name.contains(t)) inName++;
    }
  }
  return matched == 0 ? 0 : matched * 100 + inName;
}

/// True when any word is contained in the name (folder and credential-group names).
bool searchNameMatches(String name, List<String> tokens) {
  if (tokens.isEmpty) return false;
  final n = name.toLowerCase();
  return tokens.any(n.contains);
}
