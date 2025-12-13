import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // 為了 Clipboard
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:memory/services/location_uploader.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  String _role = '';
  String? _uid;
  String? _identityCode;
  String? _avatarUrl;
  bool _isLoading = true;
  bool _locationEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();

    _roleController.text = _role == 'caregiver' ? '照顧者' : '被照顧者';
  }

  /// ✅ 從 Firestore 讀取個人資料
  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _uid = user.uid;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _role = data['role'] ?? '';
          _identityCode = data['identityCode'] ?? '';
          _avatarUrl = data['avatarUrl']; // ✅ 可能為 null
          _locationEnabled = data['locationEnabled'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ 讀取個人資料失敗')),
        );
      }
    }
  }

  /// ✅ 儲存名稱 & 身分
  Future<void> _saveProfile() async {
    if (_uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(_uid).set({
      'name': _nameController.text.trim(),
      'role': _role,
      'locationEnabled': _locationEnabled, // ✅ 加這行
    }, SetOptions(merge: true));

    if (_locationEnabled) {
      LocationUploader().start();
    } else {
      LocationUploader().stop();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 資料已儲存')),
      );
    }
  }

  /// ✅ 登出功能
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    // 等待一點點時間避免 race condition
    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  /// ✅ 選擇圖片並上傳 Cloudinary
  Future<void> _pickAndUploadAvatar() async {
    // Step 1: 選擇圖片
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null) return;

    Uint8List? imageBytes;

    if (kIsWeb) {
      imageBytes = result.files.first.bytes;
    } else {
      File file = File(result.files.first.path!);
      imageBytes = await file.readAsBytes();
    }

    // ✅ 防呆：確保一定有圖片
    if (imageBytes == null) {
      debugPrint('❌ 無法取得圖片 bytes');
      return;
    }

    if (!mounted) return; // ✅ 避免 async gap 後使用 context 出錯

    // Step 2: 打開裁切對話框
    await showDialog(
      context: context,
      builder: (dialogContext) {   // ✅ 避免 async gap 直接用 context
        final cropController = CropController();

        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            height: 500,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Text('裁剪頭像', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Expanded(
                  child: Crop(
                    controller: cropController,
                    image: imageBytes!,   // ✅ 這裡已經保證是 Uint8List
                    aspectRatio: 1,      // ✅ 正方形頭像
                    onCropped: (result) async {
                      Navigator.pop(dialogContext);

                      if (result is CropSuccess) {
                        // ✅ 拿到裁切後的圖片 bytes
                        Uint8List croppedBytes = result.croppedImage;

                        // Step 3: Mobile 用暫存檔
                        File? tempFile;
                        if (!kIsWeb) {
                          final tempDir = await getTemporaryDirectory();
                          tempFile = File('${tempDir.path}/avatar.png');
                          await tempFile.writeAsBytes(croppedBytes);
                        }

                        // Step 4: 上傳到 Cloudinary
                        String? url;
                        if (kIsWeb) {
                          url = await uploadBytesToCloudinary(croppedBytes, 'avatar.png');
                        } else {
                          url = await uploadFileToCloudinary(tempFile!, isImage: true);
                        }

                        // Step 5: Firestore 更新
                        if (url != null && mounted) {
                          setState(() => _avatarUrl = url);
                          await FirebaseFirestore.instance.collection('users').doc(_uid).set({
                            'avatarUrl': url,
                          }, SetOptions(merge: true));
                        }
                      } else {
                        debugPrint('❌ 裁剪失敗: $result');
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => cropController.crop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('完成裁剪'),
                )
              ],
            ),
          ),
        );
      },
    );
  }



  Future<String?> uploadBytesToCloudinary(Uint8List bytes, String fileName) async {
    const cloudName = 'dux2hhtb5';
    const uploadPreset = 'memoirs';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
    )
      ..fields['upload_preset'] = uploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final response = await request.send();
    final resBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(resBody);
      return data['secure_url'];
    } else {
      debugPrint('❌ Cloudinary 錯誤: $resBody');
      return null;
    }
  }

  /// ✅ 上傳檔案到 Cloudinary
  Future<String?> uploadFileToCloudinary(File file, {required bool isImage}) async {
    const cloudName = 'dux2hhtb5';
    const uploadPreset = 'memoirs';
    final resourceType = isImage ? 'image' : 'video';

    final uploadUrl = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');

    final mimeType = isImage ? 'image/jpeg' : 'audio/m4a';

    final request = http.MultipartRequest('POST', uploadUrl)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(mimeType),
      ));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = json.decode(responseBody);
      return data['secure_url'];
    } else {
      debugPrint('❌ Cloudinary 錯誤: $responseBody');
      return null;
    }
  }

  /// ✅ 顯示唯一識別碼（可長按複製）
  Widget _buildIdentityCodeField() {
    return _identityCode == null || _identityCode!.isEmpty
        ? const SizedBox.shrink()
        : GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: _identityCode!));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已複製識別碼')),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('唯一識別碼（長按可複製）',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              _identityCode!,
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF4FC3F7);
    const backgroundGradient = LinearGradient(
      colors: [Color(0xFFE0F7FA), Color(0xFFE0F2F1)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('個人檔案'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: backgroundGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                /// ✅ 頭像（置中）
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                            ? NetworkImage(_avatarUrl!)
                            : const AssetImage('assets/images/default_avatar.png')
                        as ImageProvider,
                      ),
                      GestureDetector(
                        onTap: _pickAndUploadAvatar,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(0, 0, 0, 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.camera_alt, size: 20, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                /// ✅ 名稱輸入框
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.black, fontSize: 20),
                  decoration: const InputDecoration(
                    labelText: '名稱',
                    labelStyle: TextStyle( // 🔸 加這段讓 label 更明顯
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),

                /// ✅ 顯示身分
                TextFormField(
                  controller: _roleController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: '身分',
                    labelStyle: TextStyle( // 🔸 加這段讓 label 更明顯
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(color: Colors.black, fontSize: 20),
                ),

                /// ✅ 唯一識別碼（長按複製）
                _buildIdentityCodeField(),

                const SizedBox(height: 32),

                /// ✅ 位置開關
                SwitchListTile(
                  value: _locationEnabled,
                  onChanged: (value) => setState(() => _locationEnabled = value),
                  title: const Text(
                    '啟用位置上傳',
                    style: TextStyle(color: Colors.black, fontSize: 20),
                  ),
                  subtitle: const Text(
                      '開啟後照顧者可查看您的即時位置',
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                  activeColor: themeColor,
                ),

                const SizedBox(height: 20),

                /// ✅ 儲存按鈕
                ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: const Text('儲存變更', style: TextStyle(fontSize: 16)),
                ),

                const SizedBox(height: 16),

                /// 🔴 登出按鈕
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('登出', style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
