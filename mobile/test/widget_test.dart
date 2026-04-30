import 'package:flutter_test/flutter_test.dart';
import 'package:zakupy_mobile/app.dart';

void main() {
  test('Zakupy themes keep Material 3 enabled', () {
    expect(buildLightTheme().useMaterial3, isTrue);
    expect(buildDarkTheme().useMaterial3, isTrue);
  });
}
