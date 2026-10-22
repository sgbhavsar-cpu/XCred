// Ported from src/XCred.Web/src/lib/bulk.ts — keep in sync. Pure helpers behind the Bulk Edit
// sheet: they work on the decrypted payload of ONE credential (notes is a plain string,
// customFields is a JSON string) so the same change can be applied to every selected one.
import 'dart:convert';

enum NotesMode { replace, append, prepend, clear }

class NotesChange {
  final NotesMode mode;
  final String text;
  const NotesChange(this.mode, [this.text = '']);
}

/// `remove == false` updates the field with that label (case-insensitive) or adds it when
/// missing; `remove == true` deletes any field with that label.
class CustomFieldOp {
  final bool remove;
  final String label;
  final String value;
  final String fieldType; // text | password | url
  const CustomFieldOp.set(this.label, this.value, this.fieldType) : remove = false;
  const CustomFieldOp.remove(this.label)
      : remove = true,
        value = '',
        fieldType = 'text';
}

enum ExpiryMode { set, clear, extend }

class ExpiryChange {
  final ExpiryMode mode;
  final String? date; // YYYY-MM-DD, for ExpiryMode.set
  final int days; // for ExpiryMode.extend (negative shortens)
  const ExpiryChange.set(String this.date)
      : mode = ExpiryMode.set,
        days = 0;
  const ExpiryChange.clear()
      : mode = ExpiryMode.clear,
        date = null,
        days = 0;
  const ExpiryChange.extend(this.days)
      : mode = ExpiryMode.extend,
        date = null;
}

class BulkEditChanges {
  final bool updateFolder;
  final String? folderId;
  final bool updateGroup;
  final String? groupId;
  final ExpiryChange? expiry;
  final List<String> addTagIds;
  final List<String> removeTagIds;
  final NotesChange? notes;
  final List<CustomFieldOp> customFields;

  const BulkEditChanges({
    this.updateFolder = false,
    this.folderId,
    this.updateGroup = false,
    this.groupId,
    this.expiry,
    this.addTagIds = const [],
    this.removeTagIds = const [],
    this.notes,
    this.customFields = const [],
  });

  bool get hasDataChange => notes != null || customFields.isNotEmpty;
  bool get hasTagChange => addTagIds.isNotEmpty || removeTagIds.isNotEmpty;
  bool get hasAnyChange =>
      updateFolder || updateGroup || expiry != null || hasTagChange || hasDataChange;
}

String applyNotes(String? existing, NotesChange change) {
  final cur = existing ?? '';
  switch (change.mode) {
    case NotesMode.clear:
      return '';
    case NotesMode.replace:
      return change.text;
    case NotesMode.append:
      return cur.isEmpty ? change.text : '$cur\n${change.text}';
    case NotesMode.prepend:
      return cur.isEmpty ? change.text : '${change.text}\n$cur';
  }
}

List<Map<String, dynamic>> _parseCustomFields(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final parsed = jsonDecode(raw);
    return parsed is List ? parsed.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : [];
  } catch (_) {
    return [];
  }
}

/// Returns the new customFields JSON string.
String applyCustomFieldOps(String? raw, List<CustomFieldOp> ops) {
  var fields = _parseCustomFields(raw);
  for (final op in ops) {
    final key = op.label.trim().toLowerCase();
    if (key.isEmpty) continue;
    bool sameLabel(Map<String, dynamic> f) => (f['label'] ?? '').toString().trim().toLowerCase() == key;
    if (op.remove) {
      fields = fields.where((f) => !sameLabel(f)).toList();
    } else {
      final idx = fields.indexWhere(sameLabel);
      if (idx >= 0) {
        fields[idx] = {...fields[idx], 'value': op.value, 'fieldType': op.fieldType};
      } else {
        fields.add({'label': op.label.trim(), 'value': op.value, 'fieldType': op.fieldType});
      }
    }
  }
  return jsonEncode(fields);
}

/// Applies the notes / custom-field part of a bulk edit to one decrypted payload.
Map<String, dynamic> applyDataChanges(Map<String, dynamic> payload, BulkEditChanges changes) {
  final out = Map<String, dynamic>.from(payload);
  if (changes.notes != null) out['notes'] = applyNotes(out['notes'] as String?, changes.notes!);
  if (changes.customFields.isNotEmpty) {
    out['customFields'] = applyCustomFieldOps(out['customFields'] as String?, changes.customFields);
  }
  return out;
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// New expiry (YYYY-MM-DD) for one credential, or null to clear it.
String? nextExpiry(DateTime? current, ExpiryChange change, {DateTime? today}) {
  switch (change.mode) {
    case ExpiryMode.clear:
      return null;
    case ExpiryMode.set:
      return change.date;
    case ExpiryMode.extend:
      final base = current ?? today ?? DateTime.now();
      return _ymd(DateTime.utc(base.year, base.month, base.day + change.days));
  }
}
