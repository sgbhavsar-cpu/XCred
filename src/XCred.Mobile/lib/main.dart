import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  // cryptography_flutter registers itself as a plugin and routes Pbkdf2/AesGcm (used
  // throughout CryptoService) through native platform implementations automatically —
  // see Sprint 0.2's PBKDF2 performance measurement for why this matters at 600k
  // iterations. No explicit enable() call needed as of cryptography_flutter 2.x.
  runApp(const ProviderScope(child: XCredApp()));
}

class XCredApp extends ConsumerWidget {
  const XCredApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'XCred',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
