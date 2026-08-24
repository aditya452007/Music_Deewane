import 'dart:async';
import 'dart:developer';
import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
part 'connectivity_state.dart';

class ConnectivityCubit extends Cubit<ConnectivityState> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  ConnectivityCubit() : super(ConnectivityState.disconnected) {
    _init();
    _subscription = Connectivity().onConnectivityChanged.listen((event) {
      if (event.contains(ConnectivityResult.wifi) ||
          event.contains(ConnectivityResult.mobile) ||
          event.contains(ConnectivityResult.ethernet) ||
          event.contains(ConnectivityResult.bluetooth) ||
          event.contains(ConnectivityResult.vpn)) {
        emit(ConnectivityState.connected);
        log('Connected to network: $event', name: 'ConnectivityCubit');
      } else {
        emit(ConnectivityState.disconnected);
        log('Disconnected from network: $event', name: 'ConnectivityCubit');
      }
    });
  }

  Future<void> _init() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.ethernet) ||
          result.contains(ConnectivityResult.bluetooth) ||
          result.contains(ConnectivityResult.vpn)) {
        emit(ConnectivityState.connected);
        log('Initial connectivity: $result', name: 'ConnectivityCubit');
      }
    } catch (e, st) {
      log('checkConnectivity failed: $e',
          name: 'ConnectivityCubit', stackTrace: st);
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
