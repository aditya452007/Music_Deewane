import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

bool isUpdateAvailable(
    String currentVer, String currentBuild, String newVer, String newBuild,
    {bool checkBuild = true}) {
  // Normalize versions and builds and compare component-wise.
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

  log('isUpdateAvailable: currentVer="$currentVer" currentBuild="$currentBuild" newVer="$newVer" newBuild="$newBuild" checkBuild=$checkBuild',
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
      log('isUpdateAvailable: version[${neu > cur}] $neu > $cur → true',
          name: 'UpdaterTools');
      return true;
    }
    if (neu < cur) {
      log('isUpdateAvailable: version[${neu < cur}] $neu < $cur → false',
          name: 'UpdaterTools');
      return false;
    }
  }

  if (checkBuild && !Platform.isLinux) {
    int parseBuild(String b) {
      try {
        return int.parse(b);
      } catch (_) {
        final m = RegExp(r'(\d+)').firstMatch(b);
        return m != null ? int.parse(m.group(1)!) : 0;
      }
    }

    final curBuild = parseBuild(currentBuild);
    final newBuildNum = parseBuild(newBuild);
    log('isUpdateAvailable: curBuild=$curBuild newBuildNum=$newBuildNum',
        name: 'UpdaterTools');
    if (newBuildNum > curBuild) {
      log('isUpdateAvailable: build $newBuildNum > $curBuild → true',
          name: 'UpdaterTools');
      return true;
    }
    if (newBuildNum < curBuild) {
      log('isUpdateAvailable: build $newBuildNum < $curBuild → false',
          name: 'UpdaterTools');
      return false;
    }
  }

  log('isUpdateAvailable: no update found → false', name: 'UpdaterTools');
  return false;
}

Future<Map<String, dynamic>> sourceforgeUpdate(
    {Duration timeout = const Duration(seconds: 6)}) async {
  String platform = Platform.operatingSystem;
  if (platform != 'linux' && platform != 'android' && platform != 'win') {
    // normalize unknowns to win for SourceForge naming
    platform = 'win';
  }
  const url =
      'https://sourceforge.net/projects/music-deewane/best_release.json';
  final userAgent = {
    'win':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
    'linux':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3868.146 Safari/537.36 OPR/54.0.4087.46',
    'android':
        'Mozilla/5.0 (Linux; Android 13;) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
  };

  // Use a single known-working header set (desktop UA + accept + referer).
  final headers = {
    'user-agent': userAgent['win']!,
    'accept': 'application/json, text/javascript, */*; q=0.01',
    'referer': 'https://sourceforge.net',
  };
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  try {
    final response =
        await http.get(Uri.parse(url), headers: headers).timeout(timeout);
    log("SourceForge response status code: ${response.statusCode}",
        name: 'UpdaterTools');
    if (response.statusCode == 403) {
      try {
        final snippet = response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body;
        log('SourceForge 403 response snippet: $snippet', name: 'UpdaterTools');
      } catch (_) {}
      throw Exception('SourceForge returned 403');
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Prefer platform-specific release entry when available
      String platformKey = 'windows';
      if (Platform.isLinux) {
        platformKey = 'linux';
      } else if (Platform.isMacOS) {
        platformKey = 'mac';
      } else if (Platform.isAndroid) {
        platformKey = 'android';
      }

      Map? entry = (data['platform_releases'] is Map)
          ? (data['platform_releases'] as Map)[platformKey]
          : null;
      entry ??= data['release'];

      // extract url/filename from the chosen entry first, fall back to release
      final releaseUrl = (entry != null && entry['url'] != null)
          ? entry['url'] as String
          : (data['release']?['url'] ?? '');
      String filename = (entry != null && entry['filename'] != null)
          ? entry['filename'] as String
          : (data['release']?['filename'] ?? '');

      // decode percent-encoding and normalize
      try {
        filename = Uri.decodeFull(filename);
      } catch (_) {}
      String decodedUrl = releaseUrl;
      try {
        decodedUrl = Uri.decodeFull(releaseUrl);
      } catch (_) {}

      // try to find version/build in filename, then url
      final versionRegex = RegExp(r'v(\d+(?:\.\d+)*)');
      final buildRegex = RegExp(r'\+(\d+)');

      Match? versionMatch = versionRegex.firstMatch(filename);
      versionMatch ??= versionRegex.firstMatch(decodedUrl);
      Match? buildMatch = buildRegex.firstMatch(filename);
      buildMatch ??= buildRegex.firstMatch(decodedUrl);

      final version = versionMatch?.group(1) ?? '';
      final build = buildMatch?.group(1) ?? '';

      return {
        'source': 'sourceforge',
        'newVer': version,
        'newBuild': build,
        'download_url': releaseUrl,
        'currVer': packageInfo.version,
        'currBuild': packageInfo.buildNumber,
        'results': isUpdateAvailable(
          packageInfo.version,
          packageInfo.buildNumber,
          version.isNotEmpty ? version : '0.0.0',
          build.isNotEmpty ? build : '0',
          checkBuild: platform == 'linux' ? false : true,
        ),
      };
    } else {
      throw Exception('SourceForge returned ${response.statusCode}');
    }
  } catch (e, st) {
    log('SourceForge update check failed: $e\n$st', name: 'UpdaterTools');
    rethrow;
  }
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
          checkBuild: true,
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

/// New public API: try GitHub first, then SourceForge; return a consistent map.
Future<Map<String, dynamic>> getAppUpdates() async {
  // Try GitHub first, then SourceForge, produce an `updates` map and attach changelogs.
  Map<String, dynamic> updates;
  try {
    updates = await githubUpdate();
  } catch (e) {
    log('GitHub check failed, trying SourceForge: $e', name: 'UpdaterTools');
    try {
      updates = await sourceforgeUpdate();
    } catch (e2) {
      log('SourceForge check failed: $e2', name: 'UpdaterTools');
      // Final fallback: return structured failure map with current info
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        updates = {
          'results': false,
          'error': 'Failed to check remote releases',
          'currVer': packageInfo.version,
          'currBuild': packageInfo.buildNumber,
          'source': 'none',
        };
      } catch (e3) {
        updates = {
          'results': false,
          'error':
              'Failed to check remote releases and failed to read local package info',
          'source': 'none',
        };
      }
    }
  }

  return updates;
}

/// Backwards-compatible wrapper for existing callers
Future<Map<String, dynamic>> getLatestVersion() async => await getAppUpdates();

String? extractUpUrl(Map<String, dynamic> data) {
  for (var element in (data["assets"] as List)) {
    final url = element["browser_download_url"].toString();
    if (url.contains("windows") && Platform.isWindows) {
      return url;
    } else if (url.contains("android") && Platform.isAndroid) {
      return url;
    } else if (url.contains("linux") && Platform.isLinux) {
      return url;
    }
  }
  return null;
}
