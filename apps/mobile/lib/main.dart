import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'services/offline_dictionary.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  ApiClient.token = prefs.getString('access_token');
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: ApiClient.token == null || ApiClient.token!.isEmpty
          ? const LoginPage()
          : const HomePage(),
    );
  }
}
