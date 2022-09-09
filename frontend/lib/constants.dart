import 'package:aptos_sdk_dart/hex_string.dart';
import 'package:flutter/material.dart';

const String appTitle = "aclip";

const Color mainColor = Colors.indigo;

// Constants for the move module.
HexString moduleAddress = HexString.fromString(
    "3c769ea16f38fdc218341c63ff8c1c5c7dcbb4d5d850675e92b09997fd36e8f0");
const String moduleName = "root";

// Shared preferences keys.
const String keyAptosNodeUrl = "keyAptosNodeUrl";
const String keyPrivateKey = "keyPrivateKey";
const String keySecretByDefault = "keySecretByDefault";
const String keyLaunchInExternalBrowser = "keyLaunchInExternalBrowser";
const String keyForceHttpsOnly = "keyForceHttpsOnly";
const String keyShowTransactionSuccessPage = "keyShowTransactionSuccessPage";
const String keyOnlyOfflineLinks = "keyOnlyOfflineLinks";
const String keySaveOnOpen = "keySaveOnOpen";
const String keyCachedUrls = "keyCachedUrls";
const String keyAcknowledgedSecretCaveats = "keyAcknowledgedSecretCaveats";

// Shared preferences defaults.
const String defaultAptosNodeUrl = "https://testnet.aptoslabs.com/v1";
const String? defaultPrivateKey = null;
const bool defaultSecretByDefault = false;
const bool defaultLaunchInExternalBrowser = true;
const bool defaultForceHttpsOnly = false;
const bool defaultShowTransactionSuccessPage = false;
const bool defaultOnlyOfflineLinks = false;
const bool defaultSaveOnOpen = true;
const bool defaultAcknowledgedSecretCaveats = false;
