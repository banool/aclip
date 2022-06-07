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
