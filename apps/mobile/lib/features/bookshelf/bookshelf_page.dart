import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../reader/reader_page.dart';
import 'add_book_page.dart';
import 'edit_book_questions_page.dart';

class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key, required this.childId});

  final String childId;

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  final _apiService = ApiService();
  List<Book> _books = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _level;

  static const _levels = [
    ('LEVEL_1', 'Level 1'),
    ('LEVEL_2', 'Level 2'),
    ('LEVEL_3', 'Level 3'),
    ('LEVEL_4', 'Level 4'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final books = await _apiService.getBooks();
      setState(() => _books = books);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddBook() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddBookPage()),
    );
    if (created == true) await _load();
  }

  Future<void> _openEditQuestions(Book book) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditBookQuestionsPage(bookId: book.id),
      ),
    );
    await _load();
  }

  Future<void> _deleteBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除图书'),
        content: Text('确定要删除「${book.title}」吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _apiService.deleteBook(book.id);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$error')),
        );
      }
    }
  }

  List<Book> get _filtered {
    final query = _query.trim().toLowerCase();
    return _books.where((book) {
      final matchesLevel = _level == null || book.level == _level;
      final matchesQuery =
          query.isEmpty || book.title.toLowerCase().contains(query);
      return matchesLevel && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('加载失败：$_error'));
    final books = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '探索故事',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openAddBook,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('添加图书'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: '搜索书名、单词或主题',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _levelChip('全部', selected: _level == null, onSelected: () => setState(() => _level = null)),
                    ..._levels.map(
                      (level) => _levelChip(
                        level.$2,
                        selected: _level == level.$1,
                        onSelected: () => setState(() => _level = level.$1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: books.isEmpty
              ? _emptyState()
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width >= 900 ? 4 : 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, index) => _bookCard(books[index]),
                ),
        ),
      ],
    );
  }

  Widget _levelChip(String label, {required bool selected, required VoidCallback onSelected}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  Widget _bookCard(Book book) {
    final preview = book.contentPreview ?? '';
    final typeParts = [
      if (book.category?.isNotEmpty == true) book.category!,
      levelLabel(book.level),
    ];
    final typeLine = typeParts.join(' · ');
    final description = book.description?.isNotEmpty == true ? book.description! : '';

    return SurfaceCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReaderPage(bookId: book.id, childId: widget.childId),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              BookCover(
                title: book.title,
                category: book.category,
                description: book.description,
                level: book.level,
                height: 84,
                width: double.infinity,
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '添加题目',
                        onPressed: () => _openEditQuestions(book),
                        icon: const Icon(Icons.quiz_outlined, size: 19, color: AppColors.primaryDark),
                      ),
                      IconButton(
                        tooltip: '删除',
                        onPressed: () => _deleteBook(book),
                        icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.danger),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            typeLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ],
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const StarRow(size: 12),
              const SizedBox(width: 6),
              Text(
                '${book.estimatedMinutes ?? 5} 分钟',
                style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_outlined, size: 64, color: AppColors.inkSoft),
          const SizedBox(height: 12),
          const Text('没有找到匹配的图书', style: TextStyle(color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
