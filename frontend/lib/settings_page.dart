import 'package:aclip/list_manager.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';
import 'globals.dart';
import 'page_selector.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  bool advisoryShownOnce = false;

  @override
  Widget build(BuildContext context) {
    EdgeInsetsDirectional margin = const EdgeInsetsDirectional.only(
        start: 15, end: 15, top: 10, bottom: 10);

    List<AbstractSettingsSection?> sections = [
      SettingsSection(
        title: Text('Aptos Connection Settings'),
        tiles: [
          SettingsTile.navigation(
              title: getText(
                "Aptos FullNode URL",
              ),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                bool confirmed = await showChangeStringSharedPrefDialog(context,
                    "Aptos FullNode URL", keyAptosNodeUrl, defaultAptosNodeUrl);
                if (confirmed) {
                  listManager = ListManager.fromSharedPrefs();
                  setState(() {});
                }
              }),
          SettingsTile.navigation(
              title: getText(
                "Aptos account private key",
              ),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                await runUpdatePrivateKeyDialog(context);
              }),
        ],
        margin: margin,
      ),
      SettingsSection(
        title: const Text('Legal Information'),
        tiles: [
          SettingsTile.navigation(
            title: getText(
              'See legal information',
            ),
            trailing: Container(),
            onPressed: (BuildContext context) async {
              return await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LegalInformationPage(),
                  ));
            },
          )
        ],
        margin: margin,
      ),
      SettingsSection(
        title: const Text('Community'),
        tiles: [
          SettingsTile.navigation(
            title: getText(
              "View project on GitHub",
            ),
            trailing: Container(),
            onPressed: (BuildContext context) async {
              Uri uri = Uri.https("github.com", "/banool/aclip");
              await launchUrl(uri);
            },
          ),
        ],
        margin: margin,
      ),
      SettingsSection(
        title: const Text('App Details'),
        tiles: [
          SettingsTile.navigation(
            title: getText(
              'See build information',
            ),
            trailing: Container(),
            onPressed: (BuildContext context) async {
              return await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BuildInformationPage(),
                  ));
            },
          )
        ],
        margin: margin,
      ),
    ];

    List<AbstractSettingsSection> nonNullSections = [];
    for (AbstractSettingsSection? section in sections) {
      if (section != null) {
        nonNullSections.add(section);
      }
    }

    Widget body = SettingsList(sections: nonNullSections);
    return buildTopLevelScaffold(context, body, title: "Settings");
  }
}

Text getText(String s, {bool larger = false}) {
  double size = 15;
  if (larger) {
    size = 18;
  }
  return Text(
    s,
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: size),
  );
}

Future<bool> showChangeStringSharedPrefDialog(
    BuildContext context, String title, String key, String? defaultValue,
    {String cancelText = "Cancel",
    String confirmText = "Confirm",
    bool Function(BuildContext, String)? validateFn,
    allowEmptyString = false}) async {
  bool confirmed = false;
  String currentValue = sharedPreferences.getString(key) ?? defaultValue ?? "";
  TextEditingController textController =
      TextEditingController(text: currentValue);
  // TODO allow this function to take in something that changes the type
  // of text it is, e.g. for URL vs regular stuff.
  TextField textField = TextField(
    controller: textController,
  );
  // ignore: deprecated_member_use
  Widget cancelButton = FlatButton(
    child: Text(cancelText),
    onPressed: () {
      Navigator.of(context).pop();
    },
  );
  // ignore: deprecated_member_use
  Widget continueButton = FlatButton(
    child: Text(confirmText),
    onPressed: () async {
      String newValue = textController.text;
      if (newValue == "" && !allowEmptyString) {
        print("Not setting empty string for $key");
      } else {
        bool valid = true;
        if (validateFn != null) {
          valid = validateFn(context, newValue);
        }
        if (valid) {
          await sharedPreferences.setString(key, newValue);
          print("Set $key to $newValue");
        }
        confirmed = valid;
      }
      Navigator.of(context).pop();
    },
  );
  AlertDialog alert = AlertDialog(
    title: Row(children: [
      Text(title),
      Spacer(),
      IconButton(
          onPressed: () {
            textController.text = defaultValue ?? "";
          },
          icon: Icon(Icons.restore))
    ]),
    content: textField,
    actions: [
      cancelButton,
      continueButton,
    ],
  );
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
  return confirmed;
}

bool validatePrivateKey(BuildContext context, String value) {
  // ignore: prefer_is_empty
  if (value.length == 0) return true;
  try {
    // TODO: Buff HexString.fromString so it does this check.
    var hexString = HexString.fromString(value);
    AptosAccount.fromPrivateKeyHexString(hexString);
    print("Private key was valid");
    return true;
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Private key was invalid: $e"),
    ));
    return false;
  }
}

Future<void> runUpdatePrivateKeyDialog(BuildContext context) async {
  // ignore: prefer_function_declarations_over_variables
  bool confirmed = await showChangeStringSharedPrefDialog(
      context, "Private key", keyPrivateKey, defaultPrivateKey,
      validateFn: validatePrivateKey, allowEmptyString: true);
  if (confirmed) {
    print("Private key set");
    listManager = ListManager.fromSharedPrefs();
    try {
      var f = listManager.triggerPull();
      InheritedPageSelectorController.of(context)
          .pageSelectorController
          .refreshParent();
      await f;
      print("Pulled list successfully");
    } catch (e) {
      print(
          "Failed to pull after setting private key, this is probably expected: $e");
    }
  }
}

class LegalInformationPage extends StatelessWidget {
  const LegalInformationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget body = Center(
        child: Padding(
            padding: EdgeInsets.only(bottom: 10, left: 20, right: 32, top: 20),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: const [
                  Text(
                      "This app is the sole work of the developer. "
                      "It is in no way affiliated with Aptos Labs / Matonee.\n",
                      textAlign: TextAlign.center),
                  Text(
                      "The author of this app accepts no responsibility for its "
                      "use. As it stands now, the app is designed for use with "
                      "the Aptos dev / test networks. It should not be used with "
                      "the main network when it launches in its current state.",
                      textAlign: TextAlign.center),
                ])));
    return buildTopLevelScaffold(context, body,
        title: "Legal Information", isSubPage: true);
  }
}

class BuildInformationPage extends StatelessWidget {
  const BuildInformationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget body = Center(
        child: Padding(
            padding: EdgeInsets.only(bottom: 10, left: 20, right: 32, top: 20),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.start, children: [
              Text(
                "App name: ${packageInfo.appName}\n",
                textAlign: TextAlign.center,
              ),
              Text(
                "Package name: ${packageInfo.packageName}\n",
                textAlign: TextAlign.center,
              ),
              Text(
                "Version: ${packageInfo.version}\n",
                textAlign: TextAlign.center,
              ),
              Text(
                "Build number: ${packageInfo.buildNumber}\n",
                textAlign: TextAlign.center,
              ),
              Text(
                "Build signature: ${packageInfo.buildSignature}\n",
                textAlign: TextAlign.center,
              ),
              TextButton(
                child: Text(
                  "Bookmark icon created by Freekpik - Flaticon\n",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.lightBlue),
                ),
                onPressed: () => launchUrl(
                    Uri.parse("https://www.flaticon.com/free-icons/bookmark")),
              ),
            ])));
    return buildTopLevelScaffold(context, body,
        title: "Build Information", isSubPage: true);
  }
}
