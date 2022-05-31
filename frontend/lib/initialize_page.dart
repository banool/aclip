import 'package:aclip/page_selector.dart';
import 'package:flutter/material.dart';

const double fontSizeLarge = 24;
const double fontSize = 17;

class InitializePage extends StatefulWidget {
  const InitializePage({Key? key, required this.error}) : super(key: key);

  final Object error;

  @override
  State<InitializePage> createState() => InitializePageState();
}

class InitializePageState extends State<InitializePage> {
  Future<void> onPressed() async {}

  @override
  Widget build(BuildContext context) {
    Widget body = Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Initialize your list",
              style: TextStyle(
                  fontSize: fontSizeLarge, fontWeight: FontWeight.w700),
            ),
            Padding(padding: EdgeInsets.only(top: 30)),
            Text(
              "Before using aclip, you must initialize a list on your account. "
              "Creating your list, as well as adding and removing items from it, "
              "will cost gas. The Aptos network isn't like other blockchains, "
              "each action should only cost you a fraction of a cent, but this "
              "is the cost of taking control of your own data",
              style: TextStyle(fontSize: fontSize),
            ),
            Padding(padding: EdgeInsets.only(top: 50)),
            ElevatedButton(
                onPressed: onPressed,
                child: Text(
                  "Initialize list",
                  style: TextStyle(fontSize: fontSize),
                )),
          ],
        ));
    return buildTopLevelScaffold(context, body, title: "Setup");
  }
}
