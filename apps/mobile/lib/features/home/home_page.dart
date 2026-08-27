import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../auth/login_page.dart';
import '../bookshelf/bookshelf_page.dart';
import '../parent/parent_dashboard_page.dart';
import '../vocabulary/vocabulary_page.dart';
import 'home_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _apiService = ApiService();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  String _selectedLevel = 'LEVEL_2';

  List<Child> _children = [];
  String? _selectedChildId;
  bool _loading = true;
  bool _creatingChild = false;
  String? _error;
  int _tabIndex = 0;

  static const _levelOptions = [
    ('LEVEL_1', 'Level 1 · 启蒙'),
    ('LEVEL_2', 'Level 2 · 基础'),
    ('LEVEL_3', 'Level 3 · 进阶'),
    ('LEVEL_4', 'Level 4 · 提高'),
  ];

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final children = await _apiService.getChildren();
      setState(() {
        _children = children;
        if (_selectedChildId == null || !children.any((child) => child.id == _selectedChildId)) {
          _selectedChildId = children.isEmpty ? null : children.first.id;
        }
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createChild() async {
    setState(() {
      _creatingChild = true;
      _error = null;
    });

    try {
      await _apiService.createChild(
        name: _nameController.text.trim(),
        grade: int.tryParse(_gradeController.text.trim()),
        readingLevel: _selectedLevel,
      );
      _nameController.clear();
      _gradeController.clear();
      setState(() => _selectedLevel = 'LEVEL_2');
      await _loadChildren();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _creatingChild = false);
    }
  }

  Future<void> _logout() async {
    ApiClient.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReadingMaster（阅读王）'),
        actions: [
          if (_children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<String>(
                value: _selectedChildId,
                items: _children
                    .map((child) => DropdownMenuItem(value: child.id, child: Text(child.name)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedChildId = value),
              ),
            ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _children.isEmpty
          ? null
          : NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (index) => setState(() => _tabIndex = index),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: '首页'),
                NavigationDestination(icon: Icon(Icons.menu_book), label: '书架'),
                NavigationDestination(icon: Icon(Icons.style), label: '生词'),
                NavigationDestination(icon: Icon(Icons.family_restroom), label: '家长'),
              ],
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_children.isEmpty) return _buildCreateChild();
    if (_selectedChildId == null) return const Center(child: Text('请选择孩子'));

    return IndexedStack(
      index: _tabIndex,
      children: [
        HomeTab(childId: _selectedChildId!),
        BookshelfPage(childId: _selectedChildId!),
        VocabularyPage(childId: _selectedChildId!),
        ParentDashboardPage(childId: _selectedChildId!),
      ],
    );
  }

  Widget _buildCreateChild() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('先创建孩子资料', style: TextStyle(fontSize: 22)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '姓名', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: 3,
                    decoration: const InputDecoration(labelText: '年级', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('一年级')),
                      DropdownMenuItem(value: 2, child: Text('二年级')),
                      DropdownMenuItem(value: 3, child: Text('三年级')),
                      DropdownMenuItem(value: 4, child: Text('四年级')),
                      DropdownMenuItem(value: 5, child: Text('五年级')),
                      DropdownMenuItem(value: 6, child: Text('六年级')),
                    ],
                    onChanged: (value) {
                      _gradeController.text = value?.toString() ?? '';
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLevel,
                    decoration: const InputDecoration(labelText: '阅读等级', border: OutlineInputBorder()),
                    items: _levelOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.$1,
                            child: Text(option.$2),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedLevel = value ?? 'LEVEL_2'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '等级说明：Level 1 启蒙，Level 2 基础，Level 3 进阶，Level 4 提高。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _creatingChild ? null : _createChild,
                    child: const Text('创建孩子'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
