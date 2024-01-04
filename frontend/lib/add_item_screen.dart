import 'package:aclip/js_controller.dart';
import 'package:aclip/settings_page.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'constants.dart';
import 'transaction_result_widget.dart';
import 'globals.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({this.url, super.key});

  // If this is given, we will autopopulate the link field and initiate the
  // flow to add the item to the list on the backend.
  final String? url;

  @override
  State<AddItemScreen> createState() => AddItemScreenState();
}

class AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController textController = TextEditingController();
  bool makeEncrypted =
      sharedPreferences.getBool(keySecretByDefault) ?? defaultSecretByDefault;

  Future<FullTransactionResult>? addItemFuture;

  @override
  void initState() {
    if (widget.url != null) {
      textController.text = widget.url!;
      triggerAddItem();
    }
    super.initState();
  }

  Future<void> setTextFromClipboard() async {
    var data = await Clipboard.getData(Clipboard.kTextPlain);
    setState(() {
      textController.text = data?.text ?? "";
    });
  }

  void triggerAddItem() async {
    setState(() {
      addItemFuture = listManager.addItem(
          textController.text.replaceAll("\n", " "), makeEncrypted, []);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (addItemFuture != null) {
      return buildAddItemView(addItemFuture!);
    }
    TextFormField textField = TextFormField(
      controller: textController,
      keyboardType: TextInputType.url,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: 'https://example.com/page.html',
        suffixIcon: IconButton(
          onPressed: () {
            setState(() {
              textController.text = "";
            });
          },
          icon: const Icon(Icons.clear),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Please enter a URL";
        }
        Uri? parsed = Uri.tryParse(value);
        if (parsed == null || !parsed.isAbsolute) {
          return "Please enter a valid URL";
        }
        return null;
      },
    );
    Widget fromUrlBarWidget = runningAsBrowserExtension
        ? IconButton(
            onPressed: () async {
              var url = await getCurrentUrl();
              if (url == null) {
                return;
              }
              setState(() {
                textController.text = url;
              });
            },
            icon: const Icon(Icons.link))
        : Container();
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
            key: _formKey,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text("Enter URL:"),
                const Spacer(),
                fromUrlBarWidget,
                IconButton(
                    onPressed: setTextFromClipboard, icon: const Icon(Icons.paste))
              ]),
              textField,
              const Padding(padding: EdgeInsets.only(top: 20)),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        triggerAddItem();
                      }
                    },
                    child: const Text("Add"),
                  ),
                  const Spacer(flex: 2),
                  Expanded(
                      flex: 3,
                      child: CheckboxListTile(
                          title: const Text("Encrypt this item?"),
                          value: makeEncrypted,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (bool? value) async {
                            if (value != null) {
                              if (value) {
                                // First make sure they have acknowledged the secrets caveats.
                                if (!(sharedPreferences.getBool(
                                        keyAcknowledgedSecretCaveats) ??
                                    defaultAcknowledgedSecretCaveats)) {
                                  if (!(await confirmAcknowledgedSecretsCaveats(
                                      context))) {
                                    return;
                                  }
                                }
                              }
                              setState(() {
                                makeEncrypted = value;
                              });
                            }
                          })),
                ],
              )
            ])));
  }
}

Widget buildAddItemView(Future addItemFuture) {
  return FutureBuilder(
      future: addItemFuture,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    Padding(padding: EdgeInsets.only(left: 15)),
                    Text(
                      "Adding item...",
                      style: TextStyle(fontSize: 18),
                    )
                  ]));
        }
        if (snapshot.hasError) {
          return TransactionResultWidget(FullTransactionResult(
              false, false, null, getErrorString(snapshot.error!), null));
        }
        FullTransactionResult result = snapshot.data!;
        // If the result was success and the says they don't want to see the
        // transaction page on success, just pop.
        if (result.success &&
            !(sharedPreferences.getBool(keyShowTransactionSuccessPage) ??
                defaultShowTransactionSuccessPage)) {
          Navigator.pop(context);
          return const SizedBox(width: 1, height: 1);
        }
        return TransactionResultWidget(result);
      });
}
