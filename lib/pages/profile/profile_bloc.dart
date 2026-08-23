import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'profile_store.dart';

@immutable
class ProfileState {
  const ProfileState({
    required this.userId,
    required this.name,
    required this.age,
    required this.photoPath,
    required this.plannerMode,
    required this.onboardingComplete,
  });

  factory ProfileState.fromStore(ProfileStore store) {
    return ProfileState(
      userId: store.userId.value,
      name: store.name.value,
      age: store.age.value,
      photoPath: store.photoPath.value,
      plannerMode: store.plannerMode.value,
      onboardingComplete: store.onboardingComplete.value,
    );
  }

  final String userId;
  final String name;
  final int? age;
  final String? photoPath;
  final String plannerMode;
  final bool onboardingComplete;
}

class ProfileBloc extends Cubit<ProfileState> {
  ProfileBloc({ProfileStore? store})
      : _store = store ?? ProfileStore.instance,
        super(ProfileState.fromStore(store ?? ProfileStore.instance)) {
    _store.userId.addListener(_syncFromStore);
    _store.name.addListener(_syncFromStore);
    _store.age.addListener(_syncFromStore);
    _store.photoPath.addListener(_syncFromStore);
    _store.plannerMode.addListener(_syncFromStore);
    _store.onboardingComplete.addListener(_syncFromStore);
  }

  final ProfileStore _store;

  Future<void> setName(String value) => _store.setName(value);

  Future<void> setAge(int value) => _store.setAge(value);

  Future<void> setPlannerMode(String modeId) => _store.setPlannerMode(modeId);

  Future<void> setPhoto(String path) => _store.setPhoto(path);

  Future<void> clearPhoto() => _store.clearPhoto();

  void _syncFromStore() => emit(ProfileState.fromStore(_store));

  @override
  Future<void> close() {
    _store.userId.removeListener(_syncFromStore);
    _store.name.removeListener(_syncFromStore);
    _store.age.removeListener(_syncFromStore);
    _store.photoPath.removeListener(_syncFromStore);
    _store.plannerMode.removeListener(_syncFromStore);
    _store.onboardingComplete.removeListener(_syncFromStore);
    return super.close();
  }
}
