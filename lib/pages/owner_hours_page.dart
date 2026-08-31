import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../widgets/top_banner.dart';

/// Edit the shop's opening/closing hours using native time pickers.
class OwnerHoursPage extends StatefulWidget {
  final CoffeeShop shop;

  const OwnerHoursPage({super.key, required this.shop});

  @override
  State<OwnerHoursPage> createState() => _OwnerHoursPageState();
}

class _OwnerHoursPageState extends State<OwnerHoursPage> {
  late String _openTime;
  late String _closeTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _openTime = widget.shop.openTime;
    _closeTime = widget.shop.closeTime;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return minute == '00' ? '$hour $period' : '$hour:$minute $period';
  }

  Future<void> _pickTime({required bool isOpenTime}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryBrown)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isOpenTime) {
        _openTime = _formatTime(picked);
      } else {
        _closeTime = _formatTime(picked);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('shops').doc(widget.shop.id).set({
        'openTime': _openTime,
        'closeTime': _closeTime,
      }, SetOptions(merge: true));
      if (!mounted) return;
      showTopBanner(context, 'Hours updated!', isSuccess: true);
      Navigator.pop(context);
    } catch (e) {
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TimeRow(label: 'Opens at', value: _openTime, onTap: () => _pickTime(isOpenTime: true)),
                    const SizedBox(height: 14),
                    _TimeRow(label: 'Closes at', value: _closeTime, onTap: () => _pickTime(isOpenTime: false)),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBrown,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeRow({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: AppColors.primaryBrown, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark))),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryBrown)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey),
          ],
        ),
      ),
    );
  }
}