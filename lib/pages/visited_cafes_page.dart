import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../utils/distance_utils.dart';
import '../utils/location_service.dart';
import '../utils/page_transitions.dart';
import '../utils/shop_lookup.dart';
import '../utils/visited_shops_service.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/top_banner.dart';
import 'shop_detail_page.dart';

/// The user's permanent record of every café they've visited, topped by:
///  * total cafés discovered (never goes down, even if a café is removed
///    from the history list),
///  * Daily Discovery — discover 1 new café today, resetting at midnight,
///    with the nearest not-yet-visited café as a suggestion,
///  * the current exploration streak (consecutive days with a new café).
/// Everything updates live: visiting a café (opening its details) records
/// it — see ShopDetailPage.
class VisitedCafesPage extends StatefulWidget {
  const VisitedCafesPage({super.key});

  @override
  State<VisitedCafesPage> createState() => _VisitedCafesPageState();
}

class _VisitedCafesPageState extends State<VisitedCafesPage> {
  final Stream<CafeJourney> _journeyStream = VisitedShopsService.journeyStream();
  late final Future<List<CoffeeShop>> _shopsFuture = fetchAllShops();
  late final Future<LocationResult> _locationFuture = getCurrentLocation();
  Timer? _clock; // keeps the "new goal in" countdown fresh

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _openShop(CoffeeShop shop) => Navigator.push(context, slideUpRoute(ShopDetailPage(shop: shop)));

