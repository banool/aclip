// I need this to avoid build errors on web.
// https://stackoverflow.com/questions/70565611/how-to-ignore-package-when-building-flutter-project-for-web

import 'dart:convert';

import 'package:aclip/globals.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';

export 'download_manager_mobile.dart'
    if (dart.library.html) 'download_manager_web.dart';

String getFileNameFromUrl(String url) {
  return "${md5.convert(utf8.encode(url))}.html";
}

class DownloadMetadata {
  String pageTitle;
  int unixtimeDownloadedSecs;
  String? imageBase64;
  ImageProvider? imageProvider;
  bool archived;

  DownloadMetadata(this.pageTitle, this.unixtimeDownloadedSecs,
      this.imageBase64, this.imageProvider, this.archived);
}

class DownloadStatus {
  bool done;
  Object? error;

  DownloadStatus({required this.done, this.error});
}

Future<DownloadMetadata> getMetadata(String url, String content) async {
  var parsed = parse(content);

  // Try to determine the title of the page.
  String pageTitle;
  var headElements = parsed.head?.querySelectorAll("title") ?? [];
  if (headElements.isNotEmpty) {
    pageTitle = headElements[0].text;
  } else {
    pageTitle = url;
  }

  int unixtimeDownloadedSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  // Try to find a good image to use.
  ImageProvider? imageProvider;
  String? base64String;
  var imageElements = parsed.body?.querySelectorAll("img") ?? [];
  if (imageElements.isNotEmpty) {
    // See https://github.com/banool/aclip/issues/24.
    for (var element in imageElements) {
      var src = element.attributes["src"];
      if (src == null) continue;
      if (src.contains("base64,")) {
        var s = src.split("base64,");
        if (s.length > 1) {
          try {
            base64String = s.last;
            imageProvider = MemoryImage(base64Decode(base64String));
          } catch (e) {
            print("Failed to decode base64 for an image in $url");
            base64String = null;
            imageProvider = null;
            continue;
          }
          print("Sucessfully found image to use for $url");
          break;
        }
      }
    }
  }

  bool archived = listManager.links![url]!.archived;
  return DownloadMetadata(
      pageTitle, unixtimeDownloadedSecs, base64String, imageProvider, archived);
}
