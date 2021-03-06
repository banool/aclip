import 'package:aclip/js_controller.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'constants.dart';
import 'transaction_result_widget.dart';
import 'globals.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({this.url, Key? key}) : super(key: key);

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

  Future? addItemFuture;

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

  void triggerAddItem() {
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
          icon: Icon(Icons.clear),
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
            icon: Icon(Icons.link))
        : Container();
    return Padding(
        padding: EdgeInsets.all(20),
        child: Form(
            key: _formKey,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text("Enter URL:"),
                Spacer(),
                fromUrlBarWidget,
                IconButton(
                    onPressed: setTextFromClipboard, icon: Icon(Icons.paste))
              ]),
              textField,
              Padding(padding: EdgeInsets.only(top: 20)),
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
                  Spacer(flex: 2),
                  Expanded(
                      flex: 3,
                      child: CheckboxListTile(
                          title: Text("Encrypt this item?"),
                          value: makeEncrypted,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value != null) {
                                makeEncrypted = value;
                              }
                            });
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
          return Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
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
              false, null, getErrorString(snapshot.error!), null));
        }
        if (!(sharedPreferences.getBool(keyShowTransactionSuccessPage) ??
            defaultShowTransactionSuccessPage)) {
          Navigator.pop(context);
          return SizedBox(width: 1, height: 1);
        }
        return TransactionResultWidget(snapshot.data!);
      });
}
