import 'package:flutter/material.dart';

import '../utils/constants.dart';

class ExpirationIndicator extends StatelessWidget {
  final int daysUntilExpiry;
  final double size;
  final bool showText;

  const ExpirationIndicator({
    super.key,
    required this.daysUntilExpiry,
    this.size = 40,
    this.showText = true,
  });

  Color get _statusColor {
    if (daysUntilExpiry < 0) return AppConstants.dangerColor;
    if (daysUntilExpiry <= AppConstants.criticalThreshold) return Colors.red;
    if (daysUntilExpiry <= AppConstants.warningThreshold) return AppConstants.warningColor;
    if (daysUntilExpiry <= AppConstants.cautionThreshold) return Colors.yellow[700]!;
    return AppConstants.successColor;
  }

  IconData get _statusIcon {
    if (daysUntilExpiry < 0) return Icons.error;
    if (daysUntilExpiry <= AppConstants.criticalThreshold) return Icons.error_outline;
    if (daysUntilExpiry <= AppConstants.warningThreshold) return Icons.warning;
    if (daysUntilExpiry <= AppConstants.cautionThreshold) return Icons.info;
    return Icons.check_circle;
  }

  String get _statusText {
    if (daysUntilExpiry < 0) return 'Expired';
    if (daysUntilExpiry == 0) return 'Today';
    if (daysUntilExpiry == 1) return 'Tomorrow';
    if (daysUntilExpiry <= 7) return '$daysUntilExpiry days';
    return '$daysUntilExpiry days';
  }

  String get _statusDescription {
    if (daysUntilExpiry < 0) return 'Expired ${-daysUntilExpiry} days ago';
    if (daysUntilExpiry == 0) return 'Expires today';
    if (daysUntilExpiry == 1) return 'Expires tomorrow';
    if (daysUntilExpiry <= 7) return 'Expires in $daysUntilExpiry days';
    final weeks = (daysUntilExpiry / 7).floor();
    return 'Expires in $weeks ${weeks == 1 ? 'week' : 'weeks'}';
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _statusDescription,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(color: _statusColor.withOpacity(0.3), width: 2),
        ),
        child: Center(
          child: showText
              ? Text(
            _statusText,
            style: TextStyle(
              color: _statusColor,
              fontSize: size / 3,
              fontWeight: FontWeight.bold,
            ),
          )
              : Icon(
            _statusIcon,
            color: _statusColor,
            size: size / 2,
          ),
        ),
      ),
    );
  }
}

class ExpirationIndicatorWithLabel extends StatelessWidget {
  final int daysUntilExpiry;
  final Axis direction;

  const ExpirationIndicatorWithLabel({
    super.key,
    required this.daysUntilExpiry,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    if (direction == Axis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExpirationIndicator(
            daysUntilExpiry: daysUntilExpiry,
            size: 24,
            showText: false,
          ),
          const SizedBox(width: 8),
          Text(
            _getStatusLabel,
            style: TextStyle(
              color: _getStatusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExpirationIndicator(
            daysUntilExpiry: daysUntilExpiry,
            size: 32,
            showText: false,
          ),
          const SizedBox(height: 4),
          Text(
            _getStatusLabel,
            style: TextStyle(
              color: _getStatusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
  }

  Color get _getStatusColor {
    if (daysUntilExpiry < 0) return AppConstants.dangerColor;
    if (daysUntilExpiry <= 1) return Colors.red;
    if (daysUntilExpiry <= 3) return AppConstants.warningColor;
    if (daysUntilExpiry <= 7) return Colors.yellow[700]!;
    return AppConstants.successColor;
  }

  String get _getStatusLabel {
    if (daysUntilExpiry < 0) return 'Expired';
    if (daysUntilExpiry == 0) return 'Today';
    if (daysUntilExpiry == 1) return 'Tomorrow';
    if (daysUntilExpiry <= 7) return '$daysUntilExpiry days';
    return 'Safe';
  }
}

class ExpirationProgressBar extends StatelessWidget {
  final int daysUntilExpiry;
  final int totalDays;
  final double height;

  const ExpirationProgressBar({
    super.key,
    required this.daysUntilExpiry,
    required this.totalDays,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final progress = daysUntilExpiry.clamp(0, totalDays) / totalDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(_getProgressColor(progress)),
              minHeight: height,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${daysUntilExpiry.clamp(0, totalDays)} days left',
              style: TextStyle(
                fontSize: 12,
                color: _getProgressColor(progress),
              ),
            ),
            Text(
              '$totalDays days total',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Color _getProgressColor(double progress) {
    if (progress > 0.5) return Colors.green;
    if (progress > 0.25) return Colors.orange;
    return Colors.red;
  }
}