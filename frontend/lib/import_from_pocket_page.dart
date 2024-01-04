import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'constants.dart';
import 'globals.dart';
import 'import_landing_page.dart';
import 'page_selector.dart';

// TODO:
// - Make tags work
// - Add ability to start from certain point
// - Handle failures
// - Add ability to pause
// - Prevent duplicate entries
class ImportFromPocketPage extends StatefulWidget {
  const ImportFromPocketPage({super.key});

  @override
  State<ImportFromPocketPage> createState() => ImportFromPocketPageState();
}

class ImportFromPocketPageState extends State<ImportFromPocketPage> {
  File? selectedFile;
  int? numImported;
  int? numToImport;
  String? currentlyImporting;

  Future<void> selectFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm'],
    );

    var path = result?.files.single.path;
    print(path);
    if (path != null) {
      setState(() {
        selectedFile = File(path);
      });
    }
  }

  Future<void> import() async {
    bool makeEncrypted =
        sharedPreferences.getBool(keySecretByDefault) ?? defaultSecretByDefault;

    var file = selectedFile!;
    var lines = await file.readAsLines();
    // The unread section comes first.
    var inUnread = true;
    List<EntryToImport> entries = [];
    for (var line in lines) {
      if (line.contains("<h1>Read Archive</h1>")) {
        inUnread = false;
        continue;
      }
      if (!line.startsWith("<li>")) {
        continue;
      }
      var link = line.split("href=\"")[1].split("\"")[0];
      // var tags = line.split("tags=\"")[1].split("\"")[0].split(",");
      List<String> tags = [];
      var archive = !inUnread;
      entries.add(EntryToImport(link: link, tags: tags, archive: archive));
    }

    setState(() {
      numToImport = entries.length;
    });

    for (var entry in entries) {
      setState(() {
        currentlyImporting = entry.link;
      });
      await listManager.addItem(
        entry.link,
        makeEncrypted,
        entry.tags,
      );
      setState(() {
        numImported = (numImported ?? 0) + 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget?> childen = [
      const Padding(padding: EdgeInsets.only(top: 20)),
      ElevatedButton(
          child: const Text(
            "Select File",
            textAlign: TextAlign.center,
          ),
          onPressed: () async {
            await selectFile();
          }),
      Text(selectedFile?.path.split(Platform.pathSeparator).last ??
          "No file selected"),
      selectedFile != null && numImported == null
          ? ElevatedButton(
              onPressed: selectedFile == null ? null : import,
              child: const Text(
                "Import",
                textAlign: TextAlign.center,
              ))
          : null,
      numImported != null
          ? Text(
              "Imported $numImported / $numToImport",
              textAlign: TextAlign.center,
            )
          : null,
      currentlyImporting != null
          ? (numImported == numToImport
              ? const Text(
                  "Done!",
                  textAlign: TextAlign.center,
                )
              : Text(
                  "Currently importing: $currentlyImporting",
                  textAlign: TextAlign.center,
                ))
          : null,
      // todo add log to show imports progress
    ];
    Widget body = Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: childen
                .where((element) => element != null)
                .map((e) => e!)
                .toList()));
    return buildTopLevelScaffold(context, body,
        title: "Import from Pocket", isSubPage: true);
  }
}
