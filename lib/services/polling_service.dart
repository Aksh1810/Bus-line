import 'dart:async';
import '../state/transit_store.dart';

class PollingService {
  PollingService(this._store, {Duration interval = const Duration(seconds: 3)})
      : _interval = interval;

  final TransitStore _store;
  final Duration _interval;
  Timer? _timer;

  void start() {
    if (_timer != null) return;
    _store.refreshVehicles();
    _timer = Timer.periodic(_interval, (_) => _store.refreshVehicles());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
