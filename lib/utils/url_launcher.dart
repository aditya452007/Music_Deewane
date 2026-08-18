import 'dart:developer';

import 'package:url_launcher/url_launcher.dart';

Future<void> launchUrl2(Uri url) async {
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    log('Could not launch $url', name: "launchUrl2");
  }
}
