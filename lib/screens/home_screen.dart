import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/city_alert.dart';
import '../providers/disaster_provider.dart';
import '../widgets/city_card.dart';
import '../widgets/risk_badge.dart';
import 'city_detail_screen.dart';
import 'advisor_chat_screen.dart';

// ── Filter enum ───────────────────────────────────────────────────────────────
enum _Filter { all, highestRisk, earthquakes, floods }

extension _FilterLabel on _Filter {
  String get label {
    switch (this) {
      case _Filter.all:        return 'All';
      case _Filter.highestRisk: return 'Highest Risk';
      case _Filter.earthquakes: return 'Earthquakes';
      case _Filter.floods:      return 'Floods';
    }
  }
  IconData get icon {
    switch (this) {
      case _Filter.all:         return Icons.public;
      case _Filter.highestRisk: return Icons.priority_high;
      case _Filter.earthquakes: return Icons.landslide;
      case _Filter.floods:      return Icons.water_drop;
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DisasterProvider>().fetchAllData();
    });
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _applyFilters(List<String> cities, DisasterProvider provider) {
    final filtered = cities.where((city) {
      if (_query.isNotEmpty && !city.toLowerCase().contains(_query)) return false;
      final data = provider.getCityData(city);
      switch (_filter) {
        case _Filter.all: return true;
        case _Filter.highestRisk:
          return data?.overallRisk == RiskLevel.high;
        case _Filter.earthquakes:
          final r = data?.earthquakeAlert?.riskLevel ?? RiskLevel.unknown;
          return r == RiskLevel.high || r == RiskLevel.medium;
        case _Filter.floods:
          final r = data?.floodAlert?.riskLevel ?? RiskLevel.unknown;
          return r == RiskLevel.high || r == RiskLevel.medium;
      }
    }).toList();

    filtered.sort((a, b) {
      final ra = provider.getCityData(a)?.overallRisk ?? RiskLevel.unknown;
      final rb = provider.getCityData(b)?.overallRisk ?? RiskLevel.unknown;
      return _riskOrder(ra).compareTo(_riskOrder(rb));
    });
    return filtered;
  }

