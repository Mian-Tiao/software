import 'package:flutter/material.dart';
import 'package:memory/services/ai_companion_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// 👇 新增：通知服務
import 'package:memory/services/notification_service.dart';

bool _sending = false;

class AICompanionPage extends StatefulWidget {
  const AICompanionPage({super.key});

  @override
  State<AICompanionPage> createState() => _AICompanionPageState();
}

// 👇 新增：生命週期觀察，不改 UI
class _AICompanionPageState extends State<AICompanionPage> with WidgetsBindingObserver {
  final AICompanionService _service = AICompanionService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  final List<String> _fixedPrompts = ['幫助我回憶', '提醒我今天要做的事'];
  Timer? _reminderTimer;
  bool _isLoading = false;
  bool _bootstrapped = false; // ✅ 避免重複觸發開場訊息

  // 👇 新增：記錄前景/背景狀態
  AppLifecycleState _life = AppLifecycleState.resumed;
  bool get _inForeground => _life == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    // 👇 新增：掛上觀察者（不改 UI）
    WidgetsBinding.instance.addObserver(this);
    _loadPreviousMessages();
    _startReminderLoop();
  }

  // 👇 新增：更新目前是否在前景
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _life = state;
  }

  void _startReminderLoop() {
    _reminderTimer?.cancel();

    // 先跑一次（進頁就能提醒）
    Future.microtask(() async {
      final tip = await _service.taskReminderText();
      if (tip != null && mounted) {
        setState(() => _messages.add({'role': 'ai', 'text': tip}));
        await _service.speak(tip);
        await _scrollToBottom();

        // 👇 新增：只有在背景時才推通知，避免在頁面內被騷擾
        if (!_inForeground) {
          final body = tip.length > 100 ? '${tip.substring(0, 100)}…' : tip;
          await NotificationService.showNow(
            id: 61000 + DateTime.now().minute,
            title: '提醒你今天的任務',
            body: body,
            payload: 'route:/ai',
          );
        }
      }
    });

    // 每 1 分鐘檢查一次
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final tip = await _service.taskReminderText();
      if (tip != null && mounted) {
        setState(() => _messages.add({'role': 'ai', 'text': tip}));
        await _service.speak(tip);
        await _scrollToBottom();

        // 👇 新增：背景才推通知
        if (!_inForeground) {
          final body = tip.length > 100 ? '${tip.substring(0, 100)}…' : tip;
          await NotificationService.showNow(
            id: 61000 + DateTime.now().minute,
            title: '提醒你今天的任務',
            body: body,
            payload: 'route:/ai',
          );
        }
      }
    });
  }

  // ✅ 讀取路由參數：若是從心情打卡過來，主動發送「關懷開場」
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final fromMood = args?['fromMoodCheckin'] == true;
    final mood = args?['mood'] as String?;
    final note = args?['note'] as String?;
    final initialPrompt = args?['initialPrompt'] as String?;

    if (fromMood && (mood != null || (note != null && note.trim().isNotEmpty))) {
      _sendCaringStarterFromMood(mood: mood, note: note);
    } else if (initialPrompt != null && initialPrompt.trim().isNotEmpty) {
      // 如果不是從心情來、但外部仍有 initialPrompt，就照舊發送
      _sendMessage(initialPrompt);
    }
  }

  /// ✅ 給 AI 的關懷開場（不顯示使用者泡泡，只顯示 AI 關心）
  Future<void> _sendCaringStarterFromMood({String? mood, String? note}) async {
    final starter = _buildCaringStarterPrompt(mood, note);

    if (!mounted) return;
    setState(() => _isLoading = true);

    final reply = await _service.processUserMessage(starter);
    if (!mounted) return;

    if (reply != null) {
      setState(() {
        _messages.add({'role': 'ai', 'text': reply});
      });

      // 👇 新增：背景時對「關懷開場」也發通知
      if (!_inForeground && reply.isNotEmpty) {
        final body = reply.length > 80 ? '${reply.substring(0, 80)}…' : reply;
        await NotificationService.showNow(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          title: 'AI 關心你',
          body: body,
          payload: 'route:/ai',
        );
      }

      await _service.remindIfUpcomingTask();
      await _service.speak(reply.trim());
      await _service.saveToFirestore('（系統）心情打卡開場：$mood｜${note ?? ''}', reply);
    }

    setState(() => _isLoading = false);
    await _scrollToBottom();
  }

  String _buildCaringStarterPrompt(String? mood, String? note) {
    final moodPart = (mood == null || mood.isEmpty) ? '' : '使用者今天標記的心情是「$mood」。';
    final notePart = (note == null || note.trim().isEmpty)
        ? '請先用溫柔、簡短的語氣表達理解，並詢問「發生了什麼讓你有這樣的感受呢？」'
        : '他補充了一句：「$note」。請用溫柔、簡短的語氣先同理，並基於這句話，追問一個開放式問題，例如「願意多說一點細節嗎？」';
    const guide =
        '回覆規則：1) 先同理 1 句；2) 問 1 個開放式問題；3) 提供 1 個10分鐘內能做到的小建議（如深呼吸、喝水、短暫散步）。用自然中文、句子短。';
    return '$moodPart$notePart\n$guide';
  }

  Future<void> _sendMessage(String input) async {
    if (!mounted) return;

    final text = input.trim();
    if (text.isEmpty) return;

    // ✅ 防止連點/重入
    if (_sending) return;
    _sending = true;

    // ✅ 小工具：背景副作用（不阻塞 UI）
    Future<void> _afterReplySideEffects({
      required String userText,
      required String aiText,
      bool allowMemoryPlay = true,
    }) async {
      // ✅ 0) 先存 Firestore（最重要，放第一）
      try {
        await _service
            .saveToFirestore(userText, aiText)
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('❌ saveToFirestore failed: $e');
      }

      // ✅ 1) 背景通知（不重要，失敗就算了）
      try {
        if (!_inForeground && aiText.isNotEmpty) {
          final body = aiText.length > 80 ? '${aiText.substring(0, 80)}…' : aiText;
          await NotificationService.showNow(
            id: DateTime.now().millisecondsSinceEpoch % 100000,
            title: 'AI 陪伴回覆了',
            body: body,
            payload: 'route:/ai',
          );
        }
      } catch (_) {}

      // ✅ 2) 播回憶（可能卡死：加 timeout）
      if (allowMemoryPlay) {
        try {
          bool playedByExplicitBlock = false;

          if (aiText.contains('[播放回憶')) {
            final full = RegExp(
              r'\[播放回憶錄?\][\s\S]*?標題[:：]\s*(.*?)\s+描述[:：]\s*(.*?)\s+音檔[:：]\s*(\S+)',
              dotAll: true,
            ).firstMatch(aiText);

            if (full != null) {
              final url = full.group(3);
              if (url != null && url.isNotEmpty) {
                await _service
                    .playMemoryAudioFromUrl(url)
                    .timeout(const Duration(seconds: 8));
                playedByExplicitBlock = true;
              }
            } else {
              final titleOnly = RegExp(
                r'\[播放回憶錄?\][\s\S]*?標題[:：]\s*(.+)',
                dotAll: true,
              ).firstMatch(aiText);

              final t = titleOnly?.group(1)?.trim();
              if (t != null && t.isNotEmpty) {
                final ok = await _service
                    .playMemoryAudioIfMatch('[播放回憶錄] 標題: $t')
                    .timeout(const Duration(seconds: 8), onTimeout: () => false);
                if (ok) playedByExplicitBlock = true;
              }
            }
          }

          if (!playedByExplicitBlock) {
            final recentTexts = _messages.map((m) => m['text'] ?? '').toList();
            final last5 = recentTexts.length > 5
                ? recentTexts.sublist(recentTexts.length - 5)
                : recentTexts;
            final ctxForMatch = [...last5, userText, aiText].join('\n');

            await _service
                .playMemoryAudioIfMatch(ctxForMatch)
                .timeout(const Duration(seconds: 8), onTimeout: () => false);
          }
        } catch (_) {}
      }

      // ✅ 3) TTS（最容易卡：一定要 timeout）
      try {
        final speakText = aiText
            .replaceAll('[播放回憶]', '')
            .replaceAll('[播放回憶錄]', '')
            .trim();

        if (speakText.isNotEmpty) {
          await _service
              .speak(speakText)
              .timeout(const Duration(seconds: 10));
        }
      } catch (_) {}
    }

    try {
      // ✅ 開始轉圈 + 先顯示 user 泡泡
      setState(() {
        _messages.add({'role': 'user', 'text': text});
        _isLoading = true;
      });
      _controller.clear();
      await _scrollToBottom();

      final lower = text.toLowerCase();

      // -------- A) 本地：今天任務（不走 Gemini）--------
      final asksTodayTasks = (text.contains('今天') || text.contains('今日')) &&
          (text.contains('任務') || text.contains('要做') || text.contains('行程') || text.contains('提醒'));

      if (asksTodayTasks || text == '提醒我今天要做的事') {
        final tasks = await _service.fetchTodayTasks();

        String reply;
        if (tasks.isEmpty) {
          reply = '今天沒有排定任務。';
        } else {
          final now = DateTime.now();
          final pendingTasks = tasks.where((t) {
            final done = (t['done'] ?? '').toLowerCase() == 'true';
            return !done;
          }).toList();

          if (pendingTasks.isEmpty) {
            reply = '今天的任務都已完成，做得很棒！';
          } else {
            String? urgent;
            for (final t in pendingTasks) {
              DateTime? start;
              try {
                final tm = DateFormat('HH:mm').parseStrict(t['time'] ?? '');
                start = DateTime(now.year, now.month, now.day, tm.hour, tm.minute);
              } catch (_) {}

              if (start != null) {
                final diff = start.difference(now).inMinutes;
                if (diff >= 0 && diff <= 60) {
                  urgent = '提醒您，一小時內有任務：${t['task']}（${t['time']}）';
                  break;
                }
                if (now.isAfter(start) && now.difference(start).inMinutes <= 30) {
                  urgent = '現在正在進行：${t['task']}（${t['time']}）';
                  break;
                }
              }
            }

            reply = urgent ??
                '今天尚未完成的任務有：${pendingTasks.map((t) => '${t['time']}：${t['task']}').join('；')}';
          }
        }

        if (!mounted) return;

        // ✅ 回覆一出現就停轉圈（關鍵）
        setState(() {
          _messages.add({'role': 'ai', 'text': reply});
          _isLoading = false;
        });
        await _scrollToBottom();

        // ✅ 背景做：通知/TTS/存檔（不阻塞）
        unawaited(_afterReplySideEffects(userText: text, aiText: reply, allowMemoryPlay: false));
        return;
      }

      // -------- A-2) 本地：播放/重播回憶 --------
      final isReplay = lower.contains('再播') || lower.contains('重播') || lower.contains('再聽') || text == '再播一次剛剛的回憶';
      final isPlayMemory = lower.contains('播放') && (lower.contains('回憶') || lower.contains('錄音'));

      if (isReplay || isPlayMemory) {
        final ok = await _service.playMemoryAudioIfMatch(text);
        if (ok) {
          const reply = '已為你播放回憶。';
          if (!mounted) return;

          // ✅ 立刻停轉圈
          setState(() {
            _messages.add({'role': 'ai', 'text': reply});
            _isLoading = false;
          });
          await _scrollToBottom();

          // ✅ 背景做：通知/TTS/存檔（不阻塞）
          unawaited(_afterReplySideEffects(userText: text, aiText: reply, allowMemoryPlay: false));
          return;
        }
      }

      // -------- B) 需要聊天才丟 Gemini --------
      // ✅ 你前面已經把 text 加進 _messages 了，所以 recentContext 不要再 append text 一次
      final history = _messages
          .where((m) => m['role'] == 'user')
          .map((m) => m['text']!)
          .toList();
      final last3 = history.length > 3 ? history.sublist(history.length - 3) : history;
      final recentContext = last3.join('\n');

      final replyRaw = await _service.processUserMessage(recentContext);
      final reply = (replyRaw == null || replyRaw.trim().isEmpty)
          ? '我現在有點忙（AI 額度可能用完了），我們等等再聊好嗎？'
          : replyRaw.trim();

      if (!mounted) return;

      // ✅ 回覆一出現就停轉圈（關鍵）
      setState(() {
        _messages.add({'role': 'ai', 'text': reply});
        _isLoading = false;
      });
      await _scrollToBottom();

      // ✅ 背景做：通知/播回憶/TTS/存檔（不阻塞）
      unawaited(_afterReplySideEffects(userText: text, aiText: reply, allowMemoryPlay: true));
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _messages.add({'role': 'ai', 'text': '剛剛連線有點不穩，我們等一下再試～'});
        _isLoading = false;
      });
      await _scrollToBottom();
    } finally {
      _sending = false;

      // ✅ 保險：不管哪裡炸掉都不要一直轉
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  void dispose() {
    // 👇 新增：移除觀察者
    WidgetsBinding.instance.removeObserver(this);
    _reminderTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 讓清單滑到最底（最新訊息）
  Future<void> _scrollToBottom() async {
    // 等一點點時間，讓 ListView 完成布局後再捲動
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    if (!_scrollController.hasClients) return;

    try {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (_) {
      // 略過偶發的滾動競態錯誤
    }
  }

  Future<void> _loadPreviousMessages() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('ai_companion')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt')
        .get();

    if (!mounted) return;

    setState(() {
      _messages.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userText = data['userText'];
        final aiResponse = data['aiResponse'];
        if (userText is String && aiResponse is String) {
          _messages.add({'role': 'user', 'text': userText});
          _messages.add({'role': 'ai', 'text': aiResponse});
        }
      }
    });

    await Future.delayed(const Duration(milliseconds: 200));
    _scrollToBottom();
  }

  Widget _buildMessageBubble(Map<String, String> message) {
    final isUser = message['role'] == 'user';
    final text = message['text'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Image.asset(
                'assets/images/ai_icon.png',
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) => const SizedBox(width: 36),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFFDAECFF) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    // ✅ 修正：withValues 會編譯失敗，改用 withOpacity
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(fontSize: 18, color: Colors.black87), // ✅ 放大字體
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Widget>> _buildPromptButtonsRow() async {
    final userMessages = _messages.where((m) => m['role'] == 'user').map((m) => m['text']!).toList();
    final aiMessages = _messages.where((m) => m['role'] == 'ai').toList();

    final buttons = _fixedPrompts.map(_buildPromptButton).toList();

    if (userMessages.length >= 5 && userMessages.length % 5 == 0 && aiMessages.isNotEmpty) {
      final last3 = userMessages.sublist(userMessages.length - 3);
      final smart = await _service.generateSmartSuggestion(last3);

      if (smart != null && !_fixedPrompts.contains(smart)) {
        buttons.add(_buildPromptButton(smart));
      }
    }

    return buttons;
  }

  Widget _buildPromptButton(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        onPressed: () => _sendMessage(text),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: Colors.blue.shade100),
        ),
        child: Text(text, style: const TextStyle(fontSize: 15)), // ✅ 微放大
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FB),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 92, // ✅ 固定高度，避免 3px overflow
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: IconButton(
                      icon: const Icon(Icons.home_rounded, color: Color(0xFF5B8EFF), size: 30),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // ✅ 重要：避免撐滿造成溢位
                      children: [
                        Image.asset('assets/images/memory_icon.png', width: 54),
                        const SizedBox(height: 2), // ✅ 間距縮小
                        const Text(
                          'AI 陪伴',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5B8EFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFDFEFF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                ),
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: FutureBuilder<List<Widget>>(
                future: _buildPromptButtonsRow(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: snapshot.data!),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 100,
                      decoration: InputDecoration(
                        hintText: '輸入訊息...',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                      style: const TextStyle(fontSize: 18), // ✅ 放大
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5B8EFF), Color(0xFF49E3D4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () => _sendMessage(_controller.text.trim()),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}