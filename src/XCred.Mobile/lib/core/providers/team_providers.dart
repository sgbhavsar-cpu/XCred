import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/team_models.dart';
import '../vault/teams_repository.dart';
import 'core_providers.dart';

final teamsRepositoryProvider = Provider<TeamsRepository>((ref) {
  return TeamsRepository(ref.watch(apiClientProvider));
});

/// MOB-TEAM-01 — no offline cache (metadata, re-fetched on every visit), matching
/// folderTreeProvider/tagListProvider's reasoning.
class TeamsNotifier extends AsyncNotifier<List<TeamSummary>> {
  @override
  Future<List<TeamSummary>> build() => ref.read(teamsRepositoryProvider).getAll();

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final teamsProvider = AsyncNotifierProvider<TeamsNotifier, List<TeamSummary>>(TeamsNotifier.new);
