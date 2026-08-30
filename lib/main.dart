import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'theme/neu_theme.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BdSL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: NeuColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: NeuColors.accent,
          surface: NeuColors.background,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
