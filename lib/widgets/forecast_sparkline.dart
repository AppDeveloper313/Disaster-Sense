import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/weather_data.dart';

/// A sparkline that plots the 7-day temperature forecast using [fl_chart].
/// Precipitation is shown in the interactive tooltip.
class ForecastSparkline extends StatelessWidget {
  final List<DailyForecast> forecast;
  final double height;
  final String label;

  const ForecastSparkline({
    super.key,
    required this.forecast,
    required this.label,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (forecast.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Forecast not available',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    // Prepare data points for max temperature
    final spots = forecast.asMap().entries.map((e) {
      final index = e.key.toDouble();
      final temp = e.value.tempMaxC ?? 0.0;
      return FlSpot(index, temp);
    }).toList();

    // Find min and max for Y-axis scaling
    final temps = forecast.map((f) => f.tempMaxC ?? 0.0).toList();
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    
    // Add some padding to the Y axis
    final minY = (minTemp - 2).floorToDouble();
    final maxY = (maxTemp + 2).ceilToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                Icon(Icons.touch_app, size: 14, color: cs.primary),
                const SizedBox(width: 4),
                Text('Tap to view', style: theme.textTheme.labelSmall?.copyWith(color: cs.primary)),
              ],
            )
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 5,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                // Y-axis (Temperature)
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 5,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}°',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                // X-axis (Days of week)
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= forecast.length) return const SizedBox();
                      
                      try {
                        final dt = DateTime.parse(forecast[index].date);
                        final dayStr = DateFormat('E').format(dt);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            dayStr,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      } catch (_) {
                        return const SizedBox();
                      }
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (forecast.length - 1).toDouble(),
              minY: minY,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: cs.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: cs.surface,
                        strokeWidth: 2,
                        strokeColor: cs.primary,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: cs.primary.withValues(alpha: 0.15),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => cs.surfaceContainerHighest,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      final f = forecast[index];
                      final precip = f.precipitationMm ?? 0.0;
                      
                      return LineTooltipItem(
                        '${f.conditionIcon} ${f.condition}\n',
                        TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: 'High: ${f.tempMaxC}°C\n',
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          TextSpan(
                            text: 'Rain: ${precip.toStringAsFixed(1)} mm',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
