import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'common.dart';
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
    var controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
            print("Loading progress: $progress");
          },
          onPageStarted: (String url) {
            print("Started loading page $url");
          },
          onPageFinished: (String url) {
            print("Finished loading page $url");
          },
          onWebResourceError: (WebResourceError error) {
            print("Error loading page: $error");
            // Show an error snackbar and navigate back.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Failed to load page: ${error.description}"),
              ),
            );
            Navigator.of(context).pop();
          },
        ),
      )
      ..loadFile(getFilePathFromUrl(widget.url));
    var webView = WebViewWidget(
      controller: controller,
    );
    return ColoredSafeArea(
        child: buildTopLevelScaffold(context, webView, isSubPage: true));
  }
}

// From https://stackoverflow.com/questions/55250493/flutter-system-bar-colors-with-safearea.
class ColoredSafeArea extends StatelessWidget {
  final Widget child;
  final Color? color;

  const ColoredSafeArea({Key? key, required this.child, this.color})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color ?? Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: child,
      ),
    );
  }
}
