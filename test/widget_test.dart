import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sou9ix/main.dart';

void main() {
  testWidgets('App boots to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: Sou9ixApp()));
    await tester.pump();

    expect(find.text('Sou9ix'), findsOneWidget);
  });
}
