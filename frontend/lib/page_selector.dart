import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'add_item_screen.dart';
import 'common.dart';
import 'constants.dart';
import 'globals.dart';
import 'list_manager.dart';
import 'list_page_selector.dart';
import 'settings_page.dart';

class PageSelector extends StatefulWidget {
  const PageSelector({super.key});

  @override
  State<PageSelector> createState() => PageSelectorState();
}

class PageSelectorState extends State<PageSelector> {
  late PageSelectorController pageSelectorController;
  ValueKey childKey = const ValueKey(0);

  // ignore: unused_field
  late StreamSubscription _intentDataStreamSubscription;

  Future<void> handleShareUrl(Uri value) async {
    if (!listManagerSet) {
      await myShowDialog(
          context, const Text("You must setup aclip before adding links."),
          title: "Setup incomplete");
      return;
    }
    bool makeEncrypted =
        sharedPreferences.getBool(keySecretByDefault) ?? defaultSecretByDefault;
    Future? addItemFuture = listManager.addItem(
        value.toString().trim().replaceAll("\n", " "), makeEncrypted, []);
    await myShowDialog(context, buildAddItemView(addItemFuture),
        title: "Adding item...");
    refresh();
  }

  @override
  void initState() {
    pageSelectorController = PageSelectorController(refresh);

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    if (!kIsWeb) {
      _intentDataStreamSubscription =
          ReceiveSharingIntent.getTextStreamAsUri().listen((Uri value) async {
        await handleShareUrl(value);
      }, onError: (err) async {
        await showErrorInDialog(context, err);
      });

      // For sharing or opening urls/text coming from outside the app while the app is closed
      ReceiveSharingIntent.getInitialTextAsUri().then((Uri? value) async {
        if (value == null) {
          return;
        }
        await handleShareUrl(value);
      });
    }

    super.initState();
  }

  void refresh() {
    setState(() {
      // This forces the child to rebuild.
      childKey = ValueKey(childKey.value + 1);
      print("Refreshing parent");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          Provider(create: (_) => PageSelectorController(refresh)),
          ChangeNotifierProvider.value(value: downloadManager)
        ],
        builder: (BuildContext context, Widget? child) {
          var pageSelectorController =
              Provider.of<PageSelectorController>(context);
          if (getPrivateKey() == null) {
            print("Returning body without fetch data provider");
            return pageSelectorController.getCurrentScaffold();
          }
          print("Returning body with fetch data provider");
          return FutureProvider<FetchDataDummy?>.value(
            value: listManager.fetchDataFuture,
            initialData: null,
            catchError: (BuildContext context, Object? error) {
              return FetchDataDummy(error: error);
            },
            builder: (_, __) {
              return pageSelectorController.getCurrentScaffold();
            },
          );
        });
  }
}

class TabInformation {
  final BottomNavigationBarItem bottomNavBarItem;
  final Widget tabBody;

  TabInformation(this.bottomNavBarItem, this.tabBody);
}

class PageSelectorController {
  final void Function() refreshParent;

  int currentNavBarIndex = 0;

  final List<TabInformation> tabs = [
    TabInformation(
        const BottomNavigationBarItem(
          icon: Icon(Icons.list_alt),
          label: "List",
        ),
        const ListPageSelector()),
    TabInformation(
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: "Settings",
        ),
        const SettingsPage()),
  ];

  List<BottomNavigationBarItem> getBottomNavBarItems() {
    return tabs.map((e) => e.bottomNavBarItem).toList();
  }

  Widget getCurrentScaffold() {
    return tabs[currentNavBarIndex].tabBody;
  }

  void onNavBarItemTapped(int index) {
    currentNavBarIndex = index;
    refreshParent();
  }

  PageSelectorController(this.refreshParent);
}

Scaffold buildTopLevelScaffold(
  BuildContext context,
  Widget body, {
  Widget? floatingActionButton,
  String? title,
  bool isSubPage = false,
  List<Widget>? appBarActions,
  Widget? leadingAppBarButton,
  BottomAppBar? customBottomAppBar,
}) {
  AppBar? appBar;
  if (title != null) {
    appBar = AppBar(
      leading: leadingAppBarButton,
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      toolbarHeight: 50,
      centerTitle: true,
      actions: appBarActions,
    );
  }
  BottomNavigationBar? bottomNavigationBar;
  if (!isSubPage) {
    PageSelectorController p = Provider.of<PageSelectorController>(context);
    bottomNavigationBar = BottomNavigationBar(
      items: p.getBottomNavBarItems(),
      currentIndex: p.currentNavBarIndex,
      selectedItemColor: mainColor,
      onTap: p.onNavBarItemTapped,
      type: BottomNavigationBarType.fixed,
    );
  }
  return Scaffold(
    body: body,
    appBar: appBar,
    floatingActionButton: floatingActionButton,
    bottomNavigationBar: customBottomAppBar ?? bottomNavigationBar,
  );
}
