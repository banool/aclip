// AUTO GENERATED FILE, DO NOT EDIT.
// Generated by `flutter_rust_bridge`@ 1.49.2.
// ignore_for_file: non_constant_identifier_names, unused_element, duplicate_ignore, directives_ordering, curly_braces_in_flow_control_structures, unnecessary_lambdas, slash_for_doc_comments, prefer_const_literals_to_create_immutables, implicit_dynamic_list_literal, duplicate_import, unused_import, prefer_single_quotes, prefer_const_constructors, use_super_parameters, always_use_package_imports, annotate_overrides, invalid_use_of_protected_member, constant_identifier_names

import 'dart:convert';
import 'dart:async';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

abstract class Native {
  /// This is just the main function yanked from:
  /// https://github.com/Y2Z/monolith/blob/master/src/main.rs
  ///
  /// I had to do this due to https://github.com/Y2Z/monolith/issues/72.
  /// I've removed some of the functionality I don't need and of course added
  /// arguments and cleared out the argparsing stuff.
  ///
  /// You can't return the unit type, hence the bool here.
  /// https://github.com/fzyzcjy/flutter_rust_bridge/issues/197
  Future<bool> downloadPage({required Options options, dynamic hint});

  FlutterRustBridgeTaskConstMeta get kDownloadPageConstMeta;

  Future<Platform> platform({dynamic hint});

  FlutterRustBridgeTaskConstMeta get kPlatformConstMeta;

  Future<bool> rustReleaseMode({dynamic hint});

  FlutterRustBridgeTaskConstMeta get kRustReleaseModeConstMeta;
}

class Options {
  final bool noAudio;
  final String? baseUrl;
  final bool noCss;
  final String? charset;
  final bool ignoreErrors;
  final bool noFrames;
  final bool noFonts;
  final bool noImages;
  final bool isolate;
  final bool noJs;
  final bool insecure;
  final bool noMetadata;
  final String output;
  final bool silent;
  final int timeout;
  final String? userAgent;
  final bool noVideo;
  final String target;
  final bool noColor;
  final bool unwrapNoscript;

  Options({
    required this.noAudio,
    this.baseUrl,
    required this.noCss,
    this.charset,
    required this.ignoreErrors,
    required this.noFrames,
    required this.noFonts,
    required this.noImages,
    required this.isolate,
    required this.noJs,
    required this.insecure,
    required this.noMetadata,
    required this.output,
    required this.silent,
    required this.timeout,
    this.userAgent,
    required this.noVideo,
    required this.target,
    required this.noColor,
    required this.unwrapNoscript,
  });
}

enum Platform {
  Unknown,
  Android,
  Ios,
  Windows,
  Unix,
  MacIntel,
  MacApple,
  Wasm,
}