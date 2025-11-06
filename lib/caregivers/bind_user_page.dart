import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BindUserPage extends StatefulWidget {
  const BindUserPage({super.key});

  @override
  State<BindUserPage> createState() => _BindUserPageState();
}

class _BindUserPageState extends State<BindUserPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _hasBoundUser = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfHasBoundUser();
  }

  Future<void> _checkIfHasBoundUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final doc = await FirebaseFirestore.instance
          .collection('caregivers')
          .doc(currentUser.uid)
          .get();

    final data = doc.data();
    final boundUsers = (data?['boundUsers'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (boundUsers.isNotEmpty) {
      setState(() => _hasBoundUser = true);
    }
  }

  Future<void> _bindUser() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // 1️⃣ 找被照顧者
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('identityCode', isEqualTo: code)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到該識別碼')),
      );
      return;
    }

    final targetUid = snapshot.docs.first.id;

    // 2️⃣ 建立照顧者文件（如果不存在）
    final caregiverRef =
    FirebaseFirestore.instance.collection('caregivers').doc(currentUser.uid);

    final caregiverDoc = await caregiverRef.get();
    if (!caregiverDoc.exists) {
      await caregiverRef.set({
        'boundUsers': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 3️⃣ 使用 Map 格式新增被照顧者
    await caregiverRef.update({
      'boundUsers': FieldValue.arrayUnion([
        {
          'uid': targetUid,
          'nickname': '', // 預設空字串，之後可以改成「爺爺」「奶奶」
        }
      ])
    });

    setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/selectUser');
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8F2DA), // 柔綠背景
      appBar: AppBar(
        title: const Text('綁定被照顧者'),
        backgroundColor: const Color(0xFF28965A), // 主綠
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '請輸入被照顧者識別碼以綁定',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 輸入框
            TextField(
              controller: _codeController,
              style: TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '識別碼',
                labelStyle: const TextStyle(color: Color(0xFF28965A)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF77A88D)),
                ),
                prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFF28965A)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF28965A), width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 綁定按鈕
            ElevatedButton.icon(
              icon: const Icon(Icons.link),
              onPressed: _isLoading ? null : _bindUser,
              label: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text('綁定對象'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28965A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
            ),

            // 已綁定顯示返回按鈕
            if (_hasBoundUser) const SizedBox(height: 32),
            if (_hasBoundUser)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/selectUser');
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回選擇對象'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF28965A),
                  side: const BorderSide(color: Color(0xFF77A88D), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}