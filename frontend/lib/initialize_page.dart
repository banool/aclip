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
      } catch (e) {
        print("Pulling after initialize failed: $e");
      }
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
            if (snapshot.connectionState != ConnectionState.done) {
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
            }
            if (snapshot.hasError) {
              return Text("Unexpected error: ${snapshot.error}");
            }
            TransactionResult transactionResult = snapshot.data!;
            if (transactionResult.success) {
              throw "Unexpected success state on this page";
            }
            return TransactionResultWidget(transactionResult);
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
              "each action should only cost you a fraction of a cent, but this "
              "is the cost of taking control of your own data",
              style: TextStyle(fontSize: fontSize),
            ),
            Padding(padding: EdgeInsets.only(top: 50)),
            lower,
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
              textAlign: TextAlign.center,
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
