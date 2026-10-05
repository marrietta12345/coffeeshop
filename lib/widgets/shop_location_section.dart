import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../pages/pick_shop_location_page.dart';
import '../utils/form_validators.dart';
import '../utils/location_service.dart';
import '../utils/mall_service.dart';
import '../utils/page_transitions.dart';
import 'auth_text_field.dart';
import 'category_chip.dart';
import 'top_banner.dart';

/// Everything about where a café is, shared by Business Sign Up and the
/// owner's Edit Profile so both use the same fields and validation:
///
/// * Standalone / Street Location → Café Address* + GPS*
/// * Inside a Mall → Mall Name* (search existing malls), Floor Level*
///   (Ground–4th or Other → typed floor*), Unit / Store Number,
///   Specific Location / Landmark*, + GPS*
///
/// Each café keeps its own GPS coordinates, even inside a mall.
class ShopLocationController extends ChangeNotifier {
  ShopLocationController({CoffeeShop? shop})
      : isMall = shop?.isInMall ?? false,
        address = TextEditingController(text: shop?.address ?? ''),
        mallName = TextEditingController(text: shop?.isInMall == true ? shop!.mallName!.trim() : ''),
        customFloor = TextEditingController(
          text: MallFloor.choiceFor(shop?.mallFloor) == MallFloor.other ? shop!.mallFloor!.trim() : '',
        ),
        unit = TextEditingController(text: shop?.mallUnit ?? ''),
        landmark = TextEditingController(text: shop?.mallLandmark ?? ''),
        floorChoice = shop?.isInMall == true ? MallFloor.choiceFor(shop!.mallFloor) : null,
        location = shop == null || (shop.latitude == 0 && shop.longitude == 0)
            ? null
            : LatLng(shop.latitude, shop.longitude);

  bool isMall; // Location Type: false = Standalone / Street Location
  final TextEditingController address;
  final TextEditingController mallName;
  final TextEditingController customFloor; // used when floorChoice is Other
  final TextEditingController unit;
  final TextEditingController landmark;
  String? floorChoice; // one of MallFloor.options, MallFloor.other, or null
  LatLng? location;
  bool gpsMissing = false; // show the GPS error after a failed submit
  bool locating = false;

  void setMall(bool value) {
    isMall = value;
    notifyListeners();
  }

  void setFloorChoice(String choice) {
    floorChoice = choice;
    notifyListeners();
  }

  void setLocation(LatLng value) {
    location = value;
    gpsMissing = false;
    notifyListeners();
  }

  void setLocating(bool value) {
    locating = value;
    notifyListeners();
  }

  /// The floor to save: the chosen option, or the typed one for Other.
  String get floor => floorChoice == MallFloor.other ? customFloor.text.trim() : (floorChoice ?? '');

  /// True when a GPS location was captured; otherwise flags the error.
  bool validateGps() {
    gpsMissing = location == null;
    notifyListeners();
    return !gpsMissing;
  }

  /// The location fields for the shop (and the owner's account). For a
  /// mall café, resolves the shared mall record first — reusing an
  /// existing mall rather than creating a duplicate. Needs a signed-in
  /// user and a captured [location].
  Future<Map<String, dynamic>> toFirestore() async {
    String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    ({String id, String name})? mall;
    if (isMall) {
      try {
        mall = await MallService.resolve(mallName.text);
      } catch (e) {
        // Never lose the café over the shared mall record — save it with
        // the same normalized key so it still groups with its mall.
        debugPrint('Mall record unavailable, saving name only: $e');
        final name = mallName.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        mall = (id: MallService.mallKey(name), name: name);
      }
    }
    return {
      'locationType': isMall ? 'mall' : 'standalone',
      'mallId': mall?.id,
      'mallName': mall?.name,
      'mallFloor': isMall ? floor : null,
      'mallUnit': isMall ? text(unit) : null,
      'mallLandmark': isMall ? text(landmark) : null,
      // Mall cafés: the address looked up from their GPS position (may be
      // empty — the mall name is what customers see).
      'address': address.text.trim(),
      'latitude': location!.latitude,
      'longitude': location!.longitude,
    };
  }

  @override
  void dispose() {
    address.dispose();
    mallName.dispose();
    customFloor.dispose();
    unit.dispose();
    landmark.dispose();
    super.dispose();
  }
}

class ShopLocationSection extends StatefulWidget {
  final ShopLocationController controller;

  const ShopLocationSection({super.key, required this.controller});

  @override
  State<ShopLocationSection> createState() => _ShopLocationSectionState();
}

class _ShopLocationSectionState extends State<ShopLocationSection> {
  ShopLocationController get _c => widget.controller;
  final _mallFocus = FocusNode();
  List<String> _knownMalls = const [];

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    _loadMalls();
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _mallFocus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMalls() async {
    final malls = await MallService.knownMalls();
    if (mounted) setState(() => _knownMalls = malls);
  }

