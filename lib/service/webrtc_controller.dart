import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_rtc/model/icecandidate_model.dart';
import 'package:web_rtc/model/player_model.dart';
import 'package:web_rtc/model/webrtc_model.dart';
import 'package:web_rtc/service/webrtc_socket.dart';

// 화면 상태 enum
enum ScreenState { loading, initDone, waiting, receivedOffer, connected, disconnected }

class WebRTCController extends WebRTCSocket {
  String? to;
  String? from;

  RTCPeerConnection? _peer;
  RTCDataChannel? _dataChannel;

  // ICE 후보 목록 저장용
  final List<IceCandidateModel> _candidateList = [];

  // 화면 상태 및 사용자 목록을 위한 ValueNotifier
  ValueNotifier<ScreenState> screenNotifier = ValueNotifier<ScreenState>(ScreenState.loading);
  ValueNotifier<List<String>> userListNotifier = ValueNotifier<List<String>>([]);
  ValueNotifier<List<String>> chatMessageListNotifer = ValueNotifier<List<String>>([]);
  ValueNotifier<List<PlayerModel>> playerListNotifier = ValueNotifier<List<PlayerModel>>(
      [PlayerModel(name: "red", position: Offset(100, 100)), PlayerModel(name: "blue", position: Offset(200, 100))]);

  // 컨트롤러 초기화
  Future<void> initController() async {
    await _initSocket();
    await _initPeer();
    await _initDataChannel();
    screenNotifier.value = ScreenState.initDone;
    debugPrint("controller is initialized");
  }

  // 컨트롤러 종료
  Future<void> dispose() async {
    userListNotifier.dispose();
    screenNotifier.dispose();
    chatMessageListNotifer.dispose();
    playerListNotifier.dispose();
    await _peer?.dispose();
    super.disconnectSocket();
    debugPrint("controller is disposed");
  }

  // 소켓 초기화
  Future<void> _initSocket() async {
    from = await super.connectSocket();
    if (from != null) {
      super.socketOn('updateUserList', _updateUserList);
      super.socketOn('offer', _receiveOffer);
      super.socketOn('answer', _receiveAnswer);
      super.socketOn('iceCandidate', _receiveIceCandidate);
      super.socketOn('disconnectResponse', disconnectResponse);
    }
  }

