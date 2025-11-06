// lib/helpers/platform_image.dart
import 'dart:typed_data';
import 'dart:io' show File;

class PlatformImage {
  final File? file;
  final Uint8List? bytes;

  PlatformImage({this.file, this.bytes});
}