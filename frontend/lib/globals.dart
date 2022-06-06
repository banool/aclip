import 'package:aclip/list_manager.dart';
import 'package:aclip/page_downloader.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences sharedPreferences;
late PackageInfo packageInfo;
late ListManager listManager;
late String downloadsDirectory;
late DownloadManager downloadManager;

bool listManagerSet = false;
