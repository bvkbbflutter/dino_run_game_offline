import 'package:flutter_test/flutter_test.dart';
import 'package:dino_run_game/dino_run_game.dart';
import 'package:dino_run_game/dino_run_game_platform_interface.dart';
import 'package:dino_run_game/dino_run_game_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDinoRunGamePlatform
    with MockPlatformInterfaceMixin
    implements DinoRunGamePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final DinoRunGamePlatform initialPlatform = DinoRunGamePlatform.instance;

  test('$MethodChannelDinoRunGame is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDinoRunGame>());
  });

  test('getPlatformVersion', () async {});
}
