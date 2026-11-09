# Firmware Proposals (NOT APPLIED — needs owner approval)

> No code in this doc is applied. All items require explicit owner approval before implementation.

## P1. Serial.setTxTimeoutMs(0)

Prevent Serial TX blocking when USB not connected (e.g. battery power). Currently Serial.print can block if USB CDC buffer full.

## P2. Idempotent WS/mDNS begin()

Make WSServer::begin() and MdnsAdvertiser::begin() safe to call on every enterRunning() without duplicate servers. mDNS already restarts cleanly; WS already idempotent via static flag. Verify no double-bind on WiFi rejoin.

## P3. WPA2 provisioning AP + DNS catch-all

Current AP is open (HUD-Setup-XXXX). Add WPA2 password (random, shown on OLED) + DNS catch-all (all domains to 192.168.4.1) for captive portal.

## P4. Factory reset via BOOT hold

Hold BOOT 5s at boot to wipe NVS (WiFi creds) and reboot to provisioning. For recovery from bad creds without serial.

## P5. ESP-NOW boot ID + HOLD event

Add bootId (random per boot) to ESP-NOW packet. Controller sends HOLD (button held, no release yet) every 500ms while pressed, so HUD can detect stuck button / lost release.

## P6. ANNOUNCE-while-scanning

Controller sends ANNOUNCE on every channel during scan (not just after beacon). HUD replies ACK. Faster discovery (no need to wait for beacon).

## P7. OTA with password

ArduinoOTA with password auth. Update via WiFi without USB. Requires password storage (NVS) and signed images.

## P8. HUD-stamped seq on port 82 (PROPOSED)

Currently controller seq is forwarded as-is. Proposal: HUD stamps its own monotonic seq on port 82 messages (in addition to controller seq), so app can detect HUD-side drops vs controller-side drops.

## P9. App-to-HUD JSON control on port 82 (PROPOSED)

Instead of text frames on port 81 (which would break the frozen 1024-byte binary protocol), add JSON control messages on port 82 (HUD receives, not just sends):
- {"cmd":"brightness","value":100}
- {"cmd":"sleep"}
- {"cmd":"clear"}

Port 81 stays binary-only. Port 82 becomes bidirectional JSON. Requires HUD InputWSServer to handle incoming text (currently send-only).
