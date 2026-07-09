import 'package:flutter/material.dart';
import 'package:dino_run_game/dino_run_game.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dino Run Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? _lastScore;
  int? _lastHighScore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // The game widget - just add this to use it anywhere!
          DinoGame(
            onGameOver: (score, highScore) {
              setState(() {
                _lastScore = score;
                _lastHighScore = highScore;
              });
            },
            onScoreChanged: (score) {
              // You can use this for real-time score updates
            },
            onLevelUp: (level) {
              // Trigger celebrations or effects
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Level $level! 🎉'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            showThemeToggle: true,
            initialDarkMode: false,
          ),

          // Optional: Add your own UI elements on top of the game
          if (_lastScore != null)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Last game: $_lastScore points',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
