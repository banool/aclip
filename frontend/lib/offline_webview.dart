import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'download_manager.dart';
import 'page_selector.dart';

class OfflineWebView extends StatefulWidget {
  const OfflineWebView(this.url, {Key? key}) : super(key: key);

  final String url;

  @override
  State<OfflineWebView> createState() => OfflineWebViewState();
}

class OfflineWebViewState extends State<OfflineWebView> {
  @override
  Widget build(BuildContext context) {
    var webView = WebView(
      initialUrl: 'about:blank',
      javascriptMode: JavascriptMode.unrestricted,
      onWebResourceError: (WebResourceError e) {
        print("Web resource error: ${e.description}, ${e.errorType}");
      },
      debuggingEnabled: true,
      onWebViewCreated: (WebViewController controller) async {
        File(getFilePathFromUrl(widget.url))
            .readAsString()
            .then((content) => controller.loadHtmlString(content));
      },
    );
    return SafeArea(
        child: buildTopLevelScaffold(
      context,
      webView,
      isSubPage: true,
    ));
  }
}
