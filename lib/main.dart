import 'package:flutter/material.dart';
import 'sign_language_app.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BdSL Recognizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          surface: const Color(0xFFFBF8FF),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SignLanguageApp(),
    );
  }
}
