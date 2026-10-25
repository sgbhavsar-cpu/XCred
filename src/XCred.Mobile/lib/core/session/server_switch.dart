import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import 'session_actions.dart';

/// Makes [url] the active server.
///
/// Whatever is stored on the device belongs to the *previous* server — the signed-in session,
/// the biometric-wrapped key, the offline credential cache and any edits queued while offline —
/// and none of it is tagged with which server it came from. Leaving it in place would show one
/// server's credentials under another, or replay queued edits against the wrong server, so a
/// real switch wipes all of it first. Picking the server that is already active is a no-op.
Future<void> switchServer(WidgetRef ref, String url) async {
  final current = ref.read(serverBaseUrlProvider).value;
  if (current == url) return;
  await logOut(ref);
  await ref.read(databaseProvider).clearServerBoundData();
  await ref.read(serverBaseUrlProvider.notifier).set(url);
}
