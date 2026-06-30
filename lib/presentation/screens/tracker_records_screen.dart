import 'package:flutter/material.dart';
import 'package:gps_tracker/constants/app_colors.dart';
import 'package:gps_tracker/core/database_repository.dart';
import 'package:gps_tracker/data/models/tracker_record_model.dart';
import 'package:gps_tracker/presentation/widgets/tracker_record_tile.dart';

/// Dedicated screen showing the full tracker record history with a
/// summary header and a newest/oldest sort toggle.
class TrackerRecordsScreen extends StatefulWidget {
  final bool isTrackingActive;

  const TrackerRecordsScreen({super.key, required this.isTrackingActive});

  @override
  State<TrackerRecordsScreen> createState() => _TrackerRecordsScreenState();
}

class _TrackerRecordsScreenState extends State<TrackerRecordsScreen> {
  List<TrackerRecord> _records = [];
  bool _isLoading = true;
  bool _newestFirst = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final data = await DatabaseRepository.fetchTelemetryLog();
    data.sort(
      (a, b) => _newestFirst
          ? b.timestamp.compareTo(a.timestamp)
          : a.timestamp.compareTo(b.timestamp),
    );
    if (mounted) {
      setState(() {
        _records = data;
        _isLoading = false;
      });
    }
  }

  void _toggleSort() {
    setState(() {
      _newestFirst = !_newestFirst;
      _records = List.of(_records.reversed);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ALL RECORDS',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _newestFirst ? 'Newest first' : 'Oldest first',
            icon: Icon(
              _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
            ),
            onPressed: _isLoading ? null : _toggleSort,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadRecords,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryBar(
                      total: _records.length,
                      isTrackingActive: widget.isTrackingActive,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _records.isEmpty
                          ? const Center(
                              child: Text(
                                'No records yet.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _records.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  TrackerRecordTile(record: _records[index]),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int total;
  final bool isTrackingActive;

  const _SummaryBar({required this.total, required this.isTrackingActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            '$total total records',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:
                  (isTrackingActive
                          ? AppColors.success
                          : AppColors.textSecondary)
                      .withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isTrackingActive ? 'TRACKING' : 'IDLE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isTrackingActive
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
