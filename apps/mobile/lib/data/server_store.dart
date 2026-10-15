import 'package:shared_preferences/shared_preferences.dart';

/// Where the app should look for the API.
///
/// The address was fixed at build time by `--dart-define=API_BASE_URL`, which
/// is right for a release and useless on a home network: a laptop's IP moves
/// whenever the router feels like it, and every move meant rebuilding the app
/// to type a different number. Storing an override means the person holding
/// the phone can fix it in ten seconds.
///
/// The build-time value stays the default, so a fresh install still points
/// somewhere sensible and clearing the override returns to it.
class ServerStore {
  ServerStore({this.namespace = 'kamusi_server'});

  final String namespace;

  String get _key => '$namespace:base_url';

  /// The stored address, or null when none has been set.
  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  Future<void> save(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, normalise(baseUrl));
  }

  /// Forget the override and fall back to the build-time address.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Tidy what someone typed into something Dio can use.
  ///
  /// People type "192.168.1.5:8000" and expect it to work, so a missing
  /// scheme is assumed rather than rejected. A trailing slash is dropped
  /// because every path in the client already starts with one.
  static String normalise(String input) {
    var value = input.trim();
    if (value.isEmpty) {
      return value;
    }
    if (!value.contains('://')) {
      value = 'http://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  /// Whether this could be an API address. Deliberately forgiving: the only
  /// real test is whether it answers, which the settings screen does for
  /// real rather than guessing from the text.
  static bool looksUsable(String input) {
    final uri = Uri.tryParse(normalise(input));
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}
