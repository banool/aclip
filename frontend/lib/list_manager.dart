import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:built_value/json_object.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pinenacl/tweetnacl.dart';
import 'package:pinenacl/x25519.dart';

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
      ByteList(HexString.fromString(encrypted).toBytes()),
      nonce: nonce);
  return json.decode(String.fromCharCodes(decrypted));
}

// TODO: Rename this to something like LinkDataWrapperWrapper, since this doesn't
// match the LinkDataWrapper struct on-chain.
class LinkDataWrapper {
  // Whether the link came from an archived_ list.
  bool archived;

  // Whether the link came from a secret_ list.
  bool secret;

  // When the link was added, in microseconds.
  int addedAtMicros;

  List<String> tags;

  // Nonce, if this LinkDataWrapper came from a secret link.
  int? nonce;

  LinkDataWrapper(
      {required this.archived,
      required this.secret,
      required this.addedAtMicros,
      required this.tags,
      this.nonce});

  @override
  String toString() {
    return "LinkDataWrapper(archived: $archived, secret: $secret, tags: $tags)";
  }

  // Build a LinkDataWrapper from decrypted on-chain LinkData.
  LinkDataWrapper.fromJson(
      Map<String, dynamic> json, this.archived, this.secret,
      {this.nonce})
      : addedAtMicros = json["added_at_microseconds"],
        tags = List<String>.from(json["tags"]);

  // We only include the stuff in the on-chain LinkData struct here.
  // So in effect, this produces a JSON representation of LinkData.
  Map<String, dynamic> toJson() {
    return {
      "added_at_microseconds": addedAtMicros,
      "tags": tags,
    };
  }

  // Convert struct to json, then to hex, then encrypt it. We sign the message
  // using the public key, so only we can decrypt it with our private key.
  String encrypt(SecretBox secretBox, int nonceRaw) {
    return myEncryptWithSecretBox(secretBox, toJson(), nonceRaw);
  }

  // Takes the on-chain encrypted LinkData and returns a LinkDataWrapper.
  static LinkDataWrapper decrypt(SecretBox secretBox, String encryptedLinkData,
      int nonceRaw, bool archived) {
    var decryptedLinkData =
        myDecryptWithSecretBox(secretBox, encryptedLinkData, nonceRaw);
    return LinkDataWrapper.fromJson(decryptedLinkData, archived, true,
        nonce: nonceRaw);
  }
}

// Since tuples aren't allowed.
class KeyAndLinkDataWrapper {
  String key;
  LinkDataWrapper linkDataWrapper;

  KeyAndLinkDataWrapper(this.key, this.linkDataWrapper);
}

// This is all to avoid https://stackoverflow.com/questions/58451500/avoid-single-frame-waiting-state-when-passing-already-completed-future-to-a-futu
class FetchDataDummy {
  Object? error;
  FetchDataDummy({this.error});
}

class ListManager extends ChangeNotifier {
  final AptosAccount aptosAccount;

  // For encrypting and decrypting secrets we write to the chain.
  final SecretBox secretBox;

  // This is the regular and encrypted lists from the move module combined,
  // plus their archived versions. The key here is the decrypted URL in the
  // case that the link was a secret.
  LinkedHashMap<String, LinkDataWrapper>? links;

  Future<FetchDataDummy>? fetchDataFuture;

  AptosClientHelper getAptosClientHelper() {
    final dio = Dio();
    dio.interceptors.add(cookieManager);
    return AptosClientHelper.fromDio(Dio(BaseOptions(
      baseUrl: fixNodeUrl(
          sharedPreferences.getString(keyAptosNodeUrl) ?? defaultAptosNodeUrl),
      connectTimeout: const Duration(milliseconds: 8000),
      receiveTimeout: const Duration(milliseconds: 8000),
      sendTimeout: const Duration(milliseconds: 8000),
    )));
  }

