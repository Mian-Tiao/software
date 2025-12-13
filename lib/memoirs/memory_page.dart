import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'add_memory_page.dart';
import 'category_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_memory_page.dart';
import 'dart:async';


class Memory {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final List<String> imagePaths;
  final String audioPath;
  final String category;

  Memory({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.imagePaths,
    required this.audioPath,
    required this.category,
  });

  factory Memory.fromFirestore(String docId, Map<String, dynamic> data) {
    final imageList = data['imageUrls'];
    List<String> imagePaths = [];
    if (imageList is List) {
      imagePaths = imageList.whereType<String>().toList();
    }
    return Memory(
      id: docId,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imagePaths: imagePaths,
      audioPath: data['audioPath'] ?? '',
      category: data['category'] ?? '',
    );
  }
}

class MemoryPage extends StatefulWidget {
  final String? targetUid;
  const MemoryPage({super.key, this.targetUid});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

// 2) 新增這個小元件到同一個檔案（class 之外也可）
class _GradientPillButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;

  const _GradientPillButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // 藍→綠的柔和漸層，和頁面風格一致
    const c1 = Color(0xFF2563EB); // 藍
    const c2 = Color(0xFF2CEAA3); // 綠

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [c1, c2],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          // 柔和陰影，與頁面卡片一致
          BoxShadow(
            color: c1.withValues(alpha: .25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 4),
                const Icon(Icons.edit_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: .5,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _MemoryPageState extends State<MemoryPage> {
  final List<Memory> _memories = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _categories = ['人物', '旅遊'];
  final Set<String> _collapsedCategories = {};
  String? _uid;
  String _searchQuery = '';
  Timer? _searchDebounce;


  @override
  void initState() {
    super.initState();
    _uid = widget.targetUid ?? FirebaseAuth.instance.currentUser?.uid;
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    if (_uid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('memories')
        .where('uid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .get();

    final memories = snapshot.docs
        .map((doc) => Memory.fromFirestore(doc.id, doc.data()))
        .toList();

    if (!mounted) return;

    setState(() {
      _memories
        ..clear()
        ..addAll(memories);
    });
  }

  Future<void> _navigateToAddMemory() async {
    final ok = await showAddMemoryDialog(
      context,
      categories: _categories, // 我會自動把「其他」補進去
      targetUid: _uid,
    );
    if (!mounted) return;
    if (ok == true) _loadMemories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: const Text('回憶錄'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5B8EFF), Color(0xFF49E3D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // 搜尋框
          SizedBox(
            width: 180,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TextField(
                onChanged: (value) {
                  // 🔔 debounce：每次輸入先取消上一個計時器
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                    if (!mounted) return; // 頁面關掉就不要 setState
                    setState(() => _searchQuery = value.trim().toLowerCase());
                  });
                },
                decoration: InputDecoration(
                  hintText: '搜尋回憶…',
                  hintStyle: const TextStyle(color: Colors.white70, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .2),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 分類按鈕
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.category, size: 20),
              label: const Text('分類', style: TextStyle(fontSize: 16)),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => CategoryManager(
                  initialCategories: _categories,
                  onCategoriesUpdated: (newCats) {
                    if (!mounted) return;
                    setState(() => _categories = newCats);
                  },
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue[900],
                elevation: 1,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        children: _categories.map((category) {
          final memoriesInCategory = _memories
              .where((m) => m.category == category)
              .where((m) =>
          _searchQuery.isEmpty ||
              m.title.toLowerCase().contains(_searchQuery) ||
              m.description.toLowerCase().contains(_searchQuery))
              .toList();
          if (memoriesInCategory.isEmpty) return const SizedBox();
          final isCollapsed = _collapsedCategories.contains(category);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isCollapsed) {
                      _collapsedCategories.remove(category);
                    } else {
                      _collapsedCategories.add(category);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        isCollapsed ? Icons.expand_more : Icons.expand_less,
                        color: const Color(0xFF5B8EFF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5B8EFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isCollapsed)
                GridView.count(
                  padding: const EdgeInsets.only(bottom: 4),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  children: memoriesInCategory.map((memory) {
                    return GestureDetector(
                      onTap: () => _showMemoryDetail(memory),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: memory.imagePaths.isNotEmpty
                                ? Image.network(
                              memory.imagePaths.first,
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                            )
                                : Container(
                              width: double.infinity,
                              height: 120,
                              color: Colors.grey[300],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            memory.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF097988),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            memory.date.toString().substring(0, 16),
                            style: const TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          );
        }).toList(),
      ),
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B8EFF), Color(0xFF49E3D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(2, 2),
            )
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: _navigateToAddMemory,
        ),
      ),
    );
  }

  void _showMemoryDetail(Memory memory) {
    // 共用外框：白底 + 藍色描邊 + 柔和陰影
    Widget framed(Widget child) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2563EB), width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x802563EB), blurRadius: 14, offset: Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: child,
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            const double editBarHeight = 56;
            const double fabSize = 56;
            const double gap = 24;
            final double bottomSafe = MediaQuery.of(context).padding.bottom;
            final double padBottomForScroll = editBarHeight + fabSize + gap + bottomSafe;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  // 內容
                  SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.only(bottom: padBottomForScroll),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 📷 首圖（左下角顯示標題）
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: framed(
                            SizedBox(
                              width: double.infinity,
                              child: Stack(
                                children: [
                                  // 圖片
                                  memory.imagePaths.isNotEmpty
                                      ? Image.network(
                                    memory.imagePaths.first,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(height: 160, color: Colors.grey[300]),
                                  )
                                      : Container(height: 160, color: Colors.grey[200]),
                                  // 底部漸層，讓白字更清楚
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: IgnorePointer(
                                      child: Container(
                                        height: 84,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Colors.transparent, Colors.black54],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 左下角標題
                                  if ((memory.title).isNotEmpty)
                                    Positioned(
                                      left: 12,
                                      right: 12,
                                      bottom: 10,
                                      child: Text(
                                        memory.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          shadows: [
                                            Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 與圖片拉開距離
                        const SizedBox(height: 20),

                        // 📝 描述（標題在卡片外）
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            '描述',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 固定高度、內部可滾動
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: framed(
                            SizedBox(
                              height: 160,
                              width: double.infinity,
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    memory.description,
                                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 其餘圖片（同樣加外框）
                        ...memory.imagePaths.skip(1).map((path) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: framed(
                              Image.network(
                                path,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Container(height: 150, color: Colors.grey[300]),
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // 🔊 播放按鈕（避開底部編輯膠囊）
                  Positioned(
                    right: 20,
                    bottom: bottomSafe + editBarHeight + gap,
                    child: FloatingActionButton(
                      backgroundColor: const Color(0xFF5B8EFF),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                      onPressed: () async {
                        try {
                          if (memory.audioPath.startsWith('http')) {
                            await _audioPlayer.setUrl(memory.audioPath);
                          } else {
                            await _audioPlayer.setFilePath(memory.audioPath);
                          }
                          await _audioPlayer.play();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('無法播放語音')),
                            );
                          }
                        }
                      },
                    ),
                  ),

                  // ✏️ 編輯按鈕（底部膠囊）
                  Positioned(
                    bottom: 20 + bottomSafe,
                    left: 16,
                    right: 16,
                    child: _GradientPillButton(
                      text: '編輯回憶',
                      icon: Icons.edit_rounded,
                      onPressed: () async {
                        final ok = await showEditMemoryDialog(
                          context,
                          docId: memory.id,
                          title: memory.title,
                          description: memory.description,
                          imagePaths: memory.imagePaths,
                          audioPath: memory.audioPath,
                          category: memory.category,
                          categories: _categories,
                        );
                        if (!mounted) return;
                        if (ok == true) _loadMemories();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

}