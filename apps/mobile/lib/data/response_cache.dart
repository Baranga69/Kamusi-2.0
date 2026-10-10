import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A bounded, on-disk cache of raw API responses.
///
/// A dictionary is read far more often than it changes, and the people Kamusi
/// is for do not always have a connection or data to spare. Caching the exact
/// JSON the API returned means a word that has been opened once stays
/// readable offline, and re-opening it costs nothing.
///
/// Raw responses rather than serialised models, deliberately: the models only
/// parse one way, and storing what the server actually said keeps the cache
/// honest if the parsing changes.
///
/// Entries are evicted least-recently-used once [maxEntries] is reached, so a
/// long-running install cannot grow without bound. `shared_preferences` is
/// enough at this size; a full offline corpus would want sqflite with FTS.
class ResponseCache {
  ResponseCache({this.maxEntries = 250, this.namespace = 'kamusi_cache'});

  final int maxEntries;
  final String namespace;

  String _entryKey(String key) => '$namespace:entry:$key';
  String get _indexKey => '$namespace:index';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Keys in least-recently-used order.
  Future<List<String>> _index(SharedPreferences prefs) async =>
      prefs.getStringList(_indexKey) ?? <String>[];

  Future<void> write(String key, Object? body) async {
    final prefs = await _prefs;
    final payload = jsonEncode({
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'body': body,
    });

    await prefs.setString(_entryKey(key), payload);

    final index = await _index(prefs)
      ..remove(key)
      ..add(key);
    while (index.length > maxEntries) {
      final evicted = index.removeAt(0);
      await prefs.remove(_entryKey(evicted));
    }
    await prefs.setStringList(_indexKey, index);
  }

  /// The cached body, or null when nothing is stored for [key].
  Future<CachedResponse?> read(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_entryKey(key));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      // A entry written by an older, incompatible version: drop it rather
      // than failing the read.
      await prefs.remove(_entryKey(key));
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    // Touch it so the eviction order reflects real use.
    final index = await _index(prefs);
    if (index.remove(key)) {
      index.add(key);
      await prefs.setStringList(_indexKey, index);
    }

    return CachedResponse(
      body: decoded['body'],
      savedAt: DateTime.tryParse(decoded['saved_at']?.toString() ?? ''),
    );
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    for (final key in await _index(prefs)) {
      await prefs.remove(_entryKey(key));
    }
    await prefs.remove(_indexKey);
  }

  Future<int> size() async => (await _index(await _prefs)).length;
}

class CachedResponse {
  const CachedResponse({required this.body, this.savedAt});

  final Object? body;
  final DateTime? savedAt;
}