  Future<FullTransactionResult> initializeList() async {
    String func = "${moduleAddress.withPrefix()}::$moduleName::initialize_list";

    return getAptosClientHelper().buildSignSubmitWait(
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
  Future<LinkedHashMap<String, LinkDataWrapper>> fetchData() async {
    print("Getting list from the blockchain");

    var resourceType = buildResourceType();

    MoveResource resource;
    resource = await unwrapClientCall(getAptosClientHelper()
        .client
        .getAccountsApi()
        .getAccountResource(
            address: aptosAccount.address.noPrefix(),
            resourceType: resourceType));

    // Process info from the resources.
    var inner = resource.data.asMap["inner"];

    // Get the queue as it is in the account.
    LinkedHashMap<String, LinkDataWrapper> out = LinkedHashMap();

    // Read regular links.
    for (dynamic item in (inner["links"]["data"] ?? {})) {
      out[item["key"]] = LinkDataWrapper(
          archived: false,
          secret: false,
          addedAtMicros: int.parse(item["value"]["added_at_microseconds"]),
          tags: List<String>.from(item["value"]["tags"]));
    }

    // Read archived links.
    for (dynamic item in (inner["archived_links"]["data"] ?? {})) {
      out[item["key"]] = LinkDataWrapper(
          archived: true,
          secret: false,
          addedAtMicros: int.parse(item["value"]["added_at_microseconds"]),
          tags: List<String>.from(item["value"]["tags"]));
    }

    KeyAndLinkDataWrapper readSecretItem(dynamic item, bool archived) {
      int nonce = int.parse(item["value"]["nonce"]);
      String key = myDecryptWithSecretBox(secretBox, item["key"], nonce);
      LinkDataWrapper linkDataWrapper = LinkDataWrapper.decrypt(
          secretBox, item["value"]["link_data"], nonce, archived);
      return KeyAndLinkDataWrapper(key, linkDataWrapper);
    }

    // Read secret links.
    for (dynamic item in (inner["secret_links"]["data"] ?? {})) {
      var keyAndLinkDataWrapper = readSecretItem(item, false);
      out[keyAndLinkDataWrapper.key] = keyAndLinkDataWrapper.linkDataWrapper;
    }

    // Read archived secret links.
    for (dynamic item in (inner["archived_secret_links"]["data"] ?? {})) {
      var keyAndLinkDataWrapper = readSecretItem(item, true);
      out[keyAndLinkDataWrapper.key] = keyAndLinkDataWrapper.linkDataWrapper;
    }

    // Create a new map sorted by time added.
    var sortedEntries = out.entries.toList()
      ..sort((e1, e2) {
        var diff = e2.value.addedAtMicros.compareTo(e1.value.addedAtMicros);
        if (diff == 0) diff = e2.key.compareTo(e1.key);
        return diff;
      });
    out
      ..clear()
      ..addEntries(sortedEntries);

    return out;
  }

  Future<FetchDataDummy> triggerPull() async {
    fetchDataFuture = pull();
    return fetchDataFuture!;
  }

  Future<FullTransactionResult> addItem(
      String url, bool secret, List<String> tags) async {
    url = url.trim().replaceAll("\n", "");

    // Build the LinkDataWrapper.
    var linkDataWrapper = LinkDataWrapper(
        archived: false,
        secret: secret,
        tags: tags,
        // Note, for non-secret items, we use the on-chain time, but this uses
        // the time from the client. Not ideal, but that's what it is right now.
        addedAtMicros: DateTime.now().microsecondsSinceEpoch);

    List<JsonObject> arguments;
    String function_ = "${moduleAddress.withPrefix()}::$moduleName::";
    if (secret) {
      // Generate a nonce.
      var rng = Random();
      int nonceRaw = rng.nextInt(4294967294) + 1;

      // Encrypt the key.
      var urlEncrypted = myEncryptWithSecretBox(secretBox, url, nonceRaw);
      var linkDataWrapperEncrypted =
          linkDataWrapper.encrypt(secretBox, nonceRaw);
      arguments = [
        StringJsonObject(urlEncrypted),
        StringJsonObject(linkDataWrapperEncrypted),
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

    FullTransactionResult result = await getAptosClientHelper()
        .buildSignSubmitWait(
            AptosClientHelper.buildPayload(function_, [], arguments),
            aptosAccount,
            maxGasAmount: maxGasAmount,
            gasUnitPrice: gasUnitPrice);

    if (result.committed) {
      links![url] = linkDataWrapper;
      notifyListeners();
    }

    downloadManager.triggerDownload(url);

    return result;
  }

  Future<FullTransactionResult> removeItem(String url,
      LinkDataWrapper linkDataWrapper, RemoveItemAction action) async {
    bool archiveArgument;
    String function_ = "${moduleAddress.withPrefix()}::$moduleName::";

    switch (action) {
      case RemoveItemAction.remove:
        function_ += "remove";
        archiveArgument = linkDataWrapper.archived;
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
    if (linkDataWrapper.secret) {
      urlEncoded =
          myEncryptWithSecretBox(secretBox, url, linkDataWrapper.nonce!);
    } else {
      urlEncoded = HexString.fromRegularString(url).noPrefix();
    }

    List<JsonObject> arguments = [
      StringJsonObject(urlEncoded),
      BoolJsonObject(archiveArgument),
      BoolJsonObject(linkDataWrapper.secret),
    ];

    FullTransactionResult result = await getAptosClientHelper()
        .buildSignSubmitWait(
            AptosClientHelper.buildPayload(function_, [], arguments),
            aptosAccount,
            maxGasAmount: maxGasAmount,
            gasUnitPrice: gasUnitPrice);

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
