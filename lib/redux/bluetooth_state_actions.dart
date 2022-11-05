import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothStateAction {}

class AddBondedDevicesAction extends BluetoothStateAction {
  List<BluetoothDevice> devices;
  AddBondedDevicesAction(this.devices);
}

class StartBondedDevicesSearch extends BluetoothStateAction {}

class AddCamera extends BluetoothStateAction {
  BluetoothConnection camera;
  AddCamera(this.camera);
}

class SetLookingForBook extends BluetoothStateAction {
  String lookingForBook;
  SetLookingForBook(this.lookingForBook);
}

class AddMotor extends BluetoothStateAction {
  BluetoothConnection motor;
  AddMotor(this.motor);
}

class ErrorAction extends BluetoothStateAction {}

class StartAskForPermissions extends BluetoothStateAction {
  BuildContext context;
  StartAskForPermissions(this.context);
}

class PermisionsAcceptedAction extends BluetoothStateAction {}
