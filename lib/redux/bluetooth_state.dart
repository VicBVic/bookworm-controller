import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothAppState {
  BluetoothConnection? camera;
  BluetoothConnection? motor;
  List<BluetoothDevice> bondedDevices;
  String lookingForBook;
  bool permissionsAccepted = false;

  BluetoothAppState(
      {this.camera,
      this.motor,
      this.bondedDevices = const [],
      this.lookingForBook = ""});
}
