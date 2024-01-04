import 'package:aclip/list_manager.dart';
import 'package:aptos_sdk_dart/hex_string.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'common.dart';
import 'globals.dart';
import 'initialize_page.dart';
import 'list_page.dart';
import 'page_selector.dart';
import 'register_page.dart';

class ListPageSelector extends StatefulWidget {
  const ListPageSelector({super.key});

  @override
  State<ListPageSelector> createState() => ListPageSelectorState();
}

class ListPageSelectorState extends State<ListPageSelector> {
  @override
  Widget build(BuildContext context) {
    HexString? privateKey = getPrivateKey();
    if (privateKey == null) {
      return const RegisterPage();
    } else {
      return Consumer(builder: ((context, FetchDataDummy? dummy, _) {
        print("Building consumer arm of ListPageSelector");
        // Future not complete yet.
        if (dummy == null) {
          return buildTopLevelScaffold(
              context, const Center(child: CircularProgressIndicator()),
              title: "Loading");
        }

        if (dummy.error != null) {
          print("Fetch data future error: ${dummy.error}");
          return InitializePage(error: dummy.error!);
        }

        if (listManager.links == null) {
          print("No links yet for some reason");
          return InitializePage(error: Error());
        }

        return const ListPage();
      }));
    }
  }
}
