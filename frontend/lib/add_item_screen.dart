import 'package:aclip/constants.dart';
import 'package:aclip/transaction_result_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'common.dart';
import 'globals.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({Key? key}) : super(key: key);

  @override
  State<AddItemScreen> createState() => AddItemScreenState();
}

class AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController textController = TextEditingController();
  bool makeEncrypted =
      sharedPreferences.getBool(keySecretByDefault) ?? defaultSecretByDefault;

  Future? addItemFuture;

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
    return Padding(
        padding: EdgeInsets.all(20),
        child: Form(
            key: _formKey,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text("Enter URL:"),
                Spacer(),
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
                    child: const Text('Add'),
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
          return TransactionResultWidget(
              TransactionResult(false, null, getErrorString(snapshot.error!)));
        }
        return TransactionResultWidget(snapshot.data!);
      });
}
