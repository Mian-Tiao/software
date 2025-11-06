// edit_memory_dialog.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reorderables/reorderables.dart';
import 'memory_platform.dart';
import 'cloudinary_upload.dart';

Future<bool?> showEditMemoryDialog(
    BuildContext context, {
      required String docId,
      required String title,
      required String description,
      required List<String> imagePaths,
      required String audioPath,
      required String category,
      required List<String> categories,
    }) {
  return showGeneralDialog<bool>(
    context: context,
    barrierLabel: 'EditMemory',
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
          child: Material(
            type: MaterialType.transparency,
            child: EditMemoryDialog(
              docId: docId,
              title: title,
              description: description,
              imagePaths: imagePaths,
              audioPath: audioPath,
              category: category,
              categories: categories,
            ),
          ),
        ),
      );
    },
  );
}

class EditMemoryDialog extends StatefulWidget {
  final String docId;
  final String title;
  final String description;
  final List<String> imagePaths;
  final String audioPath;
  final String category;
  final List<String> categories;

  const EditMemoryDialog({
    super.key,
    required this.docId,
    required this.title,
    required this.description,
    required this.imagePaths,
    required this.audioPath,
    required this.category,
    required this.categories,
  });

  @override
  State<EditMemoryDialog> createState() => _EditMemoryDialogState();
}

class _EditMemoryDialogState extends State<EditMemoryDialog> {
  late TextEditingController _title;
  late TextEditingController _desc;
  late List<String> _imagePaths;
  String? _recordedPath;
  bool _isRecording = false;
  bool _isSaving = false;
  late final MemoryPlatform _recorder;

  // 分類（與 AddMemory 同樣：未選時 null 顯示「分類」）
  String? _selectedCategory;
  bool _catOpen = false;

