import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'bridge_definitions.dart';
import 'constants.dart';
import 'download_manager.dart';
import 'globals.dart';
import 'ffi.dart';
import 'list_manager.dart';

// See https://github.com/banool/aclip/issues/25.
const int cacheTtlSecs = 60 * 60 * 24 * 31;

// See https://github.com/banool/aclip/issues/26.
Options getOptionsFromSharedPrefs(String targetUrl, String outputPath) {
  bool insecure =
      !(sharedPreferences.getBool(keyForceHttpsOnly) ?? defaultForceHttpsOnly);
  print("outputPath: $outputPath");
  return Options(
      noAudio: false,
      noCss: false,
      ignoreErrors: false,
      blacklistDomains: false,
      domains: null,
      noFrames: false,
      noFonts: false,
      noImages: false,
      isolate: false,
      noJs: false,
      insecure: insecure,
      noMetadata: false,
      output: outputPath,
      silent: false,
      timeout: 90,
      noVideo: false,
      target: targetUrl,
      noColor: false,
      unwrapNoscript: false);
}

// Returns the path that the file was downloaded to.
Future<String> _downloadPage(String targetUrl) async {
  String outputPath = getFilePathFromUrl(targetUrl);
  Options options = getOptionsFromSharedPrefs(targetUrl, outputPath);
  print(options.target);
  await api.downloadPage(options: options);
  return outputPath;
}

String getFilePathFromUrl(String url) {
  return "$downloadsDirectory/${getFileNameFromUrl(url)}";
}

// It's easiest if DownloadMetadata exists in the common download_manager.dart
// file and we add the mobile specific stuff here is an extension.
extension StorageStuff on DownloadMetadata {
  static String getPageTitleKey(String fileNameFromUrl) {
    return "keyPageTitle$fileNameFromUrl";
  }

  static String getUnixtimeDownloadedSecsKey(String fileNameFromUrl) {
    return "keyDownloadedTime$fileNameFromUrl";
  }

  static String getImageBase64Key(String fileNameFromUrl) {
    return "keyImageBase64$fileNameFromUrl";
  }

  static String getArchivedKey(String fileNameFromUrl) {
    return "keyArchived$fileNameFromUrl";
  }

  static Future<void> addItemToCachedUrls(String url) async {
    var urls = sharedPreferences.getStringList(keyCachedUrls) ?? [];
    urls = urls.toSet().toList();
    urls.add(url);
    await sharedPreferences.setStringList(keyCachedUrls, urls);
    print("Wrote urls to cache as part of adding: $urls");
  }

  static Future<void> removeItemFromCachedUrls(String url) async {
    var urls = sharedPreferences.getStringList(keyCachedUrls) ?? [];
    urls = urls.toSet().toList();
    urls.remove(url);
    await sharedPreferences.setStringList(keyCachedUrls, urls);
    print("Wrote urls to cache as part of removing: $urls");
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
    await sharedPreferences.setBool(
      getArchivedKey(fileNameFromUrl),
      listManager.links![url]!.archived,
    );
    await addItemToCachedUrls(url);
    print("Wrote metadata to storage for $url");
  }

  Future<void> wipeFromStorage(String url) async {
    var fileNameFromUrl = getFileNameFromUrl(url);
    await sharedPreferences.remove(getPageTitleKey(fileNameFromUrl));
    await sharedPreferences
        .remove(getUnixtimeDownloadedSecsKey(fileNameFromUrl));
    await sharedPreferences.remove(getImageBase64Key(fileNameFromUrl));
    await sharedPreferences.remove(getArchivedKey(fileNameFromUrl));
    await removeItemFromCachedUrls(url);
    print("Cleared metadata from storage for $url");
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

    bool? archived = sharedPreferences.getBool(getArchivedKey(fileNameFromUrl));
    if (archived == null) return null;

    return DownloadMetadata(pageTitle, unixtimeDownloadedSecs, imageBase64,
        imageProvider, archived);
  }
}

class DownloadManagerResult {
  DownloadMetadata? downloadMetadata;
  Object? error;

  bool get success {
    return error == null;
  }

  factory DownloadManagerResult.create(
      DownloadMetadata? downloadMetadata, Object? error) {
    if (downloadMetadata == null && error == null) {
      throw "One must be set, not zero";
    }
    if (downloadMetadata != null && error != null) {
      throw "One must be set, not both";
    }
    return DownloadManagerResult(downloadMetadata, error);
  }

  @override
  String toString() {
    return "DownloadManagerResult($downloadMetadata, $error)";
  }

  DownloadManagerResult(this.downloadMetadata, this.error);
}

