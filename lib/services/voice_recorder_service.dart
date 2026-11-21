import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../models/feature_models.dart';

class VoiceRecorderService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isPaused = false;
  int _elapsedMs = 0;
  String? _currentPath;
  Timer? _timer;

  String? _playingRecordingId;
  bool _isPlaying = false;
  Duration _playPosition = Duration.zero;
  Duration _playDuration = Duration.zero;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  int get elapsedMs => _elapsedMs;
  String? get playingRecordingId => _playingRecordingId;
  bool get isPlaying => _isPlaying;
  Duration get playPosition => _playPosition;
  Duration get playDuration => _playDuration;

  VoiceRecorderService() {
    _player.onPositionChanged.listen((pos) {
      _playPosition = pos;
      notifyListeners();
    });
    _player.onDurationChanged.listen((dur) {
      _playDuration = dur;
      notifyListeners();
    });
    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _playingRecordingId = null;
      _playPosition = Duration.zero;
      notifyListeners();
    });
  }

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> startRecording() async {
    final granted = await requestMicPermission();
    if (!granted) return false;

    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(dir.path, 'voice_notes'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    final fileName = 'voice_${const Uuid().v4()}.m4a';
    final filePath = p.join(audioDir.path, fileName);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    _currentPath = filePath;
    _elapsedMs = 0;
    _isRecording = true;
    _isPaused = false;
    _startTimer();
    notifyListeners();
    return true;
  }

  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    await _recorder.pause();
    _isPaused = true;
    _timer?.cancel();
    notifyListeners();
  }

  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    await _recorder.resume();
    _isPaused = false;
    _startTimer();
    notifyListeners();
  }

  Future<VoiceRecordingModel?> stopAndSaveRecording({
    String? customTitle,
    String? attachedNoteId,
  }) async {
    if (!_isRecording) return null;
    _timer?.cancel();
    final savedPath = await _recorder.stop() ?? _currentPath;
    final duration = _elapsedMs;

    _isRecording = false;
    _isPaused = false;
    _elapsedMs = 0;
    _currentPath = null;
    notifyListeners();

    if (savedPath == null) return null;

    final now = DateTime.now();
    return VoiceRecordingModel(
      id: const Uuid().v4(),
      title: (customTitle != null && customTitle.trim().isNotEmpty)
          ? customTitle.trim()
          : 'Voice Note ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      filePath: savedPath,
      durationMs: duration,
      attachedNoteId: attachedNoteId,
      createdAt: now,
    );
  }

  Future<void> cancelRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop() ?? _currentPath;
    _isRecording = false;
    _isPaused = false;
    _elapsedMs = 0;
    _currentPath = null;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    }
    notifyListeners();
  }

  Future<void> togglePlayback(VoiceRecordingModel recording) async {
    if (_playingRecordingId == recording.id && _isPlaying) {
      await _player.pause();
      _isPlaying = false;
      notifyListeners();
      return;
    }

    if (_playingRecordingId == recording.id && !_isPlaying) {
      await _player.resume();
      _isPlaying = true;
      notifyListeners();
      return;
    }

    await _player.stop();
    final file = File(recording.filePath);
    if (!await file.exists()) return;

    _playingRecordingId = recording.id;
    _playPosition = Duration.zero;
    await _player.play(DeviceFileSource(recording.filePath));
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    _isPlaying = false;
    _playingRecordingId = null;
    _playPosition = Duration.zero;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _elapsedMs += 250;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}
