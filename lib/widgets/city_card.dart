import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/city_alert.dart';
import '../providers/disaster_provider.dart';
import 'risk_badge.dart';

class CityCard extends StatefulWidget {
  final String cityName;
  final CityData? data;
  final VoidCallback onTap;

  const CityCard({
    super.key,
    required this.cityName,
    required this.data,
    required this.onTap,
  });

  @override
  State<CityCard> createState() => _CityCardState();
}

class _CityCardState extends State<CityCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final floodRisk = widget.data?.floodAlert?.riskLevel ?? RiskLevel.unknown;
    final quakeRisk = widget.data?.earthquakeAlert?.riskLevel ?? RiskLevel.unknown;
    final heatRisk = widget.data?.heatwaveAlert?.riskLevel ?? RiskLevel.unknown;
    final overallRisk = widget.data?.overallRisk ?? RiskLevel.unknown;
    
    // Define glow color based on overall risk
    Color glowColor;
    switch (overallRisk) {
      case RiskLevel.high:
        glowColor = Colors.redAccent;
        break;
      case RiskLevel.medium:
        glowColor = Colors.orangeAccent;
        break;
      case RiskLevel.low:
        glowColor = Colors.greenAccent;
        break;
      case RiskLevel.unknown:
        glowColor = cs.primary;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        transform: Matrix4.diagonal3Values(
          _isHovered ? 1.02 : 1.0,
          _isHovered ? 1.02 : 1.0,
          1.0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: _isHovered ? 0.3 : 0.1),
              blurRadius: _isHovered ? 20 : 10,
              spreadRadius: _isHovered ? 2 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: glowColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: InkWell(
                onTap: widget.onTap,
                onHover: (hovering) => setState(() => _isHovered = hovering),
                splashColor: glowColor.withValues(alpha: 0.2),
                highlightColor: glowColor.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.cityName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chevron_right,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          RiskBadge(
                            riskLevel: floodRisk,
                            label: 'Flood',
                            compact: true,
                            iconData: Icons.water_drop_outlined,
                          ),
                          RiskBadge(
                            riskLevel: quakeRisk,
                            label: 'Earthquake',
                            compact: true,
                            iconData: Icons.broken_image_outlined,
                          ),
                          RiskBadge(
                            riskLevel: heatRisk,
                            label: 'Heatwave',
                            compact: true,
                            iconData: Icons.local_fire_department_outlined,
                          ),
                        ],
                      ),
                      if (widget.data?.floodAlert != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.water_drop,
                                size: 16,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.data!.floodAlert!.rainfall3dayMm.toStringAsFixed(1)} mm (3-day)',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
