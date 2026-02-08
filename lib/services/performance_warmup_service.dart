import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PerformanceWarmupService {
  static bool _scheduled = false;
  static bool _completed = false;

  static const List<String> _imageAssets = [
    'assets/images/homepage-background.png',
    'assets/images/math_buddy/cosmo.png',
    'assets/images/math_buddy/luna.png',
    'assets/images/math_buddy/pi.jpeg',
  ];

  static const List<String> _audioAssets = [
    'assets/audio/boing.mp3',
    'assets/audio/cheer.mp3',
    'assets/audio/pop.mp3',
  ];

  static void scheduleWarmup(BuildContext context) {
    if (_scheduled || _completed) {
      return;
    }

    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      _warmup(context);
    });
  }

  static Future<void> _warmup(BuildContext context) async {
    try {
      for (final asset in _imageAssets) {
        await precacheImage(AssetImage(asset), context);
      }

      for (final asset in _audioAssets) {
        await rootBundle.load(asset);
      }
    } catch (_) {
      // Best-effort warmup only; runtime loading remains the source of truth.
    } finally {
      _completed = true;
    }
  }
}
