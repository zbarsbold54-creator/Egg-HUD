#include "WSServer.h"
#include "Config.h"
#include "DisplayDriver.h"
#include <WebSocketsServer.h>

WSServer WsServer;
static WebSocketsServer socket(WS_PORT);

// Free function matching the library's callback signature; forwards
// into WsServer's private handling so state stays encapsulated.
void webSocketEvent(uint8_t clientId, WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_CONNECTED:
      WsServer._clientCount++;
      Serial.print(F("[WS] client connected: id="));
      Serial.print(clientId);
      Serial.print(F(" ip="));
      Serial.print(socket.remoteIP(clientId));
      Serial.print(F(" clients="));
      Serial.println(WsServer._clientCount);
      break;

    case WStype_DISCONNECTED:
      if (WsServer._clientCount > 0) WsServer._clientCount--;
      Serial.print(F("[WS] client disconnected: id="));
      Serial.print(clientId);
      Serial.print(F(" clients="));
      Serial.println(WsServer._clientCount);
      break;

    case WStype_BIN:
      if (Display.writeFrame(payload, length)) {
        WsServer._lastFrameMillis = millis();
      } else {
        // Frames of the wrong length are dropped - a malformed or partial
        // frame shouldn't corrupt what's currently on screen.
        Serial.print(F("[WS] bad frame len: "));
        Serial.println(length);
      }
      break;

    default:
      break;
  }
}

void WSServer::begin() {
  static bool started = false;
  if (started) return;  // idempotent: safe to call on re-entry
  socket.begin();
  socket.onEvent(webSocketEvent);
  socket.enableHeartbeat(WS_HEARTBEAT_PING_MS, WS_HEARTBEAT_PONG_MS, WS_HEARTBEAT_MAX_FAILS);
  started = true;
  Serial.print(F("[WS] server on port "));
  Serial.println(WS_PORT);
}

void WSServer::loop() {
  socket.loop();
}
