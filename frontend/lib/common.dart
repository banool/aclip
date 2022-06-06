import 'dart:io';

import 'package:aclip/constants.dart';
import 'package:aclip/globals.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

HexString? getPrivateKey() {
  var raw = sharedPreferences.getString(keyPrivateKey);
  if (raw == null) {
    return null;
  }
  return HexString.fromString(raw);
}

class TransactionResult {
  bool success;
  $UserTransactionRequest? transaction;
  String? errorString;

  TransactionResult(this.success, this.transaction, this.errorString);

  @override
  String toString() {
    return "Success: $success, Transaction: $transaction, Error: $errorString";
  }
}

String getErrorString(Object error) {
  if (error is DioError) {
    return "Type: ${error.type}\n"
        "Message: ${error.message}\n"
        "Response: ${error.response}\n"
        "Error: ${error.error}";
  }
  return "$error";
}

Future<void> showErrorInDialog(BuildContext context, Object error) async {
  await myShowDialog(context, Text(getErrorString(error)));
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
