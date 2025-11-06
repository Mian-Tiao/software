import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'caregiver_session.dart';

class SelectUserPage extends StatefulWidget {
  const SelectUserPage({super.key});

  @override
  State<SelectUserPage> createState() => _SelectUserPageState();
}

class _SelectUserPageState extends State<SelectUserPage> {
  List<Map<String, dynamic>> _linkedUsers = [];
  bool _isLoading = true;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _loadLinkedUsers();
  }

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

      if(!mounted) return;

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
            'name': data['name'] ?? '未命名',
            'identityCode': data['identityCode'] ?? '',
            'uid': uid,
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
      debugPrint('讀取錯誤: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('讀取失敗，請稍後再試')),
      );
    }
  }

  void _selectUser(Map<String, dynamic> userData) {
    if (_navigating) return; // 防止連點
    _navigating = true;

    Navigator.pushReplacementNamed(
      context,
      '/caregiver', // 這個 route 會對應到 NavHomePage
      arguments: {
        'uid': userData['uid'],
        'name': userData['name'],
        'identityCode': userData['identityCode'],
      },
    ).whenComplete(() => _navigating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8F2DA), // ✅ 柔綠背景
      appBar: AppBar(
        title: const Text('選擇查看對象'),
        backgroundColor: const Color(0xFF28965A), // ✅ 深綠 AppBar
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/bindUser');
            },
            tooltip: '新增綁定對象',
            icon: const Icon(Icons.person_add),
            color: Colors.white,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _linkedUsers.isEmpty
          ? const Center(
        child: Text(
          '尚未綁定任何對象',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _linkedUsers.length,
        itemBuilder: (context, index) {
          final user = _linkedUsers[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF77A88D), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(20),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2CEAA3).withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Color(0xFF28965A)),
              ),
              title: Text(
                user['nickname'] != null && user['nickname'].toString().isNotEmpty
                    ? '${user['name']}（${user['nickname']}）'
                    : user['name'],
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333), // ✅ 深灰
                ),
              ),
              subtitle: Text(
                '識別碼：${user['identityCode']}',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF777777),
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded,
                  size: 26, color: Color(0xFF28965A)),
              onTap: () {
                CaregiverSession.selectedCareReceiverUid = user['uid'];
                CaregiverSession.selectedCareReceiverName = user['name'];
                CaregiverSession.selectedCareReceiverIdentityCode = user['identityCode'];
                debugPrint(CaregiverSession.selectedCareReceiverIdentityCode);
                _selectUser(user);
              },
            ),
          );
        },
      ),
    );
  }
}
