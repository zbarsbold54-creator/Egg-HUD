/// dart:io implementation: WebSocket with ping/pong liveness detection.
library;

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectHudSocket(Uri uri) => IOWebSocketChannel.connect(
      uri,
      pingInterval: const Duration(seconds: 10),
    );