  /// Fills the address from [point] (for mall cafés, or when the address
  /// field is still empty).
  Future<void> _fillAddressFrom(LatLng point, {bool always = false}) async {
    if (!always && !_c.isMall && _c.address.text.trim().isNotEmpty) return;
    try {
      final placemarks = await placemarkFromCoordinates(point.latitude, point.longitude).timeout(const Duration(seconds: 8));
      if (placemarks.isEmpty || !mounted) return;
      final place = placemarks.first;
      final parts = [place.street, place.subLocality, place.locality, place.administrativeArea]
          .where((part) => part != null && part.trim().isNotEmpty)
          .toList();
      if (parts.isNotEmpty) _c.address.text = parts.join(', ');
    } catch (e) {
      debugPrint('Reverse geocoding failed for $point: $e');
    }
  }

  /// Gets the phone's position, then lets the owner confirm it (or adjust
  /// it on the map) before it's used.
  Future<void> _useCurrentLocation() async {
    _c.setLocating(true);
    final result = await getCurrentLocation();
    if (!mounted) return;
    _c.setLocating(false);
    if (!result.isSuccess) {
      showTopBanner(context, result.errorMessage!, isSuccess: false, duration: const Duration(seconds: 3));
      return;
    }
    final here = result.position!;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Use this location?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This is where your phone is now. Make sure you're at your café — customers will be guided here.",
              style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 18, color: AppColors.primaryBrown),
                const SizedBox(width: 6),
                Text(
                  '${here.latitude.toStringAsFixed(5)}, ${here.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'adjust'),
            child: const Text('Adjust on Map', style: TextStyle(color: AppColors.primaryBrown, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'confirm'),
            child: const Text('Confirm', style: TextStyle(color: AppColors.primaryBrown, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'adjust') {
      await _pickOnMap(start: here);
      return;
    }
    _c.setLocation(here);
    _c.setLocating(true);
    await _fillAddressFrom(here);
    if (mounted) _c.setLocating(false);
  }

  Future<void> _pickOnMap({LatLng? start}) async {
    var center = start ?? _c.location ?? const LatLng(8.9475, 125.5406); // Butuan City
    // Open near the typed address when there's no position yet.
    if (start == null && _c.location == null && _c.address.text.trim().isNotEmpty) {
      _c.setLocating(true);
      try {
        final found = await locationFromAddress(_c.address.text.trim()).timeout(const Duration(seconds: 8));
        if (found.isNotEmpty) center = LatLng(found.first.latitude, found.first.longitude);
      } catch (e) {
        debugPrint('Geocoding failed for "${_c.address.text.trim()}": $e');
      }
      if (!mounted) return;
      _c.setLocating(false);
    }
    final result = await Navigator.push<LatLng>(context, slideUpRoute(PickShopLocationPage(initialCenter: center)));
    if (result == null || !mounted) return;
    _c.setLocation(result);
    _c.setLocating(true);
    await _fillAddressFrom(result, always: _c.isMall || _c.address.text.trim().isEmpty);
    if (mounted) _c.setLocating(false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RequiredLabel('Location Type'),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _LocationTypeOption(
                  label: 'Standalone / Street Location',
                  icon: Icons.storefront_outlined,
                  selected: !_c.isMall,
                  onTap: () => _c.setMall(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LocationTypeOption(
                  label: 'Inside a Mall',
                  icon: Icons.local_mall_outlined,
                  selected: _c.isMall,
                  onTap: () => _c.setMall(true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_c.isMall) ..._mallFields() else
          AuthTextField(
            label: 'Café Address',
            controller: _c.address,
            hint: 'Enter complete café address',
            keyboardType: TextInputType.streetAddress,
            isRequired: true,
            validator: FormValidators.required,
          ),
        const SizedBox(height: 18),
        const _RequiredLabel('Café GPS Location'),
        const SizedBox(height: 4),
        Text(
          _c.isMall
              ? 'Tap "Use Current Location" while you\'re at your café inside the mall — not the mall entrance — or pick the exact spot on the map.'
              : 'Tap "Use Current Location" while you\'re at your café, or pick it on the map.',
          style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
        ),
        const SizedBox(height: 10),
        _GpsCard(
          location: _c.location,
          locating: _c.locating,
          missing: _c.gpsMissing,
          onUseCurrent: _useCurrentLocation,
          onPickOnMap: () => _pickOnMap(),
        ),
      ],
    );
  }

  List<Widget> _mallFields() {
    return [
      _MallNameField(controller: _c.mallName, focusNode: _mallFocus, knownMalls: _knownMalls),
      const SizedBox(height: 18),
      FormField<String>(
        initialValue: _c.floorChoice,
        validator: (_) => _c.floorChoice == null ? FormValidators.requiredMessage : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _RequiredLabel('Floor Level'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in [...MallFloor.options, MallFloor.other])
                  CategoryChip(
                    label: option,
                    icon: option == MallFloor.other ? Icons.edit_outlined : Icons.layers_outlined,
                    selected: _c.floorChoice == option,
                    onTap: () {
                      _c.setFloorChoice(option);
                      field.didChange(option);
                    },
                  ),
              ],
            ),
            if (field.hasError) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(field.errorText!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ],
        ),
      ),
      if (_c.floorChoice == MallFloor.other) ...[
        const SizedBox(height: 14),
        AuthTextField(
          label: 'Enter Floor Level',
          controller: _c.customFloor,
          hint: 'e.g., 6th Floor, 10th Floor, Mezzanine',
          isRequired: true,
          validator: (v) {
            final value = (v ?? '').trim();
            if (value.isEmpty) return FormValidators.requiredMessage;
            if (value.length > 30) return 'Keep it under 30 characters.';
            return null;
          },
        ),
      ],
      const SizedBox(height: 18),
      AuthTextField(
        label: 'Unit / Store Number',
        controller: _c.unit,
        hint: 'e.g., Unit 204',
        validator: (v) => (v ?? '').trim().length > 20 ? 'Keep it under 20 characters.' : null,
      ),
      const SizedBox(height: 18),
      AuthTextField(
        label: 'Specific Location / Landmark',
        controller: _c.landmark,
        hint: 'e.g., Near Food Court, Beside Cinema, Near Main Entrance',
        isRequired: true,
        validator: (v) {
          final value = (v ?? '').trim();
          if (value.isEmpty) return FormValidators.requiredMessage;
          if (value.length > 80) return 'Keep it under 80 characters.';
          return null;
        },
      ),
    ];
  }
}

/// Mall Name with suggestions from malls already on Kafelo; typing a new
/// name is allowed (it becomes a new mall record when saved).
class _MallNameField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> knownMalls;

