import 'package:flutter/material.dart';

Future<T?> showView<T>(BuildContext context, Widget view) async {
  return await Navigator.push<T>(
      context, MaterialPageRoute(builder: (c) => view));
}
