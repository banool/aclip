import 'package:flutter/material.dart';

import 'page_selector.dart';
import 'import_from_pocket_page.dart';

const double fontSizeLarge = 24;
const double fontSize = 17;

class ImportLandingPage extends StatelessWidget {
  const ImportLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget body = Center(
        child: Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 20, right: 32, top: 20),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.start, children: [
              ElevatedButton(
                  child: const Text(
                    "Import from Pocket",
                    textAlign: TextAlign.center,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ImportFromPocketPage(),
                        ));
                  }),
            ])));
    return buildTopLevelScaffold(context, body,
        title: "Import Data", isSubPage: true);
  }
}

// TODO: It should be possible to set the added timestamp too.
class EntryToImport {
  String link;
  List<String> tags;
  bool archive;

  @override
  String toString() {
    return "EntryToImport(link: $link, tags: $tags, archive: $archive)";
  }

  EntryToImport(
      {required this.link, this.tags = const [], required this.archive});
}
