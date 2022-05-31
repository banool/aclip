import 'package:flutter/material.dart';

class Link {
  Uri url;
  List<String> tags;

  Link(this.url, this.tags);
}

class ListManager extends ChangeNotifier {
  List<Link> links;

  ListManager(this.links);
}
