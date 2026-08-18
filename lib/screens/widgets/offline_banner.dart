import 'package:music_deewane/blocs/internet_connectivity/cubit/connectivity_cubit.dart';
import 'package:music_deewane/l10n/app_localizations.dart';
import 'package:music_deewane/screens/widgets/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<ConnectivityCubit, ConnectivityState>(
      listenWhen: (prev, curr) =>
          prev == ConnectivityState.disconnected &&
          curr == ConnectivityState.connected,
      listener: (_, __) =>
          SnackbarService.showMessage(l10n.bannerBackOnline, duration: const Duration(seconds: 3)),
      builder: (context, state) {
        final offline = state == ConnectivityState.disconnected;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: offline ? 40 : 0,
          color: Theme.of(context).colorScheme.error,
          child: offline
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.bannerOffline,
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                )
              : null,
        );
      },
    );
  }
}
