/// Creates the WebSocket channel for the HUD connection.
///
/// On platforms with dart:io (Android, iOS, desktop) the channel sends a
/// WebSocket ping every 10 s and drops the connection if no pong comes back,
/// so a dead link (glasses out of range, phone changed WiFi) is detected
/// instead of looking "connected" forever. The Egg's WebSocket server
/// answers pings automatically. On web the plain browser WebSocket is used.
library;

export 'hud_socket_factory_stub.dart'
    if (dart.library.io) 'hud_socket_factory_io.dart';
