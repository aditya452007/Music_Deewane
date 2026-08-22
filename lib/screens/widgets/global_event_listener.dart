import 'dart:async';
import 'dart:developer';
import 'package:music_deewane/blocs/global_events/global_events_cubit.dart';
import 'package:music_deewane/core/events/global_event_bus.dart';
import 'package:music_deewane/l10n/app_localizations.dart';
import 'package:music_deewane/screens/widgets/music_deewane_ui_kit/music_deewane_dialog.dart';
import 'package:music_deewane/screens/widgets/snackbar.dart';
import 'package:music_deewane/services/plugin/plugin_event_bus.dart';
import 'package:music_deewane/src/rust/api/plugin/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openURL(String url) async {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

class GlobalEventListener extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  const GlobalEventListener(
      {super.key, required this.child, required this.navigatorKey});

  @override
  State<GlobalEventListener> createState() => _GlobalEventListenerState();
}

class _GlobalEventListenerState extends State<GlobalEventListener> {
  StreamSubscription<PluginManagerEvent>? _pluginSub;
  StreamSubscription<AppError>? _appErrorSub;

  /// Rate-limit snackbars: track last message + timestamp to avoid flooding.
  String? _lastSnackbarMessage;
  DateTime _lastSnackbarTime = DateTime(2000);
  static const _snackbarCooldown = Duration(seconds: 2);

  /// Show a snackbar only if it's not a duplicate within the cooldown window.
  void _throttledSnackbar(String message) {
    final now = DateTime.now();
    if (message == _lastSnackbarMessage &&
        now.difference(_lastSnackbarTime) < _snackbarCooldown) {
      return; // suppress duplicate within cooldown
    }
    _lastSnackbarMessage = message;
    _lastSnackbarTime = now;
    SnackbarService.showMessage(message);
  }

  @override
  void initState() {
    super.initState();
    _pluginSub = PluginEventBus.instance.events.listen(_onPluginEvent);
    _appErrorSub = GlobalEventBus.instance.errors.listen(_onAppError);
  }

  @override
  void dispose() {
    _pluginSub?.cancel();
    _appErrorSub?.cancel();
    super.dispose();
  }

  void _onAppError(AppError error) {
    log('App error: $error', name: 'GlobalEventListener');
    switch (error) {
      case PluginNotLoadedError(:final pluginId):
        _throttledSnackbar('Plugin "$pluginId" is not loaded.');
      case MalformedMediaIdError(:final rawId):
        _throttledSnackbar('Malformed media ID: $rawId');
      case PluginErrorEvent(:final message):
        _throttledSnackbar(message);
      case NetworkFailureError(:final message):
        _throttledSnackbar(message);
    }
  }

  void _onPluginEvent(PluginManagerEvent event) {
    switch (event) {
      case PluginManagerEvent_PluginLoadFailed(:final id, :final error):
        log('Plugin load failed: $id — $error', name: 'GlobalEventListener');
        _throttledSnackbar('Plugin "$id" failed to load: $error');
      case PluginManagerEvent_PluginUnloadFailed(:final id, :final error):
        log('Plugin unload failed: $id — $error', name: 'GlobalEventListener');
        _throttledSnackbar('Plugin "$id" failed to unload: $error');
      case PluginManagerEvent_PluginInstallFailed(:final id, :final error):
        log('Plugin install failed: $id — $error', name: 'GlobalEventListener');
        _throttledSnackbar('Plugin "$id" install failed: $error');
      case PluginManagerEvent_PluginDeleteFailed(:final id, :final error):
        log('Plugin delete failed: $id — $error', name: 'GlobalEventListener');
        _throttledSnackbar('Plugin "$id" delete failed: $error');
      case PluginManagerEvent_Error(:final message):
        log('Plugin system error: $message', name: 'GlobalEventListener');
        _throttledSnackbar('Plugin error: $message');
      case PluginManagerEvent_PluginInstalled(:final id):
        if (mounted) {
          _throttledSnackbar(
              AppLocalizations.of(context)!.pluginSnackbarInstalled(id));
        }
      case PluginManagerEvent_PluginLoaded(:final id):
        log('Plugin loaded: $id', name: 'GlobalEventListener');
      case PluginManagerEvent_PluginDeleted(:final id):
        if (mounted) {
          _throttledSnackbar(
              AppLocalizations.of(context)!.pluginSnackbarDeleted(id));
        }
      default:
        break;
    }
  }

  void _showUpdateDialog(
      BuildContext context, UpdateAvailable state, AppLocalizations l10n) {
    showMusicDeewaneDialog(
      context: context,
      title: l10n.dialogUpdateAvailable,
      subtitle: l10n.updateAvailableBody(state.newVersion, state.newBuild),
      icon: Icons.system_update_rounded,
      actions: [
        MusicDeewaneDialogAction.text(l10n.buttonLater),
        MusicDeewaneDialogAction.filled(l10n.dialogUpdateNow, onPressed: () {
          Navigator.of(context).pop();
          openURL(state.downloadUrl);
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GlobalEventsCubit, GlobalEventsState>(
      listener: (context, state) {
        final dialogContext = widget.navigatorKey.currentContext ?? context;
        if (state is UpdateAvailable) {
          final l10n = AppLocalizations.of(dialogContext)!;
          log("Update Available: ${state.newVersion}+${state.newBuild}");
          _showUpdateDialog(dialogContext, state, l10n);
        } else if (state is AlertDialogState) {
          final l10n = AppLocalizations.of(dialogContext)!;
          showMusicDeewaneDialog(
            context: dialogContext,
            title: state.title,
            subtitle: state.content,
            actions: [
              MusicDeewaneDialogAction.filled(l10n.buttonOk),
            ],
          );
        }
      },
      child: widget.child,
    );
  }
}
