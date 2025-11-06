import 'dart:io'; // 👈 用來判斷 Android
import 'package:flutter/material.dart';
import '../memoirs/memory_page.dart';
import 'user_task_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:memory/services/notification_service.dart';
import 'package:memory/services/location_uploader.dart';
import 'package:memory/services/mood_service.dart';
import 'package:memory/pages/mood_checkin_sheet.dart';
import '../widgets/home_overview_cards.dart';
import '../widgets/today_summary_panel.dart';
import '../widgets/safety_quick_card.dart';

class MainMenuPage extends StatefulWidget {
  final String userRole;
  const MainMenuPage({super.key, this.userRole = '被照顧者'});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  bool _askedToday = false;
  bool _askedExactAlarmPrompt = false; // 本次啟動僅提示一次

  @override
  void initState() {
    super.initState();
    LocationUploader().start(); // ✅ 啟動位置上傳
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybePromptExactAlarm(); // 👈 權限引導
      await _maybeAskMood();          // 👈 心情打卡
    });
  }

  @override
  void dispose() {
    LocationUploader().stop(); // ✅ 停止監聽位置
    super.dispose();
  }

  // ===== 精準鬧鐘權限引導 =====
  Future<void> _maybePromptExactAlarm() async {
    if (!mounted) return;
    if (!Platform.isAndroid) return;
    if (_askedExactAlarmPrompt) return;
    _askedExactAlarmPrompt = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ExactAlarmPromptSheet(),
    );
  }

  // ===== 心情打卡流程 =====
  Future<void> _maybeAskMood() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final moodService = MoodService(user.uid);
    final already = await moodService.hasCheckedInToday();
    if (!already && !_askedToday) {
      _askedToday = true;

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: false,
        backgroundColor: Colors.transparent,
        builder: (_) => MoodCheckinSheet(
          onSubmit: (mood, note) async {
            await moodService.saveMood(mood, note: note);
            if (!mounted) return;

            if (!context.mounted) return;
            Navigator.pop(context); // 關面板

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已記錄今天的心情')),
            );

            _askToChat(mood, note);
          },
        ),
      );
    }
  }

  void _goToAIWithMood(String mood, [String? note]) {
    final prompt = _promptForMood(mood, note);
    Navigator.pushNamed(context, '/ai', arguments: {
      'initialPrompt': prompt,
      'fromMoodCheckin': true,
      'mood': mood,
      'note': note,
    });
  }

  static const Map<String, String> _moodEmoji = {
    '喜': '😊',
    '怒': '😠',
    '哀': '😢',
    '樂': '😄',
  };

  Future<void> _askToChat(String mood, String? note) async {
    const deepBlue = Color(0xFF0D47A1);
    const brandBlue = Color(0xFF5B8EFF);
    const brandGreen = Color(0xFF49E3D4);

    final emoji = _moodEmoji[mood] ?? '';
    final hasNote = note != null && note.trim().isNotEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 漸層標頭
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    gradient: LinearGradient(
                      colors: [brandBlue, brandGreen],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: const Text(
                    '需要聊聊嗎？',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),

                // 內容
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('你今天的心情：$mood $emoji',
                          style: const TextStyle(fontSize: 18, color: deepBlue, fontWeight: FontWeight.w700)),
                      if (hasNote) ...[
                        const SizedBox(height: 10),
                        const Text('發生了什麼：',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: deepBlue)),
                        const SizedBox(height: 6),
                        Text(note, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // 底部按鈕列
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: deepBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('不用，謝謝',
                              style: TextStyle(fontSize: 16, color: deepBlue, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Ink(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [brandBlue, brandGreen],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            child: const SizedBox(
                              height: 48,
                              child: Center(
                                child: Text('好，現在聊',
                                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      _goToAIWithMood(mood, note);
    }
  }

  String _promptForMood(String mood, [String? note]) {
    final extra = (note == null || note.trim().isEmpty) ? '' : '（補充：$note）';
    switch (mood) {
      case '怒':
        return '我今天有些生氣（怒）$extra。請先幫我釐清觸發點，再用三步驟：1)命名情緒、2)找需求、3)提出一個可行的小行動。語氣溫柔簡短。';
      case '哀':
        return '我今天比較悲傷（哀）$extra。請用同理的語氣，先讓我描述發生什麼，再提供兩個能在10分鐘內完成的自我照顧建議。';
      case '喜':
        return '我今天很開心（喜）$extra！請幫我把好事具體化：發生了什麼、我做了什麼、可以感謝誰？最後提醒我用一句話記錄今天。';
      case '樂':
      default:
        return '我今天心情愉悅（樂）$extra。請跟我聊聊今天最放鬆的時刻，並提供一個能維持好心情的小習慣。';
    }
  }
  /*
  Future<void> _openMoodTester() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('尚未登入，無法測試心情打卡')),
        );
      }
      return;
    }

    final moodService = MoodService(user.uid);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MoodCheckinSheet(
        onSubmit: (mood, note) async {
          await moodService.saveMood(mood, note: note);
          if (!mounted) return;
          if (context.mounted) Navigator.pop(context);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('（測試）已記錄今天的心情')),
            );
          }
          _askToChat(mood, note);
        },
      ),
    );
  }
  */


  // ====== 導頁快捷 ======
  void _openCalendar() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const UserTaskPage()));
  void _openMemories() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const MemoryPage()));
  void _openProfile() => Navigator.pushNamed(context, '/profile');
  void _openAI() => Navigator.pushNamed(context, '/ai');

  // ====== 畫面 ======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFFE0F2F1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),

              const SafetyQuickChip(),
              const SizedBox(height: 12),

              // 中間：2×2 功能區
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _FeatureGrid(
                  onCalendar: _openCalendar,
                  onMemory: _openMemories,
                  onProfile: _openProfile,
                  onAI: _openAI,
                ),
              ),

              const SizedBox(height: 8),

              const TodaySummaryPanel(),
              const SizedBox(height: 12),

              // 下方：橫向速覽卡（你的 OverviewCards）
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    OverviewCards(
                      onOpenAI: _openAI,
                      onOpenCalendar: _openCalendar,
                      onOpenMemories: _openMemories,
                      targetUid: FirebaseAuth.instance.currentUser?.uid, // ✅ 統一 UID
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== Header ======
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final name = data['name'] ?? '使用者';
          final avatarUrl = data['avatarUrl'];

          return Row(
            children: [
              Image.asset('assets/images/memory_icon.png', height: 55),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '您好，$name',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                  onBackgroundImageError: (e, s) {
                    debugPrint('頭像載入失敗: $e');
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* =========================
 *   2×2 功能格（行事曆／回憶錄／個人檔案／AI陪伴）
 * ========================= */
class _FeatureGrid extends StatelessWidget {
  final VoidCallback onCalendar, onMemory, onProfile, onAI;
  const _FeatureGrid({
    required this.onCalendar,
    required this.onMemory,
    required this.onProfile,
    required this.onAI,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <_Tile>[
      _Tile(Icons.calendar_today_rounded, '行事曆', const Color(0xFF5AA9F7), onCalendar),
      _Tile(Icons.photo_album_rounded, '回憶錄', const Color(0xFFBA8ED6), onMemory),
      _Tile(Icons.person_rounded, '個人檔案', const Color(0xFF8AA9F0), onProfile),
      _Tile(Icons.chat_bubble_outline_rounded, 'AI陪伴', const Color(0xFF6AD7D0), onAI),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.6),
      itemBuilder: (context, i) => _FeatureCard(tile: tiles[i]),
    );
  }
}

class _Tile {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _Tile(this.icon, this.label, this.color, this.onTap);
}

class _FeatureCard extends StatelessWidget {
  final _Tile tile;
  const _FeatureCard({required this.tile});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2.5,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: tile.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tile.icon, color: tile.color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tile.label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================
 *   精準鬧鐘權限引導 BottomSheet
 * ========================= */
class _ExactAlarmPromptSheet extends StatelessWidget {
  const _ExactAlarmPromptSheet();

  @override
  Widget build(BuildContext context) {
    const title = '需要允許「精準鬧鐘」';
    const msg = '為了讓背景提醒準時且能在背景產生 AI 回覆並通知你，請在系統中開啟「精準鬧鐘」。';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(msg, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('之後再說'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // 先請通知權限（如果尚未允許）
                    await NotificationService.requestNotificationPermission();
                    // 再帶去精準鬧鐘設定頁（讓使用者手動開）
                    await NotificationService.openExactAlarmSettings();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('前往設定'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
