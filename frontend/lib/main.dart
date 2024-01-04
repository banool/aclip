
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'common.dart';
import 'constants.dart';
import 'download_manager.dart';
import 'list_manager.dart';
import 'page_selector.dart';
import 'globals.dart';

Future<void> setup({bool pull = true, setupDownloadDirectory = true}) async {
  print("Setup starting");

  WidgetsFlutterBinding.ensureInitialized();

  if (const String.fromEnvironment("IS_BROWSER_EXTENSION").isNotEmpty) {
    runningAsBrowserExtension = true;
    print("Running as browser extension");
  }

  // Load shared preferences. We do this first because later things we
  // initialize here depend on its values.
  sharedPreferences = await SharedPreferences.getInstance();

  downloadManager = DownloadManager();

  if (setupDownloadDirectory && !kIsWeb) {
    downloadsDirectory = (await getApplicationDocumentsDirectory()).path;
  }

  HexString? privateKey = getPrivateKey();
  if (privateKey != null) {
    listManager = ListManager.fromSharedPrefs();
    if (pull) {
      listManager.triggerPull();
    }
  }

  if (!runningAsBrowserExtension) {
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (e) {
      print("Failed to get package info, continuing: $e");
      packageInfoRetrieveError = e;
    }
  } else {
    packageInfoRetrieveError = "Running as browser extension";
  }

  /*
  if (!kIsWeb && Platform.isAndroid) {
    WebView.platform = SurfaceAndroidWebView();
  }
  */

  print("Setup finished");
}

Future<void> main() async {
  await setup();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
      ),
      theme: ThemeData(
        primarySwatch: mainColor as MaterialColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: "Raleway",
      ),
      themeMode: ThemeMode.system,
      home: const PageSelector(),
    );
  }
}
