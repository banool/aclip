@JS()
library get_current_url.js;

import 'package:js/js.dart';
import 'package:universal_html/js_util.dart';

@JS()
external dynamic getCurrentUrlInner();

Future<String?> getCurrentUrl() async {
  var result = await promiseToFuture(getCurrentUrlInner());
  if (result == "") {
    return null;
  }
  return result;
}
