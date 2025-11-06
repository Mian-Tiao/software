// lib/services/mood_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MoodService {
  final String uid;
  MoodService(this.uid);

  final _db = FirebaseFirestore.instance;

  String get todayKey {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  DocumentReference<Map<String, dynamic>> _docRefForToday() {
    return _db.collection('users').doc(uid)
        .collection('moods').doc(todayKey);
  }

  Future<bool> hasCheckedInToday() async {
    final doc = await _docRefForToday().get();
    return doc.exists;
  }

  Future<void> saveMood(String mood, {String? note}) async {
    await _docRefForToday().set({
      'mood': mood, // '喜' | '怒' | '哀' | '樂'
      'note': note ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'source': 'daily_checkin_v1',
    }, SetOptions(merge: true));
  }
}