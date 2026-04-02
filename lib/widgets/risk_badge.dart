import 'package:flutter/material.dart';
import '../models/city_alert.dart';

class RiskBadge extends StatelessWidget {
  final RiskLevel riskLevel;
  final String label;
  final bool compact;

  const RiskBadge({
    super.key,
    required this.riskLevel,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: riskLevel.color.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskLevel.color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            riskLevel.icon,
            size: compact ? 14 : 16,
            color: riskLevel.color,
          ),
          const SizedBox(width: 4),
          Text(
            compact ? riskLevel.label : '$label: ${riskLevel.label}',
            style: TextStyle(
              color: riskLevel.color,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
