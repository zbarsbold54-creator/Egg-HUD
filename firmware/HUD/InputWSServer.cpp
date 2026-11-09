#include "InputWSServer.h"
#include "Config.h"
#include "EspNowBridge.h"
#include <WebSocketsServer.h>

InputWSServer InputWs;
static WebSocketsServer socket(INPUT_WS_PORT);

void inputWebSocketEvent(uint8_t clientId, WStype_t type, uint8_t* payload, size_t length) {
  if (type == WStype_CONNECTED) {
    InputWs._clientCount++;
    Serial.print(F("[INPUT-WS] client connected id="));
    Serial.print(clientId);
    Serial.print(F(" ip="));
    Serial.print(socket.remoteIP(clientId));
    Serial.print(F(" clients="));
    Serial.println(InputWs._clientCount);
    InputWs.broadcastStatus(EspNowBridge::controllerStatus());
  } else if (type == WStype_DISCONNECTED) {
    if (InputWs._clientCount > 0) InputWs._clientCount--;
    Serial.print(F("[INPUT-WS] client disconnected id="));
    Serial.print(clientId);
    Serial.print(F(" clients="));
    Serial.println(InputWs._clientCount);
  }
}

void InputWSServer::begin() {
  static bool started = false;
  if (started) return;
  socket.begin();
  socket.onEvent(inputWebSocketEvent);
  socket.enableHeartbeat(WS_HEARTBEAT_PING_MS, WS_HEARTBEAT_PONG_MS, WS_HEARTBEAT_MAX_FAILS);
  started = true;
  Serial.print(F("[INPUT-WS] server on port "));
  Serial.println(INPUT_WS_PORT);
}

void InputWSServer::loop() { socket.loop(); }

void InputWSServer::forwardButtonDown(uint32_t seq, uint32_t tsMs) {
  if (_clientCount == 0) return;
  char buf[160];
  snprintf(buf, sizeof(buf),
    "{\"v\":1,\"type\":\"button_down\",\"seq\":%lu,\"ts\":%lu,\"controller\":1}",
    (unsigned long)seq, (unsigned long)tsMs);
  socket.broadcastTXT(buf);
}

void InputWSServer::forwardButtonUp(uint32_t seq, uint32_t tsMs, uint32_t durationMs) {
  if (_clientCount == 0) return;
  char buf[200];
  snprintf(buf, sizeof(buf),
    "{\"v\":1,\"type\":\"button_up\",\"seq\":%lu,\"ts\":%lu,\"durationMs\":%lu,\"controller\":1}",
    (unsigned long)seq, (unsigned long)tsMs, (unsigned long)durationMs);
  socket.broadcastTXT(buf);
}

void InputWSServer::broadcastStatus(uint8_t status) {
  if (_clientCount == 0) return;
  const char* names[] = {"DISCONNECTED","SEARCHING","CONNECTING","CONNECTED","RECONNECTING","ERROR"};
  char buf[160];
  snprintf(buf, sizeof(buf),
    "{\"v\":1,\"type\":\"status\",\"status\":\"%s\",\"code\":%d}",
    (status < 6 ? names[status] : "ERROR"), status);
  socket.broadcastTXT(buf);
}
