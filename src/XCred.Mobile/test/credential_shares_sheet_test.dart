import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xcred_mobile/core/models/share_models.dart';
import 'package:xcred_mobile/core/providers/share_providers.dart';
import 'package:xcred_mobile/core/vault/shares_repository.dart';
import 'package:xcred_mobile/features/credentials/widgets/credential_shares_sheet.dart';

SharedCredentialSummary _share(String id, String user, {DateTime? expiresAt, bool untilChanged = false}) =>
    SharedCredentialSummary(
      id: id,
      credentialId: 'c1',
      encryptedData: '',
      dataIv: '',
      encryptedCredentialKey: '',
      credentialType: 'WebsiteLogin',
      sharedByUsername: 'me',
      sharedWithUserId: 'u-$id',
      sharedWithUsername: user,
      expiresAt: expiresAt,
      untilChanged: untilChanged,
      createdAt: DateTime(2026, 10, 1),
      isRevoked: false,
    );

class _FakeRepo implements SharesRepository {
  final List<String> revoked = [];
  final List<({String id, DateTime? expiresAt, bool untilChanged})> updates = [];

  @override
  Future<void> revoke(String shareId) async => revoked.add(shareId);

  @override
  Future<void> update(String shareId, {DateTime? expiresAt, required bool untilChanged}) async =>
      updates.add((id: shareId, expiresAt: expiresAt, untilChanged: untilChanged));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeIndex extends SharesByCredentialNotifier {
  _FakeIndex(this.initial, this.repo);
  final List<SharedCredentialSummary> initial;
  final _FakeRepo repo;

  @override
  Future<Map<String, List<SharedCredentialSummary>>> build() async => {
        'c1': [for (final s in initial) if (!repo.revoked.contains(s.id)) s],
      };
}

Future<_FakeRepo> _open(WidgetTester tester, List<SharedCredentialSummary> shares) async {
  final repo = _FakeRepo();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharesRepositoryProvider.overrideWithValue(repo),
      sharesByCredentialProvider.overrideWith(() => _FakeIndex(shares, repo)),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showCredentialSharesSheet(context, credentialId: 'c1', credentialName: 'Corporate Portal'),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('lists every recipient with end date and the revoke-on-change flag', (tester) async {
    await _open(tester, [
      _share('s1', 'alice', expiresAt: DateTime(2031, 5, 17), untilChanged: true),
      _share('s2', 'bob'),
    ]);
    expect(find.text('Corporate Portal'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('Ends 2031-05-17'), findsOneWidget);
    expect(find.text('No end date'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('share_switch_s1'))).value, isTrue);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('share_switch_s2'))).value, isFalse);
    expect(find.byKey(const ValueKey('stop_all')), findsOneWidget);
  });

  testWidgets('Save stays disabled until something changes, then sends the edited flag', (tester) async {
    final repo = await _open(tester, [_share('s1', 'alice')]);
    FilledButton save() => tester.widget<FilledButton>(find.byKey(const ValueKey('share_save_s1')));
    expect(save().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('share_switch_s1')));
    await tester.pump();
    expect(save().onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('share_save_s1')));
    await tester.pumpAndSettle();
    expect(repo.updates.single.id, 's1');
    expect(repo.updates.single.untilChanged, isTrue);
    expect(repo.updates.single.expiresAt, isNull);
  });

  testWidgets('Stop sharing asks first, then revokes just that person and shows the empty state when none are left', (tester) async {
    final repo = await _open(tester, [_share('s1', 'alice')]);
    await tester.tap(find.byKey(const ValueKey('share_stop_s1')));
    await tester.pumpAndSettle();
    expect(find.text('Stop sharing with alice? They lose access immediately.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.revoked, isEmpty);

    await tester.tap(find.byKey(const ValueKey('share_stop_s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Stop sharing'));
    await tester.pumpAndSettle();
    expect(repo.revoked, ['s1']);
    expect(find.text('This credential is not shared with anyone.'), findsOneWidget);
  });
}
