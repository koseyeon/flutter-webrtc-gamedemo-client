import 'dart:async';

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class WebRTCSocket {
  late io.Socket _socket;
  String? user;

  Future<String?> connectSocket() {
    debugPrint('[socket] try connecting');
    Completer<String> completer = Completer<String>();

    // 자신의 서버 주소로 변경
    _socket = io.io('http://192.168.200.141:9000', <String, dynamic>{
      'transports': ['websocket'],
      'forceNew': true,
    });

    _socket.onConnect((data) {
      user = _socket.id;
      completer.complete(user);
      debugPrint('[socket] connected : $user');
    });
    return completer.future;
  }

  void socketOn(String event, void Function(dynamic) callback) {
    _socket.on(event, callback);
  }

  void socketEmit(String event, dynamic data) {
    _socket.emit(event, data);
  }

  void disconnectSocket() {
    _socket.dispose();
  }
}
