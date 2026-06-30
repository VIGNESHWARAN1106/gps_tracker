import 'package:flutter/material.dart';
import 'package:gps_tracker/constants/app_colors.dart';

class BatteryStatusCard extends StatelessWidget {
  final int batteryLevel;

  const BatteryStatusCard({super.key, required this.batteryLevel});

  @override
  Widget build(BuildContext context) {
    final bool hasValue = batteryLevel >= 0;

    final double progress = hasValue ? batteryLevel / 100 : 0;

    Color statusColor;
    String status;

    if (!hasValue) {
      statusColor = AppColors.textSecondary;
      status = "Checking...";
    } else if (batteryLevel >= 80) {
      statusColor = AppColors.success;
      status = "Excellent";
    } else if (batteryLevel >= 40) {
      statusColor = AppColors.warning;
      status = "Good";
    } else if (batteryLevel >= 20) {
      statusColor = AppColors.alert;
      status = "Low";
    } else {
      statusColor = AppColors.error;
      status = "Critical";
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    batteryLevel > 20
                        ? Icons.battery_charging_full_rounded
                        : Icons.battery_alert_rounded,
                    color: statusColor,
                    size: 34,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Battery Status",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        "Current device battery level",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    hasValue ? "$batteryLevel%" : "--",
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation(statusColor),
              ),
            ),

            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  hasValue ? "$batteryLevel of 100%" : "Waiting...",
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
