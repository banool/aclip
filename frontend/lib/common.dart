import 'package:aclip/constants.dart';
import 'package:aclip/globals.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';

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
