import 'package:flutter/material.dart';
import 'screens/conversor_screen.dart';

void main() {
  runApp(const CuantoesApp());
}

class CuantoesApp extends StatelessWidget {
  const CuantoesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tasa BCV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ConversorScreen(),
    );
  }
}
