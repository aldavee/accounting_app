import 'package:accounting_app/features/accounting/presentation/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('HomeScreen renders Accounting App and Accounting Equation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accounting App'), findsOneWidget);
    expect(find.text('Fundamental Accounting Equation'), findsOneWidget);
    expect(find.text('Total Assets'), findsOneWidget);
  });
}
