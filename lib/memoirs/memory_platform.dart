// 平台切換主檔，不能用 external！
import 'memory_web.dart'
if (dart.library.io) 'memory_mobile.dart';

abstract class MemoryPlatform {
  Future<void> startRecording();
  Future<Map<String, String?>> stopRecording();
  void downloadWebAudio(String url) {}
}

// ✅ 這裡會依平台決定使用 web 或 mobile 的實作
MemoryPlatform getPlatformRecorder() => getPlatformRecorderImpl();