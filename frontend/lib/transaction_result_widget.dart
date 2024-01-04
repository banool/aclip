import 'package:aptos_sdk_dart/aptos_client_helper.dart';
import 'package:flutter/material.dart';

class TransactionResultWidget extends StatelessWidget {
  final FullTransactionResult transactionResult;

  const TransactionResultWidget(this.transactionResult, {super.key});

  @override
  Widget build(BuildContext context) {
    String resultsHeaderString =
        transactionResult.committed ? "Success" : "Error";
    List<Widget> textBodyChildren = [];
    if (transactionResult.transaction != null) {
      textBodyChildren += [
        const Text(
          "Transaction",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const Divider(
          indent: 100,
          endIndent: 100,
        ),
        Text(transactionResult.transaction!.toString()),
        const Divider(height: 50),
        const Padding(
          padding: EdgeInsets.only(top: 20),
        )
      ];
    }
    if (transactionResult.errorString != null) {
      textBodyChildren += [
        const Text("Error", style: TextStyle(fontWeight: FontWeight.w500)),
        const Divider(
          indent: 100,
          endIndent: 100,
        ),
        Text(transactionResult.errorString!),
      ];
      if (transactionResult.failedAt != null) {
        textBodyChildren += [
          const Padding(padding: EdgeInsets.only(top: 20)),
          Text("Failed at: ${transactionResult.failedAt}"),
        ];
      }
    }
    Widget body = Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              resultsHeaderString,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const Divider(height: 50),
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
