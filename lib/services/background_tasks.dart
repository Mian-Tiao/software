// lib/services/background_tasks.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import 'notification_service.dart';
import 'ai_companion_service.dart';

class BackgroundTasks {
  static const int _morningId = 3001;
  static const int _nightId = 3002;

  static Future<void> initAndScheduleDaily() async {
    try {
      await AndroidAlarmManager.initialize();
      debugPrint('[Alarm] initialize OK');
    } catch (e, s) {
      debugPrint('[Alarm] initialize ERROR: $e\n$s');
      return; // 初始化都失敗就先退出，不擋 UI
    }

    // 先清
    try {
      await AndroidAlarmManager.cancel(_morningId);
      await AndroidAlarmManager.cancel(_nightId);
    } catch (_) {}

    final now = DateTime.now();
    final nextMorning = _nextTime(now, hour: 9, minute: 0);
    final nextNight = _nextTime(now, hour: 21, minute: 0);

    // ⚠️ 不用 rescheduleOnReboot，避免沒有 receiver 時直接炸掉
    try {
      await AndroidAlarmManager.oneShotAt(
        nextMorning,
        _morningId,
        aiMorningCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
      );
      debugPrint('[Alarm] morning set @ $nextMorning');
    } catch (e, s) {
      debugPrint('[Alarm] morning set ERROR: $e\n$s');
    }

    try {
      await AndroidAlarmManager.oneShotAt(
        nextNight,
        _nightId,
        aiNightCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
      );
      debugPrint('[Alarm] night set @ $nextNight');
    } catch (e, s) {
      debugPrint('[Alarm] night set ERROR: $e\n$s');
    }
  }

  static DateTime _nextTime(DateTime now, {required int hour, required int minute}) {
    final t = DateTime(now.year, now.month, now.day, hour, minute);
    return t.isAfter(now) ? t : t.add(const Duration(days: 1));
  }
}

@pragma('vm:entry-point')
Future<void> aiMorningCallback() async {
  await _runHeadless(tag: 'morning');
}

@pragma('vm:entry-point')
Future<void> aiNightCallback() async {
  await _runHeadless(tag: 'night');
}

Future<void> _runHeadless({required String tag}) async {
  WidgetsFlutterBinding.ensureInitialized();
  ui.DartPluginRegistrant.ensureInitialized();

  await NotificationService.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final svc = AICompanionService();
  final title = tag == 'morning' ? '早安～今天一起加油' : '晚安～睡前小回顧';
  final prompt = tag == 'morning'
      ? '請用親切的中文 2–3 句、<=60字：早安問候 + 若我今天有代辦或習慣養成小提醒，簡短提醒；沒有就給鼓勵。語氣溫柔精簡。'
      : '請用親切的中文 2–3 句、<=60字：回顧今天亮點或鼓勵，並給一個放鬆小建議（如深呼吸/伸展）。語氣溫柔精簡。';

  String body = '來和我聊聊吧！';
  try {
    final reply = await svc.processUserMessage(prompt);
    if (reply != null && reply.trim().isNotEmpty) {
      body = reply.trim().replaceAll('\n', ' ');
      if (body.length > 120) body = '${body.substring(0, 120)}…';
    }
  } catch (_) {}

  await NotificationService.showNow(
    id: DateTime.now().millisecondsSinceEpoch % 100000,
    title: title,
    body: body,
    payload: 'route:/ai?initialPrompt=${Uri.encodeComponent(tag == "morning" ? "提醒我今天要做的事" : "幫助我回憶")}',
  );

  // 安排下一次（同樣不加 rescheduleOnReboot）
  final now = DateTime.now();
  final next = DateTime(now.year, now.month, now.day, tag == 'morning' ? 9 : 21, 0)
      .add(const Duration(days: 1));

  try {
    await AndroidAlarmManager.oneShotAt(
      next,
      tag == 'morning' ? BackgroundTasks._morningId : BackgroundTasks._nightId,
      tag == 'morning' ? aiMorningCallback : aiNightCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
    );
    debugPrint('[Alarm] next($tag) set @ $next');
  } catch (e, s) {
    debugPrint('[Alarm] next($tag) set ERROR: $e\n$s');
  }
}