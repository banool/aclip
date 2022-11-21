import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:built_value/json_object.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pinenacl/tweetnacl.dart';
import 'package:pinenacl/x25519.dart';
import 'package:url_launcher/link.dart';

import 'common.dart';
import 'constants.dart';
import 'globals.dart';

const int maxGasAmount = 10000000;
const int gasUnitPrice = 100;

enum RemoveItemAction {
  remove,
  archive,
  unarchive,
}

String myEncryptWithSecretBox(
    SecretBox secretBox, Object object, int nonceRaw) {
  var jsonEncoded = json.encode(object);
  Uint8List nonce =
      Uint8List.fromList(List.filled(TweetNaCl.nonceLength, nonceRaw));
  var encrypted = secretBox.encrypt(Uint8List.fromList(jsonEncoded.codeUnits),
      nonce: nonce);
  return HexString.fromBytes(encrypted.cipherText.toUint8List()).withPrefix();
}

dynamic myDecryptWithSecretBox(
    SecretBox secretBox, String encrypted, int nonceRaw) {
  Uint8List nonce =
      Uint8List.fromList(List.filled(TweetNaCl.nonceLength, nonceRaw));
  var decrypted = secretBox.decrypt(
      ByteList.fromList(HexString.fromString(encrypted).toBytes()),
      nonce: nonce);
  return json.decode(String.fromCharCodes(decrypted));
}

class LinkData {
  // Whether the link came from an archived_ list.
  bool archived;

  // Whether the link came from a secret_ list.
  bool secret;

  // You'll see that tags is optional. We only fetch the tags when we have to,
  // since it requires a read per link.
  List<String>? tags;

  // Nonce, if this LinkData came from a secret link.
  int? nonce;

  LinkData(
      {required this.archived, required this.secret, this.tags, this.nonce});

  @override
  String toString() {
    return "LinkData(archived: $archived, secret: $secret, tags: $tags)";
  }

  LinkData.fromJson(Map<String, dynamic> json)
      : tags = List<String>.from(json["tags"]),
        archived = json["archived"],
        secret = json["secret"];

  // We don't include the nonce in the JSON, since it's stored in a separate
  // non-encrypted field on chain, to facilitate decryption.
  Map<String, dynamic> toJson() {
    return {
      "tags": tags ?? [],
      "archived": archived,
      "secret": secret,
    };
  }

  // Convert struct to json, then to hex, then encrypt it. We sign the message
  // using the public key, so only we can decrypt it with our private key.
  String encrypt(SecretBox secretBox, int nonceRaw) {
    return myEncryptWithSecretBox(secretBox, this, nonceRaw);
  }

  static LinkData decrypt(SecretBox secretBox, String encrypted, int nonceRaw) {
    return LinkData.fromJson(
        myDecryptWithSecretBox(secretBox, encrypted, nonceRaw));
  }
}

// Since tuples aren't allowed.
class KeyAndLinkData {
  String key;
  LinkData linkData;

  KeyAndLinkData(this.key, this.linkData);
}

// This is all to avoid https://stackoverflow.com/questions/58451500/avoid-single-frame-waiting-state-when-passing-already-completed-future-to-a-futu
class FetchDataDummy {
  Object? error;

  FetchDataDummy({this.error});
}

class ListManager extends ChangeNotifier {
  final AptosClientHelper aptosClientHelper =
      AptosClientHelper.fromDio(Dio(BaseOptions(
    baseUrl: fixNodeUrl(
        sharedPreferences.getString(keyAptosNodeUrl) ?? defaultAptosNodeUrl),
    connectTimeout: 8000,
    receiveTimeout: 8000,
    sendTimeout: 8000,
  )));
  final AptosAccount aptosAccount;

  // For encrypting and decrypting secrets we write to the chain.
  final SecretBox secretBox;

  // This is the regular and encrypted lists from the move module combined,
  // plus their archived versions. The key here is the decrypted URL in the
  // case that the link was a secret.
  LinkedHashMap<String, LinkData>? links;

  Future<FetchDataDummy>? fetchDataFuture;

