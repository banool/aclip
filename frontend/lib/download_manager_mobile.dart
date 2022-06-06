import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:aclip/constants.dart';
import 'package:aclip/globals.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;

import 'download_manager.dart';
import 'ffi.dart';

// TODO: Make this configurable.
const int cacheTtlSecs = 60 * 60 * 24 * 31;

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

// Returns the path that the file was downloaded to.
Future<String> _downloadPage(String targetUrl) async {
  String outputPath = getFilePathFromUrl(targetUrl);
  Options options = getOptionsFromSharedPrefs(targetUrl, outputPath);
  await api.downloadPage(options: options);
  return outputPath;
}

String getFilePathFromUrl(String url) {
  return "$downloadsDirectory/${getFileNameFromUrl(url)}";
}

class DownloadStatus {
  bool done;
  Object? error;

  DownloadStatus({required this.done, this.error});
}

class DownloadMetadata {
  String pageTitle;
  int unixtimeDownloadedSecs;
  String? imageBase64;
  ImageProvider? imageProvider;

  static String getPageTitleKey(String fileNameFromUrl) {
    return "keyPageTitle$fileNameFromUrl";
  }

  static String getUnixtimeDownloadedSecsKey(String fileNameFromUrl) {
    return "keyDownloadedTime$fileNameFromUrl";
  }

  static String getImageBase64Key(String fileNameFromUrl) {
    return "keyImageBase64$fileNameFromUrl";
  }

  Future<void> writeToStorage(String url) async {
    var fileNameFromUrl = getFileNameFromUrl(url);
    await sharedPreferences.setString(
        getPageTitleKey(fileNameFromUrl), pageTitle);
    await sharedPreferences.setInt(
        getUnixtimeDownloadedSecsKey(fileNameFromUrl), unixtimeDownloadedSecs);
    if (imageBase64 != null) {
      await sharedPreferences.setString(
          getImageBase64Key(fileNameFromUrl), imageBase64!);
    }
    print("Wrote metadata to storage");
  }

  static Future<DownloadMetadata?> readFromStorage(String url) async {
    if (!(await File(getFilePathFromUrl(url)).exists())) {
      print("Couldn't find file for $url, returning no metadata");
      return null;
    }

    var fileNameFromUrl = getFileNameFromUrl(url);

    int? unixtimeDownloadedSecs =
        sharedPreferences.getInt(getUnixtimeDownloadedSecsKey(fileNameFromUrl));
    if (unixtimeDownloadedSecs == null) return null;

    if (unixtimeDownloadedSecs <
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) - cacheTtlSecs) {
      print(
          "Found file and metadata for $url, but it is too old, returning no metadata");
      return null;
    }

    String? pageTitle =
        sharedPreferences.getString(getPageTitleKey(fileNameFromUrl));
    if (pageTitle == null) return null;

    String? imageBase64 =
        sharedPreferences.getString(getImageBase64Key(fileNameFromUrl));

    ImageProvider? imageProvider;
    if (imageBase64 != null) {
      imageProvider = MemoryImage(base64Decode(imageBase64));
    }

    return DownloadMetadata(
        pageTitle, unixtimeDownloadedSecs, imageBase64, imageProvider);
  }

  DownloadMetadata(this.pageTitle, this.unixtimeDownloadedSecs,
      this.imageBase64, this.imageProvider);
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
    // Check whether we've previously downloaded everything first.
    var downloadFromStorage = await DownloadMetadata.readFromStorage(url);
    if (downloadFromStorage != null) {
      print("Read from storage for $url");
      return downloadFromStorage;
    }

    print("Downloading $url");

    // Download the page.
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

    // Pull the metadata.
    var metadata = await getMetadata(url, outputPath);

    // Update the stored metadata.
    await metadata.writeToStorage(url);

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
    String? base64String;
    var imageElements = parsed.body?.querySelectorAll("img") ?? [];
    if (imageElements.isNotEmpty) {
      // TODO: Be smarter here about how we parse the html and how determine
      // which image is the primo image to use.
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

    return DownloadMetadata(
        pageTitle, unixtimeDownloadedSecs, base64String, imageProvider);
  }

  Future<void> writeDownloadMetadataToStorage(
      String url, DownloadMetadata metadata) async {}
}
