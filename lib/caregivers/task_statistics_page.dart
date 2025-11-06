import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TaskStatisticsPage extends StatefulWidget {
  final String targetUid;
  final String targetName;

  const TaskStatisticsPage({
    super.key,
    required this.targetUid,
    required this.targetName,
  });

  @override
  State<TaskStatisticsPage> createState() => _TaskStatisticsPageState();
}

class _TaskStatisticsPageState extends State<TaskStatisticsPage> {
  double _completionRate = 0.0;
  List<Map<String, dynamic>> _incompleteTasks = [];
  bool _isLoading = true;
  String _selectedType = '全部';

  final List<String> _types = ['全部', '提醒', '飲食', '運動', '醫療', '生活'];

  @override
  void initState() {
    super.initState();
    _loadTaskStatistics();
  }

  Future<void> _loadTaskStatistics() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final currentTimeStr = DateFormat('HH:mm').format(now);

    final tasksSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.targetUid)
        .collection('tasks')
        .get();

    int total = 0;
    int completed = 0;
    List<Map<String, dynamic>> incomplete = [];

    for (final doc in tasksSnapshot.docs) {
      final data = doc.data();
      final date = data['date'] ?? '';
      final time = data['time'] ?? '00:00';
      final isCompleted = data['completed'] == true;
      final type = data['type'] ?? '提醒';

      final isPastTask = date.compareTo(todayKey) < 0 ||
          (date == todayKey && time.compareTo(currentTimeStr) <= 0);

      final matchType = _selectedType == '全部' || type == _selectedType;

      if (isPastTask && matchType) {
        total++;
        if (isCompleted) {
          completed++;
        } else {
          incomplete.add({
            'task': data['task'] ?? '未命名任務',
            'date': date,
            'time': time,
            'type': type,
          });
        }
      }
    }

    setState(() {
      _completionRate = total > 0 ? (completed / total) : 0.0;
      _incompleteTasks = incomplete;
      _isLoading = false;
    });
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case '提醒':
        return const Color(0xFFFFD000); // 黃
      case '飲食':
        return const Color(0xFF2CEAA3); // 主綠
      case '運動':
        return const Color(0xFF28965A); // 深綠
      case '醫療':
        return const Color(0xFFFF6670); // 紅
      case '生活':
        return const Color(0xFF678F8D); // 藍綠
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8F2DA), // 柔綠背景
      appBar: AppBar(
        backgroundColor: const Color(0xFF28965A), // 主綠
        title: Text('${widget.targetName} 的任務統計'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ⬇️ 下拉選單
            DropdownButtonFormField<String>(
              value: _selectedType,
              dropdownColor: Colors.white, // 下拉背景色
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF77A88D)),
                ),
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF28965A)),
              style: const TextStyle(
                color: Color(0xFF333333),  // 深字色
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                  _loadTaskStatistics();
                }
              },
              items: _types
                  .map((type) => DropdownMenuItem(
                value: type,
                child: Text(
                  type,
                  style: const TextStyle(
                    color: Color(0xFF333333), // 統一深色文字
                    fontSize: 16,
                  ),
                ),
              ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // ✅ 完成率卡片
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF77A88D), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2CEAA3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_box, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '完成率：${(_completionRate * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF28965A),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              '❌ 未完成任務',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _incompleteTasks.isEmpty
                  ? const Text('太棒了，目前沒有未完成的任務！', style: TextStyle(color: Colors.black),)
                  : ListView.builder(
                itemCount: _incompleteTasks.length,
                itemBuilder: (context, index) {
                  final task = _incompleteTasks[index];
                  final color = _getTypeColor(task['type']);

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF77A88D), width: 1.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withAlpha(51),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.warning, color: color),
                      ),
                      title: Text(task['task'], style: TextStyle(color: Colors.black, fontSize: 16),),
                      subtitle: Text('${task['date']} ${task['time']}', style: TextStyle(color: Colors.black, fontSize: 16),),
                      trailing: Text(task['type'], style: TextStyle(color: Colors.black, fontSize: 16),),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
