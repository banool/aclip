// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:aclip/common.dart';
import 'package:aclip/constants.dart';
import 'package:aclip/list_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aclip/main.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pinenacl/x25519.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('test signing stuff', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      keyPrivateKey:
          "0x257e96d2d763967d72d34d90502625c2d9644401aa409fa3f5e9d6cc59095f9b"
    });

    PackageInfo.setMockInitialValues(
        appName: "whatever",
        packageName: "whatever",
        version: "1.0.0",
        buildNumber: "1",
        buildSignature: "whatever");

    await setup(pull: false);

    await tester.pumpWidget(const MyApp());

    String url = "https://google.com";

    SecretBox secretBox = SecretBox(getPrivateKey()!.toBytes());

    var encrypted = myEncryptWithSecretBox(secretBox, url);
    var decrypted = myDecryptWithSecretBox(secretBox, encrypted);

    expect(url, decrypted);

    LinkData linkData = LinkData(archived: true, secret: true);

    var encryptedLinkData = linkData.encrypt(secretBox);
    var decryptedLinkData = LinkData.decrypt(secretBox, encryptedLinkData);

    expect(decryptedLinkData.archived, true);
    expect(decryptedLinkData.secret, true);
  });
}
