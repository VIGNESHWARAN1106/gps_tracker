import 'package:flutter/material.dart';
import 'package:gps_tracker/constants/app_colors.dart';
import 'package:gps_tracker/data/models/tracker_record_model.dart';
import 'package:gps_tracker/presentation/widgets/tracker_record_tile.dart';

class TrackerRecordListView extends StatelessWidget {
  final List<TrackerRecord> trackerRecordLog;
  final bool isTrackingActive;

  const TrackerRecordListView({
    super.key,
    required this.trackerRecordLog,
    required this.isTrackingActive,
  });

  @override
  Widget build(BuildContext context) {
    if (trackerRecordLog.isEmpty) {
      return Center(
        child: Text(
          isTrackingActive
              ? 'Awaiting first GPS tracker ping (60s interval)...'
              : 'No active session data found.',
          style: const TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: trackerRecordLog.length,
      itemBuilder: (context, index) =>
          TrackerRecordTile(record: trackerRecordLog[index]),
    );
  }
}
