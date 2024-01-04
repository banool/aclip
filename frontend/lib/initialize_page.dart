import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'globals.dart';
import 'common.dart';
import 'page_selector.dart';
import 'transaction_result_widget.dart';

const double fontSizeLarge = 24;
const double fontSize = 17;

class InitializePage extends StatefulWidget {
  const InitializePage({super.key, required this.error});

  final Object error;

  @override
  State<InitializePage> createState() => InitializePageState();
}

class InitializePageState extends State<InitializePage> {
  Future? onPressedFuture;

  Future<FullTransactionResult> initializeList() async {
    FullTransactionResult result = await listManager.initializeList();
    if (result.committed) {
      try {
        await listManager.triggerPull();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Successfully initialized list!"),
        ));
        Provider.of<PageSelectorController>(context, listen: false)
            .refreshParent();
      } catch (e) {
        print("Pulling after initialize failed: $e");
        showErrorInDialog(context, e);
        setState(() {
          onPressedFuture = null;
        });
      }
    } else {
      await myShowDialog(context, TransactionResultWidget(result));
      setState(() {
        onPressedFuture = null;
      });
    }
    return result;
  }

  Future<void> triggerInitializeList() async {
    setState(() {
      onPressedFuture = initializeList();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget lower;
    if (onPressedFuture == null) {
      lower = ElevatedButton(
          onPressed: triggerInitializeList,
          child: const Text(
            "Initialize list",
            style: TextStyle(fontSize: fontSize),
          ));
    } else {
      lower = FutureBuilder(
          future: onPressedFuture,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            return const Row(
              children: [
                CircularProgressIndicator(),
                Padding(padding: EdgeInsets.only(left: 20)),
                Text(
                  "Initializing list...",
                  style: TextStyle(fontSize: fontSize),
                ),
              ],
            );
          });
    }
    Widget body = Padding(
        padding: const EdgeInsets.all(30),
        child: getScrollableColumn(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Initialize your list",
              style: TextStyle(
                  fontSize: fontSizeLarge, fontWeight: FontWeight.w700),
            ),
            const Padding(padding: EdgeInsets.only(top: 25)),
            const Text(
              "Before using aclip, you must initialize a list on your account. "
              "Creating your list, as well as adding and removing items from it, "
              "will cost gas. The Aptos network isn't like other blockchains, "
              "each action should only cost a fraction of a cent, but "
              "understand that there is a small cost to taking control "
              "of your own data.",
              style: TextStyle(fontSize: fontSize),
            ),
            const Padding(padding: EdgeInsets.only(top: 30)),
            lower,
            const Padding(padding: EdgeInsets.only(top: 30)),
            const Text(
              "I have already initialized a list:",
              style: TextStyle(
                fontSize: fontSize - 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Padding(padding: EdgeInsets.only(top: 20)),
            const Text(
              "If you're confident you have already initialized a list, this "
              "indicates a bug in the app. See the error here from checking "
              "whether you already have a list and getting its content.",
              style: TextStyle(fontSize: fontSize - 3),
            ),
            const Padding(padding: EdgeInsets.only(top: 20)),
            ElevatedButton(
                onPressed: () async =>
                    await showErrorInDialog(context, widget.error),
                style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                        const Color.fromARGB(255, 181, 29, 29))),
                child: const Text(
                  "See error",
                  style: TextStyle(fontSize: fontSize - 2),
                ))
          ],
        )));
    return buildTopLevelScaffold(context, body, title: "Setup");
  }
}
