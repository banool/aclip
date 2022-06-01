import 'package:aclip/globals.dart';
import 'package:aclip/page_selector.dart';
import 'package:flutter/material.dart';

import 'add_item_screen.dart';

class ListPage extends StatefulWidget {
  const ListPage({Key? key}) : super(key: key);

  @override
  State<ListPage> createState() => ListPageState();
}

class ListPageState extends State<ListPage> {
  Future<void> initiateAddItemFlow(BuildContext context) async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return FractionallySizedBox(
              heightFactor: 0.85, child: AddItemScreen());
        });
    await listManager.pull();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> appBarActions = [
      IconButton(
          onPressed: () async => await initiateAddItemFlow(context),
          icon: Icon(Icons.add))
    ];
    return buildTopLevelScaffold(context, Text("list page"),
        title: "My List", appBarActions: appBarActions);
  }
}