  // 피어 연결 초기화
  Future<void> _initPeer() async {
    _peer = await createPeerConnection({
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ],
    });
    _peer!.onIceCandidate = _onIceCandidateEvent;
    _peer!.onConnectionState = _onConnectionStateEvent;
    _peer!.onDataChannel = (RTCDataChannel channel) {
      channel.onMessage = _handleDataChannelMessage;
      channel.onDataChannelState = _handleDataChannelState;
    };
  }

  // 데이터 채널 초기화
  Future<void> _initDataChannel() async {
    RTCDataChannelInit dataChannelForChat = RTCDataChannelInit();
    _dataChannel = await _peer!.createDataChannel('gameData', dataChannelForChat);
  }

  // 데이터 채널 메시지 처리
  void _handleDataChannelMessage(RTCDataChannelMessage message) {
    debugPrint("receive success");
    switch (message.type) {
      case MessageType.text:
        chatMessageListNotifer.value = List.from(chatMessageListNotifer.value)..add(message.text);
        break;
      case MessageType.binary:
        final Uint8List bytes = message.binary!;
        PlayerModel player = decodePlayerData(message.binary);
        updatePlayerInList(player);
        break;
    }
  }

  // 데이터 채널 상태 처리
  void _handleDataChannelState(RTCDataChannelState state) {
    if (state == RTCDataChannelState.RTCDataChannelOpen) {
      screenNotifier.value = ScreenState.connected;
      _dataChannel!.send(RTCDataChannelMessage("Connected with " + super.user.toString()));
    }
  }

  // 사용자 목록 업데이트
  void _updateUserList(data) {
    debugPrint('[socket] userList update $data');
    Map<String, dynamic> map = Map.castFrom(data);
    List<String> list = List.from(map['userList']);
    list.removeWhere((element) => element == super.user);
    userListNotifier.value = list;
  }

  // offer SDP 전송
  Future<void> sendOffer() async {
    if (to == null) {
      return;
    }
    final RTCSessionDescription offer = await _peer!.createOffer({});
    await _peer!.setLocalDescription(offer);
    WebRTCModel model = WebRTCModel(offerSDP: offer.sdp, offerType: offer.type, to: to, from: from);
    debugPrint('[webRTC] send offer : ${model.from} to ${model.to}');
    super.socketEmit('offer', model.toJson());
    screenNotifier.value = ScreenState.waiting;
  }

  // offer SDP 수신
  void _receiveOffer(data) async {
    WebRTCModel model = WebRTCModel.fromJson(data);
    debugPrint('[webRTC] receive offer : ${model.to} from ${model.from}');
    await _peer!.setRemoteDescription(RTCSessionDescription(model.offerSDP, model.offerType));
    to = model.from;
    screenNotifier.value = ScreenState.receivedOffer;
  }

  // answer SDP 전송
  void sendAnswer() async {
    debugPrint('[webRTC] send answer to $to');
    final RTCSessionDescription answer = await _peer!.createAnswer();
    await _peer!.setLocalDescription(answer);
    final model = WebRTCModel(
      answerSDP: answer.sdp,
      answerType: answer.type,
      to: to,
    );
    super.socketEmit('answer', model.toJson());
  }

  // answer SDP 수신 (answer SDP 수신과 동시에 ice 후보 교환을 시작한다.)
  void _receiveAnswer(data) async {
    WebRTCModel model = WebRTCModel.fromJson(data);
    debugPrint('[webRTC] receive answer : ${model.answerType}');
    await _peer!.setRemoteDescription(RTCSessionDescription(model.answerSDP, model.answerType));
    for (IceCandidateModel candidateModel in _candidateList) {
      debugPrint('[webRTC] send iceCandidate : ${candidateModel.toJson()}');
      super.socketEmit('iceCandidate', candidateModel.toJson());
      break;
    }
  }

  // ICE 후보 이벤트 처리
  void _onIceCandidateEvent(RTCIceCandidate e) {
    IceCandidateModel model = IceCandidateModel(
      candidate: e,
      to: to,
    );
    if (model.candidate == null || model.to == null) {
      return;
    }
    if (_candidateList.every((element) => element.candidate != model.candidate)) {
      _candidateList.add(model);
    }
  }

  // ICE 후보 수신
  void _receiveIceCandidate(data) async {
    debugPrint('[webRTC] remoteIceCandidate $data');
    try {
      IceCandidateModel model = IceCandidateModel.fromJson(data);
      await _peer!.addCandidate(model.candidate);
    } catch (e) {
      debugPrint('[webRTC] remoteIceCandidate error : $e');
    }
  }

  // 피어 연결 상태 이벤트 처리
  void _onConnectionStateEvent(RTCPeerConnectionState state) {
    debugPrint('[webRTC] peer connection state : ${state.name}, ${_peer?.connectionState}');
    if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
      _peer?.restartIce();
    }
  }

  // 연결 종료 요청
  Future<void> disconnectRequest() async {
    super.socketEmit('disconnectRequest', {'to': to});
    screenNotifier.value = ScreenState.initDone;
  }

  // 연결 종료 응답
  void disconnectResponse(_) async {
    screenNotifier.value = ScreenState.disconnected;
  }

  // 플레이어 데이터 전송
  void sendPlayerData(String name, Offset position) {
    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      Uint8List playerData = encodePlayerData(name, position);
      _dataChannel!.send(RTCDataChannelMessage.fromBinary(playerData));
      debugPrint("send success");
    } else {
      debugPrint('DataChannel is not open or not initialized.');
    }
  }

  // 플레이어 위치 업데이트
  void updatePlayerPosition(String playerName, Offset newPosition) {
    final playerIndex = playerListNotifier.value.indexWhere((player) => player.name == playerName);
    if (playerIndex != -1) {
      playerListNotifier.value[playerIndex] = PlayerModel(name: playerName, position: newPosition);
      playerListNotifier.notifyListeners();
    }
  }

  // 채팅 메시지 전송
  void sendMessage(String chatMassage) {
    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      chatMassage = from! + " : " + chatMassage;
      _dataChannel!.send(RTCDataChannelMessage(chatMassage));
      chatMessageListNotifer.value = List.from(chatMessageListNotifer.value)..add(chatMassage);
      debugPrint("send success");
    } else {
      debugPrint('DataChannel is not open or not initialized.');
      debugPrint(_dataChannel.toString());
    }
  }

  // 플레이어 데이터 인코딩
  Uint8List encodePlayerData(String name, Offset position) {
    final nameBytes = utf8.encode(name);
    final buffer = ByteData((1 + nameBytes.length + 16) as int);
    buffer.setUint8(0, nameBytes.length);
    buffer.buffer.asUint8List(1, nameBytes.length).setAll(0, nameBytes);
    buffer.setFloat64(1 + nameBytes.length, position.dx, Endian.little);
    buffer.setFloat64(1 + nameBytes.length + 8, position.dy, Endian.little);
    return buffer.buffer.asUint8List();
  }

  // 플레이어 데이터 디코딩
  PlayerModel decodePlayerData(Uint8List data) {
    final buffer = ByteData.sublistView(data);
    final nameLength = buffer.getUint8(0);
    final name = utf8.decode(data.sublist(1, 1 + nameLength));
    final dx = buffer.getFloat64(1 + nameLength, Endian.little);
    final dy = buffer.getFloat64(1 + nameLength + 8, Endian.little);
    return PlayerModel(name: name, position: Offset(dx, dy));
  }

  // 플레이어 목록 업데이트
  void updatePlayerInList(PlayerModel updatedPlayer) {
    playerListNotifier.value = playerListNotifier.value.map((player) {
      if (player.name == updatedPlayer.name) {
        return updatedPlayer;
      }
      return player;
    }).toList();
  }
}
