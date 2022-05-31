import 'package:aclip/constants.dart';
import 'package:aclip/globals.dart';
import 'package:aptos_sdk_dart/hex_string.dart';

HexString? getPrivateKey() {
  var raw = sharedPreferences.getString(keyPrivateKey);
  if (raw == null) {
    return null;
  }
  return HexString.fromString(raw);
}
