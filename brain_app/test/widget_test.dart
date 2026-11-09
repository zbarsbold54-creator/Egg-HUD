import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('EDITH app builds dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EdithApp()));
    expect(find.text('EDITH'), findsWidgets);
  });
}
