import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'user_role.dart';

/// Website only. Keeps a sign-in for this browser tab (so refreshing the
/// page doesn't log you out), or across visits when Remember me is ticked.
/// Phones are unchanged.
Future<void> applyWebRememberMe(bool rememberMe) async {
  if (!kIsWeb) return;
  try {
    await FirebaseAuth.instance.setPersistence(rememberMe ? Persistence.LOCAL : Persistence.SESSION);
  } catch (e) {
    debugPrint('Could not set web sign-in persistence: $e');
  }
}

/// Website only. After a page refresh, the role of the account that is
/// still signed in, so the app reopens on its home screen; null means
/// "show the Welcome screen" (always null on phones).
Future<UserRole?> resumedWebRole() async {
  if (!kIsWeb) return null;
  try {
    final user = await FirebaseAuth.instance.authStateChanges().first.timeout(const Duration(seconds: 5));
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection(usersCollection)
        .doc(user.uid)
        .get()
        .timeout(const Duration(seconds: 8));
    return UserRoleX.fromValue(doc.data()?['role'] as String?);
  } catch (e) {
    debugPrint('Could not restore the web session: $e');
    return null;
  }
}
