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
  final _levelController = TextEditingController();

  List<Child> _children = [];
  String? _selectedChildId;
  bool _loading = true;
  bool _creatingChild = false;
  String? _error;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _levelController.dispose();
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
        readingLevel: _levelController.text.trim().isEmpty ? null : _levelController.text.trim(),
      );
      _nameController.clear();
      _gradeController.clear();
      _levelController.clear();
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
            DropdownButton<String>(
              value: _selectedChildId,
              items: _children
                  .map((child) => DropdownMenuItem(value: child.id, child: Text(child.name)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedChildId = value),
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
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('先创建孩子资料', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 16),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: '姓名')),
              const SizedBox(height: 12),
              TextField(
                controller: _gradeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '年级'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _levelController,
                decoration: const InputDecoration(labelText: '阅读等级，例如 LEVEL_2'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _creatingChild ? null : _createChild,
                child: const Text('创建孩子'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
