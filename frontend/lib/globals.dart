import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'download_manager.dart';
import 'list_manager.dart';

late SharedPreferences sharedPreferences;
late ListManager listManager;
late String downloadsDirectory;
late DownloadManager downloadManager;

bool listManagerSet = false;

PackageInfo? packageInfo;
Object? packageInfoRetrieveError;

// This will be true if we've detected that the app is running as a browser extension.
bool runningAsBrowserExtension = false;

// We initialize these here once globally so there is only a single cookie jar
// for the life of the app process.
final cookieJar = CookieJar();
final cookieManager = CookieManager(cookieJar);
