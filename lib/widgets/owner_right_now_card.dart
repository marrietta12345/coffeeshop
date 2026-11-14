import 'package:flutter/material.dart';
import '../models/coffee_shop.dart';
import '../theme/app_colors.dart';
import '../utils/tambay_check_service.dart';

/// Owner Dashboard card: what customers at the café say right now (Tambay
/// Check) — how busy it is, free outlets and Wi-Fi.
class OwnerRightNowCard extends StatelessWidget {
  final CoffeeShop shop;

  const OwnerRightNowCard({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Right Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 12),
          ValueListenableBuilder<Map<String, TambaySummary>>(
            valueListenable: TambayCheckService.summaries,
            builder: (context, summaries, _) {
              final summary = summaries[shop.id];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.groups_2_rounded, size: 18, color: AppColors.primaryBrown),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary == null
                          ? 'No Tambay Checks from customers in the last 2 hours.'
                          : 'Customers say: ${summary.headline} · ${summary.agoAt(DateTime.now())}',
                      style: TextStyle(fontSize: 12.5, color: summary == null ? AppColors.textGrey : AppColors.textDark, height: 1.4),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
