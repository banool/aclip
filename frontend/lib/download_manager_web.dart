import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

// The web version of DownloadManager is much simpler. We don't actually
// download the whole page or store anything, we just submit a request to get
// the page headers to determine the article title and cache it in memory.

class DownloadManager {
  LinkedHashMap<String, Future<DownloadMetadata>> urlToDownload =
      LinkedHashMap();

  Future<void> triggerDownload(String url) async {
    if (!shouldDownload(url)) {
      return;
    }
    urlToDownload[url] = download(url);
  }

  Future<DownloadMetadata> download(String url) async {
    print("Submitting HEAD request for $url");

    // Download the page.
    var response = await Dio().head(url);

    print(response);

    var metadata = DownloadMetadata("hey", 0);

    return metadata;
  }

  bool shouldDownload(String url) {
    if (!urlToDownload.containsKey(url)) {
      return true;
    }
    return false;
  }
}

class DownloadMetadata {
  String pageTitle;
  int unixtimeDownloadedSecs;
  String? imageBase64;
  ImageProvider? imageProvider;

  DownloadMetadata(this.pageTitle, this.unixtimeDownloadedSecs);
}
