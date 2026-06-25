import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendConfig {
  static String? _cachedBaseUrl;

  static final List<String> _baseUrlsToTry = [
    'http://192.168.0.104:5000', // Host PC's active IP
    'http://10.0.2.2:5000',       // Android emulator loopback
    'http://127.0.0.1:5000',      // Localhost/Simulator/Desktop
  ];

  static Future<String> getBaseUrl() async {
    if (_cachedBaseUrl != null) {
      return _cachedBaseUrl!;
    }

    if (kIsWeb) {
      _cachedBaseUrl = 'http://127.0.0.1:5000';
      return _cachedBaseUrl!;
    }

    for (var baseUrl in _baseUrlsToTry) {
      try {
        await http
            .get(Uri.parse(baseUrl))
            .timeout(const Duration(milliseconds: 500));
        // If we get any HTTP response (even a 404 or 405), the server is active and reachable
        _cachedBaseUrl = baseUrl;
        debugPrint('BackendConfig: Resolved server URL to $baseUrl');
        return baseUrl;
      } catch (e) {
        debugPrint('BackendConfig: $baseUrl is unreachable: $e');
      }
    }

    // Default fallback if everything fails
    debugPrint('BackendConfig: All candidate URLs failed. Falling back to default ${_baseUrlsToTry.first}');
    return _baseUrlsToTry.first;
  }

  // Helper method to clear cache (e.g. for retrying)
  static void clearCache() {
    _cachedBaseUrl = null;
  }

  /// Runs [attempt] against the current base URL. If it throws (connection
  /// refused, timeout, dropped Wi-Fi, etc.), clears the cache and retries
  /// [attempt] once more against a freshly re-discovered URL before giving
  /// up. This is what makes a stale cached URL (e.g. after the phone briefly
  /// drops Wi-Fi) self-heal within the same action instead of requiring the
  /// next screen/message to trigger rediscovery.
  static Future<T> withRetry<T>(Future<T> Function(String baseUrl) attempt) async {
    final String firstUrl = await getBaseUrl();
    try {
      return await attempt(firstUrl);
    } catch (e) {
      debugPrint('BackendConfig: request to $firstUrl failed ($e), clearing cache and retrying once.');
      clearCache();
      final String retryUrl = await getBaseUrl();
      return await attempt(retryUrl);
    }
  }
}
