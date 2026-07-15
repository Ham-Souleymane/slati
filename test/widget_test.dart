import 'package:flutter_test/flutter_test.dart';
import 'package:manbar_almasjid/main.dart';

void main() {
  testWidgets('App widget instantiation test', (WidgetTester tester) async {
    // Verify that SalatiQourbakApp is instantiated.
    const app = SalatiQourbakApp();
    expect(app, isNotNull);
  });
}