  int _riskOrder(RiskLevel r) {
    switch (r) {
      case RiskLevel.high:    return 0;
      case RiskLevel.medium:  return 1;
      case RiskLevel.low:     return 2;
      case RiskLevel.unknown: return 3;
    }
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
            Icon(Icons.warning_amber_rounded, color: cs.primary),
            const SizedBox(width: 8),
            Text('Disaster Sense',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // ── AI Advisor button ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _AdvisorButton(cs: cs),
          ),
          Consumer<DisasterProvider>(
            builder: (_, provider, __) => provider.isLoading
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.primary),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: () =>
                        context.read<DisasterProvider>().fetchAllData(),
                  ),
          ),
        ],
      ),
      body: Consumer<DisasterProvider>(
        builder: (context, provider, _) {
          // ── First load ─────────────────────────────────────────────────────
          if (provider.isLoading && provider.cityData.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading disaster data…'),
                ],
              ),
            );
          }

          // ── Error (no cached data) ─────────────────────────────────────────
          if (provider.error != null && provider.cityData.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: cs.error),
                    const SizedBox(height: 16),
                    Text('Failed to load data',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(provider.error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => provider.fetchAllData(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // When searching, look through ALL cities; otherwise show only core cities
          final sourceList = _query.isNotEmpty
              ? provider.allCities
              : provider.cities;
          final filtered = _applyFilters(sourceList, provider);

          // ── Main layout: fixed header + scrollable list ────────────────────
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Search + filter (fixed, never scrolls away) ──────────────
              _SearchFilterBar(
                controller: _searchController,
                query: _query,
                filter: _filter,
                onFilterChanged: (f) => setState(() => _filter = f),
                onClear: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
              // ── Scrollable content ────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.fetchAllData(),
                  child: AnimationLimiter(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: AnimationConfiguration.toStaggeredList(
                        duration: const Duration(milliseconds: 500),
                        childAnimationBuilder: (widget) => SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: widget,
                          ),
                        ),
                        children: [
                          // ── Nearby cities section ──────────────────────────
                          if (provider.nearestCities.isNotEmpty)
                            _NearbyCitiesSection(provider: provider),

                          // Section header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'All Monitored Cities',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                if (provider.lastUpdated != null)
                                  Text(
                                    _fmt(provider.lastUpdated!),
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),

                          // Empty state or city cards
                          if (filtered.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 64),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.search_off,
                                        size: 64, color: cs.onSurfaceVariant),
                                    const SizedBox(height: 12),
                                    Text(
                                      _query.isNotEmpty
                                          ? 'No cities match "$_query"'
                                          : 'No cities match this filter',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...filtered.map((city) {
                              final data = provider.getCityData(city);
                              return CityCard(
                                cityName: city,
                                data: data,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CityDetailScreen(
                                      cityName: city,
                                      data: data,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          const SizedBox(height: 100), // Add padding for floating bottom nav
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(String ts) {
    try {
      final l = DateTime.parse(ts).toLocal();
      return '${l.day}/${l.month}/${l.year} '
          '${l.hour.toString().padLeft(2, '0')}:'
          '${l.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }
}

// ── Search + Filter bar (plain widget, no slivers) ────────────────────────────
class _SearchFilterBar extends StatelessWidget {
  const _SearchFilterBar({
    required this.controller,
    required this.query,
    required this.filter,
    required this.onFilterChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final _Filter filter;
  final ValueChanged<_Filter> onFilterChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Search city…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: onClear,
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          // Filter chips row
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _Filter.values.map((f) {
                final sel = f == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(f.icon,
                        size: 15,
                        color: sel ? cs.onPrimary : cs.onSurfaceVariant),
                    label:
                        Text(f.label, style: const TextStyle(fontSize: 12)),
                    selected: sel,
                    onSelected: (_) => onFilterChanged(f),
                    selectedColor: cs.primary,
                    labelStyle: TextStyle(
                      color: sel ? cs.onPrimary : cs.onSurface,
                      fontWeight:
                          sel ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: cs.surfaceContainerHighest,
                    side: BorderSide(
                        color: sel ? cs.primary : cs.outlineVariant),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 0),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: cs.outlineVariant),
        ],
      ),
    );
  }
}

// ── Nearby Cities Section ─────────────────────────────────────────────────────
class _NearbyCitiesSection extends StatelessWidget {
  const _NearbyCitiesSection({required this.provider});
  final DisasterProvider provider;

  String _formatDistance(double km) {
    if (km < 15) return 'Current Area';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final nearby = provider.nearestCities;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.near_me, size: 18, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nearest Cities',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (provider.currentCity != null)
                      Text(
                        'Based on your location${provider.currentCity != null ? " near ${provider.currentCity}" : ""}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.my_location, size: 16, color: cs.primary),
            ],
          ),
          const SizedBox(height: 10),
          // City tiles
          ...List.generate(nearby.length, (i) {
            final nc = nearby[i];
            final cityData = provider.getCityData(nc.name);
            final risk = cityData?.overallRisk ?? RiskLevel.unknown;
            final isFirst = i == 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: isFirst
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: cityData == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CityDetailScreen(
                                cityName: nc.name,
                                data: cityData,
                              ),
                            ),
                          ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // Rank circle
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFirst
                                ? cs.primary
                                : cs.onSurfaceVariant.withValues(alpha: 0.15),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isFirst
                                  ? cs.onPrimary
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // City info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    nc.name,
                                    style:
                                        theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isFirst
                                          ? cs.onPrimaryContainer
                                          : cs.onSurface,
                                    ),
                                  ),
                                  if (isFirst) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color:
                                            cs.primary.withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        nc.distanceKm < 15.0 ? 'IN CITY' : 'CLOSEST',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isFirst
                                              ? cs.onPrimaryContainer
                                              : cs.primary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.straighten,
                                      size: 12,
                                      color: isFirst
                                          ? cs.onPrimaryContainer
                                              .withValues(alpha: 0.65)
                                          : cs.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDistance(nc.distanceKm),
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: isFirst
                                          ? cs.onPrimaryContainer
                                              .withValues(alpha: 0.75)
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Risk badge
                        if (cityData != null)
                          RiskBadge(
                            riskLevel: risk,
                            label: 'Risk',
                            compact: true,
                          ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 18,
                            color: isFirst
                                ? cs.onPrimaryContainer
                                : cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── AI Advisor AppBar button ───────────────────────────────────────────────────

class _AdvisorButton extends StatefulWidget {
  final ColorScheme cs;
  const _AdvisorButton({required this.cs});

  @override
  State<_AdvisorButton> createState() => _AdvisorButtonState();
}

class _AdvisorButtonState extends State<_AdvisorButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: Tooltip(
        message: 'AI Disaster Advisor',
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, a, __) {
                final provider = context.read<DisasterProvider>();
                final city = provider.currentCity ??
                    (provider.nearestCities.isNotEmpty
                        ? provider.nearestCities.first.name
                        : null);
                return AdvisorChatScreen(initialCity: city);
              },
              transitionsBuilder: (_, anim, __, child) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 320),
            ),
          ),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.secondary.withValues(alpha: 0.6),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
