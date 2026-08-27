import 'package:flutter_test/flutter_test.dart';

import 'package:readingmaster/main.dart';

void main() {
  testWidgets('renders ReadingMaster placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const ReadingMasterApp());

    expect(find.text('ReadingMaster（阅读王）'), findsOneWidget);
    expect(find.textContaining('MVP Web 占位页'), findsOneWidget);
  });
}
