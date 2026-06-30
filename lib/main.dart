import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/platform_channel_service.dart';
import 'core/database_repository.dart';

void main() {
  runApp(const GPSTrackerApp());
}

class GPSTrackerApp extends StatelessWidget {
  const GPSTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E676),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const TrackingHomeScreen(),
    );
  }
}

class TrackingHomeScreen extends StatefulWidget {
  const TrackingHomeScreen({super.key});

  @override
  State<TrackingHomeScreen> createState() => _TrackingHomeScreenState();
}

class _TrackingHomeScreenState extends State<TrackingHomeScreen> {
  int _batteryLevel = -1;
  bool _isTrackingActive = false;
  List<Map<String, dynamic>> _telemetryLog = [];

  Timer? _batteryTimer;
  Timer? _databaseRefreshTimer;

  @override
  void initState() {
    super.initState();
    _executePreFlightValidation();
    _startPeriodicTelemetryPolling();
  }

  @override
  void dispose() {
    _batteryTimer?.cancel();
    _databaseRefreshTimer?.cancel();
    super.dispose();
  }

  /// Evaluates and enforces OS-level authorization requirements and hardware states.
  Future<void> _executePreFlightValidation() async {
    // 1. HARDWARE STATE CHECK: Verify the physical GPS radio is powered on
    bool isLocationServiceEnabled =
        await Permission.location.serviceStatus.isEnabled;
    if (!isLocationServiceEnabled) {
      _showSettingsDialog(
        "System GPS is currently disabled. The tracker cannot acquire hardware telemetry. Please turn on Location services in your device settings.",
      );
      return; // Abort further permission checks until hardware is active
    }

    // 2. SOFTWARE AUTHORIZATION: Request primary foreground permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.notification,
    ].request();

    bool locationGranted = statuses[Permission.location]?.isGranted ?? false;
    bool locationPermanentlyDenied =
        statuses[Permission.location]?.isPermanentlyDenied ?? false;

    // 3. Handle Permanent Denial (The OS blocked the prompt)
    if (locationPermanentlyDenied) {
      _showSettingsDialog(
        "Location permission is permanently denied. The tracker lacks software authorization. Please enable it in system settings.",
      );
      return;
    }

    // 4. Handle Background Location Authorization
    if (locationGranted) {
      PermissionStatus bgStatus = await Permission.locationAlways.request();

      if (bgStatus.isPermanentlyDenied) {
        _showSettingsDialog(
          "Background tracking authorization is required to operate while minimized. Please select 'Allow all the time' in system settings.",
        );
        return;
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "SYSTEM WARNING: Tracking requires location permissions to operate.",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    bool serviceStatus = await PlatformChannelService.isServiceRunning();
    if (mounted) {
      setState(() {
        _isTrackingActive = serviceStatus;
      });
    }

    // If execution reaches this block, both hardware and software gates are cleared.
    _refreshHardwareMetrics();
    _refreshLocalTelemetry();
  }

  /// Schedules UI polling loops to refresh presentation data.
  void _startPeriodicTelemetryPolling() {
    // Polls battery metrics periodically to fulfill core requirement [cite: 30]
    _batteryTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshHardwareMetrics(),
    );

    // Polls local SQLite file every 10 seconds to display active telemetry logs safely without blockages
    _databaseRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshLocalTelemetry(),
    );
  }

  Future<void> _refreshHardwareMetrics() async {
    final int level = await PlatformChannelService.getBatteryLevel();
    if (mounted) {
      setState(() {
        _batteryLevel = level;
      });
    }
  }

  Future<void> _refreshLocalTelemetry() async {
    final List<Map<String, dynamic>> data =
        await DatabaseRepository.fetchTelemetryLog();
    if (mounted) {
      setState(() {
        _telemetryLog = data;
      });
    }
  }

  /// Helper method to route the user to OS Settings when permissions are hard-locked.
  void _showSettingsDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Force user interaction
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Permission Required',
            style: TextStyle(color: Colors.redAccent),
          ),
          content: Text(message),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
              ),
              child: const Text('Open Settings'),
              onPressed: () {
                openAppSettings(); // Triggers the permission_handler native routing
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleTrackingSession() async {
    if (_isTrackingActive) {
      await PlatformChannelService.stopTrackingSession();
      setState(() {
        _isTrackingActive = false;
      });
    } else {
      // Defensive Check: Halt execution if user revoked location permissions manually
      if (await Permission.location.isGranted) {
        await PlatformChannelService.startTrackingSession();
        setState(() {
          _isTrackingActive = true;
        });
      } else {
        _executePreFlightValidation();
      }
    }
    _refreshLocalTelemetry();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telemetry Command Center'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshHardwareMetrics();
              _refreshLocalTelemetry();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Battery Status Card Component [cite: 29]
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      _batteryLevel > 20
                          ? Icons.battery_charging_full
                          : Icons.battery_alert,
                      size: 40,
                      color: _batteryLevel > 20
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System Battery Metrics',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        Text(
                          _batteryLevel != -1
                              ? '$_batteryLevel%'
                              : 'Computing...',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Operational Control Button Component [cite: 11, 12]
            ElevatedButton(
              onPressed: _toggleTrackingSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTrackingActive
                    ? Colors.redAccent
                    : Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isTrackingActive ? Icons.stop : Icons.play_arrow),
                  const SizedBox(width: 8),
                  Text(
                    _isTrackingActive
                        ? 'STOP TRACKING SESSION'
                        : 'START TRACKING SESSION',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Live Telemetry Ledger Section [cite: 27]
            const Text(
              'Recorded Locations Logs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.greenAccent,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _telemetryLog.isEmpty
                  ? Center(
                      child: Text(
                        _isTrackingActive
                            ? 'Awaiting first telemetry ping (60s interval)...'
                            : 'No active session data found.',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _telemetryLog.length,
                      itemBuilder: (context, index) {
                        final log = _telemetryLog[index];
                        final DateTime timestamp =
                            DateTime.fromMillisecondsSinceEpoch(
                              log['timestamp'],
                            );

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.black12,
                              child: Icon(
                                Icons.location_on,
                                color: Colors.greenAccent,
                              ),
                            ),
                            title: Text(
                              'Lat: ${log['latitude']}, Lon: ${log['longitude']}',
                            ),
                            subtitle: Text(
                              'Time: ${timestamp.toIso8601String().substring(11, 19)} | Accuracy: ${log['accuracy']}m',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
