import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePwd = true;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final account = _accountController.text.trim();
    final password = _passwordController.text.trim();
    final email = '$account@test.com'; // 模擬 email

    if (account.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請輸入帳號與密碼')),
        );
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('註冊成功，請返回登入')),
      );
      Navigator.pop(context); // 回到登入頁
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('註冊失敗: ${e.message ?? e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeBlue = Color(0xFF5B8EFF);
    const themeTeal = Color(0xFF49E3D4);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FB),
      appBar: AppBar(
        title: const Text('註冊'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [themeBlue, themeTeal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo + title
                  Column(
                    children: [
                      Image.asset('assets/images/memory_icon.png', width: 52),
                      const SizedBox(height: 8),
                      const Text(
                        '建立新帳號',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 帳號
                  TextField(
                    controller: _accountController,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    decoration: _inputDeco(
                      label: '帳號（自訂名稱）',
                      icon: Icons.person,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 密碼
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePwd,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    decoration: _inputDeco(
                      label: '密碼',
                      icon: Icons.lock,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePwd ? Icons.visibility : Icons.visibility_off,
                          color: themeBlue,
                        ),
                        onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 註冊按鈕
                  SizedBox(
                    height: 48,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [themeBlue, themeTeal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            '註冊',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 返回登入（按鈕外，避免 overflow）
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '返回登入頁面',
                      style: TextStyle(
                        color: themeBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 補充說明
                  const Text(
                    '點擊註冊即代表你同意服務條款與隱私權政策。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black87, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 共用輸入框外觀（避免 withOpacity 的 deprecated，改用 withValues）
  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF5B8EFF)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.grey.withValues(alpha: .06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: .25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: .25)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFF5B8EFF), width: 1.6),
      ),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E40AF),
      ),
    );
  }
}