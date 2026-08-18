import 'package:music_deewane/services/music_deewane_updater_tools.dart';
import 'package:music_deewane/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:music_deewane/core/theme/app_theme.dart';
import 'package:music_deewane/utils/url_launcher.dart';
import 'package:music_deewane/l10n/app_localizations.dart';
import 'package:iconsx_plus/iconsx_plus.dart';

class CheckUpdateView extends StatelessWidget {
  const CheckUpdateView({super.key});

  void _downloadUpdate(BuildContext context, String url) {
    final service = UpdateService();
    final fileName = service.getFileName(url);
    double progress = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF12101A),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 40,
                  width: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 20),
                Text(
                  'Downloading update...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                ),
                if (progress > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    service.download(url, fileName).listen(
      (p) {
        progress = p;
      },
      onDone: () async {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        try {
          final tempDir = await service.getTempDir();
          await service.install('$tempDir/$fileName');
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Install failed: $e')),
            );
          }
        }
      },
      onError: (e) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download failed. Try again.')),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          l10n.updateCheckTitle,
          style: const TextStyle(
                  color: Default_Theme.primaryColor1,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)
              .merge(Default_Theme.secondoryTextStyle),
        ),
      ),
      body: Center(
        child: FutureBuilder(
          future: getLatestVersion(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              if (!snapshot.data?["results"]) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Text(
                      l10n.updateUpToDate,
                      style: const TextStyle(
                              color: Default_Theme.accentColor2, fontSize: 20)
                          .merge(Default_Theme.secondoryTextStyleMedium),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: FilledButton(
                        onPressed: () {
                          launchUrl2(Uri.parse(
                              "https://github.com/aditya452007/Music_Deewane/releases"));
                        },
                        child: SizedBox(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                FontAwesome.github_alt_brand,
                                size: 25,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: Text(
                                  l10n.updateViewPreRelease,
                                  style: const TextStyle(fontSize: 17).merge(
                                      Default_Theme.secondoryTextStyleMedium),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        l10n.updateCurrentVersion(
                            snapshot.data?["currVer"] ?? '',
                            snapshot.data?["currBuild"] ?? ''),
                        style: TextStyle(
                                color: Default_Theme.primaryColor2
                                    .withValues(alpha: 0.5),
                                fontSize: 12)
                            .merge(Default_Theme.tertiaryTextStyle),
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    Text(
                      l10n.updateNewVersionAvailable,
                      style: const TextStyle(
                              color: Default_Theme.accentColor2, fontSize: 20)
                          .merge(Default_Theme.tertiaryTextStyle),
                      textAlign: TextAlign.center,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        l10n.updateVersion(snapshot.data?["newVer"] ?? '',
                            snapshot.data?["newBuild"] ?? ''),
                        style: TextStyle(
                                color: Default_Theme.primaryColor1
                                    .withValues(alpha: 0.8),
                                fontSize: 16)
                            .merge(Default_Theme.tertiaryTextStyle),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FilledButton(
                        onPressed: () {
                          _downloadUpdate(
                              context, snapshot.data?["download_url"] ?? '');
                        },
                        child: SizedBox(
                          width: 150,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.open_in_browser_rounded,
                                  size: 25),
                              Text(
                                l10n.updateDownloadNow,
                                style: const TextStyle(fontSize: 17).merge(
                                    Default_Theme.secondoryTextStyleMedium),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        l10n.updateCurrentVersion(
                            snapshot.data?["currVer"] ?? '',
                            snapshot.data?["currBuild"] ?? ''),
                        style: TextStyle(
                                color: Default_Theme.primaryColor2
                                    .withValues(alpha: 0.5),
                                fontSize: 12)
                            .merge(Default_Theme.tertiaryTextStyle),
                      ),
                    ),
                  ],
                );
              }
            } else {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(15.0),
                    child: SizedBox(
                        height: 50,
                        width: 50,
                        child: CircularProgressIndicator(
                          color: Default_Theme.accentColor2,
                        )),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        width: constraints.maxWidth * 0.6,
                        child: Text(l10n.updateChecking,
                            style: const TextStyle(
                                    color: Default_Theme.accentColor2,
                                    fontSize: 20)
                                .merge(Default_Theme.tertiaryTextStyle),
                            textAlign: TextAlign.center),
                      );
                    },
                  )
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
