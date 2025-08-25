import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:toastification/toastification.dart';

void main() {
  runApp(
    ToastificationWrapper( 
      child: const MyApp(),
    ),
  );  
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}
