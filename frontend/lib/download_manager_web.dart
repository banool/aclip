import 'dart:collection';

import 'package:flutter/material.dart';

import 'download_manager.dart';
import 'list_manager.dart';

// The web version of DownloadManager is much simpler. We don't actually
// download the whole page or store anything, we just submit a request to get
// the page headers to determine the article title and cache it in memory.

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
    var f = download(url);
    urlToDownloadMetadata[url] = null;
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

  Future<DownloadMetadata> download(String url) async {
    // We short circuit the below for now because it doesn't work due to CORS.
    // We need to use a CORS proxy or something.
    return DownloadMetadata(url, 1, null, null, true);

    /*
    print("Submitting GET request for $url");

    // Make a HEAD request to try to get the page title.
    urlToDownloadStatus[url] = DownloadStatus(done: false);
    Response<dynamic> response;
    try {
      response = await Dio().get(url);
      print(response);
      print("Successfully got $url");
      urlToDownloadStatus[url]!.done = true;
    } catch (e) {
      urlToDownloadStatus[url]!.done = true;
      urlToDownloadStatus[url]!.error = e;
      print("Failed to get $url: $e");
      rethrow;
    }

    return await getMetadata(url, response.data);
    */
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

  Future<void> clearCache() async {
    urlToDownloadMetadata.clear();
  }

  Future<LinkedHashMap<String, LinkDataWrapper>>
      populateLinksFromStorage() async {
    LinkedHashMap<String, LinkDataWrapper> out = LinkedHashMap();
    return out;
  }
}

String getFilePathFromUrl(String url) {
  throw "Should not be used";
}
