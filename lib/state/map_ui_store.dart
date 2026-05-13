import 'package:flutter/foundation.dart';

class MapUiStore extends ChangeNotifier {
  static const double stopVisibleZoom = 14.0;

  double _currentZoom = 13.0;
  double get currentZoom => _currentZoom;

  set currentZoom(double z) {
    if (z == _currentZoom) return;
    _currentZoom = z;
    notifyListeners();
  }
}
