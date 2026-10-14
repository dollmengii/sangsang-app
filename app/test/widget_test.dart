import 'package:flutter_test/flutter_test.dart';
import 'package:sangsang/core/env.dart';

void main() {
  test('설정 값이 없으면 isConfigured 는 false', () {
    expect(Env.isConfigured, isFalse);
  });
}
