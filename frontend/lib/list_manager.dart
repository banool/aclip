import 'package:aclip/common.dart';
import 'package:aclip/constants.dart';
import 'package:aclip/globals.dart';
import 'package:aptos_sdk_dart/aptos_client_helper.dart';
import 'package:aptos_sdk_dart/aptos_sdk_dart.dart';
import 'package:built_collection/built_collection.dart';
import 'package:dio/dio.dart';
import 'package:one_of/one_of.dart';

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
    } on DioError catch (e) {
      errorString =
          "Type: ${e.type}\nMessage: ${e.message}\nResponse: ${e.response}\nError: ${e.error}";
    } catch (e) {
      errorString = "$e";
    }

    return TransactionResult(
        committed, userTransactionBuilder.build(), errorString);
  }

  List<Link>? getActiveLinks() {
    if (links == null) return null;
    return links!.where((e) => !e.archived).toList();
  }

  List<Link>? getArchivedLinks() {
    if (links == null) return null;
    return links!.where((e) => e.archived).toList();
  }

  String buildResourceType({String? structName}) {
    return "0x${moduleAddress.noPrefix()}::$moduleName::${structName ?? moduleName}";
  }

  Future<void> pull() async {
    try {
      links = await fetchData();
      print("New links: $links");
    } on DioError catch (e) {
      print(
          "Type: ${e.type}\nMessage: ${e.message}\nResponse: ${e.response}\nError: ${e.error}");
    } catch (e) {
      print(e);
    }
  }

  Future<List<Link>> fetchData() async {
    print("Getting list from the blockchain");

    var resourceType = buildResourceType();

    AccountResource resource;
    resource = await unwrapClientCall(aptosClientHelper.client
        .getAccountsApi()
        .getAccountResource(
            address: moduleAddress.noPrefix(), resourceType: resourceType));

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
