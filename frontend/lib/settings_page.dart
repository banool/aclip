import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';
import 'download_logs_page.dart';
import 'list_manager.dart';
import 'globals.dart';
import 'page_selector.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  bool advisoryShownOnce = false;

  @override
  Widget build(BuildContext context) {
    EdgeInsetsDirectional margin = const EdgeInsetsDirectional.only(
        start: 15, end: 15, top: 10, bottom: 10);

    SettingsSection? browserExtensionSettingsSection;
    if (runningAsBrowserExtension) {
      browserExtensionSettingsSection = SettingsSection(
        title: const Text('Browser Extension'),
        tiles: [
          SettingsTile.switchTile(
            initialValue:
                sharedPreferences.getBool(keySaveOnOpen) ?? defaultSaveOnOpen,
            title: getText(
              "Save links by default when opening extension",
            ),
            onToggle: (bool enabled) async {
              await sharedPreferences.setBool(keySaveOnOpen, enabled);
              setState(() {});
            },
          ),
        ],
        margin: margin,
      );
    }

    List<AbstractSettingsTile> linksTiles = [];
    if (!runningAsBrowserExtension) {
      linksTiles += [
        SettingsTile.switchTile(
          initialValue: sharedPreferences.getBool(keyLaunchInExternalBrowser) ??
              defaultLaunchInExternalBrowser,
          title: getText(
            "Launch in external browser",
          ),
          onToggle: (bool enabled) async {
            await sharedPreferences.setBool(
                keyLaunchInExternalBrowser, enabled);
            await sharedPreferences.setBool(keyOnlyOfflineLinks, false);
            setState(() {});
          },
        ),
        SettingsTile.switchTile(
          initialValue: sharedPreferences.getBool(keyOnlyOfflineLinks) ??
              defaultOnlyOfflineLinks,
          title: getText(
            "Only open offline versions of items",
          ),
          onToggle: (bool enabled) async {
            await sharedPreferences.setBool(keyOnlyOfflineLinks, enabled);
            await sharedPreferences.setBool(keyLaunchInExternalBrowser, false);
            setState(() {});
          },
        ),
      ];
    }
    linksTiles += [
      SettingsTile.navigation(
          title: getText(
            "Clear cache",
          ),
          trailing: Container(),
          onPressed: (BuildContext context) async {
            await downloadManager.clearCache();
            await listManager.pull();
          }),
    ];

    if (!runningAsBrowserExtension) {
      linksTiles += [
        SettingsTile.navigation(
            title: getText(
              "Offline download errors",
            ),
            trailing: Container(),
            onPressed: (BuildContext context) async {
              return await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DownloadLogsPage(),
                  ));
            }),
      ];
    }

    List<AbstractSettingsSection?> sections = [
      SettingsSection(
        title: const Text('Account'),
        tiles: [
          SettingsTile.switchTile(
            initialValue: sharedPreferences.getBool(keySecretByDefault) ??
                defaultSecretByDefault,
            title: getText(
              "Encrypt items by default",
            ),
            onToggle: (bool enabled) async {
              bool confirmed = true;
              if (enabled) {
                if (!(sharedPreferences.getBool(keyAcknowledgedSecretCaveats) ??
                    defaultAcknowledgedSecretCaveats)) {
                  confirmed = await confirmAcknowledgedSecretsCaveats(context);
                }
              }
              if (confirmed) {
                await sharedPreferences.setBool(keySecretByDefault, enabled);
              }
              setState(() {});
            },
          ),
          SettingsTile.switchTile(
            initialValue:
                sharedPreferences.getBool(keyShowTransactionSuccessPage) ??
                    defaultShowTransactionSuccessPage,
            title: getText(
              "Show transaction output on success",
            ),
            onToggle: (bool enabled) async {
              await sharedPreferences.setBool(
                  keyShowTransactionSuccessPage, enabled);
              setState(() {});
            },
          ),
          /*
          SettingsTile.navigation(
              title: getText(
                "Wipe list from account",
              ),
              trailing: Container(),
              onPressed: (BuildContext context) async {
                bool confirmed = await confirmAlert(
                    context,
                    Text(
                        "This will remove your list from your account, even if "
                        "there are items in it, and delete all local data. Are you sure?"));
                if (confirmed) {
                  await sharedPreferences.clear();
                  listManager = ListManager.fromSharedPrefs();
                  print("Reset everything");
                }
              }),
          */
        ],
        margin: margin,
      ),
      SettingsSection(
        title: const Text('Links'),
        tiles: linksTiles,
        margin: margin,
      ),
      browserExtensionSettingsSection,
      SettingsSection(
        title: const Text('Connection'),
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
        title: const Text('Details'),
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
                    builder: (context) => const LegalInformationPage(),
                  ));
            },
          ),
          SettingsTile.navigation(
            title: getText(
              'See build information',
            ),
            trailing: Container(),
            onPressed: (BuildContext context) async {
              return await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BuildInformationPage(),
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
    style: TextStyle(fontSize: size),
  );
}

