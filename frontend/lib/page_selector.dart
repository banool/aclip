import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'add_item_screen.dart';
import 'common.dart';
import 'constants.dart';
import 'globals.dart';
import 'list_page_selector.dart';
import 'settings_page.dart';

class PageSelector extends StatefulWidget {
  const PageSelector({Key? key}) : super(key: key);

  @override
  State<PageSelector> createState() => PageSelectorState();
}

class PageSelectorState extends State<PageSelector> {
  late PageSelectorController pageSelectorController;
  ValueKey childKey = ValueKey(0);

  // ignore: unused_field
  late StreamSubscription _intentDataStreamSubscription;

  Future<void> handleShareUrl(Uri value) async {
    if (!listManagerSet) {
      await myShowDialog(
          context, Text("You must setup aclip before adding links."),
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return InheritedPageSelectorController(
        pageSelectorController: pageSelectorController,
        key: childKey,
        child: pageSelectorController.getCurrentScaffold());
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
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt),
          label: "List",
        ),
        ListPageSelector()),
    TabInformation(
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: "Settings",
        ),
        SettingsPage()),
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

class InheritedPageSelectorController extends InheritedWidget {
  final PageSelectorController pageSelectorController;

  const InheritedPageSelectorController(
      {required this.pageSelectorController, required Widget child, Key? key})
      : super(child: child, key: key);

  @override
  bool updateShouldNotify(InheritedPageSelectorController oldWidget) {
    if (pageSelectorController.currentNavBarIndex !=
        oldWidget.pageSelectorController.currentNavBarIndex) {
      return true;
    }
    return false;
  }

  static InheritedPageSelectorController of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<InheritedPageSelectorController>()!;
  }
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
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      toolbarHeight: 50,
      centerTitle: true,
      actions: appBarActions,
    );
  }
  BottomNavigationBar? bottomNavigationBar;
  if (!isSubPage) {
    var p = InheritedPageSelectorController.of(context);
    bottomNavigationBar = BottomNavigationBar(
      items: p.pageSelectorController.getBottomNavBarItems(),
      currentIndex: p.pageSelectorController.currentNavBarIndex,
      selectedItemColor: mainColor,
      onTap: p.pageSelectorController.onNavBarItemTapped,
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
