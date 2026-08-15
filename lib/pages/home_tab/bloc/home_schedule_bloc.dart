import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/sleep_schedule_store.dart';

sealed class HomeScheduleEvent {
  const HomeScheduleEvent();
}

final class HomeScheduleStarted extends HomeScheduleEvent {
  const HomeScheduleStarted();
}

final class _HomeScheduleStoreSynced extends HomeScheduleEvent {
  const _HomeScheduleStoreSynced();
}

final class _HomeScheduleClockTicked extends HomeScheduleEvent {
  const _HomeScheduleClockTicked();
}

class HomeScheduleState {
  const HomeScheduleState({
    required this.wake,
    required this.sleep,
    required this.now,
  });

  final TimeOfDay wake;
  final TimeOfDay sleep;
  final DateTime now;

  int get wakeMinutes => wake.hour * 60 + wake.minute;
  int get sleepMinutes => sleep.hour * 60 + sleep.minute;
  double get nowMinutes => now.hour * 60 + now.minute + now.second / 60.0;
}

class HomeScheduleBloc extends Bloc<HomeScheduleEvent, HomeScheduleState> {
  HomeScheduleBloc({SleepScheduleStore? store})
      : _store = store ?? SleepScheduleStore.instance,
        super(HomeScheduleState(
          wake: (store ?? SleepScheduleStore.instance).wakeTime.value,
          sleep: (store ?? SleepScheduleStore.instance).sleepTime.value,
          now: DateTime.now(),
        )) {
    on<HomeScheduleStarted>(_onStarted);
    on<_HomeScheduleStoreSynced>(_onStoreSynced);
    on<_HomeScheduleClockTicked>(_onClockTicked);

    _wakeListener = () => add(const _HomeScheduleStoreSynced());
    _sleepListener = () => add(const _HomeScheduleStoreSynced());
    _store.wakeTime.addListener(_wakeListener);
    _store.sleepTime.addListener(_sleepListener);
    add(const HomeScheduleStarted());
  }

  final SleepScheduleStore _store;
  late final VoidCallback _wakeListener;
  late final VoidCallback _sleepListener;
  Timer? _ticker;

  void _onStarted(
    HomeScheduleStarted event,
    Emitter<HomeScheduleState> emit,
  ) {
    emit(_stateFromStore());
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(seconds: 20),
      (_) => add(const _HomeScheduleClockTicked()),
    );
  }

  void _onStoreSynced(
    _HomeScheduleStoreSynced event,
    Emitter<HomeScheduleState> emit,
  ) {
    emit(_stateFromStore());
  }

  void _onClockTicked(
    _HomeScheduleClockTicked event,
    Emitter<HomeScheduleState> emit,
  ) {
    emit(HomeScheduleState(
      wake: state.wake,
      sleep: state.sleep,
      now: DateTime.now(),
    ));
  }

  HomeScheduleState _stateFromStore() {
    return HomeScheduleState(
      wake: _store.wakeTime.value,
      sleep: _store.sleepTime.value,
      now: DateTime.now(),
    );
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _store.wakeTime.removeListener(_wakeListener);
    _store.sleepTime.removeListener(_sleepListener);
    return super.close();
  }
}
