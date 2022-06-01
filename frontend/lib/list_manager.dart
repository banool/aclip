import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aclip/common.dart';
import 'package:aclip/constants.dart';
import 'package:aclip/globals.dart';
import 'package:aptos_sdk_dart/aptos_client_helper.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:built_collection/built_collection.dart';
import 'package:dio/dio.dart';
import 'package:one_of/one_of.dart';
import 'package:pinenacl/ed25519.dart';
import 'package:pinenacl/x25519.dart';

class LinkData {
  // You'll see that tags is optional. We only fetch the tags when we have to,
  // since it requires a read per link.
  List<String>? tags;

  // Whether the link came from an archived_ list.
  bool archived;

  // Whether the link came from a secret_ list.
  bool secret;

  // This is only set if the link was secret (secret is true). This is the
  // encrypted version of the key.
  String? encryptedKey;

  LinkData(this.archived, this.secret, {this.tags, this.encryptedKey});

  @override
  String toString() {
    return "LinkData(archived: $archived, secret: $secret, tags: $tags, encryptedKey: $encryptedKey)";
  }

  // Convert struct to json, then to hex, then encrypt it. We sign the message
  // using the public key, so only we can decrypt it with our private key.
  Uint8List encrypt(SealedBox sealedBox) {
    return sealedBox
        .encrypt(HexString.fromRegularString(json.encode(this)).toBytes());
  }

  static LinkData decrypt(SealedBox sealedBox, Uint8List encrypted) {
    return json.decode(
        HexString.fromBytes(sealedBox.decrypt(encrypted)).toRegularString());
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
    String aptosNodeUrl =
        sharedPreferences.getString(keyAptosNodeUrl) ?? defaultAptosNodeUrl;
    HexString privateKey =
        HexString.fromString(sharedPreferences.getString(keyPrivateKey)!);

    AptosClientHelper aptosClientHelper =
        AptosClientHelper.fromBaseUrl(aptosNodeUrl);

    AptosAccount account = AptosAccount.fromPrivateKeyHexString(privateKey);

    String func = "${moduleAddress.withPrefix()}::$moduleName::initialize_list";

    // Build a script function payload that transfers coin.
    ScriptFunctionPayloadBuilder scriptFunctionPayloadBuilder =
        ScriptFunctionPayloadBuilder()
          ..type = "script_function_payload"
          ..function_ = func
          // This is the type for an ascii string under the hood.
          ..typeArguments = ListBuilder([])
          // ..typeArguments = ListBuilder(["address", "vector<u8>"])
          ..arguments = ListBuilder([]);

    // Build that into a transaction payload.
    TransactionPayloadBuilder transactionPayloadBuilder =
        TransactionPayloadBuilder()
          ..oneOf = OneOf1(value: scriptFunctionPayloadBuilder.build());

    // Build a transasction request. This includes a call to determine the
    // current sequence number so we can build that transasction.
    $UserTransactionRequestBuilder userTransactionBuilder =
        await aptosClientHelper.generateTransaction(
            account.address, transactionPayloadBuilder);

    // Convert the transaction into the appropriate format and then sign it.
    SubmitTransactionRequestBuilder submitTransactionRequestBuilder =
        await aptosClientHelper.signTransaction(
            account, userTransactionBuilder);

    bool committed = false;
    String? errorString;

    // Finally submit the transaction.
    try {
      PendingTransaction pendingTransaction = await unwrapClientCall(
          aptosClientHelper.client.getTransactionsApi().submitTransaction(
              submitTransactionRequest:
                  submitTransactionRequestBuilder.build()));

      // Wait for the transaction to be committed.
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
