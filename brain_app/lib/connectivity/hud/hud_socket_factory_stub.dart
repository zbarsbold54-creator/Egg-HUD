/// Web / non-dart:io implementation: plain browser WebSocket.
library;

import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectHudSocket(Uri uri) => WebSocketChannel.connect(uri);
