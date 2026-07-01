// ============================================================================
// SCHOOL ERP — CLASS & SECTION MANAGEMENT SCREEN
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/di/service_locator.dart';

class AcClassSectionsScreen extends StatefulWidget {
  const AcClassSectionsScreen({super.key});

  @override
  State<AcClassSectionsScreen> createState() => _AcClassSectionsScreenState();
}

class _AcClassSectionsScreenState extends State<AcClassSectionsScreen>
    with SingleTickerProviderStateMixin {
  late AcRepository _repository;
  late TabController _tabController;

  List<AcClassRoom> _classes = [];
  bool _isLoading = true;
  String? _error;

  static const _teal = Color(0xFF0D9488);
  static const _bg = Color(0xFFF0FDFA);
  static const _cardBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repository = AcRepository(sl<ApiClient>());
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final classes = await _repository.listClasses();
      setState(() {
        _classes = classes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load classes: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? _buildSkeleton()
                : _error != null
                ? _buildError()
                : TabBarView(
                    controller: _tabController,
                    children: [_buildClassesGrid(), _buildSectionsOverview()],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddClassDialog(),
        backgroundColor: _teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Class',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      color: _bg,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.class_outlined, color: _teal, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Classes & Sections',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${_classes.length} classes configured',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: _teal),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _teal,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(text: 'Classes'),
          Tab(text: 'Sections Overview'),
        ],
      ),
    );
  }

  Widget _buildClassesGrid() {
    if (_classes.isEmpty) {
      return _buildEmpty();
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisExtent: 180,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _classes.length,
        itemBuilder: (_, i) => _buildClassCard(_classes[i]),
      ),
    );
  }

  Widget _buildClassCard(AcClassRoom cls) {
    final sectionCount = cls.sections.length;
    final studentCount = cls.totalStudents;
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: _teal.withOpacity(0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showClassDetail(cls),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _teal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cls.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) => _onClassAction(v, cls),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'add_section',
                        child: Text('Add Section'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                    child: const Icon(
                      Icons.more_vert,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statChip(
                    Icons.view_module_outlined,
                    '$sectionCount Sections',
                    _teal.withOpacity(0.1),
                    _teal,
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    Icons.people_outlined,
                    '$studentCount Students',
                    Colors.blue.shade50,
                    Colors.blue.shade700,
                  ),
                ],
              ),
              const Spacer(),
              if (cls.classTeacherName != null)
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cls.classTeacherName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionsOverview() {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _classes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, i) {
        final cls = _classes[i];
        return Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
            ],
          ),
          child: ExpansionTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _teal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  cls.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            title: Text(
              cls.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              '${cls.sections.length} sections · ${cls.totalStudents} students',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
            children: cls.sections
                .map((section) => _buildSectionTile(cls, section))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildSectionTile(AcClassRoom cls, AcSection section) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(72, 0, 16, 0),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            section.name,
            style: TextStyle(
              color: Colors.indigo.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
      title: Text(
        'Section ${section.name}',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        '${section.studentCount} students · Teacher: ${section.teacherName ?? 'Unassigned'}',
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              size: 18,
              color: Color(0xFF94A3B8),
            ),
            onPressed: () => _showEditSectionDialog(cls, section),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _confirmDeleteSection(cls, section),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.class_outlined, size: 64, color: _teal.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text(
            'No classes configured yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first class to get started',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddClassDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Class'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisExtent: 180,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    );
  }

  void _showAddClassDialog() {
    final nameCtrl = TextEditingController();
    final teacherCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add New Class',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Class Name (e.g. Class 8, Grade 10, JEE Batch)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.class_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: teacherCtrl,
              decoration: InputDecoration(
                labelText: 'Class Teacher (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _repository.createClass(
                  name: nameCtrl.text.trim(),
                  classTeacherName: teacherCtrl.text.trim().isEmpty
                      ? null
                      : teacherCtrl.text.trim(),
                );
                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showClassDetail(AcClassRoom cls) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${cls.name} — Sections',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 400,
          child: cls.sections.isEmpty
              ? const Text('No sections yet. Add a section to this class.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: cls.sections
                      .map(
                        (s) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _teal,
                            child: Text(
                              s.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text('Section ${s.name}'),
                          subtitle: Text('${s.studentCount} students'),
                        ),
                      )
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showAddSectionDialog(cls);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Section'),
          ),
        ],
      ),
    );
  }

  void _showAddSectionDialog(AcClassRoom cls) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Section to ${cls.name}'),
        content: TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.characters,
          maxLength: 1,
          decoration: InputDecoration(
            labelText: 'Section Name (A, B, C...)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.view_module_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _repository.addSection(
                  classId: cls.id,
                  sectionName: nameCtrl.text.trim().toUpperCase(),
                );
                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditSectionDialog(AcClassRoom cls, AcSection section) {
    final teacherCtrl = TextEditingController(text: section.teacherName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Section ${section.name} — ${cls.name}'),
        content: TextField(
          controller: teacherCtrl,
          decoration: InputDecoration(
            labelText: 'Assigned Teacher',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repository.updateSection(
                  classId: cls.id,
                  sectionId: section.id,
                  teacherName: teacherCtrl.text.trim().isEmpty
                      ? null
                      : teacherCtrl.text.trim(),
                );
                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSection(AcClassRoom cls, AcSection section) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Section?'),
        content: Text(
          'Are you sure you want to delete Section ${section.name} from ${cls.name}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repository.deleteSection(
                  classId: cls.id,
                  sectionId: section.id,
                );
                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _onClassAction(String action, AcClassRoom cls) {
    switch (action) {
      case 'add_section':
        _showAddSectionDialog(cls);
        break;
      case 'edit':
        _showEditClassDialog(cls);
        break;
      case 'delete':
        _confirmDeleteClass(cls);
        break;
    }
  }

  void _showEditClassDialog(AcClassRoom cls) {
    final nameCtrl = TextEditingController(text: cls.name);
    final teacherCtrl = TextEditingController(text: cls.classTeacherName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Class Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: teacherCtrl,
              decoration: InputDecoration(
                labelText: 'Class Teacher',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repository.updateClass(
                  classId: cls.id,
                  name: nameCtrl.text.trim(),
                  classTeacherName: teacherCtrl.text.trim().isEmpty
                      ? null
                      : teacherCtrl.text.trim(),
                );
                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteClass(AcClassRoom cls) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Class?', style: TextStyle(color: Colors.red)),
        content: Text(
          'Delete ${cls.name}? All sections under this class will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repository.deleteClass(classId: cls.id);
                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