  Future<void> _remove(CoffeeShop shop) async {
    try {
      await VisitedShopsService.removeVisit(shop.id);
      if (mounted) {
        showTopBanner(
          context,
          'Removed ${shop.name} from your history. It still counts as discovered!',
          isSuccess: true,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (_) {
      if (mounted) showTopBanner(context, "Couldn't remove café. Please try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Visited Cafés',
      child: StreamBuilder<CafeJourney>(
        stream: _journeyStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Visited Cafés: could not load history: ${snapshot.error}');
            return const SettingsEmptyState(
              icon: Icons.cloud_off_rounded,
              title: "Couldn't load your visited cafés",
              subtitle: 'Check your connection and try again.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown));
          }
          final journey = snapshot.data!;
          final visited = journey.history;

          return FutureBuilder<List<CoffeeShop>>(
            future: _shopsFuture,
            builder: (context, shopsSnapshot) {
              final shops = shopsSnapshot.data;

              return ListView(
                children: [
                  _DiscoveredCard(journey: journey, totalCafes: shops?.length),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _DailyDiscoveryTile(journey: journey)),
                        const SizedBox(width: 12),
                        Expanded(child: _StreakTile(journey: journey)),
                      ],
                    ),
                  ),
                  if (!journey.dailyGoalReached && shops != null)
                    _TodaysPick(
                      undiscovered: shops.where((s) => !journey.discoveredIds.contains(s.id)).toList(),
                      locationFuture: _locationFuture,
                      onOpen: _openShop,
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text('History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      const SizedBox(width: 8),
                      if (visited.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBrown.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${visited.length}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryBrown),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (visited.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: SettingsEmptyState(
                        icon: Icons.history_rounded,
                        title: 'No visited cafés yet',
                        subtitle: 'Tap "View Details" on any café and it will show up here.',
                      ),
                    )
                  else
                    for (final visit in visited) ...[
                      ResolvedShopRow(
                        key: ValueKey(visit.shopId),
                        shopId: visit.shopId,
                        detailBuilder: (shop) => _visitLabel(visit, shop),
                        onTap: _openShop,
                        trailingBuilder: (shop) => IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.textGrey),
                          tooltip: 'Remove from history',
                          onPressed: () => _remove(shop),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// e.g. "★ 4.8 • Visited today • 3 visits".
  String _visitLabel(VisitedShop visit, CoffeeShop shop) {
    final rating = shop.rating > 0 ? '★ ${shop.rating.toStringAsFixed(1)}' : '';
    final when = visit.visitedAt == null ? '' : 'Visited ${_relativeDate(visit.visitedAt!)}';
    final count = visit.visitCount > 1 ? '${visit.visitCount} visits' : '';
    return [rating, when, count].where((s) => s.isNotEmpty).join(' • ');
  }

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final daysAgo = today.difference(day).inDays;
    if (daysAgo <= 0) return 'today';
    if (daysAgo == 1) return 'yesterday';
    if (daysAgo < 7) return '$daysAgo days ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final sameYear = date.year == now.year;
    return 'on ${months[date.month - 1]} ${date.day}${sameYear ? '' : ', ${date.year}'}';
  }
}

/// Coffee-gradient hero card: total cafés discovered (permanent), total
/// visits, and how much of Kafelo's café list the user has explored.
class _DiscoveredCard extends StatelessWidget {
  final CafeJourney journey;
  final int? totalCafes; // null while loading

  const _DiscoveredCard({required this.journey, required this.totalCafes});

  @override
  Widget build(BuildContext context) {
    final count = journey.cafesDiscovered;
    final total = totalCafes;
    final explored = total == null ? 0 : count.clamp(0, total);
    final progress = (total == null || total == 0) ? 0.0 : explored / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryBrown, Color(0xFF5C3D2A)],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primaryBrown.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$count', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1)),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    count == 1 ? 'café discovered' : 'cafés discovered',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Icon(Icons.local_cafe_rounded, color: Colors.white54, size: 30),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniStat(icon: Icons.repeat_rounded, text: '${journey.totalVisits} ${journey.totalVisits == 1 ? 'visit' : 'visits'}'),
              const SizedBox(width: 8),
              _MiniStat(
                icon: Icons.explore_rounded,
                text: total == null ? 'Explored –' : '${(progress * 100).round()}% explored',
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            total == null ? 'Counting cafés…' : "You've discovered $explored of $total cafés on Kafelo",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniStat({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Today's goal — discover 1 new café — as a progress ring, with a
/// countdown to the midnight reset.
class _DailyDiscoveryTile extends StatelessWidget {
  final CafeJourney journey;

  const _DailyDiscoveryTile({required this.journey});

  static const _cream = Color(0xFFFFF7EE);
  static const _green = Color(0xFF2E7D32);

  String get _resetsIn {
    final now = DateTime.now();
    final left = DateTime(now.year, now.month, now.day + 1).difference(now);
    final h = left.inHours;
    final m = left.inMinutes % 60;
    return h > 0 ? 'New goal in ${h}h ${m}m' : 'New goal in ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final done = journey.dailyGoalReached;

    return _Tile(
      background: _cream,
      borderColor: AppColors.primaryBrown.withOpacity(0.18),
      top: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: done ? 1 : 0,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.primaryBrown.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryBrown),
            ),
            Center(
              child: done
                  ? const Icon(Icons.check_rounded, color: AppColors.primaryBrown, size: 22)
                  : const Text('0/1', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppColors.textDark)),
            ),
          ],
        ),
      ),
      title: 'Daily Discovery',
      body: done ? 'Done for today! 🎉' : 'Discover 1 new café today',
      footer: _resetsIn,
      footerColor: done ? _green : AppColors.textGrey,
    );
  }
}

/// Consecutive days with a new café, with a nudge when today's
/// discovery is still needed to keep it going.
class _StreakTile extends StatelessWidget {
  final CafeJourney journey;

  const _StreakTile({required this.journey});

  static const _flame = Color(0xFFFF7A2F);

  @override
  Widget build(BuildContext context) {
    final streak = journey.currentStreak;
    final String footer;
    if (journey.streakAtRisk) {
      footer = 'Visit a new café today to keep it!';
    } else if (streak == 0) {
      footer = 'Visit a new café to start one';
    } else {
      footer = "You're on fire ☕";
    }

    return _Tile(
      background: AppColors.inputFill,
      top: Icon(Icons.local_fire_department_rounded, size: 40, color: streak > 0 ? _flame : AppColors.textGrey),
      title: streak == 1 ? '1-day streak' : '$streak-day streak',
      body: 'New café every day',
      footer: footer,
      footerColor: journey.streakAtRisk ? _flame : AppColors.textGrey,
    );
  }
}

class _Tile extends StatelessWidget {
  final Color background;
  final Color? borderColor;
  final Widget top;
  final String title;
  final String body;
  final String footer;
  final Color footerColor;

  const _Tile({
    required this.background,
    this.borderColor,
    required this.top,
    required this.title,
    required this.body,
    required this.footer,
    required this.footerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          top,
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textDark)),
          const SizedBox(height: 2),
          Text(body, style: const TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.3)),
          const SizedBox(height: 6),
          Text(footer, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: footerColor, height: 1.3)),
        ],
      ),
    );
  }
}

/// One suggestion for today's discovery: the nearest café the user
/// hasn't visited yet (or the top-rated one without location).
class _TodaysPick extends StatelessWidget {
  final List<CoffeeShop> undiscovered;
  final Future<LocationResult> locationFuture;
  final ValueChanged<CoffeeShop> onOpen;

  const _TodaysPick({required this.undiscovered, required this.locationFuture, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (undiscovered.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<LocationResult>(
      future: locationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
        final here = snapshot.data?.position;

        final CoffeeShop pick;
        final String detail;
        if (here != null) {
          const calculator = Distance();
          double meters(CoffeeShop s) => calculator.as(LengthUnit.Meter, here, LatLng(s.latitude, s.longitude));
          pick = undiscovered.reduce((a, b) => meters(a) <= meters(b) ? a : b);
          detail = '${formatDistance(here, LatLng(pick.latitude, pick.longitude))} away • ★ ${pick.rating.toStringAsFixed(1)}';
        } else {
          pick = undiscovered.reduce((a, b) => a.rating >= b.rating ? a : b);
          detail = '★ ${pick.rating.toStringAsFixed(1)} • Top rated';
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primaryBrown),
                  SizedBox(width: 6),
                  Text("Today's pick", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                ],
              ),
              const SizedBox(height: 8),
              ShopListRow(shop: pick, detail: detail, onTap: () => onOpen(pick)),
            ],
          ),
        );
      },
    );
  }
}
