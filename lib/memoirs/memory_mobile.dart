import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'memory_platform.dart';

class MobileMemoryRecorder extends MemoryPlatform {
  final AudioRecorder _recorder = AudioRecorder();
  String? _audioPath;

  @override
  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _audioPath = path;

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
  }

  @override
  Future<Map<String, String?>> stopRecording() async {
    await _recorder.stop();
    return {'audioPath': _audioPath};
  }

  @override
  void downloadWebAudio(String url) {} // no-op on mobile
}

// ✅ 提供平台專屬的實作函式
MemoryPlatform getPlatformRecorderImpl() => MobileMemoryRecorder();