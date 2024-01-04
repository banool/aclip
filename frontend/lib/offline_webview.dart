
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'download_manager.dart';
import 'page_selector.dart';

class InAppWebView extends StatefulWidget {
  const InAppWebView(this.url, {super.key, this.viewOffline = false});

  final String url;
  final bool viewOffline;

  @override
  State<InAppWebView> createState() => InAppWebViewState();
}

class InAppWebViewState extends State<InAppWebView> {
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
      );
    if (widget.viewOffline) {
      controller = controller..loadFile(getFilePathFromUrl(widget.url));
    } else {
      controller = controller..loadRequest(Uri.parse(widget.url));
    }
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

  const ColoredSafeArea({super.key, required this.child, this.color});

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
