import 'dart:ui';

class PlayerModel {
  String name;
  Offset position;
  PlayerModel({required this.name, required this.position});

  static PlayerModel? getPlayerByName(List<PlayerModel> players, String name) {
    return players.firstWhere((player) => player.name == name);
  }
}
