#pragma once
#include <Arduino.h>
#include <WebSocketsServer.h>

// Input WebSocket on port 82 — separate from display WS (port 81).
// Forwards controller button events as JSON text to the Brain App.
class InputWSServer {
public:
  void begin();
  void loop();
  void forwardButtonDown(uint32_t seq, uint32_t tsMs);
  void forwardButtonUp(uint32_t seq, uint32_t tsMs, uint32_t durationMs);
  void broadcastStatus(uint8_t status);
  bool clientConnected() const { return _clientCount > 0; }
private:
  uint8_t _clientCount = 0;
  friend void inputWebSocketEvent(uint8_t clientId, WStype_t type, uint8_t* payload, size_t length);
};
extern InputWSServer InputWs;
