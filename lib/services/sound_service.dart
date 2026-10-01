import 'package:audioplayers/audioplayers.dart';

/// Service for playing sound effects during scanning
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  AudioPlayer? _audioPlayer;

  /// Get or create audio player instance
  AudioPlayer get _player {
    _audioPlayer ??= AudioPlayer();
    return _audioPlayer!;
  }

  /// Play success sound (valid student scanned)
  Future<void> playSuccess() async {
    try {
      await _player.stop(); // Stop any currently playing sound
      await _player.setVolume(1.0); // Set volume to maximum (100%)
      await _player.play(AssetSource('sounds/success.wav'));
    } catch (e) {
      // If playback fails, try recreating the player
      print('Sound playback failed: $e');
      _audioPlayer?.dispose();
      _audioPlayer = null;
      // Retry once with fresh player
      try {
        await _player.setVolume(1.0);
        await _player.play(AssetSource('sounds/success.wav'));
      } catch (retryError) {
        print('Sound retry failed: $retryError');
      }
    }
  }

  /// Play error sound (unknown code)
  Future<void> playError() async {
    try {
      await _player.stop();
      await _player.setVolume(1.0); // Set volume to maximum (100%)
      await _player.play(AssetSource('sounds/error.mp3'));
    } catch (e) {
      print('Sound playback failed: $e');
      _audioPlayer?.dispose();
      _audioPlayer = null;
      try {
        await _player.setVolume(1.0);
        await _player.play(AssetSource('sounds/error.mp3'));
      } catch (retryError) {
        print('Sound retry failed: $retryError');
      }
    }
  }

  /// Play duplicate sound (student already scanned)
  Future<void> playDuplicate() async {
    try {
      await _player.stop();
      await _player.setVolume(1.0); // Set volume to maximum (100%)
      await _player.play(AssetSource('sounds/duplicate.mp3'));
    } catch (e) {
      print('Sound playback failed: $e');
      _audioPlayer?.dispose();
      _audioPlayer = null;
      try {
        await _player.setVolume(1.0);
        await _player.play(AssetSource('sounds/duplicate.mp3'));
      } catch (retryError) {
        print('Sound retry failed: $retryError');
      }
    }
  }

  /// Release audio player resources (but allow recreation)
  void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}
