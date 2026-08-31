import 'package:flutter/material.dart';

/// A polished, direction-aware page transition: the incoming page slides in
/// from the right while fading in, and the outgoing page dims slightly as
/// it's covered. Use for lateral, "peer" navigation.
///
/// Respects the OS-level "Reduce Motion" accessibility setting — when
/// enabled, this falls back to a simple cross-fade instead of a slide.
Route<T> slideFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) {
        return FadeTransition(opacity: animation, child: child);
      }

      final incoming = Tween<Offset>(
        begin: const Offset(0.12, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      final incomingFade = CurvedAnimation(parent: animation, curve: Curves.easeOut);

      final outgoing = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.08, 0),
      ).animate(CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic));

      final outgoingFade = Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut),
      );

      return SlideTransition(
        position: outgoing,
        child: FadeTransition(
          opacity: outgoingFade,
          child: SlideTransition(
            position: incoming,
            child: FadeTransition(
              opacity: incomingFade,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// A modal-style transition: the incoming page rises up from the bottom
/// while fading in, and the page underneath dims slightly. This is the
/// familiar pattern most apps use specifically for auth screens (sign in /
/// sign up feeling like a sheet presented over the app, rather than a
/// lateral "next page" navigation).
///
/// Also respects "Reduce Motion" — falls back to a cross-fade if enabled.
Route<T> slideUpRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) {
        return FadeTransition(opacity: animation, child: child);
      }

      final incoming = Tween<Offset>(
        begin: const Offset(0, 0.18),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      final incomingFade = CurvedAnimation(parent: animation, curve: Curves.easeOut);

      final outgoingFade = Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut),
      );

      return FadeTransition(
        opacity: outgoingFade,
        child: SlideTransition(
          position: incoming,
          child: FadeTransition(
            opacity: incomingFade,
            child: child,
          ),
        ),
      );
    },
  );
}