import 'package:aclip/common.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'list_manager.dart';
import 'page_selector.dart';
import 'globals.dart';

Future<void> setup() async {
  print("Setup starting");

  WidgetsFlutterBinding.ensureInitialized();

  // Load shared preferences. We do this first because later things we
  // initialize here depend on its values.
  sharedPreferences = await SharedPreferences.getInstance();

  HexString? privateKey = getPrivateKey();
  if (privateKey != null) {
    listManager = ListManager.fromSharedPrefs();
    listManager.triggerPull();
  }

  packageInfo = await PackageInfo.fromPlatform();

  print("Setup finished");
}

Future<void> main() async {
  await setup();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: mainColor as MaterialColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: "Raleway",
      ),
      home: const PageSelector(),
    );
  }
}
