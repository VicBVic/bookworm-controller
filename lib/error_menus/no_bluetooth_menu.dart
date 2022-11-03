import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../redux/bluetooth_state.dart';
import '../redux/bluetooth_state_actions.dart';

class NoBluetoothMenu extends StatelessWidget {
  NoBluetoothMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<BluetoothAppState>(builder: (context, store) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Bluetooth is disabled"),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "MatrixController needs location permissions and bluetooth to be active in order to function properly.",
              textAlign: TextAlign.center,
            ),
            TextButton(
                onPressed: () =>
                    store.dispatch(StartAskForPermissions(context)),
                child: Text("Retry"))
          ],
        ),
      );
    });
  }
}
