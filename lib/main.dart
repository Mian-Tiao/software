import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'caregivers/role_selection_page.dart';
import 'pages/user_task_page.dart';
import 'caregivers/caregiver_home_page.dart';
import 'pages/main_menu_page.dart';
import 'memoirs/memory_page.dart';
import 'pages/register_page.dart';
import 'pages/profile_page.dart';
import 'caregivers/bind_user_page.dart';
import 'caregivers/select_user_page.dart';
import 'caregivers/caregiver_profile_page.dart';
import 'pages/ai_companion_page.dart';
import 'firebase_options.dart'; // 用 FlutterFire CLI 產生
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'caregivers/map.dart';
import 'services/background_tasks.dart'; // 👈 新增

/// 全域 navigatorKey：讓通知點擊時能在這裡做導頁
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _initAndWireNotifications() async {
  await NotificationService.init();

  // 點通知時導頁（payload 形如：route:/ai?initialPrompt=提醒我今天要做的事）
  NotificationService.setOnTapHandler((String payload) {
    try {
      debugPrint('🔔 onTap payload=$payload');
      String routeSpec = payload;
      if (payload.startsWith('route:')) {
        routeSpec = payload.substring(6);
      }
      final uri = Uri.parse(routeSpec);

      // 目標路徑（例如 /ai、/mainMenu）
      final destRoute = uri.path.isEmpty ? '/' : uri.path;

      // 參數全部塞進 arguments，AI 頁可用 ModalRoute.of(context)!.settings.arguments 取出
      final args = <String, dynamic>{};
      for (final entry in uri.queryParameters.entries) {
        args[entry.key] = entry.value;
      }

      navigatorKey.currentState?.pushNamed(
        destRoute,
        arguments: args.isEmpty ? null : args,
      );
    } catch (e) {
      debugPrint('❗通知 payload 解析失敗: $e');
    }
  });
}

// main.dart（重點片段）
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();                 // 只初始化，不要請權限
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MemoryAssistantApp());

  // 👇 讓 UI 出來後再排背景鬧鐘；並且保險 try/catch
  Future.microtask(() async {
    try {
      await BackgroundTasks.initAndScheduleDaily();
    } catch (e, s) {
      debugPrint('[Alarm] schedule after runApp ERROR: $e\n$s');
    }
  });
}
class MemoryAssistantApp extends StatelessWidget {
  const MemoryAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '記憶助理',
      theme: ThemeData.dark(),
      navigatorKey: navigatorKey, // 👈 讓通知點擊能導頁
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/role': (context) => const RoleSelectionPage(),
        '/user': (context) => const UserTaskPage(),
        '/caregiver': (context) => const CaregiverHomePage(),
        '/mainMenu': (context) => const MainMenuPage(),
        '/memory': (context) => const MemoryPage(),
        '/register': (context) => const RegisterPage(),
        '/profile': (context) => const ProfilePage(),
        '/bindUser': (context) => const BindUserPage(),
        '/selectUser': (context) => const SelectUserPage(),
        '/ai': (context) => const AICompanionPage(),
        '/careProfile': (context) => CaregiverProfilePage(),
      },
      onGenerateRoute: (settings) {
        // 地圖頁需要帶入被照顧者 uid
        if (settings.name == '/map') {
          final args = (settings.arguments ?? const <String, dynamic>{}) as Map<String, dynamic>;
          final careReceiverUid = args['selectedCareReceiverUid'] ?? '';
          final careReceiverName = args['selectedCareReceiverName'] ?? '未命名';
          return MaterialPageRoute(
            builder: (_) => NavHomePage(careReceiverUid: careReceiverUid, careReceiverName: careReceiverName),
          );
        }
        return null;
      },
    );
  }
}