class DownloadManager extends ChangeNotifier {
  // State of this map based on the download state:
  // - Downloading: Key (URL) present with null value.
  // - Downloaded: Key present with DownloadManagerResult(downloadMetadata).
  // - Error: Key present with DownloadManagerResult(error).
  // This is wrapped in a ValueListenable so downstream widgets can subscribe
  // to changes to it.
  LinkedHashMap<String, DownloadManagerResult?> urlToDownloadMetadata =
      LinkedHashMap();

  Future<void> triggerDownload(String url,
      {bool forceFromInternet = false}) async {
    if (!shouldDownload(url) && !forceFromInternet) {
      return;
    }
    urlToDownloadMetadata[url] = null;
    var f = download(url, forceFromInternet: forceFromInternet);
    notifyListeners();

    DownloadMetadata? downloadMetadata;
    Object? error;
    try {
      downloadMetadata = await f;
      print("Successfully downloaded $url");
    } catch (e) {
      print("Failed to download $url: $e");
      error = e;
    }
    urlToDownloadMetadata[url] =
        DownloadManagerResult.create(downloadMetadata, error);
    notifyListeners();
  }

  Future<DownloadMetadata> download(String url,
      {bool forceFromInternet = false}) async {
    // Check whether we've previously downloaded everything first.
    if (!forceFromInternet) {
      var downloadFromStorage = await StorageStuff.readFromStorage(url);
      if (downloadFromStorage != null) {
        print("Read from storage for $url");
        return downloadFromStorage;
      }
    }

    print("Downloading $url");

    // Download the page.
    String outputPath;
    outputPath = await _downloadPage(url);

    // Pull the metadata.
    String content = await File(outputPath).readAsString();
    var metadata = await getMetadata(url, content);

    // Update the stored metadata.
    await metadata.writeToStorage(url);

    return metadata;
  }

  bool shouldDownload(String url) {
    if (!urlToDownloadMetadata.containsKey(url)) {
      return true;
    }
    if (!urlToDownloadMetadata[url]!.success) {
      return true;
    }
    return false;
  }

  // Remove every file from storage unless we are aware of it and it has not
  // exceeded its cache TTL.
  Future<void> removeExpiredFiles({bool forceAll = false}) async {
    final List<FileSystemEntity> entities =
        await Directory(downloadsDirectory).list().toList();
    final Map<String, String> fileNameToPath = {};

    for (var entity in entities) {
      var fileName = entity.path.split("/").last;
      fileNameToPath[fileName] = entity.path;
    }

    Set<String> toRemove = fileNameToPath.keys.toSet();

    if (!forceAll) {
      // ignore: avoid_function_literals_in_foreach_calls
      urlToDownloadMetadata.entries.forEach((element) async {
        var url = element.key;
        if (element.value == null || !element.value!.success) {
          print("Ignoring $url because value is ${element.value}");
          return;
        }
        var metadata = element.value!.downloadMetadata!;
        if (metadata.unixtimeDownloadedSecs >
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) - cacheTtlSecs) {
          toRemove.remove(getFileNameFromUrl(url));
        }
      });
    }

    for (String filename in toRemove) {
      await File(fileNameToPath[filename]!).delete();
      print("Deleted $filename");
    }
  }

  Future<void> clearCache() async {
    await removeExpiredFiles(forceAll: true);
    // ignore: avoid_function_literals_in_foreach_calls
    urlToDownloadMetadata.entries.forEach((element) async {
      var url = element.key;
      if (element.value == null || !element.value!.success) {
        print("Ignoring $url because value is ${element.value}");
        return;
      }
      var metadata = element.value!.downloadMetadata!;
      await metadata.wipeFromStorage(element.key);
    });
    urlToDownloadMetadata.clear();
    print("Cleared cache");
  }

  Future<LinkedHashMap<String, LinkDataWrapper>>
      populateLinksFromStorage() async {
    LinkedHashMap<String, LinkDataWrapper> out = LinkedHashMap();
    List<String> keys = sharedPreferences.getStringList(keyCachedUrls) ?? [];
    int addedAtMicros = 1;
    for (String url in keys) {
      var fileNameFromUrl = getFileNameFromUrl(url);
      bool? archived = sharedPreferences
              .getBool(StorageStuff.getArchivedKey(fileNameFromUrl)) ??
          false;

      var linkData = LinkDataWrapper(
        archived: archived,
        secret: false,
        tags: [],
        addedAtMicros: addedAtMicros,
      );
      out[url] = linkData;
      addedAtMicros += 1;
    }
    return out;
  }
}
