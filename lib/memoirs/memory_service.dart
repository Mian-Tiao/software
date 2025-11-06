import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 取得使用者最近的回憶資料（最多 5 筆）
  Future<List<Map<String, dynamic>>> fetchMemories(String uid) async {
    final snapshot = await _firestore
        .collection('memories')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// 將回憶資料轉為簡單摘要文字，供 Gemini 使用
  String summarizeMemories(List<Map<String, dynamic>> memories) {
    if (memories.isEmpty) return '使用者目前沒有任何回憶紀錄。';

    return memories.map((m) {
      final title = m['title'] ?? '';
      final desc = m['description'] ?? '';
      final date = (m['createdAt'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? '';
      return '【$date】$title：$desc';
    }).join('\n');
  }
}