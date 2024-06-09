import 'package:flutter_webrtc/flutter_webrtc.dart';

class IceCandidateModel {
  RTCIceCandidate candidate;
  String? to;

  IceCandidateModel({
    required this.candidate,
    this.to,
  });

  factory IceCandidateModel.fromJson(Map<String, dynamic> json) {
    return IceCandidateModel(
      candidate: RTCIceCandidate(
        json['candidate']['candidate'],
        json['candidate']['sdpMid'],
        json['candidate']['sdpMLineIndex'],
      ),
      to: json['to'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'candidate': candidate.toMap(),
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
      'to': to,
    };
  }
}