  Future<FullTransactionResult> initializeList() async {
    String func = "${moduleAddress.withPrefix()}::$moduleName::initialize_list";

    return aptosClientHelper.buildSignSubmitWait(
        AptosClientHelper.buildPayload(func, [], []), aptosAccount,
        maxGasAmount: maxGasAmount, gasUnitPrice: gasUnitPrice);
  }

  /*
  Future<FullTransactionResult> obliterateList() async {
    String func = "${moduleAddress.withPrefix()}::$moduleName::obliterate";

    EntryFunctionPayloadBuilder entryFunctionPayloadBuilder =
        EntryFunctionPayloadBuilder()
          ..type = "script_function_payload"
          ..function_ = func
          ..typeArguments = ListBuilder([])
          ..arguments = ListBuilder([]);

    return aptosClientHelper.buildSignSubmitWait(
        OneOf1<ScriptFunctionPayload>(
            value: entryFunctionPayloadBuilder.build()),
        aptosAccount);
  }
  */

  List<String>? getLinksKeys({bool archived = false}) {
    if (links == null) return null;
    List<String> keys = [];
    links!.forEach((k, v) {
      if (v.archived == archived) {
        keys.add(k);
      }
    });
    return keys;
  }

  String buildResourceType({String? structNameOverride}) {
    return "0x${moduleAddress.noPrefix()}::$moduleName::${structNameOverride ?? structName}";
  }

  Future<FetchDataDummy> pull() async {
    try {
      if (await canConnectToInternet()) {
        print("Fetching data from internet");
        links = await fetchData();
      } else {
        print("Fetching data from storage because no internet access");
        links = await downloadManager.populateLinksFromStorage();
      }
      print("Updated links: $links");
      for (var url in links!.keys) {
        downloadManager.triggerDownload(url);
      }
      notifyListeners();
    } on DioError catch (e) {
      print(getErrorString(e));
      rethrow;
    } catch (e) {
      rethrow;
    }
    return FetchDataDummy();
  }

  // We don't fetch values for the keys here (therefore no tags).
  Future<LinkedHashMap<String, LinkData>> fetchData() async {
    print("Getting list from the blockchain");

    var resourceType = buildResourceType();

    MoveResource resource;
    resource = await unwrapClientCall(aptosClientHelper.client
        .getAccountsApi()
        .getAccountResource(
            address: aptosAccount.address.noPrefix(),
            resourceType: resourceType));

    // Process info from the resources.
    var inner = resource.data.asMap["inner"];

    // Get the queue as it is in the account.
    LinkedHashMap<String, LinkData> out = LinkedHashMap();

    // Read regular links.
    for (dynamic item in (inner["links"]["data"] ?? {})) {
      out[item["key"]] = LinkData(archived: false, secret: false);
    }

    // Read archived links.
    for (dynamic item in (inner["archived_links"]["data"] ?? {})) {
      out[item["key"]] = LinkData(archived: true, secret: false);
    }

    KeyAndLinkData readSecretItem(dynamic item, bool archived) {
      int nonce = int.parse(item["value"]["nonce"]);
      String key = myDecryptWithSecretBox(secretBox, item["key"], nonce);
      // We don't bother reading the actual LinkData (tags) for now.
      LinkData linkData =
          LinkData(archived: archived, secret: true, nonce: nonce);
      return KeyAndLinkData(key, linkData);
    }

    // Read secret links.
    for (dynamic item in (inner["secret_links"]["data"] ?? {})) {
      var keyAndLinkData = readSecretItem(item, false);
      out[keyAndLinkData.key] = keyAndLinkData.linkData;
    }

    // Read archived secret links.
    for (dynamic item in (inner["archived_secret_links"]["data"] ?? {})) {
      var keyAndLinkData = readSecretItem(item, true);
      out[keyAndLinkData.key] = keyAndLinkData.linkData;
    }

    return out;
  }

  Future<FetchDataDummy> triggerPull() async {
    fetchDataFuture = pull();
    return fetchDataFuture!;
  }

