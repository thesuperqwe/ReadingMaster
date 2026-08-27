import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/models.dart';

class OfflineDictionary {
  OfflineDictionary._();

  static final Map<String, Word> _entries = {};

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/offline_dictionary.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;

    _entries.clear();
    for (final entry in data.entries) {
      final word = Word.fromJson(entry.value as Map<String, dynamic>);
      _entries[word.word.toLowerCase()] = word;
    }
  }

  static Word? lookup(String text) {
    return _entries[text.trim().toLowerCase()];
  }
}
