import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:you_wouldnt_steal_a_lawnmower/main.dart';

void main() {
  test('LawnmowerApp can be created', () {
    const app = LawnmowerApp();

    expect(app, isA<StatelessWidget>());
  });
}
