import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vault/backup_repository.dart';
import '../vault/settings_repository.dart';
import 'core_providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(apiClientProvider));
});

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository(ref.watch(apiClientProvider), ref.watch(dioProvider));
});
