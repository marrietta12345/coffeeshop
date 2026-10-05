import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'pages/welcome_page.dart';
import 'pages/sign_in_page.dart';
import 'pages/sign_up_page.dart';
import 'pages/main_nav_page.dart';
import 'widgets/mobile_frame.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase — Auth + Firestore, unchanged.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Supabase — used exclusively for image storage (shop gallery, logos,
  // best-seller item photos). Not used for auth or any database data;
  // Firebase Auth + Firestore remain the source of truth for everything
  // except image files.
  await Supabase.initialize(
    url: 'https://mltdmmpyjdnjxfdxsmyg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRtbXB5amRuanhmZHhzbXlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODczNjk2NTEsImV4cCI6MjEwMjk0NTY1MX0.HURPu68Oki2wvcuoOeQDYwv2kzBmgt9VjMXvUuWAKnc',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kafelo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFA67C5B),
        ),
        useMaterial3: true,
      ),
      // Mobile layout guard: capped text scaling + a phone-width column on
      // landscape phones and tablets (see MobileFrame).
      builder: (context, child) => MobileFrame(child: child ?? const SizedBox.shrink()),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/signin': (context) => const SignInPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const MainNavPage(),
      },
    );
  }
}