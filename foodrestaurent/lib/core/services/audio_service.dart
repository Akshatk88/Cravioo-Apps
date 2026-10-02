import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playRefreshSound() async {
    try {
      await _player.play(AssetSource('sound/refersh.mp4'));
    } catch (e) {
      // Ignore errors for sound playback
    }
  }
}
