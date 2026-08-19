import 'package:flutter_test/flutter_test.dart';
import 'package:xcred_mobile/core/models/credential_models.dart';
import 'package:xcred_mobile/core/vault/credential_csv.dart';

CredentialListItem _cred({
  required String id,
  String type = 'WebsiteLogin',
  DateTime? expiryDate,
  List<TagRef> tags = const [],
}) =>
    CredentialListItem(
      id: id,
      type: type,
      encryptedData: 'x',
      dataIv: 'x',
      encryptedCredentialKey: 'x',
      expiryDate: expiryDate,
      ownerId: 'owner',
      ownerUsername: 'owner',
      isShared: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 8, 15),
      tags: tags,
    );

void main() {
  test('buildCredentialsCsv produces the expected header and rows, and omits password values', () {
    final items = [
      _cred(id: '1', tags: [const TagRef(id: 't1', name: 'Work', color: '#fff')]),
      _cred(id: '2', type: 'Generic'),
    ];
    final decrypted = {
      '1': const DecryptedCredentialMeta(name: 'GitHub', subtitle: 'me@example.com', hasPassword: true),
      '2': const DecryptedCredentialMeta(name: 'Scratch Note', hasPassword: false),
    };

    final csv = buildCredentialsCsv(items, decrypted);
    final lines = csv.split('\r\n');

    expect(lines[0], 'Name,Type,Username,Tags,Has Password,Expiry Date,Last Updated');
    expect(lines[1], 'GitHub,Website Login,me@example.com,Work,Yes,,2026-08-15');
    expect(lines[2], 'Scratch Note,Generic,,,No,,2026-08-15');
    expect(csv, isNot(contains('S3cret')));
  });

  test('a comma or quote in a field is escaped RFC4180-style', () {
    final items = [_cred(id: '1')];
    final decrypted = {
      '1': const DecryptedCredentialMeta(name: 'Acme, Inc. "HQ"', hasPassword: true),
    };

    final csv = buildCredentialsCsv(items, decrypted);
    expect(csv, contains('"Acme, Inc. ""HQ"""'));
  });

  test('expiry date is included when set', () {
    final items = [_cred(id: '1', expiryDate: DateTime(2020, 1, 1))];
    final decrypted = {'1': const DecryptedCredentialMeta(name: 'Old Cert', hasPassword: true)};

    final csv = buildCredentialsCsv(items, decrypted);
    expect(csv, contains('2020-01-01'));
  });
}
