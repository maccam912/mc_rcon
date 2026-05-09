import 'package:flutter_test/flutter_test.dart';

import 'package:mc_rcon/main.dart';

void main() {
  testWidgets('App loads connection screen', (WidgetTester tester) async {
    await tester.pumpWidget(const McRconApp());
    await tester.pumpAndSettle();

    // Verify the connection screen loads with the app title
    expect(find.text('MC RCON'), findsOneWidget);
  });
}
