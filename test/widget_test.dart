import 'package:flutter_test/flutter_test.dart';
import 'package:slati/main.dart';

void main() {
  testWidgets('App widget instantiation test', (WidgetTester tester) async {
    // Verify that SalatiQourbakApp is instantiated.
    const app = SalatiQourbakApp();
    expect(app, isNotNull);
  });
}
