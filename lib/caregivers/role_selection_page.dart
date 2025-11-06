import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  final FlutterTts flutterTts = FlutterTts();
  String? _selectedRole; // 'caregiver' or 'user'

  Future<void> _handleSelection(String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await flutterTts.speak("尚未登入，無法選擇角色");
      return;
    }

    if (_selectedRole == role) {
      final uid = user.uid;
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

      final dataToSave = {
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (role == 'user') {
        final uniqueId = const Uuid().v4();
        dataToSave['identityCode'] = uniqueId;
      }

      await userDoc.set(dataToSave, SetOptions(merge: true));
      await flutterTts.speak("角色已確認並儲存");

      if (!mounted) return;
      if (role == 'caregiver') {
        final caregiverDoc = await FirebaseFirestore.instance.collection('caregivers').doc(uid).get();
        final boundUsers = caregiverDoc.data()?['boundUsers'] ?? [];

        if (boundUsers.isEmpty) {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/bindUser');
        } else {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/selectUser');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/mainMenu');
      }
    } else {
      setState(() {
        _selectedRole = role;
      });
      final roleText = role == 'caregiver' ? '照顧者' : '被照顧者';
      await flutterTts.speak("你已選擇 $roleText，請再點擊一次確認選擇");
    }
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> selectedGradient,
    required List<Color> unselectedGradient,
  }) {
    final isSelected = _selectedRole == role;

    return InkWell(
      onTap: () => _handleSelection(role),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected ? selectedGradient : unselectedGradient,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: isSelected ? selectedGradient.last : unselectedGradient.last,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              child: Icon(
                icon,
                size: 36,
                color: isSelected ? Colors.white : selectedGradient.last,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : selectedGradient.last,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.grey[800],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      appBar: AppBar(
        title: const Text(
          '請選擇您的身分',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 照顧者（綠色系）
            _buildRoleCard(
              role: 'caregiver',
              icon: Icons.volunteer_activism,
              title: '我是照顧者',
              subtitle: '我負責協助照顧他人',
              selectedGradient: [
                const Color(0xFF2CEAA3),
                const Color(0xFF28965A),
              ],
              unselectedGradient: [
                const Color(0xFFD8F2DA),
                const Color(0xFFB2E5C1),
              ],
            ),
            const SizedBox(height: 32),
            // 被照顧者（藍色系）
            _buildRoleCard(
              role: 'user',
              icon: Icons.person,
              title: '我是被照顧者',
              subtitle: '我需要協助與提醒',
              selectedGradient: [
                const Color(0xFF4A90E2),
                const Color(0xFF145DA0),
              ],
              unselectedGradient: [
                const Color(0xFFD8E6F2),
                const Color(0xFFA9CBE7),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
