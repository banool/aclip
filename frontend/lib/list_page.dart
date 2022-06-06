import 'package:aclip/constants.dart';
import 'package:aclip/globals.dart';
import 'package:aclip/page_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_item_screen.dart';
import 'common.dart';
import 'download_manager.dart';
import 'list_manager.dart';
import 'transaction_result_widget.dart';

class ListPage extends StatefulWidget {
  const ListPage({Key? key}) : super(key: key);

  @override
  State<ListPage> createState() => ListPageState();
}

class ListPageState extends State<ListPage> with TickerProviderStateMixin {
  Future? removeItemFuture;
  String? currentAction;

  bool showArchived = false;

  late List<String> linksKeys;
  late List<String> linksKeysArchived;

  late AnimationController loadingAnimationController;

  @override
  void initState() {
    loadingAnimationController = AnimationController(
        vsync: this, duration: Duration(milliseconds: 1000));
    loadingAnimationController.repeat(reverse: true);
    updateLinksKeys();
    super.initState();
  }

  void updateLinksKeys() {
    setState(() {
      linksKeys = listManager.getLinksKeys(archived: false)!;
      linksKeysArchived = listManager.getLinksKeys(archived: true)!;
    });
  }

  Future<void> initiateAddItemFlow(BuildContext context) async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return FractionallySizedBox(
              heightFactor: 0.85, child: AddItemScreen());
        });
    await listManager.pull();
    setState(() {});
  }

  Future<TransactionResult> removeItem(BuildContext context, String url,
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
          // TODO: Handle this case.
          currentAction = "Unarchiving";
          break;
      }
    });
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              content: FutureBuilder(
                  future: removeItemFuture,
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
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
                      return TransactionResultWidget(TransactionResult(
                          false, null, getErrorString(snapshot.error!)));
                    }
                    if (!(sharedPreferences
                            .getBool(keyShowTransactionSuccessPage) ??
                        defaultShowTransactionSuccessPage)) {
                      Navigator.pop(context);
                      return Container();
                    }
                    return TransactionResultWidget(snapshot.data!);
                  }));
        });
    var result = await removeItemFuture;
    if (result.success) {
      final controller = Slidable.of(context);
      controller!.dismiss(ResizeRequest(Duration(milliseconds: 100), () => {}));
      updateLinksKeys();
    }
    return result;
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
        setState(() {});
      },
      displacement: 2,
    );
    return buildTopLevelScaffold(
        context, Padding(padding: EdgeInsets.all(5), child: body),
        title: showArchived ? "Archived" : "My List",
        appBarActions: appBarActions,
        leadingAppBarButton: leadingAppBarAction);
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

    if (kIsWeb || await canConnectToInternet()) {
      await launchUrl(
        Uri.parse(url),
        mode: launchMode,
      );
    } else {
      await launchUrl(
        Uri.parse(getFilePathFromUrl(url)),
        mode: launchMode,
      );
    }
  }

  Widget buildListItem(String url, LinkData linkData) {
    print(downloadManager.urlToDownload);
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
            return Align(
                alignment: Alignment.center,
                child: RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.25)
                        .animate(loadingAnimationController),
                    child: AnimatedIcon(
                        size: 22,
                        icon: AnimatedIcons.search_ellipsis,
                        progress: loadingAnimationController)));
          }
          IconData iconData;
          if (snapshot.hasError) {
            iconData = Icons.error;
          } else {
            iconData = Icons.done;
          }
          return IconButton(
            icon: Icon(iconData, size: 20),
            onPressed: () async {
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
      children: [Text(subtitleSuffix), downloadingIndicator],
    );

    Widget trailing = FutureBuilder(
        future: downloadManager.urlToDownload[url]!,
        builder:
            (BuildContext context, AsyncSnapshot<DownloadMetadata> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return SizedBox(width: 10, height: 10);
          }
          if (snapshot.hasError) {
            return SizedBox(width: 10, height: 10);
          }
          if (snapshot.data!.imageProvider == null) {
            return SizedBox(width: 10, height: 10);
          }
          return FractionallySizedBox(
              widthFactor: 0.38,
              child: Image(image: snapshot.data!.imageProvider!));
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
    loadingAnimationController.dispose();
    super.dispose();
  }
}