  // Theme
  static const Color _brandBlue = Color(0xFF5B8EFF);
  static const Color _brandMint = Color(0xFF49E3D4);
  static const Color _labelBlue = Color(0xFF0B5ED7); // 深藍標籤色
  LinearGradient get _brandGradient => const LinearGradient(
    colors: [_brandBlue, _brandMint],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _recorder = getPlatformRecorder();
    _title = TextEditingController(text: widget.title);
    _desc = TextEditingController(text: widget.description);
    _imagePaths = [...widget.imagePaths];
    _recordedPath = widget.audioPath.isEmpty ? null : widget.audioPath;

    // 將原本分類帶入；若不是合法選項，設為 null（顯示「分類」）
    final setCats = {...widget.categories, '其他'};
    _selectedCategory = setCats.contains(widget.category) ? widget.category : null;
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
      _isRecording = false;
    });
  }

  Future<void> _playRecording() async {
    if (_recordedPath == null) return;
    final p = AudioPlayer();
    if (_recordedPath!.startsWith('http')) {
      await p.setUrl(_recordedPath!);
    } else {
      await p.setFilePath(_recordedPath!);
    }
    await p.play();
  }

  // 1) 儲存：統一用 _saveMemory()
  Future<void> _saveMemory() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入回憶標題')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // 上傳圖片（保留已是 URL 的）
      final List<String> imageUrls = [];
      for (final path in _imagePaths) {
        if (path.startsWith('http')) {
          imageUrls.add(path);
        } else {
          final url = await uploadFileToCloudinary(File(path), isImage: true);
          if (url != null) imageUrls.add(url);
        }
      }

      // 上傳音檔（本地才上傳）
      String? audioUrl = _recordedPath;
      if (_recordedPath != null && !_recordedPath!.startsWith('http')) {
        final up = await uploadFileToCloudinary(File(_recordedPath!), isImage: false);
        if (up != null) audioUrl = up;
      }

      await FirebaseFirestore.instance
          .collection('memories')
          .doc(widget.docId)
          .update({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'category': _selectedCategory ?? '其他',
        'imageUrls': imageUrls,
        'audioPath': audioUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('回憶已更新')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新失敗，請稍後再試')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除回憶'),
        content: const Text('確定要刪除這則回憶嗎？刪除後無法恢復。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('memories').doc(widget.docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('回憶已刪除')));
      Navigator.of(context).pop(true);
    }
  }

  // ---- UI helpers ----


  Widget _primaryCTA({
    required String text,
    VoidCallback? onPressed,
    IconData icon = Icons.save_rounded,   // ← 新增：可選參數＋預設值
  }) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x802563EB), blurRadius: 14, offset: Offset(0, 6))],
          border: Border.all(color: Color(0xFF2563EB), width: 2),
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: const Color(0xFF2563EB)),   // ← 用呼叫方傳進來的 icon
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

  // 新增：白底紅邊的危險樣式按鈕
  Widget _dangerCTA({required String text, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE11D48), width: 2), // 紅色邊
          boxShadow: const [BoxShadow(color: Color(0x14E11D48), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.delete_outline, color: Color(0xFFE11D48)),
          label: Text(
            text,
            style: const TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6, top: 2),
    child: Text(text, style: const TextStyle(color: _labelBlue, fontWeight: FontWeight.w800)),
  );

  InputDecoration _whiteFieldDeco({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.black38),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
          color: (_isRecording && icon == Icons.mic) ? Colors.redAccent : _brandBlue.withValues(alpha: .25),
        ),
      ),
    );
  }



  // 縮圖（含刪除與「封面」標籤）
  // 取代原本的 _thumbTile
  Widget _thumbTile(int index) {
    final path = _imagePaths[index];
    return SizedBox( // ← 固定尺寸，避免被擠扁
      key: ValueKey('img_$index'),
      width: 110,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? Image.network(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbFallback(),
              )
                  : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbFallback(),
              ),
            ),
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
      ),
    );
  }

  Widget _thumbFallback() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF2F3F5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.broken_image_outlined),
  );


  // 內嵌的分類欄位：點擊展開於下方、直向列表
  Widget _categoryField(List<String> options) {
    if (!options.contains('其他')) options = [...options, '其他'];
    final placeholder = _selectedCategory == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('分類'),
        InkWell(
          onTap: () => setState(() => _catOpen = !_catOpen),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 56,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
                      color: placeholder ? Colors.black38 : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(_catOpen ? Icons.expand_less : Icons.expand_more, color: Colors.black54),
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
                  onTap: () => setState(() {
                    _selectedCategory = c;
                    _catOpen = false;
                  }),
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
    final List<String> categoryOptions = [
      ...{...widget.categories, '其他'}
    ];

    // 2) build(...) 內回傳的整段：加入遮罩 + 修正 ReorderableWrap 的 key + 正確綁 _saveMemory
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Center(
        child: Stack(
          children: [
            // 內容：儲存中不可互動
            AbsorbPointer(
              absorbing: _isSaving,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _brandGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 12))
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 標題（白色）＋關閉
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              const Text(
                                '編輯回憶',
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

                        // 表單（白底欄位＋左上角深藍標籤）
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _label('回憶標題'),
                              TextField(
                                controller: _title,
                                style: const TextStyle(color: Colors.black87),
                                decoration: _whiteFieldDeco(hint: '給這段回憶取個名字'),
                              ),
                              const SizedBox(height: 12),

                              _label('回憶描述'),
                              TextField(
                                controller: _desc,
                                maxLines: 4,
                                style: const TextStyle(color: Colors.black87),
                                decoration: _whiteFieldDeco(hint: '想記下的細節、感受…'),
                              ),
                              const SizedBox(height: 12),

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
                                  // **要有 Key 才能穩定拖曳**
                                  children: List.generate(
                                    _imagePaths.length,
                                        (i) => Container(
                                      key: ValueKey(_imagePaths[i]),
                                      child: _thumbTile(i),
                                    ),
                                  ),
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

                              _primaryCTA(
                                text: _isSaving ? '儲存中…' : '儲存變更',
                                icon: Icons.save_rounded,                   // 可留可不留
                                onPressed: _isSaving ? null : _saveMemory,
                              ),

                              const SizedBox(height: 14),

                              // 刪除（白底邊框紅字）
                              _dangerCTA(text: '刪除回憶', onPressed: _confirmDelete),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 儲存中覆蓋層（居中 Loading）
            if (_isSaving)
              Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          SizedBox(width: 12),
                          Text('儲存中…請勿關閉', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

  }
}