import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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

  String getFileName(String url) {
    final uri = Uri.parse(url);
    final path = uri.pathSegments;
    return path.isNotEmpty ? Uri.decodeFull(path.last) : 'update_download';
  }

  /// Shows a premium download progress dialog and handles the full
  /// download → install flow. The download runs while the dialog is open.
  /// Closing the dialog cancels the download.
  Future<void> showDownloadDialog(
    BuildContext context, {
    required String url,
    required String version,
  }) async {
    final fileName = getFileName(url);
    double progress = 0;
    String status = 'Preparing download...';
    bool completed = false;

    final sub = download(url, fileName).listen(
      (p) {
        progress = p;
        status = p >= 1.0 ? 'Installing...' : 'Downloading update...';
      },
      onDone: () async {
        completed = true;
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        try {
          final dir = await getTemporaryDirectory();
          await install('${dir.path}/$fileName');
        } catch (_) {}
      },
      onError: (_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Periodic rebuild to update progress UI
          Timer.periodic(const Duration(milliseconds: 100), (timer) {
            if (!ctx.mounted || completed) {
              timer.cancel();
              return;
            }
            setDialogState(() {});
          });

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                cancel();
                Navigator.of(ctx).pop();
              }
            },
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  color: const Color(0xFF12101A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 28),
                    // Logo
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icons/logo.jpeg',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.system_update_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    Text(
                      'Updating to v$version',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Status text
                    Text(
                      status,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Progress bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress > 0 ? progress : null,
                              minHeight: 6,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.06),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progress > 0
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                progress > 0
                                    ? '${(progress * 100).toStringAsFixed(0)}%'
                                    : '0%',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 12,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                              if (progress >= 1.0)
                                Text(
                                  'Installing...',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Cancel button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: TextButton(
                          onPressed: () {
                            cancel();
                            Navigator.of(ctx).pop();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Colors.white.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    // If dialog was closed by completion, don't cancel the stream
    if (!completed) {
      sub.cancel();
    }
  }
}
