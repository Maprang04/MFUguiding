import 'package:flutter_test/flutter_test.dart';

import 'package:mfuguide/main.dart';

void main() {
  testWidgets('home screen presents the primary navigation action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('MFU'), findsOneWidget);
    expect(find.text('SmartGuide'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });
}
