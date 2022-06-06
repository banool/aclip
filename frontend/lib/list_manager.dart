import 'dart:collection';
import 'dart:convert';

import 'package:aclip/common.dart';
import 'package:aclip/constants.dart';
import 'package:aclip/globals.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:one_of/one_of.dart';
import 'package:pinenacl/tweetnacl.dart';
import 'package:pinenacl/x25519.dart';

// TODO: This is obviously bad and potentially completely invalidates the
// encryption, investigate an alternative.
Uint8List nonce = Uint8List.fromList(List.filled(TweetNaCl.nonceLength, 1));

enum RemoveItemAction {
  remove,
  archive,
  unarchive,
}

String myEncryptWithSecretBox(SecretBox secretBox, Object object) {
  var jsonEncoded = json.encode(object);
  var encrypted = secretBox.encrypt(Uint8List.fromList(jsonEncoded.codeUnits),
      nonce: nonce);
  return HexString.fromBytes(encrypted.cipherText.toUint8List()).withPrefix();
}

dynamic myDecryptWithSecretBox(SecretBox secretBox, String encrypted) {
  var decrypted = secretBox.decrypt(
      ByteList.fromList(HexString.fromString(encrypted).toBytes()),
      nonce: nonce);
  return json.decode(String.fromCharCodes(decrypted));
}

class LinkData {
  // You'll see that tags is optional. We only fetch the tags when we have to,
  // since it requires a read per link.
  List<String>? tags;

  // Whether the link came from an archived_ list.
  bool archived;

  // Whether the link came from a secret_ list.
  bool secret;

  LinkData({required this.archived, required this.secret, this.tags});

  @override
  String toString() {
    return "LinkData(archived: $archived, secret: $secret, tags: $tags)";
  }

  LinkData.fromJson(Map<String, dynamic> json)
      : tags = List<String>.from(json["tags"]),
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
  String encrypt(SecretBox secretBox) {
    return myEncryptWithSecretBox(secretBox, this);
  }

  static LinkData decrypt(SecretBox secretBox, String encrypted) {
    return LinkData.fromJson(myDecryptWithSecretBox(secretBox, encrypted));
  }
}

class ListManager {
  final AptosClientHelper aptosClientHelper =
      AptosClientHelper.fromDio(Dio(BaseOptions(
    baseUrl:
        sharedPreferences.getString(keyAptosNodeUrl) ?? defaultAptosNodeUrl,
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

  Future<TransactionResult> obliterateList() async {
    String func = "${moduleAddress.withPrefix()}::$moduleName::obliterate";

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
      print("Updated links: $links");
      if (!kIsWeb) {
        for (var url in links!.keys) {
          downloadManager.triggerDownload(url);
        }
      }
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
      out[url] = LinkData(archived: false, secret: false);
    }

    // Read archived links.
    for (String url in inner["archived_links"]["keys"]) {
      out[url] = LinkData(archived: true, secret: false);
    }

    // Read secret links.
    for (String url in inner["secret_links"]["keys"]) {
      out[myDecryptWithSecretBox(secretBox, url)] =
          LinkData(archived: false, secret: true);
    }

    // Read archived secret links.
    for (String url in inner["archived_secret_links"]["keys"]) {
      out[myDecryptWithSecretBox(secretBox, url)] =
          LinkData(archived: true, secret: true);
    }

    return out;
  }

  Future<void> triggerPull() async {
    fetchDataFuture = pull();
    return fetchDataFuture;
  }

  Future<TransactionResult> addItem(
      String url, bool secret, List<String> tags) async {
    url = url.trim().replaceAll("\n", "");

    List<JsonObject> arguments;
    String function_ = "${moduleAddress.withPrefix()}::$moduleName::";
    if (secret) {
      var linkData = LinkData(archived: false, secret: secret);
      arguments = [
        StringJsonObject(myEncryptWithSecretBox(secretBox, url)),
        StringJsonObject(linkData.encrypt(secretBox)),
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

    ScriptFunctionPayloadBuilder scriptFunctionPayloadBuilder =
        ScriptFunctionPayloadBuilder()
          ..type = "script_function_payload"
          ..function_ = function_
          ..typeArguments = ListBuilder([])
          ..arguments = ListBuilder(arguments);

    var result = await signBuildWait(scriptFunctionPayloadBuilder);

    if (result.success) {
      links![url] = LinkData(archived: false, secret: secret);
    }

    return result;
  }

  Future<TransactionResult> removeItem(
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
      urlEncoded = myEncryptWithSecretBox(secretBox, url);
    } else {
      urlEncoded = HexString.fromRegularString(url).noPrefix();
    }

    List<JsonObject> arguments = [
      StringJsonObject(urlEncoded),
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
          links![url]!.archived = true;
          break;
        case RemoveItemAction.unarchive:
          links![url]!.archived = false;
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

    // This is a temporary thing to handle the case where the client says the
    // call failed, but really it succeeded, and it's just that the API returns
    // a struct with an illegally empty field according to the OpenAPI spec.
    if (errorString != null &&
        errorString.contains("mark \"handle\" with @nullable")) {
      print("Skipping special OpenAPI thingo error: $errorString");
      return TransactionResult(true, userTransactionBuilder.build(), null);
    }

    return TransactionResult(
        committed, userTransactionBuilder.build(), errorString);
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
