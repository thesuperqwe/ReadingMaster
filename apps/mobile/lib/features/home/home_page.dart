import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/parent_pin.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
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
  bool _parentUnlocked = false;

  static const _parentTabIndex = 3;

  static const _levelOptions = [
    ('LEVEL_1', 'Level 1 · 启蒙'),
    ('LEVEL_2', 'Level 2 · 基础'),
    ('LEVEL_3', 'Level 3 · 进阶'),
    ('LEVEL_4', 'Level 4 · 提高'),
  ];

  static const _navItems = [
    (icon: Icons.home_rounded, label: '首页'),
    (icon: Icons.auto_stories_rounded, label: '书架'),
    (icon: Icons.style_rounded, label: '生词本'),
    (icon: Icons.family_restroom_rounded, label: '家长中心'),
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

  Child? get _selectedChild {
    if (_selectedChildId == null) return null;
    for (final child in _children) {
      if (child.id == _selectedChildId) return child;
    }
    return null;
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
        if (_selectedChildId == null ||
            !children.any((child) => child.id == _selectedChildId)) {
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

  Future<void> _selectTab(int index) async {
    if (index == _parentTabIndex && !_parentUnlocked) {
      final ok = await _promptParentPin();
      if (!ok) return;
      _parentUnlocked = true;
    }
    if (!mounted) return;
    setState(() {
      _tabIndex = index;
      if (index != _parentTabIndex) _parentUnlocked = false;
    });
  }

  Future<bool> _promptParentPin() async {
    final pin = await ParentPin.get();
    if (!mounted) return false;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('家长模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入家长 PIN 码'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(hintText: '4 位数字'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim() == pin),
            child: const Text('进入'),
          ),
        ],
      ),
    );
    controller.dispose();
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_children.isEmpty) {
      return Scaffold(body: _buildCreateChild());
    }
    if (_selectedChildId == null) {
      return const Scaffold(body: Center(child: Text('请选择孩子')));
    }

    final wide = MediaQuery.of(context).size.width >= 900;
    final content = _buildContent();

    return Scaffold(
      body: wide
          ? Row(
              children: [
                _buildSidebar(),
                Expanded(child: content),
              ],
            )
          : content,
      appBar: wide ? null : _buildNarrowAppBar(),
      bottomNavigationBar: wide ? null : _buildBottomNav(),
    );
  }

  Widget _buildContent() {
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

  Widget _buildSidebar() {
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppLogo(),
              const SizedBox(height: 30),
              ...List.generate(
                _navItems.length,
                (index) => _navItem(
                  icon: _navItems[index].icon,
                  label: _navItems[index].label,
                  active: _tabIndex == index,
                  onTap: () => _selectTab(index),
                ),
              ),
              const Spacer(),
              _childMenu(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '账号中心',
                      style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                    ),
                  ),
                  IconButton(
                    onPressed: _logout,
                    tooltip: '退出登录',
                    icon: const Icon(Icons.logout_rounded, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: active ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: active ? AppColors.primaryDark : AppColors.inkSoft,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.primaryDark : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildNarrowAppBar() {
    return AppBar(
      title: Text(_navItems[_tabIndex].label),
      actions: [
        _childMenu(),
        IconButton(onPressed: _logout, tooltip: '退出登录', icon: const Icon(Icons.logout_rounded)),
      ],
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _tabIndex,
      onDestinationSelected: (index) => _selectTab(index),
      destinations: _navItems
          .map(
            (item) => NavigationDestination(icon: Icon(item.icon), label: item.label),
          )
          .toList(),
    );
  }

  Widget _childMenu() {
    final child = _selectedChild;
    return PopupMenuButton<String>(
      tooltip: '切换孩子',
      onSelected: (id) => setState(() => _selectedChildId = id),
      itemBuilder: (context) => _children
          .map((c) => PopupMenuItem(value: c.id, child: Text(c.name)))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.face_rounded, size: 18, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                child?.name ?? '选择孩子',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primaryDark),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateChild() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SurfaceCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppLogo(),
                const SizedBox(height: 20),
                const Text(
                  '先创建孩子资料',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                const Text(
                  '创建后即可开始阅读、学习单词和查看成长报告。',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '姓名',
                    prefixIcon: Icon(Icons.face_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: 3,
                  decoration: const InputDecoration(
                    labelText: '年级',
                    prefixIcon: Icon(Icons.school_rounded),
                  ),
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
                  decoration: const InputDecoration(
                    labelText: '阅读等级',
                    prefixIcon: Icon(Icons.auto_awesome_rounded),
                  ),
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
                const SizedBox(height: 10),
                const Text(
                  '等级说明：Level 1 启蒙，Level 2 基础，Level 3 进阶，Level 4 提高。',
                  style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
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
    );
  }
}
