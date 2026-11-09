#pragma once
#include <Arduino.h>
#include <WebSocketsServer.h>   // for WStype_t, used by the friend callback below

// Hosts the WebSocket server the Brain App connects to as a client.
// Binary messages of exactly FRAME_BYTES length are treated as full
// bitmap frames and written straight to the display.
class WSServer {
public:
  void begin();
  void loop();

  // True while at least one client is connected. (A count, not a bool, so
  // one client leaving - e.g. a test script - doesn't mark the Egg offline
  // while the Brain App is still connected.)
  bool clientConnected() const { return _clientCount > 0; }
  uint8_t clientCount() const { return _clientCount; }
  uint32_t lastFrameMillis() const { return _lastFrameMillis; }

private:
  uint8_t _clientCount = 0;
  uint32_t _lastFrameMillis = 0;

  friend void webSocketEvent(uint8_t clientId, WStype_t type, uint8_t* payload, size_t length);
};

extern WSServer WsServer;
