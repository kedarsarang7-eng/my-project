import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/ac_screen_wrapper.dart';

/// Document Vault Screen - Secure Document Management
class AcDocumentsScreen extends ConsumerStatefulWidget {
  const AcDocumentsScreen({super.key});

  @override
  ConsumerState<AcDocumentsScreen> createState() => _AcDocumentsScreenState();
}

class _AcDocumentsScreenState extends ConsumerState<AcDocumentsScreen> {
  String _selectedType = 'all';
  String _searchQuery = '';
  bool _showUploadDialog = false;

  final List<Map<String, dynamic>> _documentTypes = [
    {'id': 'photo', 'name': 'Photo', 'icon': Icons.camera},
    {
      'id': 'birth_certificate',
      'name': 'Birth Certificate',
      'icon': Icons.description,
    },
    {'id': 'marksheet', 'name': 'Marksheet', 'icon': Icons.grade},
    {'id': 'tc', 'name': 'Transfer Certificate', 'icon': Icons.school},
    {'id': 'id_proof', 'name': 'ID Proof', 'icon': Icons.badge},
    {'id': 'address_proof', 'name': 'Address Proof', 'icon': Icons.home},
    {
      'id': 'medical_record',
      'name': 'Medical Record',
      'icon': Icons.medical_services,
    },
    {'id': 'achievement', 'name': 'Achievement', 'icon': Icons.emoji_events},
    {'id': 'fee_receipt', 'name': 'Fee Receipt', 'icon': Icons.receipt},
  ];

  @override
  Widget build(BuildContext context) {
    return AcScreenWrapper(
      title: 'Document Vault',
      actions: [
        FilledButton.icon(
          onPressed: () => _showUploadDocumentDialog(),
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload'),
        ),
        const SizedBox(width: 8),
        IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list)),
      ],
      child: Column(
        children: [
          // Stats
          _buildDocumentStats(),
          const SizedBox(height: 16),
          // Type Filter Chips
          _buildTypeFilter(),
          const SizedBox(height: 16),
          // Search
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search documents...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),
          // Documents List
          Expanded(child: _buildDocumentsList()),
        ],
      ),
    );
  }

  Widget _buildDocumentStats() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text('248', style: Theme.of(context).textTheme.headlineSmall),
                  const Text('Total', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    '12',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.orange),
                  ),
                  const Text('Pending', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    '5',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.red),
                  ),
                  const Text('Expired', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeFilter() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _documentTypes.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('All'),
                selected: _selectedType == 'all',
                onSelected: (v) => setState(() => _selectedType = 'all'),
              ),
            );
          }
          final type = _documentTypes[index - 1];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(type['name']),
              selected: _selectedType == type['id'],
              onSelected: (v) => setState(() => _selectedType = type['id']),
              avatar: Icon(type['icon'], size: 16),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentsList() {
    return ListView.builder(
      itemCount: 20,
      itemBuilder: (context, index) {
        final typeIndex = index % _documentTypes.length;
        final type = _documentTypes[typeIndex];
        final statuses = ['verified', 'pending', 'rejected'];
        final status = statuses[index % statuses.length];
        final statusColors = {
          'verified': Colors.green,
          'pending': Colors.orange,
          'rejected': Colors.red,
        };

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(type['icon'], color: Colors.blue),
            ),
            title: Text('${type['name']} - Student ${index + 1}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Size: ${(index + 1) * 100} KB'),
                Text(
                  'Uploaded: ${DateTime.now().subtract(Duration(days: index)).toString().split(' ').first}',
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(
                    status.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: statusColors[status]?.withOpacity(0.2),
                  side: BorderSide.none,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleDocumentAction(value, index),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Text('View')),
                    const PopupMenuItem(
                      value: 'download',
                      child: Text('Download'),
                    ),
                    const PopupMenuItem(value: 'verify', child: Text('Verify')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUploadDocumentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Document'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Entity Type
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'For',
                  border: OutlineInputBorder(),
                ),
                items: ['Student', 'Faculty', 'Application']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {},
              ),
              const SizedBox(height: 16),
              // Entity Selection
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Select Student/Faculty',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Document Type
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Document Type',
                  border: OutlineInputBorder(),
                ),
                items: _documentTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t['id'] as String,
                        child: Text(t['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) {},
              ),
              const SizedBox(height: 16),
              // File Drop Zone
              Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Drop file here or click to browse'),
                      Text(
                        'Max 10MB',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Description
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _uploadDocument();
            },
            icon: const Icon(Icons.upload),
            label: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  void _uploadDocument() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uploading...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Uploading document to secure storage...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded successfully')),
      );
    });
  }

  void _handleDocumentAction(String action, int index) {
    switch (action) {
      case 'view':
        _viewDocument(index);
        break;
      case 'download':
        _downloadDocument(index);
        break;
      case 'verify':
        _verifyDocument(index);
        break;
      case 'delete':
        _deleteDocument(index);
        break;
    }
  }

  void _viewDocument(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Document Preview'),
        content: SizedBox(
          width: 400,
          height: 500,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.document_scanner,
                  size: 100,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text('Document ${index + 1} Preview'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _downloadDocument(int index) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Downloading...')));
  }

  void _verifyDocument(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Document'),
        content: const Text('Confirm this document is valid and authentic?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Document verified')),
              );
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _deleteDocument(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Document deleted')));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
