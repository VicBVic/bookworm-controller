import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class _ConnectionWithName {
  BluetoothConnection connection;
  String name;
  _ConnectionWithName(this.connection, this.name);
}

class BlueBroadcastHandler {
  Map<String, BluetoothConnection> _connectionBuffer = {};
  Map<BluetoothConnection, StreamController<String>> _commandStreamBuffer = {};
  Map<BluetoothConnection, Stream<_ConnectionWithName>> _alarmStreamBuffer = {};
  StreamGroup<_ConnectionWithName> _alarmStreamGroup = StreamGroup();

  static final BlueBroadcastHandler instance = BlueBroadcastHandler._internal();

  factory BlueBroadcastHandler() {
    return instance;
  }
  final int maxConnectionRetries = 2;

  void addAlarmListener(void Function(_ConnectionWithName) callback) {
    _alarmStreamGroup.stream.listen(callback);
  }

  Set<BluetoothDevice> _bondedDevicesBuffer = <BluetoothDevice>{};

  Future<BluetoothConnection?> getConnectionToAdress(String address,
      {int retries = 0}) async {
    if (_connectionBuffer.containsKey(address)) {
      var connection = _connectionBuffer[address]!;
      if (connection.isConnected)
        return _connectionBuffer[address];
      else {
        connection.dispose();
        _connectionBuffer.remove(address);
      }
    }

    if (retries > 0) throw ("Cannot connect to address $address.");

    CancelableOperation connectOperation = CancelableOperation.fromFuture(
      BluetoothConnection.toAddress(address),
      onCancel: () => null,
    );
    var result = await connectOperation
        .valueOrCancellation()
        .onError((error, stackTrace) async {
      print("cuie frate $address");
      return await getConnectionToAdress(address, retries: retries + 1);
    });
    if (result is BluetoothConnection) {
      print("connected $address!");
      _connectionBuffer[address] = result;

      if (_alarmStreamBuffer[result] == null) {
        _alarmStreamBuffer[result] = getAlertStream(result, address);
        _alarmStreamGroup.add(_alarmStreamBuffer[result]!);
      }

      return result;
    }
    print("not connected to $address!");
    return result;
  }

  Future<List<BluetoothDevice>> getBondedDevices() async {
    await FlutterBluetoothSerial.instance
        .getBondedDevices()
        .then((avalibleDevices) {
      _bondedDevicesBuffer.addAll(avalibleDevices);
    });
    return _bondedDevicesBuffer.toList();
  }

  final String alertString = "Alert";

  StreamController<String> getCommandStreamController(
      BluetoothConnection connection) {
    var commandStream = _commandStreamBuffer[connection];

    if (commandStream != null) return commandStream;
    commandStream = StreamController<String>.broadcast();
    commandStream.addStream(_bluetoothConnectionReceivedCommands(connection));
    _commandStreamBuffer[connection] = commandStream;
    return commandStream;
  }

  Stream<String> _bluetoothConnectionReceivedCommands(
      BluetoothConnection connection) async* {
    String buffer = "";
    await for (final data in connection.input!.asBroadcastStream()) {
      String received = utf8.decode(data, allowMalformed: true);
      for (var a in received.split('')) {
        buffer += a;
        if (a == '\n') {
          yield buffer;
          buffer = '';
        }
      }
    }
  }

  void printMessage(BluetoothConnection connection, String message) async {
    connection.output.add(ascii.encode(message));
  }

  Stream<_ConnectionWithName> getAlertStream(
      BluetoothConnection connection, String name) async* {
    await for (String command
        in getCommandStreamController(connection).stream) {
      command = command.replaceAll('\n', '');
      command = command.replaceAll('\r', '');
      if (command == alertString) {
        print("alert found command $command ${command == alertString}");
        yield _ConnectionWithName(connection, name);
      }
    }
  }

  BlueBroadcastHandler._internal();
}
