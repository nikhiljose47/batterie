import 'package:flutter/foundation.dart';

import 'home_state.dart';

class HomeController extends ChangeNotifier {
  HomeState _state = const HomeState();

  HomeState get state => _state;

  void updateSelectedIndex(int index) {
    if (_state.selectedIndex == index) {
      return;
    }

    _state = _state.copyWith(selectedIndex: index);
    notifyListeners();
  }
}
