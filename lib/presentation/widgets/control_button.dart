import 'package:flutter/material.dart';
import 'package:gps_tracker/constants/app_colors.dart';

class ControlButton extends StatelessWidget {
  final bool isTrackingActive;
  final VoidCallback onToggle;

  const ControlButton({
    super.key,
    required this.isTrackingActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onToggle,
      style: ElevatedButton.styleFrom(
        backgroundColor: isTrackingActive ? AppColors.error : AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isTrackingActive ? Icons.stop : Icons.play_arrow),
          const SizedBox(width: 8),
          Text(
            isTrackingActive
                ? 'STOP TRACKING SESSION'
                : 'START TRACKING SESSION',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
