import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';
import 'package:ludo/ludo.dart';

/// Runs the Ludo module on its own.
void main() {
  runApp(const LudoExampleApp());
}

class LudoExampleApp extends StatelessWidget {
  const LudoExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Race Board',
      debugShowCheckedModeBanner: false,
      theme: KitTheme.data(),
      home: const LudoGame(),
    );
  }
}
