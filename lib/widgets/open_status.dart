import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/operating_hours.dart';

/// Colour for each open state — green open, red closed, orange
/// temporarily closed, grey when hours aren't set.
Color openStateColor(OpenState state) => switch (state) {
      OpenState.open => const Color(0xFF2E7D32),
      OpenState.closed => const Color(0xFFC62828),
      OpenState.temporarilyClosed => const Color(0xFFE65100),
      OpenState.unavailable => AppColors.textGrey,
    };

/// Rebuilds [builder] with a fresh status every 30 seconds, so "Open
/// Now" flips to "Closed Now" on its own as time passes.
class _LiveStatus extends StatefulWidget {
  final OperatingHours hours;
  final Widget Function(OpenStatus status) builder;

  const _LiveStatus({required this.hours, required this.builder});

  @override
  State<_LiveStatus> createState() => _LiveStatusState();
}

class _LiveStatusState extends State<_LiveStatus> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(widget.hours.statusAt(DateTime.now()));
}

/// "● Open Now · Closes at 9:00 PM" — the café page / list version.
class OpenStatusLine extends StatelessWidget {
  final OperatingHours hours;
  final double fontSize;

  const OpenStatusLine({super.key, required this.hours, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return _LiveStatus(
      hours: hours,
      builder: (status) {
        final color = openStateColor(status.state);
        return Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: status.headline,
                      style: TextStyle(fontWeight: FontWeight.w700, color: color),
                    ),
                    if (status.detail != null)
                      TextSpan(
                        text: ' · ${status.detail}',
                        style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textGrey),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSize),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Small "● Open Now" pill — white for café photos, or [tinted] in the
/// status colour for white cards.
class OpenStatusBadge extends StatelessWidget {
  final OperatingHours hours;
  final bool tinted;

  const OpenStatusBadge({super.key, required this.hours, this.tinted = false});

  @override
  Widget build(BuildContext context) {
    return _LiveStatus(
      hours: hours,
      builder: (status) {
        final color = openStateColor(status.state);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: tinted ? color.withOpacity(0.1) : Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(
                status.headline,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        );
      },
    );
  }
}
