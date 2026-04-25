import 'package:HPGM/components/pop_up.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('popup message helpers return expected threshold messages', () {
    expect(determineMessage(null), 'No data available');
    expect(determineMessage(10), contains('Low'));
    expect(determineMessage(25), contains('Moderate'));
    expect(determineMessage(35), contains('High'));

    expect(determineHoneyMessage(null), 'No data available');
    expect(determineHoneyMessage(10), contains('Low'));
    expect(determineHoneyMessage(35), contains('Moderate'));
    expect(determineHoneyMessage(80), contains('High'));
  });
}
