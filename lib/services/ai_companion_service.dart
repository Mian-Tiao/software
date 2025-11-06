import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:memory/memoirs/memory_service.dart';
import 'package:flutter/foundation.dart'; // for debugPrint

class AICompanionService {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 一天內避免重複提醒
  final Set<String> _remindedToday = {};

  /// 讀「今天」任務（支援 dateKey、String、Timestamp）
  Future<List<Map<String, String>>> fetchTodayTasks({bool verbose = true}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final tasksRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks');

    final List<Map<String, String>> results = [];

    // ① dateKey: 'yyyy-MM-dd'
    try {
      final snapKey = await tasksRef.where('dateKey', isEqualTo: todayKey).get();
      for (final doc in snapKey.docs) {
        final d = doc.data();
        results.add({
          'task': (d['task'] ?? '').toString(),
          'time': (d['time'] ?? '').toString(),
          'end' : (d['end']  ?? '').toString(),
          'type': (d['type'] ?? '').toString(),
          'done': (d['done'] ?? false).toString(),
        });
      }
      if (verbose) debugPrint('🗓️ 用 dateKey 命中 ${snapKey.docs.length} 筆');
    } catch (_) {}

    // ② date 為 'yyyy-MM-dd' 字串
    if (results.isEmpty) {
      try {
        final snapStr = await tasksRef.where('date', isEqualTo: todayKey).get();
        for (final doc in snapStr.docs) {
          final d = doc.data();
          results.add({
            'task': (d['task'] ?? '').toString(),
            'time': (d['time'] ?? '').toString(),
            'end' : (d['end']  ?? '').toString(),
            'type': (d['type'] ?? '').toString(),
            'done': (d['done'] ?? false).toString(),
          });
        }
        if (verbose) debugPrint('🗓️ 用 date=string 命中 ${snapStr.docs.length} 筆');
      } catch (_) {}
    }

    // ③ date 為 Timestamp：今日 00:00 ~ 明日 00:00
    if (results.isEmpty) {
      try {
        final snapTs = await tasksRef
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThan: Timestamp.fromDate(end))
            .get();
        for (final doc in snapTs.docs) {
          final d = doc.data();
          results.add({
            'task': (d['task'] ?? '').toString(),
            'time': (d['time'] ?? '').toString(),
            'end' : (d['end']  ?? '').toString(),
            'type': (d['type'] ?? '').toString(),
            'done': (d['done'] ?? false).toString(),
          });
        }
        if (verbose) debugPrint('🗓️ 用 date=Timestamp 範圍命中 ${snapTs.docs.length} 筆');
      } catch (e) {
        if (verbose) debugPrint('ℹ️ Timestamp 範圍查詢失敗：$e');
      }
    }

    // ④ 最後保險：掃描少量並自行判斷今天
    if (results.isEmpty) {
      final snapAll = await tasksRef.limit(300).get();
      for (final doc in snapAll.docs) {
        final d = doc.data();
        final dateField = d['date'];
        final dateKeyField = d['dateKey'];
        bool isToday = false;

        if (dateKeyField is String) {
          isToday = dateKeyField.trim() == todayKey;
        } else if (dateField is String) {
          final norm = dateField.split('T').first.replaceAll('/', '-').trim();
          isToday = norm == todayKey;
        } else if (dateField is Timestamp) {
          final dt = dateField.toDate();
          isToday = !dt.isBefore(start) && dt.isBefore(end);
        }

        if (isToday) {
          results.add({
            'task': (d['task'] ?? '').toString(),
            'time': (d['time'] ?? '').toString(),
            'end' : (d['end']  ?? '').toString(),
            'type': (d['type'] ?? '').toString(),
            'done': (d['done'] ?? false).toString(),
          });
        }
      }
      if (verbose) debugPrint('🗓️ 用保險梯掃描後命中 ${results.length} 筆');
    }

