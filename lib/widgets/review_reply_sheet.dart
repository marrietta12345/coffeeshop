import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/review.dart';
import '../utils/review_service.dart';
import 'top_banner.dart';

/// Saves the owner's response text somewhere other than a café review
/// (e.g. a coffee review).
typedef ReplySaver = Future<void> Function(String reply);

/// Opens the owner's "Respond" sheet for [review] (or "Edit Response" when
/// it already has one). Resolves to true once the response is saved.
/// Shared by the Dashboard's Recent Reviews and the owner Reviews page.
Future<bool> showReviewReplySheet(
  BuildContext context, {
  required String shopId,
  required Review review,
  ReplySaver? save, // defaults to a café review reply
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => ReviewReplySheet(shopId: shopId, review: review, save: save),
  );
  return saved == true;
}

class ReviewReplySheet extends StatefulWidget {
  final String shopId;
  final Review review;
  final ReplySaver? save;

  const ReviewReplySheet({super.key, required this.shopId, required this.review, this.save});

  @override
  State<ReviewReplySheet> createState() => _ReviewReplySheetState();
}

class _ReviewReplySheetState extends State<ReviewReplySheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.review.ownerReply ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final save = widget.save;
      if (save != null) {
        await save(text);
      } else {
        await ReviewService.replyToReview(
          shopId: widget.shopId,
          reviewId: widget.review.id,
          reply: text,
          firstReply: !widget.review.hasOwnerReply,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showTopBanner(context, "Couldn't save your response. Please try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Stays above the keyboard, and scrolls when the space is short.
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.review.hasOwnerReply ? 'Edit Response' : 'Respond to ${widget.review.userName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Thank your customer or address their feedback…',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textGrey),
              filled: true,
              fillColor: AppColors.inputFill,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving || _controller.text.trim().isEmpty ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBrown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Save Response', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
