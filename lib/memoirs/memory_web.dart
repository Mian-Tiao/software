// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'memory_platform.dart';

class WebMemoryRecorder extends MemoryPlatform {
  html.MediaRecorder? _mediaRecorder;
  html.MediaStream? _mediaStream;
  final List<html.Blob> _audioChunks = [];
  String? _webAudioUrl;

  @override
  Future<void> startRecording() async {
    _mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});
    if (_mediaStream != null) {
      _audioChunks.clear();
      _mediaRecorder = html.MediaRecorder(_mediaStream!);
      _mediaRecorder!.addEventListener('dataavailable', (event) {
        final e = event as html.BlobEvent;
        if (e.data != null) _audioChunks.add(e.data!);
      });
      _mediaRecorder!.addEventListener('stop', (_) {
        final blob = html.Blob(_audioChunks, 'audio/webm');
        _webAudioUrl = html.Url.createObjectUrl(blob);
        _mediaStream?.getTracks().forEach((track) => track.stop());
        _mediaStream = null;
      });
      _mediaRecorder!.start();
    }
  }

  @override
  Future<Map<String, String?>> stopRecording() async {
    _mediaRecorder?.stop();
    return {'audioPath': _webAudioUrl};
  }

  @override
  void downloadWebAudio(String url) {
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'recorded_audio.webm')
      ..click();
  }
}

// ✅ 提供平台專屬的實作函式
MemoryPlatform getPlatformRecorderImpl() => WebMemoryRecorder();