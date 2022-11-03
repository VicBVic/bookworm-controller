import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:google_ml_kit_example/bluetooth_views/device_select_screen.dart';
import 'package:google_ml_kit_example/util/show_view.dart';
import 'bluetooth_backend/blue_broadcast_handler.dart';
import 'error_menus/no_bluetooth_menu.dart';
import 'redux/bluetooth_reducer.dart';
import 'redux/bluetooth_state.dart';
import 'redux/bluetooth_state_actions.dart';
import 'vision_detector_views/text_detector_view.dart';
import 'package:redux/redux.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Store<BluetoothAppState> store = Store<BluetoothAppState>(
    bluetoothStateReducer,
    initialState: BluetoothAppState(),
    middleware: [
      bluetoothStateBondedDevicesMiddleware,
      bluetoothStateAskPermissionsMiddleware,
    ],
  );

  cameras = await availableCameras();

  runApp(MyApp(store: store));
}

class MyApp extends StatelessWidget {
  final Store<BluetoothAppState> store;
  MyApp({required this.store});
  @override
  Widget build(BuildContext context) {
    store.dispatch(StartAskForPermissions(context));
    return StoreProvider<BluetoothAppState>(
      store: store,
      child: MaterialApp(
          title: 'MariusController',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          //hemeMode: ThemeMode.Rdark,
          debugShowCheckedModeBanner: false,
          home: StoreBuilder<BluetoothAppState>(builder: (context, store) {
            if (!store.state.permissionsAccepted) {
              return NoBluetoothMenu();
            }
            return Home();
          })),
    );
  }
}

class Home extends StatefulWidget {
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Uint8List? imageBytes;
  int imageLength = 0;
  List<Uint8List> chunks = List.empty(growable: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bookworm Controller'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: StoreBuilder<BluetoothAppState>(builder: (context, store) {
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            BluetoothConnection? connection = await showView(
                                context,
                                DeviceSelectScreen(
                                  checkActivity: true,
                                  connectionTimeLimit: Duration(seconds: 10),
                                  title: Text("Choose a camera device:"),
                                ));
                            if (connection != null)
                              store.dispatch(AddCamera(connection));
                          },
                          child: Text("Choose camera"),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            BluetoothConnection? connection = await showView(
                                context,
                                DeviceSelectScreen(
                                  checkActivity: true,
                                  connectionTimeLimit: Duration(seconds: 10),
                                  title: Text("Choose a motor device:"),
                                ));
                            if (connection != null)
                              store.dispatch(AddMotor(connection));
                          },
                          child: Text("Choose motor"),
                        ),
                      ],
                    ),
                    TextFormField(
                      decoration:
                          InputDecoration(hintText: "choose a book name"),
                    ),
                    ElevatedButton(
                        onPressed: () {
                          startCameraSearch(store);
                        },
                        child: Text("Run!")),
                    imageBytes == null
                        ? Container()
                        : Image.memory(
                            imageBytes!,
                            fit: BoxFit.cover,
                          ),
                    ExpansionTile(
                      title: const Text('Vision APIs'),
                      children: [
                        CustomCard('Text Recognition', TextRecognizerView()),
                      ],
                    ),
                    SizedBox(
                      height: 20,
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  void startCameraSearch(Store<BluetoothAppState> store) async {
    BluetoothConnection connection = store.state.camera!;
    BlueBroadcastHandler.instance.printMessage(connection, "p");
    var sub = BlueBroadcastHandler.instance
        .getCommandStreamController(connection)
        .stream
        .listen((event) {
      print("recieved ${event.length} bytes ");
      setState(() {
        chunks.add(event);
        imageLength += event.length;
      });
    });
    await Future.delayed(Duration(seconds: 5));
    print("Hopefully all data was received!");
    sub.cancel();
    buildImage();
  }

  void buildImage() {
    if (chunks.isEmpty || imageLength == 0) return;
    imageBytes = Uint8List(imageLength);
    int offset = 0;
    for (var chunk in chunks) {
      imageBytes!.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    setState(() {});
  }
}

class CustomCard extends StatelessWidget {
  final String _label;
  final Widget _viewPage;
  final bool featureCompleted;

  const CustomCard(this._label, this._viewPage, {this.featureCompleted = true});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      margin: EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: Theme.of(context).primaryColor,
        title: Text(
          _label,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onTap: () {
          if (!featureCompleted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    const Text('This feature has not been implemented yet')));
          } else {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => _viewPage));
          }
        },
      ),
    );
  }
}
