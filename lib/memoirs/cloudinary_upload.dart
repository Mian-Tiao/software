import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart'; // ⬅️ 需要加入 mime 套件：mime: ^1.0.4

Future<String?> uploadFileToCloudinary(File file, {required bool isImage}) async {
  const cloudName = 'dux2hhtb5';
  const uploadPreset = 'memoirs';
  final resourceType = isImage ? 'image' : 'video'; // Cloudinary 對音訊用 video 上傳

  final uploadUrl = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');

  final mimeStr = lookupMimeType(file.path) ?? (isImage ? 'image/jpeg' : 'audio/m4a');
  final mimeSplit = mimeStr.split('/');
  final mimeType = MediaType(mimeSplit[0], mimeSplit[1]);

  final request = http.MultipartRequest('POST', uploadUrl)
    ..fields['upload_preset'] = uploadPreset
    ..files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: mimeType,
    ));

  final response = await request.send();
  final responseBody = await response.stream.bytesToString();

  if (response.statusCode == 200) {
    final data = json.decode(responseBody);
    return data['secure_url'];
  } else {
    return null;
  }
}