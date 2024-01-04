import 'dart:collection';

import 'package:flutter/material.dart';

import 'globals.dart';
import 'page_selector.dart';

class DownloadLogsPage extends StatelessWidget {
  const DownloadLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget body;
    LinkedHashMap<String, Object> errors = LinkedHashMap();
    downloadManager.urlToDownloadMetadata.forEach((key, value) {
      var error = value?.error;
      if (error != null) {
        errors[key] = error;
      }
    });
    if (errors.isEmpty) {
      body = const Center(child: Text("All is well!"));
    } else {
      body = ListView.builder(
          itemCount: errors.length,
          itemBuilder: (context, index) {
            MapEntry<String, Object> e = errors.entries.elementAt(index);
            return Card(
              child: ListTile(
                title: Text(e.key),
                subtitle: Text("${e.value}"),
                isThreeLine: true,
              ),
            );
          });
    }
    return buildTopLevelScaffold(context, body,
        title: "Offline download error logs", isSubPage: true);
  }
}
