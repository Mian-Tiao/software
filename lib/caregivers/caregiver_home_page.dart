import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'caregiver_session.dart';           // ✅ 全域 Session
import '../pages/user_task_page.dart';
import 'task_statistics_page.dart';
import 'package:memory/memoirs/memory_page.dart';

class CaregiverHomePage extends StatefulWidget {
  /// 可選的直接注入資料（例如從上一頁用 constructor 帶進來）
  final Map<String, dynamic>? userData;

  const CaregiverHomePage({super.key, this.userData});

  @override
  State<CaregiverHomePage> createState() => _CaregiverHomePageState();
}

class _CaregiverHomePageState extends State<CaregiverHomePage> {
  bool _inited = false;

  /// 將 route arguments / constructor 的 userData 同步進 CaregiverSession
  void _ingestArgsOnce(BuildContext context) {
    if (_inited) return;
    _inited = true;

    // 1) 命名路由帶來的 arguments
    final routeData = ModalRoute.of(context)?.settings.arguments;
    if (routeData is Map<String, dynamic>) {
      final uid = routeData['selectedCareReceiverUid'] ?? routeData['uid'];
      final name = routeData['selectedCareReceiverName'] ?? routeData['name'];
      final identityCode =
          routeData['selectedCareReceiverIdentityCode'] ?? routeData['identityCode'];

      if (uid != null) CaregiverSession.selectedCareReceiverUid = uid;
      if (name != null) CaregiverSession.selectedCareReceiverName = name;
      if (identityCode != null) {
        CaregiverSession.selectedCareReceiverIdentityCode = identityCode;
      }
    }

    // 2) 透過建構子直接帶入的 userData（若有）
    final data = widget.userData;
    if (data != null) {
      if (data['uid'] != null) {
        CaregiverSession.selectedCareReceiverUid = data['uid'];
      }
      if (data['name'] != null) {
        CaregiverSession.selectedCareReceiverName = data['name'];
      }
      if (data['identityCode'] != null) {
        CaregiverSession.selectedCareReceiverIdentityCode = data['identityCode'];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 僅首次進頁把參數寫入 Session
    _ingestArgsOnce(context);

    final String name = CaregiverSession.selectedCareReceiverName ?? '未命名';
    final String identityCode = CaregiverSession.selectedCareReceiverIdentityCode ?? '無代碼';
    final String? selectedUid = CaregiverSession.selectedCareReceiverUid;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 自訂 AppBar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '照顧者後台',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.switch_account, color: Color(0xFF2E7D32)),
                      tooltip: '切換查看對象',
                      onPressed: () {
                        // ✅ 用 replacement，避免舊頁殘留（更穩）
                        Navigator.pushReplacementNamed(context, '/selectUser');
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                _buildInfoCard(name, identityCode),

                // 個人檔案
                _buildMenuCard(
                  context,
                  icon: Icons.person,
                  label: '個人檔案',
                  color: const Color(0xFF81D4FA),
                  onTap: () {
                    Navigator.pushNamed(context, '/careProfile');
                  },
                ),

                const SizedBox(height: 24),
                const Text(
                  '功能選單',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 12),

                // 查看任務行事曆
                _buildMenuCard(
                  context,
                  icon: Icons.calendar_today,
                  label: '查看任務行事曆',
                  color: const Color(0xFF4CAF50),
                  onTap: () {
                    if (selectedUid == null) {
                      _showPickUserSnackBar(context);
                      return;
                    }
                    final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
                    const caregiverName = '照顧者';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserTaskPage(
                          targetUid: selectedUid,
                        ),
                        settings: RouteSettings(arguments: {
                          'fromCaregiver': true,
                          'caregiverUid': caregiverUid,
                          'caregiverName': caregiverName,
                        }),
                      ),
                    );
                  },
                ),

                // 查看回憶錄
                _buildMenuCard(
                  context,
                  icon: Icons.photo_library,
                  label: '查看回憶錄',
                  color: const Color(0xFF64B5F6),
                  onTap: () {
                    if (selectedUid == null) {
                      _showPickUserSnackBar(context);
                      return;
                    }
                    final caregiverUid = FirebaseAuth.instance.currentUser?.uid;
                    const caregiverName = '照顧者';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemoryPage(
                          targetUid: selectedUid,
                        ),
                        settings: RouteSettings(arguments: {
                          'fromCaregiver': true,
                          'caregiverUid': caregiverUid,
                          'caregiverName': caregiverName,
                        }),
                      ),
                    );
                  },
                ),

                // 查看任務完成率
                _buildMenuCard(
                  context,
                  icon: Icons.bar_chart,
                  label: '查看任務完成率',
                  color: const Color(0xFF81C784),
                  onTap: () {
                    if (selectedUid == null) {
                      _showPickUserSnackBar(context);
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TaskStatisticsPage(
                          targetUid: selectedUid,
                          targetName: CaregiverSession.selectedCareReceiverName ?? '未命名',
                        ),
                      ),
                    );
                  },
                ),

                // 查看定位地圖
                _buildMenuCard(
                  context,
                  icon: Icons.location_on,
                  label: '查看定位地圖',
                  color: const Color(0xFF1976D2),
                  onTap: () {
                    if (selectedUid == null) {
                      _showPickUserSnackBar(context);
                      return;
                    }
                    Navigator.pushNamed(
                      context,
                      '/map',
                      arguments: {
                        'selectedCareReceiverUid': CaregiverSession.selectedCareReceiverUid,
                        'selectedCareReceiverName': CaregiverSession.selectedCareReceiverName,
                        'selectedCareReceiverIdentityCode':
                        CaregiverSession.selectedCareReceiverIdentityCode,
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI widgets ---

  Widget _buildInfoCard(String name, String identityCode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '當前查看對象：',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Text('姓名：$name', style: const TextStyle(fontSize: 16, color: Colors.black)),
          Text('識別碼：$identityCode', style: const TextStyle(fontSize: 16, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(38),
                radius: 22,
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showPickUserSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('請先選擇要查看的被照顧者')),
    );
  }
}
