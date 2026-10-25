import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/server_check.dart';
import 'core_providers.dart';

/// One entry in the user's list of XCred servers ("Office", "Home lab", …).
class SavedServer {
  const SavedServer({required this.id, required this.name, required this.url});
  final String id;
  final String name;
  final String url;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url};

  factory SavedServer.fromJson(Map<String, dynamic> json) => SavedServer(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
      );

  SavedServer copyWith({String? name, String? url}) =>
      SavedServer(id: id, name: name ?? this.name, url: url ?? this.url);
}

/// Trims and drops trailing slashes so "https://a.com/" and "https://a.com" are one server.
String normalizeServerUrl(String raw) {
  var url = raw.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

/// A human-readable problem with [raw], or null when it looks like a usable server URL.
String? validateServerUrl(String raw) {
  final url = normalizeServerUrl(raw);
  if (url.isEmpty) return 'Enter a server URL.';
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
    return 'Start with http:// or https:// (e.g. https://vault.example.com).';
  }
  return null;
}

/// "vault.example.com" for a URL — the name used when the user doesn't type one.
String defaultServerName(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host.isEmpty ? url : host;
}

/// The saved server list, kept in secure storage as JSON (it isn't secret, but this is the
/// store the app already depends on). The server that is currently *active* lives in
/// [serverBaseUrlProvider] as before; on first load that URL is folded into this list so
/// existing installs don't lose their server.
class SavedServersNotifier extends AsyncNotifier<List<SavedServer>> {
  static const storageKey = 'saved_servers.v1';

  @override
  Future<List<SavedServer>> build() async {
    final storage = ref.read(secureStorageProvider);
    final servers = <SavedServer>[];
    try {
      final raw = await storage.read(key: storageKey);
      if (raw != null && raw.isNotEmpty) {
        for (final e in jsonDecode(raw) as List<dynamic>) {
          servers.add(SavedServer.fromJson(e as Map<String, dynamic>));
        }
      }
    } catch (_) {
      // A corrupt list shouldn't lock anyone out — start again from the active URL below.
    }

    final active = await ref.read(serverBaseUrlProvider.future);
    if (active != null && active.isNotEmpty && !servers.any((s) => s.url == active)) {
      servers.add(SavedServer(id: _newId(), name: defaultServerName(active), url: active));
      await _persist(servers);
    }
    return servers;
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _persist(List<SavedServer> servers) => ref
      .read(secureStorageProvider)
      .write(key: storageKey, value: jsonEncode([for (final s in servers) s.toJson()]));

  /// Adds a server, or updates one: by [id] when editing, else by matching URL (so saving the
  /// same address twice renames rather than duplicates). A blank [name] falls back to the host.
  Future<SavedServer> upsert({String? id, required String name, required String url}) async {
    final list = [...(state.value ?? await future)];
    final cleanUrl = normalizeServerUrl(url);
    final cleanName = name.trim().isEmpty ? defaultServerName(cleanUrl) : name.trim();

    var index = id == null ? -1 : list.indexWhere((s) => s.id == id);
    if (index < 0) index = list.indexWhere((s) => s.url == cleanUrl);

    final SavedServer saved;
    if (index >= 0) {
      saved = list[index].copyWith(name: cleanName, url: cleanUrl);
      list[index] = saved;
    } else {
      saved = SavedServer(id: _newId(), name: cleanName, url: cleanUrl);
      list.add(saved);
    }
    await _persist(list);
    state = AsyncData(list);
    return saved;
  }

  Future<void> remove(String id) async {
    final list = [...(state.value ?? await future)]..removeWhere((s) => s.id == id);
    await _persist(list);
    state = AsyncData(list);
  }
}

final savedServersProvider =
    AsyncNotifierProvider<SavedServersNotifier, List<SavedServer>>(SavedServersNotifier.new);

/// The saved entry for the active URL (to show its friendly name), if there is one.
final activeServerProvider = Provider<SavedServer?>((ref) {
  final url = ref.watch(serverBaseUrlProvider).value;
  final servers = ref.watch(savedServersProvider).value;
  if (url == null || servers == null) return null;
  for (final s in servers) {
    if (s.url == url) return s;
  }
  return null;
});

/// How a URL is verified before it is saved - overridable so tests don't need a network.
final serverCheckProvider = Provider<Future<bool> Function(String url)>((ref) => isXCredServer);
