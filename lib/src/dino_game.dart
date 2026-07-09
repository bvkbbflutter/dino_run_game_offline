import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Main game widget that can be embedded in any Flutter app
///
/// Example:
/// ```dart
/// DinoGame(
///   onGameOver: (score, highScore) => print('Score: $score'),
///   showThemeToggle: true,
/// )
/// ```
class DinoGame extends StatefulWidget {
  /// Callback when the game is over
  final Function(int score, int highScore)? onGameOver;

  /// Callback when score changes
  final Function(int score)? onScoreChanged;

  /// Callback when level changes
  final Function(int level)? onLevelUp;

  /// Whether to show the theme toggle button
  final bool showThemeToggle;

  /// Initial theme mode
  final bool initialDarkMode;

  const DinoGame({
    super.key,
    this.onGameOver,
    this.onScoreChanged,
    this.onLevelUp,
    this.showThemeToggle = true,
    this.initialDarkMode = false,
  });

  @override
  State<DinoGame> createState() => _DinoGameState();
}

class _DinoGameState extends State<DinoGame>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Game state
  late double dinoY;
  double dinoHeight = 60;
  double dinoWidth = 40;
  late double groundY;
  double gravity = 0.6;
  double jumpVelocity = -12;
  double velocity = 0;
  bool isJumping = false;
  int score = 0;
  int highScore = 0;
  bool isGameOver = false;
  bool isGameStarted = false;

  // Level & speed
  int level = 1;
  double displaySpeed = 0;
  bool showLevelUp = false;
  Timer? levelUpTimer;

  // Theme
  bool isDarkMode = false;

  // Animation
  late AnimationController _runController;
  late AnimationController _wingController;
  double runAnimationValue = 0.0;

  // Obstacles
  List<Map<String, dynamic>> obstacles = [];
  double obstacleSpeed = 5.5;
  double lastObstacleTime = 0;
  int frameCount = 0;

  // Game loop
  Timer? gameLoop;
  final Random random = Random();

  // Screen
  double screenWidth = 0;
  double screenHeight = 0;
  bool isInitialized = false;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    isDarkMode = widget.initialDarkMode;

    _runController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _wingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isInitialized) {
      _initializeGame();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _initializeGame() {
    final size = MediaQuery.of(context).size;
    screenWidth = size.width;
    screenHeight = size.height;

    dinoHeight = screenHeight * 0.15;
    dinoWidth = dinoHeight * 0.65;
    groundY = screenHeight * 0.8;
    dinoY = 0;

    gravity = screenHeight * 0.0015;
    jumpVelocity = -(screenHeight * 0.025);
    obstacleSpeed = screenWidth * 0.006;
    displaySpeed = ((obstacleSpeed / screenWidth) * 400).roundToDouble();

    isInitialized = true;
    _startGame();
  }

  void _startGame() {
    _runController.repeat();
    _wingController.repeat(reverse: true);

    gameLoop?.cancel();
    gameLoop = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!isGameOver && isGameStarted) {
        _updateGame();
      }
      if (mounted) setState(() {});
    });
  }

  void _updateGame() {
    frameCount++;

    if (isJumping) {
      velocity += gravity;
      dinoY += velocity;
      if (dinoY >= 0) {
        dinoY = 0;
        isJumping = false;
        velocity = 0;
      }
    }

    for (int i = obstacles.length - 1; i >= 0; i--) {
      obstacles[i]['x'] -= obstacleSpeed;
      if (obstacles[i]['x'] < -obstacles[i]['width'] - 50) {
        obstacles.removeAt(i);
        if (!isGameOver) {
          score += 1;
          if (score > highScore) highScore = score;
          _checkLevelUp();
          widget.onScoreChanged?.call(score);
        }
      }
    }

    double spawnThreshold = 55 - (score / 40).clamp(0.0, 30);
    if (lastObstacleTime > spawnThreshold) {
      _spawnObstacle();
      lastObstacleTime = 0;
    } else {
      lastObstacleTime += 1;
    }

    obstacleSpeed = (screenWidth * 0.006 + (score / 35) * 0.0008).clamp(
      screenWidth * 0.006,
      screenWidth * 0.016,
    );
    displaySpeed = ((obstacleSpeed / screenWidth) * 400).roundToDouble();

    _checkCollisions();
    runAnimationValue = _runController.value;
  }

  void _checkLevelUp() {
    int newLevel = (score / 100).floor() + 1;
    if (newLevel > level) {
      level = newLevel;
      showLevelUp = true;
      levelUpTimer?.cancel();
      levelUpTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => showLevelUp = false);
      });
      HapticFeedback.mediumImpact();
      widget.onLevelUp?.call(level);
    }
  }

  void _spawnObstacle() {
    if (screenWidth == 0) return;

    final double baseX = screenWidth + 50 + random.nextDouble() * 80;
    final bool spawnBird = score > 12 && random.nextDouble() < 0.3;

    if (spawnBird) {
      final double birdHeight = dinoHeight * 0.5;
      final double birdY =
          groundY - dinoHeight * 1.2 - random.nextDouble() * (dinoHeight * 0.6);
      obstacles.add({
        'x': baseX,
        'y': birdY,
        'width': dinoWidth * 0.9,
        'height': birdHeight,
        'type': 'bird',
      });
    } else {
      double height = dinoHeight * (0.6 + random.nextDouble() * 0.5);
      double width = dinoWidth * (0.35 + random.nextDouble() * 0.3);
      final int groupSize = (score > 25 && random.nextDouble() < 0.3) ? 2 : 1;

      for (int i = 0; i < groupSize; i++) {
        obstacles.add({
          'x': baseX + i * (width * 1.6),
          'y': groundY - height,
          'width': width,
          'height': height,
          'type': 'cactus',
        });
      }
    }
  }

  void _checkCollisions() {
    const double dinoX = 50;
    final double dinoLeft = dinoX + dinoWidth * 0.2;
    final double dinoRight = dinoX + dinoWidth * 0.75;
    final double dinoTop = groundY - dinoHeight + dinoY + dinoHeight * 0.13;
    final double dinoBottom = groundY + dinoY - dinoHeight * 0.1;

    for (var obs in obstacles) {
      final double obsLeft = obs['x'];
      final double obsRight = obs['x'] + obs['width'];
      final double obsTop = obs['y'];
      final double obsBottom = obs['y'] + obs['height'];

      if (dinoLeft < obsRight &&
          dinoRight > obsLeft &&
          dinoTop < obsBottom &&
          dinoBottom > obsTop) {
        _gameOver();
        return;
      }
    }
  }

  void jump() {
    if (!isJumping && !isGameOver && isGameStarted) {
      setState(() {
        isJumping = true;
        velocity = jumpVelocity;
      });
      HapticFeedback.mediumImpact();
    }
  }

  void _gameOver() {
    setState(() {
      isGameOver = true;
      isGameStarted = false;
    });
    HapticFeedback.heavyImpact();
    _runController.stop();
    _wingController.stop();
    widget.onGameOver?.call(score, highScore);
  }

  void resetGame() {
    _runController.repeat();
    _wingController.repeat(reverse: true);
    setState(() {
      dinoY = 0;
      velocity = 0;
      isJumping = false;
      score = 0;
      level = 1;
      showLevelUp = false;
      isGameOver = false;
      isGameStarted = false;
      obstacles.clear();
      obstacleSpeed = screenWidth * 0.006;
      displaySpeed = ((obstacleSpeed / screenWidth) * 400).roundToDouble();
      lastObstacleTime = 0;
      frameCount = 0;
    });
  }

  void toggleTheme() {
    setState(() => isDarkMode = !isDarkMode);
  }

  void _handleAction() {
    if (isGameOver) {
      resetGame();
    } else if (!isGameStarted) {
      setState(() => isGameStarted = true);
      _wingController.repeat(reverse: true);
    } else {
      jump();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    gameLoop?.cancel();
    _runController.dispose();
    _wingController.dispose();
    _focusNode.dispose();
    levelUpTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if (isInitialized &&
        (mediaQuery.size.width != screenWidth ||
            mediaQuery.size.height != screenHeight)) {
      _initializeGame();
    }

    if (!isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.arrowUp) {
                _handleAction();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _handleAction,
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -20) {
                _handleAction();
              }
            },
            child: RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Game Canvas
                  CustomPaint(
                    painter: _GamePainter(
                      dinoY: dinoY,
                      dinoHeight: dinoHeight,
                      dinoWidth: dinoWidth,
                      groundY: groundY,
                      obstacles: obstacles,
                      isJumping: isJumping,
                      isGameOver: isGameOver,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                      runAnimationValue: runAnimationValue,
                      wingAnimationValue: _wingController.value,
                      frameCount: frameCount,
                      isDarkMode: isDarkMode,
                    ),
                    size: Size(screenWidth, screenHeight),
                  ),

                  // HUD - Score
                  Positioned(
                    top: screenHeight * 0.03,
                    right: screenWidth * 0.03,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'SCORE $score',
                          style: TextStyle(
                            fontSize: screenWidth * 0.025,
                            fontWeight: FontWeight.w900,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            letterSpacing: 2,
                          ),
                        ),
                        if (highScore > 0)
                          Text(
                            'HI $highScore',
                            style: TextStyle(
                              fontSize: screenWidth * 0.018,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // HUD - Level & Speed
                  Positioned(
                    top: screenHeight * 0.03,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.02,
                              vertical: screenHeight * 0.005,
                            ),
                            decoration: BoxDecoration(
                              color: (isDarkMode ? Colors.black : Colors.white)
                                  .withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'LEVEL $level',
                              style: TextStyle(
                                fontSize: screenWidth * 0.02,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.amberAccent
                                    : Colors.deepOrange,
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          Container(
                            width: screenWidth * 0.15,
                            height: screenHeight * 0.015,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.grey.withOpacity(0.3),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor:
                                  ((obstacleSpeed - screenWidth * 0.006) /
                                          (screenWidth * 0.016 -
                                              screenWidth * 0.006))
                                      .clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.green,
                                      Colors.yellow,
                                      Colors.red,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.005),
                          Text(
                            '${displaySpeed.toInt()} km/h',
                            style: TextStyle(
                              fontSize: screenWidth * 0.016,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Theme toggle
                  if (widget.showThemeToggle)
                    Positioned(
                      top: screenHeight * 0.03,
                      left: screenWidth * 0.03,
                      child: IconButton(
                        icon: Icon(
                          isDarkMode ? Icons.light_mode : Icons.dark_mode,
                          color: isDarkMode ? Colors.white : Colors.black87,
                          size: screenWidth * 0.04,
                        ),
                        onPressed: toggleTheme,
                      ),
                    ),

                  // Level up popup
                  if (showLevelUp)
                    Center(
                      child: AnimatedOpacity(
                        opacity: showLevelUp ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.05,
                            vertical: screenHeight * 0.02,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            '🎉 LEVEL UP!',
                            style: TextStyle(
                              fontSize: screenWidth * 0.06,
                              fontWeight: FontWeight.w900,
                              color: Colors.amberAccent,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Overlays
                  if (!isGameStarted && !isGameOver)
                    _buildOverlay(
                      emoji: '🦖',
                      title: 'DINO RUN',
                      subtitle: 'Tap to Start',
                    ),
                  if (isGameOver)
                    _buildOverlay(
                      emoji: '💀',
                      title: 'GAME OVER',
                      subtitle: 'Score: $score  •  Level: $level',
                      isGameOver: true,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay({
    required String emoji,
    required String title,
    required String subtitle,
    bool isGameOver = false,
  }) {
    return Container(
      color: (isDarkMode ? Colors.black : Colors.white).withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: screenWidth * 0.12)),
            SizedBox(height: screenHeight * 0.03),
            Text(
              title,
              style: TextStyle(
                fontSize: screenWidth * 0.06,
                fontWeight: FontWeight.bold,
                color: isGameOver
                    ? (isDarkMode ? Colors.red[300] : Colors.red[800])
                    : (isDarkMode ? Colors.white : Colors.black87),
              ),
            ),
            if (!isGameOver && highScore > 0) ...[
              SizedBox(height: screenHeight * 0.02),
              Text(
                'Best: $highScore',
                style: TextStyle(
                  fontSize: screenWidth * 0.025,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ],
            SizedBox(height: screenHeight * 0.02),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: screenWidth * 0.028,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
            if (isGameOver && score == highScore && score > 0) ...[
              SizedBox(height: screenHeight * 0.02),
              Text(
                '🏆 NEW HIGH SCORE!',
                style: TextStyle(
                  fontSize: screenWidth * 0.025,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (isGameOver) ...[
              SizedBox(height: screenHeight * 0.05),
              ElevatedButton(
                onPressed: resetGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? Colors.white : Colors.black87,
                  foregroundColor: isDarkMode ? Colors.black87 : Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.06,
                    vertical: screenHeight * 0.025,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'RESTART',
                  style: TextStyle(
                    fontSize: screenWidth * 0.025,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Internal game painter
class _GamePainter extends CustomPainter {
  final double dinoY, dinoHeight, dinoWidth, groundY;
  final List<Map<String, dynamic>> obstacles;
  final bool isJumping, isGameOver, isDarkMode;
  final double screenWidth, screenHeight;
  final double runAnimationValue, wingAnimationValue;
  final int frameCount;

  _GamePainter({
    required this.dinoY,
    required this.dinoHeight,
    required this.dinoWidth,
    required this.groundY,
    required this.obstacles,
    required this.isJumping,
    required this.isGameOver,
    required this.screenWidth,
    required this.screenHeight,
    required this.runAnimationValue,
    required this.wingAnimationValue,
    required this.frameCount,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final time = DateTime.now().millisecondsSinceEpoch;

    // Sky
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDarkMode
          ? [const Color(0xFF0B1A30), const Color(0xFF1E3A5F)]
          : [const Color(0xFF87CEEB), const Color(0xFFE0F7FA)],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, groundY),
      Paint()
        ..shader = skyGradient.createShader(
          Rect.fromLTWH(0, 0, size.width, groundY),
        ),
    );

    _drawMountains(canvas, size, time);
    _drawGround(canvas, size);
    _drawGroundTexture(canvas, size, time);
    _drawClouds(canvas, size, time);
    _drawObstacles(canvas);
    _drawDino(canvas, size);
    if (!isJumping && !isGameOver) _drawDust(canvas, time);
  }

  void _drawMountains(Canvas canvas, Size size, int time) {
    final paint = Paint()
      ..color = isDarkMode ? const Color(0x30FFFFFF) : const Color(0x40B0BEC5);
    final shift = isGameOver ? 0 : (time / 150) % size.width;

    for (int i = 0; i < 3; i++) {
      double baseX = i * size.width * 0.45 + shift - 40;
      double h = size.height * 0.15 + i * 30;
      var path = Path()
        ..moveTo(baseX, groundY)
        ..lineTo(baseX + size.width * 0.1, groundY - h)
        ..lineTo(baseX + size.width * 0.2, groundY);
      canvas.drawPath(path, paint);
    }
  }

  void _drawGround(Canvas canvas, Size size) {
    final groundColor = isDarkMode
        ? const Color(0xFF3E2723)
        : const Color(0xFF8D6E63);
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      Paint()..color = groundColor,
    );
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = isDarkMode ? const Color(0xFF2E7D32) : const Color(0xFF4CAF50)
        ..strokeWidth = 6,
    );
  }

  void _drawGroundTexture(Canvas canvas, Size size, int time) {
    final paint = Paint()
      ..color = isDarkMode ? const Color(0xFF5D4037) : const Color(0xFF6D4C41);
    final step = size.width * 0.06;
    final offset = isGameOver ? 0 : (time / 25) % step;

    for (double x = -30; x < size.width + 30; x += step) {
      canvas.drawRect(
        Rect.fromLTWH(
          x + offset,
          groundY + size.height * 0.02,
          size.width * 0.008,
          size.height * 0.03,
        ),
        paint,
      );
    }
  }

  void _drawClouds(Canvas canvas, Size size, int time) {
    final cloudColor = isDarkMode
        ? Colors.white.withOpacity(0.22)
        : Colors.white.withOpacity(0.9);
    final speed = isGameOver ? 0 : (time / 45) % (size.width * 2);

    for (int i = 0; i < 5; i++) {
      final baseX = (i * size.width * 0.42 + speed) % (size.width * 1.6) - 60;
      final baseY = size.height * 0.06 + (i % 3) * size.height * 0.08;
      final r = size.width * 0.03 + (i % 3) * size.width * 0.01;

      canvas.drawCircle(
        Offset(baseX, baseY),
        r * 0.65,
        Paint()..color = cloudColor,
      );
      canvas.drawCircle(
        Offset(baseX + r * 0.6, baseY - r * 0.35),
        r * 0.75,
        Paint()..color = cloudColor,
      );
      canvas.drawCircle(
        Offset(baseX + r * 1.25, baseY),
        r * 0.6,
        Paint()..color = cloudColor,
      );
    }
  }

  void _drawObstacles(Canvas canvas) {
    for (var obs in obstacles) {
      final x = obs['x'], y = obs['y'], w = obs['width'], h = obs['height'];
      if (obs['type'] == 'bird') {
        _drawBird(canvas, x, y, w, h);
      } else {
        _drawCactus(canvas, x, y, w, h);
      }
    }
  }

  void _drawCactus(Canvas canvas, double x, double y, double w, double h) {
    final color = isGameOver
        ? (isDarkMode ? const Color(0xFF9E9E9E) : const Color(0xFF757575))
        : (isDarkMode ? const Color(0xFF388E3C) : const Color(0xFF2E7D32));
    final Paint paint = Paint()..color = color;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      Radius.circular(w * 0.35),
    );
    canvas.drawRRect(body, paint);

    if (w > 10) {
      final leftBranch = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - w * 0.45, y + h * 0.25, w * 0.45, h * 0.35),
        Radius.circular(w * 0.25),
      );
      final rightBranch = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + w, y + h * 0.45, w * 0.45, h * 0.32),
        Radius.circular(w * 0.25),
      );
      canvas.drawRRect(leftBranch, paint);
      canvas.drawRRect(rightBranch, paint);
    }

    if (!isGameOver && h > 30) {
      final spikePaint = Paint()
        ..color = isDarkMode ? const Color(0xFF1B5E20) : const Color(0xFF1B5E20)
        ..strokeWidth = 1.5;
      for (int i = 1; i < 3; i++) {
        final sy = y + h * i / 3;
        canvas.drawLine(Offset(x + 3, sy), Offset(x + w - 3, sy), spikePaint);
      }
    }
  }

  void _drawBird(Canvas canvas, double x, double y, double w, double h) {
    final bodyColor = isDarkMode
        ? const Color(0xFF90A4AE)
        : const Color(0xFF37474F);
    final Paint paint = Paint()..color = bodyColor;

    canvas.drawOval(Rect.fromLTWH(x, y, w, h * 0.6), paint);
    canvas.drawOval(Rect.fromLTWH(x + 4, y + 3, w * 0.75, h * 0.45), paint);

    final beakPaint = Paint()..color = const Color(0xFFFF9800);
    canvas.drawPath(
      Path()
        ..moveTo(x + w - 2, y + h * 0.35)
        ..lineTo(x + w + 8, y + h * 0.4)
        ..lineTo(x + w - 2, y + h * 0.48)
        ..close(),
      beakPaint,
    );

    double wingAngle = (wingAnimationValue * 0.8 - 0.4);
    canvas.save();
    canvas.translate(x + w * 0.55, y + h * 0.3);
    canvas.rotate(wingAngle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w * 0.4, -h * 0.1, w * 0.7, h * 0.25),
        const Radius.circular(4),
      ),
      paint,
    );
    canvas.restore();
  }

  void _drawDino(Canvas canvas, Size size) {
    final dinoX = 50.0;
    final dinoYPos = groundY - dinoHeight + dinoY;
    final dinoColor = isGameOver
        ? (isDarkMode ? const Color(0xFF9E9E9E) : const Color(0xFF757575))
        : (isDarkMode ? Colors.white : Colors.black);
    final Paint bodyPaint = Paint()..color = dinoColor;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(dinoX + dinoWidth / 2, groundY + size.height * 0.02),
        width: dinoWidth * 0.85,
        height: size.height * 0.015,
      ),
      Paint()..color = Colors.black.withOpacity(isDarkMode ? 0.25 : 0.12),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(dinoX, dinoYPos, dinoWidth, dinoHeight),
        const Radius.circular(6),
      ),
      bodyPaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        dinoX + dinoWidth - dinoWidth * 0.3,
        dinoYPos + dinoHeight * 0.13,
        dinoWidth * 0.35,
        dinoHeight * 0.3,
      ),
      bodyPaint,
    );

    final eyeX = dinoX + dinoWidth - dinoWidth * 0.22;
    final eyeY = dinoYPos + dinoHeight * 0.22;
    canvas.drawCircle(
      Offset(eyeX, eyeY),
      dinoWidth * 0.15,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(eyeX + dinoWidth * 0.06, eyeY + dinoWidth * 0.03),
      dinoWidth * 0.09,
      Paint()..color = isGameOver ? const Color(0xFF9E9E9E) : Colors.black,
    );

    if (isGameOver) {
      canvas.drawLine(
        Offset(
          dinoX + dinoWidth - dinoWidth * 0.33,
          dinoYPos + dinoHeight * 0.38,
        ),
        Offset(
          dinoX + dinoWidth - dinoWidth * 0.1,
          dinoYPos + dinoHeight * 0.45,
        ),
        Paint()
          ..color = isDarkMode ? Colors.grey[400]! : const Color(0xFFBDBDBD)
          ..strokeWidth = 2.5,
      );
    } else {
      canvas.drawArc(
        Rect.fromLTWH(
          dinoX + dinoWidth - dinoWidth * 0.33,
          dinoYPos + dinoHeight * 0.37,
          dinoWidth * 0.28,
          dinoHeight * 0.12,
        ),
        0.2,
        2.7,
        false,
        Paint()..color = Colors.white,
      );
    }

    final legPhase = runAnimationValue * 2 * pi;
    final armPhase = legPhase + 0.8;
    final Paint limbPaint = Paint()..color = dinoColor;

    if (isJumping) {
      canvas.drawRect(
        Rect.fromLTWH(
          dinoX + dinoWidth * 0.18,
          dinoYPos + dinoHeight - dinoHeight * 0.13,
          dinoWidth * 0.22,
          dinoHeight * 0.23,
        ),
        limbPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          dinoX + dinoWidth - dinoWidth * 0.4,
          dinoYPos + dinoHeight - dinoHeight * 0.17,
          dinoWidth * 0.22,
          dinoHeight * 0.2,
        ),
        limbPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          dinoX + dinoWidth * 0.1,
          dinoYPos + dinoHeight * 0.3,
          dinoWidth * 0.17,
          dinoHeight * 0.27,
        ),
        limbPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          dinoX + dinoWidth - dinoWidth * 0.22,
          dinoYPos + dinoHeight * 0.23,
          dinoWidth * 0.17,
          dinoHeight * 0.25,
        ),
        limbPaint,
      );
    } else {
      final legOffset = sin(legPhase) * dinoHeight * 0.1;
      final armOffset = sin(armPhase) * dinoHeight * 0.09;

      canvas.drawRect(
        Rect.fromLTWH(
          dinoX + dinoWidth * 0.15,
          dinoYPos + dinoHeight - dinoHeight * 0.1,
          dinoWidth * 0.21,
          dinoHeight * 0.23 + legOffset,
        ),
        limbPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          dinoX + dinoWidth - dinoWidth * 0.38,
          dinoYPos + dinoHeight - dinoHeight * 0.1,
          dinoWidth * 0.21,
          dinoHeight * 0.23 - legOffset,
        ),
        limbPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          dinoX + dinoWidth * 0.1,
          dinoYPos + dinoHeight * 0.37 + armOffset,
          dinoWidth * 0.15,
          dinoHeight * 0.23,
        ),
        limbPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          dinoX + dinoWidth - dinoWidth * 0.25,
          dinoYPos + dinoHeight * 0.32 - armOffset,
          dinoWidth * 0.15,
          dinoHeight * 0.23,
        ),
        limbPaint,
      );
    }
  }

  void _drawDust(Canvas canvas, int time) {
    if (isGameOver) return;
    final dinoX = 50.0;
    final dustX = dinoX - dinoWidth * 0.2;
    final dustY = groundY;

    for (int i = 0; i < 2; i++) {
      double size = dinoWidth * 0.15 + sin((time / 80 + i) % (2 * pi)) * 2;
      canvas.drawCircle(
        Offset(dustX - i * 4, dustY - size * 0.5),
        size,
        Paint()..color = Colors.brown.withOpacity(0.4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