// See https://github.com/banool/aclip/issues/28.
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
  TextField textField = TextField(
    key: const ValueKey("myTextField"),
    controller: textController,
  );
  // ignore: deprecated_member_use
  Widget cancelButton = ElevatedButton(
    child: Text(cancelText),
    onPressed: () {
      Navigator.of(context).pop();
    },
  );
  // ignore: deprecated_member_use
  Widget continueButton = ElevatedButton(
    key: const ValueKey("continueButton"),
    child: Text(confirmText),
    onPressed: () async {
      String newValue = textController.text.trim();
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
      const Spacer(),
      IconButton(
          onPressed: () async {
            var data = await Clipboard.getData(Clipboard.kTextPlain);
            textController.text = data?.text ?? "";
          },
          icon: const Icon(Icons.paste)),
      IconButton(
          onPressed: () {
            textController.text = defaultValue ?? "";
          },
          icon: const Icon(Icons.restore))
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
    // See https://github.com/banool/aptos_sdk_dart/issues/1.
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
      Provider.of<PageSelectorController>(context, listen: false)
          .refreshParent();
      var f = listManager.triggerPull();
      await f;
      print("Pulled list successfully");
    } catch (e) {
      print(
          "Failed to pull after setting private key, this is probably expected: $e");
    }
  }
}

class LegalInformationPage extends StatelessWidget {
  const LegalInformationPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget body = const Center(
        child: Padding(
            padding: EdgeInsets.only(bottom: 10, left: 20, right: 32, top: 20),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
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
  const BuildInformationPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (packageInfo == null) {
      body = Center(
          child: Column(children: [
        const Text("Failed to determine build information"),
        const Padding(padding: EdgeInsets.only(top: 20)),
        Text("$packageInfoRetrieveError")
      ]));
    } else {
      var p = packageInfo!;
      body = Center(
          child: Padding(
              padding:
                  const EdgeInsets.only(bottom: 10, left: 20, right: 32, top: 20),
              child:
                  Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                Text(
                  "App name: ${p.appName}\n",
                  textAlign: TextAlign.center,
                ),
                Text(
                  "Package name: ${p.packageName}\n",
                  textAlign: TextAlign.center,
                ),
                Text(
                  "Version: ${p.version}\n",
                  textAlign: TextAlign.center,
                ),
                Text(
                  "Build number: ${p.buildNumber}\n",
                  textAlign: TextAlign.center,
                ),
                Text(
                  "Build signature: ${p.buildSignature}\n",
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  child: const Text(
                    "Bookmark icon created by Freekpik - Flaticon\n",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.lightBlue),
                  ),
                  onPressed: () => launchUrl(Uri.parse(
                      "https://www.flaticon.com/free-icons/bookmark")),
                ),
              ])));
    }
    return buildTopLevelScaffold(context, body,
        title: "Build Information", isSubPage: true);
  }
}

Future<bool> confirmAlert(BuildContext context, Widget content,
    {String title = "Careful!",
    String cancelText = "Cancel",
    String confirmText = "Confirm"}) async {
  bool confirmed = false;
  Widget cancelButton = ElevatedButton(
    child: Text(cancelText),
    onPressed: () {
      Navigator.of(context).pop();
    },
  );
  Widget continueButton = ElevatedButton(
    child: Text(confirmText),
    onPressed: () {
      confirmed = true;
      Navigator.of(context).pop();
    },
  );
  AlertDialog alert = AlertDialog(
    title: Text(title),
    content: content,
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

Future<bool> confirmAcknowledgedSecretsCaveats(BuildContext context) async {
  bool confirmed = await confirmAlert(
      context,
      RichText(
          text: TextSpan(
        children: [
          const TextSpan(
            text: "Warning: Storing encrypted private information in a "
                "publicly accessible location (I.e. the Aptos blockchain) "
                "is only safe so long as you never lose your private key / "
                "associated mnemonic and the encryption scheme used is "
                "never broken. Make sure you understand these risks and "
                "weigh them against how sensitive the data you're storing "
                "on chain is before using this feature. ",
            style: TextStyle(
                color: Colors.black, fontSize: 16, fontWeight: FontWeight.w300),
          ),
          TextSpan(
              text: "Read more here.",
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  await launchUrl(Uri.parse(
                      "https://crypto.stackexchange.com/questions/46848/can-private-data-be-encrypted-and-stored-safely-in-public"));
                },
              style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w300)),
        ],
      )),
      title: "Warning",
      confirmText: "I understand");
  if (confirmed) {
    await sharedPreferences.setBool(keyAcknowledgedSecretCaveats, true);
  }
  return confirmed;
}
