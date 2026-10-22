import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xcred_mobile/core/vault/bulk_edit.dart';

void main() {
  group('notes', () {
    test('replace / append / prepend / clear', () {
      expect(applyNotes('old', const NotesChange(NotesMode.replace, 'new')), 'new');
      expect(applyNotes('old', const NotesChange(NotesMode.append, 'more')), 'old\nmore');
      expect(applyNotes('', const NotesChange(NotesMode.append, 'more')), 'more');
      expect(applyNotes('old', const NotesChange(NotesMode.prepend, 'top')), 'top\nold');
      expect(applyNotes(null, const NotesChange(NotesMode.clear)), '');
    });
  });

  group('custom fields', () {
    final cf = jsonEncode([
      {'label': 'Rack', 'value': 'R1', 'fieldType': 'text'},
      {'label': 'Vault', 'value': 's', 'fieldType': 'password'},
    ]);
    List<dynamic> run(String? raw, List<CustomFieldOp> ops) => jsonDecode(applyCustomFieldOps(raw, ops)) as List<dynamic>;

    test('set updates an existing label case-insensitively and keeps its original label', () {
      final out = run(cf, const [CustomFieldOp.set('rack', 'R9', 'text')]);
      expect(out.first, {'label': 'Rack', 'value': 'R9', 'fieldType': 'text'});
      expect(out.length, 2);
    });
    test('set adds a missing field', () {
      expect(run(cf, const [CustomFieldOp.set('Owner', 'IT', 'text')]).length, 3);
    });
    test('remove by label', () {
      expect(run(cf, const [CustomFieldOp.remove('VAULT')]).map((f) => f['label']), ['Rack']);
    });
    test('works with no / malformed existing custom fields', () {
      expect(run(null, const [CustomFieldOp.set('A', '1', 'url')]).single['label'], 'A');
      expect(run('not json', const [CustomFieldOp.remove('x')]), isEmpty);
    });
    test('only notes/customFields change; other payload fields are untouched', () {
      final out = applyDataChanges(
        {'name': 'N', 'notes': 'a', 'password': 'keep'},
        const BulkEditChanges(notes: NotesChange(NotesMode.append, 'b')),
      );
      expect(out, {'name': 'N', 'notes': 'a\nb', 'password': 'keep'});
    });
  });

  group('expiry', () {
    test('extend from the credential\'s own expiry (month rollover) and from today when none', () {
      expect(nextExpiry(DateTime(2026, 1, 31), const ExpiryChange.extend(30)), '2026-03-02');
      expect(nextExpiry(null, const ExpiryChange.extend(10), today: DateTime(2026, 10, 23)), '2026-11-02');
      expect(nextExpiry(DateTime(2026, 5, 1), const ExpiryChange.extend(-1)), '2026-04-30');
    });
    test('set and clear', () {
      expect(nextExpiry(DateTime(2026, 5, 1), const ExpiryChange.set('2030-01-01')), '2030-01-01');
      expect(nextExpiry(DateTime(2026, 5, 1), const ExpiryChange.clear()), isNull);
    });
  });

  test('hasAnyChange', () {
    expect(const BulkEditChanges().hasAnyChange, isFalse);
    expect(const BulkEditChanges(notes: NotesChange(NotesMode.clear)).hasAnyChange, isTrue);
    expect(const BulkEditChanges(addTagIds: ['t']).hasAnyChange, isTrue);
    expect(const BulkEditChanges(updateFolder: true).hasAnyChange, isTrue);
  });
}
