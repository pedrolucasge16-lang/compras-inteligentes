import 'package:flutter/material.dart';

import 'ui/tela_inicial.dart';

void main() {
  runApp(const ComprasApp());
}

class ComprasApp extends StatelessWidget {
  const ComprasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Compras Inteligentes',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6D00)),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const TelaInicial(),
    );
  }
}
