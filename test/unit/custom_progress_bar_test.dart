import 'package:HPGM/components/custom_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CustomProgressBar maps temperature values to progress and colors', () {
    const bar = CustomProgressBar(value: 26);

    expect(bar.getValue(10), 0.15);
    expect(bar.getValue(26), 0.64);
    expect(bar.getValue(32), 0.74);
    expect(bar.getValue(40), 0.85);
    expect(bar.getFillColor(26), Colors.green);
    expect(const CustomProgressBar(value: 35).getFillColor(35), Colors.red);
  });
}
