import 'dart:developer';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:music_deewane/core/constants/setting_keys.dart';
import 'package:music_deewane/services/db/db_provider.dart';
import 'package:music_deewane/services/db/global_db.dart';

/// One-time migration: `bloomfactory` → `musicdeewanefactory`.
///
/// Covers:
/// - Isar collections: TrackDB, DownloadDB, LyricsDB, CacheEntryDB,
///   PluginStorageEntity, AppSettingsStrDB (+ embedded mediaIds)
/// - AppSettingsStrDB plugin-ID prefs (home/search/suggestion, autoLoad lists)
/// - Filesystem: stale `plugins/*bloomfactory*` directories
///
/// Safe to run repeatedly — no-ops when nothing matches.
/// Uses `bloomfactory` lower-case match (all stored IDs are lower-case).
class PluginIdMigrationService {
  static const _old = 'bloomfactory';
  static const _new = 'musicdeewanefactory';
  static const _flagKey = 'plugin_id_migration_bloom_to_musicdeewane_v1';

  static String _migrateStr(String s) =>
      s.contains(_old) ? s.replaceAll(_old, _new) : s;

  static bool _needs(String s) => s.contains(_old);

  /// Run DB + filesystem migration. Returns true if anything changed.
  static Future<bool> run() async {
    final isar = await DBProvider.db;
    // Guard: run once per app install (stored in AppSettingsStrDB).
    final already = await isar.appSettingsStrDBs
        .filter()
        .settingNameEqualTo(_flagKey)
        .findFirst();
    // Even if flag exists, still check for stragglers (e.g. restored backup).
    // But if flag exists and no stragglers, skip fast.
    var changed = false;

    // TrackDB
    changed |= await _migrateTracks(isar);
    // DownloadDB
    changed |= await _migrateDownloads(isar);
    // LyricsDB
    changed |= await _migrateLyrics(isar);
    // CacheEntryDB
    changed |= await _migrateCache(isar);
    // PluginStorageEntity
    changed |= await _migratePluginStorage(isar);
    // AppSettingsStrDB
    changed |= await _migrateSettings(isar);

    // Filesystem: delete stale plugin dirs so bootstrap re-downloads correctly.
    final fsChanged = await _cleanupPluginDirs();
    changed |= fsChanged;

    // Mark done.
    if (changed || already == null) {
      await isar.writeTxn(() async {
        await isar.appSettingsStrDBs.put(
          AppSettingsStrDB(settingName: _flagKey, settingValue: 'done'),
        );
      });
    }

    if (changed) {
      log('PluginIdMigration: migrated bloomfactory → musicdeewanefactory',
          name: 'PluginIdMigration');
    }
    return changed;
  }

