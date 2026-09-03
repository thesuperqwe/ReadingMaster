import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _envBase = String.fromEnvironment('API_BASE_URL');

  /// Base URL for API requests.
  ///
  /// Priority:
  /// 1. `API_BASE_URL` passed via `--dart-define`.
  /// 2. Web: the origin the app is served from, so a single tunnel/proxy that
  ///    also routes `/api/*` to the backend works for phones and tablets.
  /// 3. Non-web: `http://localhost:8000`.
  static String get apiBaseUrl {
    if (_envBase.isNotEmpty) return _envBase;
    if (kIsWeb) return Uri.base.origin;
    return 'http://localhost:8000';
  }
}
