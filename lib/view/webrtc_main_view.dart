import 'package:flutter/material.dart';
import 'package:web_rtc/service/webrtc_controller.dart';
import 'package:web_rtc/view/webrtc_datachannel_view.dart';

class WebRTCMainView extends StatefulWidget {
  WebRTCMainView({Key? key}) : super(key: key);

  @override
  State<WebRTCMainView> createState() => _WebRTCMainViewState();
}

class _WebRTCMainViewState extends State<WebRTCMainView> {
  WebRTCController _controller = WebRTCController();

  @override
  void initState() {
    super.initState();
    debugPrint("init Main View");
    _controller.initController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ScreenState>(
      valueListenable: _controller.screenNotifier,
      builder: (_, screenState, __) {
        Widget body;
        switch (screenState) {
          case ScreenState.loading:
            body = const Center(
              child: Text('Loading...'),
            );
            break;
          case ScreenState.initDone:
            body = _initDone();
            break;
          case ScreenState.waiting:
            body = const Center(
              child: Text('Waiting...'),
            );
            break;
          case ScreenState.receivedOffer:
            body = _receivedOffer();
            break;
          case ScreenState.connected:
            body = _connected();
            break;

          default:
            body = SizedBox();
            break;
        }
        return Scaffold(
            appBar: screenState == ScreenState.initDone
                ? AppBar(
                    title: const Text('Online User list'),
                    automaticallyImplyLeading: false,
                  )
                : null,
            body: body,
            floatingActionButton: screenState == ScreenState.initDone
                ? Container(
                    width: 100,
                    height: 100,
                    child: FloatingActionButton(
                      child: const Icon(
                        Icons.waving_hand_outlined,
                        size: 60,
                      ),
                      onPressed: () async {
                        await _controller.sendOffer();
                      },
                    ),
                  )
                : null,
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat);
      },
    );
  }

  Widget _initDone() {
    return SafeArea(
      child: ValueListenableBuilder<List<String>>(
        valueListenable: _controller.userListNotifier,
        builder: (_, list, __) {
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, index) {
              String userId = list[index];
              return ListTile(
                leading: Text('${index + 1}'),
                title: Text(
                  userId,
                  style: TextStyle(
                    color: _controller.to == userId ? Colors.red : null,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _controller.to = userId;
                  });
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _receivedOffer() {
    return Align(
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Received offer from ${_controller.from}",
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              _controller.sendAnswer();
            },
            style: ElevatedButton.styleFrom(
              shape: CircleBorder(),
              padding: EdgeInsets.all(50),
            ),
            child: Icon(
              Icons.waving_hand_outlined,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _connected() {
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WebRTCDataChannelView(controller: _controller),
        ),
      );
    });
    return SizedBox();
  }
}
