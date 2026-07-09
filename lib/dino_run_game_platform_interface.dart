import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dino_run_game_method_channel.dart';

abstract class DinoRunGamePlatform extends PlatformInterface {
  /// Constructs a DinoRunGamePlatform.
  DinoRunGamePlatform() : super(token: _token);

  static final Object _token = Object();

  static DinoRunGamePlatform _instance = MethodChannelDinoRunGame();

  /// The default instance of [DinoRunGamePlatform] to use.
  ///
  /// Defaults to [MethodChannelDinoRunGame].
  static DinoRunGamePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DinoRunGamePlatform] when
  /// they register themselves.
  static set instance(DinoRunGamePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
