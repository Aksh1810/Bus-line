import 'package:flutter/services.dart';

class LiveActivityService {
  static const platform = MethodChannel('com.busline/live_activity');

  Future<void> startBusActivity(
    String busId,
    String status,
    int arrivalTime,
  ) async {
    try {
      await platform.invokeMethod('startActivity', {
        'busId': busId,
        'status': status,
        'arrivalTime': arrivalTime,
      });
    } on PlatformException catch (e) {
      print("Failed to start Live Activity: '${e.message}'.");
    }
  }

  Future<void> updateBusActivity(String status, int arrivalTime) async {
    try {
      await platform.invokeMethod('updateActivity', {
        'status': status,
        'arrivalTime': arrivalTime,
      });
    } on PlatformException catch (e) {
      print("Failed to update Live Activity: '${e.message}'.");
    }
  }

  Future<void> stopBusActivity() async {
    try {
      await platform.invokeMethod('stopActivity');
    } on PlatformException catch (e) {
      print("Failed to stop Live Activity: '${e.message}'.");
    }
  }
}
