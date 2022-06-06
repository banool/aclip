import 'dart:collection';

import 'package:dio/dio.dart';

import 'download_manager.dart';

// The web version of DownloadManager is much simpler. We don't actually
// download the whole page or store anything, we just submit a request to get
// the page headers to determine the article title and cache it in memory.

class DownloadManager {
  LinkedHashMap<String, Future<DownloadMetadata>> urlToDownload =
      LinkedHashMap();
  LinkedHashMap<String, DownloadStatus> urlToDownloadStatus = LinkedHashMap();

  Future<void> triggerDownload(String url,
      {bool forceFromInternet = false}) async {
    print('sould: ${shouldDownload(url)} ');
    if (!shouldDownload(url) && !forceFromInternet) {
      return;
    }
    urlToDownload[url] = download(url);
    await urlToDownload[url];
  }

  Future<DownloadMetadata> download(String url) async {
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

  Future<void> clearCache() async {
    urlToDownload.clear();
    urlToDownloadStatus.clear();
  }
}

String getFilePathFromUrl(String url) {
  throw "Should not be used";
}
