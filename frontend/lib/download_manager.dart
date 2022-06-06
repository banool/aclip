// I need this to avoid build errors on web.
// https://stackoverflow.com/questions/70565611/how-to-ignore-package-when-building-flutter-project-for-web

import 'dart:convert';

import 'package:crypto/crypto.dart';

export 'download_manager_mobile.dart'
    if (dart.library.html) 'download_manager_web.dart';

String getFileNameFromUrl(String url) {
  return md5.convert(utf8.encode(url)).toString();
}
