// AUTO GENERATED FILE, DO NOT EDIT.
// Generated by `flutter_rust_bridge`.

// ignore_for_file: non_constant_identifier_names, unused_element, duplicate_ignore, directives_ordering, curly_braces_in_flow_control_structures, unnecessary_lambdas, slash_for_doc_comments, prefer_const_literals_to_create_immutables, implicit_dynamic_list_literal, duplicate_import, unused_import, prefer_single_quotes, prefer_const_constructors

import 'dart:convert';
import 'dart:typed_data';

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'dart:ffi' as ffi;

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

  Future<Platform> platform({dynamic hint});

  Future<bool> rustReleaseMode({dynamic hint});
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

class NativeImpl extends FlutterRustBridgeBase<NativeWire> implements Native {
  factory NativeImpl(ffi.DynamicLibrary dylib) =>
      NativeImpl.raw(NativeWire(dylib));

  NativeImpl.raw(NativeWire inner) : super(inner);

  Future<bool> downloadPage({required Options options, dynamic hint}) =>
      executeNormal(FlutterRustBridgeTask(
        callFfi: (port_) => inner.wire_download_page(
            port_, _api2wire_box_autoadd_options(options)),
        parseSuccessData: _wire2api_bool,
        constMeta: const FlutterRustBridgeTaskConstMeta(
          debugName: "download_page",
          argNames: ["options"],
        ),
        argValues: [options],
        hint: hint,
      ));

  Future<Platform> platform({dynamic hint}) =>
      executeNormal(FlutterRustBridgeTask(
        callFfi: (port_) => inner.wire_platform(port_),
        parseSuccessData: _wire2api_platform,
        constMeta: const FlutterRustBridgeTaskConstMeta(
          debugName: "platform",
          argNames: [],
        ),
        argValues: [],
        hint: hint,
      ));

  Future<bool> rustReleaseMode({dynamic hint}) =>
      executeNormal(FlutterRustBridgeTask(
        callFfi: (port_) => inner.wire_rust_release_mode(port_),
        parseSuccessData: _wire2api_bool,
        constMeta: const FlutterRustBridgeTaskConstMeta(
          debugName: "rust_release_mode",
          argNames: [],
        ),
        argValues: [],
        hint: hint,
      ));

  // Section: api2wire
  ffi.Pointer<wire_uint_8_list> _api2wire_String(String raw) {
    return _api2wire_uint_8_list(utf8.encoder.convert(raw));
  }

  int _api2wire_bool(bool raw) {
    return raw ? 1 : 0;
  }

  ffi.Pointer<wire_Options> _api2wire_box_autoadd_options(Options raw) {
    final ptr = inner.new_box_autoadd_options();
    _api_fill_to_wire_options(raw, ptr.ref);
    return ptr;
  }

  ffi.Pointer<wire_uint_8_list> _api2wire_opt_String(String? raw) {
    return raw == null ? ffi.nullptr : _api2wire_String(raw);
  }

  int _api2wire_u64(int raw) {
    return raw;
  }

  int _api2wire_u8(int raw) {
    return raw;
  }

  ffi.Pointer<wire_uint_8_list> _api2wire_uint_8_list(Uint8List raw) {
    final ans = inner.new_uint_8_list(raw.length);
    ans.ref.ptr.asTypedList(raw.length).setAll(0, raw);
    return ans;
  }

  // Section: api_fill_to_wire

  void _api_fill_to_wire_box_autoadd_options(
      Options apiObj, ffi.Pointer<wire_Options> wireObj) {
    _api_fill_to_wire_options(apiObj, wireObj.ref);
  }

  void _api_fill_to_wire_options(Options apiObj, wire_Options wireObj) {
    wireObj.no_audio = _api2wire_bool(apiObj.noAudio);
    wireObj.base_url = _api2wire_opt_String(apiObj.baseUrl);
    wireObj.no_css = _api2wire_bool(apiObj.noCss);
    wireObj.charset = _api2wire_opt_String(apiObj.charset);
    wireObj.ignore_errors = _api2wire_bool(apiObj.ignoreErrors);
    wireObj.no_frames = _api2wire_bool(apiObj.noFrames);
    wireObj.no_fonts = _api2wire_bool(apiObj.noFonts);
    wireObj.no_images = _api2wire_bool(apiObj.noImages);
    wireObj.isolate = _api2wire_bool(apiObj.isolate);
    wireObj.no_js = _api2wire_bool(apiObj.noJs);
    wireObj.insecure = _api2wire_bool(apiObj.insecure);
    wireObj.no_metadata = _api2wire_bool(apiObj.noMetadata);
    wireObj.output = _api2wire_String(apiObj.output);
    wireObj.silent = _api2wire_bool(apiObj.silent);
    wireObj.timeout = _api2wire_u64(apiObj.timeout);
    wireObj.user_agent = _api2wire_opt_String(apiObj.userAgent);
    wireObj.no_video = _api2wire_bool(apiObj.noVideo);
    wireObj.target = _api2wire_String(apiObj.target);
    wireObj.no_color = _api2wire_bool(apiObj.noColor);
    wireObj.unwrap_noscript = _api2wire_bool(apiObj.unwrapNoscript);
  }
}

