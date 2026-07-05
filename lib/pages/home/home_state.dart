class HomeState {
  const HomeState({
    this.selectedIndex = 0,
  });

  final int selectedIndex;

  HomeState copyWith({
    int? selectedIndex,
  }) {
    return HomeState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }
}
