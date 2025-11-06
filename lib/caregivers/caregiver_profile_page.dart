import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CaregiverProfilePage extends StatefulWidget {
  const CaregiverProfilePage({super.key});

  @override
  State<CaregiverProfilePage> createState() => _CaregiverProfilePageState();
}

class _CaregiverProfilePageState extends State<CaregiverProfilePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _linkedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadLinkedUsers();
  }

  /// 🔄 讀取綁定的被照顧者
  Future<void> _loadLinkedUsers() async {
    try {
      final caregiver = FirebaseAuth.instance.currentUser;
      if (caregiver == null) return;

      final caregiverDoc = await FirebaseFirestore.instance
          .collection('caregivers')
          .doc(caregiver.uid)
          .get();

      final boundUsers = (caregiverDoc.data()?['boundUsers'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (boundUsers.isEmpty) {
        setState(() {
          _linkedUsers = [];
          _isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> users = [];

      for (final user in boundUsers) {
        final uid = user['uid'] as String;
        final nickname = user['nickname'] as String? ?? '';

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = userDoc.data();

        if (data != null) {
          users.add({
            'uid': uid,
            'name': data['name'] ?? '未命名',
            'identityCode': data['identityCode'] ?? '',
            'nickname': nickname,
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _linkedUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 讀取錯誤: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('讀取失敗，請稍後再試')),
      );
    }
  }

  /// ✏️ 修改暱稱
  Future<void> _editNickname(int index) async {
    final TextEditingController controller =
    TextEditingController(text: _linkedUsers[index]['nickname'] ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('修改暱稱'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '輸入暱稱（例如：爺爺、奶奶）'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newNickname = controller.text.trim();
                if (newNickname.isNotEmpty) {
                  await _updateNicknameInFirestore(
                      _linkedUsers[index]['uid'], newNickname);

                  setState(() {
                    _linkedUsers[index]['nickname'] = newNickname;
                  });
                }
                if (mounted) Navigator.pop(context);
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  /// 📝 更新 Firestore 中的 nickname
  Future<void> _updateNicknameInFirestore(String uid, String newNickname) async {
    final caregiver = FirebaseAuth.instance.currentUser;
    if (caregiver == null) return;

    final caregiverRef = FirebaseFirestore.instance.collection('caregivers').doc(caregiver.uid);
    final caregiverDoc = await caregiverRef.get();

    if (!caregiverDoc.exists) return;

    final boundUsers = (caregiverDoc.data()?['boundUsers'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // 找到對應 uid，更新 nickname
    for (final user in boundUsers) {
      if (user['uid'] == uid) {
        user['nickname'] = newNickname;
        break;
      }
    }

    await caregiverRef.update({'boundUsers': boundUsers});
  }

  /// 🚪 登出
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8F2DA), // ✅ 柔綠背景
      appBar: AppBar(
        title: const Text('照顧者個人檔案'),
        backgroundColor: const Color(0xFF28965A), // ✅ 主綠
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          const SizedBox(height: 20),

          // 🔹 標題 & 小說明
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已綁定的被照顧者',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '你可以在這裡管理被照顧者的暱稱',
                  style: TextStyle(fontSize: 14, color: Color(0xFF777777)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 🔹 被照顧者清單
          Expanded(
            child: _linkedUsers.isEmpty
                ? const Center(
              child: Text('尚未綁定任何被照顧者',
                  style:
                  TextStyle(fontSize: 16, color: Colors.grey)),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _linkedUsers.length,
              itemBuilder: (context, index) {
                final user = _linkedUsers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF77A88D), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color:
                        Colors.grey.withAlpha(25), // 約 10% 陰影
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2CEAA3)
                            .withAlpha(51), // 約 20%
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person,
                          size: 30, color: Color(0xFF28965A)),
                    ),
                    title: Text(
                      user['name'] ?? '未命名',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    subtitle: Text(
                      '暱稱: ${user['nickname']?.isNotEmpty == true ? user['nickname'] : '未設定'}',
                      style: const TextStyle(
                          color: Color(0xFF777777), fontSize: 14),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit,
                          color: Colors.deepPurple),
                      onPressed: () => _editNickname(index),
                    ),
                  ),
                );
              },
            ),
          ),

          // 🔹 登出按鈕
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('登出', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
                onPressed: _logout,
              ),
            ),
          ),
        ],
      ),
    );
  }


}
