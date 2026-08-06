import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sou9ix/main_admin.dart';

void main() {
  testWidgets('Admin app boots to the splash screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: Sou9ixAdminApp()));
    await tester.pump();

    expect(find.text('Sou9ix'), findsOneWidget);

    // The splash screen auto-navigates after a fixed delay, and the screen
    // it lands on mounts its own flutter_animate entrance animations —
    // settle all of that so the test binding doesn't see anything still
    // pending on teardown.
    await tester.pumpAndSettle(const Duration(milliseconds: 2000));
  });
}
