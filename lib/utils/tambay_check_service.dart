import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// How busy a café is, as said by someone who's there.
enum TambayBusy { chill, some, packed }

extension TambayBusyX on TambayBusy {
  String get value => name;
  String get emoji => switch (this) { TambayBusy.chill => '🟢', TambayBusy.some => '🟡', TambayBusy.packed => '🔴' };
  String get label => switch (this) { TambayBusy.chill => 'Chill', TambayBusy.some => 'Some seats', TambayBusy.packed => 'Packed' };

  static TambayBusy? fromValue(Object? value) =>
      TambayBusy.values.where((b) => b.name == value).firstOrNull;
}

/// Wi-Fi as rated by someone at the café ('fast', 'ok', 'slow').
const tambayWifiLabels = {'fast': 'Fast Wi-Fi', 'ok': 'OK Wi-Fi', 'slow': 'Slow Wi-Fi'};

/// One "I'm here" report: `tambayChecks/{shopId}_{uid}` — one per person
/// per café, replaced when they check in again.
class TambayCheck {
  final String shopId;
  final String uid;
  final TambayBusy busy;
  final bool? outlets; // free outlets? null = didn't say
  final String? wifi; // key of tambayWifiLabels, null = didn't say
  final DateTime createdAt;

  const TambayCheck({
    required this.shopId,
    required this.uid,
    required this.busy,
    required this.createdAt,
    this.outlets,
    this.wifi,
  });

  static TambayCheck? fromMap(Map<String, dynamic> data) {
    final busy = TambayBusyX.fromValue(data['busy']);
    final created = data['createdAt'];
    if (busy == null || created is! Timestamp || data['shopId'] is! String) return null;
    return TambayCheck(
      shopId: data['shopId'] as String,
      uid: (data['uid'] as String?) ?? '',
      busy: busy,
      outlets: data['outlets'] as bool?,
      wifi: tambayWifiLabels.containsKey(data['wifi']) ? data['wifi'] as String : null,
      createdAt: created.toDate(),
    );
  }
}

/// What a café is like right now, from its recent check-ins.
class TambaySummary {
  final TambayBusy busy; // from the newest check-in
  final bool? outlets; // newest answer about outlets
  final String? wifi; // newest answer about Wi-Fi
  final DateTime latest;
  final int count;

  const TambaySummary({required this.busy, required this.latest, required this.count, this.outlets, this.wifi});

  /// "🟢 Chill · Outlets free · Fast Wi-Fi"
  String get headline => [
        '${busy.emoji} ${busy.label}',
        if (outlets != null) outlets! ? 'Outlets free' : 'No free outlets',
        if (wifi != null) tambayWifiLabels[wifi]!,
      ].join(' · ');

  /// "just now", "12 min ago", "1 hr ago".
  String agoAt(DateTime now) {
    final minutes = now.difference(latest).inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '$minutes min ago';
    return '${minutes ~/ 60} hr ago';
  }
}

/// "Tambay Check": people at a café say how busy it is, whether outlets
/// are free and how the Wi-Fi is. A report is live for [liveFor]; you can
/// only check in within [maxDistanceMeters] of the café.
class TambayCheckService {
  TambayCheckService._();

  static const Duration liveFor = Duration(hours: 2);
  static const double maxDistanceMeters = 150;
  static const String collection = 'tambayChecks';

  /// Live summaries by café id, for every café with a recent check-in.
  static final ValueNotifier<Map<String, TambaySummary>> summaries = ValueNotifier(const {});

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  static StreamSubscription<User?>? _authSubscription;
  static Timer? _refresh;
  static List<TambayCheck> _checks = const [];

  /// Starts following recent check-ins while someone is signed in (they're
  /// only readable when signed in). The query is renewed every few minutes
  /// so old reports drop off.
  static void start() {
    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _stopFollowing();
      } else if (_subscription == null) {
        _subscribe();
        _refresh ??= Timer.periodic(const Duration(minutes: 5), (_) {
          if (_subscription == null) return;
          _subscription?.cancel();
          _subscribe();
        });
      }
    });
  }

  static void _stopFollowing() {
    _subscription?.cancel();
    _subscription = null;
    _refresh?.cancel();
    _refresh = null;
    _checks = const [];
    summaries.value = const {};
  }

  static void _subscribe() {
    final since = Timestamp.fromDate(DateTime.now().subtract(liveFor));
    _subscription = FirebaseFirestore.instance
        .collection(collection)
        .where('createdAt', isGreaterThan: since)
        .snapshots()
        .listen(
      (snapshot) {
        _checks = [for (final doc in snapshot.docs) ?TambayCheck.fromMap(doc.data())];
        summaries.value = summarize(_checks, DateTime.now());
      },
      onError: (Object e) => debugPrint('Tambay Check stream error: $e'),
    );
  }

  /// Per café: the newest check-in's busy level, the newest answers about
  /// outlets and Wi-Fi, and how many people checked in — counting only
  /// reports from the last [liveFor].
  static Map<String, TambaySummary> summarize(List<TambayCheck> checks, DateTime now) {
    final byShop = <String, List<TambayCheck>>{};
    for (final c in checks) {
      if (now.difference(c.createdAt) > liveFor) continue;
      (byShop[c.shopId] ??= []).add(c);
    }
    return {
      for (final entry in byShop.entries)
        entry.key: () {
          final list = entry.value..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return TambaySummary(
            busy: list.first.busy,
            outlets: list.map((c) => c.outlets).whereType<bool>().firstOrNull,
            wifi: list.map((c) => c.wifi).whereType<String>().firstOrNull,
            latest: list.first.createdAt,
            count: list.length,
          );
        }(),
    };
  }

  /// Saves the signed-in customer's check-in for [shopId] (replacing their
  /// earlier one there).
  static Future<void> checkIn({required String shopId, required TambayBusy busy, bool? outlets, String? wifi}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to check in.');
    await FirebaseFirestore.instance.collection(collection).doc('${shopId}_$uid').set({
      'shopId': shopId,
      'uid': uid,
      'busy': busy.value,
      'outlets': outlets,
      'wifi': wifi,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
