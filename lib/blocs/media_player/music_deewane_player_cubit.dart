import 'package:music_deewane/services/music_deewane_player.dart';
import 'package:bloc/bloc.dart';
import 'package:rxdart/rxdart.dart';
part 'music_deewane_player_state.dart';

class MusicDeewanePlayerCubit extends Cubit<MusicDeewanePlayerState> {
  final MusicDeewanePlayer player;
  late ValueStream<ProgressBarStreams> progressStreams;

  MusicDeewanePlayerCubit(this.player)
      : super(MusicDeewanePlayerState(isReady: true)) {
    player.syncPublicState();
    _setupProgressStreams();
  }

  void switchShowLyrics({bool? value}) {
    emit(MusicDeewanePlayerState(
        isReady: true, showLyrics: value ?? !state.showLyrics));
  }

  void _setupProgressStreams() {
    progressStreams = Rx.combineLatest4(
      Rx.defer(() => player.engine.positionStream, reusable: true),
      Rx.defer(() => player.engine.durationStream, reusable: true),
      Rx.defer(() => player.engine.bufferedStream, reusable: true),
      Rx.defer(() => player.engine.playingStream, reusable: true),
      (Duration position, Duration duration, Duration buffered, bool playing) =>
          ProgressBarStreams(
        position: position,
        duration: duration,
        buffered: buffered,
        isPlaying: playing,
      ),
    ).shareValueSeeded(
      ProgressBarStreams(
        position: Duration.zero,
        duration: Duration.zero,
        buffered: Duration.zero,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> close() {
    // Intentionally does NOT stop the player.
    // The AudioService foreground service manages its own lifecycle via
    // onTaskRemoved() / onNotificationDeleted().
    return super.close();
  }
}
