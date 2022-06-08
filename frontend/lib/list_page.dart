import 'package:aclip/js_controller.dart';
import 'package:aptos_sdk_dart/aptos_client_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
  const ListPage({Key? key}) : super(key: key);

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
    await initiateAddItemFlow(context, url: url);
  }

  Future<void> updateCurrentUrlInList(String url) async {
    bool inList = listManager.links!.containsKey(url);
    setState(() {
      urlInList = inList;
    });
  }

  void updateLinksKeys() {
    setState(() {
      linksKeys = listManager.getLinksKeys(archived: false)!;
      linksKeysArchived = listManager.getLinksKeys(archived: true)!;
    });
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
    await Future.delayed(Duration(milliseconds: 200));
    await listManager.pull();
    updateLinksKeys();
    setState(() {
      currentAction = null;
    });
    if (runningAsBrowserExtension && url != null) {
      await updateCurrentUrlInList(url);
    }
  }

  Future<FullTransactionResult> removeItem(BuildContext context, String url,
      LinkData linkData, RemoveItemAction removeItemAction) async {
    setState(() {
      removeItemFuture =
          listManager.removeItem(url, linkData, removeItemAction);
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
                          padding: EdgeInsets.all(20),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                Padding(padding: EdgeInsets.only(left: 15)),
                                Text(
                                  "${currentAction!} item...",
                                  style: TextStyle(fontSize: 18),
                                )
                              ]));
                    }
                    if (snapshot.hasError) {
                      return TransactionResultWidget(FullTransactionResult(
                          false, null, getErrorString(snapshot.error!), null));
                    }
                    if (snapshot.data!.committed &&
                        !(sharedPreferences
                                .getBool(keyShowTransactionSuccessPage) ??
                            defaultShowTransactionSuccessPage)) {
                      Navigator.pop(context);
                      return Container();
                    }
                    return TransactionResultWidget(snapshot.data!);
                  }));
        });
    FullTransactionResult result = await removeItemFuture!;
    if (result.committed) {
      final controller = Slidable.of(context);
      controller!.dismiss(ResizeRequest(Duration(milliseconds: 100), () => {}));
      updateLinksKeys();
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
            padding: EdgeInsets.all(8),
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
                  padding: EdgeInsets.all(8),
                  child: Text(
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
          icon: Icon(Icons.add))
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
          String key = l.elementAt(index);
          return buildListItem(key, listManager.links![key]!);
        });
    Widget body = RefreshIndicator(
      child: listView,
      onRefresh: () async {
        await listManager.pull();
        updateLinksKeys();
      },
      displacement: 2,
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
      Padding(padding: EdgeInsets.all(5), child: body),
      title: showArchived ? "Archive" : "My List",
      appBarActions: appBarActions,
      leadingAppBarButton: leadingAppBarAction,
    );
  }

  Future<void> myLaunchUrl(
    String url,
  ) async {
    LaunchMode launchMode;
    if (sharedPreferences.getBool(keyLaunchInExternalBrowser) ??
        defaultLaunchInExternalBrowser) {
      launchMode = LaunchMode.externalApplication;
    } else {
      launchMode = LaunchMode.platformDefault;
    }

    bool offlineOnly = sharedPreferences.getBool(keyOnlyOfflineLinks) ??
        defaultOnlyOfflineLinks;

    if (kIsWeb || (await canConnectToInternet()) && !offlineOnly) {
      await launchUrl(
        Uri.parse(url),
        mode: launchMode,
      );
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (context) {
        return OfflineWebView(url);
      }));
    }
  }

  Widget buildListItem(String url, LinkData linkData) {
    Widget title = FutureBuilder(
        future: downloadManager.urlToDownload[url]!,
        builder:
            (BuildContext context, AsyncSnapshot<DownloadMetadata> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Text(url);
          }
          if (snapshot.hasError) {
            return Text(url);
          }
          return Text(snapshot.data!.pageTitle);
        });

    String subtitleSuffix = Uri.tryParse(url)?.host ?? url;

    Widget downloadingIndicator = FutureBuilder(
        future: downloadManager.urlToDownload[url]!,
        builder:
            (BuildContext context, AsyncSnapshot<DownloadMetadata> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            var lac = AnimationController(
                vsync: this, duration: Duration(milliseconds: 1000));
            loadingAnimationControllers[url] = lac;
            lac.repeat(reverse: true);
            return Align(
                alignment: Alignment.center,
                child: RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.25).animate(lac),
                    child: AnimatedIcon(
                        size: 22,
                        icon: AnimatedIcons.search_ellipsis,
                        progress: lac)));
          }
          loadingAnimationControllers[url]?.stop();
          IconData iconData;
          if (snapshot.hasError) {
            iconData = Icons.error_outline;
          } else {
            iconData = Icons.done;
          }
          return IconButton(
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
            },
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            alignment: Alignment.center,
          );
        });

    Widget subtitle = Row(
      children: [
        Text(subtitleSuffix),
        Padding(padding: EdgeInsets.only(left: 5)),
        downloadingIndicator
      ],
    );

    Widget trailing = FutureBuilder(
        future: downloadManager.urlToDownload[url]!,
        builder:
            (BuildContext context, AsyncSnapshot<DownloadMetadata> snapshot) {
          var nothing = SizedBox(width: 10, height: 10);
          if (snapshot.connectionState != ConnectionState.done) {
            return nothing;
          }
          if (snapshot.hasError) {
            return nothing;
          }
          if (snapshot.data!.imageProvider == null) {
            return nothing;
          }
          return Image(
            image: snapshot.data!.imageProvider!,
            loadingBuilder: (context, child, loadingProgress) =>
                (loadingProgress == null)
                    ? FractionallySizedBox(widthFactor: 0.35, child: child)
                    : CircularProgressIndicator(),
            errorBuilder: (BuildContext context, _, __) {
              return nothing;
            },
          );
        });

    return Card(
        child: Slidable(
            key: ValueKey(url + "${linkData.archived}"),
            endActionPane: ActionPane(
                extentRatio: 0.5,
                dragDismissible: false,
                dismissible: DismissiblePane(onDismissed: () => {}),
                motion: ScrollMotion(),
                children: [
                  SlidableAction(
                    onPressed: (BuildContext context) async => await removeItem(
                        context,
                        url,
                        linkData,
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
                        context, url, linkData, RemoveItemAction.remove),
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
