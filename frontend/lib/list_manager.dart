import 'dart:collection';
import 'dart:convert';

import 'package:aclip/common.dart';
import 'package:aclip/constants.dart';
import 'package:aclip/globals.dart';
import 'package:aptos_sdk_dart/aptos_client_helper.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:dio/dio.dart';
import 'package:one_of/one_of.dart';
import 'package:pinenacl/ed25519.dart';
import 'package:pinenacl/x25519.dart';

enum RemoveItemAction {
  remove,
  archive,
  unarchive,
}

Uint8List encryptWithSealedBox(SealedBox sealedBox, Object object) {
  print(json.encode(object));
  print(HexString.fromRegularString(jsonEncode(object)).noPrefix());
  return sealedBox
      .encrypt(HexString.fromRegularString(json.encode(object)).toBytes());
}

T decryptWithSealedBox<T>(SealedBox sealedBox, Uint8List encrypted) {
  return json.decode(
      HexString.fromBytes(sealedBox.decrypt(encrypted)).toRegularString());
}

String getUrlForTransaction(SealedBox sealedBox, String url, bool secret) {
  HexString hexString;
  if (secret) {
    hexString = HexString.fromBytes(encryptWithSealedBox(sealedBox, url));
  } else {
    hexString = HexString.fromRegularString(url);
  }
  return hexString.noPrefix();
}

class LinkData {
  // You'll see that tags is optional. We only fetch the tags when we have to,
  // since it requires a read per link.
  List<String>? tags;

  // Whether the link came from an archived_ list.
  bool archived;

  // Whether the link came from a secret_ list.
  bool secret;

  LinkData(this.archived, this.secret, {this.tags});

  @override
  String toString() {
    return "LinkData(archived: $archived, secret: $secret, tags: $tags)";
  }

  LinkData.fromJson(Map<String, dynamic> json)
      : tags = json["tags"],
        archived = json["archived"],
        secret = json["secret"];

  Map<String, dynamic> toJson() {
    return {
      "tags": tags ?? [],
      "archived": archived,
      "secret": secret,
    };
  }

  // Convert struct to json, then to hex, then encrypt it. We sign the message
  // using the public key, so only we can decrypt it with our private key.
  Uint8List encrypt(SealedBox sealedBox) {
    return encryptWithSealedBox(sealedBox, this);
  }

  static LinkData decrypt(SealedBox sealedBox, Uint8List encrypted) {
    return decryptWithSealedBox<LinkData>(sealedBox, encrypted);
  }
}

class ListManager {
  final AptosClientHelper aptosClientHelper = AptosClientHelper.fromBaseUrl(
      sharedPreferences.getString(keyAptosNodeUrl) ?? defaultAptosNodeUrl);
  final AptosAccount aptosAccount;
  final SealedBox sealedBox;

  // This is the regular and encrypted lists from the move module combined,
  // plus their archived versions. The key here is the decrypted URL in the
  // case that the link was a secret.
  LinkedHashMap<String, LinkData>? links;

  Future? fetchDataFuture;

  Future<TransactionResult> initializeList() async {
    String func = "${moduleAddress.withPrefix()}::$moduleName::initialize_list";

    // Build a script function payload that transfers coin.
    ScriptFunctionPayloadBuilder scriptFunctionPayloadBuilder =
        ScriptFunctionPayloadBuilder()
          ..type = "script_function_payload"
          ..function_ = func
          ..typeArguments = ListBuilder([])
          ..arguments = ListBuilder([]);

    return signBuildWait(scriptFunctionPayloadBuilder);
  }

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

  String buildResourceType({String? structName}) {
    return "0x${moduleAddress.noPrefix()}::$moduleName::${structName ?? moduleName}";
  }

