import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_api_service.dart';

void main() {
  runApp(const NdppApp());
}

class NdppApp extends StatelessWidget {
  const NdppApp({super.key});

  Future<bool> hasToken() async {
    final token = await AuthApiService().getToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'منصة الحماية الرقمية',
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainShell(),
      },
      home: FutureBuilder<bool>(
        future: hasToken(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.data == true) {
            return const MainShell();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}