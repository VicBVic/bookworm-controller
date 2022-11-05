import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:google_ml_kit_example/redux/bluetooth_state.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'camera_view.dart';
import 'painters/text_detector_painter.dart';

class TextRecognizerView extends StatefulWidget {
  @override
  _TextRecognizerViewState createState() => _TextRecognizerViewState();
}

class _TextRecognizerViewState extends State<TextRecognizerView> {
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  double confidence = 0;

  @override
  void dispose() async {
    _canProcess = false;
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder<BluetoothAppState>(builder: (context, store) {
      return CameraView(
        title: 'Text Detector',
        botText: Text(
          "Found book ${store.state.lookingForBook} with confidence: $confidence",
          style: TextStyle(color: Colors.green),
        ),
        customPaint: _customPaint,
        text: _text,
        onImage: (inputImage) {
          processImage(inputImage, store);
        },
      );
    });
  }

  Future<void> processImage(
      InputImage inputImage, Store<BluetoothAppState> store) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final recognizedText = await _textRecognizer.processImage(inputImage);
    _text = 'Recognized text:\n\n${recognizedText.text}';
    setState(() {
      confidence =
          getFuzzyMatch(recognizedText.text, store.state.lookingForBook);
    });
    _customPaint = null;
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  double getFuzzyMatch(String main, String pattern) {
    Fuzzy fuzzy = Fuzzy(main.split(' '),
        options: FuzzyOptions(tokenize: false, threshold: 0.5));

    print("ers ${fuzzy.list} $pattern");
    final res = fuzzy.search(pattern);
    double resultt = 0;
    for (var r in res) {
      print("res res ${r.score} ${r.item}");
      resultt = max(resultt, r.score + 0.5);
    }
    return resultt;
  }
}
