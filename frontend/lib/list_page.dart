import 'package:aclip/js_controller.dart';
import 'package:aptos_sdk_dart/aptos_client_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_item_screen.dart';
import 'common.dart';
import 'constants.dart';
import 'download_manager.dart';
import 'globals.dart';
import 'list_manager.dart';
import 'offline_webview.dart';
import 'page_selector.dart';
import 'transaction_result_widget.dart';

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => ListPageState();
}

class ListPageState extends State<ListPage> with TickerProviderStateMixin {
  Future<FullTransactionResult>? removeItemFuture;
  String? currentAction;

  bool showArchived = false;

  late List<String> linksKeys;
  late List<String> linksKeysArchived;

  Map<String, AnimationController> loadingAnimationControllers = {};

  bool? urlInList;

  late Future<bool> checkOnlineStatusFuture;

  @override
  void initState() {
    super.initState();
    updateLinksKeys();
    if (runningAsBrowserExtension) {
      launchAddItemFlowOnStartup();
    }
    checkOnlineStatusFuture = canConnectToInternet();

    listManager.addListener(() {
      updateLinksKeys();
    });
  }

  Future<void> launchAddItemFlowOnStartup() async {
    if (!(sharedPreferences.getBool(keySaveOnOpen) ?? defaultSaveOnOpen)) {
      return;
    }
    print("Getting current URL");
    String? url = await getCurrentUrl();
    if (url == null) {
      print("Couldn't determine URL, not adding anything to the list");
      return;
    }
    print("Current URL is $url");
    if (!url.startsWith("http")) {
      print("Not adding item because it doesn't start with http: $url");
      return;
    }
    updateCurrentUrlInList(url);
    if (urlInList!) {
      print("Not adding item because it is already in the list: $url");
      return;
    }
    print("Initiating add item flow on startup as browser extension");
    if (!mounted) return;
    await initiateAddItemFlow(context, url: url);
  }

  Future<void> updateCurrentUrlInList(String url) async {
    bool inList = listManager.links!.containsKey(url);
    setState(() {
      urlInList = inList;
    });
  }

  void updateLinksKeys() {
    if (mounted) {
      print("Updating links keys");
      setState(() {
        linksKeys = listManager.getLinksKeys(archived: false)!;
        linksKeysArchived = listManager.getLinksKeys(archived: true)!;
      });
    }
  }

