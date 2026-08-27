import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readingmaster/core/api_client.dart';
import 'package:readingmaster/main.dart';

void main() {
  testWidgets('renders login page when there is no saved token', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.token = null;

    await tester.pumpWidget(const ReadingMasterApp());

    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });
}
