import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  http.Client? _client;

  Stream<double> download(String url, String fileName) async* {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');

    _client = http.Client();
    final request = http.Request('GET', Uri.parse(url));
    final response = await _client!.send(request);

    if (response.statusCode != 200) {
      _client?.close();
      throw Exception('Download failed: ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    int received = 0;
    final sink = file.openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) yield received / total;
    }

    await sink.close();
    _client?.close();
    _client = null;

    yield 1.0;
  }

  Future<void> install(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File not found: $filePath');

    if (Platform.isAndroid) {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Could not open installer: ${result.message}');
      }
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', filePath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [filePath]);
    }
  }

  void cancel() {
    _client?.close();
    _client = null;
  }

  Future<String> getTempDir() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  String getFileName(String url) {
    final uri = Uri.parse(url);
    final path = uri.pathSegments;
    return path.isNotEmpty ? Uri.decodeFull(path.last) : 'update_download';
  }
}
