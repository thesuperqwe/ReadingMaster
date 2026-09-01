import 'package:shared_preferences/shared_preferences.dart';

class ParentPin {
  ParentPin._();

  static const _key = 'parent_pin';
  static const defaultPin = '1234';

  static Future<String> get() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? defaultPin;
  }

  static Future<void> set(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, pin);
  }
}