// Ported from src/XCred.Web/src/lib/accounts.ts — keep in sync. A server credential
// (Windows Server / Linux Server) stores its logins as a JSON array in the `accounts`
// field of the encrypted payload.
import 'dart:convert';

class Account {
  final String label;
  final String username;
  final String password;
  const Account({this.label = '', this.username = '', this.password = ''});

  Map<String, String> toJson() => {'label': label, 'username': username, 'password': password};
}

const String kAccountsKey = 'accounts';

/// Rows a brand-new credential of this type starts with; the user can edit, delete or add.
List<Account> defaultAccounts(String type) {
  switch (type) {
    case 'LinuxServer':
      return const [Account(label: 'RDP'), Account(label: 'Root'), Account(label: 'SSH')];
    case 'WindowsServer':
      return const [Account(label: 'Administrator')];
    default:
      return const [];
  }
}

List<Account> parseAccounts(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final parsed = jsonDecode(raw);
    if (parsed is! List) return const [];
    return parsed.map((e) {
      final m = e is Map ? e : const {};
      return Account(
        label: (m['label'] ?? '').toString(),
        username: (m['username'] ?? '').toString(),
        password: (m['password'] ?? '').toString(),
      );
    }).toList();
  } catch (_) {
    return const [];
  }
}

/// Reads the account rows from a decrypted payload. Windows Server entries saved before
/// accounts existed carry single `username`/`password` fields; those surface as a first
/// "Default" row and are written back in the new shape the next time the credential is
/// saved (no bulk migration).
List<Account> readAccounts(Map<String, dynamic>? fields) {
  if (fields == null) return const [];
  final rows = parseAccounts(fields[kAccountsKey]?.toString());
  if (rows.isNotEmpty || fields.containsKey(kAccountsKey)) return rows;
  final username = (fields['username'] ?? '').toString();
  final password = (fields['password'] ?? '').toString();
  return (username.isNotEmpty || password.isNotEmpty)
      ? [Account(label: 'Default', username: username, password: password)]
      : const [];
}

String encodeAccounts(Iterable<Account> accounts) =>
    jsonEncode(accounts.map((a) => a.toJson()).toList());

final RegExp _ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

/// Strict dotted-quad check (four 0–255 parts). Used only for a non-blocking warning.
bool isValidIPv4(String value) {
  final m = _ipv4.firstMatch(value.trim());
  if (m == null) return false;
  for (var i = 1; i <= 4; i++) {
    if (int.parse(m.group(i)!) > 255) return false;
  }
  return true;
}
