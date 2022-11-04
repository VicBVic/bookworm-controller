import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:google_ml_kit_example/bluetooth_views/device_select_screen.dart';
import 'package:google_ml_kit_example/util/show_view.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'bluetooth_backend/blue_broadcast_handler.dart';
import 'error_menus/no_bluetooth_menu.dart';
import 'redux/bluetooth_reducer.dart';
import 'redux/bluetooth_state.dart';
import 'redux/bluetooth_state_actions.dart';
import 'vision_detector_views/text_detector_view.dart';
import 'package:redux/redux.dart';

import 'dart:ui' as UI;
import 'package:async/async.dart';

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
  final TextRecognizer _textRecognizer = TextRecognizer();
  Uint8List? imageBytes;
  int imageLength = 0;
  List<Uint8List> chunks = List.empty(growable: true);
  final imageSizeNames = {
    1: "240x240",
    2: "QVGA(320x240)",
    3: "SVGA(800x600)",
    4: "HD(1280,720)",
    5: "QXGA(2048,1356)"
  };
  final imageSizes = {
    1: [240, 240],
    2: [320, 240],
    3: [800, 600],
    4: [1280, 720],
    5: [2048, 1356]
  };
  int pickedImageSize = 1;

  int picSeconds = 5;
  int moveSeconds = 2;
  int moveTimes = 5;

  List<String> imageFoundText = List.empty(growable: true);

  String searchingFor = "";
  double foundConfidence = -1;

  @override
  void dispose() async {
    _textRecognizer.close();
    super.dispose();
  }

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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                    Text("Pic Seconds:"),
                    Slider(
                      value: picSeconds.toDouble(),
                      max: 10,
                      min: 1,
                      divisions: 10,
                      label: picSeconds.toString(),
                      onChanged: (double value) {
                        setState(() {
                          picSeconds = value.round();
                        });
                      },
                    ),
                    Text("Move Seconds:"),
                    Slider(
                      value: moveSeconds.toDouble(),
                      max: 10,
                      min: 1,
                      divisions: 10,
                      label: moveSeconds.toString(),
                      onChanged: (double value) {
                        setState(() {
                          moveSeconds = value.round();
                        });
                      },
                    ),
                    Text("Move Times:"),
                    Slider(
                      value: moveTimes.toDouble(),
                      max: 10,
                      min: 1,
                      divisions: 10,
                      label: moveTimes.toString(),
                      onChanged: (double value) {
                        setState(() {
                          moveTimes = value.round();
                        });
                      },
                    ),
                    MotorControlRow(
                      store: store,
                    ),
                    TextFormField(
                      decoration:
                          InputDecoration(hintText: "choose a book name"),
                      onChanged: (value) {
                        setState(() {
                          searchingFor = value;
                        });
                      },
                    ),
                    DropdownButton<int>(
                      value: pickedImageSize,
                      items: imageSizes.keys
                          .map(
                            (e) => DropdownMenuItem<int>(
                              child: Text(imageSizeNames[e]!),
                              value: e,
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          pickedImageSize = value ?? pickedImageSize;
                        });
                      },
                    ),
                    ElevatedButton(
                        onPressed: () {
                          takeCameraPic(store, Duration(seconds: picSeconds));
                        },
                        child: Text("Capture photo")),
                    imageBytes == null
                        ? Container()
                        : Image.memory(
                            imageBytes!,
                            fit: BoxFit.cover,
                          ),
                    imageFoundText.length > 0
                        ? Text(imageFoundText.fold(
                            "Found text: ",
                            (previousValue, element) =>
                                previousValue + element))
                        : Container(),
                    foundConfidence > 0
                        ? Text(
                            "Found book with confidence: $foundConfidence",
                            style: TextStyle(color: Colors.green),
                          )
                        : Container(),
                    ElevatedButton(
                        onPressed: () async {
                          final text =
                              await runVisionAI("/bruh.jpeg", imageBytes!);
                          setState(() {
                            imageFoundText.clear();
                            imageFoundText.add(text);
                          });
                        },
                        child: Text("Run Vision AI!")),
                    ElevatedButton(
                        onPressed: () {
                          runFullApp(store);
                        },
                        child: Text("Run Full App!")),
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

  double getFuzzyMatch(String main, String pattern) {
    Fuzzy fuzzy = Fuzzy(imageFoundText,
        options: FuzzyOptions(tokenize: false, threshold: 0.5));
    final res = fuzzy.search(pattern);
    double result = 0;
    for (var r in res) {
      result = max(result, r.score);
    }
    return result;
  }

  Future<void> runFullApp(Store<BluetoothAppState> store) async {
    imageFoundText.clear();
    for (int i = 0; i < moveTimes; i++) {
      Future<void> moveMotor = Future.delayed(Duration(milliseconds: 500)).then(
          (value) async =>
              await turnMotor(store, false, Duration(seconds: moveSeconds)));
      Future<void> takePic = takeCameraPic(store, Duration(seconds: picSeconds))
          .then((value) async {
        print("maiking request!");
        final text = await runVisionAI("/bruh$i.jpeg", imageBytes!);
        print("finished request!");
        setState(() {
          imageFoundText.add(text);
        });
      });
      //FutureGroup group = FutureGroup();
      //group.add(moveMotor);
      //group.add(takePic);
      //group.close();
      await takePic;
      await moveMotor;
      print("finished a cycle!");
    }
  }

  Future<String> runVisionAI(String imagePath, Uint8List bytes) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    //  UI.ImageDescriptor imd =
    //      await UI.ImageDescriptor.encoded(
    //          await UI.ImmutableBuffer.fromUint8List(
    //              imageBytes!));
    //  UI.Codec codec = await imd.instantiateCodec();
    //  UI.FrameInfo frame = await codec.getNextFrame();
    //  UI.Image image = frame.image;
    File img = File("${appDocDir.path}${imagePath}");
    if (img.existsSync()) await img.delete();
    img = await img.create();
    img.writeAsBytesSync(bytes.toList());
    final recognizedText =
        await _textRecognizer.processImage(InputImage.fromFile(img));
    if (searchingFor != "")
      setState(() {
        foundConfidence = getFuzzyMatch(recognizedText.text, searchingFor);
      });
    return recognizedText.text;
  }

  Future<void> turnMotor(
      Store<BluetoothAppState> store, bool left, Duration time) async {
    BluetoothConnection connection = store.state.motor!;
    BlueBroadcastHandler.instance.printMessage(connection, left ? "<" : ">");
    await Future.delayed(time);
    print("stopped motor");
    BlueBroadcastHandler.instance.printMessage(connection, "V");
  }

  Future<void> takeCameraPic(
      Store<BluetoothAppState> store, Duration timeout) async {
    imageLength = 0;
    chunks.clear();
    BluetoothConnection connection = store.state.camera!;
    BlueBroadcastHandler.instance.printMessage(connection, "p$pickedImageSize");
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
    await Future.delayed(timeout);
    print("Hopefully all data was received!");
    sub.cancel();
    buildImage();
  }

  void buildImage() {
    if (chunks.isEmpty || imageLength == 0) return;
    setState(() {
      imageBytes = Uint8List(imageLength);
    });
    int offset = 0;
    for (var chunk in chunks) {
      setState(() {
        imageBytes!.setRange(offset, offset + chunk.length, chunk);
      });
      offset += chunk.length;
    }
  }
}

class MotorControlRow extends StatelessWidget {
  final Store<BluetoothAppState> store;
  const MotorControlRow({
    Key? key,
    required this.store,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () {
            BluetoothConnection? connection = store.state.motor;
            if (connection != null) {
              BlueBroadcastHandler.instance.printMessage(connection, "<");
            }
          },
          child: Text("<"),
        ),
        ElevatedButton(
          onPressed: () {
            BluetoothConnection? connection = store.state.motor;
            if (connection != null) {
              BlueBroadcastHandler.instance.printMessage(connection, "V");
            }
          },
          child: Text("V"),
        ),
        ElevatedButton(
          onPressed: () {
            BluetoothConnection? connection = store.state.motor;
            if (connection != null) {
              BlueBroadcastHandler.instance.printMessage(connection, ">");
            }
          },
          child: Text(">"),
        ),
      ],
    );
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
