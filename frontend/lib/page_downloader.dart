import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:aclip/constants.dart';
import 'package:aclip/globals.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;

import 'ffi.dart';

Options getOptionsFromSharedPrefs(String targetUrl, String outputPath) {
  bool insecure =
      !(sharedPreferences.getBool(keyForceHttpsOnly) ?? defaultForceHttpsOnly);
  return Options(
      noAudio: false,
      noCss: false,
      ignoreErrors: false,
      noFrames: false,
      noFonts: false,
      noImages: false,
      isolate: false,
      noJs: false,
      insecure: insecure,
      noMetadata: false,
      output: outputPath,
      silent: false,
      timeout: 120,
      noVideo: false,
      target: targetUrl,
      noColor: false,
      unwrapNoscript: false);
}

String getFileNameFromUrl(String url) {
  return md5.convert(utf8.encode(url)).toString();
}

// Returns the path that the file was downloaded to.
Future<String> _downloadPage(String targetUrl) async {
  String outputPath = "$downloadsDirectory/${getFileNameFromUrl(targetUrl)}";
  Options options = getOptionsFromSharedPrefs(targetUrl, outputPath);
  await api.downloadPage(options: options);
  return outputPath;
}

class DownloadStatus {
  bool done;
  Object? error;

  DownloadStatus({required this.done, this.error});
}

class DownloadMetadata {
  String pageTitle;
  int unixtimeDownloadedSecs;
  ImageProvider? imageProvider;

  DownloadMetadata(
      this.pageTitle, this.unixtimeDownloadedSecs, this.imageProvider);
}

class DownloadManager {
  LinkedHashMap<String, Future<DownloadMetadata>> urlToDownload =
      LinkedHashMap();
  LinkedHashMap<String, DownloadStatus> urlToDownloadStatus = LinkedHashMap();

  Future<void> triggerDownload(String url) async {
    if (!shouldDownload(url)) {
      return;
    }
    urlToDownload[url] = download(url);
  }

  Future<DownloadMetadata> download(String url) async {
    print("Downloading $url");
    urlToDownloadStatus[url] = DownloadStatus(done: false);
    String outputPath;
    try {
      outputPath = await _downloadPage(url);
      urlToDownloadStatus[url]!.done = true;
      print("Successfully downloaded $url");
    } catch (e) {
      urlToDownloadStatus[url]!.done = true;
      urlToDownloadStatus[url]!.error = e;
      print("Failed to download $url: $e");
      rethrow;
    }
    var metadata = await getMetadata(url, outputPath);

    //

    return metadata;
  }

  bool shouldDownload(String url) {
    if (!urlToDownload.containsKey(url)) {
      return true;
    }
    if (!urlToDownloadStatus.containsKey(url)) {
      return true;
    }
    if (urlToDownloadStatus[url]!.error != null) {
      return true;
    }
    return false;
  }

  Future<DownloadMetadata> getMetadata(
      String url, String downloadedPath) async {
    String content = await File(downloadedPath).readAsString();

    var parsed = parse(content);

    // Try to determine the title of the page.
    String pageTitle;
    var headElements = parsed.head?.getElementsByClassName("title") ?? [];
    if (headElements.isNotEmpty) {
      pageTitle = headElements[0].text;
    } else {
      pageTitle = url;
    }

    int unixtimeDownloadedSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Try to find a good image to use.
    ImageProvider? imageProvider;
    var imageElements = parsed.body?.querySelectorAll("img") ?? [];
    if (imageElements.isNotEmpty) {
      // TODO: Be smarter here about how we parse the html and find the ideal
      // image to use.
      for (var element in imageElements) {
        var src = element.attributes["src"];
        if (src == null) continue;
        if (src.contains("base64,")) {
          var s = src.split("base64,");
          if (s.length > 1) {
            var base64String = s.last;
            imageProvider = MemoryImage(base64Decode(base64String));
            print("Sucessfully found image to use for $url");
            break;
          }
        }
      }
    }

    return DownloadMetadata(pageTitle, unixtimeDownloadedSecs, imageProvider);
  }
}
