import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/core/services/foreground_service.dart';

void main() {
  test('type set: connectedDevice always', () {
    expect(computeTypeSet(micGranted: false, locationGranted: false), {'connectedDevice'});
  });
  test('type set: +microphone when mic granted', () {
    expect(computeTypeSet(micGranted: true, locationGranted: false), {'connectedDevice', 'microphone'});
  });
  test('type set: +location when location granted', () {
    expect(computeTypeSet(micGranted: false, locationGranted: true), {'connectedDevice', 'location'});
  });
  test('type set: all three when both granted', () {
    expect(computeTypeSet(micGranted: true, locationGranted: true), {'connectedDevice', 'microphone', 'location'});
  });
}
