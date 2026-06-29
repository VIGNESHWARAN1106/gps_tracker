import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PlatformChannelService {
  static const MethodChannel _batteryChannel = MethodChannel(
    'com.example.gps_tracker/battery',
  );
  static const MethodChannel _controlChannel = MethodChannel(
    'com.example.gps_tracker/control',
  );

  /// Fetches the hardware battery capacity via the native Android framework.
  static Future<int> getBatteryLevel() async {
    try {
      final int result = await _batteryChannel.invokeMethod('getBatteryLevel');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print(
          "SYSTEM METRIC: IPC Failure - Unable to acquire battery telemetry: '${e.message}'.",
        );
      }
      return -1;
    }
  }

  /// Transmits the initialization command to the Kotlin Foreground Service.
  static Future<void> startTrackingSession() async {
    try {
      await _controlChannel.invokeMethod('startTracking');
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print(
          "SYSTEM METRIC: IPC Failure - Tracking initialization aborted: '${e.message}'.",
        );
      }
    }
  }

  /// Transmits the termination command to the Kotlin Foreground Service.
  static Future<void> stopTrackingSession() async {
    try {
      await _controlChannel.invokeMethod('stopTracking');
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print(
          "SYSTEM METRIC: IPC Failure - Tracking termination aborted: '${e.message}'.",
        );
      }
    }
  }
}
