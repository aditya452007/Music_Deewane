import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

bool isUpdateAvailable(
    String currentVer, String currentBuild, String newVer, String newBuild) {
  // Compare semantic versions only. Build numbers are NOT compared because:
  // - The binary's build number comes from pubspec.yaml (always 1 unless bumped)
  // - CI release tags use github.run_number (59+), which can never match pubspec
  // - Comparing them causes false "update available" on the latest release
  List<int> parseVersion(String v) {
    v = v.replaceFirst(RegExp(r'^v'), '');
    final parts = v.split('.');
    return parts.map((p) {
      final m = RegExp(r'^(\d+)').firstMatch(p);
      return m != null ? int.parse(m.group(1)!) : 0;
    }).toList();
  }

  List<int> currentParts = parseVersion(currentVer);
  List<int> newParts = parseVersion(newVer);

  log('isUpdateAvailable: currentVer="$currentVer" newVer="$newVer"',
      name: 'UpdaterTools');
  log('isUpdateAvailable: currentParts=$currentParts newParts=$newParts',
      name: 'UpdaterTools');

  final maxLen = currentParts.length > newParts.length
      ? currentParts.length
      : newParts.length;
  for (int i = 0; i < maxLen; i++) {
    final cur = i < currentParts.length ? currentParts[i] : 0;
    final neu = i < newParts.length ? newParts[i] : 0;
    if (neu > cur) {
      log('isUpdateAvailable: version $neu > $cur → true',
          name: 'UpdaterTools');
      return true;
    }
    if (neu < cur) {
      log('isUpdateAvailable: version $neu < $cur → false',
          name: 'UpdaterTools');
      return false;
    }
  }

  log('isUpdateAvailable: same version → false', name: 'UpdaterTools');
  return false;
}

Future<Map<String, dynamic>> githubUpdate(
    {Duration timeout = const Duration(seconds: 6)}) async {
  const url =
      'https://api.github.com/repos/aditya452007/Music_Deewane/releases/latest';
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  try {
    final response = await http.get(Uri.parse(url)).timeout(timeout);
    log("GitHub response status code: ${response.statusCode}",
        name: 'UpdaterTools');
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final tag = (data['tag_name'] as String?) ?? '';
      // tag might be like v2.7.11+12 or v2.7.11
      final tagParts = tag.split('+');
      final versionPart =
          tagParts.isNotEmpty ? tagParts[0].replaceFirst('v', '') : '';
      final buildPart = tagParts.length > 1 ? tagParts[1] : '';

      log('GitHub raw tag="$tag" versionPart="$versionPart" buildPart="$buildPart"',
          name: 'UpdaterTools');
      log('GitHub local: version="${packageInfo.version}" build="${packageInfo.buildNumber}"',
          name: 'UpdaterTools');

      // Attempt to extract download url from assets if possible
      String? download = extractUpUrl(data);
      download ??= data['html_url'] ?? '';

      return {
        'source': 'github',
        'newVer': versionPart,
        'newBuild': buildPart,
        'download_url': download,
        'currVer': packageInfo.version,
        'currBuild': packageInfo.buildNumber,
        'results': isUpdateAvailable(
          packageInfo.version,
          packageInfo.buildNumber,
          versionPart.isNotEmpty ? versionPart : '0.0.0',
          buildPart.isNotEmpty ? buildPart : '0',
        ),
      };
    } else {
      throw Exception('GitHub returned ${response.statusCode}');
    }
  } catch (e, st) {
    log('GitHub update check failed: $e\n$st', name: 'UpdaterTools');
    rethrow;
  }
}

/// New public API: check the latest GitHub release; return a consistent map.
Future<Map<String, dynamic>> getAppUpdates() async {
  try {
    return await githubUpdate();
  } catch (e) {
    log('GitHub update check failed: $e', name: 'UpdaterTools');
    // Final fallback: return structured failure map with current info
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'results': false,
        'error': 'Failed to check remote releases',
        'currVer': packageInfo.version,
        'currBuild': packageInfo.buildNumber,
        'source': 'none',
      };
    } catch (e2) {
      return {
        'results': false,
        'error':
            'Failed to check remote releases and failed to read local package info',
        'source': 'none',
      };
    }
  }
}

/// Backwards-compatible wrapper for existing callers
Future<Map<String, dynamic>> getLatestVersion() async => await getAppUpdates();

String? extractUpUrl(Map<String, dynamic> data) {
  final assets = data["assets"] as List;
  // Prefer .zip for Windows (user choice) — first pass looks for windows + .zip
  if (Platform.isWindows) {
    for (var element in assets) {
      final raw = element["browser_download_url"].toString();
      final url = raw.toLowerCase();
      if (url.contains("windows") && url.contains(".zip")) return raw;
    }
  }
  for (var element in assets) {
    final raw = element["browser_download_url"].toString();
    final url = raw.toLowerCase();
    if (url.contains("windows") && Platform.isWindows) return raw;
    if (url.contains("android") && Platform.isAndroid) return raw;
    if (url.contains("linux") && Platform.isLinux) return raw;
  }
  return null;
}
