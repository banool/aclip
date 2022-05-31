import 'package:aclip/globals.dart';
import 'package:aclip/list_manager.dart';
import 'package:aclip/page_selector.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';
import 'settings_page.dart';

const double fontSizeLarge = 24;
const double fontSize = 17;

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  Future<void> onPressed() async {
    print("Awaiting private key");
    bool confirmed = await showChangeStringSharedPrefDialog(
        context, "Private key", keyPrivateKey, defaultPrivateKey,
        validateFn: (String value) {
      try {
        // TODO: Buff HexString.fromString so it does this check.
        var hexString = HexString.fromString(value);
        AptosAccount.fromPrivateKeyHexString(hexString);
        print("Private key was valid");
        return true;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Private key was invalid: $e"),
        ));
        return false;
      }
    });
    if (confirmed) {
      print("Private key set");
      listManager = ListManager.fromSharedPrefs();
      try {
        await listManager.triggerPull();
        print("Pulled list successfully");
      } catch (e) {
        print(
            "Failed to pull after setting private key, this is probably expected: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body = Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome to aclip!",
              style: TextStyle(
                  fontSize: fontSizeLarge, fontWeight: FontWeight.w700),
            ),
            Padding(padding: EdgeInsets.only(top: 30)),
            Text(
              "aclip is a bookmarking app powered by the Aptos Blockchain. "
              "In order to use aclip you must have an account on Aptos. ",
              style: TextStyle(fontSize: fontSize),
            ),
            Padding(padding: EdgeInsets.only(top: 50)),
            Text(
              "I need to make an account:",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            Padding(padding: EdgeInsets.only(top: 20)),
            InkWell(
              child: Text(
                "Create an Aptos account",
                style: TextStyle(color: Colors.blue, fontSize: fontSize),
              ),
              onTap: () => launchUrl(Uri.parse(
                  "https://aptos.dev/tutorials/building-wallet-extension")),
            ),
            Padding(padding: EdgeInsets.only(top: 50)),
            Text(
              "I already have an account:",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            Padding(padding: EdgeInsets.only(top: 20)),
            ElevatedButton(
                onPressed: onPressed,
                child: Text(
                  "Enter private key",
                  style: TextStyle(fontSize: fontSize),
                )),
          ],
        ));
    return buildTopLevelScaffold(context, body, title: "Setup");
  }
}
