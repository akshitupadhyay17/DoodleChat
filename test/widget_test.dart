import 'package:flutter_test/flutter_test.dart';
import 'package:doodle_chat/main.dart';

void main() {
  testWidgets('DoodleChatApp builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DoodleChatApp());
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(find.byType(DoodleChatApp), findsOneWidget);
  });
}
