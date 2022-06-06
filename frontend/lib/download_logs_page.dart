import 'dart:collection';

import 'package:aclip/globals.dart';
import 'package:flutter/material.dart';

import 'download_manager.dart';
import 'page_selector.dart';

class DownloadLogsPage extends StatelessWidget {
  const DownloadLogsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget body;
    LinkedHashMap<String, Object> errors = LinkedHashMap();
    downloadManager.urlToDownloadStatus.forEach((key, DownloadStatus value) {
      if (value.error != null) {
        errors[key] = value.error!;
      }
    });
    if (errors.isEmpty) {
      body = Center(child: Text("All is well!"));
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
