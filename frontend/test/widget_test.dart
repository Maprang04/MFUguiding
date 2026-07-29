import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mfuguide/main.dart';

void main() {
  testWidgets('home screen presents the primary navigation action', (
    WidgetTester tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('MFU'), findsOneWidget);
    expect(find.text('SmartGuide'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });
}
