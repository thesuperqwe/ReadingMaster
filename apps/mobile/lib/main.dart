import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'services/offline_dictionary.dart';
import 'theme/app_theme.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  ApiClient.token = prefs.getString('access_token');
  ApiClient.onUnauthorized = () async {
    ApiClient.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  };
  await OfflineDictionary.load();
  runApp(const ReadingMasterApp());
}

class ReadingMasterApp extends StatelessWidget {
  const ReadingMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReadingMaster（阅读王）',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: buildAppTheme(),
      home: ApiClient.token == null || ApiClient.token!.isEmpty
          ? const LoginPage()
          : const HomePage(),
    );
  }
}