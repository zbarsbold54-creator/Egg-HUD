import 'package:flutter_test/flutter_test.dart';

bool isReset(int lastSeq, int seq) {
  if (seq > lastSeq) return false;
  if (seq <= 4 && (lastSeq - seq) >= 3) return true;
  if ((lastSeq - seq) > 100) return true;
  return false;
}

void main() {
  test('40 -> 1 is reset (seq<=4, jump 39>=3)', () {
    expect(isReset(40, 1), true);
  });
  test('3 -> 2 is NOT reset (jump 1 < 3)', () {
    expect(isReset(3, 2), false);
  });
  test('5 -> 5 is duplicate, rejected', () {
    expect(isReset(5, 5), false);
  });
  test('1000 -> 0 is reset (large jump)', () {
    expect(isReset(1000, 0), true);
  });
}
