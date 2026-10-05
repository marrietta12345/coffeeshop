import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Recommended floor choices for cafés inside a mall. Anything else
/// (5th Floor, Mezzanine, Lower Ground, Roof Deck…) goes under [other]
/// and is typed by the owner.
class MallFloor {
  MallFloor._();

  static const List<String> options = ['Ground Floor', '1st Floor', '2nd Floor', '3rd Floor', '4th Floor'];
  static const String other = 'Other';

  /// The choice to preselect for a saved floor: a matching option, or
  /// [other] for a custom floor (null when nothing is saved).
  static String? choiceFor(String? saved) {
    final value = saved?.trim() ?? '';
    if (value.isEmpty) return null;
    for (final option in options) {
      if (option.toLowerCase() == value.toLowerCase()) return option;
    }
    return other;
  }
}

/// Malls are shared locations, NOT businesses: `malls/{mallKey}` =
/// `{name, createdBy, createdAt}`, and each café inside one keeps its own
/// shop document that points at it with `mallId` + `mallName`. One mall →
/// many cafés; any number of cafés can share a mall and a floor.
///
/// The document id is a normalized key of the name, so "Gaisano Mall
/// Butuan", "gaisano mall butuan" and "Gaisano Mall - Butuan" all resolve
/// to the same mall instead of creating duplicates.
class MallService {
  MallService._();

  static final _db = FirebaseFirestore.instance;

  /// "Gaisano Mall - Butuan" → "gaisano-mall-butuan".
  static String mallKey(String name) {
    final words = name
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty);
    return words.join('-');
  }

  /// Every mall already on Kafelo — from the malls registry plus the mall
  /// names on existing café listings (cafés added before the registry) —
  /// one name per mall, A–Z.
  static Future<List<String>> knownMalls() async {
    final byKey = <String, String>{};
    try {
      final malls = await _db.collection('malls').get();
      for (final doc in malls.docs) {
        final name = (doc.data()['name'] as String?)?.trim() ?? '';
        if (name.isNotEmpty) byKey[doc.id] = name;
      }
    } catch (e) {
      debugPrint('Loading malls failed: $e');
    }
    try {
      final shops = await _db.collection('shops').where('locationType', isEqualTo: 'mall').get();
      for (final doc in shops.docs) {
        final name = (doc.data()['mallName'] as String?)?.trim() ?? '';
        if (name.isNotEmpty) byKey.putIfAbsent(mallKey(name), () => name);
      }
    } catch (e) {
      debugPrint('Loading mall names from cafés failed: $e');
    }
    return byKey.values.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// Malls in [all] matching what's typed (ignores case, spaces and
  /// punctuation), names starting with it first.
  static List<String> suggestions(List<String> all, String query) {
    final q = mallKey(query);
    if (q.isEmpty) return all;
    final matches = all.where((m) => mallKey(m).contains(q)).toList()
      ..sort((a, b) {
        final aStarts = mallKey(a).startsWith(q) ? 0 : 1;
        final bStarts = mallKey(b).startsWith(q) ? 0 : 1;
        return aStarts != bStarts ? aStarts - bStarts : a.toLowerCase().compareTo(b.toLowerCase());
      });
    return matches;
  }

  /// The mall record for [typedName]: the existing one when its key
  /// already exists (keeping that mall's spelling), otherwise a new one.
  /// Must be called by a signed-in user.
  static Future<({String id, String name})> resolve(String typedName) async {
    final name = typedName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final id = mallKey(name);
    final ref = _db.collection('malls').doc(id);
    final existing = await ref.get();
    final existingName = (existing.data()?['name'] as String?)?.trim();
    if (existing.exists && existingName != null && existingName.isNotEmpty) {
      return (id: id, name: existingName);
    }
    try {
      await ref.set({
        'name': name,
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Another owner may have just added the same mall — use theirs.
      final again = await ref.get();
      final againName = (again.data()?['name'] as String?)?.trim();
      if (again.exists && againName != null && againName.isNotEmpty) return (id: id, name: againName);
      rethrow;
    }
    return (id: id, name: name);
  }
}