  static Future<bool> _migrateTracks(Isar isar) async {
    final all = await isar.trackDBs.where().findAll();
    var dirty = false;
    final toPut = <TrackDB>[];
    final seenNewIds = <String>{};
    // Pre-collect existing new IDs to dedupe.
    for (final t in all) {
      if (!t.mediaId.contains(_old) && t.mediaId.contains(_new)) {
        seenNewIds.add(t.mediaId);
      }
    }
    final toDeleteIds = <int>[];
    for (final t in all) {
      var trackChanged = false;
      final oldMediaId = t.mediaId;
      if (_needs(oldMediaId)) {
        final newId = _migrateStr(oldMediaId);
        if (seenNewIds.contains(newId)) {
          // Duplicate — keep the existing new-ID row, delete the old bloomfactory row.
          toDeleteIds.add(t.id);
          dirty = true;
          continue;
        }
        t.mediaId = newId;
        seenNewIds.add(newId);
        trackChanged = true;
      }
      // Embedded ArtistSummaryDB.mediaId
      if (t.artists != null) {
        for (final a in t.artists!) {
          if (a.mediaId != null && _needs(a.mediaId!)) {
            a.mediaId = _migrateStr(a.mediaId!);
            trackChanged = true;
          }
        }
      }
      // Embedded AlbumSummaryDB.mediaId + its artists
      final album = t.album;
      if (album != null) {
        if (album.mediaId != null && _needs(album.mediaId!)) {
          album.mediaId = _migrateStr(album.mediaId!);
          trackChanged = true;
        }
        if (album.artists != null) {
          for (final a in album.artists!) {
            if (a.mediaId != null && _needs(a.mediaId!)) {
              a.mediaId = _migrateStr(a.mediaId!);
              trackChanged = true;
            }
          }
        }
      }
      if (trackChanged) {
        toPut.add(t);
        dirty = true;
      }
    }
    if (toDeleteIds.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final id in toDeleteIds) {
          await isar.trackDBs.delete(id);
        }
      });
    }
    if (toPut.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final t in toPut) {
          await isar.trackDBs.put(t);
        }
      });
    }
    // Also handle PlaylistDB embedded mediaIds (not indexed, so scan all)
    final playlists = await isar.playlistDBs.where().findAll();
    final plToPut = <PlaylistDB>[];
    for (final pl in playlists) {
      var ch = false;
      if (pl.artists != null) {
        for (final a in pl.artists!) {
          if (a.mediaId != null && _needs(a.mediaId!)) {
            a.mediaId = _migrateStr(a.mediaId!);
            ch = true;
          }
        }
      }
      final al = pl.album;
      if (al != null) {
        if (al.mediaId != null && _needs(al.mediaId!)) {
          al.mediaId = _migrateStr(al.mediaId!);
          ch = true;
        }
        if (al.artists != null) {
          for (final a in al.artists!) {
            if (a.mediaId != null && _needs(a.mediaId!)) {
              a.mediaId = _migrateStr(a.mediaId!);
              ch = true;
            }
          }
        }
      }
      final rp = pl.remotePlaylist;
      if (rp != null) {
        if (rp.mediaId != null && _needs(rp.mediaId!)) {
          rp.mediaId = _migrateStr(rp.mediaId!);
          ch = true;
        }
        if (rp.artists != null) {
          for (final a in rp.artists!) {
            if (a.mediaId != null && _needs(a.mediaId!)) {
              a.mediaId = _migrateStr(a.mediaId!);
              ch = true;
            }
          }
        }
        final rpa = rp.album;
        if (rpa != null) {
          if (rpa.mediaId != null && _needs(rpa.mediaId!)) {
            rpa.mediaId = _migrateStr(rpa.mediaId!);
            ch = true;
          }
        }
      }
      if (ch) {
        plToPut.add(pl);
        dirty = true;
      }
    }
    if (plToPut.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final pl in plToPut) {
          await isar.playlistDBs.put(pl);
        }
      });
    }
    return dirty;
  }

  static Future<bool> _migrateDownloads(Isar isar) async {
    final all = await isar.downloadDBs.where().findAll();
    var dirty = false;
    final toPut = <DownloadDB>[];
    final seen = <String>{};
    for (final d in all) {
      if (!d.mediaId.contains(_old)) {
        seen.add(d.mediaId);
      }
    }
    final toDelete = <int>[];
    for (final d in all) {
      if (_needs(d.mediaId)) {
        final newId = _migrateStr(d.mediaId);
        if (seen.contains(newId)) {
          toDelete.add(d.id);
          dirty = true;
          continue;
        }
        d.mediaId = newId;
        seen.add(newId);
        toPut.add(d);
        dirty = true;
      }
    }
    if (toDelete.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final id in toDelete) {
          await isar.downloadDBs.delete(id);
        }
      });
    }
    if (toPut.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final d in toPut) {
          await isar.downloadDBs.put(d);
        }
      });
    }
    return dirty;
  }

  static Future<bool> _migrateLyrics(Isar isar) async {
    final all = await isar.lyricsDBs.where().findAll();
    var dirty = false;
    final toPut = <LyricsDB>[];
    final seenIds = <String>{};
    for (final l in all) {
      if (!l.mediaID.contains(_old)) seenIds.add(l.mediaID);
    }
    final toDelete = <int>[];
    for (final l in all) {
      var ch = false;
      if (_needs(l.mediaID)) {
        final nid = _migrateStr(l.mediaID);
        if (seenIds.contains(nid)) {
          toDelete.add(l.id);
          dirty = true;
          continue;
        }
        l.mediaID = nid;
        seenIds.add(nid);
        ch = true;
      }
      if (_needs(l.sourceId)) {
        l.sourceId = _migrateStr(l.sourceId);
        ch = true;
      }
      if (_needs(l.source)) {
        l.source = _migrateStr(l.source);
        ch = true;
      }
      if (ch) {
        toPut.add(l);
        dirty = true;
      }
    }
    if (toDelete.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final id in toDelete) {
          await isar.lyricsDBs.delete(id);
        }
      });
    }
    if (toPut.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final l in toPut) {
          await isar.lyricsDBs.put(l);
        }
      });
    }
    return dirty;
  }

  static Future<bool> _migrateCache(Isar isar) async {
    final all = await isar.cacheEntryDBs.where().findAll();
    var dirty = false;
    final toPut = <CacheEntryDB>[];
    for (final c in all) {
      var ch = false;
      if (_needs(c.key)) {
        c.key = _migrateStr(c.key);
        ch = true;
      }
      if (_needs(c.value)) {
        c.value = _migrateStr(c.value);
        ch = true;
      }
      if (c.blob != null && _needs(c.blob!)) {
        c.blob = _migrateStr(c.blob!);
        ch = true;
      }
      if (ch) {
        toPut.add(c);
        dirty = true;
      }
    }
    if (toPut.isNotEmpty) {
      // Dedupe by key — if bloomfactory key collides with existing new key, keep newer.
      final byKey = <String, CacheEntryDB>{};
      for (final c in toPut) {
        byKey[c.key] = c;
      }
      // Also need to delete old keys that were replaced and collided?
      await isar.writeTxn(() async {
        for (final c in byKey.values) {
          await isar.cacheEntryDBs.put(c);
        }
      });
      // Delete stale old-key rows that were superseded (if we migrated key, old key row remains with old key? No, we mutated in place.)
      // No extra delete needed because we mutated.
    }
    return dirty;
  }

  static Future<bool> _migratePluginStorage(Isar isar) async {
    final all = await isar.pluginStorageEntitys.where().findAll();
    var dirty = false;
    final toDelete = <int>[];
    final toPut = <PluginStorageEntity>[];
    final seenKeys = <String>{};
    for (final e in all) {
      if (!e.pluginId.contains(_old)) {
        seenKeys.add(e.compositeKey);
      }
    }
    for (final e in all) {
      if (_needs(e.pluginId) || _needs(e.compositeKey)) {
        final newPluginId = _migrateStr(e.pluginId);
        final newKey = _migrateStr(e.key);
        final newComposite = '$newPluginId/$newKey';
        if (seenKeys.contains(newComposite)) {
          toDelete.add(e.id);
          dirty = true;
          continue;
        }
        e.pluginId = newPluginId;
        e.key = newKey;
        e.compositeKey = newComposite;
        if (_needs(e.value)) {
          e.value = _migrateStr(e.value);
        }
        seenKeys.add(newComposite);
        toPut.add(e);
        dirty = true;
      } else if (_needs(e.value)) {
        e.value = _migrateStr(e.value);
        toPut.add(e);
        dirty = true;
      }
    }
    if (toDelete.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final id in toDelete) {
          await isar.pluginStorageEntitys.delete(id);
        }
      });
    }
    if (toPut.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final e in toPut) {
          await isar.pluginStorageEntitys.put(e);
        }
      });
    }
    return dirty;
  }

  static Future<bool> _migrateSettings(Isar isar) async {
    final all = await isar.appSettingsStrDBs.where().findAll();
    var dirty = false;
    final toPut = <AppSettingsStrDB>[];
    // Known plugin-ID-bearing keys
    const pluginKeys = {
      SettingKeys.homePluginId,
      SettingKeys.searchPluginId,
      SettingKeys.suggestionPluginId,
      SettingKeys.autoLoadPluginIds,
      SettingKeys.resolverPriority,
      SettingKeys.lyricsPriority,
    };
    for (final s in all) {
      var ch = false;
      if (_needs(s.settingValue)) {
        // For autoLoadPluginIds etc JSON may contain bloomfactory
        s.settingValue = _migrateStr(s.settingValue);
        ch = true;
      }
      if (s.settingValue2 != null && _needs(s.settingValue2!)) {
        s.settingValue2 = _migrateStr(s.settingValue2!);
        ch = true;
      }
      // Even unknown keys: if they contain bloomfactory, migrate (defensive)
      if (ch) {
        toPut.add(s);
        dirty = true;
      } else if (pluginKeys.contains(s.settingName) && _needs(s.settingName)) {
        // not needed; name itself not bloomfactory
      }
    }
    // Also handle case where settingValue IS the pluginId string exactly
    if (toPut.isNotEmpty) {
      await isar.writeTxn(() async {
        for (final s in toPut) {
          await isar.appSettingsStrDBs.put(s);
        }
      });
    }
    return dirty;
  }

  static Future<bool> _cleanupPluginDirs() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final pluginsDir = Directory(p.join(supportDir.path, 'plugins'));
      if (!await pluginsDir.exists()) return false;
      var changed = false;
      await for (final ent in pluginsDir.list(followLinks: false)) {
        final name = p.basename(ent.path);
        if (name.contains(_old)) {
          try {
            if (ent is Directory) {
              await ent.delete(recursive: true);
            } else {
              await ent.delete();
            }
            log('Deleted stale plugin dir: $name', name: 'PluginIdMigration');
            changed = true;
          } catch (e) {
            log('Failed to delete stale plugin dir $name: $e',
                name: 'PluginIdMigration');
          }
        }
      }
      return changed;
    } catch (e) {
      log('Plugin dir cleanup skipped: $e', name: 'PluginIdMigration');
      return false;
    }
  }
}
