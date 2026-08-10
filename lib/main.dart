import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sign_language_app.dart';
import 'theme/neu_theme.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BdSL Recognizer',
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
      home: const SignLanguageApp(),
    );
  }
}
