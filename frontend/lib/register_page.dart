import 'package:aclip/common.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'page_selector.dart';
import 'settings_page.dart';

const double fontSizeLarge = 24;
const double fontSize = 17;

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  @override
  Widget build(BuildContext context) {
    Widget body = Padding(
        padding: EdgeInsets.all(30),
        child: getScrollableColumn(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome to aclip!",
              style: TextStyle(
                  fontSize: fontSizeLarge, fontWeight: FontWeight.w700),
            ),
            Padding(padding: EdgeInsets.only(top: 25)),
            Text(
              "aclip is a bookmarking app powered by the Aptos Blockchain. "
              "In order to use aclip you must have an account on Aptos. ",
              style: TextStyle(fontSize: fontSize),
            ),
            Padding(padding: EdgeInsets.only(top: 25)),
            Text(
              "I already have an account:",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            Padding(padding: EdgeInsets.only(top: 15)),
            ElevatedButton(
                key: ValueKey("enterPrivateKeyButton"),
                onPressed: () async => await runUpdatePrivateKeyDialog(context),
                child: Text(
                  "Enter private key",
                  style: TextStyle(fontSize: fontSize),
                )),
            Padding(padding: EdgeInsets.only(top: 25)),
            Text(
              "I need to make an account:",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            Padding(padding: EdgeInsets.only(top: 15)),
            InkWell(
              child: Text(
                "Create an Aptos account",
                style: TextStyle(color: Colors.blue, fontSize: fontSize),
              ),
              onTap: () => launchUrl(Uri.parse(
                  "https://aptos.dev/cli-tools/aptos-cli-tool/use-aptos-cli#initialize-local-configuration-and-create-an-account")),
            ),
          ],
        )));
    return buildTopLevelScaffold(context, body, title: "Setup");
  }
}
