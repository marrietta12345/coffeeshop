import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/operating_hours.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/open_status.dart';
import '../widgets/schedule_editor.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/top_banner.dart';

/// Owner's operating schedule: hours for each day of the week, plus an
/// optional "Temporarily closed" status. Customers' Open Now / Closed Now
/// is worked out from this automatically — there's no manual switch.
class OwnerHoursPage extends StatefulWidget {
  final CoffeeShop shop;

  const OwnerHoursPage({super.key, required this.shop});

  @override
  State<OwnerHoursPage> createState() => _OwnerHoursPageState();
}

class _OwnerHoursPageState extends State<OwnerHoursPage> {
  late OperatingHours _hours = widget.shop.hours;
  late final TextEditingController _noteController = TextEditingController(text: widget.shop.hours.closureNote ?? '');
  bool _isSaving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final note = _noteController.text.trim();
    try {
      // update() replaces the whole schedule, so days switched off are removed.
      await FirebaseFirestore.instance.collection('shops').doc(widget.shop.id).update({
        'operatingHours': _hours.toFirestoreMap(),
        'temporarilyClosed': _hours.temporarilyClosed,
        'closureNote': _hours.temporarilyClosed && note.isNotEmpty ? note : null,
      });
      if (!mounted) return;
      showTopBanner(context, 'Hours updated!', isSuccess: true);
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Saving hours failed: $e');
      if (!mounted) return;
      showTopBanner(context, "Couldn't save changes. Please try again.", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 4),
                  const Text('Business Hours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  // What customers will see right now (live preview).
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBrown.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Customers see', style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
                        const SizedBox(height: 4),
                        OpenStatusLine(hours: _hours.copyWith(closureNote: _noteController.text.trim()), fontSize: 13),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const AuthSectionLabel('Operating Days & Hours'),
                  const SizedBox(height: 4),
                  const Text(
                    'Switch on the days you\'re open and set the hours (Philippine time).',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 16),
                  ScheduleEditor(value: _hours, onChanged: (h) => setState(() => _hours = h)),
                  const SizedBox(height: 28),
                  const AuthSectionLabel('Temporary Closure'),
                  const SizedBox(height: 16),
                  SettingsSwitchTile(
                    icon: Icons.pause_circle_outline_rounded,
                    title: 'Temporarily closed',
                    subtitle: 'Shows "Temporarily Closed" to customers instead of your hours until you turn this off.',
                    value: _hours.temporarilyClosed,
                    onChanged: (v) => setState(() => _hours = _hours.copyWith(temporarilyClosed: v)),
                  ),
                  if (_hours.temporarilyClosed) ...[
                    const SizedBox(height: 4),
                    AuthTextField(
                      label: 'Note for customers',
                      controller: _noteController,
                      hint: 'Optional — e.g. Closed for renovation until Oct 20',
                    ),
                  ],
                  const SizedBox(height: 28),
                  AuthSubmitButton(label: 'Save Changes', isLoading: _isSaving, onPressed: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
