import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_ml_kit_example/bluetooth_backend/blue_broadcast_handler.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:async/async.dart';

import 'package:flutter_redux/flutter_redux.dart';
import '../redux/bluetooth_state.dart';

import '../redux/bluetooth_state_actions.dart';

class DeviceSelectScreen extends StatefulWidget {
  final Duration connectionTimeLimit;
  final bool checkActivity;
  final Widget title;
  const DeviceSelectScreen(
      {Key? key,
      required this.checkActivity,
      required this.connectionTimeLimit,
      required this.title})
      : super(key: key);

  @override
  State<DeviceSelectScreen> createState() => _DeviceSelectScreenState();
}

class _DeviceSelectScreenState extends State<DeviceSelectScreen>
    with TickerProviderStateMixin {
  late AnimationController _reloadController;
  @override
  void initState() {
    _reloadController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      animationBehavior: AnimationBehavior.preserve,
      reverseDuration: const Duration(seconds: 1),
    );
    // _reloadController.stop();
    super.initState();
  }

  @override
  void dispose() {
    //_reloadController.dispose();
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // _reloadController.stop();
    return StoreBuilder<BluetoothAppState>(builder: ((context, store) {
      store.onChange.listen((event) {
        _reloadController.stop();
      });
      List<BluetoothDevice> devices = store.state.bondedDevices;

      List<Widget> list = devices.map((e) {
        bool used = false;

        return ListTile(
            trailing: used ? const Icon(Icons.check) : null,
            title: Text(e.name ?? "Missingno"),
            subtitle: Text(e.address),
            leading: null,
            onTap: used
                ? null
                : () async {
                    CancelableOperation connectOperation =
                        CancelableOperation.fromFuture(BlueBroadcastHandler
                            .instance
                            .getConnectionToAdress(e.address));
                    BluetoothConnection? connection = await showDialog(
                        barrierDismissible: true,
                        context: context,
                        builder: (context) => FutureBuilder(
                              builder: ((context, snapshot) {
                                if (snapshot.hasError)
                                  return const SimpleDialog(
                                    title: Text("Error when connecting!"),
                                    titlePadding: EdgeInsets.all(16.0),
                                  );
                                if (snapshot.hasData)
                                  Navigator.pop(context, snapshot.data);
                                return SimpleDialog(
                                  title:
                                      const Text("Waiting for connection..."),
                                  titlePadding: const EdgeInsets.all(16.0),
                                  children: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("Cancel"))
                                  ],
                                );
                              }),
                              future: connectOperation.value,
                            ));
                    connectOperation.cancel();
                    if (connection == null) return;
                    Navigator.pop(context, connection);
                    //if (connection is BluetoothConnection) {}
                  });
      }).toList();
      return Scaffold(
        appBar: AppBar(
          title: widget.title,
          actions: [
            RotationTransition(
              turns: CurvedAnimation(
                  parent: _reloadController,
                  curve: Curves.decelerate,
                  reverseCurve: (Curves.decelerate)),
              child: IconButton(
                onPressed: () {
                  _reloadController..reset();
                  _reloadController..repeat();
                  store.dispatch(StartBondedDevicesSearch());
                },
                icon: const Icon(Icons.replay),
              ),
            )
          ],
        ),
        body: ListView(
          children: list,
        ),
      );
    }));
  }
}
