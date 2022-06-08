import 'dart:io';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:integration_test/src/channel.dart';

import 'package:aclip/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// This function handles all the specifics around taking screenshots
// under Android. Note, sometimes the test will crash at the end, but the
// screenshots do actually still get taken.
Future<void> takeScreenshotForAndroid(
    IntegrationTestWidgetsFlutterBinding binding, String name) async {
  await integrationTestChannel.invokeMethod<void>(
    'convertFlutterSurfaceToImage',
    null,
  );
  binding.reportData ??= <String, dynamic>{};
  binding.reportData!['screenshots'] ??= <dynamic>[];
  integrationTestChannel.setMethodCallHandler((MethodCall call) async {
    switch (call.method) {
      case 'scheduleFrame':
        PlatformDispatcher.instance.scheduleFrame();
        break;
    }
    return null;
  });
  final List<int>? rawBytes =
      await integrationTestChannel.invokeMethod<List<int>>(
    'captureScreenshot',
    <String, dynamic>{'name': name},
  );
  if (rawBytes == null) {
    throw StateError(
        'Expected a list of bytes, but instead captureScreenshot returned null');
  }
  final Map<String, dynamic> data = {
    'screenshotName': name,
    'bytes': rawBytes,
  };
  assert(data.containsKey('bytes'));
  (binding.reportData!['screenshots'] as List<dynamic>).add(data);

  await integrationTestChannel.invokeMethod<void>(
    'revertFlutterImage',
    null,
  );
}

// Take a screenshot, handling Android specially.
Future<void> takeScreenshot(
    WidgetTester tester,
    IntegrationTestWidgetsFlutterBinding binding,
    ScreenshotNameInfo screenshotNameInfo,
    String name,
    {String locale = "en-US"}) async {
  name = "${screenshotNameInfo.platformName}/$locale/"
      "${screenshotNameInfo.deviceName}-${screenshotNameInfo.physicalScreenSize}-"
      "${screenshotNameInfo.getAndIncrementCounter().toString().padLeft(2, '0')}-"
      "$name";
  await tester.pumpAndSettle();
  sleep(const Duration(milliseconds: 250));
  if (Platform.isAndroid) {
    await takeScreenshotForAndroid(binding, name);
  } else {
    await binding.takeScreenshot(name);
  }
  // ignore: avoid_print
  print("Took screenshot: $name");
}

class ScreenshotNameInfo {
  String platformName;
  String deviceName;
  String physicalScreenSize;
  int counter = 1;

  ScreenshotNameInfo(
      {required this.platformName,
      required this.deviceName,
      required this.physicalScreenSize});

  int getAndIncrementCounter() {
    int out = counter;
    counter += 1;
    return out;
  }

  static Future<ScreenshotNameInfo> buildScreenshotNameInfo() async {
    Size size = window.physicalSize;
    String physicalScreenSize = "${size.width.toInt()}x${size.height.toInt()}";

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    String platformName;
    String deviceName;
    if (Platform.isAndroid) {
      platformName = "android";
      AndroidDeviceInfo info = await deviceInfo.androidInfo;
      deviceName = info.product!;
    } else if (Platform.isIOS) {
      platformName = "ios";
      IosDeviceInfo info = await deviceInfo.iosInfo;
      deviceName = info.name!;
    } else {
      throw "Unsupported platform";
    }

    return ScreenshotNameInfo(
        platformName: platformName,
        deviceName: deviceName,
        physicalScreenSize: physicalScreenSize);
  }
}

void main() async {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets("takeScreenshots", (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    PackageInfo.setMockInitialValues(
        appName: "whatever",
        packageName: "whatever",
        version: "1.0.0",
        buildNumber: "1",
        buildSignature: "whatever");

    await setup(pull: false);

    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle(Duration(seconds: 2));

    var screenshotNameInfo = await ScreenshotNameInfo.buildScreenshotNameInfo();

    await takeScreenshot(tester, binding, screenshotNameInfo, "loginPage");

    final Finder enterPrviateKeyButton =
        find.byKey(ValueKey("enterPrivateKeyButton"));
    await tester.tap(enterPrviateKeyButton);
    await tester.pumpAndSettle();

    final Finder enterPrivateKeyField = find.byKey(ValueKey("myTextField"));
    await tester.tap(enterPrivateKeyField);
    await tester.pumpAndSettle();
    await tester.enterText(enterPrivateKeyField,
        "0x257e96d2d763967d72d34d90502625c2d9644401aa409fa3f5e9d6cc59095f9b");
    await tester.pumpAndSettle();
    final Finder continueButton = find.byKey(ValueKey("continueButton"));
    await tester.tap(continueButton);

    await tester.pumpAndSettle(Duration(seconds: 5));

    await takeScreenshot(tester, binding, screenshotNameInfo, "listPage");

    final Finder settingsNavBarButton = find.byIcon(Icons.settings);
    await tester.tap(settingsNavBarButton);
    await tester.pumpAndSettle();
    await takeScreenshot(tester, binding, screenshotNameInfo, "settingsPage");
  });
}
