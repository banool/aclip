import 'package:aptos_sdk_dart/hex_string.dart';
import 'package:flutter/material.dart';

import 'common.dart';
import 'globals.dart';
import 'initialize_page.dart';
import 'list_page.dart';
import 'page_selector.dart';
import 'register_page.dart';

class ListPageSelector extends StatefulWidget {
  const ListPageSelector({Key? key}) : super(key: key);

  @override
  State<ListPageSelector> createState() => ListPageSelectorState();
}

class ListPageSelectorState extends State<ListPageSelector> {
  @override
  Widget build(BuildContext context) {
    HexString? privateKey = getPrivateKey();
    if (privateKey == null) {
      return RegisterPage();
    } else {
      return FutureBuilder(
          future: listManager.fetchDataFuture,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return buildTopLevelScaffold(
                  context, Center(child: CircularProgressIndicator()),
                  title: "Loading");
            }
            if (snapshot.hasError || listManager.links == null) {
              print(
                  "Fetch data future error or we're offline and there are no links offlined: ${snapshot.error}");
              return InitializePage(error: snapshot.error ?? Error());
            }
            return ListPage();
          });
    }
  }
}
