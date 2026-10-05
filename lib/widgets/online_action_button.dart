import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/online_links.dart';

/// The café page's single "Online" action button — same look as the
/// Call / Directions / Share buttons. It adapts to what the owner added:
///  * nothing → not shown at all;
///  * one link → shows that platform (🌐 Website, 📘 Facebook, ...) and
///    opens it directly;
///  * several → shows "Online" and opens a small menu listing only the
///    platforms the café actually has.
class OnlineActionButton extends StatelessWidget {
  final List<OnlineLink> links;
  final ValueChanged<OnlineLink> onOpen;

  const OnlineActionButton({super.key, required this.links, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    final single = links.length == 1 ? links.single : null;

    return InkWell(
      onTap: () => single != null ? onOpen(single) : _showMenu(context),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.inputFill),
            child: Icon(single?.platform.icon ?? Icons.language_rounded, size: 20, color: AppColors.primaryBrown),
          ),
          const SizedBox(height: 5),
          Text(
            single?.platform.label ?? 'Online',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          // Scrolls on short (landscape) screens.
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Find us online', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 6),
              for (final link in links)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.inputFill),
                    child: Icon(link.platform.icon, size: 20, color: AppColors.primaryBrown),
                  ),
                  title: Text(
                    '${link.platform.emoji} ${link.platform.label}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.textGrey),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onOpen(link);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
