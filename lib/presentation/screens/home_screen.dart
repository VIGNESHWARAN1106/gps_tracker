import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gps_tracker/constants/app_colors.dart';
import 'package:gps_tracker/core/database_repository.dart';
import 'package:gps_tracker/data/models/tracker_record_model.dart';
import 'package:gps_tracker/presentation/screens/tracker_records_screen.dart';
import 'package:location/location.dart' as loc;
import 'package:gps_tracker/core/platform_channel_service.dart';
import 'package:gps_tracker/presentation/widgets/control_button.dart';
import 'package:gps_tracker/presentation/widgets/tracker_record_listview.dart';
import 'package:gps_tracker/presentation/widgets/battery_status_card.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _batteryLevel = -1;
  bool _isTrackingActive = false;
  List<TrackerRecord> recordsLog = [];

  Timer? _batteryTimer;
  Timer? _databaseRefreshTimer;

  static const int _recentRecordsLimit = 10;

  @override
  void initState() {
    super.initState();
    _refreshHardwareMetrics();
    _refreshLocalTelemetry();
    _executePreFlightValidation();
    _startPeriodicTelemetryPolling();
  }

  @override
  void dispose() {
    _batteryTimer?.cancel();
    _databaseRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _executePreFlightValidation() async {
    loc.Location location = loc.Location();
    bool isLocationServiceEnabled =
        await Permission.location.serviceStatus.isEnabled;
    if (!isLocationServiceEnabled) {
      isLocationServiceEnabled = await location.requestService();
      if (!isLocationServiceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Hardware GPS is disabled. Tracking cannot function.",
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }
    }

    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.notification,
    ].request();

    bool locationGranted = statuses[Permission.location]?.isGranted ?? false;
    bool locationPermanentlyDenied =
        statuses[Permission.location]?.isPermanentlyDenied ?? false;

    if (locationPermanentlyDenied) {
      _showSettingsDialog(
        "Location permission is permanently denied. Please enable it in system settings.",
      );
      return;
    }

    if (locationGranted) {
      PermissionStatus bgStatus = await Permission.locationAlways.request();
      if (bgStatus.isPermanentlyDenied) {
        _showSettingsDialog(
          "Background tracking authorization is required. Please select 'Allow all the time' in system settings.",
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
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    bool serviceStatus = await PlatformChannelService.isServiceRunning();
    if (mounted) setState(() => _isTrackingActive = serviceStatus);
    _refreshHardwareMetrics();
    _refreshLocalTelemetry();
  }

  void _startPeriodicTelemetryPolling() {
    _batteryTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshHardwareMetrics(),
    );
    _databaseRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshLocalTelemetry(),
    );
  }

  Future<void> _refreshHardwareMetrics() async {
    final int level = await PlatformChannelService.getBatteryLevel();
    if (mounted) setState(() => _batteryLevel = level);
  }

  Future<void> _refreshLocalTelemetry() async {
    final List<TrackerRecord> data =
        await DatabaseRepository.fetchTelemetryLog();
    if (mounted) setState(() => recordsLog = data);
  }

  void _showSettingsDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Permission Required',
          style: TextStyle(color: AppColors.error),
        ),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _toggleTrackingSession() async {
    if (_isTrackingActive) {
      await PlatformChannelService.stopTrackingSession();
      setState(() => _isTrackingActive = false);
    } else {
      loc.Location location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();

      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "SYSTEM HALTED: Enable GPS hardware to start tracking.",
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      if (await Permission.location.isGranted) {
        await PlatformChannelService.startTrackingSession();
        setState(() => _isTrackingActive = true);
      } else {
        _executePreFlightValidation();
      }
    }
    _refreshLocalTelemetry();
  }

  void _navigateToAllRecords() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            TrackerRecordsScreen(isTrackingActive: _isTrackingActive),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentRecords = recordsLog.length > _recentRecordsLimit
        ? recordsLog.sublist(0, _recentRecordsLimit)
        : recordsLog;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GPS TRACKER',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
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
            BatteryStatusCard(batteryLevel: _batteryLevel),
            const SizedBox(height: 16),
            ControlButton(
              isTrackingActive: _isTrackingActive,
              onToggle: _toggleTrackingSession,
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Tracker Records',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryLight,
                  ),
                ),
                TextButton(
                  onPressed: _navigateToAllRecords,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryLight,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'See All',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TrackerRecordListView(
                trackerRecordLog: recentRecords,
                isTrackingActive: _isTrackingActive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
