import 'package:aptos_sdk_dart/hex_string.dart';
import 'package:flutter/material.dart';

const String appTitle = "aclip";

const Color mainColor = Colors.indigo;

// Constants for the move module.
HexString moduleAddress = HexString.fromString(
    "b078d693856a65401d492f99ca0d6a29a0c5c0e371bc2521570a86e40d95f823");
const String moduleName = "aclip";
const String structName = "Root";

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
const String defaultAptosNodeUrl = "https://fullnode.testnet.aptoslabs.com";
const String? defaultPrivateKey = null;
const bool defaultSecretByDefault = false;
const bool defaultLaunchInExternalBrowser = false;
const bool defaultForceHttpsOnly = false;
const bool defaultShowTransactionSuccessPage = false;
const bool defaultOnlyOfflineLinks = false;
const bool defaultSaveOnOpen = true;
const bool defaultAcknowledgedSecretCaveats = false;
