import 'package:aclip/common.dart';
import 'package:flutter/material.dart';

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
