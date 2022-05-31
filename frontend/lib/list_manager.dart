import 'package:aclip/common.dart';
import 'package:aclip/constants.dart';
import 'package:aclip/globals.dart';
import 'package:aptos_sdk_dart/aptos_client_helper.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';

class Link {
  Uri url;
  List<String> tags;
  bool archived;

  Link(this.url, this.tags, this.archived);
}

class ListManager {
  final AptosClientHelper aptosClientHelper = AptosClientHelper.fromBaseUrl(
      sharedPreferences.getString(keyAptosNodeUrl) ?? defaultAptosNodeUrl);
  final AptosAccount aptosAccount;

  List<Link>? links;

  Future? fetchDataFuture;

  List<Link>? getActiveLinks() {
    if (links == null) return null;
    return links!.where((e) => !e.archived).toList();
  }

  List<Link>? getArchivedLinks() {
    if (links == null) return null;
    return links!.where((e) => e.archived).toList();
  }

  String buildResourceType({String? structName}) {
    return "0x$moduleAddress::$moduleName::${structName ?? moduleName}";
  }

  Future<void> pull() async {
    links = await fetchData();
  }

  Future<List<Link>> fetchData() async {
    print("Getting list from the blockchain");

    var resourceType = buildResourceType();

    AccountResource resource;
    resource = await unwrapClientCall(aptosClientHelper.client
        .getAccountsApi()
        .getAccountResource(
            address: moduleAddress, resourceType: resourceType));

    // Process info from the resources.
    var inner = resource.data.asMap["inner"];
    var links = inner["links"];

    // Get the queue as it is in the account.
    List<Link> out = [];
    for (Map<String, dynamic> o in links) {
      print(o);
    }

    return out;
  }

  Future<void> triggerPull() async {
    fetchDataFuture = pull();
    return fetchDataFuture;
  }

  // This assumes the private key is already set.
  factory ListManager.fromSharedPrefs() {
    AptosAccount aptosAccount;
    try {
      var privateKey = getPrivateKey()!;
      print("Private key from shared prefs: ${privateKey.withPrefix()}");
      aptosAccount = AptosAccount.fromPrivateKeyHexString(privateKey);
    } catch (e) {
      sharedPreferences.clear();
      print(
          "Failed to make ListManager from private key so we cleared shared prefs: $e");
      rethrow;
    }
    return ListManager(aptosAccount);
  }
  ListManager(this.aptosAccount);
}