  Future<void> initiateAddItemFlow(BuildContext context, {String? url}) async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return FractionallySizedBox(
              heightFactor: 0.85, child: AddItemScreen(url: url));
        });
    // This shouldn't be necessary, see https://github.com/banool/aclip/issues/23.
    await Future.delayed(const Duration(milliseconds: 200));
    await listManager.pull();
    setState(() {
      currentAction = null;
    });
    if (runningAsBrowserExtension && url != null) {
      await updateCurrentUrlInList(url);
    }
  }

  Future<FullTransactionResult> removeItem(
      BuildContext context,
      String url,
      LinkDataWrapper linkDataWrapper,
      RemoveItemAction removeItemAction) async {
    setState(() {
      removeItemFuture =
          listManager.removeItem(url, linkDataWrapper, removeItemAction);
      switch (removeItemAction) {
        case RemoveItemAction.remove:
          currentAction = "Deleting";
          break;
        case RemoveItemAction.archive:
          currentAction = "Archiving";
          break;
        case RemoveItemAction.unarchive:
          currentAction = "Unarchiving";
          break;
      }
    });
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              content: FutureBuilder(
                  future: removeItemFuture!,
                  builder: (BuildContext context,
                      AsyncSnapshot<FullTransactionResult> snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                const Padding(
                                    padding: EdgeInsets.only(left: 15)),
                                Text(
                                  "${currentAction!} item...",
                                  style: const TextStyle(fontSize: 18),
                                )
                              ]));
                    }
                    if (snapshot.hasError) {
                      return TransactionResultWidget(FullTransactionResult(
                          false,
                          false,
                          null,
                          getErrorString(snapshot.error!),
                          null));
                    }
                    FullTransactionResult result = snapshot.data!;
                    // If the result was success and the says they don't want to see the
                    // transaction page on success, just pop.
                    if (result.success &&
                        !(sharedPreferences
                                .getBool(keyShowTransactionSuccessPage) ??
                            defaultShowTransactionSuccessPage)) {
                      Navigator.pop(context);
                      return const SizedBox(width: 1, height: 1);
                    }
                    return TransactionResultWidget(result);
                  }));
        });
    FullTransactionResult result = await removeItemFuture!;
    if (result.committed) {
      final controller = Slidable.of(context);
      controller!
          .dismiss(ResizeRequest(const Duration(milliseconds: 100), () => {}));
      await updateCurrentUrlInList(url);
    }
    return result;
  }

  Widget getInListInfoWidget() {
    if (urlInList == null) {
      return Container();
    }
    String message;
    if (urlInList!) {
      message = "Current page in list!";
    } else {
      message = "Current page not in list";
    }
    return Align(
        alignment: Alignment.bottomRight,
        child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.all(8),
            child: Text(
              message,
              textAlign: TextAlign.right,
            )));
  }

  Widget getOfflineInfoWidget() {
    return Align(
        alignment: Alignment.bottomRight,
        child: FutureBuilder(
            future: checkOnlineStatusFuture,
            builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Container();
              }
              if (snapshot.data != null && snapshot.data!) {
                return Container();
              }
              return Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    "Showing offline items only",
                    textAlign: TextAlign.right,
                  ));
            }));
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> appBarActions = [
      IconButton(
          onPressed: () async => await initiateAddItemFlow(context),
          icon: const Icon(Icons.add))
    ];
    Widget leadingAppBarAction = IconButton(
        onPressed: () {
          setState(() {
            showArchived = !showArchived;
          });
        },
        icon: Icon(showArchived ? Icons.list_alt : Icons.archive_outlined));
    var l = showArchived ? linksKeysArchived : linksKeys;
    Widget listView = ListView.builder(
        itemCount: l.length,
        itemBuilder: (context, index) {
          return Builder(builder: ((context) {
            String key = l.elementAt(index);
            return buildListItem(context, key, listManager.links![key]!);
          }));
        });
    Widget body = RefreshIndicator(
      onRefresh: () async {
        await listManager.pull();
      },
      displacement: 2,
      child: listView,
    );
    if (runningAsBrowserExtension) {
      body = Stack(children: [
        body,
        getInListInfoWidget(),
      ]);
    }
    body = Stack(children: [
      body,
      getOfflineInfoWidget(),
    ]);
    return buildTopLevelScaffold(
      context,
      Padding(padding: const EdgeInsets.all(5), child: body),
      title: showArchived ? "Archive" : "My List",
      appBarActions: appBarActions,
      leadingAppBarButton: leadingAppBarAction,
    );
  }

  Future<void> myLaunchUrl(
    String url,
  ) async {
    bool useExternalBrowser =
        sharedPreferences.getBool(keyLaunchInExternalBrowser) ??
            defaultLaunchInExternalBrowser;

    bool offlineOnly = sharedPreferences.getBool(keyOnlyOfflineLinks) ??
        defaultOnlyOfflineLinks;

    bool showOfflineContent = !(await canConnectToInternet()) || offlineOnly;

    print("Launching url $url");
    if (kIsWeb || !showOfflineContent && useExternalBrowser) {
      await launchUrl(
        Uri.parse(url),
      );
    } else {
      final navigator = Navigator.of(context);
      await navigator.push(MaterialPageRoute(builder: (context) {
        return InAppWebView(url, viewOffline: showOfflineContent);
      }));
    }
  }

  Widget buildListItem(
      BuildContext context, String url, LinkDataWrapper linkDataWrapper) {
    DownloadManagerResult? downloadManagerResult =
        context.select<DownloadManager, DownloadManagerResult?>(
            (downloadManager) => downloadManager.urlToDownloadMetadata[url]);

    Widget nothing = const SizedBox(width: 10, height: 10);

    Widget title = Text(url.trim());
    Widget downloadingIndicator;
    Widget trailing = nothing;

    if (downloadManagerResult == null) {
      var lac = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1000));
      loadingAnimationControllers[url] = lac;
      lac.repeat(reverse: true);
      downloadingIndicator = Align(
          alignment: Alignment.center,
          child: RotationTransition(
              turns: Tween(begin: 0.0, end: 0.25).animate(lac),
              child: AnimatedIcon(
                  size: 22,
                  icon: AnimatedIcons.search_ellipsis,
                  progress: lac)));
    } else {
      loadingAnimationControllers[url]?.dispose();
      loadingAnimationControllers.remove(url);
      IconData iconData;
      if (downloadManagerResult.success) {
        DownloadMetadata downloadMetadata =
            downloadManagerResult.downloadMetadata!;
        title = Text(downloadMetadata.pageTitle.trim());
        iconData = Icons.done;
        if (downloadMetadata.imageProvider != null) {
          trailing = Image(
            image: downloadMetadata.imageProvider!,
            loadingBuilder: (context, child, loadingProgress) =>
                (loadingProgress == null)
                    ? FractionallySizedBox(widthFactor: 0.35, child: child)
                    : const CircularProgressIndicator(),
            errorBuilder: (BuildContext context, _, __) {
              return nothing;
            },
          );
        }
      } else {
        iconData = Icons.error_outline;
      }
      downloadingIndicator = IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          alignment: Alignment.center,
          icon: Icon(iconData, size: 20),
          onPressed: () async {
            bool online = await checkOnlineStatusFuture;
            if (!online) {
              print("Not redownloading stuff because we're offline");
              return;
            }
            var f =
                downloadManager.triggerDownload(url, forceFromInternet: true);
            setState(() {});
            await f;
            setState(() {});
          });
    }

    String subtitleSuffix = Uri.tryParse(url)?.host ?? url;

    Widget subtitle = Row(
      children: [
        Text(subtitleSuffix),
        const Padding(padding: EdgeInsets.only(left: 5)),
        downloadingIndicator
      ],
    );

    return Card(
        child: Slidable(
            key: ValueKey("$url${linkDataWrapper.archived}"),
            endActionPane: ActionPane(
                extentRatio: 0.5,
                dragDismissible: false,
                dismissible: DismissiblePane(onDismissed: () => {}),
                motion: const ScrollMotion(),
                children: [
                  SlidableAction(
                    onPressed: (BuildContext context) async => await removeItem(
                        context,
                        url,
                        linkDataWrapper,
                        showArchived
                            ? RemoveItemAction.unarchive
                            : RemoveItemAction.archive),
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    label: showArchived ? "Unarchive" : "Archive",
                    icon: Icons.archive,
                    autoClose: false,
                  ),
                  SlidableAction(
                    onPressed: (BuildContext context) async => await removeItem(
                        context, url, linkDataWrapper, RemoveItemAction.remove),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    label: "Delete",
                    icon: Icons.delete,
                    autoClose: false,
                  )
                ]),
            child: ListTile(
              title: title,
              subtitle: subtitle,
              trailing: trailing,
              onTap: () async => await myLaunchUrl(url),
            )));
  }

  @override
  void dispose() {
    loadingAnimationControllers.values.map((e) => e.dispose());
    super.dispose();
  }
}
