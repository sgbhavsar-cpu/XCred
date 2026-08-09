// Sprint 0.1 smoke test: app boots, ProviderScope + go_router resolve, and with no
// server configured yet, the redirect guard in core/router/app_router.dart lands on
// the Server Setup screen (proof go_router's redirect logic actually runs at startup).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xcred_mobile/main.dart';

void main() {
  testWidgets('App boots to Server Setup when no server is configured', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: XCredApp()));
    await tester.pumpAndSettle();

    expect(find.text('XCred'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Server URL'), findsOneWidget);
  });
}