  const _MallNameField({required this.controller, required this.focusNode, required this.knownMalls});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RequiredLabel('Mall Name'),
        const SizedBox(height: 8),
        RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: focusNode,
          optionsBuilder: (value) {
            if (value.text.trim().isEmpty) return knownMalls.take(6);
            final matches = MallService.suggestions(knownMalls, value.text);
            // Hide the list once the name exactly matches a known mall.
            if (matches.length == 1 && MallService.mallKey(matches.first) == MallService.mallKey(value.text)) {
              return const Iterable<String>.empty();
            }
            return matches.take(6);
          },
          fieldViewBuilder: (context, textController, node, onSubmitted) => TextFormField(
            controller: textController,
            focusNode: node,
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return FormValidators.requiredMessage;
              if (MallService.mallKey(value).length < 2 || value.length > 80) return 'Please enter a valid mall name.';
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Search or enter mall name',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              filled: true,
              fillColor: AppColors.inputFill,
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textGrey, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 240, maxWidth: MediaQuery.of(context).size.width - 48),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  children: [
                    for (final mall in options)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.local_mall_outlined, size: 20, color: AppColors.primaryBrown),
                        title: Text(mall, style: const TextStyle(fontSize: 13.5, color: AppColors.textDark)),
                        onTap: () => onSelected(mall),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pick your mall from the list if it\'s already on Kafelo, or type its full name.',
          style: TextStyle(fontSize: 11, color: AppColors.textGrey),
        ),
      ],
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  final String text;

  const _RequiredLabel(this.text);

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

class _LocationTypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LocationTypeOption({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.textDark;
    return Material(
      color: selected ? AppColors.primaryBrown : AppColors.inputFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : AppColors.primaryBrown),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color, height: 1.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// GPS status (captured coordinates or not yet), with "Use Current
/// Location" and "Pick on Map", and a red error after a failed submit.
class _GpsCard extends StatelessWidget {
  final LatLng? location;
  final bool locating;
  final bool missing;
  final VoidCallback onUseCurrent;
  final VoidCallback onPickOnMap;

  const _GpsCard({
    required this.location,
    required this.locating,
    required this.missing,
    required this.onUseCurrent,
    required this.onPickOnMap,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: location != null ? AppColors.primaryBrown.withOpacity(0.08) : AppColors.inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: missing
                  ? errorColor
                  : location != null
                      ? AppColors.primaryBrown.withOpacity(0.4)
                      : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              if (locating)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBrown))
              else
                Icon(location != null ? Icons.check_circle_rounded : Icons.location_searching_rounded, size: 20, color: AppColors.primaryBrown),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locating
                          ? 'Getting location…'
                          : location != null
                              ? '📍 Captured Location'
                              : 'No location captured yet',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryBrown),
                    ),
                    if (location != null && !locating)
                      Text(
                        '${location!.latitude.toStringAsFixed(5)}, ${location!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrown,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: locating ? null : onUseCurrent,
                icon: const Icon(Icons.my_location_rounded, size: 18, color: Colors.white),
                label: const Text('Use Current Location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  side: BorderSide(color: AppColors.primaryBrown.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: locating ? null : onPickOnMap,
                icon: const Icon(Icons.map_outlined, size: 18, color: AppColors.primaryBrown),
                label: const Text('Pick on Map', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryBrown)),
              ),
            ),
          ],
        ),
        if (missing) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text("Please capture your café's GPS location.", style: TextStyle(fontSize: 12, color: errorColor)),
          ),
        ],
      ],
    );
  }
}
