// lib/widgets/mood_checkin_sheet.dart  或  lib/pages/mood_checkin_sheet.dart
import 'package:flutter/material.dart';

class MoodCheckinSheet extends StatefulWidget {
  final void Function(String mood, String? note) onSubmit;
  const MoodCheckinSheet({super.key, required this.onSubmit});

  @override
  State<MoodCheckinSheet> createState() => _MoodCheckinSheetState();
}

class _MoodCheckinSheetState extends State<MoodCheckinSheet> {
  final TextEditingController _ctrl = TextEditingController();
  String? _selectedMood; // ✅ 使用者選擇但尚未送出的心情

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const deepBlue = Color(0xFF0D47A1);
    const brandBlue = Color(0xFF5B8EFF);

    final items = const [
      {'label': '喜', 'emoji': '😊'},
      {'label': '怒', 'emoji': '😠'},
      {'label': '哀', 'emoji': '😢'},
      {'label': '樂', 'emoji': '😄'},
    ];

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 標題 + 右上角 完成
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '今天的心情是？',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: deepBlue,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: (_selectedMood == null)
                            ? null
                            : () {
                          FocusScope.of(context).unfocus();
                          final note = _ctrl.text.trim();
                          widget.onSubmit(
                            _selectedMood!,
                            note.isEmpty ? null : note,
                          );
                        },
                        child: const Text(
                          '完成',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: deepBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 4 個表情（可自動換行），選到會有藍色外框
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: items.map((m) {
                      final label = m['label']!;
                      final selected = _selectedMood == label;
                      return SizedBox(
                        width: (MediaQuery.of(context).size.width - 20*2 - 12*3)/4,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected ? brandBlue : Colors.transparent,
                              width: selected ? 3 : 3, // 保持高度一致
                            ),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: brandBlue,
                              foregroundColor: Colors.white,
                              elevation: selected ? 4 : 2,
                            ),
                            onPressed: () {
                              setState(() => _selectedMood =
                              selected ? null : label); // 點同一顆可取消
                            },
                            child: Column(
                              children: [
                                Text(m['emoji']!, style: const TextStyle(fontSize: 30)),
                                const SizedBox(height: 8),
                                Text(label, style: const TextStyle(fontSize: 18)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 可選的一句話
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '發生了什麼：（可不填）',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: deepBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.done,
                    maxLines: 2,
                    minLines: 1,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: '想補充一句嗎？（例如：和家人吃飯很開心 / 通勤塞車心很煩）',
                      filled: true,
                      fillColor: const Color(0xFFF5F7FB),
                      hintStyle: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF5E6A7D), // 提示字顏色更深
                      ),
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0E6F1)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: brandBlue, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    _selectedMood == null
                        ? '（請先選擇一個心情，再點右上角「完成」）'
                        : '（已選擇：$_selectedMood）',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
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