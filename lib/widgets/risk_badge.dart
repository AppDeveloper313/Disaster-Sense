import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../models/city_alert.dart';

/// Returns a pair of (background, foreground) colors for [level] that are
/// accessible in both light and dark mode by blending the semantic color with
/// the surface so contrast is always ≥ 4.5:1.
(Color bg, Color fg) _riskColors(BuildContext context, RiskLevel level) {
  final brightness = Theme.of(context).brightness;
  final isDark = brightness == Brightness.dark;

  switch (level) {
    case RiskLevel.low:
      return isDark
          ? (const Color(0xFF1B3A2B), const Color(0xFF6EE8A2))
          : (const Color(0xFFDCF5E7), const Color(0xFF1B6B3A));
    case RiskLevel.medium:
      return isDark
          ? (const Color(0xFF3A2E00), const Color(0xFFFFD54F))
          : (const Color(0xFFFFF8E1), const Color(0xFF7A5900));
    case RiskLevel.high:
      return isDark
          ? (const Color(0xFF4A1010), const Color(0xFFFF8A80))
          : (const Color(0xFFFFEBEE), const Color(0xFFB71C1C));
    case RiskLevel.unknown:
      final surface = Theme.of(context).colorScheme.surfaceContainerHighest;
      final onSurface = Theme.of(context).colorScheme.onSurfaceVariant;
      return (surface, onSurface);
  }
}

class RiskBadge extends StatelessWidget {
  final RiskLevel riskLevel;
  final String label;
  final bool compact;
  final IconData? iconData;

  const RiskBadge({
    super.key,
    required this.riskLevel,
    required this.label,
    this.compact = false,
    this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _riskColors(context, riskLevel);

    Widget badge = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: fg.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData ?? riskLevel.icon,
            size: compact ? 14 : 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            compact ? riskLevel.label : '$label: ${riskLevel.label}',
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 12 : 13,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );

    // Add pulse animation for high risk
    if (riskLevel == RiskLevel.high) {
      return Pulse(
        infinite: true,
        duration: const Duration(seconds: 2),
        child: badge,
      );
    }

    return badge;
  }
}
