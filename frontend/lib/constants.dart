import 'package:aptos_sdk_dart/hex_string.dart';
import 'package:flutter/material.dart';

const String appTitle = "aclip";

const Color mainColor = Colors.indigo;

// Constants for the move module.
HexString moduleAddress = HexString.fromString(
    "c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd");
const String moduleName = "RootV4";

// Shared preferences keys.
const String keyAptosNodeUrl = "keyAptosNodeUrl";
const String keyPrivateKey = "keyPrivateKey";
const String keySecretByDefault = "keySecretByDefault";
const String keyLaunchInExternalBrowser = "keyLaunchInExternalBrowser";

// Shared preferences defaults.
const String defaultAptosNodeUrl = "https://fullnode.devnet.aptoslabs.com";
const String? defaultPrivateKey = null;
const bool defaultSecretByDefault = false;
const bool defaultLaunchInExternalBrowser = true;
