import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/coffee_shop.dart';
import '../theme/app_colors.dart';
import '../utils/distance_utils.dart';
import '../utils/location_service.dart';
import '../utils/tambay_check_service.dart';
import 'top_banner.dart';

/// A small pill over a café card's photo with how busy people there say
/// it is (🟢 Chill).
class TambayCardBadges extends StatelessWidget {
  final String shopId;

  const TambayCardBadges({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, TambaySummary>>(
      valueListenable: TambayCheckService.summaries,
      builder: (context, summaries, _) {
        final busy = summaries[shopId]?.busy;
        if (busy == null) return const SizedBox.shrink();
        return Stack(
          children: [
            Positioned(right: 6, bottom: 6, child: _Pill(text: '${busy.emoji} ${busy.label}', color: Colors.black87)),
          ],
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

/// "Tambay Check" on a café page: how busy it is right now, free outlets
/// and Wi-Fi — from people who are there — plus an "I'm here" button.
class TambayCheckCard extends StatelessWidget {
  final CoffeeShop shop;
  final bool canCheckIn; // false for the café's own owner

  const TambayCheckCard({super.key, required this.shop, this.canCheckIn = true});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, TambaySummary>>(
      valueListenable: TambayCheckService.summaries,
      builder: (context, summaries, _) {
        final summary = summaries[shop.id];
        final now = DateTime.now();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEDEAE6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.groups_2_rounded, size: 18, color: AppColors.primaryBrown),
                  SizedBox(width: 6),
                  Text('Tambay Check', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  SizedBox(width: 6),
                  Text('· right now', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                ],
              ),
              const SizedBox(height: 10),
              if (summary != null) ...[
                Text(summary.headline, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 3),
                Text(
                  '${summary.count == 1 ? '1 person' : '${summary.count} people'} here · updated ${summary.agoAt(now)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                ),
              ] else
                const Text(
                  'No one has checked in during the last 2 hours.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textGrey),
                ),
              if (canCheckIn) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => startTambayCheckIn(context, shop),
                    icon: const Icon(Icons.where_to_vote_rounded, size: 18),
                    label: const Text("I'm here — share how it is"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBrown,
                      side: const BorderSide(color: AppColors.primaryBrown),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Checks the person is at the café (within 150 m), then asks how it is.
Future<void> startTambayCheckIn(BuildContext context, CoffeeShop shop) async {
  if (FirebaseAuth.instance.currentUser == null) {
    showTopBanner(context, 'Sign in to share a Tambay Check.', isSuccess: false);
    return;
  }
  if (!shop.hasLocation) {
    showTopBanner(context, "This café's location isn't set yet.", isSuccess: false);
    return;
  }
  showTopBanner(context, 'Checking that you’re at the café…', isSuccess: true);
  final result = await getCurrentLocation();
  if (!context.mounted) return;
  if (!result.isSuccess) {
    showTopBanner(context, result.errorMessage!, isSuccess: false);
    return;
  }
  final cafe = LatLng(shop.latitude, shop.longitude);
  final meters = const Distance().as(LengthUnit.Meter, result.position!, cafe);
  if (meters > TambayCheckService.maxDistanceMeters) {
    final away = formatDistance(result.position!, cafe);
    showTopBanner(context, "You need to be at the café to check in — you're $away.", isSuccess: false);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CheckInSheet(shop: shop),
  );
}

class _CheckInSheet extends StatefulWidget {
  final CoffeeShop shop;

  const _CheckInSheet({required this.shop});

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  TambayBusy? _busy;
  bool? _outlets;
  String? _wifi;
  bool _saving = false;

  Future<void> _submit() async {
    final busy = _busy;
    if (busy == null) return;
    setState(() => _saving = true);
    try {
      await TambayCheckService.checkIn(shopId: widget.shop.id, busy: busy, outlets: _outlets, wifi: _wifi);
      if (!mounted) return;
      Navigator.pop(context);
      showTopBanner(context, 'Thanks! Your Tambay Check is live for 2 hours.', isSuccess: true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTopBanner(
        context,
        e.code == 'permission-denied'
            ? 'Only Coffee Explorer accounts can check in to cafés.'
            : "Couldn't save your Tambay Check. Please try again.",
        isSuccess: false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTopBanner(context, "Couldn't save your Tambay Check. Please try again.", isSuccess: false);
    }
  }

  Widget _group<T>(String title, List<(T, String)> options, T? selected, ValueChanged<T?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in options)
              ChoiceChip(
                label: Text(label),
                selected: selected == value,
                onSelected: (on) => onChanged(on ? value : null),
                selectedColor: AppColors.primaryBrown.withValues(alpha: 0.18),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: selected == value ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textDark,
                ),
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text('How is ${widget.shop.name} right now?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 4),
            const Text('Helps others decide where to tambay. Shown for 2 hours.',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
            const SizedBox(height: 16),
            _group<TambayBusy>(
              'How busy is it?',
              [for (final b in TambayBusy.values) (b, '${b.emoji} ${b.label}')],
              _busy,
              (v) => setState(() => _busy = v),
            ),
            _group<bool>('Free outlets?', const [(true, '🔌 Yes'), (false, 'None free')], _outlets,
                (v) => setState(() => _outlets = v)),
            _group<String>('Wi-Fi?', [for (final e in tambayWifiLabels.entries) (e.key, e.value.replaceAll(' Wi-Fi', ''))],
                _wifi, (v) => setState(() => _wifi = v)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy == null || _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_busy == null ? 'Pick how busy it is' : 'Share Tambay Check',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
