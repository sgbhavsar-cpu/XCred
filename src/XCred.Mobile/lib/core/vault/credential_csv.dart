import '../models/credential_models.dart';
import 'credential_type_meta.dart';

String _csvEscape(String value) {
  if (value.contains(RegExp(r'[",\n]'))) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Mirrors the web app's lib/csv.ts buildCredentialsCsv — a metadata/audit summary, not a
/// secrets dump: actual password *values* are never included (only whether one's set),
/// since this ends up as a plain-text file handed off through the OS share sheet. Someone
/// who genuinely wants every decrypted field belongs at Settings' "Export All as Plain
/// JSON" instead, which already carries that warning.
String buildCredentialsCsv(
  List<CredentialListItem> items,
  Map<String, DecryptedCredentialMeta> decrypted,
) {
  final rows = <List<String>>[
    ['Name', 'Type', 'Username', 'Tags', 'Has Password', 'Expiry Date', 'Last Updated'],
  ];
  for (final c in items) {
    final meta = decrypted[c.id];
    rows.add([
      meta?.name ?? credentialTypeLabel(c.type),
      credentialTypeLabel(c.type),
      meta?.subtitle ?? '',
      c.tags.map((t) => t.name).join('; '),
      (meta?.hasPassword ?? true) ? 'Yes' : 'No',
      c.expiryDate != null ? _formatDate(c.expiryDate!) : '',
      _formatDate(c.updatedAt),
    ]);
  }
  return rows.map((r) => r.map(_csvEscape).join(',')).join('\r\n');
}