// Section: wire2api
bool _wire2api_bool(dynamic raw) {
  return raw as bool;
}

Platform _wire2api_platform(dynamic raw) {
  return Platform.values[raw];
}

// ignore_for_file: camel_case_types, non_constant_identifier_names, avoid_positional_boolean_parameters, annotate_overrides, constant_identifier_names

// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `package:ffigen`.

/// generated by flutter_rust_bridge
class NativeWire implements FlutterRustBridgeWireBase {
  /// Holds the symbol lookup function.
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  NativeWire(ffi.DynamicLibrary dynamicLibrary)
      : _lookup = dynamicLibrary.lookup;

  /// The symbols are looked up with [lookup].
  NativeWire.fromLookup(
      ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
          lookup)
      : _lookup = lookup;

  void wire_download_page(
    int port_,
    ffi.Pointer<wire_Options> options,
  ) {
    return _wire_download_page(
      port_,
      options,
    );
  }

  late final _wire_download_pagePtr = _lookup<
      ffi.NativeFunction<
          ffi.Void Function(
              ffi.Int64, ffi.Pointer<wire_Options>)>>('wire_download_page');
  late final _wire_download_page = _wire_download_pagePtr
      .asFunction<void Function(int, ffi.Pointer<wire_Options>)>();

  void wire_platform(
    int port_,
  ) {
    return _wire_platform(
      port_,
    );
  }

  late final _wire_platformPtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(ffi.Int64)>>(
          'wire_platform');
  late final _wire_platform =
      _wire_platformPtr.asFunction<void Function(int)>();

  void wire_rust_release_mode(
    int port_,
  ) {
    return _wire_rust_release_mode(
      port_,
    );
  }

  late final _wire_rust_release_modePtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(ffi.Int64)>>(
          'wire_rust_release_mode');
  late final _wire_rust_release_mode =
      _wire_rust_release_modePtr.asFunction<void Function(int)>();

  ffi.Pointer<wire_Options> new_box_autoadd_options() {
    return _new_box_autoadd_options();
  }

  late final _new_box_autoadd_optionsPtr =
      _lookup<ffi.NativeFunction<ffi.Pointer<wire_Options> Function()>>(
          'new_box_autoadd_options');
  late final _new_box_autoadd_options = _new_box_autoadd_optionsPtr
      .asFunction<ffi.Pointer<wire_Options> Function()>();

  ffi.Pointer<wire_uint_8_list> new_uint_8_list(
    int len,
  ) {
    return _new_uint_8_list(
      len,
    );
  }

  late final _new_uint_8_listPtr = _lookup<
      ffi.NativeFunction<
          ffi.Pointer<wire_uint_8_list> Function(
              ffi.Int32)>>('new_uint_8_list');
  late final _new_uint_8_list = _new_uint_8_listPtr
      .asFunction<ffi.Pointer<wire_uint_8_list> Function(int)>();

  void free_WireSyncReturnStruct(
    WireSyncReturnStruct val,
  ) {
    return _free_WireSyncReturnStruct(
      val,
    );
  }

  late final _free_WireSyncReturnStructPtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(WireSyncReturnStruct)>>(
          'free_WireSyncReturnStruct');
  late final _free_WireSyncReturnStruct = _free_WireSyncReturnStructPtr
      .asFunction<void Function(WireSyncReturnStruct)>();

  void store_dart_post_cobject(
    DartPostCObjectFnType ptr,
  ) {
    return _store_dart_post_cobject(
      ptr,
    );
  }

  late final _store_dart_post_cobjectPtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(DartPostCObjectFnType)>>(
          'store_dart_post_cobject');
  late final _store_dart_post_cobject = _store_dart_post_cobjectPtr
      .asFunction<void Function(DartPostCObjectFnType)>();
}

class wire_uint_8_list extends ffi.Struct {
  external ffi.Pointer<ffi.Uint8> ptr;

  @ffi.Int32()
  external int len;
}

class wire_Options extends ffi.Struct {
  @ffi.Uint8()
  external int no_audio;

  external ffi.Pointer<wire_uint_8_list> base_url;

  @ffi.Uint8()
  external int no_css;

  external ffi.Pointer<wire_uint_8_list> charset;

  @ffi.Uint8()
  external int ignore_errors;

  @ffi.Uint8()
  external int no_frames;

  @ffi.Uint8()
  external int no_fonts;

  @ffi.Uint8()
  external int no_images;

  @ffi.Uint8()
  external int isolate;

  @ffi.Uint8()
  external int no_js;

  @ffi.Uint8()
  external int insecure;

  @ffi.Uint8()
  external int no_metadata;

  external ffi.Pointer<wire_uint_8_list> output;

  @ffi.Uint8()
  external int silent;

  @ffi.Uint64()
  external int timeout;

  external ffi.Pointer<wire_uint_8_list> user_agent;

  @ffi.Uint8()
  external int no_video;

  external ffi.Pointer<wire_uint_8_list> target;

  @ffi.Uint8()
  external int no_color;

  @ffi.Uint8()
  external int unwrap_noscript;
}

typedef DartPostCObjectFnType = ffi.Pointer<
    ffi.NativeFunction<ffi.Uint8 Function(DartPort, ffi.Pointer<ffi.Void>)>>;
typedef DartPort = ffi.Int64;
