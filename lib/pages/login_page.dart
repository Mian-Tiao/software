import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _login() async {
    debugPrint('✅ login pressed');

    final account = _accountController.text.trim();
    final password = _passwordController.text.trim();
    final email = '$account@test.com';

    if (account.isEmpty || password.isEmpty) {
      _showMessage('請輸入帳號與密碼');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('➡️ signing in: $email');
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ signIn success');

      final user = FirebaseAuth.instance.currentUser;
      debugPrint('➡️ currentUser = ${user?.uid}');

      if (user != null) {
        debugPrint('➡️ reading role from firestore');
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        debugPrint('✅ firestore got doc exists=${doc.exists} data=${doc.data()}');

        if (!mounted) return;

        if (doc.exists && doc.data()?['role'] != null) {
          final role = doc['role'];
          debugPrint('✅ role=$role');
          if (role == 'caregiver') {
            Navigator.pushReplacementNamed(context, '/selectUser');
          } else if (role == 'user') {
            Navigator.pushReplacementNamed(context, '/mainMenu');
          } else {
            Navigator.pushReplacementNamed(context, '/role');
          }
        } else {
          Navigator.pushReplacementNamed(context, '/role');
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} ${e.message}');
      _showMessage('登入失敗: ${e.message}');
    } catch (e, st) {
      debugPrint('❌ login error: $e');
      debugPrint(st.toString());
      _showMessage('登入失敗：$e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFEBFDFD)], // 淺藍紫背景
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // 🔵 LOGO 區塊
                  // 🔵 LOGO 區塊
                  Container(
                    height: 100,
                    width: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/memory_icon.png',
                        width: 100,
                        height: 100,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

// 🟢 新增 APP 名稱
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF5B8EFF), Color(0xFF49E3D4)], // 藍紫 → 青綠 漸層
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      '光時',
                      style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // 會被漸層覆蓋
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    '歡迎回來',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5B8EFF), // Logo 主色
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '請登入以繼續使用',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 30),

                  // 🟣 登入卡片（白底＋輸入欄）
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _accountController,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              labelText: '帳號',
                              prefixIcon: const Icon(Icons.person_outline),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              labelText: '密碼',
                              prefixIcon: const Icon(Icons.lock_outline),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),

                          // ✅ 登入按鈕（Logo 漸層風格）
                          _isLoading
                              ? const CircularProgressIndicator()
                              : Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF5B8EFF), Color(0xFF49E3D4)],
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '登入',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: const Text(
                              '還沒有帳號？前往註冊',
                              style: TextStyle(color: Color(0xFF5B8EFF)),
                            ),
                          ),
                        ],
                      ),
                    ),
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
