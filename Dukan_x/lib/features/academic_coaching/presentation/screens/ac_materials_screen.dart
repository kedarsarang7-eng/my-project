// ============================================================================
// ACADEMIC COACHING — STUDY MATERIALS SCREEN
// ============================================================================
// Digital content library with upload, download, and access management

import 'package:flutter/material.dart' hide MaterialType;
import 'package:intl/intl.dart';
import '../../data/models/ac_models.dart';
import '../../data/repositories/ac_repository.dart';
import '../../../../core/di/service_locator.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AcMaterialsScreen extends StatefulWidget {
  const AcMaterialsScreen({super.key});

  @override
  State<AcMaterialsScreen> createState() => _AcMaterialsScreenState();
}

class _AcMaterialsScreenState extends State<AcMaterialsScreen> {
  late AcRepository _repository;
  List<AcMaterial> _materials = [];
  List<AcBatch> _batches = [];
  List<AcCourse> _courses = [];
  bool _isLoading = true;
  String? _error;

  String? _selectedBatchId;
  String? _selectedCourseId;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _repository = sl<AcRepository>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final [materials, batches, courses] = await Future.wait([
        _repository.listMaterials(),
        _repository.listBatches(),
        _repository.listCourses(),
      ]);

      setState(() {
        _materials = materials as List<AcMaterial>;
        _batches = batches as List<AcBatch>;
        _courses = courses as List<AcCourse>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load materials: $e';
        _isLoading = false;
      });
    }
  }

  List<AcMaterial> get _filteredMaterials {
    return _materials.where((m) {
      if (_selectedBatchId != null && !m.batchIds.contains(_selectedBatchId)) return false;
      if (_selectedCourseId != null && !m.courseIds.contains(_selectedCourseId)) return false;
      if (_selectedType != null && m.type.name != _selectedType) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 12, tablet: 20, desktop: 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 16),
              _buildFilterBar(),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildError()
                        : _buildMaterialsGrid(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadDialog(),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload Material'),
        backgroundColor: const Color(0xFF4F46E5),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Study Materials',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_materials.length} materials · ${_materials.fold<int>(0, (sum, m) => sum + m.downloadCount)} total downloads',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      ],
    );

    final actionRow = Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showUploadDialog(),
            icon: const Icon(Icons.cloud_upload, size: 18),
            label: const Text('Upload'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );

    return isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleColumn,
              const SizedBox(height: 16),
              actionRow,
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              titleColumn,
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showUploadDialog(),
                    icon: const Icon(Icons.cloud_upload, size: 18),
                    label: const Text('Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBatchId,
              hint: const Text('Filter by Batch'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Batches')),
                ..._batches.map((b) => DropdownMenuItem(
                  value: b.id,
                  child: Text(b.name),
                )),
              ],
              onChanged: (v) => setState(() => _selectedBatchId = v),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCourseId,
              hint: const Text('Filter by Course'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Courses')),
                ..._courses.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name),
                )),
              ],
              onChanged: (v) => setState(() => _selectedCourseId = v),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedType,
              hint: const Text('Filter by Type'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Types')),
                ...MaterialType.values.map((t) => DropdownMenuItem(
                  value: t.name,
                  child: Text(t.name.replaceAll('_', ' ').toUpperCase()),
                )),
              ],
              onChanged: (v) => setState(() => _selectedType = v),
            ),
          ),
          if (_selectedBatchId != null || _selectedCourseId != null || _selectedType != null)
            TextButton.icon(
              onPressed: () => setState(() {
                _selectedBatchId = null;
                _selectedCourseId = null;
                _selectedType = null;
              }),
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildMaterialsGrid() {
    if (_filteredMaterials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No materials found',
              style: TextStyle(fontSize: responsiveValue<double>(context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,  // PRESERVED: Desktop uses exactly 18 as before
                  ), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload your first study material',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showUploadDialog(),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Material'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: responsiveValue<int>(context, mobile: 1, tablet: 2, desktop: 3),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: responsiveValue<double>(context, mobile: 1.45, tablet: 1.2, desktop: 1.2),
      ),
      itemCount: _filteredMaterials.length,
      itemBuilder: (context, index) {
        final material = _filteredMaterials[index];
        return _buildMaterialCard(material);
      },
    );
  }

  Widget _buildMaterialCard(AcMaterial material) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showMaterialDetails(material),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getTypeColor(material.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      material.typeIcon,
                      color: _getTypeColor(material.type),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _showEditDialog(material);
                      if (v == 'delete') _deleteMaterial(material.id);
                      if (v == 'download') _downloadMaterial(material);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'download', child: Row(children: [Icon(Icons.download, size: 18), SizedBox(width: 8), Text('Download')])),
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                material.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                material.typeLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: _getTypeColor(material.type),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.download, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        '${material.downloadCount}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  if (!material.isFree)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₹${material.materialFee.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
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

  Color _getTypeColor(MaterialType type) {
    switch (type) {
      case MaterialType.notes:
        return const Color(0xFF4F46E5);
      case MaterialType.practicePaper:
        return const Color(0xFFF59E0B);
      case MaterialType.solution:
        return const Color(0xFF059669);
      case MaterialType.videoLink:
        return const Color(0xFFDC2626);
      case MaterialType.reference:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
          const SizedBox(height: 16),
          Text(_error ?? 'An error occurred'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showUploadDialog() {
    // Pending: Show upload dialog with file picker
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Material'),
        content: const Text('File upload dialog - implement with file_picker'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  void _showMaterialDetails(AcMaterial material) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(material.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${material.typeLabel}'),
            Text('Subject: ${material.subjectName ?? material.subjectId}'),
            Text('Downloads: ${material.downloadCount}'),
            if (material.fileSize != null)
              Text('Size: ${_formatFileSize(material.fileSize!)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _downloadMaterial(material);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(AcMaterial material) {
    // Pending: Implement edit dialog
  }

  Future<void> _deleteMaterial(String materialId) async {
    try {
      await _repository.deleteMaterial(materialId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material deleted successfully')),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  Future<void> _downloadMaterial(AcMaterial material) async {
    try {
      final result = await _repository.getMaterialDownloadUrl(material.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download URL: ${result['downloadUrl']}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get download URL: $e')),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
