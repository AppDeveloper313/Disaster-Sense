import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alert_log_entry.dart';
import '../models/city_alert.dart';
import '../providers/disaster_provider.dart';

class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DisasterProvider>().loadAlertLog();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Icon(Icons.history, color: cs.primary),
            const SizedBox(width: 8),
            Text('Alert History',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                context.read<DisasterProvider>().refreshAlertLog(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear history',
            onPressed: () => _confirmClear(context),
          ),
        ],
      ),
      body: Consumer<DisasterProvider>(
        builder: (context, provider, _) {
          final log = provider.alertLog;

          if (log.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 72, color: cs.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No alerts logged yet',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(
                    'Alerts will appear here after your first data fetch.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Group by date
          final grouped = <String, List<AlertLogEntry>>{};
          for (final entry in log) {
            final key = _dateKey(entry.timestamp);
            grouped.putIfAbsent(key, () => []).add(entry);
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: grouped.entries.map((group) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Date header ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Text(
                      group.key,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // ── Entries ─────────────────────────────────────────────
                  ...group.value.map((e) => _AlertLogTile(entry: e)),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  String _dateKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(dt.year, dt.month, dt.day);

    if (entryDay == today) return 'Today';
    if (entryDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${dt.day} ${_month(dt.month)} ${dt.year}';
  }

  String _month(int m) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m];
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear alert history?'),
        content: const Text(
            'This will permanently delete all logged alerts. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<DisasterProvider>().clearAlertLog();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

// ── Individual log tile ───────────────────────────────────────────────────────
class _AlertLogTile extends StatelessWidget {
  const _AlertLogTile({required this.entry});
  final AlertLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final (bgColor, fgColor, icon) = _style(entry.riskLevel, entry.type, isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: fgColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: fgColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.city,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: fgColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TypeChip(type: entry.type, color: fgColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.message,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Time
              const SizedBox(width: 8),
              Text(
                _timeStr(entry.timestamp),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, Color, IconData) _style(
      RiskLevel level, String type, bool isDark) {
    final typeIcon = type == 'flood'
        ? Icons.water_drop
        : type == 'earthquake'
            ? Icons.landslide
            : Icons.warning_amber_rounded;

    switch (level) {
      case RiskLevel.high:
        return isDark
            ? (const Color(0xFF4A1010), const Color(0xFFFF8A80), typeIcon)
            : (const Color(0xFFFFEBEE), const Color(0xFFB71C1C), typeIcon);
      case RiskLevel.medium:
        return isDark
            ? (const Color(0xFF3A2E00), const Color(0xFFFFD54F), typeIcon)
            : (const Color(0xFFFFF8E1), const Color(0xFF7A5900), typeIcon);
      case RiskLevel.low:
        return isDark
            ? (const Color(0xFF1B3A2B), const Color(0xFF6EE8A2), typeIcon)
            : (const Color(0xFFDCF5E7), const Color(0xFF1B6B3A), typeIcon);
      case RiskLevel.unknown:
        return (Colors.transparent, Colors.grey, typeIcon);
    }
  }

  String _timeStr(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type, required this.color});
  final String type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type[0].toUpperCase() + type.substring(1),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
