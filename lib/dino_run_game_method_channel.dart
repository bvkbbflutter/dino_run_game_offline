import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dino_run_game_platform_interface.dart';

/// An implementation of [DinoRunGamePlatform] that uses method channels.
class MethodChannelDinoRunGame extends DinoRunGamePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('dino_run_game');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
