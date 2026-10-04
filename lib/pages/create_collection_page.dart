import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/shop_collection.dart';
import '../utils/collections_service.dart';
import '../utils/page_transitions.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/category_chip.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/top_banner.dart';
import 'collections_page.dart';

/// Ready-made ideas shown as chips when creating a collection — tapping
/// one fills in the name and a matching icon.
const List<(String, String)> _nameIdeas = [
  ('Best Matcha', 'leaf'),
  ('Quiet Cafés', 'quiet'),
  ('Cafés Near School', 'school'),
  ('Affordable Cafés', 'savings'),
];

/// What the Create/Edit Collection screen asks to be saved.
class CollectionDraft {
  final String name;
  final String iconKey;
  final String? categoryId; // set when the name picks a built-in category
  final String? existingId; // set when editing a custom collection
  final List<String> shopIds; // cafés to start the new collection with

  const CollectionDraft({
    required this.name,
    required this.iconKey,
    this.categoryId,
    this.existingId,
    this.shopIds = const [],
  });
}

/// Saves a [CollectionDraft] for the signed-in user. Replaceable in tests.
typedef CollectionSaver = Future<void> Function(CollectionDraft draft);

Future<void> saveCollectionDraft(CollectionDraft draft) async {
  if (draft.existingId != null) {
    await CollectionsService.updateCustom(draft.existingId!, name: draft.name, iconKey: draft.iconKey);
  } else if (draft.categoryId != null) {
    await CollectionsService.createCategory(draft.categoryId!, shopIds: draft.shopIds);
  } else {
    await CollectionsService.createCustom(name: draft.name, iconKey: draft.iconKey, shopIds: draft.shopIds);
  }
}

/// Opens the Create Collection screen (or Edit, when [existing] is given).
/// Resolves to true once the collection has been saved, or null if the
/// user went back without saving.
Future<bool?> openCreateCollection(
  BuildContext context, {
  required List<ShopCollection> allCollections,
  ShopCollection? existing,
  String? initialShopId,
}) {
  return Navigator.of(context).push<bool>(
    slideUpRoute(CreateCollectionPage(
      allCollections: allCollections,
      existing: existing,
      initialShopId: initialShopId,
    )),
  );
}

/// Full-screen form to create a collection — or edit a custom one when
/// [existing] is given — with a user-chosen name and icon, in the same
/// layout as the other Collection screens (dark header with a back arrow,
/// white sheet below). Suggestions offer the built-in categories the user
/// hasn't started yet (picking one starts that category, with its own
/// icon) plus a few name ideas. [allCollections] is used to block
/// duplicate names; [initialShopId] starts the new collection with that
/// café already saved in it.
class CreateCollectionPage extends StatefulWidget {
  final List<ShopCollection> allCollections;
  final ShopCollection? existing;
  final String? initialShopId;
  final CollectionSaver saver;

  const CreateCollectionPage({
    super.key,
    required this.allCollections,
    this.existing,
    this.initialShopId,
    this.saver = saveCollectionDraft,
  });

  @override
  State<CreateCollectionPage> createState() => _CreateCollectionPageState();
}

class _CreateCollectionPageState extends State<CreateCollectionPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late String _iconKey = widget.existing?.iconKey ?? CollectionIconOption.defaultKey;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  /// Collections the user actually has (not unstarted categories).
  Iterable<ShopCollection> get _existing => widget.allCollections.where((c) => c.exists);

  /// Built-in categories the user hasn't started — offered as suggestions.
  List<CollectionCategory> get _unstartedCategories => [
        for (final c in CollectionCategory.all)
          if (!_existing.any((e) => e.id == c.id)) c,
      ];

  /// The unstarted built-in category whose name matches what's typed, if
  /// any — creating it starts that category instead of a custom one.
  CollectionCategory? get _matchingCategory {
    if (_isEditing) return null;
    final name = _nameController.text.trim().toLowerCase();
    for (final c in _unstartedCategories) {
      if (c.name.toLowerCase() == name) return c;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Keep the preview and the selected chip in step with typing.
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Please enter a collection name';
    if (name.length > 40) return 'Keep it under 40 characters';
    final taken = _existing.any(
      (c) => c.id != widget.existing?.id && c.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (taken) return 'You already have a collection with this name';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      await widget.saver(CollectionDraft(
        name: _nameController.text.trim(),
        iconKey: _iconKey,
        categoryId: _matchingCategory?.id,
        existingId: widget.existing?.id,
        shopIds: [if (widget.initialShopId != null) widget.initialShopId!],
      ));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Saving collection failed: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      showTopBanner(context, "Couldn't save collection. Please try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.trim();
    final matchingCategory = _matchingCategory;
    final previewIcon = matchingCategory?.icon ?? CollectionIconOption.iconFor(_iconKey);

    return SettingsPageScaffold(
      title: _isEditing ? 'Edit Collection' : 'Create Collection',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live preview of how the collection card will look.
                    Row(
                      children: [
                        CollectionIconTile(icon: previewIcon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name.isEmpty ? 'Your collection' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: name.isEmpty ? AppColors.textGrey : AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AuthTextField(
                      label: 'Collection name',
                      controller: _nameController,
                      hint: 'e.g. Best Matcha',
                      validator: _validateName,
                    ),
                    if (!_isEditing) ...[
                      const SizedBox(height: 12),
                      const Text('Suggestions', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in _unstartedCategories)
                            CategoryChip(
                              label: category.name,
                              icon: category.icon,
                              selected: matchingCategory?.id == category.id,
                              onTap: () => setState(() {
                                _nameController.text = category.name;
                                _iconKey = category.iconKey;
                              }),
                            ),
                          for (final (idea, iconKey) in _nameIdeas)
                            if (!_existing.any((c) => c.name.toLowerCase() == idea.toLowerCase()))
                              CategoryChip(
                                label: idea,
                                icon: CollectionIconOption.iconFor(iconKey),
                                selected: name == idea,
                                onTap: () => setState(() {
                                  _nameController.text = idea;
                                  _iconKey = iconKey;
                                }),
                              ),
                        ],
                      ),
                    ],
                    // Built-in categories keep their own icon.
                    if (matchingCategory == null) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Choose an icon',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final option in CollectionIconOption.all)
                            _IconChoice(
                              key: ValueKey('icon-${option.key}'),
                              icon: option.icon,
                              selected: option.key == _iconKey,
                              onTap: () => setState(() => _iconKey = option.key),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AuthSubmitButton(
              label: _isEditing ? 'Save Changes' : 'Create Collection',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({super.key, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBrown : AppColors.primaryBrown.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: selected ? Colors.white : AppColors.primaryBrown),
      ),
    );
  }
}
