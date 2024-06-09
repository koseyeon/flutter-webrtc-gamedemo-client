import 'package:flutter/material.dart';
import 'package:web_rtc/model/player_model.dart';
import 'package:web_rtc/service/webrtc_controller.dart';
import 'package:web_rtc/view/webrtc_main_view.dart';

class WebRTCDataChannelView extends StatefulWidget {
  WebRTCDataChannelView({Key? key, this.controller}) : super(key: key);

  WebRTCController? controller;

  @override
  State<WebRTCDataChannelView> createState() => _WebRTCDataChannelViewState();
}

class _WebRTCDataChannelViewState extends State<WebRTCDataChannelView> {
  late WebRTCController _controller;
  String chatMessage = "";

  @override
  void initState() {
    super.initState();
    _controller = widget.controller!;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ScreenState>(
        valueListenable: _controller.screenNotifier,
        builder: (_, screenState, __) {
          Widget body;
          switch (screenState) {
            case ScreenState.connected:
              body = _connected();
              break;
            case ScreenState.disconnected:
              body = _disconnected();
              break;
            default:
              body = SizedBox();
              break;
          }
          return Scaffold(
            appBar: AppBar(
              title: Text('WebRTC DataChannel Example'),
              leading: IconButton(
                onPressed: () async {
                  await _controller.disconnectRequest();
                  await _controller.dispose();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => WebRTCMainView()),
                  );
                },
                icon: Icon(Icons.close),
              ),
              automaticallyImplyLeading: false,
            ),
            body: body,
          );
        });
  }

  Widget _connected() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onSubmitted: (String value) {
                      _controller.sendMessage(chatMessage);
                    },
                    onChanged: (newValue) {
                      chatMessage = newValue;
                    },
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    _controller.sendMessage(chatMessage);
                  },
                  child: Text('Send'),
                ),
              ],
            ),
            SizedBox(height: 20),
            Divider(height: 20, color: Colors.grey),
            Text("Chatting Test", style: TextStyle(fontSize: 20)),
            ValueListenableBuilder<List<String>>(
              valueListenable: _controller.chatMessageListNotifer,
              builder: (context, chatMessages, child) {
                return Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: ListView.builder(
                      itemCount: chatMessages.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(chatMessages[index]),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 20),
            Divider(height: 20, color: Colors.grey),
            Text("Moving Test", style: TextStyle(fontSize: 20)),
            ValueListenableBuilder<List<PlayerModel>>(
              valueListenable: _controller.playerListNotifier,
              builder: (context, playerList, child) {
                if (playerList.isEmpty) {
                  return Container();
                }
                final redPlayer = PlayerModel.getPlayerByName(playerList, "red");
                final bluePlayer = PlayerModel.getPlayerByName(playerList, "blue");
                if (redPlayer == null || bluePlayer == null) {
                  return Container();
                }
                return Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: Stack(
                      children: [
                        Positioned(
                          left: redPlayer.position.dx,
                          top: redPlayer.position.dy,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              Offset newPosition = redPlayer.position + details.delta;
                              _controller.updatePlayerPosition("red", newPosition);
                              _controller.sendPlayerData("red", newPosition);
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        Positioned(
                          left: bluePlayer.position.dx,
                          top: bluePlayer.position.dy,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              Offset newPosition = bluePlayer.position + details.delta;
                              _controller.updatePlayerPosition("blue", newPosition);
                              _controller.sendPlayerData("blue", newPosition);
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _disconnected() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You have been disconnected.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          IconButton(
            onPressed: () async {
              await _controller.dispose();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => WebRTCMainView()),
              );
            },
            icon: Icon(Icons.close),
            iconSize: 40,
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}