  Future<FullTransactionResult> addItem(
      String url, bool secret, List<String> tags) async {
    url = url.trim().replaceAll("\n", "");

    List<JsonObject> arguments;
    String function_ = "${moduleAddress.withPrefix()}::$moduleName::";
    if (secret) {
      // Build the LinkData.
      var linkData = LinkData(archived: false, secret: secret);

      // Generate a nonce.
      var rng = Random();
      int nonceRaw = rng.nextInt(4294967294) + 1;

      // Encrypt the key.
      var urlEncrypted = myEncryptWithSecretBox(secretBox, url, nonceRaw);
      var linkDataEncrypted = linkData.encrypt(secretBox, nonceRaw);
      arguments = [
        StringJsonObject(urlEncrypted),
        StringJsonObject(linkDataEncrypted),
        StringJsonObject("$nonceRaw"), // The API expects numbers as strings.
        BoolJsonObject(false),
      ];
      function_ += "add_secret";
    } else {
      arguments = [
        StringJsonObject(HexString.fromRegularString(url).noPrefix()),
        ListJsonObject(tags
            .map((e) => HexString.fromRegularString(e).noPrefix())
            .toList()),
        BoolJsonObject(false),
      ];
      function_ += "add";
    }

    FullTransactionResult result = await aptosClientHelper.buildSignSubmitWait(
        AptosClientHelper.buildPayload(function_, [], arguments), aptosAccount,
        maxGasAmount: maxGasAmount, gasUnitPrice: gasUnitPrice);

    if (result.committed) {
      links![url] = LinkData(archived: false, secret: secret);
      notifyListeners();
    }

    downloadManager.triggerDownload(url);

    return result;
  }

  Future<FullTransactionResult> removeItem(
      String url, LinkData linkData, RemoveItemAction action) async {
    bool archiveArgument;
    String function_ = "${moduleAddress.withPrefix()}::$moduleName::";

    switch (action) {
      case RemoveItemAction.remove:
        function_ += "remove";
        archiveArgument = linkData.archived;
        break;
      case RemoveItemAction.archive:
        function_ += "set_archived";
        archiveArgument = true;
        break;
      case RemoveItemAction.unarchive:
        function_ += "set_archived";
        archiveArgument = false;
        break;
    }

    String urlEncoded;
    if (linkData.secret) {
      urlEncoded = myEncryptWithSecretBox(secretBox, url, linkData.nonce!);
    } else {
      urlEncoded = HexString.fromRegularString(url).noPrefix();
    }

    List<JsonObject> arguments = [
      StringJsonObject(urlEncoded),
      BoolJsonObject(archiveArgument),
      BoolJsonObject(linkData.secret),
    ];

    FullTransactionResult result = await aptosClientHelper.buildSignSubmitWait(
        AptosClientHelper.buildPayload(function_, [], arguments), aptosAccount,
        maxGasAmount: maxGasAmount, gasUnitPrice: gasUnitPrice);

    if (result.committed) {
      switch (action) {
        case RemoveItemAction.remove:
          links!.remove(url);
          break;
        case RemoveItemAction.archive:
          links![url]!.archived = true;
          break;
        case RemoveItemAction.unarchive:
          links![url]!.archived = false;
          break;
      }
      notifyListeners();
    }

    return result;
  }

  // This assumes the private key is already set.
  factory ListManager.fromSharedPrefs() {
    AptosAccount aptosAccount;
    HexString privateKey;
    try {
      privateKey = getPrivateKey()!;
      print("Private key from shared prefs: ${privateKey.withPrefix()}");
      aptosAccount = AptosAccount.fromPrivateKeyHexString(privateKey);
    } catch (e) {
      sharedPreferences.clear();
      print(
          "Failed to make ListManager from private key so we cleared shared prefs: $e");
      rethrow;
    }

    SecretBox secretBox = SecretBox(privateKey.toBytes());

    listManagerSet = true;
    return ListManager(aptosAccount, secretBox);
  }

  ListManager(this.aptosAccount, this.secretBox);
}
