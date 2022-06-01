import 'package:aclip/common.dart';
import 'package:aclip/globals.dart';
import 'package:aclip/initialize_page.dart';
import 'package:aclip/page_selector.dart';
import 'package:aclip/register_page.dart';
import 'package:aptos_sdk_dart/hex_string.dart';
import 'package:flutter/material.dart';

import 'list_page.dart';

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
      print(listManager.fetchDataFuture);
      print("kljsdflkdskjfl");
      return FutureBuilder(
          future: listManager.fetchDataFuture,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return buildTopLevelScaffold(
                  context, Center(child: CircularProgressIndicator()),
                  title: "Loading");
            }
            if (snapshot.hasError) {
              return InitializePage(error: snapshot.error!);
            }
            return ListPage();
          });
    }
  }
}
