import 'package:aclip/list_page.dart';
import 'package:flutter/material.dart';

import 'constants.dart';
import 'settings_page.dart';

class PageSelector extends StatefulWidget {
  const PageSelector({Key? key}) : super(key: key);

  @override
  State<PageSelector> createState() => PageSelectorState();
}

class PageSelectorState extends State<PageSelector> {
  late PageSelectorController pageSelectorController;

  @override
  void initState() {
    pageSelectorController = PageSelectorController(refresh);
    super.initState();
  }

  void refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return InheritedPageSelectorController(
        pageSelectorController: pageSelectorController,
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
          label: "Links",
        ),
        ListPage()),
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

// TODO: On web, show a sidebar down the left instead of a bottom tab bar.
Scaffold buildTopLevelScaffold(BuildContext context, Widget body,
    {Widget? floatingActionButton,
    String? title,
    bool isSubPage = false,
    List<Widget>? appBarActions,
    Widget? leadingAppBarButton}) {
  AppBar? appBar;
  if (title != null) {
    appBar = AppBar(
      leading: leadingAppBarButton,
      title: Text(title),
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
    bottomNavigationBar: bottomNavigationBar,
  );
}
