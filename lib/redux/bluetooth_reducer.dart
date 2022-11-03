import 'dart:math';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../bluetooth_backend/blue_broadcast_handler.dart';

import 'bluetooth_state.dart';
import 'bluetooth_state_actions.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:redux/redux.dart';

BluetoothAppState bluetoothStateReducer(
    BluetoothAppState state, dynamic action) {
  print("reducer bitch ass mf $action");
  if (action is PermisionsAcceptedAction) {
    state.permissionsAccepted = true;
  }

  if (action is ErrorAction) {
    print("Error!");
  }
  if (action is AddBondedDevicesAction) {
    //print("ready to get plowed ${action.devices}");
    state.bondedDevices = action.devices;
  }

  if (action is AddCamera) {
    state.camera = action.camera;
  }
  if (action is AddMotor) {
    state.motor = action.motor;
  }
  return state;
}

void bluetoothStateBondedDevicesMiddleware(
    Store<BluetoothAppState> store, dynamic action, NextDispatcher next) {
  if (action is StartBondedDevicesSearch) {
    print("bruhfuck");
    BlueBroadcastHandler.instance
        .getBondedDevices()
        .onError((error, stackTrace) {
      print("Bluetooth error!");
      return List.empty();
    }).then((value) async {
      //debug
      await Future.delayed(Duration(milliseconds: 500));
      if (value.isEmpty) {
        store.dispatch(ErrorAction());
      } else {
        store.dispatch(AddBondedDevicesAction(value));
      }
    });
  } else
    next(action);
}

void bluetoothStateAskPermissionsMiddleware(
    Store<BluetoothAppState> store, dynamic action, NextDispatcher next) {
  if (action is StartAskForPermissions) {
    FlutterBluetoothSerial blue = FlutterBluetoothSerial.instance;
    blue.requestEnable().then((value) async {
      //print("here2");
      bool accepted = (value ?? false) &&
          (await Permission.location.request().then((value) {
            if (value.isPermanentlyDenied) {
              print("ErrorAction sent");
              store.dispatch(ErrorAction());
            }
            print(
                "here ${value.isGranted} ${value.isDenied} ${value.isPermanentlyDenied} ${value.isRestricted}");
            return value.isGranted;
          }));
      if (accepted) {
        store.dispatch(PermisionsAcceptedAction());
        store.dispatch(StartBondedDevicesSearch());
      }
    });
  } else
    next(action);
}
