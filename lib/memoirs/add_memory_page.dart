import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'memory_platform.dart';
import 'cloudinary_upload.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reorderables/reorderables.dart'; // ← 拖曳排序

Future<bool?> showAddMemoryDialog(
    BuildContext context, {
      required List<String> categories,
      String? targetUid,
    }) {
  return showGeneralDialog<bool>(
    context: context,
    barrierLabel: 'AddMemory',
    barrierDismissible: true,
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, __, ___) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Opacity(
        opacity: curved.value,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: Material( // 保證 TextField 有 Material 上下文
            type: MaterialType.transparency,
            child: AddMemoryDialog(
              categories: categories,
              targetUid: targetUid,
            ),
          ),
        ),
      );
    },
  );
}

class AddMemoryDialog extends StatefulWidget {
  final List<String> categories;
  final String? targetUid;
  const AddMemoryDialog({super.key, required this.categories, this.targetUid});

  @override
  State<AddMemoryDialog> createState() => _AddMemoryDialogState();
}

class _AddMemoryDialogState extends State<AddMemoryDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _desc  = TextEditingController();
  final List<String> _imagePaths = [];
  String? _recordedPath;
  bool _isRecording = false;
  bool _isSaving    = false;

  late final MemoryPlatform _recorder;

  // 分類：未選時為 null（顯示「分類」占位）
  String? _selectedCategory;
  bool _catOpen = false; // 內嵌展開/收起

  // Brand colors
  static const Color _brandBlue  = Color(0xFF5B8EFF);
  static const Color _labelBlue = Color(0xFF1E40AF); // 深藍：標籤用
  static const Color _brandMint  = Color(0xFF49E3D4);
  //static const Color _fieldBlue  = Color(0xFF2A5FD3); // 比背景更深的藍色
  LinearGradient get _brandGradient => const LinearGradient(
    colors: [_brandBlue, _brandMint],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _recorder = getPlatformRecorder();
  }

  // ---- actions ----
  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isNotEmpty) setState(() => _imagePaths.addAll(picked.map((e) => e.path)));
  }

  Future<void> _startRec() async {
    await _recorder.startRecording();
    setState(() => _isRecording = true);
  }

  Future<void> _stopRec() async {
    final r = await _recorder.stopRecording();
    setState(() {
      _recordedPath = r['audioPath'];
      _isRecording  = false;
    });
  }

  Future<void> _playRecording() async {
    if (_recordedPath == null) return;
    final p = AudioPlayer();
    await p.setFilePath(_recordedPath!);
    await p.play();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請輸入回憶標題')));
      return;
    }
    final uid = widget.targetUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('尚未登入')));
      return;
    }

    setState(() => _isSaving = true);

    final List<String> imageUrls = [];
    for (final path in _imagePaths) {
      final url = await uploadFileToCloudinary(File(path), isImage: true);
      if (url != null) imageUrls.add(url);
    }

    String? audioUrl;
    if (_recordedPath != null) {
      audioUrl = await uploadFileToCloudinary(File(_recordedPath!), isImage: false);
    }

    try {
      // 確保 Firestore 也能拿到「其他」
      final category = _selectedCategory ?? '其他';
      await FirebaseFirestore.instance.collection('memories').add({
        'uid'        : uid,
        'title'      : _title.text.trim(),
        'description': _desc.text.trim(),
        'category'   : category,
        'imageUrls'  : imageUrls,
        'audioPath'  : audioUrl,
        'createdAt'  : FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('回憶已儲存')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---- UI helpers ----
  // 左上角的欄位說明文字（深藍）
  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF1E40AF), // 深藍
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  // 白底輸入框（不放 label，只有 hint）
  InputDecoration _whiteFieldBox({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.black45),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );

  Widget _pillButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? fg,
    Color? bg,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        foregroundColor: fg ?? _brandBlue,
        backgroundColor: bg ?? Colors.white,
        disabledForegroundColor: Colors.black38,
        disabledBackgroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        side: BorderSide(
          color: (_isRecording && icon == Icons.mic)
              ? Colors.redAccent
              : _brandBlue.withValues(alpha: .25)
        ),
      ),
    );
  }

  // 更顯眼的主按鈕：白底 + 深藍字 + 描邊與光暈
  Widget _primaryCTA({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x802563EB), blurRadius: 14, offset: Offset(0, 6))],
          border: Border.all(color: const Color(0xFF2563EB), width: 2),
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.save_rounded, color: Color(0xFF2563EB)),
          label: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF1E40AF),
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: .5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  // 縮圖（含刪除與「封面」標籤）
  Widget _thumbTile(int index) {
    final path = _imagePaths[index];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: kIsWeb
              ? Image.network(path, width: 110, height: 110, fit: BoxFit.cover)
              : Image.file(File(path), width: 110, height: 110, fit: BoxFit.cover),
        ),
        if (index == 0)
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: const Text('封面',
                  style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        Positioned(
          right: -8,
          top: -8,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _imagePaths.removeAt(index)),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close, size: 18, color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 內嵌的分類欄位：點擊展開於下方、直向列表，不跳走
  Widget _categoryField(List<String> options) {
    if (!options.contains('其他')) options = [...options, '其他'];
    final placeholder = _selectedCategory == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _catOpen = !_catOpen),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,                     // ← 白底
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    placeholder ? '分類' : _selectedCategory!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: placeholder ? _labelBlue.withValues(alpha: .65) : Colors.black, // ← 深藍 placeholder、選後黑字
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(_catOpen ? Icons.expand_less : Icons.expand_more, color: _labelBlue), // ← 深藍 icon
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: !_catOpen
              ? const SizedBox.shrink()
              : Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: options.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE8E8E8)),
              itemBuilder: (_, i) {
                final c = options[i];
                return ListTile(
                  dense: true,
                  title: Text(c, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                  onTap: () => setState(() { _selectedCategory = c; _catOpen = false; }),
                );
              },
            ),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // 類別清單（顯示用）：補上「其他」
    final List<String> categoryOptions = [
      ...{...widget.categories, '其他'}
    ];

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              decoration: BoxDecoration(
                gradient: _brandGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 12))],
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 標題：白色，與外殼對齊（不加底線）
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        const Text(
                          '建立回憶',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(false),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 表單內容（直接用深藍欄位，已移除黑底）
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _fieldLabel('回憶標題'),
                        TextField(
                          controller: _title,
                          style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
                          decoration: _whiteFieldBox(hint: '給這段回憶取個名字'),
                        ),
                        const SizedBox(height: 12),

                        _fieldLabel('回憶描述'),
                        TextField(
                          controller: _desc,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.black),
                          decoration: _whiteFieldBox(hint: '想記下的細節、感受…'),
                        ),

                        const SizedBox(height: 12),
                        // 內嵌分類（展開直向列表）
                        _categoryField(categoryOptions),
                        const SizedBox(height: 16),

                        // 圖片：可拖曳排序；第一張顯示「封面」
                        if (_imagePaths.isNotEmpty)
                          ReorderableWrap(
                            spacing: 10,
                            runSpacing: 10,
                            needsLongPressDraggable: true,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                final item = _imagePaths.removeAt(oldIndex);
                                _imagePaths.insert(newIndex, item);
                              });
                            },
                            children: List.generate(_imagePaths.length, (i) => _thumbTile(i)),
                          ),
                        if (_imagePaths.isNotEmpty) const SizedBox(height: 10),

                        _pillButton(
                          text: '新增圖片',
                          icon: Icons.add_photo_alternate,
                          onPressed: _pickImages,
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _pillButton(
                                text: _isRecording ? '停止錄音' : '開始錄音',
                                icon: _isRecording ? Icons.stop : Icons.mic,
                                onPressed: _isRecording ? _stopRec : _startRec,
                                fg: _isRecording ? Colors.white : _brandBlue,
                                bg: _isRecording ? Colors.redAccent : Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              // 白底；未有錄音→灰字；有錄音→藍字
                              child: _pillButton(
                                text: '播放錄音',
                                icon: Icons.play_arrow,
                                onPressed: _recordedPath == null ? null : _playRecording,
                                fg: _recordedPath == null ? Colors.black38 : _brandBlue,
                                bg: Colors.white,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // 更顯眼的儲存按鈕（白底深藍字）
                        _primaryCTA(
                          text: _isSaving ? '儲存中…' : '儲存回憶',
                          icon: Icons.save_rounded,
                          onPressed: _isSaving ? null : _save,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}