import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TodaySummaryPanel extends StatelessWidget {
  const TodaySummaryPanel({super.key});

  String _todayStr() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int _toMinutes(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return -1;
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    return h * 60 + m;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }

    final today = _todayStr();
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .where('date', isEqualTo: today)
        .snapshots();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日速覽',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];

              // 統計
              final total = docs.length;
              final done = docs.where((d) => d.data()['completed'] == true).length;

              // 下一件（未完成且時間未過的最早）
              final now = TimeOfDay.now();
              final nowMin = now.hour * 60 + now.minute;

              final items = docs.map((d) => d.data()).toList();
              items.sort((a, b) => (a['time'] ?? '').toString().compareTo((b['time'] ?? '').toString()));
              Map<String, dynamic>? nextItem;
              for (final m in items) {
                final completed = m['completed'] == true;
                final tMin = _toMinutes((m['time'] ?? '').toString());
                if (!completed && tMin >= nowMin) {
                  nextItem = m;
                  break;
                }
              }

              return Row(
                children: [
                  // 今日任務
                  Expanded(
                    child: _SmallCard(
                      leading: Icons.checklist_rounded,
                      leadingBg: const Color(0xFFE6F0FF),
                      title: '今日任務',
                      body: '完成 $done / $total',
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 下一件
                  Expanded(
                    child: _SmallCard(
                      leading: Icons.alarm_rounded,
                      leadingBg: const Color(0xFFFFEFE5),
                      title: '下一件',
                      body: (nextItem == null)
                          ? '—'
                          : '${(nextItem['time'] ?? '--:--')}  ${(nextItem['task'] ?? '').toString()}',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  final IconData leading;
  final Color leadingBg;
  final String title;
  final String body;

  const _SmallCard({
    required this.leading,
    required this.leadingBg,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: leadingBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(leading, color: const Color(0xFF111827)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    )),
                const SizedBox(height: 6),
                Text(body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    )),
              ],
            ),
          )
        ],
      ),
    );
  }
}
