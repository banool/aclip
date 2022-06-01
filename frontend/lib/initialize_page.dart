import 'package:aclip/common.dart';
import 'package:aclip/globals.dart';
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
  Future? onPressedFuture;

  Future<TransactionResult> initializeList() async {
    var result = await listManager.initializeList();
    if (result.success) {
      try {
        await listManager.triggerPull();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Successfully initialized list!"),
        ));
        InheritedPageSelectorController.of(context)
            .pageSelectorController
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
          child: Text(
            "Initialize list",
            style: TextStyle(fontSize: fontSize),
          ));
    } else {
      lower = FutureBuilder(
          future: onPressedFuture,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            return Row(
              children: const [
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
              "each action should only cost a fraction of a cent, but "
              "understand that there is a small cost to taking control "
              "of your own data.",
              style: TextStyle(fontSize: fontSize),
            ),
            Padding(padding: EdgeInsets.only(top: 40)),
            lower,
            Padding(padding: EdgeInsets.only(top: 40)),
            Text(
              "I have already initialized a list:",
              style: TextStyle(
                fontSize: fontSize - 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            Padding(padding: EdgeInsets.only(top: 20)),
            Text(
              "If you're confident you have already initialized a list, this "
              "indicates a bug in the app. See the error here from checking "
              "whether you already have a list and getting its content.",
              style: TextStyle(fontSize: fontSize - 3),
            ),
            Padding(padding: EdgeInsets.only(top: 10)),
            ElevatedButton(
                onPressed: () async =>
                    await showErrorInDialog(context, widget.error),
                style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                        Color.fromARGB(255, 181, 29, 29))),
                child: Text(
                  "See error",
                  style: TextStyle(fontSize: fontSize - 2),
                ))
          ],
        ));
    return buildTopLevelScaffold(context, body, title: "Setup");
  }
}

class TransactionResultWidget extends StatelessWidget {
  final TransactionResult transactionResult;

  const TransactionResultWidget(this.transactionResult, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    String resultsHeaderString =
        transactionResult.success ? "🤠  Success  🤠" : "😢  Error  😢";
    List<Widget> textBodyChildren = [];
    if (transactionResult.transaction != null) {
      textBodyChildren += [
        Text(
          "Transaction",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        Divider(
          indent: 100,
          endIndent: 100,
        ),
        Text(transactionResult.transaction!.toString()),
        Divider(height: 50),
        Padding(
          padding: EdgeInsets.only(top: 20),
        )
      ];
    }
    if (transactionResult.errorString != null) {
      textBodyChildren += [
        Text("Error", style: TextStyle(fontWeight: FontWeight.w500)),
        Divider(
          indent: 100,
          endIndent: 100,
        ),
        Text(transactionResult.errorString!)
      ];
    }
    Widget body = Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              resultsHeaderString,
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            Divider(height: 50),
            Expanded(
                child: SingleChildScrollView(
                    child: Column(
              children: textBodyChildren,
            ))),
          ],
        ));
    return body;
  }
}
