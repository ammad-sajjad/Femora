import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../models/pulse.dart';

/// Where pulse samples come from. The camera in the app, a fake in tests.
abstract class PulseSource {
  bool get isSupported;

  /// Starts streaming samples; returns an error message instead when the camera cannot be used.
  Future<String?> start(void Function(PulseSample) onSample);

  Future<void> stop();
}

/// The phone's rear camera with the flash on as a torch; each frame is reduced to the average red and green of its centre.
class CameraPulseSource implements PulseSource {
  CameraController? _controller;
  final _clock = Stopwatch();

  @override
  bool get isSupported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<String?> start(void Function(PulseSample) onSample) async {
    try {
      final cameras = await availableCameras();
      final back = cameras.where((c) => c.lensDirection == CameraLensDirection.back).toList();
      if (back.isEmpty) return 'This phone has no rear camera.';
      final c = CameraController(back.first, ResolutionPreset.low, enableAudio: false,
          imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420);
      _controller = c;
      await c.initialize();
      try {
        await c.setFlashMode(FlashMode.torch);
      } catch (_) {
        return 'This phone\'s flash cannot stay on, so the pulse cannot be read.';
      }
      _clock
        ..reset()
        ..start();
      await c.startImageStream((img) {
        final s = _reduce(img);
        if (s != null) onSample(PulseSample(_clock.elapsedMicroseconds / 1e6, s.$1, s.$2));
      });
      return null;
    } on CameraException catch (e) {
      await stop();
      return e.code.contains('Denied') || e.code.contains('denied')
          ? 'Femora needs the camera to read your pulse. Please allow camera access in your phone settings.'
          : 'The camera could not start (${e.code}). Please try again.';
    } catch (_) {
      await stop();
      return 'The camera could not start. Please try again.';
    }
  }

  /// Average red and green over the central half of the frame, sampling every 4th pixel.
  static (double, double)? _reduce(CameraImage img) {
    final w = img.width, h = img.height;
    var r = 0.0, g = 0.0, n = 0;
    if (img.format.group == ImageFormatGroup.yuv420 && img.planes.length >= 3) {
      final y = img.planes[0], u = img.planes[1], v = img.planes[2];
      final uvPixel = u.bytesPerPixel ?? 1;
      for (var row = h ~/ 4; row < 3 * h ~/ 4; row += 4) {
        for (var col = w ~/ 4; col < 3 * w ~/ 4; col += 4) {
          final yy = y.bytes[row * y.bytesPerRow + col].toDouble();
          final uvIndex = (row ~/ 2) * u.bytesPerRow + (col ~/ 2) * uvPixel;
          final uu = u.bytes[uvIndex] - 128.0, vv = v.bytes[uvIndex] - 128.0;
          r += yy + 1.402 * vv;
          g += yy - 0.344 * uu - 0.714 * vv;
          n++;
        }
      }
    } else if (img.format.group == ImageFormatGroup.bgra8888) {
      final p = img.planes[0];
      for (var row = h ~/ 4; row < 3 * h ~/ 4; row += 4) {
        for (var col = w ~/ 4; col < 3 * w ~/ 4; col += 4) {
          final i = row * p.bytesPerRow + col * 4;
          g += p.bytes[i + 1];
          r += p.bytes[i + 2];
          n++;
        }
      }
    }
    return n == 0 ? null : (r / n, g / n);
  }

  @override
  Future<void> stop() async {
    final c = _controller;
    _controller = null;
    _clock.stop();
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
      await c.setFlashMode(FlashMode.off);
    } catch (_) {}
    await c.dispose();
  }
}
