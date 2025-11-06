// category_manager.dart
import 'package:flutter/material.dart';

class CategoryManager extends StatefulWidget {
  final List<String> initialCategories;
  final void Function(List<String>) onCategoriesUpdated;

  const CategoryManager({
    super.key,
    required this.initialCategories,
    required this.onCategoriesUpdated,
  });

  @override
  State<CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<CategoryManager> {
  late List<String> _categories;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _categories = List<String>.from(widget.initialCategories);
  }

  void _addCategory() {
    final newCategory = _controller.text.trim();
    if (newCategory.isNotEmpty && !_categories.contains(newCategory)) {
      setState(() {
        _categories.add(newCategory);
        _controller.clear();
      });
      widget.onCategoriesUpdated(_categories);
    }
  }

  void _removeCategory(int index) {
    setState(() {
      _categories.removeAt(index);
    });
    widget.onCategoriesUpdated(_categories);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      minChildSize: 0.6,
      expand: false,
      builder: (_, controller) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '分類管理',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ReorderableListView(
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _categories.removeAt(oldIndex);
                    _categories.insert(newIndex, item);
                    widget.onCategoriesUpdated(_categories);
                  });
                },
                children: [
                  for (int i = 0; i < _categories.length; i++)
                    ListTile(
                      key: ValueKey(_categories[i]),
                      title: Text(_categories[i]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeCategory(i),
                      ),
                    )
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: '新增分類',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addCategory,
                  child: const Text('新增'),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}