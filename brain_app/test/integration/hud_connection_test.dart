// Integration tests for HUD connection using mocks.
// Physical hardware unavailable — verifies protocol, reconnect, frame validation.
import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/connectivity/hud/hud_connection.dart';
import 'package:brain_app/display/encoders/display_frame_encoder.dart';

void main() {
  group('HudConnection (mocked)', () {
    test('rejects wrong-length frames', () {
      final conn = HudConnection();
      expect(conn.sendFrame(List<int>.filled(100, 0)), false);
      expect(conn.sendFrame(List<int>.filled(1024, 0)), false); // not connected
      conn.dispose();
    });

    test('encoder produces valid 1024-byte frames', () {
      final enc = DisplayFrameEncoder();
      expect(enc.isValidFrame(enc.blackFrame()), true);
      expect(enc.isValidFrame(enc.whiteFrame()), true);
      expect(enc.isValidFrame(enc.checkerboardFrame()), true);
      expect(enc.isValidFrame(enc.halfFrame()), true);
      expect(enc.isValidFrame(List<int>.filled(100, 0)), false);
    });

    test('hostToUrl normalizes what a person types', () {
      expect(HudConnection.hostToUrl('192.168.1.27'), 'ws://192.168.1.27:81');
      expect(HudConnection.hostToUrl('  192.168.1.27:81  '), 'ws://192.168.1.27:81');
      expect(HudConnection.hostToUrl('ws://192.168.1.27:81/'), 'ws://192.168.1.27:81');
      expect(HudConnection.hostToUrl('hud.local'), 'ws://hud.local:81');
      expect(HudConnection.hostToUrl('192.168.1.27:8081'), 'ws://192.168.1.27:8081');
      expect(HudConnection.hostToUrl(''), isNull);
      expect(HudConnection.hostToUrl('   '), isNull);
    });

    test('failed connect reports an error and disconnect stops retries', () async {
      final conn = HudConnection();
      // Nothing listens on loopback port 1: connection is refused quickly.
      final ok = await conn.connect('ws://127.0.0.1:1');
      expect(ok, false);
      expect(conn.isConnected, false);
      expect(conn.lastError, isNotNull);
      expect(conn.state, HudConnectionState.error);

      await conn.disconnect();
      expect(conn.state, HudConnectionState.disconnected);
      await conn.dispose();
    });

    test('ensureConnected is a no-op when the user never connected', () async {
      final conn = HudConnection();
      conn.ensureConnected();
      expect(conn.state, HudConnectionState.disconnected);
      await conn.dispose();
    });

    test('connection state starts disconnected', () {
      final conn = HudConnection();
      expect(conn.state, HudConnectionState.disconnected);
      expect(conn.isConnected, false);
      conn.dispose();
    });
  });
}
