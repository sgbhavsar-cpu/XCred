import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xcred_mobile/core/vault/accounts.dart';
import 'package:xcred_mobile/core/vault/credential_search.dart';
import 'package:xcred_mobile/core/vault/smart_links.dart';
import 'package:xcred_mobile/core/vault/credential_fields.dart';

SearchEntry _entry(String type, Map<String, dynamic> fields, {List<String> tags = const []}) =>
    buildSearchEntry(
      type: type,
      name: (fields['name'] ?? '').toString(),
      tagNames: tags,
      fields: fields,
    );

int _score(SearchEntry e, String query) =>
    scoreSearchText(e.hay, e.name, tokenizeQuery(query));

void main() {
  final win = <String, dynamic>{
    'name': 'Sachin Office DC',
    'notes': 'Primary domain controller',
    'customFields': jsonEncode([
      {'label': 'Rack', 'value': 'R12-U4', 'fieldType': 'text'},
      {'label': 'Vault', 'value': 'hunter2-secret', 'fieldType': 'password'},
    ]),
    'serverOrDomainName': 'contoso.local',
    'ipAddresses': jsonEncode(['10.2.8.214', '10.2.8.215']),
    'accounts': jsonEncode([
      {'label': 'Admin', 'username': 'administrator', 'password': 'P@ssw0rdZZ'},
    ]),
  };
  final e = _entry('WindowsServer', win, tags: ['Production']);

  group('search', () {
    test('contains, not starts-with', () => expect(_score(e, 'fice') > 0, isTrue));
    test('more matched words rank higher',
        () => expect(_score(e, 'office sachin') > _score(e, 'sachin zzz'), isTrue));
    test('OR semantics: one word is enough', () => expect(_score(e, 'zzz office') > 0, isTrue));
    test('matches IP list, account username/label, notes, custom field, tag, type label', () {
      for (final q in ['8.214', 'administrator', 'admin', 'domain controller', 'R12-U4', 'production', 'windows']) {
        expect(_score(e, q) > 0, isTrue, reason: q);
      }
    });
    test('secrets are never searchable', () {
      expect(_score(e, 'P@ssw0rdZZ'), 0);
      expect(_score(e, 'hunter2'), 0);
      final card = _entry('CreditCard', {
        'name': 'HDFC', 'cardNumber': '4111111111111111', 'cvv': '123', 'cardholderName': 'Sachin',
      });
      expect(_score(card, '4111'), 0);
      expect(_score(card, '123'), 0);
      expect(_score(card, 'sachin') > 0, isTrue);
    });
    test('folder/group names: any word contained', () {
      expect(searchNameMatches('Garrage Servers', tokenizeQuery('serv')), isTrue);
      expect(searchNameMatches('Garrage', tokenizeQuery('')), isFalse);
    });
  });

  group('accounts', () {
    test('legacy username/password surfaces as a Default row', () {
      final rows = readAccounts({'username': 'old', 'password': 'pw'});
      expect(rows.length, 1);
      expect(rows.first.label, 'Default');
    });
    test('saved accounts win over legacy keys, and empty list stays empty', () {
      expect(readAccounts({'accounts': '[]', 'username': 'old'}), isEmpty);
    });
    test('Linux server starts with RDP, Root, SSH', () {
      expect(defaultAccounts('LinuxServer').map((a) => a.label), ['RDP', 'Root', 'SSH']);
    });
    test('round-trips through JSON', () {
      final rows = parseAccounts(encodeAccounts(const [Account(label: 'SSH', username: 'u', password: 'p')]));
      expect(rows.single.password, 'p');
    });
    test('IPv4 validation', () {
      expect(isValidIPv4('192.168.1.10'), isTrue);
      expect(isValidIPv4('192.168.1.300'), isFalse);
      expect(isValidIPv4('server01'), isFalse);
    });
  });

  group('server links', () {
    final ip = kCredentialFields['LinuxServer']!.firstWhere((f) => f.key == 'ipAddresses');
    test('Linux IP opens ssh with the SSH account username', () {
      final link = listItemLink(ip, '10.0.0.5', {
        'accounts': encodeAccounts(const [Account(label: 'ssh', username: 'deploy')]),
      });
      expect(link, 'ssh://deploy@10.0.0.5');
    });
    test('Windows IP opens rdp', () {
      final wip = kCredentialFields['WindowsServer']!.firstWhere((f) => f.key == 'ipAddresses');
      expect(listItemLink(wip, '10.0.0.6', const {}), 'rdp://10.0.0.6');
    });
  });
}
