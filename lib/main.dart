import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  await DatabaseService.instance.database;
  runApp(const ComprasInteligentesApp());
}

class ComprasInteligentesApp extends StatelessWidget {
  const ComprasInteligentesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Compras Inteligentes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
