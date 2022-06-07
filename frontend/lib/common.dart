import 'dart:io';

import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:flutter/material.dart';

import 'constants.dart';
import 'globals.dart';

HexString? getPrivateKey() {
  var raw = sharedPreferences.getString(keyPrivateKey);
  if (raw == null) {
    return null;
  }
  return HexString.fromString(raw);
}

Future<void> showErrorInDialog(BuildContext context, Object error) async {
  await myShowDialog(context, Text(getErrorString(error)!));
}

Future<void> myShowDialog(BuildContext context, Widget body,
    {String title = "Error"}) async {
  AlertDialog alert = AlertDialog(
    title: Text(title),
    content: body,
  );
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}

Future<bool> canConnectToInternet() async {
  try {
    final result = await InternetAddress.lookup('example.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  }
}