    // 正規化時間 + 排序
    String hm(String s) {
      if (s.isEmpty) return s;
      final p = s.split(':');
      if (p.length >= 2) return '${p[0].padLeft(2,'0')}:${p[1].padLeft(2,'0')}';
      return s;
    }
    for (final t in results) {
      t['time'] = hm(t['time'] ?? '');
      t['end']  = hm(t['end']  ?? '');
    }
    results.sort((a,b) => (a['time']??'').compareTo(b['time']??''));

    if (verbose) {
      debugPrint('✅ 今日($todayKey) 共 ${results.length} 筆: '
          '${results.map((e) => '${e['time']} ${e['task']}').join(' | ')}');
    }
    return results;
  }

  /// 產生「聚合提醒」文字：同時列出 進行中 / 30 分內開始 / 剛剛錯過（30 分內）
  /// 規則：
  /// - 若本次沒有「新」任務出現，回傳 null（避免打擾）
  /// - 若有新任務出現：訊息中會包含 **所有進行中** 的任務（即使之前提醒過），
  ///   以及本次新出現的「即將開始 / 剛錯過」任務。
  Future<String?> taskReminderText() async {
    final tasks = await fetchTodayTasks(verbose: false);
    if (tasks.isEmpty) return null;

    DateTime? _parseHmToday(String s) {
      final now = DateTime.now();
      for (final fmt in const ['HH:mm', 'HH:mm:ss']) {
        try {
          final tm = DateFormat(fmt).parseStrict(s);
          return DateTime(now.year, now.month, now.day, tm.hour, tm.minute);
        } catch (_) {}
      }
      return null;
    }

    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    // 分類
    final List<Map<String, String>> ongoingAll = [];
    final List<Map<String, String>> upcomingAll = [];
    final List<Map<String, String>> missedAll = [];

    // 追蹤哪些是「新」的（尚未提醒過）
    final List<String> newKeys = [];

    String keyOf(Map<String, String> t, String label) =>
        '$todayKey|${t['time']}|${t['task']}|$label';

    for (final t in tasks) {
      final done = (t['done'] ?? '').toLowerCase() == 'true';
      if (done) continue;

      final start = _parseHmToday(t['time'] ?? '');
      final end = _parseHmToday(t['end'] ?? '') ?? (start?.add(const Duration(minutes: 30)));
      if (start == null) continue;

      // 進行中（最高優先）：訊息內永遠顯示
      if (end != null && now.isAfter(start) && now.isBefore(end)) {
        ongoingAll.add(t);
        // 進行中這個「狀態鍵」
        final k = keyOf(t, 'ongoing');
        if (!_remindedToday.contains(k)) newKeys.add(k);
        continue;
      }

      // 30 分鐘內即將開始
      final diffMin = start.difference(now).inMinutes;
      if (diffMin >= 0 && diffMin <= 30) {
        upcomingAll.add(t);
        final k = keyOf(t, 'upcoming30');
        if (!_remindedToday.contains(k)) newKeys.add(k);
        continue;
      }

      // 剛剛錯過（30 分內）
      if (end != null) {
        final miss = now.difference(end).inMinutes;
        if (miss >= 0 && miss <= 30) {
          missedAll.add(t);
          final k = keyOf(t, 'missed30');
          if (!_remindedToday.contains(k)) newKeys.add(k);
        }
      }
    }

    // 沒有「新」任務出現 → 不提醒（避免重複刷存在感）
    if (newKeys.isEmpty) return null;

    String fmt(Map<String, String> t) => '${t['time']}：${t['task']}';

    final parts = <String>[];
    if (ongoingAll.isNotEmpty) {
      parts.add('進行中：${ongoingAll.map(fmt).join('、')}');
    }
    // 只把「本次新出現」的 upcoming/missed 列入訊息（舊的就不再重複）
    final upcomingNew = upcomingAll.where((t) => newKeys.contains(keyOf(t, 'upcoming30'))).toList();
    final missedNew = missedAll.where((t) => newKeys.contains(keyOf(t, 'missed30'))).toList();

    if (upcomingNew.isNotEmpty) {
      parts.add('30 分內開始：${upcomingNew.map(fmt).join('、')}');
    }
    if (missedNew.isNotEmpty) {
      parts.add('剛錯過：${missedNew.map(fmt).join('、')}');
    }

    // 標記所有「新鍵」已提醒，避免下次重複。
    _remindedToday.addAll(newKeys);

    return parts.isEmpty ? null : '提醒您，${parts.join('；')}。';
  }

  /// 提供給 AI 的簡短摘要（不做去重、不佔太多字）
  /// 例： "進行中 1 項、30 分內 2 項"
  Future<String?> taskHintSummary() async {
    final tasks = await fetchTodayTasks(verbose: false);
    if (tasks.isEmpty) return null;

    DateTime? _parseHmToday(String s) {
      final now = DateTime.now();
      for (final fmt in const ['HH:mm', 'HH:mm:ss']) {
        try {
          final tm = DateFormat(fmt).parseStrict(s);
          return DateTime(now.year, now.month, now.day, tm.hour, tm.minute);
        } catch (_) {}
      }
      return null;
    }

    final now = DateTime.now();
    int cOngoing = 0, cUpcoming = 0, cMissed = 0;

    for (final t in tasks) {
      final done = (t['done'] ?? '').toLowerCase() == 'true';
      if (done) continue;

      final start = _parseHmToday(t['time'] ?? '');
      final end = _parseHmToday(t['end'] ?? '') ?? (start?.add(const Duration(minutes: 30)));
      if (start == null) continue;

      if (end != null && now.isAfter(start) && now.isBefore(end)) {
        cOngoing++;
        continue;
      }
      final diffMin = start.difference(now).inMinutes;
      if (diffMin >= 0 && diffMin <= 30) {
        cUpcoming++;
        continue;
      }
      if (end != null) {
        final miss = now.difference(end).inMinutes;
        if (miss >= 0 && miss <= 30) cMissed++;
      }
    }

    final parts = <String>[];
    if (cOngoing > 0) parts.add('進行中 $cOngoing 項');
    if (cUpcoming > 0) parts.add('30 分內 $cUpcoming 項');
    if (cMissed > 0) parts.add('剛錯過 $cMissed 項');
    return parts.isEmpty ? null : parts.join('、');
  }


  /// 只語音念提醒（保留舊呼叫相容）
  Future<void> remindIfUpcomingTask() async {
    final msg = await taskReminderText();
    if (msg != null) await speak(msg);
  }

  Future<bool> playMemoryAudioFromUrl(String url) async {
    try {
      await _audioPlayer.stop();
      await _flutterTts.stop();
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
      debugPrint('▶️ 成功播放 AI 指定音檔：$url');
      return true;
    } catch (e) {
      debugPrint('❌ 無法播放 AI 指定音檔：$e');
      return false;
    }
  }

  /// AI 說話
  Future<void> speak(String text) async {
    await _flutterTts.setPitch(1.2);
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setLanguage('zh-TW');
    await _flutterTts.speak(text);
  }

  /// 存對話
  Future<void> saveToFirestore(String userText, String aiResponse) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('ai_companion').add({
      'uid': uid,
      'userText': userText,
      'aiResponse': aiResponse,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic>? _lastPlayedMemory;

  /// 比對並播放回憶
  Future<bool> playMemoryAudioIfMatch(String userInput) async {
    debugPrint('🎧 呼叫 playMemoryAudioIfMatch');

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final memoryService = MemoryService();
    final memories = await memoryService.fetchMemories(uid);
    debugPrint('📦 撈到 ${memories.length} 筆記憶');
    if (memories.isEmpty) return false;

    String normalize(String s) {
      final lowered = s.toLowerCase();
      return lowered.replaceAll(RegExp(r'[\s\u3000\p{P}]+', unicode: true), '');
    }

    bool containsAll(String haystack, String needle) {
      if (needle.isEmpty) return false;
      return haystack.contains(needle);
    }

    // 再播一次
    final lowerInput = userInput.toLowerCase();
    if (lowerInput.contains("再播") || lowerInput.contains("重播") || lowerInput.contains("再聽")) {
      if (_lastPlayedMemory != null) {
        final audioUrl = _lastPlayedMemory!['audioPath'];
        if (audioUrl != null && audioUrl.toString().isNotEmpty) {
          debugPrint('🔁 重播上次記憶：$audioUrl');
          return await _playAudioFromPath(audioUrl);
        }
      }
      debugPrint('⚠️ 沒有可重播的記憶');
    }

    // AI 標題
    Map<String, dynamic>? matched;
    final titleMatch = RegExp(
      r'\[播放回憶錄?\][\s\S]*?標題[:：]\s*(.+)',
      dotAll: true,
    ).firstMatch(userInput);

    final titleFromAI = titleMatch?.group(1)?.trim();

    final ctxRaw = userInput;
    final ctxNorm = normalize(ctxRaw);

    int scoreFor(Map<String, dynamic> mem) {
      final title = (mem['title'] ?? '').toString();
      final desc  = (mem['description'] ?? '').toString();
      final audio = (mem['audioPath'] ?? '').toString();

      final tRaw = title;
      final dRaw = desc;
      final t = normalize(tRaw);
      final d = normalize(dRaw);

      int s = 0;

      if (titleFromAI != null && titleFromAI.isNotEmpty) {
        final aiNorm = normalize(titleFromAI);
        if (aiNorm.isNotEmpty && (t.contains(aiNorm) || aiNorm.contains(t))) s += 20;
        if (tRaw.isNotEmpty && titleFromAI.contains(tRaw)) s += 20;
      }

      if (tRaw.isNotEmpty && ctxRaw.contains(tRaw)) s += 10;
      if (t.isNotEmpty && containsAll(ctxNorm, t)) s += 6;
      if (dRaw.isNotEmpty && ctxRaw.contains(dRaw)) s += 4;
      if (d.isNotEmpty && containsAll(ctxNorm, d)) s += 2;

      final roughTokens = ctxRaw.split(RegExp(r'[\s、,，。.!！?？:：;；\-/]+'))
          .where((w) => w.trim().length >= 2)
          .toList();
      const stop = {'播放','回憶','錄音','再播','重播','再聽','一下','那個','這個','幫我','請','幫忙','聽'};
      for (final w in roughTokens) {
        if (stop.contains(w)) continue;
        if (tRaw.contains(w)) {
          s += 3;
        } else if (dRaw.contains(w)) {
          s += 1;
        }
      }

      if (audio.isNotEmpty) s += 2;

      return s;
    }

    // 先嘗試標題精準找
    if (titleFromAI != null && titleFromAI.isNotEmpty) {
      matched = memories.firstWhere(
            (m) {
          final t = (m['title'] ?? '').toString();
          return t.isNotEmpty &&
              (t == titleFromAI || t.contains(titleFromAI) || titleFromAI.contains(t));
        },
        orElse: () => {},
      );
      if (matched.isNotEmpty) {
        final audioUrl = matched['audioPath'];
        if (audioUrl != null && audioUrl.toString().isNotEmpty) {
          _lastPlayedMemory = matched;
          return await _playAudioFromPath(audioUrl);
        }
      }
    }

    // 打分選最佳
    int best = -1;
    Map<String, dynamic>? bestMem;
    for (final m in memories) {
      final sc = scoreFor(m);
      if (sc > best) {
        best = sc;
        bestMem = m;
      }
    }

    if (bestMem != null && best >= 2) {
      final audioUrl = bestMem['audioPath'];
      if (audioUrl != null && audioUrl.toString().isNotEmpty) {
        _lastPlayedMemory = bestMem;
        debugPrint('✅ 比對成功，播放：${bestMem['title']}（score=$best）');
        return await _playAudioFromPath(audioUrl);
      } else {
        debugPrint('⚠️ 找到回憶但沒音檔，標題：${bestMem['title']}');
      }
    }

    debugPrint('❌ 未找到可播放的回憶');
    return false;
  }

  Future<bool> _playAudioFromPath(String path) async {
    try {
      await _audioPlayer.stop();
      await _flutterTts.stop();

      if (path.startsWith('http')) {
        await _audioPlayer.setUrl(path);
      } else if (path.startsWith('gs://')) {
        final ref = FirebaseStorage.instance.refFromURL(path);
        final downloadUrl = await ref.getDownloadURL();
        debugPrint('☁️ Firebase Storage URL: $downloadUrl');
        await _audioPlayer.setUrl(downloadUrl);
      } else {
        debugPrint('📁 播放本地音檔: $path');
        await _audioPlayer.setFilePath(path); // 僅限手機
      }

      await _audioPlayer.play();
      debugPrint('▶️ 開始播放音檔');
      return true;
    } catch (e) {
      debugPrint('❌ 音檔播放失敗: $e');
      return false;
    }
  }

  /// （選用）智慧建議
  Future<String?> generateSmartSuggestion(List<String> recentMessages) async {
    const apiKey = 'AIzaSyCSiUQBqYBaWgpxHr37RcuKoaiiUOUfQhs';
    const url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    final prompt = '''
你是一位溫柔的 AI 陪伴者，請根據以下三句使用者的訊息，生成一句短建議延續對話，繁體中文、10字內、只回純文字：
${recentMessages.join('\n')}
''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      return text?.replaceAll(RegExp(r'[。！\s]'), '');
    } else {
      debugPrint('❌ generateSmartSuggestion failed: ${response.body}');
      return null;
    }
  }

  /// 主要聊天：把「改良後提示詞 + 30 分鐘提醒」一起送給 AI
  Future<String?> processUserMessage(String prompt) async {
    const apiKey = 'AIzaSyCSiUQBqYBaWgpxHr37RcuKoaiiUOUfQhs';
    const url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    final uid = FirebaseAuth.instance.currentUser?.uid;
    String memorySummary = '（尚無回憶紀錄）';
    if (uid != null) {
      final memoryService = MemoryService();
      final memories = await memoryService.fetchMemories(uid);
      memorySummary = memoryService.summarizeMemories(memories);
    }

    // 取得 30 分鐘提醒（若有）
    final taskHint = await taskHintSummary(); // 簡短摘要給 AI
    final nowStr = DateFormat('HH:mm').format(DateTime.now());

    // ====== 改良後 Prompt（你要的內容都在，並更精準）======
    final systemPrompt = '''
你是一位溫柔且簡潔的 AI 陪伴者，擅長傾聽與陪伴使用者，幫助他們回憶過去的美好往事，並提醒即將到來的重要任務。

【互動規則】
1) 當使用者表示要「聽錄音／播放／聽某段記憶」，請先用一句簡短回覆，並緊接輸出一行：
   [播放回憶錄] 標題: <記憶標題>
   - 不要輸出網址、完整內容或其它欄位。
2) 「回憶錄」是**過去**的經歷（錄音、描述）；「行事曆任務」是**未來**事件（吃藥、活動、看診）。不要混淆。
3) 回覆以 50 字以內、1–2 句自然口語為限；避免冗長與過多標點。
4) 你無法自行查詢行事曆。系統會提供 TASK_HINT（可能為空）。只有當 TASK_HINT 非空時，請在回覆最後加一個簡短提醒（例如：「小提醒：{TASK_HINT}」）。若為空，請不要主動談任務。
5) 延續對話脈絡，善用 MEMORY_SUMMARY 的線索；避免重複。
6) 需要澄清記憶標題時，請用不超過 15 字的一句話詢問。

NOW: $nowStr
TASK_HINT: ${taskHint ?? ''}
MEMORY_SUMMARY:
$memorySummary

使用者說：
「$prompt」
''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': systemPrompt}
          ]
        }
      ]
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    } else {
      debugPrint('Gemini API error: ${response.body}');
      return null;
    }
  }
}