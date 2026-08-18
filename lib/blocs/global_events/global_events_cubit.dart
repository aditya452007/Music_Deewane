import 'dart:developer';

import 'package:music_deewane/core/constants/setting_keys.dart';
import 'package:music_deewane/services/music_deewane_updater_tools.dart';
import 'package:music_deewane/services/db/dao/settings_dao.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'global_events_state.dart';

class GlobalEventsCubit extends Cubit<GlobalEventsState> {
  final SettingsDAO _settingsDao;

  GlobalEventsCubit({required SettingsDAO settingsDao})
      : _settingsDao = settingsDao,
        super(GlobalEventsInitial()) {
    checkForUpdates();
  }

  void checkForUpdates() async {
    final Map<String, dynamic> updates = await getAppUpdates();
    log("Checking for updates...", name: 'GlobalEventsCubit');
    log("Current: ${updates["currVer"]}+${updates["currBuild"]}",
        name: 'GlobalEventsCubit');
    log("Remote: ${updates["newVer"]}+${updates["newBuild"]} (source: ${updates["source"]})",
        name: 'GlobalEventsCubit');
    log("isUpdateAvailable: ${updates["results"]}", name: 'GlobalEventsCubit');

    if (await _settingsDao.getSettingBool(SettingKeys.autoUpdateNotify) ??
        true) {
      if (updates["results"]) {
        emit(UpdateAvailable(
          newVersion: updates["newVer"],
          newBuild: updates["newBuild"],
          downloadUrl: updates["download_url"] ??
              "https://music-deewane.sourceforge.io/",
        ));
      }
    }
  }

  void showAlertDialog(String title, String content) {
    emit(AlertDialogState(title: title, content: content));
  }
}