  Future<void> pull() async {
    try {
      links = await fetchData();
      print("New links: $links");
    } on DioError catch (e) {
      print(getErrorString(e));
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // We don't fetch values for the keys here (therefore no tags).
  Future<LinkedHashMap<String, LinkData>> fetchData() async {
    print("Getting list from the blockchain");

    var resourceType = buildResourceType();

    AccountResource resource;
    resource = await unwrapClientCall(aptosClientHelper.client
        .getAccountsApi()
        .getAccountResource(
            address: moduleAddress.noPrefix(), resourceType: resourceType));

    // Process info from the resources.
    var inner = resource.data.asMap["inner"];

    // Get the queue as it is in the account.
    LinkedHashMap<String, LinkData> out = LinkedHashMap();

    // Read regular links.
    for (String url in inner["links"]["keys"]) {
      out[url] = LinkData(false, false);
    }

    // Read archived links.
    for (String url in inner["archived_links"]["keys"]) {
      out[url] = LinkData(true, false);
    }

    // Read secret links.
    for (String url in inner["secret_links"]["keys"]) {
      out[url] = LinkData(false, true);
    }

    // Read archived secret links.
    for (String url in inner["archived_secret_links"]["keys"]) {
      out[url] = LinkData(true, true);
    }

    return out;
  }

  Future<void> triggerPull() async {
    fetchDataFuture = pull();
    return fetchDataFuture;
  }

  Future<TransactionResult> addItem(
      String url, bool secret, List<String> tags) async {
    List<JsonObject> arguments;
    String function_ = "${moduleAddress.withPrefix()}::$moduleName::";
    String urlForTransaction = getUrlForTransaction(sealedBox, url, secret);
    if (secret) {
      var linkData = LinkData(false, secret);
      var linkDataEncrypted = linkData.encrypt(sealedBox);
      arguments = [
        StringJsonObject(urlForTransaction),
        StringJsonObject(HexString.fromBytes(linkDataEncrypted).noPrefix()),
        BoolJsonObject(false),
      ];
      function_ += "add_secret";
    } else {
      arguments = [
        StringJsonObject(urlForTransaction),
        ListJsonObject(tags
            .map((e) => HexString.fromRegularString(e).noPrefix())
            .toList()),
        BoolJsonObject(false),
      ];
      function_ += "add";
    }

    ScriptFunctionPayloadBuilder scriptFunctionPayloadBuilder =
        ScriptFunctionPayloadBuilder()
          ..type = "script_function_payload"
          ..function_ = function_
          ..typeArguments = ListBuilder([])
          ..arguments = ListBuilder(arguments);

    var result = await signBuildWait(scriptFunctionPayloadBuilder);

    if (result.success) {
      links![url] = LinkData(false, secret);
    }

    return result;
  }

  Future<TransactionResult> removeItem(
      String url, LinkData linkData, RemoveItemAction action) async {
    String urlForTransaction =
        getUrlForTransaction(sealedBox, url, linkData.secret);

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

    List<JsonObject> arguments = [
      StringJsonObject(urlForTransaction),
      BoolJsonObject(archiveArgument),
      BoolJsonObject(linkData.secret),
    ];

    ScriptFunctionPayloadBuilder scriptFunctionPayloadBuilder =
        ScriptFunctionPayloadBuilder()
          ..type = "script_function_payload"
          ..function_ = function_
          ..typeArguments = ListBuilder([])
          ..arguments = ListBuilder(arguments);

    var result = await signBuildWait(scriptFunctionPayloadBuilder);

    if (result.success) {
      switch (action) {
        case RemoveItemAction.remove:
          links!.remove(url);
          break;
        case RemoveItemAction.archive:
          links!["url"]!.archived = true;
          break;
        case RemoveItemAction.unarchive:
          links!["url"]!.archived = false;
          break;
      }
    }

    return result;
  }

  Future<TransactionResult> signBuildWait(
      ScriptFunctionPayloadBuilder scriptFunctionPayloadBuilder) async {
    TransactionPayloadBuilder transactionPayloadBuilder =
        TransactionPayloadBuilder()
          ..oneOf = OneOf1(value: scriptFunctionPayloadBuilder.build());

    $UserTransactionRequestBuilder userTransactionBuilder =
        await aptosClientHelper.generateTransaction(
            aptosAccount.address, transactionPayloadBuilder);

    SubmitTransactionRequestBuilder submitTransactionRequestBuilder =
        await aptosClientHelper.signTransaction(
            aptosAccount, userTransactionBuilder);

    bool committed = false;
    String? errorString;

    try {
      PendingTransaction pendingTransaction = await unwrapClientCall(
          aptosClientHelper.client.getTransactionsApi().submitTransaction(
              submitTransactionRequest:
                  submitTransactionRequestBuilder.build()));

      PendingTransactionResult pendingTransactionResult =
          await aptosClientHelper.waitForTransaction(pendingTransaction.hash);

      committed = pendingTransactionResult.committed;
      errorString = pendingTransactionResult.getErrorString();
    } catch (e) {
      errorString = getErrorString(e);
    }

    return TransactionResult(
        committed, userTransactionBuilder.build(), errorString);
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
    AsymmetricPublicKey publicKey = VerifyKey(aptosAccount.pubKey().toBytes());
    SealedBox sealedBox = SealedBox(publicKey);
    return ListManager(aptosAccount, sealedBox);
  }

  ListManager(this.aptosAccount, this.sealedBox);
}
