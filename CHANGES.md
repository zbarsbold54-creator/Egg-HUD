# Glasses connection fix: changed files

Copy these files over the same paths in your Jarvis_Project folder (4 are new).
Then: `flutter pub get`, `flutter test`, rebuild the app, and re-flash the HUD Egg.

## Brain App (brain_app/)
- NEW lib/connectivity/hud/hud_providers.dart: ONE shared HudConnection + renderer; auto-connect on launch (saved IP, else discovery; re-discovers if the saved IP went stale)
- NEW hud_socket_factory*.dart: ping/pong liveness on dart:io platforms (dead links detected)
- lib/connectivity/hud/hud_connection.dart: rewritten (single reconnect owner, generation guard, no unhandled Completer errors, backoff 1-30 s, ensureConnected(), hostToUrl())
- lib/connectivity/hud/hud_discovery.dart: PTR->SRV->A (was querying A on the instance name), fixed 'hud.local.local' bug, Android multicast lock, web guard, last-saved-IP fallback, reasons reported
- lib/app/app.dart + lifecycle.dart: lifecycle now actually instantiated; reconnect on resume; screen restored on reconnect
- lib/features/settings/settings_screen.dart: uses the shared connection (was a private one that died with the screen); empty IP no longer builds "ws://:81"; text fields keep state; status driven by connection state
- android: CHANGE_WIFI_MULTICAST_STATE + MainActivity multicast-lock channel
- test/integration/hud_connection_test.dart: new tests
## Firmware (firmware/HUD/)
- Radio modem-sleep only while a client is connected (idle + no client keeps radio awake)
- WS: heartbeat, client COUNT instead of bool, missing break, connect/disconnect logging with IP
- mDNS restarted on every enterRunning (survives WiFi drop/rejoin)
- WiFi: disconnect-reason logging, tries every visible known network, hidden-SSID fallback at boot
- Provisioning: no scan/join retry while a phone is on the setup AP
## tools/hud_cors_proxy.py: corrected misleading CORS docs
