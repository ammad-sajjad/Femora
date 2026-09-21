import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'api_service.dart';

/// Microphone and speaker access, behind an interface so tests can replace it.
abstract class VoiceDevice {
  Future<bool> ensureMicPermission();
  Future<void> startRecording();
  Future<Uint8List?> stopRecording();
  Future<void> cancelRecording();
  Future<void> play(Uint8List wav);

  /// Reads [text] with the phone's own voice. Returns false when the phone has no voice for that language.
  Future<bool> speakLocal(String text, {required bool urdu});
  Future<void> stopPlayback();
  Stream<void> get playbackComplete;
  void dispose();
}

class PlatformVoiceDevice implements VoiceDevice {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  final StreamController<void> _complete = StreamController<void>.broadcast();
  StreamSubscription<void>? _playerDone;
  bool _ttsReady = false;

  PlatformVoiceDevice() {
    _playerDone = _player.onPlayerComplete.listen((_) => _complete.add(null));
  }

  @override
  Future<bool> ensureMicPermission() => _recorder.hasPermission();

  @override
  Future<void> startRecording() async {
    final dir = await getTemporaryDirectory();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: '${dir.path}/femora_recording.wav',
    );
  }

  @override
  Future<Uint8List?> stopRecording() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    unawaited(file.delete().catchError((_) => file));
    return bytes;
  }

  @override
  Future<void> cancelRecording() async {
    await _recorder.cancel();
  }

  @override
  Future<void> play(Uint8List wav) async {
    // A file is more dependable than in-memory bytes on Android phones.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/femora_reply.wav');
    await file.writeAsBytes(wav, flush: true);
    await _player.play(DeviceFileSource(file.path));
  }

  @override
  Future<bool> speakLocal(String text, {required bool urdu}) async {
    try {
      if (!_ttsReady) {
        _ttsReady = true;
        _tts.setCompletionHandler(() => _complete.add(null));
        _tts.setCancelHandler(() => _complete.add(null));
        _tts.setErrorHandler((_) => _complete.add(null));
      }
      final lang = urdu ? 'ur-PK' : 'en-US';
      final available = await _tts.isLanguageAvailable(lang);
      if (available != true && available != 1) return false;
      await _tts.setLanguage(lang);
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      final started = await _tts.speak(text);
      return started == 1 || started == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stopPlayback() async {
    await _player.stop();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Stream<void> get playbackComplete => _complete.stream;

  @override
  void dispose() {
    _playerDone?.cancel();
    _complete.close();
    _recorder.dispose();
    _player.dispose();
    _tts.stop();
  }
}

enum VoicePhase { idle, recording, transcribing, speaking }

/// Push-to-talk voice: record, transcribe on the server, and read answers aloud.
class VoiceController extends ChangeNotifier {
  static const maxRecording = Duration(seconds: 45);

  final ApiService _api;
  final VoiceDevice? _injected;

  VoiceController({ApiService? api, VoiceDevice? device})
      : _api = api ?? ApiService(),
        _injected = device;

  // The microphone and speaker are only created when voice is first used
  VoiceDevice? _deviceInstance;
  StreamSubscription<void>? _done;

  VoiceDevice get _device => _deviceInstance ??= _createDevice();

  VoiceDevice _createDevice() {
    final d = _injected ?? PlatformVoiceDevice();
    _done = d.playbackComplete.listen((_) {
      if (_phase == VoicePhase.speaking) _set(VoicePhase.idle);
    });
    return d;
  }

  Timer? _limit;

  VoicePhase _phase = VoicePhase.idle;
  VoicePhase get phase => _phase;

  String? _error;
  String? get error => _error;

  /// Read every companion answer aloud (also switched on automatically after a spoken question).
  bool readAloud = false;

  void _set(VoicePhase p) {
    _phase = p;
    notifyListeners();
  }

  void setReadAloud(bool value) {
    readAloud = value;
    if (!value) stopSpeaking();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Starts recording; returns false (with [error] set) if the microphone is not allowed.
  Future<bool> startListening() async {
    if (_phase != VoicePhase.idle) return false;
    _error = null;
    try {
      if (!await _device.ensureMicPermission()) {
        _error = 'Allow the microphone for Femora in your phone settings to talk to the companion.';
        notifyListeners();
        return false;
      }
      await _device.stopPlayback();
      await _device.startRecording();
    } catch (_) {
      _error = 'Could not start the microphone. Please type your question instead.';
      notifyListeners();
      return false;
    }
    _set(VoicePhase.recording);
    _limit = Timer(maxRecording, () => stopAndTranscribe(language: 'auto'));
    return true;
  }

  /// Stops recording and returns the transcript (null if nothing was understood; [error] then says why).
  Future<String?> stopAndTranscribe({required String language}) async {
    if (_phase != VoicePhase.recording) return null;
    _limit?.cancel();
    _set(VoicePhase.transcribing);
    try {
      final wav = await _device.stopRecording();
      if (wav == null || wav.length < 1600) {
        _error = 'I did not catch that. Hold the mic a little longer and try again.';
        return null;
      }
      final text = await _api.transcribe(wav, language: language);
      if (text.isEmpty) {
        _error = 'I could not hear any speech. Please try again in a quieter place.';
        return null;
      }
      return text;
    } on ApiException catch (e) {
      _error = e.message;
      return null;
    } catch (_) {
      _error = 'Something went wrong with the recording. Please type your question instead.';
      return null;
    } finally {
      _set(VoicePhase.idle);
    }
  }

  Future<void> cancelListening() async {
    _limit?.cancel();
    if (_phase == VoicePhase.recording) {
      try {
        await _device.cancelRecording();
      } catch (_) {}
      _set(VoicePhase.idle);
    }
  }

  static final _urduScript = RegExp(r'[؀-ۿ]');

  /// Reads [text] aloud, then falls back to the other voice if the first one cannot speak.
  ///
  /// [natural] picks which voice is tried first. The AI voice sounds better but has to be generated by the
  /// server: measured at about 5 seconds for one sentence and 16 for a paragraph, which is far too long to
  /// wait after every spoken question. So an answer that is read out automatically uses the phone's own
  /// voice, which starts at once and costs nothing, and the speaker button on a message asks for the AI
  /// voice on purpose. Failures are reported through [error] and never block the chat.
  Future<void> speak(String text, {required String language, bool natural = true}) async {
    if (_phase == VoicePhase.recording || _phase == VoicePhase.transcribing) return;
    _error = null;
    _set(VoicePhase.speaking);
    final urdu = language == 'ur' || (language != 'en' && _urduScript.hasMatch(text));

    if (!natural) {
      if (await _device.speakLocal(text, urdu: urdu)) return; // stays "speaking" until the phone voice finishes
      if (_phase != VoicePhase.speaking) return;
    }

    String failure;
    try {
      final wav = await _api.speak(text, language: language);
      if (_phase != VoicePhase.speaking) return; // stopped while the voice was being prepared
      await _device.play(wav);
      return;
    } on ApiException catch (e) {
      failure = e.message;
    } catch (_) {
      failure = 'Could not play the voice. Please read the text instead.';
    }
    if (_phase != VoicePhase.speaking) return;
    if (natural && await _device.speakLocal(text, urdu: urdu)) return;
    if (_phase != VoicePhase.speaking) return;
    _error = urdu ? '$failure This phone also has no Urdu voice installed.' : failure;
    _set(VoicePhase.idle);
  }

  Future<void> stopSpeaking() async {
    if (_phase == VoicePhase.speaking) {
      try {
        await _device.stopPlayback();
      } catch (_) {}
      _set(VoicePhase.idle);
    }
  }

  @override
  void dispose() {
    _limit?.cancel();
    _done?.cancel();
    _deviceInstance?.dispose();
    super.dispose();
  }
}
