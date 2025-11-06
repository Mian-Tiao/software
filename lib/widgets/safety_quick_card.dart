import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SafetyQuickChip extends StatelessWidget {
  const SafetyQuickChip({super.key});

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    double dLat = (lat2 - lat1) * pi / 180.0;
    double dLon = (lon2 - lon1) * pi / 180.0;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snap) {
        final user = snap.data?.data() as Map<String, dynamic>?;

        final locEnabled = user?['locationEnabled'] as bool? ?? false;
        final loc = (user?['location'] as Map<String, dynamic>?) ?? {};
        final lat = (loc['lat'] as num?)?.toDouble();
        final lng = (loc['lng'] as num?)?.toDouble();

        final zone = (user?['safeZone'] as Map<String, dynamic>?);

        String text;
        Color bg;
        Color fg;
        IconData icon;

        if (zone == null) {
          // 🔹 尚未被綁定 → 沒有安全範圍
          text = '尚未設定安全範圍';
          bg = const Color(0xFFFFF7ED);
          fg = const Color(0xFF9A3412);
          icon = Icons.shield_outlined;
        } else if (!locEnabled) {
          text = '尚未開啟定位';
          bg = const Color(0xFFFFF7ED);
          fg = const Color(0xFF9A3412);
          icon = Icons.location_off_outlined;
        } else if (lat == null || lng == null) {
          text = '等待定位…';
          bg = const Color(0xFFFFFBEB);
          fg = const Color(0xFF854D0E);
          icon = Icons.location_searching;
        } else {
          // 🔹 判斷是否在範圍內
          final cLat = (zone['lat'] as num?)?.toDouble() ?? 0.0;
          final cLng = (zone['lng'] as num?)?.toDouble() ?? 0.0;
          final radius = ((zone['radius'] as num?) ?? 300).toDouble();

          final dist = _haversine(lat, lng, cLat, cLng);
          if (dist <= radius) {
            text = '安全範圍內 · 距中心 ${dist.toStringAsFixed(0)}m';
            bg = const Color(0xFFECFDF5);
            fg = const Color(0xFF065F46);
            icon = Icons.verified_user_rounded;
          } else {
            text = '已離開安全範圍 · 超出 ${(dist - radius).toStringAsFixed(0)}m';
            bg = const Color(0xFFFFF1F2);
            fg = const Color(0xFF991B1B);
            icon = Icons.warning_rounded;
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


