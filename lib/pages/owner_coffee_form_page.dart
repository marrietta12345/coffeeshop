import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;
import '../widgets/fitted_image.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import '../utils/form_validators.dart';
import '../utils/menu_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/category_chip.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/top_banner.dart';

/// Full-screen form to add a coffee to the owner's menu, or edit one
/// ([existing]). Pops with true once saved. [menu] is the current menu,
/// used to block a second coffee with the same name. Leaving with unsaved
/// changes asks before discarding them.
class OwnerCoffeeFormPage extends StatefulWidget {
  final CoffeeShop shop;
  final MenuItem? existing;
  final List<MenuItem> menu;

  const OwnerCoffeeFormPage({super.key, required this.shop, this.existing, this.menu = const []});

  @override
  State<OwnerCoffeeFormPage> createState() => _OwnerCoffeeFormPageState();
}

class _OwnerCoffeeFormPageState extends State<OwnerCoffeeFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.existing?.description ?? '');
  late final TextEditingController _price = TextEditingController(
    text: widget.existing == null ? '' : _priceText(widget.existing!.price),
  );
  late String? _category = widget.existing?.category;
  late bool _available = widget.existing?.available ?? true;
  late bool _bestSeller = widget.existing?.bestSeller ?? false;
  late bool _featured = widget.existing?.featured ?? false;
  File? _newImage;
  bool _removeImage = false;
  bool _isSaving = false;
  bool _saved = false; // lets the page close after a successful save
  late final String _initialSnapshot;

  /// Everything the owner can change, to tell whether anything did.
  String _snapshot() => [
        _name.text.trim(),
        _description.text.trim(),
        _price.text.trim(),
        _category,
        _available,
        _bestSeller,
        _featured,
        _newImage?.path,
        _removeImage,
      ].join('|');

  bool get _hasChanges => _snapshot() != _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _initialSnapshot = _snapshot(); // the starting values
  }

  /// "Discard changes?" — true when the owner chooses to leave.
  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard changes?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        content: Text(
          _isEditing ? "Your changes to this coffee won't be saved." : "This coffee won't be added to your menu.",
          style: const TextStyle(fontSize: 13.5, color: AppColors.textGrey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing', style: TextStyle(color: AppColors.primaryBrown, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: Color(0xFFD64545), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return discard == true;
  }

  bool get _isEditing => widget.existing != null;

  String? get _currentImageUrl => _removeImage ? null : widget.existing?.imageUrl;

  static String _priceText(double price) =>
      price == price.roundToDouble() ? price.toStringAsFixed(0) : price.toStringAsFixed(2);

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      // Good quality, sensible file size; the preview shows the exact menu framing.
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
      if (picked == null || !mounted) return;
      final file = File(picked.path);
      final use = await confirmPhoto(context, image: FileImage(file), aspectRatio: ImageRatios.coffee, title: 'Use this coffee photo?', fit: BoxFit.cover);
      if (!use || !mounted) return;
      setState(() {
        _newImage = file;
        _removeImage = false;
      });
    } catch (e) {
      debugPrint('Picking coffee photo failed: $e');
      if (mounted) showTopBanner(context, "Couldn't open your photos. Please try again.", isSuccess: false);
    }
  }

  void _clearImage() => setState(() {
        _newImage = null;
        _removeImage = true;
      });

  String? _validateName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return FormValidators.requiredMessage;
    if (name.length > 60) return 'Keep the name under 60 characters.';
    final taken = widget.menu.any(
      (i) => i.id != widget.existing?.id && i.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (taken) return 'This coffee is already on your menu.';
    return null;
  }

  Future<void> _save() async {
    if (_isSaving) return; // no double submits → no duplicate coffees
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      await MenuService.saveItem(
        shopId: widget.shop.id,
        itemId: widget.existing?.id,
        name: _name.text,
        description: _description.text,
        price: FormValidators.parsePrice(_price.text),
        category: _category!,
        available: _available,
        bestSeller: _bestSeller,
        featured: _featured,
        currentImageUrl: widget.existing?.imageUrl,
        newImage: _newImage,
        removeImage: _removeImage,
      );
      if (!mounted) return;
      setState(() => _saved = true);
      Navigator.pop(context, true);
    } on StorageException catch (e) {
      debugPrint('Coffee photo upload failed: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      showTopBanner(context, "Couldn't upload the photo. Try again, or save without a photo.", isSuccess: false);
    } catch (e) {
      debugPrint('Saving coffee failed: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      showTopBanner(context, "Couldn't save this coffee. Please check your connection and try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _saved || !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          setState(() => _saved = true); // allow this pop
          Navigator.pop(context);
        }
      },
      child: _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textDark), onPressed: () => Navigator.maybePop(context)),
                  const SizedBox(width: 4),
                  Text(
                    _isEditing ? 'Edit Coffee' : 'Add Coffee',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                onChanged: () => setState(() {}), // keeps "unsaved changes" up to date
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    _PhotoPicker(
                      newImage: _newImage,
                      currentUrl: _currentImageUrl,
                      onPick: _pickImage,
                      onRemove: _clearImage,
                    ),
                    const SizedBox(height: 20),
                    AuthTextField(
                      label: 'Coffee Name',
                      isRequired: true,
                      controller: _name,
                      hint: 'e.g. Iced Spanish Latte',
                      validator: _validateName,
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      label: 'Description',
                      controller: _description,
                      hint: 'Optional — e.g. Creamy espresso with condensed milk',
                      maxLines: 3,
                      maxLength: 300,
                    ),
                    const SizedBox(height: 8),
                    AuthTextField(
                      label: 'Price (₱)',
                      isRequired: true,
                      controller: _price,
                      hint: 'e.g. 120',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      validator: FormValidators.price,
                    ),
                    const SizedBox(height: 20),
                    FormField<String>(
                      initialValue: _category,
                      validator: (_) => _category == null ? FormValidators.requiredMessage : null,
                      builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Coffee Category'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final category in CoffeeCategory.all)
                                CategoryChip(
                                  label: category,
                                  icon: Icons.local_cafe_rounded,
                                  selected: _category == category,
                                  onTap: () {
                                    setState(() => _category = category);
                                    field.didChange(category);
                                  },
                                ),
                            ],
                          ),
                          if (field.hasError) ...[
                            const SizedBox(height: 8),
                            Text(field.errorText!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _FieldLabel('Availability'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _AvailabilityOption(
                            label: 'Available',
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF2E9E5B),
                            selected: _available,
                            onTap: () => setState(() => _available = true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AvailabilityOption(
                            label: 'Unavailable',
                            icon: Icons.do_not_disturb_on_rounded,
                            color: const Color(0xFFD64545),
                            selected: !_available,
                            onTap: () => setState(() => _available = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Unavailable coffee stays on your menu, marked for customers, until you switch it back.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                    ),
                    const SizedBox(height: 20),
                    const Text('Highlights', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    const SizedBox(height: 10),
                    SettingsSwitchTile(
                      icon: Icons.local_fire_department_rounded,
                      title: 'Mark as Best Seller',
                      subtitle: 'Shows a Best Seller badge to customers. You decide which coffees get it.',
                      value: _bestSeller,
                      onChanged: (v) => setState(() => _bestSeller = v),
                    ),
                    SettingsSwitchTile(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Feature this coffee',
                      subtitle: 'Shows it in the Featured row at the top of your menu.',
                      value: _featured,
                      onChanged: (v) => setState(() => _featured = v),
                    ),
                    const SizedBox(height: 16),
                    AuthSubmitButton(
                      label: _isEditing ? 'Save Changes' : 'Add Coffee',
                      isLoading: _isSaving,
                      onPressed: _save,
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

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const Text(' *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD64545))),
      ],
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final File? newImage;
  final String? currentUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoPicker({required this.newImage, required this.currentUrl, required this.onPick, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = newImage != null || (currentUrl?.isNotEmpty ?? false);
    Widget preview;
    // Shown exactly as on the menu: the photo fills a 4:3 box.
    if (newImage != null) {
      preview = FittedImage(image: FileImage(newImage!), width: double.infinity, height: double.infinity, fit: BoxFit.cover);
    } else if (currentUrl?.isNotEmpty ?? false) {
      preview = FittedImage.network(currentUrl!, width: double.infinity, height: double.infinity, fit: BoxFit.cover);
    } else {
      preview = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppColors.primaryBrown),
          SizedBox(height: 8),
          Text('Add a coffee photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          SizedBox(height: 2),
          Text('Optional · square or landscape photos look best', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.textGrey)),
        ],
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: onPick,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: ImageRatios.coffee,
              child: Container(color: AppColors.inputFill, child: preview),
            ),
          ),
        ),
        if (hasPhoto)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: const Text('Change'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryBrown),
              ),
              TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFD64545)),
              ),
            ],
          ),
      ],
    );
  }
}

class _AvailabilityOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _AvailabilityOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? color : AppColors.textGrey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? color : AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }
}
