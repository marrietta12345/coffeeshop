import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';
import '../widgets/settings_widgets.dart';

/// Shows the app's real location-permission status and lets the user
/// turn access on (system prompt) or off / back on after a hard denial
/// (device settings — apps can't revoke their own permission). Re-checks
/// automatically when the user comes back from the settings app.
class LocationSettingsPage extends StatefulWidget {
  const LocationSettingsPage({super.key});

  @override
  State<LocationSettingsPage> createState() => _LocationSettingsPageState();
}

enum _LocationStatus { checking, allowed, notAllowed, blocked, servicesOff }

class _LocationSettingsPageState extends State<LocationSettingsPage> with WidgetsBindingObserver {
  _LocationStatus _status = _LocationStatus.checking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    _LocationStatus status;
    try {
      final permission = await Geolocator.checkPermission();
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (permission == LocationPermission.deniedForever) {
        status = _LocationStatus.blocked;
      } else if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        status = _LocationStatus.notAllowed;
      } else if (!serviceEnabled) {
        status = _LocationStatus.servicesOff;
      } else {
        status = _LocationStatus.allowed;
      }
    } catch (_) {
      status = _LocationStatus.notAllowed;
    }
    if (mounted) setState(() => _status = status);
  }

  Future<void> _onToggle(bool enable) async {
    if (!enable) {
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Turn off location?'),
          content: const Text(
            "Location access is turned off from your device settings. Without it, "
            "the map can't show coffee shops near you.",
            style: TextStyle(fontSize: 13.5, height: 1.45),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBrown),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (open == true) await Geolocator.openAppSettings();
      return;
    }

    switch (_status) {
      case _LocationStatus.notAllowed:
        await Geolocator.requestPermission();
        break;
      case _LocationStatus.blocked:
        await Geolocator.openAppSettings();
        break;
      case _LocationStatus.servicesOff:
        await Geolocator.openLocationSettings();
        break;
      case _LocationStatus.allowed:
      case _LocationStatus.checking:
        break;
    }
    await _refresh();
  }

  Future<void> _openDeviceSettings() async {
    if (_status == _LocationStatus.servicesOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  ({String label, String detail, Color color, IconData icon}) get _statusInfo {
    switch (_status) {
      case _LocationStatus.allowed:
        return (
          label: 'Allowed',
          detail: 'Kafelo can use your location to find nearby coffee shops.',
          color: const Color(0xFF2E7D32),
          icon: Icons.check_circle_rounded,
        );
      case _LocationStatus.notAllowed:
        return (
          label: 'Not allowed',
          detail: 'Turn on location access to see coffee shops near you.',
          color: const Color(0xFFC62828),
          icon: Icons.location_off_rounded,
        );
      case _LocationStatus.blocked:
        return (
          label: 'Blocked',
          detail: 'Location was denied permanently. Allow it again from your device settings.',
          color: const Color(0xFFC62828),
          icon: Icons.block_rounded,
        );
      case _LocationStatus.servicesOff:
        return (
          label: 'Location services off',
          detail: "Your device's location is turned off. Turn it on in your device settings.",
          color: const Color(0xFFE65100),
          icon: Icons.location_disabled_rounded,
        );
      case _LocationStatus.checking:
        return (
          label: 'Checking…',
          detail: '',
          color: AppColors.textGrey,
          icon: Icons.location_searching_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _statusInfo;
    final isChecking = _status == _LocationStatus.checking;
    final isAllowed = _status == _LocationStatus.allowed;

    return SettingsPageScaffold(
      title: 'Location',
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryBrown.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.map_outlined, color: AppColors.primaryBrown, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kafelo uses your location to show nearby coffee shops on the map '
                    'and how far each one is from you. It is never shared with cafés.',
                    style: TextStyle(fontSize: 13, color: AppColors.textDark, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SettingsSwitchTile(
            icon: Icons.location_on_outlined,
            title: 'Location access',
            subtitle: isAllowed ? 'On' : 'Off',
            value: isAllowed,
            onChanged: isChecking ? null : _onToggle,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(info.icon, color: info.color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Permission status', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      const SizedBox(height: 2),
                      Text(info.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: info.color)),
                      if (info.detail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(info.detail, style: const TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isAllowed && !isChecking) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrown,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _openDeviceSettings,
                icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                label: const Text(
                  'Open Location Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
