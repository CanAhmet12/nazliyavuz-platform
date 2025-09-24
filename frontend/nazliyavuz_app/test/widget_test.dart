import 'package:flutter_test/flutter_test.dart';

import 'package:nazliyavuz_app/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NazliyavuzApp());

    // Verify that our app loads
    expect(find.byType(NazliyavuzApp), findsOneWidget);
  });
}
