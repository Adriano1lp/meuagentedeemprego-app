import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/models/message_model.dart';
import 'presentation/screens/chat_screen.dart';
import 'presentation/screens/user_registration_screen.dart';
import 'presentation/providers/session_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(MessageModelAdapter());
  await Hive.openBox<MessageModel>('chat_history');
  await Hive.openBox<String>('app_session');

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color _bg = Color(0xFFFFF6E9);
  static const Color _surface = Color(0xFFFDFDF7);
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF4E5566);
  static const Color _pink = Color(0xFFFF5D8F);
  static const Color _blue = Color(0xFF3B82F6);
  static const Color _green = Color(0xFFB6F36A);
  static const Color _orange = Color(0xFFFF8A3D);
  static const Color _border = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.spaceGroteskTextTheme();
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: _pink,
        secondary: _blue,
        tertiary: _green,
        surface: _surface,
        onSurface: _text,
        onPrimary: _text,
        onSecondary: _text,
        error: _orange,
        onError: _text,
      ),
      scaffoldBackgroundColor: _bg,
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(
          color: _text,
          fontSize: 48,
          height: 0.92,
          fontWeight: FontWeight.w800,
          letterSpacing: -2.2,
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          color: _text,
          fontSize: 38,
          height: 0.95,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
        headlineLarge: GoogleFonts.spaceGrotesk(
          color: _text,
          fontSize: 30,
          height: 1.05,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          color: _text,
          fontSize: 24,
          height: 1.08,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: GoogleFonts.spaceGrotesk(
          color: _text,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        titleMedium: GoogleFonts.spaceGrotesk(
          color: _text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.inter(
          color: _text,
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: GoogleFonts.inter(
          color: _muted,
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
        bodySmall: GoogleFonts.inter(
          color: _muted,
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _bg,
        foregroundColor: _text,
        elevation: 0,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: _text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _border, width: 3),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surface,
        contentTextStyle: GoogleFonts.inter(
          color: _text,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _border, width: 3),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        hintStyle: GoogleFonts.inter(
          color: _muted,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _border, width: 3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _border, width: 3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _border, width: 3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _pink,
          foregroundColor: _text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: _border, width: 3),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _text,
          side: const BorderSide(color: _border, width: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
      dividerColor: _border,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agente de Emprego',
      theme: theme,
      home: const AppEntryPoint(),
    );
  }
}

class AppEntryPoint extends ConsumerWidget {
  const AppEntryPoint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return session.hasUser
        ? const ChatScreen()
        : const UserRegistrationScreen();
  }
}
